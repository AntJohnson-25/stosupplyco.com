-- ════════════════════════════════════════════════════════════════════════
--  stosupplyco.com — full Supabase schema
--
--  Paste this whole file into the Supabase SQL editor and run it once.
--  It is idempotent: running it again is harmless.
--
--  The browser talks to Postgres directly through PostgREST using the
--  publishable "anon" key. That key is public by design — every rule that
--  matters is enforced here, by row-level security and by the security-
--  definer functions below.
--
--  Trust model, in one line: readers may read published posts and approved
--  comments, and may write only through the four functions at the bottom;
--  everything else requires a signed-in author.
--
--  Adapted from F:\fred-seniorsecured.org\supabase\schema.sql — same
--  trust model, but a post is a short caption + a gallery of assets
--  (photos, videos, or a Facebook Reel embed) instead of a long-form
--  article with one cover image. Reactions and comments stay scoped to
--  the whole post, not to individual assets in the gallery.
-- ════════════════════════════════════════════════════════════════════════

-- ── tables ─────────────────────────────────────────────────────────────
create table if not exists public.posts (
  id            serial primary key,
  slug          text not null unique,
  caption       text not null default '',
  author        text not null default 'STO Supply Co',
  status        text not null default 'published'
                  check (status in ('published','draft')),
  published_at  timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- The gallery. One post can carry several photos/videos, or a single
-- Facebook Reel embed. `position` orders them left-to-right in the
-- carousel; `url` is the full public URL (storage CDN link for an
-- uploaded file, or the facebook.com/reel/... link for an embed).
create table if not exists public.post_assets (
  id          serial primary key,
  post_id     integer not null references public.posts(id) on delete cascade,
  kind        text not null check (kind in ('photo','video','facebook_embed')),
  url         text not null,
  alt         text,
  position    int not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.comments (
  id          serial primary key,
  post_id     integer not null references public.posts(id) on delete cascade,
  name        text not null,
  body        text not null,
  visitor_id  text,
  approved    boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Reaction kinds default to like / fire / hundred (👍 🔥 💯) — swap the
-- check constraint and the REACTIONS table in index.html together if the
-- client wants different ones.
create table if not exists public.reactions (
  post_id     integer not null references public.posts(id) on delete cascade,
  visitor_id  text not null,
  kind        text not null check (kind in ('like','fire','hundred')),
  created_at  timestamptz not null default now(),
  primary key (post_id, visitor_id, kind)
);

-- One row per tracked interaction. type: view | share
-- (No scroll-depth/dwell tracking here — those measure long-form reading,
-- which doesn't apply to a short social-style post.)
create table if not exists public.events (
  id          bigserial primary key,
  post_id     integer references public.posts(id) on delete cascade,
  visitor_id  text not null,
  session_id  text,
  type        text not null,
  referrer    text,
  device      text,
  created_at  timestamptz not null default now()
);

create index if not exists post_assets_post_idx  on public.post_assets (post_id, position);
create index if not exists events_post_created_idx on public.events (post_id, created_at desc);
create index if not exists events_type_created_idx on public.events (type, created_at desc);
create index if not exists comments_post_idx       on public.comments (post_id, created_at desc);

-- One "view" row per session per post — keeps refreshes from inflating counts.
create unique index if not exists events_view_once_idx
  on public.events (post_id, session_id) where type = 'view';

-- ── small helpers ──────────────────────────────────────────────────────
create or replace function public.slugify(txt text)
returns text language sql immutable as $$
  select coalesce(
    nullif(
      left(
        trim(both '-' from
          regexp_replace(
            regexp_replace(lower(coalesce(txt, '')), '[^a-z0-9]+', '-', 'g'),
            '-{2,}', '-', 'g')),
        70),
      ''),
    'post');
$$;

-- Fills in a unique slug on insert (from the caption's first few words),
-- and keeps updated_at honest.
create or replace function public.posts_before_write()
returns trigger language plpgsql as $$
declare
  v_base text;
  v_try  text;
  v_n    int := 2;
begin
  if new.slug is null or btrim(new.slug) = '' then
    v_base := public.slugify(left(coalesce(new.caption, ''), 60));
    v_try  := v_base;
    while exists (select 1 from public.posts p
                   where p.slug = v_try and p.id is distinct from new.id) loop
      v_try := v_base || '-' || v_n;
      v_n   := v_n + 1;
    end loop;
    new.slug := v_try;
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists posts_before_write on public.posts;
create trigger posts_before_write
  before insert or update on public.posts
  for each row execute function public.posts_before_write();

-- ── row-level security ─────────────────────────────────────────────────
alter table public.posts       enable row level security;
alter table public.post_assets enable row level security;
alter table public.comments    enable row level security;
alter table public.reactions   enable row level security;
alter table public.events      enable row level security;

-- posts: the world reads published pieces; the author does everything.
drop policy if exists posts_read       on public.posts;
drop policy if exists posts_author_ins on public.posts;
drop policy if exists posts_author_upd on public.posts;
drop policy if exists posts_author_del on public.posts;

create policy posts_read on public.posts for select
  using (status = 'published' or auth.role() = 'authenticated');
create policy posts_author_ins on public.posts for insert
  to authenticated with check (true);
create policy posts_author_upd on public.posts for update
  to authenticated using (true) with check (true);
create policy posts_author_del on public.posts for delete
  to authenticated using (true);

-- post_assets: readable whenever the parent post is; writable by any
-- signed-in author (tightened to the allowlist in authors.sql).
drop policy if exists post_assets_read       on public.post_assets;
drop policy if exists post_assets_author_ins on public.post_assets;
drop policy if exists post_assets_author_upd on public.post_assets;
drop policy if exists post_assets_author_del on public.post_assets;

create policy post_assets_read on public.post_assets for select
  using (exists (
    select 1 from public.posts p
     where p.id = post_assets.post_id
       and (p.status = 'published' or auth.role() = 'authenticated')));
create policy post_assets_author_ins on public.post_assets for insert
  to authenticated with check (true);
create policy post_assets_author_upd on public.post_assets for update
  to authenticated using (true) with check (true);
create policy post_assets_author_del on public.post_assets for delete
  to authenticated using (true);

-- comments: approved ones are public to read; writes go through add_comment().
drop policy if exists comments_read       on public.comments;
drop policy if exists comments_author_del on public.comments;
drop policy if exists comments_author_upd on public.comments;

create policy comments_read on public.comments for select
  using (approved = true or auth.role() = 'authenticated');
create policy comments_author_upd on public.comments for update
  to authenticated using (true) with check (true);
create policy comments_author_del on public.comments for delete
  to authenticated using (true);

-- reactions and events carry no policies at all, so no direct access is
-- possible from the browser. They are reachable only through the
-- security-definer functions below, which is where the rules live.

-- ════════════════════════════════════════════════════════════════════════
--  READ PATHS
-- ════════════════════════════════════════════════════════════════════════

-- The feed. Drafts only for a signed-in author. Each row carries its
-- gallery as a jsonb array, ordered by position.
create or replace function public.list_posts(include_drafts boolean default false)
returns table (
  id int, slug text, caption text, author text,
  status text, published_at timestamptz,
  assets jsonb,
  reaction_count int, comment_count int, view_count int
)
language sql stable security definer set search_path = public as $$
  select p.id, p.slug, p.caption, p.author,
         p.status, p.published_at,
         coalesce((
           select jsonb_agg(jsonb_build_object(
                    'kind', a.kind, 'url', a.url, 'alt', a.alt)
                    order by a.position)
             from public.post_assets a where a.post_id = p.id), '[]'::jsonb),
         (select count(*)::int from public.reactions r where r.post_id = p.id),
         (select count(*)::int from public.comments  c where c.post_id = p.id and c.approved),
         (select count(*)::int from public.events    e where e.post_id = p.id and e.type = 'view')
    from public.posts p
   where p.status = 'published'
      or (include_drafts and auth.role() = 'authenticated')
   order by p.published_at desc;
$$;

-- One post, with its gallery, reaction tally and approved comments. Null
-- if missing or if it is a draft and the caller is not the author.
create or replace function public.get_post(p_slug text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_post public.posts;
begin
  select * into v_post from public.posts where slug = p_slug;
  if not found then return null; end if;
  if v_post.status <> 'published' and auth.role() <> 'authenticated' then
    return null;
  end if;

  return jsonb_build_object(
    'post', jsonb_build_object(
      'id',           v_post.id,
      'slug',         v_post.slug,
      'caption',      v_post.caption,
      'author',       v_post.author,
      'status',       v_post.status,
      'published_at', v_post.published_at),
    'assets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'kind', a.kind, 'url', a.url, 'alt', a.alt) order by a.position)
        from public.post_assets a where a.post_id = v_post.id), '[]'::jsonb),
    'reactions', (
      select jsonb_build_object(
        'like',    count(*) filter (where kind = 'like'),
        'fire',    count(*) filter (where kind = 'fire'),
        'hundred', count(*) filter (where kind = 'hundred'))
        from public.reactions where post_id = v_post.id),
    'comments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name, 'body', c.body, 'created_at', c.created_at)
        order by c.created_at)
        from public.comments c
       where c.post_id = v_post.id and c.approved), '[]'::jsonb));
end $$;

-- ════════════════════════════════════════════════════════════════════════
--  WRITE PATHS  (the only way a reader may write anything)
-- ════════════════════════════════════════════════════════════════════════

-- Toggle one reaction for one visitor. Returns the fresh tally.
create or replace function public.toggle_reaction(
  p_post_id int, p_visitor_id text, p_kind text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_visitor text := nullif(left(coalesce(p_visitor_id, ''), 64), '');
  v_added   boolean;
begin
  if p_kind not in ('like','fire','hundred') then
    raise exception 'Unknown reaction';
  end if;
  if v_visitor is null then
    raise exception 'Missing visitor id';
  end if;
  if not exists (select 1 from public.posts where id = p_post_id) then
    raise exception 'Post not found';
  end if;

  delete from public.reactions
   where post_id = p_post_id and visitor_id = v_visitor and kind = p_kind;

  if found then
    v_added := false;
  else
    insert into public.reactions (post_id, visitor_id, kind)
    values (p_post_id, v_visitor, p_kind)
    on conflict do nothing;
    v_added := true;
  end if;

  return jsonb_build_object(
    'added', v_added,
    'reactions', (
      select jsonb_build_object(
        'like',    count(*) filter (where kind = 'like'),
        'fire',    count(*) filter (where kind = 'fire'),
        'hundred', count(*) filter (where kind = 'hundred'))
        from public.reactions where post_id = p_post_id));
end $$;

-- Post a comment. Rate-limited to three per visitor per post per hour.
create or replace function public.add_comment(
  p_post_id int, p_name text, p_body text, p_visitor_id text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_name    text := left(btrim(coalesce(p_name, '')), 60);
  v_body    text := left(btrim(coalesce(p_body, '')), 2000);
  v_visitor text := nullif(left(coalesce(p_visitor_id, ''), 64), '');
  v_row     public.comments;
begin
  if v_name = '' or v_body = '' then
    raise exception 'Name and comment are required';
  end if;
  if not exists (
    select 1 from public.posts where id = p_post_id and status = 'published'
  ) then
    raise exception 'Post not found';
  end if;

  if v_visitor is not null and (
      select count(*) from public.comments
       where post_id = p_post_id and visitor_id = v_visitor
         and created_at > now() - interval '1 hour') >= 3 then
    raise exception 'Slow down a moment — try again shortly.';
  end if;

  insert into public.comments (post_id, name, body, visitor_id)
  values (p_post_id, v_name, v_body, v_visitor)
  returning * into v_row;

  return jsonb_build_object(
    'id', v_row.id, 'name', v_row.name,
    'body', v_row.body, 'created_at', v_row.created_at);
end $$;

-- Analytics ingest. Silently ignores anything malformed — measurement must
-- never break reading.
create or replace function public.track_event(
  p_post_id    int,
  p_visitor_id text,
  p_session_id text,
  p_type       text,
  p_referrer   text default null,
  p_device     text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_visitor text := nullif(left(coalesce(p_visitor_id, ''), 64), '');
  v_session text := nullif(left(coalesce(p_session_id, ''), 64), '');
  v_ref     text := nullif(left(coalesce(p_referrer, ''), 200), '');
  v_device  text := case when p_device in ('mobile','tablet','desktop')
                         then p_device else 'unknown' end;
begin
  if p_type not in ('view','share') then return; end if;
  if v_visitor is null or p_post_id is null then return; end if;
  if not exists (select 1 from public.posts where id = p_post_id) then return; end if;

  if p_type = 'view' then
    insert into public.events (post_id, visitor_id, session_id, type, referrer, device)
    values (p_post_id, v_visitor, v_session, 'view', v_ref, v_device)
    on conflict (post_id, session_id) where type = 'view' do nothing;
  else
    insert into public.events (post_id, visitor_id, session_id, type, referrer, device)
    values (p_post_id, v_visitor, v_session, 'share', v_ref, v_device);
  end if;
end $$;

-- ════════════════════════════════════════════════════════════════════════
--  THE DASHBOARD QUERY  (author only)
--  Views, reactions, comments and top posts — no scroll-depth/dwell, that
--  metric doesn't mean much for a short post.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.analytics(
  p_days int default 30, p_post_id int default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_days         int;
  v_since        timestamptz;
  v_series_since timestamptz;
  v_totals   jsonb;
  v_daily    jsonb;
  v_posts    jsonb;
  v_refs     jsonb;
  v_devices  jsonb;
  v_recent   jsonb;
begin
  if auth.role() <> 'authenticated' then
    raise exception 'Not authorised' using errcode = '42501';
  end if;

  v_days := case
    when p_days is null then 30
    when p_days <= 0    then 0
    else least(greatest(p_days, 1), 730)
  end;
  v_since := case when v_days = 0
                  then timestamptz '1970-01-01'
                  else now() - make_interval(days => v_days) end;
  v_series_since := case when v_days = 0
                         then now() - interval '365 days'
                         else v_since end;

  select jsonb_build_object(
           'views',    count(*) filter (where type = 'view'),
           'viewers',  count(distinct visitor_id) filter (where type = 'view'),
           'shares',   count(*) filter (where type = 'share'))
    into v_totals
    from public.events
   where created_at >= v_since
     and (p_post_id is null or post_id = p_post_id);

  select coalesce(jsonb_agg(jsonb_build_object(
           'day',   to_char(d.day, 'YYYY-MM-DD'),
           'views', coalesce(v.views, 0)) order by d.day), '[]'::jsonb)
    into v_daily
    from generate_series(date_trunc('day', v_series_since),
                         date_trunc('day', now()),
                         interval '1 day') as d(day)
    left join (
      select date_trunc('day', created_at) as day, count(*)::int as views
        from public.events
       where type = 'view' and created_at >= v_series_since
         and (p_post_id is null or post_id = p_post_id)
       group by 1) v on v.day = d.day;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', t.id, 'slug', t.slug, 'caption', t.caption, 'status', t.status,
           'views', t.views, 'comments', t.comments, 'reactions', t.reactions)
           order by t.views desc, t.published_at desc), '[]'::jsonb)
    into v_posts
    from (
      select p.id, p.slug, p.caption, p.status, p.published_at,
             count(e.*) filter (where e.type = 'view')::int as views,
             (select count(*)::int from public.comments  c where c.post_id = p.id) as comments,
             (select count(*)::int from public.reactions r where r.post_id = p.id) as reactions
        from public.posts p
        left join public.events e
          on e.post_id = p.id and e.created_at >= v_since
       group by p.id) t;

  select coalesce(jsonb_agg(jsonb_build_object('source', r.source, 'views', r.views)
           order by r.views desc), '[]'::jsonb)
    into v_refs
    from (
      select coalesce(nullif(referrer, ''), 'direct') as source, count(*)::int as views
        from public.events
       where type = 'view' and created_at >= v_since
         and (p_post_id is null or post_id = p_post_id)
       group by 1 order by views desc limit 8) r;

  select coalesce(jsonb_agg(jsonb_build_object('device', x.device, 'views', x.views)
           order by x.views desc), '[]'::jsonb)
    into v_devices
    from (
      select coalesce(device, 'unknown') as device, count(*)::int as views
        from public.events
       where type = 'view' and created_at >= v_since
         and (p_post_id is null or post_id = p_post_id)
       group by 1) x;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'name', c.name, 'body', c.body,
           'created_at', c.created_at, 'caption', c.caption, 'slug', c.slug)
           order by c.created_at desc), '[]'::jsonb)
    into v_recent
    from (
      select c.id, c.name, c.body, c.created_at, p.caption, p.slug
        from public.comments c
        join public.posts p on p.id = c.post_id
       where c.created_at >= v_since
       order by c.created_at desc limit 12) c;

  return jsonb_build_object(
    'range',           jsonb_build_object('days', v_days, 'since', v_since),
    'totals',          v_totals,
    'daily',           v_daily,
    'posts',           v_posts,
    'referrers',       v_refs,
    'devices',         v_devices,
    'recent_comments', v_recent);
