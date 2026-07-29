#!/usr/bin/env python3
"""UI 확인용 샘플 데이터를 만든다. LLM 호출 없이 돌아간다.

실제 RSS 에서 기사를 가져오되, 요약 자리에는 원문 발췌를 그대로 넣는다.
즉 여기 나오는 한국어 요약은 '진짜 요약이 아니다'. 화면 레이아웃이
실제 길이의 글에서 어떻게 보이는지 확인하는 용도로만 쓴다.

    python collector/make_fixture.py /tmp/ui-fixture
"""

import json
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import collect  # noqa: E402
import fetcher  # noqa: E402
import store  # noqa: E402

CATEGORIES = ["속보", "중요", "참고", "팁"]
TAG_HINTS = {
    "OpenAI": ["openai", "chatgpt", "gpt", "오픈ai"],
    "Anthropic": ["anthropic", "claude", "클로드", "앤트로픽"],
    "Google": ["google", "gemini", "deepmind", "구글", "제미나이"],
    "오픈소스": ["open source", "open-source", "llama", "qwen", "오픈소스"],
    "AI 에이전트": ["agent", "에이전트", "mcp"],
    "반도체": ["nvidia", "gpu", "chip", "엔비디아", "반도체"],
}


def guess_tags(text: str):
    low = text.lower()
    tags = [tag for tag, hints in TAG_HINTS.items() if any(h in low for h in hints)]
    return tags[:3] or ["AI"]


def main() -> int:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ui-fixture"
    os.makedirs(os.path.join(out_dir, "data"), exist_ok=True)

    settings, sources = collect.load_config()
    articles = fetcher.fetch_all(sources, settings["max_age_hours"], log=print)
    articles = collect.select_new(articles, {}, [], 40)

    items = []
    for index, article in enumerate(articles):
        blob = f"{article['title']} {article['raw_summary']}"
        items.append(
            {
                "id": article["id"],
                "url": article["url"],
                "source": article["source"],
                "title": article["title"],
                "title_ko": article["title"],
                "summary_ko": (article["raw_summary"] or article["title"])[:180],
                "category": CATEGORIES[index % len(CATEGORIES)],
                "tags": guess_tags(blob),
                "published_at": article["published_at"],
                "collected_at": article["collected_at"],
            }
        )

    with open(os.path.join(out_dir, "data", "latest.json"), "w", encoding="utf-8") as f:
        json.dump(
            {
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "generator": "fixture (요약 아님)",
                "count": len(items),
                "items": items,
            },
            f,
            ensure_ascii=False,
            indent=1,
        )

    with open(os.path.join(out_dir, "data", "briefing.json"), "w", encoding="utf-8") as f:
        json.dump(
            {
                "headline": "이것은 화면 확인용 샘플 브리핑입니다",
                "points": [
                    "실제 브리핑은 LLM 이 지난 24시간 기사를 읽고 만듭니다.",
                    "여기 문장들은 길이만 비슷하게 맞춘 자리 채우기입니다.",
                    "카드가 길어졌을 때 줄바꿈과 여백이 어떻게 보이는지 확인합니다.",
                ],
                "date_kst": datetime.now(store.KST).strftime("%Y-%m-%d"),
                "generated_at": datetime.now(timezone.utc).isoformat(),
            },
            f,
            ensure_ascii=False,
            indent=1,
        )

    print(f"\n샘플 {len(items)}건 → {out_dir}/data/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
