-- ═══════════════════════════════════════════════════════════════════════
--  stosupplyco.com — editable site settings
--
--  Run this in the Supabase SQL editor AFTER schema.sql and authors.sql.
--  It is idempotent: running it again is harmless.
--
--  What it is for: the profile carousel beside the logo used to be two
--  <img> tags hard-coded in index.html, so changing them meant editing and
--  redeploying the site. This table holds that list instead, letting an
--  author swap the images from the UI ("Edit profile images").
--
--  One row per setting, keyed by name, value as jsonb. The carousel lives
--  under key 'profile_carousel' shaped like:
--
--    { "items": [ { "kind": "photo", "url": "https://…", "alt": "" }, … ] }
--
--  The table is deliberately generic — a tagline, a bio or a link list can
--  be added later as new keys without another migration.
--
--  Who may do what: the world may READ (the carousel is public content on
--  the front page); only an allowlisted author may write. The read policy
--  is open rather than gated because index.html fetches this with the anon
--  key before anyone has signed in.
-- ═══════════════════════════════════════════════════════════════════════

-- Fail loudly rather than silently creating an unguarded table.
do $$
begin
  if to_regprocedure('public.is_author()') is null then
    raise exception 'public.is_author() not found — run supabase/authors.sql first';
  end if;
end $$;

create table if not exists public.site_settings (
  key        text primary key,
  value      jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

comment on table public.site_settings is
  'Key/value site content an author can edit from the UI. Public read, author write.';

alter table public.site_settings enable row level security;

drop policy if exists site_settings_read       on public.site_settings;
drop policy if exists site_settings_author_ins on public.site_settings;
drop policy if exists site_settings_author_upd on public.site_settings;
drop policy if exists site_settings_author_del on public.site_settings;

create policy site_settings_read on public.site_settings for select
  using (true);
create policy site_settings_author_ins on public.site_settings for insert
  to authenticated with check (public.is_author());
create policy site_settings_author_upd on public.site_settings for update
  to authenticated using (public.is_author()) with check (public.is_author());
create policy site_settings_author_del on public.site_settings for delete
  to authenticated using (public.is_author());

grant select on public.site_settings to anon, authenticated;
grant insert, update, delete on public.site_settings to authenticated;

-- ── verify ─────────────────────────────────────────────────────────────
select 'table' as check, 'public.site_settings' as result
 where to_regclass('public.site_settings') is not null
union all
select 'policies', string_agg(policyname, ', ' order by policyname)
  from pg_policies
 where schemaname = 'public' and tablename = 'site_settings';
