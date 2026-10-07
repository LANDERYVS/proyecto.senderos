-- Allow an authenticated user to update only their own editable profile fields.
-- Run this script in the Supabase SQL Editor.
alter table public.usuarios enable row level security;

drop policy if exists "Users can view own profile" on public.usuarios;
create policy "Users can view own profile"
  on public.usuarios
  as permissive
  for select
  to authenticated
  using (auth.uid() = id);

revoke update on table public.usuarios from public, anon, authenticated;
grant update (name, telefono, user_photo)
  on table public.usuarios to authenticated;

drop policy if exists "Users can update own profile" on public.usuarios;
create policy "Users can update own profile"
  on public.usuarios
  as permissive
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users can only update their own profile" on public.usuarios;
create policy "Users can only update their own profile"
  on public.usuarios
  as restrictive
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);
