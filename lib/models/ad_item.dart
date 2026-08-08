import 'package:flutter/painting.dart';

class AdItem {
  final String advertiser;
  final String tagline;
  final String cta;
  final String category;
  final String icon;
  final Color color;
  final String link;

  AdItem({
    required this.advertiser,
    required this.tagline,
    required this.cta,
    required this.category,
    required this.icon,
    required this.color,
    required this.link,
  });

  factory AdItem.fromMap(Map<String, dynamic> json) => AdItem(
        advertiser: json['advertiser']?.toString() ?? 'Sponsor',
        tagline: json['tagline']?.toString() ?? '',
        cta: json['cta']?.toString() ?? 'Learn more',
        category: json['category']?.toString() ?? 'General Business',
        icon: json['icon']?.toString() ?? '🎯',
        color: _parseHex(json['color_hex']?.toString()),
        link: json['link']?.toString() ?? '',
      );

  static Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF4F46E5);
    var cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? const Color(0xFF4F46E5) : Color(value);
  }
}
