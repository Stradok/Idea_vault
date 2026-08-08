import 'package:supabase_flutter/supabase_flutter.dart';

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

  Backend(this.client)
      : ideas = SupabaseIdeaStore(client),
        media = SupabaseMediaService(client),
        research = SupabaseResearchService(client),
        news = SupabaseNewsService(client),
        sponsors = SupabaseSponsorService(client);
}
