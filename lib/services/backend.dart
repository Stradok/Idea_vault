import 'package:supabase_flutter/supabase_flutter.dart';

import 'affiliate_service.dart';
import 'ai_queue_service.dart';
import 'drive/drive_client.dart';
import 'idea_store.dart';
import 'media_service.dart';
import 'news_service.dart';
import 'research_service.dart';
import 'sponsor_service.dart';

class Backend {
  final SupabaseClient client;
  final IdeaStore ideas;
  final MediaService media;
  final AiResearchService research;
  final NewsService news;
  final SponsorService sponsors;
  final AffiliateService affiliates;
  final AiQueueService queue;

  factory Backend(SupabaseClient client, DriveClient drive) {
    // One DriveIdeaStore shared as both the IdeaStore and the IdeaCache used
    // by research/news/affiliates — a second instance would keep its own
    // Drive-file-id lookup cache and redundantly re-list the Drive folder.
    final ideaStore = DriveIdeaStore(drive);
    final sponsors = SupabaseSponsorService(client);
    final queue = SupabaseAiQueueService(client);
    return Backend._(
      client: client,
      ideas: ideaStore,
      media: DriveMediaService(drive),
      news: DriveNewsService(queue, ideaStore),
      sponsors: sponsors,
      research: DriveResearchService(queue, ideaStore),
      affiliates: DriveAffiliateService(queue, ideaStore, sponsors),
      queue: queue,
    );
  }

  Backend._({
    required this.client,
    required this.ideas,
    required this.media,
    required this.research,
    required this.news,
    required this.sponsors,
    required this.affiliates,
    required this.queue,
  });
}
