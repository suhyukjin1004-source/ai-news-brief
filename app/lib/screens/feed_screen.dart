import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/empty_view.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  String _updatedLabel(DateTime? updatedAt) {
    if (updatedAt == null) return '갱신 정보 없음';
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inMinutes < 1) return '방금 갱신';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전 갱신';
    if (diff.inHours < 24) return '${diff.inHours}시간 전 갱신';
    return '${diff.inDays}일 전 갱신';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final articles = state.visibleArticles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 뉴스'),
        actions: [
          Center(
            child: Text(
              _updatedLabel(state.updatedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(state.availableTags.isEmpty ? 46 : 92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CategoryBar(state: state),
              if (state.availableTags.isNotEmpty) _TagBar(state: state),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(force: true),
        child: _buildBody(context, state, articles),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppState state, List<Article> articles) {
    if (state.loading && articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && articles.isEmpty) {
      return EmptyView(
        icon: Icons.cloud_off,
        title: '뉴스를 불러오지 못했습니다',
        message: state.error!,
        action: FilledButton.tonal(
          onPressed: () => context.read<AppState>().refresh(force: true),
          child: const Text('다시 시도'),
        ),
      );
    }
    if (articles.isEmpty) {
      final filtered = state.category != null || state.selectedTags.isNotEmpty;
      return EmptyView(
        icon: filtered ? Icons.filter_alt_off : Icons.inbox_outlined,
        title: filtered ? '조건에 맞는 뉴스가 없습니다' : '아직 수집된 뉴스가 없습니다',
        message: filtered
            ? '필터를 풀면 다른 뉴스를 볼 수 있습니다.'
            : '수집기가 처음 도는 데 최대 한 시간이 걸립니다.',
        action: filtered
            ? TextButton(
                onPressed: () {
                  final s = context.read<AppState>();
                  s.setCategory(null);
                  s.clearTags();
                },
                child: const Text('필터 전체 해제'),
              )
            : null,
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: articles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final article = articles[index];
        return ArticleCard(
          article: article,
          bookmarked: state.isBookmarked(article.id),
          onBookmark: () => context.read<AppState>().toggleBookmark(article),
          onTagTap: (tag) => context.read<AppState>().toggleTag(tag),
        );
      },
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final AppState state;
  const _CategoryBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final entries = <String?>[null, ...AppConfig.categories];
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final value = entries[index];
          final count = state.countFor(value);
          return ChoiceChip(
            selected: state.category == value,
            onSelected: (_) => context.read<AppState>().setCategory(value),
            showCheckmark: false,
            label: Text('${value ?? '전체'} $count'),
          );
        },
      ),
    );
  }
}

class _TagBar extends StatelessWidget {
  final AppState state;
  const _TagBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final tags = state.availableTags;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: tags.length + (state.selectedTags.isEmpty ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (state.selectedTags.isNotEmpty && index == 0) {
            return ActionChip(
              avatar: const Icon(Icons.close, size: 16),
              label: const Text('해제'),
              onPressed: () => context.read<AppState>().clearTags(),
            );
          }
          final tag = tags[index - (state.selectedTags.isEmpty ? 0 : 1)];
          return FilterChip(
            selected: state.selectedTags.contains(tag),
            onSelected: (_) => context.read<AppState>().toggleTag(tag),
            showCheckmark: false,
            label: Text('#$tag'),
          );
        },
      ),
    );
  }
}
