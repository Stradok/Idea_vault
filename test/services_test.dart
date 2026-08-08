import 'package:flutter_test/flutter_test.dart';

import 'package:idea_vault/models/ad_item.dart';
import 'package:idea_vault/models/news_item.dart';
import 'package:idea_vault/models/research.dart';

void main() {
  test('ResearchReport parses a full report', () {
    final report = ResearchReport.fromJson({
      'summary': 'A delivery app for local shops',
      'problem': 'Local shops lack same-day delivery.',
      'solution': 'A rider network for small merchants.',
      'targetMarket': 'Small shops in tier-2 cities.',
      'competitors': ['Swiggy', 'Rapido'],
      'costRange': '\$50k - \$150k',
      'costBreakdown': 'App dev, riders, ops.',
      'potentialScore': 82,
      'keyInsights': ['Thin margins', 'High retention'],
      'sources': ['https://example.com/1'],
    });

    expect(report.summary, contains('delivery'));
    expect(report.problem, isNotEmpty);
    expect(report.solution, isNotEmpty);
    expect(report.targetMarket, isNotEmpty);
    expect(report.competitors, hasLength(2));
    expect(report.costRange, isNotEmpty);
    expect(report.costBreakdown, isNotEmpty);
    expect(report.potentialScore, inInclusiveRange(0, 100));
    expect(report.keyInsights, hasLength(2));
    expect(report.sources, hasLength(1));
  });

  test('ResearchReport tolerates missing fields', () {
    final report = ResearchReport.fromJson(const {});
    expect(report.summary, isEmpty);
    expect(report.competitors, isEmpty);
    expect(report.potentialScore, 0);
  });

  test('NewsItem parses a feed article', () {
    final item = NewsItem.fromJson({
      'title': 'Riders unionize',
      'source': 'TechCrunch',
      'snippet': 'Delivery platforms respond...',
      'publishedAt': '2026-08-08T10:00:00Z',
      'url': 'https://techcrunch.com/riders',
    });

    expect(item.title, isNotEmpty);
    expect(item.source, isNotEmpty);
    expect(item.url, isNotEmpty);
  });

  test('NewsItem tolerates missing url', () {
    final item = NewsItem.fromJson({'title': 'No link'});
    expect(item.url, isEmpty);
    expect(item.source, isNotEmpty);
  });

  test('AdItem parses a sponsor row', () {
    final ad = AdItem.fromMap({
      'advertiser': 'Stripe',
      'tagline': 'Payments for startups',
      'cta': 'Start now',
      'category': 'General Business',
      'icon': '💳',
      'color_hex': '#635BFF',
      'link': 'https://stripe.com',
    });

    expect(ad.advertiser, isNotEmpty);
    expect(ad.cta, isNotEmpty);
    expect(ad.link, isNotEmpty);
  });

  test('AdItem falls back on bad color', () {
    final ad = AdItem.fromMap({'advertiser': 'X', 'color_hex': 'nope'});
    expect(ad.link, isEmpty);
    expect(ad.color, isNotNull);
  });
}
