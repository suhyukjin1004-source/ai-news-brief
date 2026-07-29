/// 기사 한 건. 수집기가 만든 JSON 과 1:1로 대응한다.
class Article {
  final String id;
  final String url;
  final String source;
  final String title;
  final String titleKo;
  final String summaryKo;
  final String category;
  final List<String> tags;
  final DateTime publishedAt;

  const Article({
    required this.id,
    required this.url,
    required this.source,
    required this.title,
    required this.titleKo,
    required this.summaryKo,
    required this.category,
    required this.tags,
    required this.publishedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      source: json['source'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleKo: json['title_ko'] as String? ?? json['title'] as String? ?? '',
      summaryKo: json['summary_ko'] as String? ?? '',
      category: json['category'] as String? ?? '참고',
      tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? const [],
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'source': source,
        'title': title,
        'title_ko': titleKo,
        'summary_ko': summaryKo,
        'category': category,
        'tags': tags,
        'published_at': publishedAt.toUtc().toIso8601String(),
      };

  /// "12분 전" 같은 상대 시각.
  String get relativeTime {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${publishedAt.month}월 ${publishedAt.day}일';
  }
}

/// 오늘의 브리핑.
class Briefing {
  final String headline;
  final List<String> points;
  final String dateKst;

  const Briefing({
    required this.headline,
    required this.points,
    required this.dateKst,
  });

  factory Briefing.fromJson(Map<String, dynamic> json) => Briefing(
        headline: json['headline'] as String? ?? '',
        points:
            (json['points'] as List?)?.map((p) => p.toString()).toList() ?? const [],
        dateKst: json['date_kst'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'points': points,
        'date_kst': dateKst,
      };
}
