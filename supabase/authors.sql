-- ════════════════════════════════════════════════════════════════════════
--  stosupplyco.com — author allowlist
--
--  Paste this whole file into the Supabase SQL editor and run it once,
--  AFTER schema.sql. It is idempotent: running it again is harmless.
--
--  Why this exists
--  ───────────────
--  schema.sql answers "may this caller publish?" with
--  `auth.role() = 'authenticated'` — that is, *anyone holding a valid
--  login*. Combined with open signups, any stranger who registers gets
--  author rights: publish, edit, delete, and the analytics dashboard.
--
--  This file replaces that test with membership of an explicit allowlist.
--  Being signed in is no longer enough; you must be named in
--  public.authors. Signups can stay open or closed — an account that is
--  not on the list can do nothing a logged-out reader cannot.
-- ════════════════════════════════════════════════════════════════════════

-- ── the allowlist ──────────────────────────────────────────────────────
create table if not exists public.authors (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  email     text,
  note      text,                       -- e.g. 'site owner', 'client'
  added_at  timestamptz not null default now()
);

comment on table public.authors is
  'Allowlist of accounts permitted to publish and view analytics. '
  'Managed from the SQL editor or table editor only — the browser has no '
  'write path to this table.';

-- ── the test every rule below hangs off ────────────────────────────────
create or replace function public.is_author()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.authors a where a.user_id = auth.uid()
  );
$$;

comment on function public.is_author() is
  'True when the caller is signed in AND on the author allowlist.';

-- ── locking down the allowlist itself ──────────────────────────────────
alter table public.authors enable row level security;

drop policy if exists authors_read_self on public.authors;
create policy authors_read_self on public.authors for select
  to authenticated using (user_id = auth.uid());

grant select on public.authors to authenticated;

-- ════════════════════════════════════════════════════════════════════════
--  REPLACED POLICIES — same shape as schema.sql, allowlist instead of
--  bare `authenticated`
-- ════════════════════════════════════════════════════════════════════════

-- posts
drop policy if exists posts_read       on public.posts;
drop policy if exists posts_author_ins on public.posts;
drop policy if exists posts_author_upd on public.posts;
drop policy if exists posts_author_del on public.posts;

create policy posts_read on public.posts for select
  using (status = 'published' or public.is_author());
create policy posts_author_ins on public.posts for insert
  to authenticated with check (public.is_author());
create policy posts_author_upd on public.posts for update
  to authenticated using (public.is_author()) with check (public.is_author());
create policy posts_author_del on public.posts for delete
  to authenticated using (public.is_author());

-- post_assets
drop policy if exists post_assets_read       on public.post_assets;
drop policy if exists post_assets_author_ins on public.post_assets;
drop policy if exists post_assets_author_upd on public.post_assets;
drop policy if exists post_assets_author_del on public.post_assets;

create policy post_assets_read on public.post_assets for select
  using (exists (
    select 1 from public.posts p
     where p.id = post_assets.post_id
       and (p.status = 'published' or public.is_author())));
create policy post_assets_author_ins on public.post_assets for insert
  to authenticated with check (public.is_author());
create policy post_assets_author_upd on public.post_assets for update
  to authenticated using (public.is_author()) with check (public.is_author());
create policy post_assets_author_del on public.post_assets for delete
  to authenticated using (public.is_author());

-- comments
drop policy if exists comments_read       on public.comments;
drop policy if exists comments_author_upd on public.comments;
drop policy if exists comments_author_del on public.comments;

create policy comments_read on public.comments for select
  using (approved = true or public.is_author());
create policy comments_author_upd on public.comments for update
  to authenticated using (public.is_author()) with check (public.is_author());
create policy comments_author_del on public.comments for delete
  to authenticated using (public.is_author());

-- ════════════════════════════════════════════════════════════════════════
--  REPLACED FUNCTIONS — bodies identical to schema.sql except for the
--  authorisation test. Signatures unchanged, so schema.sql's grants stand.
-- ════════════════════════════════════════════════════════════════════════

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
      or (include_drafts and public.is_author())
   order by p.published_at desc;
$$;

create or replace function public.get_post(p_slug text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_post public.posts;
begin
  select * into v_post from public.posts where slug = p_slug;
  if not found then return null; end if;
  if v_post.status <> 'published' and not public.is_author() then
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

-- ── the dashboard gate ─────────────────────────────────────────────────
do $$
declare v_src text;
begin
  select pg_get_functiondef(p.oid) into v_src
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'analytics';

  if v_src is null then
    raise exception 'public.analytics() not found — run schema.sql first';
  end if;

  if position('auth.role() <> ''authenticated''' in v_src) = 0 then
    if position('not public.is_author()' in v_src) > 0 then
      raise notice 'analytics() already gated on the allowlist — leaving it alone';
      return;
    end if;
    raise exception
      'analytics() guard clause not recognised; gate it on public.is_author() by hand';
  end if;

  v_src := replace(v_src,
                   'auth.role() <> ''authenticated''',
                   'not public.is_author()');
  execute v_src;
  raise notice 'analytics() now gated on public.is_author()';
end $$;

-- ════════════════════════════════════════════════════════════════════════
--  SEED THE ALLOWLIST
--
--  ► EDIT THE TWO ADDRESSES BELOW, then run.
--
--  Each account must already exist under Authentication → Users. This
--  block does not create logins; it grants author rights to logins that
--  are already there.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare
  v_wanted constant text[] := array[
    'ant.johnsonsql22@gmail.com',   -- ← Anthony, site builder
    'alontaesto@gmail.com'          -- ← the client
  ];
  v_email    text;
  v_id       uuid;
  v_found    int := 0;
  v_missing  text[] := '{}';
  v_existing text;
begin
  foreach v_email in array v_wanted loop
    select id into v_id
      from auth.users
     where lower(email) = lower(trim(v_email))
     limit 1;

    if v_id is null then
      v_missing := v_missing || v_email;
    else
      insert into public.authors (user_id, email, note)
           values (v_id, lower(trim(v_email)), 'seeded by authors.sql')
      on conflict (user_id) do update set email = excluded.email;
      v_found := v_found + 1;
    end if;
  end loop;

  if v_found = 0 then
    select coalesce(string_agg(email, ', ' order by created_at), '(none — auth.users is empty)')
      into v_existing from auth.users;

    raise exception
      'allowlist is empty — nobody can publish, so nothing was applied.'
      using detail  = format('wanted: %s | accounts that actually exist: %s',
                             array_to_string(v_wanted, ', '), v_existing),
            hint    = 'Create the accounts under Authentication → Users with '
                      '"Auto Confirm User" ticked, then re-run this file.';
  end if;

  if array_length(v_missing, 1) > 0 then
    raise exception
      'partial allowlist — refusing to apply, or the missing person is locked out.'
      using detail = format('granted: %s of %s | no account for: %s',
                            v_found, array_length(v_wanted, 1),
                            array_to_string(v_missing, ', ')),
            hint   = 'Create the missing account, then re-run. To proceed with '
                     'fewer authors, remove that address from v_wanted above.';
  end if;
end $$;

-- ── verify ─────────────────────────────────────────────────────────────
select a.email, a.note, a.added_at, u.last_sign_in_at
  from public.authors a
  join auth.users u on u.id = a.user_id
 order by a.added_at;
