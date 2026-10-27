-- ============================================================
-- Mission Écran — schéma Supabase
-- À coller dans Supabase > SQL Editor > New query > Run
-- ============================================================

-- 1) Parents autorisés (remplace par ton courriel et celui de l'autre parent)
create table if not exists public.parents (
  email text primary key
);
insert into public.parents (email) values
  ('ton.courriel@exemple.com')
on conflict do nothing;

create or replace function public.is_parent()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.parents
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- 2) Enfants
create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  emoji text not null default '🙂',
  color text not null default '#F26A1B',
  default_minutes int not null default 60,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

-- 3) Tâches : récurrentes (days, 0 = dimanche … 6 = samedi) ou ponctuelles (one_off_date)
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  title text not null,
  emoji text not null default '✅',
  days smallint[] not null default '{1,2,3,4,5}',
  one_off_date date,
  active boolean not null default true,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

-- 4) Preuves (une par tâche par jour)
create table if not exists public.completions (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  day date not null,
  photo_path text not null,
  status text not null default 'done' check (status in ('done', 'redo')),
  parent_note text,
  created_at timestamptz not null default now(),
  unique (task_id, day)
);

-- 5) Demandes de temps d'écran
create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  day date not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  minutes int,
  parent_note text,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create index if not exists requests_child_day on public.requests (child_id, day);

-- ============================================================
-- Sécurité (RLS)
-- Les appareils des enfants utilisent la clé "anon" : ils peuvent lire
-- les tâches, envoyer des preuves et créer une demande.
-- Seuls les parents connectés (table parents) peuvent approuver,
-- voir les photos et modifier les tâches.
-- ============================================================
alter table public.parents     enable row level security;
alter table public.children    enable row level security;
alter table public.tasks       enable row level security;
alter table public.completions enable row level security;
alter table public.requests    enable row level security;

-- parents : personne ne lit la liste via l'API (la fonction is_parent la lit)

create policy "lecture enfants" on public.children for select using (true);
create policy "parents gerent enfants" on public.children for all to authenticated
  using (public.is_parent()) with check (public.is_parent());

create policy "lecture taches" on public.tasks for select using (true);
create policy "parents gerent taches" on public.tasks for all to authenticated
  using (public.is_parent()) with check (public.is_parent());

create policy "lecture preuves" on public.completions for select using (true);
create policy "enfants envoient preuve" on public.completions for insert to anon, authenticated
  with check (status = 'done' and parent_note is null
              and day between current_date - 1 and current_date + 1);
create policy "enfants refont preuve" on public.completions for update to anon, authenticated
  using (day >= current_date - 1)
  with check (status = 'done' and parent_note is null
              and day between current_date - 1 and current_date + 1);
create policy "parents gerent preuves" on public.completions for all to authenticated
  using (public.is_parent()) with check (public.is_parent());

create policy "lecture demandes" on public.requests for select using (true);
create policy "enfants demandent" on public.requests for insert to anon, authenticated
  with check (status = 'pending' and minutes is null and decided_at is null and parent_note is null
              and day between current_date - 1 and current_date + 1);
create policy "parents decident" on public.requests for update to authenticated
  using (public.is_parent()) with check (public.is_parent());
create policy "parents suppriment demandes" on public.requests for delete to authenticated
  using (public.is_parent());

-- ============================================================
-- Stockage des photos (bucket privé)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('preuves', 'preuves', false)
on conflict (id) do nothing;

create policy "enfants televersent photos" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'preuves');
create policy "parents voient photos" on storage.objects for select to authenticated
  using (bucket_id = 'preuves' and public.is_parent());
create policy "parents suppriment photos" on storage.objects for delete to authenticated
  using (bucket_id = 'preuves' and public.is_parent());
