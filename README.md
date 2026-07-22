# Traffic Ledger

A small, self-hosted traffic monitor for a handful of static sites. Three moving parts:

| File | What it does | Where it lives |
|---|---|---|
| `schema.sql` | One table, two policies, three counting functions | Supabase |
| `tracker.js` | ~1 KB script that records a page view | Served from GitHub Pages, loaded by your sites |
| `index.html` | Password-protected dashboard, no dependencies | GitHub Pages |

No cookies, no third-party services, no build step.

---

## Setup

### 1. Database

In the Supabase SQL editor, paste and run `schema.sql`. It creates a `hits`
table where anonymous visitors may **insert** rows but only a signed-in user
may **read** them.

### 2. Your dashboard login

- **Authentication → Users → Add user**: your email and a password, with
  auto-confirm on.
- **Authentication → Sign In / Providers → Email**: turn *Allow new users to
  sign up* **off**. You already have your account; nobody else needs one.

### 3. Keys

From **Project Settings → API**, copy the Project URL and the `anon` public key
into the two placeholder lines at the top of both `tracker.js` and
`index.html`.

The anon key is meant to be public. It can only do what the policies permit,
which is add a row to `hits` — it cannot read anything back.

### 4. Publish

Push this folder to a repo and turn on GitHub Pages. The dashboard lives at
`https://YOURNAME.github.io/webstats/`. It is safe to leave public: the numbers
only appear after you sign in.

### 5. Add the tracker to your sites

One line before `</body>` on any page you want counted:

```html
<script src="https://YOURNAME.github.io/webstats/tracker.js"
        data-site="ptv-english" defer></script>
```

`data-site` is the label the dashboard groups by, so give each project its own:
`jawschat`, `ptv-english`, `eslworldnews`, `littlerpgs`.

---

## Counting things that aren't page loads

Your worksheets are single files with tabs, so a page load undercounts what
actually happened. The tracker exposes one function:

```js
ptvTrack('/burger-worksheet#ordering');   // when a tab opens
ptvTrack('/burger-worksheet#finished');   // when a student completes it
```

Those arrive as separate rows and show up in the Pages table, which turns the
dashboard into a rough picture of how far students get before they stop.

---

## What gets recorded

Site label, path, referring domain, a random per-tab session id, device class,
browser name, browser language, and a timestamp. No IP addresses, no cookies,
no persistent identifier. The session id lives in `sessionStorage` and is gone
when the tab closes.

The tracker skips visitors whose browser sends Do Not Track, obvious bots, and
`localhost`, so testing your own pages does not pollute the numbers.

Because visitors are counted per session rather than per person, the dashboard
says **visits**, not "unique visitors". One student across three days counts
as three visits. That is the honest number, and it is the one the data
supports.

---

## Two things worth knowing

**Anyone can post fake hits.** The anon key sits in your tracker file, so a
determined person could send junk rows. For a teaching business this is a
nuisance rather than a risk, and the length constraints in the schema stop the
table being used as storage. If it ever happens, put a Cloudflare Worker or a
Vercel function between the tracker and Supabase and keep the key server-side.

**The table grows.** Roughly 100 bytes a row, so a hundred thousand views is
about 10 MB. The commented-out `pg_cron` job at the bottom of `schema.sql`
deletes anything older than a year if you'd rather it stayed small.

---

## Adjusting it

- **Timezone** — `TZ` at the top of `index.html`, currently `Asia/Tokyo`. Days
  break at local midnight, not UTC.
- **Ranges** — the `RANGES` object; add a `"1y"` entry if you want one.
- **Refresh rate** — `setInterval(load, 60000)` at the bottom.
- **How many rows per table** — the `p_limit` values in `load()`.
