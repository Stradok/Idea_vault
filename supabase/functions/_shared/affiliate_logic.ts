// Core "find matching tools" logic, shared between the direct HTTP
// endpoint (affiliate-matches/index.ts) and the queue processor.

import { tokenize } from "./rank.ts";
import { tavilySearch } from "./tavily.ts";
import { fetchWithRetry } from "./http_retry.ts";

// See research_logic.ts for why this is the "-latest" alias, not a pinned version.
const GEMINI_MODEL = "gemini-flash-latest";

function buildQuery(title: string, notes?: string | null): string {
  const parts = [title, notes ?? ""].filter((p) => p.trim().length > 0);
  const joined = parts.join(" ");
  const tokens = tokenize(joined);
  return tokens.slice(0, 8).join(" ");
}

async function webSearch(query: string): Promise<{ answer: string; citations: string[] }> {
  return await tavilySearch(`best tools software services for ${query} business`);
}

async function geminiMatches(ideaTitle: string, context: string): Promise<unknown[]> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("GEMINI_API_KEY not configured");

  const prompt =
    `You help founders find real tools/suppliers/services for the business idea: "${ideaTitle}".\n\n` +
    `Use ONLY the research context below to extract real, named products/companies with real URLs. ` +
    `Do not invent companies or URLs. If the context doesn't have enough for 4 matches, return fewer.\n\n` +
    `RESEARCH CONTEXT:\n${context}\n\n` +
    `Return STRICT JSON (no markdown fences): an array of 3-5 objects with exactly this schema:\n` +
    `{ "name": string, "description": string (one sentence, why it fits this idea), ` +
    `"url": string (real homepage URL), "category": string (e.g. "Payments", "Manufacturing", "Marketing") }`;

  const res = await fetchWithRetry(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${key}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.4 },
      }),
    },
  );

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Gemini error ${res.status}: ${text.slice(0, 500)}`);
  }
  const data = await res.json();
  const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  const cleaned = raw.replace(/```json|```/g, "").trim();
  const start = cleaned.indexOf("[");
  const end = cleaned.lastIndexOf("]");
  const json = cleaned.slice(start, end + 1);
  const parsed = JSON.parse(json);
  return Array.isArray(parsed) ? parsed : [];
}

export async function runAffiliateMatch(
  title: string,
  notes?: string | null,
): Promise<unknown[]> {
  const query = buildQuery(title, notes);
  const { answer, citations } = await webSearch(query);
  const context = `Web search results:\n${answer}\n\nSources:\n${(citations ?? []).join("\n")}`;
  return await geminiMatches(title, context);
}
