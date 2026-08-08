-- ============================================================
-- IdeaVault schema
-- Run via: supabase db push  (or run in Supabase SQL editor)
-- ============================================================

create extension if not exists "uuid-ossp";

-- ---------- Profiles (one row per user) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  created_at timestamptz not null default now()
);

-- ---------- Ideas ----------
create table if not exists public.ideas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  notes text,
  image_url text,
  audio_url text,
  is_favorite boolean not null default false,
  reminder_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------- Research reports (cache, one per idea) ----------
create table if not exists public.research_reports (
  idea_id uuid primary key references public.ideas (id) on delete cascade,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

-- ---------- Curated sponsors (the "For you" ads) ----------
create table if not exists public.sponsors (
  id uuid primary key default gen_random_uuid(),
  advertiser text not null,
  tagline text not null,
  cta text not null,
  category text not null,          -- matches IdeaCategory enum label
  icon text not null,
  color_hex text not null,         -- e.g. '#1565C0'
  link text not null,              -- real destination URL
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------- Row level security ----------
alter table public.profiles enable row level security;
alter table public.ideas enable row level security;
alter table public.research_reports enable row level security;
alter table public.sponsors enable row level security;

-- Users can read/write their own profile
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- Ideas: fully private per user
create policy "ideas_select_own" on public.ideas
  for select using (auth.uid() = user_id);
create policy "ideas_insert_own" on public.ideas
  for insert with check (auth.uid() = user_id);
create policy "ideas_update_own" on public.ideas
  for update using (auth.uid() = user_id);
create policy "ideas_delete_own" on public.ideas
  for delete using (auth.uid() = user_id);

-- Research reports: private per user (joined through idea ownership)
create policy "research_select_own" on public.research_reports
  for select using (
    exists (select 1 from public.ideas i where i.id = idea_id and i.user_id = auth.uid())
  );
create policy "research_insert_own" on public.research_reports
  for insert with check (
    exists (select 1 from public.ideas i where i.id = idea_id and i.user_id = auth.uid())
  );
create policy "research_update_own" on public.research_reports
  for update using (
    exists (select 1 from public.ideas i where i.id = idea_id and i.user_id = auth.uid())
  );
create policy "research_delete_own" on public.research_reports
  for delete using (
    exists (select 1 from public.ideas i where i.id = idea_id and i.user_id = auth.uid())
  );

-- Sponsors: readable by any authenticated user
create policy "sponsors_select_auth" on public.sponsors
  for select using (auth.role() = 'authenticated');

-- ---------- Auto-create profile on signup ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- Storage buckets ----------
insert into storage.buckets (id, name, public)
values ('idea-media', 'idea-media', false)
on conflict (id) do nothing;

-- Storage policies: users can only touch files inside their own folder
create policy "media_read_own"
  on storage.objects for select
  using (bucket_id = 'idea-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "media_insert_own"
  on storage.objects for insert
  with check (bucket_id = 'idea-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "media_delete_own"
  on storage.objects for delete
  using (bucket_id = 'idea-media' and (storage.foldername(name))[1] = auth.uid()::text);

-- ============================================================
-- Seed sponsors (real links). Edit/expand in Supabase dashboard.
-- ============================================================
insert into public.sponsors (advertiser, tagline, cta, category, icon, color_hex, link, active) values
  ('Shopify', 'Start selling online today - build your store in minutes', 'Start free trial', 'General Business', '🛍️', '#5E8E3E', 'https://www.shopify.com', true),
  ('Stripe', 'Payments infrastructure for your new business', 'Get started', 'Finance & Payments', '💳', '#635BFF', 'https://stripe.com', true),
  ('Google Cloud', 'Free startup credits to launch your app', 'Claim credits', 'Tech & SaaS', '☁️', '#4285F4', 'https://cloud.google.com/startup', true),
  ('GitHub', 'Host your code and ship faster', 'Start free', 'Tech & SaaS', '💻', '#24292F', 'https://github.com', true),
  ('Square', 'Accept payments in person and online', 'Get started', 'E-commerce & Retail', '📟', '#006AFF', 'https://squareup.com', true),
  ('Canva', 'Design your brand and marketing in minutes', 'Start designing', 'General Business', '🎨', '#00C4CC', 'https://www.canva.com', true),
  ('Airbnb', 'List experiences and earn from travelers', 'Become a host', 'Travel & Hospitality', '🏨', '#FF5A5F', 'https://www.airbnb.com/host', true),
  ('Mindbody', 'Software for wellness and fitness businesses', 'Learn more', 'Fitness & Sports', '💪', '#0F8A5F', 'https://www.mindbodyonline.com', true),
  ('QuickBooks', 'Bookkeeping and invoicing for small business', 'Try free', 'Finance & Payments', '📊', '#2CA01C', 'https://quickbooks.intuit.com', true),
  ('Wix', 'Build a professional website for your idea', 'Create site', 'General Business', '🌐', '#FF3366', 'https://www.wix.com', true)
on conflict (id) do nothing;
