import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleCors, jsonResponse } from "../_shared/cors.ts";
import { tokenize } from "../_shared/rank.ts";

// ============================================================
// Research endpoint (RAG pipeline):
//  1. Perplexity (web-search model) gathers fresh context + sources
//     about the user's idea.
//  2. Gemini writes a rich, structured research report grounded
//     in that context (retrieval-augmented generation).
// Stateless: the client caches the report itself (inside the idea's
// Google Drive file) — this function does not persist anything.
// ============================================================

interface ResearchBody {
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

async function perplexityResearch(query: string): Promise<{ answer: string; citations: string[] }> {
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
            "You are a business research analyst. Research the given business idea. " +
            "Report current market facts, real competitors, typical cost ranges to launch, " +
            "the core problem and who the target customer is. Be concrete and cite real sources. " +
            "Keep the answer under 500 words.",
        },
        { role: "user", content: `Business idea to research: ${query}` },
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

async function geminiReport(ideaTitle: string, context: string): Promise<Record<string, unknown>> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("GEMINI_API_KEY not configured");

  const prompt =
    `You are an expert startup advisor. Write a research report for the business idea: "${ideaTitle}".\n\n` +
    `Use ONLY the research context below. If the context is missing a section, say so honestly ` +
    `("Limited data available") instead of inventing figures.\n\n` +
    `RESEARCH CONTEXT:\n${context}\n\n` +
    `Return your answer as STRICT JSON (no markdown fences) with exactly this schema:\n` +
    `{\n` +
    `  "summary": string (2-3 sentences, grounded in the context),\n` +
    `  "problem": string (the core customer problem),\n` +
    `  "solution": string (a practical solution approach),\n` +
    `  "targetMarket": string (who to sell to first),\n` +
    `  "competitors": string[] (3-5 real competitors from the context),\n` +
    `  "costRange": string (realistic launch cost range),\n` +
    `  "costBreakdown": string (how that cost splits),\n` +
    `  "potentialScore": number (0-100 honest viability score),\n` +
    `  "keyInsights": string[] (4-5 sharp insights),\n` +
    `  "sources": string[] (the URLs from the context)\n` +
    `}`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${key}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              {
                text: prompt,
                generationConfig: { temperature: 0.4 },
              },
            ],
          },
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
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  const json = cleaned.slice(start, end + 1);
  return JSON.parse(json) as Record<string, unknown>;
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

    const body = (await req.json()) as ResearchBody;
    if (!body?.title) {
      return jsonResponse({ error: "title is required" }, 400);
    }

    const query = buildQuery(body.title, body.notes);
    const { answer, citations } = await perplexityResearch(query);

    const context =
      `Perplexity research:\n${answer}\n\nSources:\n${(citations ?? []).join("\n")}`;
    const report = await geminiReport(body.title, context);
    if (!Array.isArray(report.sources)) report.sources = citations ?? [];

    return jsonResponse({ report });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: message }, 500);
  }
});
