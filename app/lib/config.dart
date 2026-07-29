/// 앱 전역 설정. 바꿀 일이 있으면 대부분 이 파일만 고치면 된다.
class AppConfig {
  /// 수집기가 결과를 커밋하는 GitHub 저장소.
  static const String repo = 'suhyukjin1004-source/ai-news-brief';
  static const String branch = 'main';

  /// 평소에는 GitHub 에서 읽는다.
  /// 개발 중 로컬 서버로 바꿔보고 싶으면:
  ///   flutter run --dart-define=DATA_BASE=http://10.0.2.2:8000
  /// (10.0.2.2 는 안드로이드 에뮬레이터에서 본 맥의 주소다.)
  static const String _base = String.fromEnvironment(
    'DATA_BASE',
    defaultValue: 'https://raw.githubusercontent.com/$repo/$branch/data',
  );

  /// 최근 기사 목록.
  static String get latestUrl => '$_base/latest.json';

  /// 오늘의 브리핑.
  static String get briefingUrl => '$_base/briefing.json';

  /// 카테고리. 순서가 곧 화면의 탭 순서다.
  static const List<String> categories = ['속보', '중요', '참고', '팁'];

  /// 새로고침을 눌러도 이 시간 안에는 네트워크를 다시 치지 않는다.
  static const Duration refreshCooldown = Duration(seconds: 20);

  /// FCM 토픽. 수집기의 FCM_TOPIC 과 같아야 알림이 온다.
  static const String pushTopic = 'alerts';
}
