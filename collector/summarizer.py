"""기사를 한국어로 요약하고 분류하는 층.

이 파일만 갈아끼우면 요약 엔진을 바꿀 수 있다.
환경변수:
  LLM_PROVIDER   gemini (기본) 또는 claude
  GEMINI_API_KEY / ANTHROPIC_API_KEY
  LLM_MODEL      비워두면 각 제공자의 기본 모델을 쓴다
"""

import json
import os
import re
import time
from typing import Dict, List, Optional

import requests

CATEGORIES = ["속보", "중요", "참고", "팁"]
BATCH_SIZE = 15
REQUEST_TIMEOUT = 180

# 앞에서부터 시도해서 처음 성공하는 모델을 쓴다. 모델이 사라져도 수집이 멈추지 않게.
GEMINI_MODELS = [
    "gemini-3.5-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-2.5-flash",
    "gemini-2.0-flash",
]
CLAUDE_MODELS = ["claude-haiku-4-5-20251001"]

SYSTEM_PROMPT = """당신은 AI 업계 뉴스를 한국어로 정리하는 편집자입니다.
입력으로 기사 목록이 주어집니다. 각 기사를 판단해 JSON 배열로만 답하세요.

각 원소는 다음 형식입니다:
{
  "i": 입력의 index 정수,
  "relevant": true/false,
  "title_ko": "한국어 제목 (40자 이내, 명사형으로 간결하게)",
  "summary_ko": "한두 문장 요약. 무슨 일이 있었는지 + 왜 중요한지.",
  "category": "속보" | "중요" | "참고" | "팁",
  "tags": ["태그", ...]
}

판단 기준:
- relevant: AI/머신러닝/LLM 업계와 직접 관련되면 true. 일반 IT·정치·연예 등은 false.
  false 인 경우 나머지 필드는 빈 문자열/빈 배열로 두세요.
- category:
  - 속보: 방금 터진 발표·출시·사건. 지금 알아야 하는 것.
  - 중요: 업계 방향을 바꿀 만한 소식. 대형 투자, 규제, 주요 모델 공개.
  - 참고: 알아두면 좋은 배경·분석·연구.
  - 팁: 실무에 바로 쓸 수 있는 도구·기법·튜토리얼.
- tags: 1~3개. 회사명(OpenAI, Anthropic, Google, Meta, NVIDIA), 모델명(GPT, Claude, Gemini),
  주제(AI 에이전트, 오픈소스, 규제, 반도체, 투자, 로보틱스, 코딩) 중에서 고르되
  적절한 게 없으면 새로 만들어도 됩니다. 한국어 또는 고유명사 원문 표기.

원문이 한국어면 title_ko 는 원제를 다듬어 쓰고, 영어면 자연스러운 한국어로 옮기세요.
번역투를 피하고 기술 용어는 통용되는 표기를 쓰세요.
JSON 배열 외의 텍스트는 절대 출력하지 마세요."""

BRIEFING_PROMPT = """당신은 AI 업계 뉴스를 한국어로 정리하는 편집자입니다.
아래는 지난 24시간 동안의 AI 뉴스 목록입니다.
오늘 꼭 알아야 할 흐름을 3~5개의 짧은 문장으로 정리하세요.

JSON 으로만 답하세요:
{"headline": "오늘을 한 문장으로", "points": ["문장1", "문장2", ...]}

개별 기사 나열이 아니라 흐름을 묶어서 쓰세요.
JSON 외의 텍스트는 출력하지 마세요."""


class SummarizerError(RuntimeError):
    pass


