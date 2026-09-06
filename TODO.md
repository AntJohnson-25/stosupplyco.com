# What's left to do — stosupplyco.com

Status **05 Sep 2026**. Site is **live at https://stosupplyco.com** with the
front end, Supabase backend, branding, SEO and a range mini-game all built and
deployed. What remains is listed under "Next up" — mostly things that need a
human with an author login. The opening paragraphs below are kept as the
original plan; scroll to "Second pass" for the current state.

*(Original note: repo cloned empty at `F:\Ctsgpyprojects\stosupplyco.com`,
nothing built yet — this file tracked the plan while Anthony built the front end
and the client handled Supabase + GitHub setup.)*

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
- [x] `supabase/schema.sql`, `authors.sql`, `post-images.sql` — written and
      applied to the live project (see setup queue below)
- [x] `config.js`, `404.html`, `CNAME`, `.nojekyll` — written and deployed
- [x] **Full front end built** (05 Sep 2026) — `index.html` now has:
      - Feed: reverse-chron post cards (caption, gallery carousel,
        reaction bar, comment/view counts), shareable `/p/<slug>` URLs
      - Single-post view: full gallery, true per-kind reaction counts,
        comments list + form, fires a `view` event once per session
      - Reactions: 👍/🔥/💯 (like/fire/hundred), toggled via
        `toggle_reaction`, pressed state tracked client-side
      - Composer (author-only): caption, multi-file photo/video upload to
        `post-media`, add-a-Facebook-Reel-link field, draft or publish
      - Auth: sign in/out, gated on the `authors` allowlist — a valid
        login that isn't an author gets signed back out with an
        explanation
      - Dashboard (author-only): 30-day totals, daily views, per-post
        performance, recent comments via `analytics()`
      - Client-side router (`/`, `/signin`, `/compose`, `/dashboard`,
        `/p/<slug>`) + the `404.html` deep-link restore on boot
      - Verified live against the deployed Supabase project: empty feed
        state renders correctly, `/signin` round-trips to Supabase Auth
        and cleanly surfaces "Invalid login credentials" on a bad login.
      - **Not yet tested**: the actual sign-in → compose → upload →
        publish → react → comment path, since that needs a real author
        password (Anthony's or the client's) that Claude doesn't hold.
        Anthony should smoke-test this next, same as Fred's own
        first-post smoke test.
- [x] **Branding, layout, post deletion, editable carousel, SEO and a range
      mini-game** (05 Sep 2026) — see the section below.

## Second pass: branding, layout, features, SEO (05 Sep 2026)

