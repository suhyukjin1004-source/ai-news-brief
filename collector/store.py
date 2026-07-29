"""data/ 폴더의 JSON 파일을 읽고 쓴다."""

import json
import os
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

KST = timezone(timedelta(hours=9))


def data_dir() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(os.path.dirname(here), "data")


def _path(*parts) -> str:
    return os.path.join(data_dir(), *parts)


def read_json(relative: str, default):
    path = _path(relative)
    if not os.path.exists(path):
        return default
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (json.JSONDecodeError, OSError):
        return default


def write_json(relative: str, payload) -> None:
    path = _path(relative)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    os.replace(tmp, path)


def load_seen() -> Dict[str, str]:
    seen = read_json("seen.json", {})
    return seen if isinstance(seen, dict) else {}


def save_seen(seen: Dict[str, str], retention_days: int) -> None:
    cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)
    kept = {}
    for key, stamp in seen.items():
        try:
            if datetime.fromisoformat(stamp) >= cutoff:
                kept[key] = stamp
        except (ValueError, TypeError):
            continue
    write_json("seen.json", kept)


def load_latest() -> List[Dict]:
    payload = read_json("latest.json", {})
    if isinstance(payload, dict):
        items = payload.get("items", [])
    else:
        items = payload
    return items if isinstance(items, list) else []


def save_latest(items: List[Dict], limit: int, generator: str) -> None:
    write_json(
        "latest.json",
        {
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "generator": generator,
            "count": len(items[:limit]),
            "items": items[:limit],
        },
    )


def append_archive(items: List[Dict]) -> None:
    """기사를 발행일(KST) 기준 날짜별 파일에 덧붙인다."""
    by_day: Dict[str, List[Dict]] = {}
    for item in items:
        try:
            when = datetime.fromisoformat(item["published_at"]).astimezone(KST)
        except (ValueError, KeyError, TypeError):
            when = datetime.now(KST)
        by_day.setdefault(when.strftime("%Y-%m-%d"), []).append(item)

    for day, day_items in by_day.items():
        relative = os.path.join("archive", f"{day}.json")
        existing = read_json(relative, [])
        if not isinstance(existing, list):
            existing = []
        known = {i.get("id") for i in existing}
        merged = existing + [i for i in day_items if i.get("id") not in known]
        merged.sort(key=lambda i: i.get("published_at", ""), reverse=True)
        write_json(relative, merged)


def save_briefing(briefing: Dict) -> None:
    payload = dict(briefing)
    payload["generated_at"] = datetime.now(timezone.utc).isoformat()
    payload["date_kst"] = datetime.now(KST).strftime("%Y-%m-%d")
    write_json("briefing.json", payload)


def load_briefing() -> Optional[Dict]:
    payload = read_json("briefing.json", None)
    return payload if isinstance(payload, dict) else None
