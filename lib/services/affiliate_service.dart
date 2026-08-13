import '../models/affiliate_match.dart';
import 'ai_queue_service.dart';
import 'idea_category.dart';
import 'idea_store.dart';
import 'sponsor_service.dart';

abstract class AffiliateService {
  Future<List<AffiliateMatch>> matchesFor({
    required String ideaId,
    required String title,
    String? notes,
    required IdeaCategory category,
  });
}

/// AI-matched tools/services/suppliers for a specific idea (the "For you"
/// tab), cached inside the idea's own Drive file via [IdeaCache]. Falls back
/// to the curated [SponsorService] list if the AI call fails or the model
/// can't find real matches, so the tab is never empty.
class DriveAffiliateService implements AffiliateService {
  final IdeaCache _cache;
  final AiQueueService _queue;
  final SponsorService _fallback;
  static const _cacheKey = 'affiliates';

  DriveAffiliateService(this._queue, this._cache, this._fallback);

  @override
  Future<List<AffiliateMatch>> matchesFor({
    required String ideaId,
    required String title,
    String? notes,
    required IdeaCategory category,
  }) async {
    final cached = await _cachedMatches(ideaId);
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final result = await _queue.enqueueAndWait(
        kind: 'affiliate',
        title: title,
        ideaId: ideaId,
        notes: notes,
      );
      // process-ai-queue stores runAffiliateMatch()'s return value (a raw
      // array) directly in the queue row's `result` column.
      final list = (result as List?) ?? const [];
      final matches = list
          .whereType<Map<String, dynamic>>()
          .map(AffiliateMatch.fromJson)
          .where((m) => m.url.isNotEmpty)
          .toList();
      if (matches.isNotEmpty) {
        await _cache.writeCache(
          ideaId,
          _cacheKey,
          matches.map((m) => m.toJson()).toList(),
        );
        return matches;
      }
    } catch (_) {
      // Fall through to the curated fallback below.
    }

    final sponsors = await _fallback.adsFor(category);
    return sponsors
        .map((ad) => AffiliateMatch(
              name: ad.advertiser,
              description: ad.tagline,
              url: ad.link,
              category: ad.category,
            ))
        .toList();
  }

  Future<List<AffiliateMatch>?> _cachedMatches(String ideaId) async {
    try {
      final payload = await _cache.readCache(ideaId, _cacheKey);
      if (payload is! List) return null;
      return payload
          .whereType<Map>()
          .map((m) => AffiliateMatch.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
