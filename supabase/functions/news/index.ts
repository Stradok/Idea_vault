import { handleCors, jsonResponse } from "../_shared/cors.ts";
import { runNews } from "../_shared/news_logic.ts";

// ============================================================
// News endpoint: fetch from many sources (Google Search, NewsAPI,
// GNews, Hacker News Algolia, Reddit), dedupe, then BM25-rerank
// against the user's idea text. Returns the top results.
//
// Direct HTTP path, kept for debugging/manual testing — the app
// queues these requests (see ai_request_queue) instead of calling
// this directly, since Google Search's free quota is shared across
// every user.
// ============================================================

interface NewsBody {
  title: string;
  notes?: string | null;
  limit?: number;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const auth = req.headers.get("Authorization");
    if (!auth || !auth.startsWith("Bearer ")) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const body = (await req.json()) as NewsBody;
    if (!body?.title) return jsonResponse({ error: "title is required" }, 400);

    const news = await runNews(body.title, body.notes, body.limit ?? 8);
    return jsonResponse({ news });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: message }, 500);
  }
});
