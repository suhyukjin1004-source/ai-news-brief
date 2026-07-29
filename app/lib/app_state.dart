import 'package:flutter/foundation.dart';

import 'config.dart';
import 'models/article.dart';
import 'services/bookmark_store.dart';
import 'services/news_repository.dart';

/// 앱 전체가 공유하는 상태. 화면들은 이걸 읽기만 하고,
/// 데이터를 바꾸는 일은 전부 여기 모여 있다.
class AppState extends ChangeNotifier {
  final NewsRepository _repository;
  final BookmarkStore _bookmarks;

  AppState({NewsRepository? repository, BookmarkStore? bookmarks})
      : _repository = repository ?? NewsRepository(),
        _bookmarks = bookmarks ?? BookmarkStore();

  List<Article> _articles = [];
  List<Article> _bookmarked = [];
  Briefing? _briefing;
  DateTime? _updatedAt;
  DateTime? _lastFetchAttempt;

  bool _loading = true;
  String? _error;

  /// null 이면 전체 카테고리.
  String? _category;
  final Set<String> _selectedTags = {};

  List<Article> get articles => _articles;
  List<Article> get bookmarked => _bookmarked;
  Briefing? get briefing => _briefing;
  DateTime? get updatedAt => _updatedAt;
  bool get loading => _loading;
  String? get error => _error;
  String? get category => _category;
  Set<String> get selectedTags => _selectedTags;

  /// 현재 카테고리·태그 필터를 적용한 목록.
  List<Article> get visibleArticles {
    return _articles.where((a) {
      if (_category != null && a.category != _category) return false;
      if (_selectedTags.isEmpty) return true;
      return a.tags.any(_selectedTags.contains);
    }).toList();
  }

  /// 현재 카테고리 안에서 많이 쓰인 태그 순.
  List<String> get availableTags {
    final counts = <String, int>{};
    for (final article in _articles) {
      if (_category != null && article.category != _category) continue;
      for (final tag in article.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final tags = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return tags.take(20).toList();
  }

  int countFor(String? category) {
    if (category == null) return _articles.length;
    return _articles.where((a) => a.category == category).length;
  }

  bool isBookmarked(String id) => _bookmarked.any((a) => a.id == id);

  /// 앱 시작 시 한 번. 캐시를 먼저 보여주고 네트워크로 갱신한다.
  Future<void> initialize() async {
    final cached = await _repository.loadCached();
    _articles = cached.articles;
    _briefing = cached.briefing;
    _updatedAt = cached.updatedAt;
    _bookmarked = await _bookmarks.load();
    _loading = _articles.isEmpty;
    notifyListeners();

    await refresh(force: true);
  }

  Future<void> refresh({bool force = false}) async {
    if (!force && _lastFetchAttempt != null) {
      final since = DateTime.now().difference(_lastFetchAttempt!);
      if (since < AppConfig.refreshCooldown) return;
    }
    _lastFetchAttempt = DateTime.now();

    try {
      final snapshot = await _repository.fetch();
      _articles = snapshot.articles;
      _briefing = snapshot.briefing ?? _briefing;
      _updatedAt = snapshot.updatedAt;
      _error = null;
    } catch (e) {
      // 캐시가 있으면 조용히 실패한다. 없으면 화면에 알린다.
      _error = _articles.isEmpty ? '뉴스를 불러오지 못했습니다. 연결을 확인해 주세요.' : null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setCategory(String? category) {
    if (_category == category) return;
    _category = category;
    // 카테고리를 바꾸면 그 안에 없는 태그가 남아 결과가 0건이 되는 걸 막는다.
    _selectedTags.removeWhere((tag) => !availableTags.contains(tag));
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (!_selectedTags.remove(tag)) _selectedTags.add(tag);
    notifyListeners();
  }

  void clearTags() {
    if (_selectedTags.isEmpty) return;
    _selectedTags.clear();
    notifyListeners();
  }

  Future<void> toggleBookmark(Article article) async {
    final index = _bookmarked.indexWhere((a) => a.id == article.id);
    if (index >= 0) {
      _bookmarked.removeAt(index);
    } else {
      _bookmarked.insert(0, article);
    }
    notifyListeners();
    await _bookmarks.save(_bookmarked);
  }
}
