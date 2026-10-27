-- ============================================================
-- Mission Écran — schéma Supabase
-- À coller tel quel dans Supabase > SQL Editor > New query > Run.
-- Ne mets AUCUNE donnée personnelle dans ce fichier : il est public.
-- Les courriels autorisés et le sujet ntfy s'ajoutent ensuite
-- directement dans Supabase (voir l'étape 2 du README).
-- ============================================================

create extension if not exists pg_net with schema extensions;

-- 1) Comptes autorisés : 'parent' (approuve, gère) ou 'appareil' (tablette des enfants)
create table if not exists public.members (
  email text primary key,
  role text not null check (role in ('parent', 'appareil'))
);

create or replace function public.my_role()
returns text
language sql stable security definer set search_path = public
as $$
  select role from public.members
  where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

create or replace function public.is_member()
returns boolean language sql stable security definer set search_path = public
as $$ select public.my_role() is not null; $$;

create or replace function public.is_parent()
returns boolean language sql stable security definer set search_path = public
as $$ select public.my_role() = 'parent'; $$;

revoke execute on function public.my_role(), public.is_member(), public.is_parent() from anon, public;
grant execute on function public.my_role(), public.is_member(), public.is_parent() to authenticated;

-- 2) Réglages privés (sujet ntfy, URL de l'app) — jamais lisibles par l'API
create table if not exists public.private_settings (
  key text primary key,
  value text not null
);

-- 3) Enfants
create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  emoji text not null default '🙂',
  color text not null default '#F26A1B',
  default_minutes int not null default 60,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

-- 4) Tâches : récurrentes (days, 0 = dimanche … 6 = samedi) ou ponctuelles (one_off_date)
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  title text not null,
  emoji text not null default '✅',
  days smallint[] not null default '{1,2,3,4,5}',
  one_off_date date,
  min_photos int not null default 1 check (min_photos between 1 and 10),
  active boolean not null default true,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

-- 5) Preuves (une par tâche par jour)
create table if not exists public.completions (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  day date not null,
  photo_path text not null,
  photo_paths text[] not null default '{}',
  status text not null default 'done' check (status in ('done', 'redo')),
  parent_note text,
  created_at timestamptz not null default now(),
  unique (task_id, day)
);

-- 6) Demandes de temps d'écran
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
-- Sans connexion : rien n'est lisible ni modifiable.
-- Appareil familial : lit les tâches, envoie des preuves, crée une demande.
-- Parent : tout, y compris approuver et voir les photos.
-- ============================================================
alter table public.members          enable row level security;
alter table public.private_settings enable row level security;
alter table public.children         enable row level security;
alter table public.tasks            enable row level security;
alter table public.completions      enable row level security;
alter table public.requests         enable row level security;
-- members et private_settings : aucune règle = inaccessibles par l'API

create policy "membres lisent enfants" on public.children for select to authenticated using (public.is_member());
create policy "parents gerent enfants" on public.children for all to authenticated
  using (public.is_parent()) with check (public.is_parent());

create policy "membres lisent taches" on public.tasks for select to authenticated using (public.is_member());
create policy "parents gerent taches" on public.tasks for all to authenticated
  using (public.is_parent()) with check (public.is_parent());

create policy "membres lisent preuves" on public.completions for select to authenticated using (public.is_member());
create policy "membres envoient preuve" on public.completions for insert to authenticated
  with check (public.is_member() and status = 'done' and parent_note is null
              and day between current_date - 1 and current_date + 1);
create policy "membres refont preuve" on public.completions for update to authenticated
  using (public.is_member() and day >= current_date - 1)
  with check (public.is_member() and status = 'done' and parent_note is null
              and day between current_date - 1 and current_date + 1);
create policy "parents gerent preuves" on public.completions for all to authenticated
  using (public.is_parent()) with check (public.is_parent());

create policy "membres lisent demandes" on public.requests for select to authenticated using (public.is_member());
create policy "membres demandent" on public.requests for insert to authenticated
  with check (public.is_member() and status = 'pending' and minutes is null
              and decided_at is null and parent_note is null
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

create policy "membres televersent photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'preuves' and public.is_member());
create policy "parents voient photos" on storage.objects for select to authenticated
  using (bucket_id = 'preuves' and public.is_parent());
create policy "parents suppriment photos" on storage.objects for delete to authenticated
  using (bucket_id = 'preuves' and public.is_parent());

-- ============================================================
-- Notification push (ntfy) envoyée par Supabase à chaque nouvelle demande.
-- Le message ne contient aucun prénom.
-- ============================================================
create or replace function public.notify_new_request()
returns trigger
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_topic  text := (select value from public.private_settings where key = 'ntfy_topic');
  v_server text := coalesce((select value from public.private_settings where key = 'ntfy_server'), 'https://ntfy.sh');
  v_url    text := (select value from public.private_settings where key = 'app_url');
  v_body   jsonb;
begin
  if coalesce(v_topic, '') = '' then
    return new;
  end if;
  v_body := jsonb_build_object(
    'topic', v_topic,
    'title', 'Mission Écran',
    'message', 'Les tâches sont terminées. Touche pour voir les photos.',
    'tags', jsonb_build_array('white_check_mark'),
    'priority', 4
  );
  if coalesce(v_url, '') <> '' then
    v_body := v_body || jsonb_build_object('click', v_url);
  end if;
  perform net.http_post(
    url     := v_server,
    body    := v_body,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  return new;
exception when others then
  return new; -- une notif ratée ne doit jamais bloquer la demande
end;
$$;

revoke execute on function public.notify_new_request() from anon, authenticated, public;

drop trigger if exists requests_notify on public.requests;
create trigger requests_notify
  after insert on public.requests
  for each row execute function public.notify_new_request();
