# AI 뉴스 브리핑

전 세계 AI 뉴스를 **매시간** 모아 한국어 한 줄 요약으로 보여주는 개인용 Android 앱.

```
GitHub Actions (매시간)          →  data/*.json  →  Flutter 앱 (Android)
 RSS 수집 → 중복 제거 → LLM 요약      (이 저장소)      피드 · 필터 · 북마크
                    ↘ 속보/중요면 FCM 푸시 ───────────→ 알림
```

상시 서버가 없다. GitHub Actions 가 매시간 깨어나 뉴스를 모으고, 결과 JSON 을 이 저장소에
커밋한다. 앱은 그 JSON 을 그냥 내려받아 보여준다. 운영비는 0원.

> **처음이라면 → [docs/setup.md](docs/setup.md)** (Gemini API 키 등록 + 앱 설치, 약 10분)
> 푸시 알림을 켜려면 → [docs/push-setup.md](docs/push-setup.md)

## 폴더

| 경로 | 내용 |
|---|---|
| `collector/` | 파이썬 수집기. Actions 가 실행한다. |
| `collector/sources.yaml` | **뉴스 소스 목록. 소스를 늘리거나 줄이려면 여기만 고치면 된다.** |
| `data/` | 수집 결과. 앱이 읽는 곳. Actions 가 자동으로 갱신한다. |
| `app/` | Flutter 앱 소스. |

## 데이터 파일

- `data/latest.json` — 최근 기사 200건. 앱의 피드가 이걸 읽는다.
- `data/briefing.json` — 오늘의 브리핑 (매일 아침 KST 07시 이후 첫 실행에서 생성).
- `data/archive/YYYY-MM-DD.json` — 날짜별 보관본.
- `data/seen.json` — 이미 처리한 기사 ID. 중복 방지용 내부 파일.

## 수집기 직접 돌려보기

```bash
python3 -m venv .venv
.venv/bin/pip install -r collector/requirements.txt

# LLM 없이 어떤 기사가 잡히는지만 확인
.venv/bin/python collector/collect.py --dry-run

# 실제 요약까지 (API 키 필요)
GEMINI_API_KEY=... .venv/bin/python collector/collect.py --no-push
```

주요 옵션: `--dry-run` (수집만), `--no-push` (푸시 안 보냄), `--briefing` (브리핑 강제 생성).

## 앱 빌드하기

```bash
cd app
flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (요즘 폰은 이걸 쓴다)
```

화면을 고치면서 확인할 때는 에뮬레이터나 USB 연결된 폰에 바로 띄운다.

```bash
flutter run
```

아직 GitHub 에 데이터가 없거나 로컬 데이터로 실험하고 싶으면,
샘플을 만들어 로컬 서버로 띄운 뒤 앱이 그쪽을 보게 한다.

```bash
.venv/bin/python collector/make_fixture.py /tmp/fixture
(cd /tmp/fixture && python3 -m http.server 8765) &
adb reverse tcp:8765 tcp:8765
cd app && flutter run --dart-define=DATA_BASE=http://localhost:8765/data
```

## 설정

GitHub 저장소 → Settings → Secrets and variables → Actions

**Secrets** (비밀 값)

| 이름 | 필요 여부 | 내용 |
|---|---|---|
| `GEMINI_API_KEY` | 필수 | https://aistudio.google.com/apikey 에서 발급 (무료) |
| `FIREBASE_SERVICE_ACCOUNT` | 푸시 쓸 때 | Firebase 서비스 계정 JSON **전체 내용** |
| `ANTHROPIC_API_KEY` | 선택 | 요약 엔진을 Claude 로 바꿀 때 |

**Variables** (공개돼도 되는 값)

| 이름 | 기본값 | 내용 |
|---|---|---|
| `LLM_PROVIDER` | `gemini` | `claude` 로 바꾸면 Claude 를 쓴다 |
| `LLM_MODEL` | 자동 | 특정 모델을 고정하고 싶을 때 |

## 자주 하는 수정

**뉴스 소스 추가/삭제** → `collector/sources.yaml` 의 `sources:` 목록을 고친다.
줄 맨 앞에 `#` 을 붙이면 잠시 끌 수 있다.

**요약 말투나 분류 기준 변경** → `collector/summarizer.py` 의 `SYSTEM_PROMPT`.

**수집 주기 변경** → `.github/workflows/collect.yml` 의 `cron`.
(GitHub 사정으로 정시보다 몇 분 늦게 도는 건 정상이다.)

**한 번에 처리할 기사 수 / 보관 기간** → `collector/sources.yaml` 의 `settings:`.
