import { NextRequest, NextResponse } from "next/server";
import { requireSignedIn } from "@/lib/auth";
import { ensureAppUser } from "@/lib/users";
import { getServiceSupabase } from "@/lib/supabase";

/**
 * DELETE /api/archive/sessions/:sessionId — soft-delete a catalog row for this user.
 */
export async function DELETE(
  _request: NextRequest,
  context: { params: Promise<{ sessionId: string }> }
) {
  try {
    const session = await requireSignedIn();
    const user = await ensureAppUser(session.userId!);
    if (user.status === "disabled") {
      return NextResponse.json({ error: "Account disabled" }, { status: 403 });
    }

    const { sessionId } = await context.params;
    const trimmed = sessionId?.trim();
    if (!trimmed) {
      return NextResponse.json({ error: "sessionId required" }, { status: 400 });
    }

    const supabase = getServiceSupabase();
    const now = new Date().toISOString();
    const { data, error } = await supabase
      .from("archive_sessions")
      .update({ deleted_at: now, updated_at: now })
      .eq("user_id", user.id)
      .eq("session_id", trimmed)
      .is("deleted_at", null)
      .select("session_id")
      .maybeSingle();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
    if (!data) {
      return NextResponse.json({ error: "Session not found" }, { status: 404 });
    }

    return NextResponse.json({ deleted: true, sessionId: trimmed });
  } catch (error) {
    const message = error instanceof Error ? error.message : "error";
    const status = message === "Unauthorized" ? 401 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
