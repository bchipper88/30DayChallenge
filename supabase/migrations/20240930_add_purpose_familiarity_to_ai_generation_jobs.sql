alter table public.ai_generation_jobs
    add column if not exists purpose text,
    add column if not exists familiarity text;

create index if not exists ai_generation_jobs_familiarity_idx
    on public.ai_generation_jobs (familiarity);
