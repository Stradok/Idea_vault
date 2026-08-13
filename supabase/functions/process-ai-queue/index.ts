import { createClient } from "jsr:@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/cors.ts";
import { runResearch } from "../_shared/research_logic.ts";
import { runNews } from "../_shared/news_logic.ts";
import { runAffiliateMatch } from "../_shared/affiliate_logic.ts";

// ============================================================
// Processes exactly one pending row from ai_request_queue per
// invocation, so Google Search's shared 100/day free quota is
// spent deliberately (one queued request at a time) instead of
// however many users happen to open Research/News/For-you at
// once. Invoked on a schedule by pg_cron (see migration 0004) —
// not called directly by the app.
// ============================================================

interface QueueRow {
  id: string;
  kind: "research" | "news" | "affiliate";
  title: string;
  notes: string | null;
  category: string | null;
}

Deno.serve(async (req) => {
  // Only pg_cron (which sends this shared secret) should be able to
  // trigger processing — not the general public hitting this URL.
  const cronSecret = Deno.env.get("QUEUE_CRON_SECRET");
  if (cronSecret && req.headers.get("x-cron-secret") !== cronSecret) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const { data: candidates, error: selectError } = await supabase
      .from("ai_request_queue")
      .select("id, kind, title, notes, category")
      .eq("status", "pending")
      .order("created_at", { ascending: true })
      .limit(1);
    if (selectError) throw selectError;
    if (!candidates || candidates.length === 0) {
      return jsonResponse({ processed: false, reason: "queue empty" });
    }
    const row = candidates[0] as QueueRow;

    // Claim it — the .eq("status", "pending") guard means a second
    // concurrent invocation racing on the same row updates 0 rows and
    // backs off instead of double-processing it.
    const { data: claimed, error: claimError } = await supabase
      .from("ai_request_queue")
      .update({ status: "processing" })
      .eq("id", row.id)
      .eq("status", "pending")
      .select("id");
    if (claimError) throw claimError;
    if (!claimed || claimed.length === 0) {
      return jsonResponse({ processed: false, reason: "lost claim race" });
    }

    try {
      let result: unknown;
      if (row.kind === "research") {
        result = await runResearch(row.title, row.notes);
      } else if (row.kind === "news") {
        result = await runNews(row.title, row.notes);
      } else {
        result = await runAffiliateMatch(row.title, row.notes);
      }

      await supabase
        .from("ai_request_queue")
        .update({ status: "done", result, processed_at: new Date().toISOString() })
        .eq("id", row.id);

      return jsonResponse({ processed: true, id: row.id, kind: row.kind });
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      await supabase
        .from("ai_request_queue")
        .update({
          status: "error",
          error_message: message.slice(0, 500),
          processed_at: new Date().toISOString(),
        })
        .eq("id", row.id);
      return jsonResponse({ processed: false, id: row.id, error: message }, 500);
    }
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: message }, 500);
  }
});
