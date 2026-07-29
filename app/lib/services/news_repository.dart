import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/article.dart';

/// 서버(GitHub)에서 뉴스를 가져오고, 마지막 결과를 폰에 캐시한다.
///
/// 캐시가 있으면 앱을 켜자마자 바로 보여주고, 네트워크는 그 뒤에 갱신한다.
/// 비행기 모드에서도 마지막으로 받은 뉴스는 읽을 수 있다.
class NewsRepository {
  static const _cacheArticles = 'cache_articles';
  static const _cacheBriefing = 'cache_briefing';
  static const _cacheUpdatedAt = 'cache_updated_at';

  final http.Client _client;

  NewsRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<NewsSnapshot> loadCached() async {
    final prefs = await SharedPreferences.getInstance();

    final articlesRaw = prefs.getString(_cacheArticles);
    final articles = articlesRaw == null
        ? <Article>[]
        : (jsonDecode(articlesRaw) as List)
            .map((e) => Article.fromJson(e as Map<String, dynamic>))
            .toList();

    final briefingRaw = prefs.getString(_cacheBriefing);
    final briefing = briefingRaw == null
        ? null
        : Briefing.fromJson(jsonDecode(briefingRaw) as Map<String, dynamic>);

    return NewsSnapshot(
      articles: articles,
      briefing: briefing,
      updatedAt: DateTime.tryParse(prefs.getString(_cacheUpdatedAt) ?? ''),
      fromCache: true,
    );
  }

  Future<NewsSnapshot> fetch() async {
    // 브리핑은 아직 파일이 없을 수 있으니 실패해도 넘어간다.
    final results = await Future.wait([
      _getJson(AppConfig.latestUrl),
      _getJson(AppConfig.briefingUrl).catchError((_) => null),
    ]);

    final latest = results[0];
    if (latest == null) {
      throw Exception('뉴스 목록을 가져오지 못했습니다.');
    }

    final articles = (latest['items'] as List? ?? [])
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .toList();
    final briefingJson = results[1];
    final briefing = briefingJson == null ? null : Briefing.fromJson(briefingJson);
    final updatedAt =
        DateTime.tryParse(latest['updated_at'] as String? ?? '')?.toLocal();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheArticles,
      jsonEncode(articles.map((a) => a.toJson()).toList()),
    );
    if (briefing != null) {
      await prefs.setString(_cacheBriefing, jsonEncode(briefing.toJson()));
    }
    if (updatedAt != null) {
      await prefs.setString(_cacheUpdatedAt, updatedAt.toIso8601String());
    }

    return NewsSnapshot(
      articles: articles,
      briefing: briefing,
      updatedAt: updatedAt,
      fromCache: false,
    );
  }

  Future<Map<String, dynamic>?> _getJson(String url) async {
    // raw.githubusercontent.com 은 CDN 캐시가 있어 쿼리로 흔들어준다.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final response = await _client
        .get(Uri.parse('$url?t=$stamp'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}

class NewsSnapshot {
  final List<Article> articles;
  final Briefing? briefing;
  final DateTime? updatedAt;
  final bool fromCache;

  const NewsSnapshot({
    required this.articles,
    required this.briefing,
    required this.updatedAt,
    required this.fromCache,
  });

  bool get isEmpty => articles.isEmpty;
}
