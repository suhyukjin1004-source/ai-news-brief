import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../services/push_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushEnabled = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PushService.instance.isEnabled().then((value) {
      if (mounted) setState(() => _pushEnabled = value);
    });
  }

  Future<void> _togglePush(bool value) async {
    setState(() => _busy = true);
    final applied = await PushService.instance.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _pushEnabled = applied;
      _busy = false;
    });
    if (value && !applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림 권한이 없습니다. 안드로이드 설정에서 이 앱의 알림을 켜주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const _SectionTitle('알림'),
          SwitchListTile(
            title: const Text('속보 · 중요 뉴스 알림'),
            subtitle: Text(
              PushService.instance.isConfigured
                  ? '중요도가 높은 뉴스만 골라서 보냅니다. 한 번에 최대 3건.'
                  : 'Firebase 를 아직 연결하지 않아 알림이 오지 않습니다.\n'
                      '연결 방법은 저장소의 docs/push-setup.md 를 보세요.',
            ),
            value: _pushEnabled && PushService.instance.isConfigured,
            onChanged:
                (_busy || !PushService.instance.isConfigured) ? null : _togglePush,
          ),
          const Divider(),

          const _SectionTitle('데이터'),
          ListTile(
            title: const Text('지금 새로고침'),
            subtitle: Text(
              state.updatedAt == null
                  ? '아직 받아온 데이터가 없습니다'
                  : '마지막 갱신 ${_formatTime(state.updatedAt!)}',
            ),
            trailing: const Icon(Icons.refresh),
            onTap: () => context.read<AppState>().refresh(force: true),
          ),
          ListTile(
            title: const Text('저장된 기사'),
            subtitle: Text('피드 ${state.articles.length}건 · 북마크 ${state.bookmarked.length}건'),
          ),
          const Divider(),

          const _SectionTitle('정보'),
          ListTile(
            title: const Text('뉴스 소스 · 수집기 코드'),
            subtitle: const Text(AppConfig.repo),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('https://github.com/${AppConfig.repo}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const ListTile(
            title: Text('수집 주기'),
            subtitle: Text('매시간 (GitHub 사정으로 몇 분 늦을 수 있습니다)'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '${time.month}/${time.day} $h:$m';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
