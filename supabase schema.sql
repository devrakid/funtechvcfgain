-- ============================================================
--  VCF CONTACTS GAIN — SUPABASE SCHEMA
--  Run this once in:  Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- ---------- 1. REGISTRATIONS TABLE --------------------------
create table if not exists public.registrations (
  id            uuid        primary key default gen_random_uuid(),
  contact_name  text        not null,
  phone_number  text        not null unique,   -- prevents duplicate registrations
  registered_at timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

-- Helpful index for ordering newest-first in the admin table
create index if not exists idx_registrations_created_at
  on public.registrations (created_at desc);


-- ---------- 2. APP SETTINGS TABLE (single row, id = 1) ------
create table if not exists public.app_settings (
  id                  int  primary key default 1,
  whatsapp_link       text not null default '',
  registration_target int  not null default 300,
  website_title       text not null default 'VCF Contacts Gain',
  updated_at          timestamptz not null default now(),
  constraint app_settings_single_row check (id = 1)
);

-- Seed the single settings row (does nothing if it already exists)
insert into public.app_settings (id) values (1)
  on conflict (id) do nothing;


-- ---------- 3. ROW LEVEL SECURITY ---------------------------
alter table public.registrations enable row level security;
alter table public.app_settings  enable row level security;

-- Registrations: public can READ (for the progress bar) and INSERT (to register)
create policy "registrations_select_public"
  on public.registrations for select using (true);

create policy "registrations_insert_public"
  on public.registrations for insert with check (true);

-- Registrations: DELETE is used by the admin panel.
--   The bundled admin uses a client-side password only, so this policy
--   currently allows delete with the public anon key.  See SECURITY NOTE.
create policy "registrations_delete_public"
  on public.registrations for delete using (true);

-- Settings: public can READ (index page needs the WhatsApp link + target)
create policy "settings_select_public"
  on public.app_settings for select using (true);

-- Settings: admin panel updates these values.  Same caveat as delete above.
create policy "settings_update_public"
  on public.app_settings for update using (true) with check (true);


-- ---------- 4. REALTIME -------------------------------------
-- Enables live progress + live admin table updates.
alter publication supabase_realtime add table public.registrations;


-- ============================================================
--  SECURITY NOTE — hardening the admin (recommended for production)
-- ------------------------------------------------------------
--  The admin login is client-side only, so the two "public" write
--  policies above (delete + settings update) can in theory be called
--  by anyone holding the public anon key.
--
--  To lock this down properly, switch the admin to Supabase Auth and
--  replace those two policies with authenticated-only versions, e.g.:
--
--    drop policy "registrations_delete_public" on public.registrations;
--    create policy "registrations_delete_auth"
--      on public.registrations for delete
--      to authenticated using (true);
--
--    drop policy "settings_update_public" on public.app_settings;
--    create policy "settings_update_auth"
--      on public.app_settings for update
--      to authenticated using (true) with check (true);
--
--  Then sign the admin in with supabase.auth before allowing deletes.
--  (INSERT + SELECT stay public so the registration form + progress
--   bar keep working for anonymous visitors.)
-- ============================================================