**Logo.** Two rounds. The first supplied logo was a product mockup — artwork on
a vignetted grey wall with a drop shadow. Neither brightness nor colour can cut
that: the shadow (160-224) overlaps the artwork's own metal highlights, and the
steel is as neutral as the wall. It came out on *texture* — over a 3x3 window
the wall reads std ~0.3 and its shadow ~0.9 while the gritty render never drops
below ~10 — in three stages (flat-bright-neutral test, border flood for the
shadow's dark core, gradient-limited grow for the contact shadow). That produced
`sto-logo.*`, `sto-badge.*` and the favicons.

It was then replaced by the current wordmark (`new_sto_logo.png`), which
**already carried a clean alpha channel** — alpha-vs-luminance correlation of
0.019 proves a real mask rather than a brightness key. Its core plateaus at
252-253 rather than 255, which over `#141414` shifts a metal value of 60 to
59.5, so the mask was deliberately left untouched. Delivered at 1200px: the mark
renders at ~190 CSS px, so that is already ~6x, and going larger only costs
visitors bandwidth. WebP is served with a PNG fallback because the artwork is
photographic and PNG is a poor fit for it (126KB vs 452KB).

**The favicons still come from the OLD shield emblem**, because a wordmark is
illegible at 32px. That makes `sto-badge.*` the only surviving piece of the
previous artwork, and it is otherwise unreferenced by the page.

**Layout.** `.page` is now three tracks (`1fr | 480px | 1fr`). The feed sits in
the fixed middle track so it centres on the viewport regardless of what flanks
it; the profile widget is pinned to the left gutter and the range game to the
right. The feed used to be `1fr`, which stretched the post card to ~920px around
a 420px gallery and left a band of dead card beside every image. Below 1000px
the whole thing stacks — at 900px the third track squeezed the game panel to
~128px, which is not playable.

**Post deletion.** Author-only, on feed cards and the single-post view, behind a
real confirmation. No migration was needed: `posts_author_del` already permitted
it and assets/comments/reactions/events cascade. What does *not* cascade is the
uploaded file, so `deletePost()` sweeps the storage objects first — otherwise
every deleted post orphans its photos in the storage quota forever.

**Editable profile carousel.** The two images were hard-coded, so changing them
meant a redeploy. They now come from `public.site_settings` (new migration,
public read / author write) with the shipped pair as the fallback, and an author
can upload, reorder and reset them from the UI. The migration has been applied
and verified live: anon read works, and an anonymous write is correctly refused
by RLS. The table is generic key/value jsonb, so moving the name/role/bio into
it later needs no second migration.

**SEO.** Title and description aimed at 2A, Black gun owners, and Cleveland /
Ohio firearms; canonical, robots, theme-color; Open Graph and Twitter cards with
**absolute** image URLs — the previous `og:image` was a relative path, which
crawlers cannot resolve, so every link preview was broken. New 1200x630 share
card, Organization + WebSite JSON-LD, the site name promoted to an `h1` (there
was none), a `noscript` summary, `robots.txt` and `sitemap.xml`. Copy says
"firearms" throughout except "Black gun owners" / "Black gun lovers", which are
kept because that is what the community calls itself and what people search.

> **The real SEO ceiling is structural, not tag-level.** The feed is rendered
> client-side from Supabase, and `/p/<slug>` falls through to `404.html` and
> bounces to the root — so no individual post is indexable, and the sitemap
> lists only `/` on purpose. Fixing that means pre-rendering or moving off
> GitHub Pages. No amount of meta-tag work substitutes for it.

**Range mini-game** (`The Range`, right gutter). A self-contained IIFE placed
*above* the `CONFIGURED` guard so it still runs if Supabase is unwired. An
outdoor dusk range: steel deer rise from behind cover in three depth lanes,
stand, then drop. Far lane pays triple, the vital ring pays most, and both the
standing time and the gap between pop-ups tighten as you score. Canvas scene is
prerendered offscreen with a seeded PRNG so hills and trees survive a resize;
deer are clipped to their lane's ground line with grass drawn over it, so the
edge each one rises through never shows. Works on touch. A synthesised bell
(no audio file) rings on a vital hit, with a mute toggle — audio on a public
site should never be forced on a visitor.

- **Latent bug fixed here, worth remembering:** the loop guarded its restart on
  `if (!raf)`. A backgrounded tab never fires its pending frame, so `raf` kept a
  handle that could never resolve and the game was dead permanently after one
  tab switch. Always cancel-and-reschedule.
- **The drawn vital ring and its hit test are separate code** (`drawDeer`'s arc
  vs `zoneAt`'s hypot). They must stay identical or the game lies about where to
  aim. Currently `(54, -64) r11` in both.

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

## Next up

Nothing below is blocked on code — these all need a human with an author login
or a decision from the client.

- [ ] **Smoke-test the author path.** Sign in on the live site and: publish a
      post with a photo/video, react, comment, check the dashboard, **delete a
      post**, and **save a new profile carousel**. None of these have ever been
      run for real — they need an author password, which Claude does not hold
      and will not handle. This is the single biggest untested area.
- [ ] **Watch the range game run for 30 seconds.** Its logic was verified
      against a stubbed DOM and its artwork by re-rendering the same
      coordinates offline, but the animation itself — rise, knockdown pivot,
      drifting clouds, reticle — has never been seen in a browser.
- [ ] **A dead Facebook embed.** The second post's reel renders "Video
      Unavailable" — it is gone or not public. Fix or delete that post.
- [ ] Verify the site in Google Search Console and submit `sitemap.xml`. Add
      the client's social URLs to the JSON-LD `sameAs` array. Consider a Google
      Business Profile — local pack placement is what "Cleveland firearms"
      actually rewards, far more than any on-page tag.
- [ ] Decide reaction icon set/wording — currently defaulted to
      👍/🔥/💯, not yet confirmed with the client
- [ ] The 3 Facebook Reels in `fb_embeddedings.txt` haven't been added as
      posts yet — composer supports it (paste the reel URL into the
      "Facebook Reel link" field), just needs doing
- [ ] Decide whether the favicon should stay as the old shield emblem now that
      the logo is a wordmark (see the branding section above)
- [ ] Optional: move the name/role/bio into `site_settings` so the client can
      edit their own copy. Currently hard-coded in `index.html` as
      "Daddy, Life Saver, Springfield Armory Lover" / "Cleveland, OH · 2A
      Advocate" — note *Armory*, the US spelling of the brand.

## Known constraints (not bugs)

- **Individual posts are not indexable.** GitHub Pages has no rewrite rules, so
  `/p/<slug>` hits `404.html` and is bounced to `/`. Search engines only ever
  see the home page.
- **`sto-badge.png` / `.webp` are unreferenced** by the page. They are kept as
  the source for regenerating favicons; safe to delete if the favicon changes.
- **PowerShell 5.1 wraps git's stderr as a NativeCommandError** on push. The
  push has usually succeeded — check `git status -sb` rather than trusting the
  red text.
