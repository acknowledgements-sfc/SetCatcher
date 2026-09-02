-- Archive catalog sync (metadata + SetContext only — no audio, no tracklists)
-- Privacy: no source/archive paths, no track titles/artists, no manualTracklistID

create table public.archive_sessions (
  session_id uuid not null,
  user_id uuid not null references public.users (id) on delete cascade,
  origin_device_id uuid references public.devices (id) on delete set null,
  origin_device_name text,
  platform text not null,
  source_app_id text not null,
  detected_at timestamptz not null,
  completed_at timestamptz,
  original_filename text not null,
  file_size bigint not null default 0,
  duration_seconds double precision,
  ingestion_kind text,
  companion_app_id text,
  capture_route text,
  capture_backend text,
  capture_device_name text,
  capture_device_transport text,
  capture_interrupted boolean not null default false,
  capture_interruption_reason text,
  audio_backed_up boolean not null default false,
  deleted_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  primary key (user_id, session_id)
);

create index archive_sessions_user_updated_idx
  on public.archive_sessions (user_id, updated_at desc);

create table public.archive_set_contexts (
  user_id uuid not null,
  session_id uuid not null,
  event_name text not null default '',
  venue text not null default '',
  city text not null default '',
  tags text not null default '',
  notes text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, session_id),
  foreign key (user_id, session_id)
    references public.archive_sessions (user_id, session_id) on delete cascade
);

alter table public.archive_sessions enable row level security;
alter table public.archive_set_contexts enable row level security;

revoke all on public.archive_sessions from anon, authenticated;
revoke all on public.archive_set_contexts from anon, authenticated;
grant all on public.archive_sessions to service_role;
grant all on public.archive_set_contexts to service_role;