end $$;

-- ── who may call what ──────────────────────────────────────────────────
-- Postgres grants EXECUTE to PUBLIC by default, so lock down first.
revoke execute on function public.list_posts(boolean)                    from public;
revoke execute on function public.get_post(text)                         from public;
revoke execute on function public.toggle_reaction(int, text, text)       from public;
revoke execute on function public.add_comment(int, text, text, text)     from public;
revoke execute on function public.track_event(int, text, text, text, text, text) from public;
revoke execute on function public.analytics(int, int)                    from public;

grant execute on function public.list_posts(boolean)                to anon, authenticated;
grant execute on function public.get_post(text)                     to anon, authenticated;
grant execute on function public.toggle_reaction(int, text, text)   to anon, authenticated;
grant execute on function public.add_comment(int, text, text, text) to anon, authenticated;
grant execute on function public.track_event(int, text, text, text, text, text)
                                                                    to anon, authenticated;
-- The dashboard is the author's alone.
grant execute on function public.analytics(int, int)                to authenticated;

-- ── no seed post ───────────────────────────────────────────────────────
-- This file deliberately creates no content. The first post is written by
-- an author through the site's own composer, which also proves the
-- sign-in and publish path works.
--
-- Until then the site shows its empty state ("No posts yet") rather than
-- an error, so it is safe to deploy an empty database.
