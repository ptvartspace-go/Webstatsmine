-- =====================================================================
--  PTV Traffic Ledger — Supabase schema
--  Run this once in the Supabase SQL editor.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The table
-- ---------------------------------------------------------------------
create table if not exists public.hits (
  id          bigint generated always as identity primary key,
  seen_at     timestamptz not null default now(),
  site        text not null,
  path        text not null,
  referrer    text,
  visit_id    text,
  device      text,
  browser     text,
  lang        text,

  constraint site_len     check (char_length(site)     <= 60),
  constraint path_len     check (char_length(path)     <= 300),
  constraint referrer_len check (char_length(referrer) <= 200),
  constraint visit_len    check (char_length(visit_id) <= 40),
  constraint device_len   check (char_length(device)   <= 20),
  constraint browser_len  check (char_length(browser)  <= 20),
  constraint lang_len     check (char_length(lang)     <= 10)
);

create index if not exists hits_seen_at_idx      on public.hits (seen_at desc);
create index if not exists hits_site_seen_at_idx on public.hits (site, seen_at desc);

-- ---------------------------------------------------------------------
-- 2. Row level security
--    anon  -> may INSERT only (that is all the tracker script needs)
--    you   -> may SELECT once signed in
-- ---------------------------------------------------------------------
alter table public.hits enable row level security;

drop policy if exists "anon may record a hit" on public.hits;
create policy "anon may record a hit"
  on public.hits for insert to anon
  with check (true);

drop policy if exists "signed in may read" on public.hits;
create policy "signed in may read"
  on public.hits for select to authenticated
  using (true);

-- ---------------------------------------------------------------------
-- 3. Aggregates
--    All counting happens in Postgres, so the dashboard downloads
--    a few dozen rows instead of your whole traffic history.
--    p_site = null means "all sites".
-- ---------------------------------------------------------------------

-- Totals for the selected window.
create or replace function public.stats_summary(p_site text, p_from timestamptz)
returns table (views bigint, visits bigint)
language sql stable
as $$
  select count(*)::bigint,
         count(distinct visit_id)::bigint
  from public.hits
  where seen_at >= p_from
    and (p_site is null or site = p_site);
$$;

-- Time series. p_bucket is 'hour' or 'day'. p_tz keeps day boundaries
-- local, e.g. 'Asia/Tokyo', so a Tuesday is a Tuesday where you are.
create or replace function public.stats_series(p_site text, p_from timestamptz, p_bucket text, p_tz text)
returns table (bucket timestamp, views bigint, visits bigint)
language sql stable
as $$
  select date_trunc(
           case when p_bucket = 'hour' then 'hour' else 'day' end,
           seen_at at time zone coalesce(p_tz, 'UTC')
         ),
         count(*)::bigint,
         count(distinct visit_id)::bigint
  from public.hits
  where seen_at >= p_from
    and (p_site is null or site = p_site)
  group by 1
  order by 1;
$$;

-- Top values for one dimension: 'path', 'referrer', 'browser', 'device', 'site', 'lang'.
create or replace function public.stats_top(p_site text, p_from timestamptz, p_dim text, p_limit int)
returns table (label text, views bigint, visits bigint)
language sql stable
as $$
  select label, views, visits from (
    select case p_dim
             when 'path'     then path
             when 'referrer' then coalesce(nullif(referrer, ''), 'Direct')
             when 'browser'  then coalesce(nullif(browser, ''), 'Unknown')
             when 'device'   then coalesce(nullif(device, ''), 'Unknown')
             when 'site'     then site
             when 'lang'     then coalesce(nullif(lang, ''), 'Unknown')
           end as label,
           count(*)::bigint as views,
           count(distinct visit_id)::bigint as visits
    from public.hits
    where seen_at >= p_from
      and (p_site is null or site = p_site)
    group by 1
  ) t
  where label is not null
  order by views desc
  limit greatest(1, least(coalesce(p_limit, 10), 50));
$$;

-- ---------------------------------------------------------------------
-- 4. Lock the functions to signed-in users
-- ---------------------------------------------------------------------
revoke execute on function public.stats_summary(text, timestamptz)              from public, anon;
revoke execute on function public.stats_series(text, timestamptz, text, text)   from public, anon;
revoke execute on function public.stats_top(text, timestamptz, text, int)       from public, anon;

grant execute on function public.stats_summary(text, timestamptz)              to authenticated;
grant execute on function public.stats_series(text, timestamptz, text, text)   to authenticated;
grant execute on function public.stats_top(text, timestamptz, text, int)       to authenticated;

-- ---------------------------------------------------------------------
-- 5. Optional: throw away hits older than a year.
--    Needs the pg_cron extension enabled under Database > Extensions.
-- ---------------------------------------------------------------------
-- select cron.schedule(
--   'trim-hits',
--   '0 3 * * 0',
--   $$ delete from public.hits where seen_at < now() - interval '365 days' $$
-- );
