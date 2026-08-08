import { handleCors, jsonResponse } from "../_shared/cors.ts";
import { bm25Score, tokenize } from "../_shared/rank.ts";

// ============================================================
// News endpoint: fetch from many sources (NewsAPI, GNews,
// Hacker News Algolia, Reddit), dedupe, then BM25-rerank
// against the user's idea text. Returns the top results.
// ============================================================

interface NewsBody {
  title: string;
  notes?: string | null;
  limit?: number;
}

interface Article {
  title: string;
  source: string;
  snippet: string;
  url: string;
  publishedAt: string;
}

const USER_AGENT = "IdeaVaultApp/1.0 (business idea research)";

function buildQuery(title: string, notes?: string | null): string {
  const joined = `${title} ${notes ?? ""}`;
  const tokens = tokenize(joined);
  return tokens.slice(0, 10).join(" ");
}

function normalizeKey(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]/g, "");
}

async function fetchNewsAPI(query: string): Promise<Article[]> {
  const key = Deno.env.get("NEWSAPI_KEY");
  if (!key) return [];
  try {
    const url =
      `https://newsapi.org/v2/everything?q=${encodeURIComponent(query)}` +
      `&language=en&sortBy=relevancy&pageSize=25&apiKey=${key}`;
    const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) return [];
    const data = await res.json();
    const arts = (data?.articles ?? []) as Array<Record<string, unknown>>;
    return arts.map((a) => {
      const source = (a.source ?? {}) as Record<string, unknown>;
      return {
        title: String(a.title ?? "").replace(/ - \S+$/, ""),
        source: String(source?.name ?? "News"),
        snippet: String(a.description ?? a.content ?? "").slice(0, 300),
        url: String(a.url ?? ""),
        publishedAt: String(a.publishedAt ?? new Date().toISOString()),
      };
    });
  } catch (_) {
    return [];
  }
}

async function fetchGNews(query: string): Promise<Article[]> {
  const key = Deno.env.get("GNEWS_KEY");
  if (!key) return [];
  try {
    const url =
      `https://gnews.io/api/v4/search?q=${encodeURIComponent(query)}` +
      `&lang=en&max=25&token=${key}`;
    const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) return [];
    const data = await res.json();
    const arts = (data?.articles ?? []) as Array<Record<string, unknown>>;
    return arts.map((a) => {
      const source = (a.source ?? {}) as Record<string, unknown>;
      return {
        title: String(a.title ?? ""),
        source: String(source?.name ?? "News"),
        snippet: String(a.description ?? "").slice(0, 300),
        url: String(a.url ?? ""),
        publishedAt: String(a.publishedAt ?? new Date().toISOString()),
      };
    });
  } catch (_) {
    return [];
  }
}

async function fetchHackerNews(query: string): Promise<Article[]> {
  try {
    const url =
      `https://hn.algolia.com/api/v1/search?query=${encodeURIComponent(query)}` +
      `&hitsPerPage=20&tags=story`;
    const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) return [];
    const data = await res.json();
    const hits = (data?.hits ?? []) as Array<Record<string, unknown>>;
    return hits
      .filter((h) => h.url)
      .map((h) => ({
        title: String(h.title ?? ""),
        source: "Hacker News",
        snippet: String(h.title ?? ""),
        url: String(h.url),
        publishedAt: new Date((h.created_at_i as number) * 1000).toISOString(),
      }));
  } catch (_) {
    return [];
  }
}

async function fetchReddit(query: string): Promise<Article[]> {
  try {
    const url =
      `https://www.reddit.com/search.json?q=${encodeURIComponent(query)}` +
      `&sort=relevance&limit=20&t=year`;
    const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) return [];
    const data = await res.json();
    const children = (data?.data?.children ?? []) as Array<{ data: Record<string, unknown> }>;
    return children
      .filter((c) => c.data.permalink)
      .map((c) => ({
        title: String(c.data.title ?? ""),
        source: "Reddit",
        snippet: String(c.data.selftext ?? "").slice(0, 300),
        url: `https://www.reddit.com${c.data.permalink}`,
        publishedAt: new Date((c.data.created_utc as number) * 1000).toISOString(),
      }));
  } catch (_) {
    return [];
  }
}

function dedupe(articles: Article[]): Article[] {
  const seen = new Set<string>();
  const out: Article[] = [];
  for (const a of articles) {
    if (!a.url && !a.title) continue;
    const key = normalizeKey(a.title) || normalizeKey(a.url);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(a);
  }
  return out;
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

    const query = buildQuery(body.title, body.notes);
    if (!query) return jsonResponse({ news: [] });

    const [newsapi, gnews, hn, reddit] = await Promise.all([
      fetchNewsAPI(query),
      fetchGNews(query),
      fetchHackerNews(query),
      fetchReddit(query),
    ]);

    const all = dedupe([...newsapi, ...gnews, ...hn, ...reddit]);
    if (all.length === 0) return jsonResponse({ news: [] });

    const queryTokens = tokenize(query);
    const docFreq = new Map<string, number>();
    for (const a of all) {
      const seen = new Set(tokenize(`${a.title} ${a.snippet}`));
      for (const t of seen) docFreq.set(t, (docFreq.get(t) ?? 0) + 1);
    }
    const totalDocs = all.length;
    const avgDocLen =
      all.reduce((sum, a) => sum + tokenize(`${a.title} ${a.snippet}`).length, 0) / totalDocs;

    const scored = all.map((a) => ({
      ...a,
      score: bm25Score(queryTokens, `${a.title} ${a.snippet}`, docFreq, totalDocs, avgDocLen),
    }));
    scored.sort((a, b) => b.score - a.score);

    const limit = Math.min(body.limit ?? 8, 12);
    const news = scored.slice(0, limit).map(({ score, ...rest }) => rest);
    return jsonResponse({ news });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: message }, 500);
  }
});
