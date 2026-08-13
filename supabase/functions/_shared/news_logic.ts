// Core "find relevant news" logic, shared between the direct HTTP
// endpoint (news/index.ts) and the queue processor.

import { bm25Score, tokenize } from "./rank.ts";

interface Article {
  title: string;
  source: string;
  snippet: string;
  url: string;
  publishedAt: string;
}

const USER_AGENT = "IdeaVaultApp/1.0 (business idea research)";

// News sources (especially Hacker News's Algolia search) behave close to an
// AND match — every extra term shrinks the result set fast. A query built
// from title+notes together (up to 10 tokens, often with duplicates) was
// empirically found to return zero results for anything but the broadest
// ideas. Prefer a short, title-only query, and broaden by dropping terms
// (not adding them) if that first attempt finds nothing.
//
function buildQueries(title: string, notes?: string | null): string[] {
  const titleTokens = [...new Set(tokenize(title))];
  const notesTokens = [...new Set(tokenize(notes ?? ""))].filter(
    (t) => !titleTokens.includes(t),
  );

  const queries: string[] = [];
  if (titleTokens.length > 0) queries.push(titleTokens.slice(0, 5).join(" "));
  if (titleTokens.length > 0) queries.push(titleTokens[0]);
  else if (notesTokens.length > 0) queries.push(notesTokens[0]);
  return [...new Set(queries)].filter((q) => q.length > 0);
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

export async function runNews(
  title: string,
  notes?: string | null,
  limit = 8,
): Promise<Article[]> {
  const queries = buildQueries(title, notes);
  if (queries.length === 0) return [];

  // Try each query (broadest/most-specific first, then progressively
  // fewer terms) until one actually returns something — a single overly
  // specific query returning zero shouldn't mean the whole idea gets no
  // news.
  let all: Article[] = [];
  let query = queries[0];
  for (let i = 0; i < queries.length; i++) {
    const q = queries[i];
    const [newsapi, gnews, hn, reddit] = await Promise.all([
      fetchNewsAPI(q),
      fetchGNews(q),
      fetchHackerNews(q),
      fetchReddit(q),
    ]);
    all = dedupe([...newsapi, ...gnews, ...hn, ...reddit]);
    query = q;
    if (all.length > 0) break;
  }
  if (all.length === 0) return [];

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

  return scored.slice(0, Math.min(limit, 12)).map(({ score: _score, ...rest }) => rest);
}
