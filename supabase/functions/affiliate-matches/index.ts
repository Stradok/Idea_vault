import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleCors, jsonResponse } from "../_shared/cors.ts";
import { runAffiliateMatch } from "../_shared/affiliate_logic.ts";

// ============================================================
// "For you" tab: AI-matched tools/services/suppliers for a specific
// idea. Genuine recommendations with real URLs, not paid placements
// or affiliate links — this function has no way to generate real
// affiliate tracking codes.
//
// Direct HTTP path, kept for debugging/manual testing — the app
// queues these requests (see ai_request_queue) instead of calling
// this directly, since Google Search's free quota is shared across
// every user.
// ============================================================

interface MatchBody {
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

    const body = (await req.json()) as MatchBody;
    if (!body?.title) {
      return jsonResponse({ error: "title is required" }, 400);
    }

    const matches = await runAffiliateMatch(body.title, body.notes);
    return jsonResponse({ matches });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: message }, 500);
  }
});
