import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleCors, jsonResponse } from "../_shared/cors.ts";
import { runResearch } from "../_shared/research_logic.ts";

// ============================================================
// Research endpoint (RAG pipeline) — direct HTTP path, kept for
// debugging/manual testing. The app itself now queues these
// requests (see ai_request_queue + process-ai-queue) instead of
// calling this directly, since Google Search's free quota is
// shared across every user.
// ============================================================

interface ResearchBody {
  title: string;
  notes?: string | null;
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

    const report = await runResearch(body.title, body.notes);
    return jsonResponse({ report });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: message }, 500);
  }
});