def _extract_json(text: str):
    """모델이 앞뒤에 군더더기를 붙였을 때를 대비해 JSON 부분만 꺼낸다."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    for opener, closer in (("[", "]"), ("{", "}")):
        start = text.find(opener)
        end = text.rfind(closer)
        if start != -1 and end > start:
            try:
                return json.loads(text[start : end + 1])
            except json.JSONDecodeError:
                continue
    raise SummarizerError(f"JSON 파싱 실패: {text[:300]}")


def _build_input(articles: List[Dict]) -> str:
    lines = []
    for index, article in enumerate(articles):
        body = (article.get("raw_summary") or "")[:600]
        lines.append(
            json.dumps(
                {
                    "i": index,
                    "source": article["source"],
                    "title": article["title"],
                    "body": body,
                },
                ensure_ascii=False,
            )
        )
    return "\n".join(lines)


class GeminiSummarizer:
    name = "gemini"

    def __init__(self, api_key: str, model: Optional[str] = None):
        self.api_key = api_key
        self.models = [model] if model else list(GEMINI_MODELS)
        self.active_model: Optional[str] = None

    def _call(self, system: str, user: str) -> str:
        last_error = None
        candidates = [self.active_model] if self.active_model else self.models
        for candidate in candidates:
            url = (
                "https://generativelanguage.googleapis.com/v1beta/models/"
                f"{candidate}:generateContent"
            )
            payload = {
                "systemInstruction": {"parts": [{"text": system}]},
                "contents": [{"role": "user", "parts": [{"text": user}]}],
                "generationConfig": {
                    "temperature": 0.2,
                    "responseMimeType": "application/json",
                    "maxOutputTokens": 8192,
                },
            }
            try:
                response = requests.post(
                    url,
                    params={"key": self.api_key},
                    json=payload,
                    timeout=REQUEST_TIMEOUT,
                )
            except requests.RequestException as exc:
                last_error = exc
                continue

            if response.status_code == 429:
                raise SummarizerError("Gemini 무료 한도 초과(429). 다음 실행에서 재시도합니다.")
            if response.status_code >= 400:
                last_error = SummarizerError(
                    f"{candidate}: HTTP {response.status_code} {response.text[:200]}"
                )
                continue

            self.active_model = candidate
            data = response.json()
            try:
                parts = data["candidates"][0]["content"]["parts"]
                return "".join(p.get("text", "") for p in parts)
            except (KeyError, IndexError) as exc:
                raise SummarizerError(f"예상 밖 응답 형식: {json.dumps(data)[:300]}") from exc

        raise SummarizerError(f"모든 Gemini 모델 호출 실패: {last_error}")


class ClaudeSummarizer:
    name = "claude"

    def __init__(self, api_key: str, model: Optional[str] = None):
        self.api_key = api_key
        self.models = [model] if model else list(CLAUDE_MODELS)
        self.active_model: Optional[str] = None

    def _call(self, system: str, user: str) -> str:
        last_error = None
        candidates = [self.active_model] if self.active_model else self.models
        for candidate in candidates:
            try:
                response = requests.post(
                    "https://api.anthropic.com/v1/messages",
                    headers={
                        "x-api-key": self.api_key,
                        "anthropic-version": "2023-06-01",
                        "content-type": "application/json",
                    },
                    json={
                        "model": candidate,
                        "max_tokens": 8192,
                        "temperature": 0.2,
                        "system": system,
                        "messages": [{"role": "user", "content": user}],
                    },
                    timeout=REQUEST_TIMEOUT,
                )
            except requests.RequestException as exc:
                last_error = exc
                continue

            if response.status_code >= 400:
                last_error = SummarizerError(
                    f"{candidate}: HTTP {response.status_code} {response.text[:200]}"
                )
                continue

            self.active_model = candidate
            data = response.json()
            return "".join(
                block.get("text", "")
                for block in data.get("content", [])
                if block.get("type") == "text"
            )

        raise SummarizerError(f"모든 Claude 모델 호출 실패: {last_error}")


def _enrich(articles: List[Dict], results, log) -> List[Dict]:
    """모델 응답을 기사에 합친다. AI 무관 기사와 응답 누락 기사는 버린다."""
    by_index = {}
    if isinstance(results, dict):
        results = results.get("items") or results.get("results") or []
    for item in results or []:
        if not isinstance(item, dict):
            continue
        try:
            by_index[int(item.get("i"))] = item
        except (TypeError, ValueError):
            continue

    enriched = []
    for index, article in enumerate(articles):
        result = by_index.get(index)
        if not result or not result.get("relevant"):
            continue
        category = result.get("category")
        if category not in CATEGORIES:
            category = "참고"
        tags = [str(t).strip() for t in (result.get("tags") or []) if str(t).strip()]
        title_ko = (result.get("title_ko") or "").strip() or article["title"]
        summary_ko = (result.get("summary_ko") or "").strip()
        if not summary_ko:
            continue
        merged = dict(article)
        merged.pop("raw_summary", None)
        merged.pop("lang", None)
        merged.update(
            {
                "title_ko": title_ko,
                "summary_ko": summary_ko,
                "category": category,
                "tags": tags[:3],
            }
        )
        enriched.append(merged)

    log(f"  [요약] {len(articles)}건 중 AI 관련 {len(enriched)}건 채택")
    return enriched


class Summarizer:
    """제공자에 상관없이 같은 방식으로 쓰는 겉면."""

    def __init__(self, backend):
        self.backend = backend

    @property
    def label(self) -> str:
        return f"{self.backend.name}/{self.backend.active_model or '미정'}"

    def summarize(self, articles: List[Dict], log=print) -> List[Dict]:
        enriched: List[Dict] = []
        for start in range(0, len(articles), BATCH_SIZE):
            chunk = articles[start : start + BATCH_SIZE]
            try:
                raw = self.backend._call(SYSTEM_PROMPT, _build_input(chunk))
                results = _extract_json(raw)
            except SummarizerError as exc:
                log(f"  [요약 실패] {start}~{start + len(chunk)}: {exc}")
                continue
            enriched.extend(_enrich(chunk, results, log))
            if start + BATCH_SIZE < len(articles):
                time.sleep(2)
        return enriched

    def briefing(self, articles: List[Dict], log=print) -> Optional[Dict]:
        if not articles:
            return None
        lines = [
            "- [{}] {} :: {}".format(
                a.get("category", "참고"),
                a.get("title_ko") or a.get("title", ""),
                a.get("summary_ko", ""),
            )
            for a in articles[:60]
        ]
        try:
            raw = self.backend._call(BRIEFING_PROMPT, "\n".join(lines))
            data = _extract_json(raw)
        except SummarizerError as exc:
            log(f"  [브리핑 실패] {exc}")
            return None
        if not isinstance(data, dict) or not data.get("points"):
            return None
        return {
            "headline": str(data.get("headline", "")).strip(),
            "points": [str(p).strip() for p in data["points"] if str(p).strip()][:5],
        }


def get_summarizer() -> Summarizer:
    provider = os.environ.get("LLM_PROVIDER", "gemini").strip().lower()
    model = os.environ.get("LLM_MODEL", "").strip() or None

    if provider == "claude":
        key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
        if not key:
            raise SummarizerError("ANTHROPIC_API_KEY 가 설정되지 않았습니다.")
        return Summarizer(ClaudeSummarizer(key, model))

    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        raise SummarizerError("GEMINI_API_KEY 가 설정되지 않았습니다.")
    return Summarizer(GeminiSummarizer(key, model))
