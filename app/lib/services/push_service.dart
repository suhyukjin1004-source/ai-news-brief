import 'package:shared_preferences/shared_preferences.dart';

/// 푸시 알림 담당.
///
/// Firebase 를 붙이기 전에도 앱이 그대로 돌아가도록 만들어 두었다.
/// [isConfigured] 가 false 면 설정값만 기억하고 실제 알림은 오지 않는다.
///
/// Firebase 를 붙이는 방법은 저장소의 docs/push-setup.md 를 보라.
/// 그때 고칠 곳은 이 파일 하나뿐이다 — 화면 코드는 건드리지 않는다.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _prefKey = 'push_enabled';

  /// Firebase 연동을 마치면 true 가 된다.
  bool get isConfigured => false;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? true;
  }

  /// 요청한 값을 적용하고, **실제로 적용된 값**을 돌려준다.
  /// 권한이 거부되면 요청이 true 여도 false 가 돌아온다.
  Future<bool> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (!isConfigured) return value;

    // Firebase 연동 후 여기에서 토픽 구독/해제를 처리한다.
    return value;
  }

  /// 앱 시작 시 호출. Firebase 초기화와 토픽 구독을 맡는다.
  Future<void> initialize() async {
    if (!isConfigured) return;
  }
}
