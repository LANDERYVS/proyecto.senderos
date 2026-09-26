create table if not exists public.senderos_favoritos (
  user_id uuid not null references auth.users(id) on delete cascade,
  sendero_id bigint not null references public.senderos(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, sendero_id)
);

alter table public.senderos_favoritos enable row level security;

grant select, insert, delete on table public.senderos_favoritos to authenticated;

drop policy if exists "Cada usuario ve sus favoritos"
on public.senderos_favoritos;
create policy "Cada usuario ve sus favoritos"
on public.senderos_favoritos for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "Cada usuario agrega sus favoritos"
on public.senderos_favoritos;
create policy "Cada usuario agrega sus favoritos"
on public.senderos_favoritos for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Cada usuario elimina sus favoritos"
on public.senderos_favoritos;
create policy "Cada usuario elimina sus favoritos"
on public.senderos_favoritos for delete to authenticated
using (auth.uid() = user_id);