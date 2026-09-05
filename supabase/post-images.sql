-- ════════════════════════════════════════════════════════════════════════
--  stosupplyco.com — storage for post photos/videos
--
--  Paste this whole file into the Supabase SQL editor and run it once,
--  AFTER schema.sql and authors.sql. It is idempotent: running it again is
--  harmless.
--
--  Unlike Fred's site (one optional cover image per post, stored as a
--  column), STO posts carry a gallery — rows already live in
--  public.post_assets from schema.sql. This file only needs to create the
--  storage bucket those rows point at, and the policies for who may
--  upload/replace/delete objects in it. Facebook Reel embeds need no
--  storage at all — they're just a URL in post_assets.url.
--
--  Who may do what: the world may READ every file in the bucket (they
--  appear on a public website, so they are public by definition); only an
--  allowlisted author may upload, replace or delete one.
-- ════════════════════════════════════════════════════════════════════════

-- ── guard ──────────────────────────────────────────────────────────────
do $$
begin
  if to_regprocedure('public.is_author()') is null then
    raise exception 'public.is_author() not found — run supabase/authors.sql first';
  end if;
end $$;

-- ── the bucket ─────────────────────────────────────────────────────────
-- 50 MB cap covers a phone-shot video clip; images will be far smaller.
-- Tighten file_size_limit here if the free-tier storage quota gets tight.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
     values ('post-media', 'post-media', true, 52428800,
             array['image/jpeg','image/png','image/webp','image/gif',
                   'video/mp4','video/quicktime','video/webm'])
on conflict (id) do update
        set public             = true,
            file_size_limit    = 52428800,
            allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif',
                                        'video/mp4','video/quicktime','video/webm'];

-- ── who may touch the files ────────────────────────────────────────────
drop policy if exists post_media_public_read on storage.objects;
drop policy if exists post_media_author_ins  on storage.objects;
drop policy if exists post_media_author_upd  on storage.objects;
drop policy if exists post_media_author_del  on storage.objects;

create policy post_media_public_read on storage.objects for select
  using (bucket_id = 'post-media');

create policy post_media_author_ins on storage.objects for insert
  to authenticated with check (bucket_id = 'post-media' and public.is_author());

create policy post_media_author_upd on storage.objects for update
  to authenticated
  using (bucket_id = 'post-media' and public.is_author())
  with check (bucket_id = 'post-media' and public.is_author());

create policy post_media_author_del on storage.objects for delete
  to authenticated using (bucket_id = 'post-media' and public.is_author());

-- ── verify ─────────────────────────────────────────────────────────────
select 'bucket' as check, id || ' (public=' || public || ', limit=' || file_size_limit || ')' as result
  from storage.buckets where id = 'post-media'
union all
select 'storage policies', string_agg(policyname, ', ' order by policyname)
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects' and policyname like 'post_media%';
