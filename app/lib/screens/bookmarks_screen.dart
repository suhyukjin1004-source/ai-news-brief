import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/article_card.dart';
import '../widgets/empty_view.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<AppState>().bookmarked;

    return Scaffold(
      appBar: AppBar(title: Text('북마크 ${bookmarks.isEmpty ? '' : bookmarks.length}')),
      body: bookmarks.isEmpty
          ? const EmptyView(
              icon: Icons.bookmark_outline,
              title: '저장한 기사가 없습니다',
              message: '피드에서 북마크 아이콘을 누르면 여기에 모입니다.\n저장한 기사는 피드에서 밀려나도 남습니다.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: bookmarks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final article = bookmarks[index];
                return Dismissible(
                  key: ValueKey(article.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) =>
                      context.read<AppState>().toggleBookmark(article),
                  child: ArticleCard(
                    article: article,
                    bookmarked: true,
                    onBookmark: () =>
                        context.read<AppState>().toggleBookmark(article),
                  ),
                );
              },
            ),
    );
  }
}
