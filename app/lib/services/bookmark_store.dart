import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';

/// 북마크는 폰에만 저장한다. 기사 전체를 저장하므로
/// latest.json 에서 밀려난 오래된 기사도 계속 읽을 수 있다.
class BookmarkStore {
  static const _key = 'bookmarks';

  Future<List<Article>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Article.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> save(List<Article> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(bookmarks.map((a) => a.toJson()).toList()),
    );
  }
}
