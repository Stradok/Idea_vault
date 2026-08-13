// Shared Google Custom Search JSON API client. Replaces Perplexity as the
// "gather live web context" step in research/affiliate-matches, and doubles
// as a News source. Free tier: 100 queries/day per Google Cloud project.
//
// Setup: https://programmablesearchengine.google.com/ (create a search
// engine configured for "Search the entire web"), then enable the "Custom
// Search API" in Google Cloud Console for the same project as your other
// keys. Needs two secrets: GOOGLE_SEARCH_API_KEY and GOOGLE_SEARCH_CX.

export interface GoogleSearchResult {
  title: string;
  link: string;
  snippet: string;
  displayLink: string;
}

export async function googleSearch(
  query: string,
  { num = 8 }: { num?: number } = {},
): Promise<GoogleSearchResult[]> {
  const key = Deno.env.get("GOOGLE_SEARCH_API_KEY");
  const cx = Deno.env.get("GOOGLE_SEARCH_CX");
  if (!key || !cx) {
    throw new Error("GOOGLE_SEARCH_API_KEY/GOOGLE_SEARCH_CX not configured");
  }

  const url =
    `https://www.googleapis.com/customsearch/v1?key=${key}&cx=${cx}` +
    `&q=${encodeURIComponent(query)}&num=${Math.min(num, 10)}`;

  const res = await fetch(url);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Google Search error ${res.status}: ${text.slice(0, 500)}`);
  }
  const data = await res.json();
  const items = (data?.items ?? []) as Array<Record<string, unknown>>;
  return items.map((it) => ({
    title: String(it.title ?? ""),
    link: String(it.link ?? ""),
    snippet: String(it.snippet ?? ""),
    displayLink: String(it.displayLink ?? ""),
  }));
}
