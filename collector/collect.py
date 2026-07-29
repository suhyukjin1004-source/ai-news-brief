#!/usr/bin/env python3
"""AI 뉴스 수집기 — RSS 수집 → 중복 제거 → 한국어 요약/분류 → data/*.json 저장.

로컬 실행:
    GEMINI_API_KEY=... python collector/collect.py
    python collector/collect.py --dry-run    # LLM 호출 없이 수집만 확인
"""

import argparse
import os
import sys
from collections import OrderedDict
from datetime import datetime, timezone

import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fetcher  # noqa: E402
import notify  # noqa: E402
import store  # noqa: E402
import summarizer  # noqa: E402

CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sources.yaml")

DEFAULT_SETTINGS = {
    "max_age_hours": 36,
    "max_new_per_run": 45,
    "latest_size": 200,
    "seen_retention_days": 14,
    "briefing_hour_kst": 7,
}


def log(message: str = "") -> None:
    print(message, flush=True)


def load_config():
    with open(CONFIG_PATH, "r", encoding="utf-8") as handle:
        config = yaml.safe_load(handle) or {}
    settings = dict(DEFAULT_SETTINGS)
    settings.update(config.get("settings") or {})
    sources = [s for s in (config.get("sources") or []) if s.get("url")]
    return settings, sources


def select_new(candidates, seen, recent_items, limit):
    """이미 본 기사와 제목이 겹치는 기사를 걸러낸 뒤 limit 개를 고른다.

    글이 잦은 소스(AI타임스 등)가 목록을 독차지하지 않도록,
    소스별 최신순 줄을 세워 한 건씩 번갈아 뽑는다.
    """
    known_titles = {fetcher.title_key(i.get("title", "")) for i in recent_items}
    known_titles.discard("")

    by_source = OrderedDict()
    total = 0
    for article in candidates:
        if article["id"] in seen:
            continue
        key = fetcher.title_key(article["title"])
        if key and key in known_titles:
            continue
        known_titles.add(key)
        by_source.setdefault(article["source"], []).append(article)
        total += 1

    for queue in by_source.values():
        queue.sort(key=lambda a: a.get("published_at", ""), reverse=True)

    fresh = []
    while len(fresh) < limit and any(by_source.values()):
        for queue in by_source.values():
            if not queue:
                continue
            fresh.append(queue.pop(0))
            if len(fresh) >= limit:
                break

    if total > len(fresh):
        log(f"  [제한] 새 기사 {total}건 중 소스별로 고루 {len(fresh)}건만 처리합니다.")
    fresh.sort(key=lambda a: a.get("published_at", ""), reverse=True)
    return fresh


def should_make_briefing(settings, force: bool) -> bool:
    if force:
        return True
    hour = settings.get("briefing_hour_kst")
    if hour is None:
        return True
    now_kst = datetime.now(store.KST)
    today = now_kst.strftime("%Y-%m-%d")
    existing = store.load_briefing()
    if existing and existing.get("date_kst") == today:
        return False
    return now_kst.hour >= int(hour)


def main() -> int:
    parser = argparse.ArgumentParser(description="AI 뉴스 수집기")
    parser.add_argument(
        "--dry-run", action="store_true", help="LLM 호출 없이 수집 결과만 출력"
    )
    parser.add_argument(
        "--no-push", action="store_true", help="푸시 알림을 보내지 않음"
    )
    parser.add_argument(
        "--briefing", action="store_true", help="시각과 무관하게 브리핑을 생성"
    )
    args = parser.parse_args()

    settings, sources = load_config()
    log(f"=== 수집 시작 {datetime.now(store.KST).strftime('%Y-%m-%d %H:%M KST')} ===")
    log(f"소스 {len(sources)}개")

    candidates = fetcher.fetch_all(sources, settings["max_age_hours"], log=log)
    log(f"후보 {len(candidates)}건")

    seen = store.load_seen()
    latest = store.load_latest()
    fresh = select_new(candidates, seen, latest[:150], settings["max_new_per_run"])
    log(f"새 기사 {len(fresh)}건")

    if args.dry_run:
        for article in fresh[:30]:
            log(f"  · [{article['source']}] {article['title'][:80]}")
        log("--dry-run 이므로 여기까지 합니다.")
        return 0

    if not fresh:
        log("새 기사가 없어 종료합니다.")
        return 0

    try:
        engine = summarizer.get_summarizer()
    except summarizer.SummarizerError as exc:
        log("")
        log(f"요약 엔진을 쓸 수 없습니다: {exc}")
        log("GitHub 저장소 Settings → Secrets and variables → Actions 에서")
        log("GEMINI_API_KEY 를 등록하세요. 자세한 절차는 docs/setup.md 를 보세요.")
        return 1

    enriched = engine.summarize(fresh, log=log)
    log(f"엔진: {engine.label}")

    now_iso = datetime.now(timezone.utc).isoformat()
    for article in fresh:
        seen[article["id"]] = now_iso

    if enriched:
        new_ids = {e["id"] for e in enriched}
        merged = enriched + [i for i in latest if i.get("id") not in new_ids]
        merged.sort(key=lambda i: i.get("published_at", ""), reverse=True)
        store.save_latest(merged, settings["latest_size"], engine.label)
        store.append_archive(enriched)
        log(f"latest.json 갱신: 신규 {len(enriched)}건 / 전체 {min(len(merged), settings['latest_size'])}건")
    else:
        merged = latest
        log("채택된 기사가 없습니다.")

    store.save_seen(seen, settings["seen_retention_days"])

    if should_make_briefing(settings, args.briefing):
        briefing = engine.briefing(merged[:60], log=log)
        if briefing:
            store.save_briefing(briefing)
            log(f"브리핑 생성: {briefing['headline']}")

    if not args.no_push and enriched:
        notify.push_alerts(enriched, log=log)

    log("=== 완료 ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
