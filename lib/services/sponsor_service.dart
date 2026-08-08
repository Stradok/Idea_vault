import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ad_item.dart';
import 'idea_category.dart';

abstract class SponsorService {
  Future<List<AdItem>> adsFor(IdeaCategory category);
}

class SupabaseSponsorService implements SponsorService {
  final SupabaseClient _client;

  SupabaseSponsorService(this._client);

  @override
  Future<List<AdItem>> adsFor(IdeaCategory category) async {
    final categoryLabel = category.label;
    try {
      final res = await _client
          .from('sponsors')
          .select()
          .eq('active', true)
          .inFilter('category', [categoryLabel, 'General Business'])
          .limit(10);
      final ads = res.map(AdItem.fromMap).toList();
      if (ads.isEmpty) return [];
      ads.shuffle();
      return ads.take(2).toList();
    } catch (_) {
      return [];
    }
  }
}
