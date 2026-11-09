-- Teacher Pratchaya: migrate the PIN-based Dashboard to Supabase Auth.
-- Run ONLY in Supabase project timetable-ftt:
-- https://lhtxkaakztygfxvcodqx.supabase.co
--
-- This migration does not delete or overwrite hub_pages.data.

begin;

-- 1) Allow-list of teacher accounts allowed to edit the Dashboard.
create table if not exists public.hub_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  created_at timestamptz not null default now()
);

alter table public.hub_admins enable row level security;
revoke all on table public.hub_admins from public, anon, authenticated;

-- Security-definer function checks the current authenticated user.
create or replace function public.hub_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.hub_admins a
    where a.user_id = auth.uid()
  );
$$;

revoke all on function public.hub_is_admin() from public, anon;
grant execute on function public.hub_is_admin() to authenticated;

-- 2) Add the teacher to the allow-list if the Auth user already exists.
-- If no row is inserted, create the user in Authentication > Users first,
-- then run this INSERT statement again.
insert into public.hub_admins (user_id, email)
select id, lower(email)
from auth.users
where lower(email) = lower('pratchaya.piw@gmail.com')
on conflict (user_id) do update
set email = excluded.email;

-- 3) Dashboard remains publicly viewable, but only the allow-listed
-- authenticated teacher can insert/update/delete its content.
alter table public.hub_pages enable row level security;

drop policy if exists "hub pages are public to read" on public.hub_pages;
drop policy if exists "hub pages public read" on public.hub_pages;
drop policy if exists "hub pages admin write" on public.hub_pages;

create policy "hub pages public read"
on public.hub_pages
for select
to anon, authenticated
using (true);

create policy "hub pages admin write"
on public.hub_pages
for all
to authenticated
using (public.hub_is_admin())
with check (public.hub_is_admin());

grant select on public.hub_pages to anon, authenticated;
grant insert, update, delete on public.hub_pages to authenticated;

-- 4) Ensure the main Dashboard row exists without changing existing data.
insert into public.hub_pages (id, data)
values ('main', '{}'::jsonb)
on conflict (id) do nothing;

-- 5) Disable browser access to legacy PIN RPCs.
-- Keep the legacy records/functions for rollback; do not delete them yet.
do $$
begin
  if to_regprocedure('public.hub_check_pin(text,text)') is not null then
    execute 'revoke all on function public.hub_check_pin(text,text) from public, anon, authenticated';
  end if;

  if to_regprocedure('public.hub_save(text,text,jsonb,timestamp with time zone)') is not null then
    execute 'revoke all on function public.hub_save(text,text,jsonb,timestamp with time zone) from public, anon, authenticated';
  end if;

  if to_regprocedure('public.hub_change_pin(text,text,text)') is not null then
    execute 'revoke all on function public.hub_change_pin(text,text,text) from public, anon, authenticated';
  end if;
end $$;

commit;

-- 6) Verification: expected result is exactly one row for the teacher.
select email, user_id
from public.hub_admins
where lower(email) = lower('pratchaya.piw@gmail.com');
