import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleCors, jsonResponse } from "../_shared/cors.ts";

// ============================================================
// Account deletion (Play Store / App Store require in-app
// self-service account + data deletion for apps with sign-up).
//
// 1. Verify the caller's JWT with the anon key (never trust a
//    client-supplied user id).
// 2. Use the service-role key (server-side only) to wipe the
//    user's storage files, then delete the auth user — which
//    cascades to profiles/ideas/research_reports via FK
//    `on delete cascade` in 0001_init.sql.
// ============================================================

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const authClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
    );
    const { data: { user }, error: authError } = await authClient.auth.getUser();
    if (authError || !user) return jsonResponse({ error: "Unauthorized" }, 401);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Remove the user's media folder from storage first (not covered by the auth cascade).
    const { data: files, error: listError } = await admin.storage
      .from("idea-media")
      .list(user.id);
    if (!listError && files && files.length > 0) {
      const paths = files.map((f) => `${user.id}/${f.name}`);
      await admin.storage.from("idea-media").remove(paths);
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) return jsonResponse({ error: deleteError.message }, 500);

    return jsonResponse({ success: true });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: message }, 500);
  }
});
