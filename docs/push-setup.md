# 푸시 알림 붙이기

속보·중요 뉴스가 뜨면 폰으로 알림이 오게 만드는 절차. 처음 한 번만 하면 된다.
Firebase 무료 요금제(Spark)면 충분하고 카드 등록은 필요 없다.

앱은 이 설정 없이도 잘 돌아간다. 설정 화면에 "Firebase 를 아직 연결하지 않아
알림이 오지 않습니다" 라고 나오는 상태가 정상이다.

---

## 1. Firebase 프로젝트 만들기 (브라우저, 약 5분)

1. https://console.firebase.google.com 접속 → **프로젝트 추가**
2. 이름은 아무거나 (예: `ai-news-brief`). Google 애널리틱스는 **끄기** 선택.
3. 프로젝트가 만들어지면 홈에서 **Android 아이콘** 클릭
4. **Android 패키지 이름**에 정확히 아래 값을 입력:

   ```
   com.suhyukjin.ai_news
   ```

5. **google-services.json 다운로드** → 받은 파일을 이 경로에 둔다:

   ```
   app/android/app/google-services.json
   ```

   > 이 파일은 `.gitignore` 에 들어 있어 저장소에 올라가지 않는다. 그대로 두면 된다.

6. 나머지 "SDK 추가" 단계는 **건너뛰기**. 그건 아래 2번에서 자동으로 처리된다.

## 2. 서비스 계정 키 만들기 (수집기가 알림을 보낼 때 쓴다)

1. Firebase 콘솔 → 좌측 상단 **톱니바퀴 → 프로젝트 설정 → 서비스 계정** 탭
2. **새 비공개 키 생성** → JSON 파일이 다운로드된다
3. GitHub 저장소 → **Settings → Secrets and variables → Actions → New repository secret**
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Secret: 받은 **JSON 파일의 내용 전체**를 복사해 붙여넣기 (`{` 부터 `}` 까지)

> 이 JSON 은 비밀번호와 같다. 저장소 파일로 커밋하지 말 것.
> Secrets 에 넣으면 GitHub 가 암호화해 보관하고 로그에도 가려서 출력된다.

## 3. 앱에 Firebase 연결하기

이 단계부터는 Claude 에게 "푸시 설정 3단계 해줘" 라고 하면 된다. 하는 일은:

```bash
cd app
flutter pub add firebase_core firebase_messaging flutter_local_notifications
```

그리고 `app/lib/services/push_service.dart` 의 내용을 실제 구현으로 교체한다.
화면 코드는 손대지 않는다 — `PushService` 의 함수 이름과 반환값은 그대로 두고
속을 채우기만 하면 되도록 만들어 두었다.

바꿀 것:

- `isConfigured` → `true`
- `initialize()` → Firebase 초기화, 안드로이드 13+ 알림 권한 요청,
  `ai_news_alerts` 알림 채널 생성, 저장된 설정이 켜져 있으면 토픽 구독
- `setEnabled()` → `subscribeToTopic('alerts')` / `unsubscribeFromTopic('alerts')`,
  권한이 거부되면 `false` 를 돌려준다

## 4. 확인

1. `flutter run` 으로 앱을 다시 설치 → 설정 화면의 알림 스위치가 켜지는지 확인
2. Firebase 콘솔 → **Messaging → 첫 캠페인 만들기 → Firebase 알림 메시지**
   → 타겟을 **주제(topic)** `alerts` 로 지정하고 테스트 발송
3. 폰에 알림이 뜨면 성공. 이후로는 수집기가 속보·중요 기사를 찾을 때마다 자동으로 보낸다.

---

## 알림이 안 올 때

| 증상 | 확인할 것 |
|---|---|
| 앱 설정 스위치가 회색으로 잠김 | `google-services.json` 이 `app/android/app/` 에 있는지 |
| 콘솔 테스트는 오는데 수집기 알림은 안 옴 | Actions 로그의 `[푸시]` 줄. `자격 증명 없음` 이면 Secret 이름 확인 |
| 아무것도 안 옴 | 안드로이드 설정 → 앱 → AI 뉴스 → 알림 권한이 켜져 있는지 |
| 너무 자주 옴 | `collector/notify.py` 의 `MAX_PUSH_PER_RUN` 을 줄이거나 `PUSH_CATEGORIES` 에서 `중요` 를 빼기 |
