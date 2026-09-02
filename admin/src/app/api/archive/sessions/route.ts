import { NextRequest, NextResponse } from "next/server";
import { requireSignedIn } from "@/lib/auth";
import {
  assertNoForbiddenCatalogKeys,
  mapSessionRow,
  normalizePlatform,
  sanitizeSetContext,
  type ArchiveCatalogSessionInput,
} from "@/lib/archive-catalog";
import { ensureAppUser } from "@/lib/users";
import { getServiceSupabase } from "@/lib/supabase";

/**
 * GET /api/archive/sessions — pull catalog metadata for the signed-in user.
 * Query: updatedSince (ISO8601, optional)
 */
export async function GET(request: NextRequest) {
  try {
    const session = await requireSignedIn();
    const user = await ensureAppUser(session.userId!);
    if (user.status === "disabled") {
      return NextResponse.json({ error: "Account disabled" }, { status: 403 });
    }

    const updatedSince = request.nextUrl.searchParams.get("updatedSince")?.trim();
    const supabase = getServiceSupabase();
    let query = supabase
      .from("archive_sessions")
      .select(
        `
        session_id,
        origin_device_id,
        origin_device_name,
        platform,
        source_app_id,
        detected_at,
        completed_at,
        original_filename,
        file_size,
        duration_seconds,
        ingestion_kind,
        companion_app_id,
        capture_route,
        capture_backend,
        capture_device_name,
        capture_device_transport,
        capture_interrupted,
        capture_interruption_reason,
        audio_backed_up,
        updated_at,
        deleted_at,
        archive_set_contexts (
          event_name,
          venue,
          city,
          tags,
          notes,
          updated_at
        )
      `
      )
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .order("updated_at", { ascending: false });

    if (updatedSince) {
      query = query.gte("updated_at", updatedSince);
    }

    const { data, error } = await query;
    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({
      sessions: (data ?? []).map((row) => mapSessionRow(row as Record<string, unknown>)),
      restrictions: {
        audio: false,
        tracklistContents: false,
        note: "Archive catalog sync contains metadata and set details only — never audio or track titles.",
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "error";
    const status = message === "Unauthorized" ? 401 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}

/**
 * POST /api/archive/sessions — upsert catalog rows from this device.
 * Body: { sessions: ArchiveCatalogSessionInput[] }
 */
export async function POST(request: NextRequest) {
  try {
    const session = await requireSignedIn();
    const body = (await request.json()) as { sessions?: ArchiveCatalogSessionInput[] };
    assertNoForbiddenCatalogKeys(body);

    const sessions = body.sessions;
    if (!Array.isArray(sessions) || sessions.length === 0) {
      return NextResponse.json({ error: "sessions array required" }, { status: 400 });
    }

    const user = await ensureAppUser(session.userId!);
    if (user.status === "disabled") {
      return NextResponse.json({ error: "Account disabled" }, { status: 403 });
    }

    const supabase = getServiceSupabase();
    const upserted: string[] = [];

    for (const item of sessions) {
      const sessionId = item.sessionId?.trim();
      const sourceAppId = item.sourceAppId?.trim();
      const originalFilename = item.originalFilename?.trim();
      const detectedAt = item.detectedAt?.trim();

      if (!sessionId || !sourceAppId || !originalFilename || !detectedAt) {
        return NextResponse.json(
          { error: "Each session requires sessionId, sourceAppId, originalFilename, and detectedAt" },
          { status: 400 }
        );
      }

      let platform: "macos" | "ios";
      try {
        platform = normalizePlatform(item.platform);
      } catch (error) {
        return NextResponse.json(
          { error: error instanceof Error ? error.message : "invalid platform" },
          { status: 400 }
        );
      }

      const now = new Date().toISOString();
      const row = {
        user_id: user.id,
        session_id: sessionId,
        origin_device_name: item.originDeviceName?.trim() || null,
        platform,
        source_app_id: sourceAppId,
        detected_at: detectedAt,
        completed_at: item.completedAt ?? null,
        original_filename: originalFilename,
        file_size: item.fileSize ?? 0,
        duration_seconds: item.durationSeconds ?? null,
        ingestion_kind: item.ingestionKind ?? null,
        companion_app_id: item.companionAppId ?? null,
        capture_route: item.captureRoute ?? null,
        capture_backend: item.captureBackend ?? null,
        capture_device_name: item.captureDeviceName ?? null,
        capture_device_transport: item.captureDeviceTransport ?? null,
        capture_interrupted: item.captureInterrupted ?? false,
        capture_interruption_reason: item.captureInterruptionReason ?? null,
        audio_backed_up: item.audioBackedUp ?? false,
        deleted_at: null,
        updated_at: now,
      };

      const { error: sessionError } = await supabase
        .from("archive_sessions")
        .upsert(row, { onConflict: "user_id,session_id" });

      if (sessionError) {
        return NextResponse.json({ error: sessionError.message }, { status: 500 });
      }

      const context = sanitizeSetContext(item.setContext);
      const { error: contextError } = await supabase.from("archive_set_contexts").upsert(
        {
          user_id: user.id,
          session_id: sessionId,
          ...context,
        },
        { onConflict: "user_id,session_id" }
      );

      if (contextError) {
        return NextResponse.json({ error: contextError.message }, { status: 500 });
      }

      upserted.push(sessionId);
    }

    return NextResponse.json({
      upserted,
      count: upserted.length,
      restrictions: {
        audio: false,
        tracklistContents: false,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "error";
    const status =
      message === "Unauthorized"
        ? 401
        : message.includes("not accepted")
          ? 400
          : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
