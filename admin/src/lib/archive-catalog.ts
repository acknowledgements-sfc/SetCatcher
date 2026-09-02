const FORBIDDEN_KEYS = new Set([
  "title",
  "artist",
  "tracks",
  "tracklist",
  "sourcePath",
  "archivePath",
  "manualTracklistID",
  "manualTracklistId",
]);

export type ArchiveCatalogPlatform = "macos" | "ios";

export type ArchiveCatalogSetContextInput = {
  eventName?: string;
  venue?: string;
  city?: string;
  tags?: string;
  notes?: string;
  updatedAt?: string;
};

export type ArchiveCatalogSessionInput = {
  sessionId?: string;
  platform?: string;
  originDeviceName?: string;
  sourceAppId?: string;
  detectedAt?: string;
  completedAt?: string | null;
  originalFilename?: string;
  fileSize?: number;
  durationSeconds?: number | null;
  ingestionKind?: string | null;
  companionAppId?: string | null;
  captureRoute?: string | null;
  captureBackend?: string | null;
  captureDeviceName?: string | null;
  captureDeviceTransport?: string | null;
  captureInterrupted?: boolean;
  captureInterruptionReason?: string | null;
  audioBackedUp?: boolean;
  setContext?: ArchiveCatalogSetContextInput | null;
};

export function assertNoForbiddenCatalogKeys(value: unknown, path = "body"): void {
  if (value === null || value === undefined) {
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => assertNoForbiddenCatalogKeys(item, `${path}[${index}]`));
    return;
  }
  if (typeof value !== "object") {
    return;
  }
  for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
    if (FORBIDDEN_KEYS.has(key)) {
      throw new Error(
        `Archive catalog must be metadata only — ${path}.${key} is not accepted.`
      );
    }
    assertNoForbiddenCatalogKeys(nested, `${path}.${key}`);
  }
}

export function normalizePlatform(value: string | undefined): ArchiveCatalogPlatform {
  const normalized = value?.trim().toLowerCase();
  if (normalized === "macos" || normalized === "ios") {
    return normalized;
  }
  throw new Error("platform must be macos or ios");
}

export function sanitizeSetContext(
  input: ArchiveCatalogSetContextInput | null | undefined
): {
  event_name: string;
  venue: string;
  city: string;
  tags: string;
  notes: string;
  updated_at: string;
} {
  const now = new Date().toISOString();
  return {
    event_name: input?.eventName?.trim() ?? "",
    venue: input?.venue?.trim() ?? "",
    city: input?.city?.trim() ?? "",
    tags: input?.tags?.trim() ?? "",
    notes: input?.notes?.trim() ?? "",
    updated_at: input?.updatedAt ?? now,
  };
}

export function mapSessionRow(row: Record<string, unknown>) {
  const context = row.archive_set_contexts as Record<string, unknown> | null | undefined;
  return {
    sessionId: row.session_id,
    platform: row.platform,
    originDeviceId: row.origin_device_id,
    originDeviceName: row.origin_device_name,
    sourceAppId: row.source_app_id,
    detectedAt: row.detected_at,
    completedAt: row.completed_at,
    originalFilename: row.original_filename,
    fileSize: row.file_size,
    durationSeconds: row.duration_seconds,
    ingestionKind: row.ingestion_kind,
    companionAppId: row.companion_app_id,
    captureRoute: row.capture_route,
    captureBackend: row.capture_backend,
    captureDeviceName: row.capture_device_name,
    captureDeviceTransport: row.capture_device_transport,
    captureInterrupted: row.capture_interrupted,
    captureInterruptionReason: row.capture_interruption_reason,
    audioBackedUp: row.audio_backed_up,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
    setContext: context
      ? {
          eventName: context.event_name,
          venue: context.venue,
          city: context.city,
          tags: context.tags,
          notes: context.notes,
          updatedAt: context.updated_at,
        }
      : null,
  };
}
