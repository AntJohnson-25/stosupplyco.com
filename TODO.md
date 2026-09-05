# What's left to do — stosupplyco.com

Status **05 Sep 2026**. Repo cloned (empty) at
`F:\Ctsgpyprojects\stosupplyco.com`. Nothing built yet — this file tracks the
plan while Anthony builds the front end and the client (or Anthony) handles
Supabase + GitHub setup.

Architecture reference: `F:\fred-seniorsecured.org` (Anthony's first client
site) — same skeleton, adapted from long-form blog to short-post feed. See
that repo's README.md and supabase/schema.sql for the pattern being mimicked.

---

## Decisions locked in

- **Format**: social-feed style, not long-form blog. Short caption + photo/video
  assets per post, not article body.
- **Stack**: static HTML/CSS/JS, no build step, no server. Browser talks to
  Supabase Postgres directly via PostgREST. Same trust model as Fred's site —
  RLS policies + security-definer functions do all the gatekeeping.
- **Deploy**: GitHub Pages + Namecheap CNAME → stosupplyco.com.
- **Video**: direct upload to Supabase Storage for new content going forward.
- **Interaction scope**: reactions + comments apply to the whole post, not
  per-asset within a multi-photo gallery.
- **Authors**: two — Anthony and the client — both need rows in
  `public.authors`, same allowlist pattern as Fred's site.

## Open decision — surfaced by the assets provided (05 Sep 2026)

- The client's existing content isn't raw video files — it's **3 Facebook
  Reel embed codes** (iframes, in `fb_embeddedings.txt`). Direct-upload-only
  storage doesn't cover this. Need either:
  - a `post_assets.kind = 'facebook_embed'` option that stores the Reel URL
    and renders the FB iframe embed, alongside `'photo'` / `'video'` for
    direct uploads, or
  - manually re-uploading those 3 reels as native video files instead.
  - **Leaning toward supporting the embed kind** since re-hosting someone
    else's Facebook Reel as a raw file is more work and worse quality than
    just embedding it. Confirm with Anthony before building the schema.

## Assets received (05 Sep 2026)

- `C:\Users\Acjoh\Downloads\fb_embeddedings.txt` — 3 Facebook Reel iframe
  embeds (see above).
- Two images from the client:
  - Stylized/anime shooting-range art — treating as the **profile/avatar
    image** (like Fred's `fred-flamer.jpg`) unless told otherwise.
  - Candid real photo (cap, maroon/leather varsity jacket) — treating as a
    **post asset**, not the profile photo, unless told otherwise.
  - *(Not yet saved into the repo — need confirmed filenames/roles before
    placing them, e.g. `sto-avatar.jpg` vs a post upload.)*

## Still needed from the client

- Bio / "about" text for the profile panel (mirrors Fred's role + bio fields)
- Confirmation of reaction icon set/wording (defaulted to something like
  👍 / 🔥 / 💯 for gun-content culture — not yet finalized)
- Any additional social links to display (or explicitly none, like Fred's
  site after his request to remove that panel)
- First real post content once assets are placed, to smoke-test the
  publish path

## Anthony's build queue

- [x] **Profile carousel prototype** (05 Sep 2026) — `index.html` has a working
      image carousel in the left profile column, same position/size as
      Fred's static avatar. Cycles `assets/sto-01.jpg` (anime shooting-range
      art) and `assets/sto-02.jpg` (candid photo) — prev/next arrows, dot
      indicators, 4s auto-advance, loops both directions, responsive on
      mobile. No feed/backend wiring yet — verified standalone in-browser via
      a local static server. Placeholder name/role/bio text still needs real
      copy from the client.
- [ ] `supabase/schema.sql` — posts (caption-based), post_assets, comments,
      reactions, events tables + functions, adapted from
      `F:\fred-seniorsecured.org\supabase\schema.sql`
- [ ] `supabase/authors.sql` — two-author allowlist
- [ ] `supabase/post-images.sql` — storage bucket + policies for photo/video
      uploads (and embed rows if that decision is confirmed)
- [ ] Feed view, single-post `/p/<slug>` view, composer, reaction bar,
      comments, dashboard — build into `index.html` alongside the carousel
- [ ] `config.js`, `404.html`, `CNAME`, `.nojekyll` — same as Fred's site

## Anthony's (or client's) setup queue

- [x] **Supabase account** (05 Sep 2026) — separate account, signed in via the
      `AntJohnSQL` GitHub login (`github.com/AntJohnSQL`, distinct from
      `AntJohnson-25` which owns this repo). Fully isolated from Fred's
      Supabase project/account, so it gets its own fresh free-tier project
      slot. This means the schema does **not** need the `sto_` table/function
      prefix that would've been required to safely share Fred's existing
      project — clean names (`posts`, `comments`, `reactions`, `events`,
      `authors`) are fine here.
- [x] **Supabase project created and schema applied** (05 Sep 2026) —
      `schema.sql`, `authors.sql`, `post-images.sql` all run successfully.
      Two author accounts exist and are on the allowlist: Anthony
      (`ant.johnsonsql22@gmail.com`) and the client
      (`alontaesto@gmail.com`), both Auto Confirm User. `post-media` storage
      bucket created (images + video, 50MB cap).
- [x] Public signup turned off (05 Sep 2026) — Authentication → Sign In /
      Providers → Email → "Allow new users to sign up" unchecked
- [x] `config.js` written (05 Sep 2026) — project
      `https://nakuixaixfnymqpnchbj.supabase.co`, legacy JWT anon key
      (matches supabase-js 2.58.0's expectations; the sb_publishable_ key
      Anthony also has is a one-line swap later if the legacy format is
      ever retired).
- [x] **Site is live** (05 Sep 2026) — `http://stosupplyco.com` returns 200,
      confirmed by direct request. Repo pushed to
      `AntJohnson-25/stosupplyco.com`, Namecheap DNS (4 A records + www
      CNAME) done, GitHub Pages source fixed from the "GitHub Actions"
      default (no workflow file, so nothing built) to "Deploy from a
      branch" / `main` / root — that was the actual cause of the
      "improperly configured" error, not DNS. An empty commit forced the
      first real build.
- [x] **HTTPS enforced** (05 Sep 2026) — `https://stosupplyco.com` confirmed
      returning 200 with a valid cert. Admin/deploy work is done.
- [ ] Build the actual feed/composer/reactions front end into `index.html`
      against the Supabase schema (currently only has the profile carousel
      prototype)
