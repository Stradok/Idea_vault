import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleCors, jsonResponse } from "../_shared/cors.ts";
import { tokenize } from "../_shared/rank.ts";

// ============================================================
// "For you" tab: AI-matched tools/services/suppliers for a specific
// idea, replacing the old static curated-sponsor list. Same
// Perplexity->Gemini pattern as research/index.ts:
//  1. Perplexity searches for real tools, suppliers, and platforms a
//     founder building this idea could actually use.
//  2. Gemini structures the results.
// These are genuine recommendations with real URLs, not paid
// placements or affiliate links — this function has no way to
// generate real affiliate tracking codes.
// ============================================================

interface MatchBody {
  title: string;
  notes?: string | null;
}

const PERPLEXITY_MODEL = "sonar-pro";
const GEMINI_MODEL = "gemini-2.5-flash";

function buildQuery(title: string, notes?: string | null): string {
  const parts = [title, notes ?? ""].filter((p) => p.trim().length > 0);
  const joined = parts.join(" ");
  const tokens = tokenize(joined);
  return tokens.slice(0, 12).join(" ");
}

async function perplexitySearch(query: string): Promise<{ answer: string; citations: string[] }> {
  const key = Deno.env.get("PERPLEXITY_API_KEY");
  if (!key) throw new Error("PERPLEXITY_API_KEY not configured");

  const res = await fetch("https://api.perplexity.ai/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      model: PERPLEXITY_MODEL,
      messages: [
        {
          role: "system",
          content:
            "You help founders find real tools, suppliers, platforms, and services to build " +
            "their business idea. Recommend specific, real products/companies with real " +
            "websites (e.g. Shopify, Stripe, a specific manufacturer or wholesaler relevant " +
            "to the niche) — not generic advice. Keep the answer under 400 words.",
        },
        { role: "user", content: `Business idea: ${query}` },
      ],
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Perplexity error ${res.status}: ${text.slice(0, 500)}`);
  }
  const data = await res.json();
  const answer: string = data?.choices?.[0]?.message?.content ?? "";
  const citations: string[] = Array.isArray(data?.citations) ? data.citations : [];
  return { answer, citations };
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

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${key}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          { parts: [{ text: prompt, generationConfig: { temperature: 0.4 } }] },
        ],
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

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
    );
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return jsonResponse({ error: "Unauthorized" }, 401);

    const body = (await req.json()) as MatchBody;
    if (!body?.title) {
      return jsonResponse({ error: "title is required" }, 400);
    }

    const query = buildQuery(body.title, body.notes);
    const { answer, citations } = await perplexitySearch(query);
    const context =
      `Perplexity research:\n${answer}\n\nSources:\n${(citations ?? []).join("\n")}`;
    const matches = await geminiMatches(body.title, context);

    return jsonResponse({ matches });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: message }, 500);
  }
});
