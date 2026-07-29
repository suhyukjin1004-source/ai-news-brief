"""속보·중요 기사가 생기면 FCM 토픽으로 푸시를 보낸다.

FIREBASE_SERVICE_ACCOUNT 환경변수(서비스 계정 JSON 원문)가 없으면 조용히 건너뛴다.
그래서 푸시 설정 전에도 수집기는 그대로 돌아간다.
"""

import json
import os
from typing import Dict, List

import requests

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
TOPIC = os.environ.get("FCM_TOPIC", "alerts")
PUSH_CATEGORIES = ("속보", "중요")
MAX_PUSH_PER_RUN = 3


def _access_token(service_account: Dict) -> str:
    from google.auth.transport.requests import Request
    from google.oauth2 import service_account as sa

    credentials = sa.Credentials.from_service_account_info(
        service_account, scopes=[FCM_SCOPE]
    )
    credentials.refresh(Request())
    return credentials.token


def _send_one(project_id: str, token: str, article: Dict) -> None:
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    payload = {
        "message": {
            "topic": TOPIC,
            "notification": {
                "title": f"[{article['category']}] {article['title_ko']}",
                "body": article["summary_ko"][:180],
            },
            "data": {
                "id": article["id"],
                "url": article["url"],
                "category": article["category"],
            },
            "android": {
                "priority": "high",
                "notification": {"channel_id": "ai_news_alerts"},
            },
        }
    }
    response = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json; UTF-8",
        },
        json=payload,
        timeout=30,
    )
    response.raise_for_status()


def push_alerts(new_articles: List[Dict], log=print) -> int:
    raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
    if not raw:
        log("  [푸시] 자격 증명 없음 — 건너뜀")
        return 0

    alerts = [a for a in new_articles if a.get("category") in PUSH_CATEGORIES]
    if not alerts:
        log("  [푸시] 보낼 속보/중요 기사 없음")
        return 0

    # 속보를 중요보다 먼저, 그 안에서는 최신순. 한 번에 너무 많이 울리지 않게 제한.
    alerts.sort(
        key=lambda a: (a["category"] != "속보", a.get("published_at", "")),
        reverse=False,
    )
    alerts = alerts[:MAX_PUSH_PER_RUN]

    try:
        service_account = json.loads(raw)
        project_id = service_account["project_id"]
        token = _access_token(service_account)
    except Exception as exc:  # noqa: BLE001 - 푸시 실패로 수집을 막지 않는다
        log(f"  [푸시 실패] 자격 증명 오류: {type(exc).__name__}: {exc}")
        return 0

    sent = 0
    for article in alerts:
        try:
            _send_one(project_id, token, article)
            sent += 1
        except Exception as exc:  # noqa: BLE001
            log(f"  [푸시 실패] {article['id']}: {type(exc).__name__}: {exc}")
    log(f"  [푸시] {sent}건 발송")
    return sent
