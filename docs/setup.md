# 처음 시작하기

지금 상태에서 **딱 하나** 남은 것은 Gemini API 키다. 그것만 넣으면
매시간 뉴스가 자동으로 쌓이고 앱에 뜬다.

---

## 1. Gemini API 키 발급 (약 2분, 무료)

1. https://aistudio.google.com/apikey 접속 → 구글 계정으로 로그인
2. **Create API key** 클릭
3. 프로젝트를 고르라고 하면 아무거나 (없으면 새로 만들기)
4. `AIza...` 로 시작하는 문자열이 나온다. **복사**

> 카드 등록도, 결제 설정도 필요 없다. 무료 한도 안에서만 쓴다.
> 이 앱은 한 시간에 API 를 3~4번 부른다. 무료 한도에 한참 못 미친다.

## 2. GitHub 저장소에 키 등록

1. https://github.com/suhyukjin1004-source/ai-news-brief/settings/secrets/actions 접속
2. **New repository secret** 클릭
3. 입력:
   - **Name**: `GEMINI_API_KEY`  (오타 주의 — 정확히 이 이름이어야 한다)
   - **Secret**: 1번에서 복사한 키
4. **Add secret**

> Secret 은 등록 후 다시 볼 수 없다. GitHub 가 암호화해 보관하고
> Actions 로그에도 `***` 로 가려서 나온다.

## 3. 첫 수집 돌려보기

1. https://github.com/suhyukjin1004-source/ai-news-brief/actions/workflows/collect.yml 접속
2. 우측 **Run workflow** → 옵션은 건드리지 말고 초록 **Run workflow** 버튼
3. 2~3분 기다린다
4. https://github.com/suhyukjin1004-source/ai-news-brief/blob/main/data/latest.json
   에 기사들이 한국어 요약과 함께 들어와 있으면 성공

이후로는 **매시 5분경 자동으로** 돈다. 아무것도 안 해도 된다.

## 4. 앱 설치

`app-release.apk` 파일을 폰으로 옮겨서 설치한다. 옮기는 방법은 아무거나:
카카오톡 나에게 보내기, 구글 드라이브, USB 케이블, 이메일 첨부.

폰에서 APK 를 열면 "출처를 알 수 없는 앱" 경고가 나온다.
**설정 → 허용** 을 눌러주면 설치된다. (내가 만든 앱이라 정상이다.)

앱을 켜면 바로 뉴스가 뜬다.

---

## 문제가 생기면

**앱에 "아직 수집된 뉴스가 없습니다" 라고 나온다**
→ 3번의 첫 수집이 아직 안 돌았거나 실패했다. Actions 탭에서 빨간 X 를 눌러 로그를 본다.

**Actions 로그에 `GEMINI_API_KEY 가 설정되지 않았습니다`**
→ 2번에서 Secret 이름을 정확히 `GEMINI_API_KEY` 로 넣었는지 확인.

**Actions 로그에 `Gemini 무료 한도 초과(429)`**
→ 그 회차만 건너뛴다. 다음 시간에 자동으로 다시 시도하니 그냥 두면 된다.
   계속 그러면 `collector/sources.yaml` 의 `max_new_per_run` 을 줄인다.

**요약이 마음에 안 든다 (너무 길다 / 말투가 어색하다 / 분류가 이상하다)**
→ `collector/summarizer.py` 의 `SYSTEM_PROMPT` 를 고친다. 사람 말로 쓰면 된다.

**뉴스 소스를 바꾸고 싶다**
→ `collector/sources.yaml`. 줄 앞에 `#` 을 붙이면 그 소스만 끌 수 있다.

**푸시 알림을 켜고 싶다**
→ [docs/push-setup.md](push-setup.md)
