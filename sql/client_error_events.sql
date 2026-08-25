-- Historico duravel de falhas observadas no navegador/Flutter Web.
-- Execute uma vez no SQL Editor do Supabase.

create table if not exists public.client_error_events (
  id uuid primary key default gen_random_uuid(),
  reference_id text not null unique,
  context text not null,
  error_message text not null,
  stack_trace text,
  path text,
  platform text,
  diagnostics jsonb not null default '{}'::jsonb,
  user_agent text,
  request_id text,
  deployment_id text,
  git_commit_sha text,
  received_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists client_error_events_created_at_idx
  on public.client_error_events (created_at desc);
create index if not exists client_error_events_context_created_at_idx
  on public.client_error_events (context, created_at desc);

alter table public.client_error_events enable row level security;
revoke all on table public.client_error_events from anon, authenticated;
grant all on table public.client_error_events to service_role;

comment on table public.client_error_events is
  'Erros tecnicos sanitizados recebidos pelo endpoint /api/client-errors.';
