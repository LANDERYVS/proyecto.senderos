-- Crear tabla de logros
create table public.logros (
  id text primary key,
  name text not null,
  description text,
  event text,
  target int default 1,
  points int default 10,
  category text default 'General',
  rarity text default 'common',
  created_at timestamptz default now()
);

-- Habilitar RLS
alter table public.logros enable row level security;

-- Permitir lectura de logros para usuarios autenticados o anónimos
create policy "logros_visible_para_todos"
on public.logros
for select
using (true);

-- Insertar logros iniciales de ejemplo
insert into public.logros (id, name, description, event, target, points, category, rarity)
values
  ('first_trail', 'Creaste tu primer sendero', 'Graba y guarda tu primer sendero.', 'first_trail_created', 1, 10, 'Senderismo', 'common'),
  ('explorer', 'Explorador', 'Descubre 5 senderos', 'trail_explored', 5, 25, 'Exploración', 'common'),
  ('distance_10k', 'Kilómetro 10', 'Completa 10 km en senderos', 'distance_traveled', 10, 40, 'Distancia', 'rare'),
  ('social', 'Conectado', 'Añade 3 amigos', 'friend_added', 3, 30, 'Social', 'uncommon'),
  ('route_lover', 'Amante de rutas', 'Guarda 5 rutas favoritas', 'favorite_saved', 5, 35, 'Colección', 'epic')
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  event = excluded.event,
  target = excluded.target,
  points = excluded.points,
  category = excluded.category,
  rarity = excluded.rarity;
