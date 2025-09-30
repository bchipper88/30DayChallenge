alter table public.ai_generation_jobs
    add column if not exists agent text,
    add column if not exists model text;

create index if not exists ai_generation_jobs_agent_idx
    on public.ai_generation_jobs (agent);
