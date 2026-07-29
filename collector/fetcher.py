"""RSS/Atom 피드를 읽어 공통 형식의 기사 목록으로 바꾼다.

여기서는 '가져오기'만 한다. 요약·분류는 summarizer.py 가 맡는다.
"""

import hashlib
import html
import re
import time
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional
from urllib.parse import urlparse, urlunparse

import feedparser
import requests

USER_AGENT = "Mozilla/5.0 (compatible; ai-news-collector/1.0; +https://github.com)"
REQUEST_TIMEOUT = 25
DEFAULT_MAX_ENTRIES = 20

# 링크에 붙는 추적용 쿼리 파라미터. 같은 기사가 다른 URL로 보이는 걸 막는다.
TRACKING_PARAMS = ("utm_", "fbclid", "gclid", "ref", "ref_src", "source")

_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")
_NON_WORD_RE = re.compile(r"[^0-9a-z가-힣]+")


def canonical_url(url: str) -> str:
    """추적 파라미터를 떼어낸 정규화 URL."""
    try:
        parts = urlparse(url)
    except ValueError:
        return url
    kept = []
    for chunk in parts.query.split("&"):
        if not chunk:
            continue
        key = chunk.split("=", 1)[0].lower()
        if any(key.startswith(p) for p in TRACKING_PARAMS):
            continue
        kept.append(chunk)
    netloc = parts.netloc.lower()
    if netloc.startswith("www."):
        netloc = netloc[4:]
    path = parts.path.rstrip("/") or "/"
    return urlunparse((parts.scheme, netloc, path, "", "&".join(kept), ""))


def article_id(url: str) -> str:
    return hashlib.sha1(canonical_url(url).encode("utf-8")).hexdigest()[:16]


def title_key(title: str) -> str:
    """제목 기반 중복 판별용 키. 서로 다른 매체가 같은 소식을 올린 경우를 잡는다."""
    text = _NON_WORD_RE.sub(" ", strip_html(title).lower())
    words = [w for w in text.split() if len(w) > 1]
    return " ".join(sorted(set(words))[:12])


def strip_html(text: str) -> str:
    if not text:
        return ""
    return _WS_RE.sub(" ", html.unescape(_TAG_RE.sub(" ", text))).strip()


def _published_at(entry) -> Optional[datetime]:
    for field in ("published_parsed", "updated_parsed", "created_parsed"):
        value = getattr(entry, field, None)
        if value:
            try:
                return datetime.fromtimestamp(time.mktime(value), tz=timezone.utc)
            except (ValueError, OverflowError):
                continue
    return None


def _entry_summary(entry) -> str:
    for field in ("summary", "description"):
        value = getattr(entry, field, None)
        if value:
            return strip_html(value)[:1200]
    content = getattr(entry, "content", None)
    if content:
        return strip_html(content[0].get("value", ""))[:1200]
    return ""


def _get_with_retry(url: str, attempts: int = 3):
    """429/5xx 는 잠깐 쉬고 다시 시도한다. Reddit 이 자주 걸린다."""
    delay = 4
    last = None
    for attempt in range(attempts):
        response = requests.get(
            url, timeout=REQUEST_TIMEOUT, headers={"User-Agent": USER_AGENT}
        )
        if response.status_code < 400:
            return response
        last = response
        if response.status_code not in (429, 500, 502, 503, 504):
            break
        if attempt < attempts - 1:
            time.sleep(delay)
            delay *= 2
    last.raise_for_status()
    return last


def fetch_source(source: Dict, max_age_hours: int) -> List[Dict]:
    """소스 하나를 읽어 기사 리스트를 돌려준다. 실패하면 예외를 올린다."""
    response = _get_with_retry(source["url"])
    parsed = feedparser.parse(response.content)

    cutoff = datetime.now(timezone.utc) - timedelta(hours=max_age_hours)
    limit = source.get("max_entries", DEFAULT_MAX_ENTRIES)
    now_iso = datetime.now(timezone.utc).isoformat()

    articles = []
    for entry in parsed.entries[: limit * 3]:
        link = getattr(entry, "link", "") or ""
        title = strip_html(getattr(entry, "title", "") or "")
        if not link or not title:
            continue
        published = _published_at(entry)
        if published and published < cutoff:
            continue
        articles.append(
            {
                "id": article_id(link),
                "url": link,
                "source": source["name"],
                "lang": source.get("lang", "en"),
                "title": title,
                "raw_summary": _entry_summary(entry),
                "published_at": (published or datetime.now(timezone.utc)).isoformat(),
                "collected_at": now_iso,
            }
        )
        if len(articles) >= limit:
            break
    return articles


def fetch_all(sources: List[Dict], max_age_hours: int, log=print) -> List[Dict]:
    """모든 소스를 순회한다. 한 소스가 실패해도 나머지는 계속 진행한다."""
    collected: List[Dict] = []
    seen_ids = set()
    hard_failures = []

    for source in sources:
        try:
            articles = fetch_source(source, max_age_hours)
        except Exception as exc:  # noqa: BLE001 - 소스별 실패 격리가 목적
            label = "건너뜀" if source.get("optional") else "실패"
            log(f"  [{label}] {source['name']}: {type(exc).__name__}: {exc}")
            if not source.get("optional"):
                hard_failures.append(source["name"])
            continue

        added = 0
        for article in articles:
            if article["id"] in seen_ids:
                continue
            seen_ids.add(article["id"])
            collected.append(article)
            added += 1
        log(f"  [수집] {source['name']}: {added}건")

    if hard_failures and len(hard_failures) == len(
        [s for s in sources if not s.get("optional")]
    ):
        raise RuntimeError(f"필수 소스가 전부 실패했습니다: {hard_failures}")

    return collected
