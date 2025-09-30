create table if not exists public.ai_generation_jobs (
    id uuid primary key default gen_random_uuid(),
    prompt text not null,
    status text not null check (status in ('pending', 'in_progress', 'completed', 'failed')) default 'pending',
    response_id text,
    result jsonb,
    error text,
    user_id uuid,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists ai_generation_jobs_status_created_idx
    on public.ai_generation_jobs (status, created_at asc);

create or replace function public.set_ai_generation_jobs_updated_at()
returns trigger as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$ language plpgsql;

create trigger ai_generation_jobs_set_updated_at
    before update on public.ai_generation_jobs
    for each row execute function public.set_ai_generation_jobs_updated_at();

alter table public.ai_generation_jobs enable row level security;

-- Service role (used by edge functions / workers) bypasses RLS; define policy for authenticated users if needed later.
