class NewsItem {
  final String title;
  final String source;
  final String snippet;
  final DateTime publishedAt;
  final String url;

  NewsItem({
    required this.title,
    required this.source,
    required this.snippet,
    required this.publishedAt,
    required this.url,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        title: json['title']?.toString() ?? '',
        source: json['source']?.toString() ?? 'News',
        snippet: json['snippet']?.toString() ?? '',
        publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? '')
                ?.toLocal() ??
            DateTime.now(),
        url: json['url']?.toString() ?? '',
      );
}
