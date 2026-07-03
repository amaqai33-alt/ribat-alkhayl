-- مديول بصمة المشية — pgvector (المرحلة ٢)
-- نفّذ في SQL Editor بعد schema.sql الأساسي

create extension if not exists vector;

-- === baseline embedding (بصمة واحدة لكل profile) ===
create table if not exists gait_baseline_embeddings (
    profile_id text primary key,
    device_id text not null,
    horse_name text not null,
    embedding vector(77) not null,
    dimensions int not null default 77,
    dtw_reference_distance double precision,
    updated_at timestamptz not null default now()
);

-- === session embedding (لكل جلسة) ===
create table if not exists gait_session_embeddings (
    capture_id text primary key references gait_sessions (capture_id) on delete cascade,
    device_id text not null,
    profile_id text,
    horse_name text not null,
    embedding vector(77) not null,
    cosine_similarity double precision,
    updated_at timestamptz not null default now()
);

create index if not exists idx_session_embeddings_device
    on gait_session_embeddings (device_id, updated_at desc);

-- مقارنة cosine مع baseline (للوحة/استعلامات)
create or replace function match_session_to_baseline(
    p_device_id text,
    p_profile_id text,
    query_embedding vector(77)
)
returns table (
    capture_id text,
    similarity double precision
)
language sql
stable
as $$
    select
        se.capture_id,
        1 - (se.embedding <=> query_embedding) as similarity
    from gait_session_embeddings se
    where se.device_id = p_device_id
      and (p_profile_id is null or se.profile_id = p_profile_id)
    order by se.embedding <=> query_embedding
    limit 20;
$$;

alter table gait_baseline_embeddings enable row level security;
alter table gait_session_embeddings enable row level security;

create policy "anon_all_baseline_embeddings"
    on gait_baseline_embeddings for all using (true) with check (true);
create policy "anon_all_session_embeddings"
    on gait_session_embeddings for all using (true) with check (true);
