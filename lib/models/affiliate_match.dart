class AffiliateMatch {
  final String name;
  final String description;
  final String url;
  final String category;

  AffiliateMatch({
    required this.name,
    required this.description,
    required this.url,
    required this.category,
  });

  factory AffiliateMatch.fromJson(Map<String, dynamic> json) => AffiliateMatch(
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'url': url,
        'category': category,
      };
}
