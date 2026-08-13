// Web search via Tavily — replaces Google Custom Search as the "gather
// live context" step for research/affiliate-matches. Google's free Custom
// Search tier turned out to be structurally unreliable for this project
// (flip-flopping between 403 "no access" and 429 "quota exceeded" well
// under the 100/day cap). Tavily is built specifically for LLM/RAG search
// grounding and has a genuinely free tier (no card required), so this is a
// like-for-like swap: same shape (raw results + citations), same downstream
// Gemini structuring step in research_logic.ts/affiliate_logic.ts.

import { fetchWithRetry } from "./http_retry.ts";

interface TavilyResult {
  title: string;
  url: string;
  content: string;
}

interface TavilyResponse {
  results?: TavilyResult[];
}

export async function tavilySearch(
  query: string,
): Promise<{ answer: string; citations: string[] }> {
  const key = Deno.env.get("TAVILY_API_KEY");
  if (!key) throw new Error("TAVILY_API_KEY not configured");

  // One retry on rate limits / transient server errors — a control group
  // of a few people won't come close to Tavily's real limits, but a single
  // blip shouldn't burn a whole queued request.
  const res = await fetchWithRetry("https://api.tavily.com/search", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      api_key: key,
      query,
      search_depth: "basic",
      max_results: 8,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Tavily error ${res.status}: ${text.slice(0, 500)}`);
  }

  const data = (await res.json()) as TavilyResponse;
  const results = data.results ?? [];
  const answer = results
    .map((r) => `- ${r.title}: ${r.content}`)
    .join("\n");
  const citations = results.map((r) => r.url).filter((u) => !!u);
  return { answer, citations };
}
