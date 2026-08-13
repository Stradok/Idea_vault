// Core "do the research" logic, shared between the direct HTTP endpoint
// (research/index.ts) and the queue processor (process-ai-queue/index.ts)
// so there's exactly one implementation of the search->Gemini pipeline.

import { tokenize } from "./rank.ts";
import { googleSearch } from "./google_search.ts";

const GEMINI_MODEL = "gemini-2.5-flash";

function buildQuery(title: string, notes?: string | null): string {
  const parts = [title, notes ?? ""].filter((p) => p.trim().length > 0);
  const joined = parts.join(" ");
  const tokens = tokenize(joined);
  return tokens.slice(0, 8).join(" ");
}

async function webResearch(query: string): Promise<{ answer: string; citations: string[] }> {
  const results = await googleSearch(`${query} market competitors cost`, { num: 8 });
  const answer = results
    .map((r) => `- ${r.title} (${r.displayLink}): ${r.snippet}`)
    .join("\n");
  const citations = results.map((r) => r.link).filter((l) => l.length > 0);
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

export async function runResearch(
  title: string,
  notes?: string | null,
): Promise<Record<string, unknown>> {
  const query = buildQuery(title, notes);
  const { answer, citations } = await webResearch(query);
  const context = `Web search results:\n${answer}\n\nSources:\n${(citations ?? []).join("\n")}`;
  const report = await geminiReport(title, context);
  if (!Array.isArray(report.sources)) report.sources = citations ?? [];
  return report;
}
