import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/empty_view.dart';

/// 오늘의 브리핑 + 오늘 올라온 '중요/속보' 기사 모음.
class BriefingScreen extends StatelessWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final briefing = state.briefing;
    final theme = Theme.of(context);

    final today = DateTime.now();
    final highlights = state.articles
        .where((a) =>
            (a.category == '속보' || a.category == '중요') &&
            a.publishedAt.isAfter(today.subtract(const Duration(hours: 24))))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 브리핑')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(force: true),
        child: briefing == null && highlights.isEmpty
            ? const EmptyView(
                icon: Icons.wb_sunny_outlined,
                title: '아직 브리핑이 없습니다',
                message: '브리핑은 매일 아침 7시 이후 첫 수집 때 만들어집니다.',
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  if (briefing != null) _BriefingCard(briefing: briefing),
                  if (highlights.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
                      child: Text(
                        '지난 24시간 주요 소식 ${highlights.length}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final article in highlights) ...[
                      ArticleCard(
                        article: article,
                        bookmarked: state.isBookmarked(article.id),
                        onBookmark: () =>
                            context.read<AppState>().toggleBookmark(article),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _BriefingCard extends StatelessWidget {
  final Briefing briefing;
  const _BriefingCard({required this.briefing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('☀️', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  briefing.dateKst,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              briefing.headline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            for (final point in briefing.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: 9),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
