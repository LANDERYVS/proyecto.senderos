create unique index if not exists user_logros_user_id_logro_id_uidx
  on public.user_logros (user_id, logro_id);

alter table public.logros enable row level security;
alter table public.user_logros enable row level security;
alter table public.senderos enable row level security;
alter table public.waypoint enable row level security;

drop policy if exists logros_read_authenticated on public.logros;
create policy logros_read_authenticated
  on public.logros
  for select
  to authenticated
  using (true);

drop policy if exists user_logros_read_own on public.user_logros;
create policy user_logros_read_own
  on public.user_logros
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists achievement_senderos_read_own on public.senderos;
create policy achievement_senderos_read_own
  on public.senderos
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists achievement_waypoints_read_own on public.waypoint;
create policy achievement_waypoints_read_own
  on public.waypoint
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.senderos
      where senderos.id = waypoint.sendero_id
        and senderos.user_id = (select auth.uid())
    )
  );

grant select on public.logros to authenticated;
grant select on public.user_logros to authenticated;
grant select on public.senderos, public.waypoint to authenticated;
revoke insert, update, delete on public.user_logros from authenticated;

create or replace function public.claim_eligible_achievements()
returns table (logro_id bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  achievement_row record;
  current_value numeric;
  inserted_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

  for achievement_row in
    select id, requisito, valor_logro
    from public.logros
  loop
    current_value := case lower(trim(achievement_row.requisito))
      when 'senderos_publicados' then (
        select count(*)::numeric
        from public.senderos
        where user_id = auth.uid()
      )
      when 'rutas_publicadas' then (
        select count(*)::numeric
        from public.senderos
        where user_id = auth.uid()
      )
      when 'distancia_km' then (
        select coalesce(sum(distancia), 0)::numeric
        from public.senderos
        where user_id = auth.uid()
      )
      when 'distancia_total_km' then (
        select coalesce(sum(distancia), 0)::numeric
        from public.senderos
        where user_id = auth.uid()
      )
      when 'waypoints' then (
        select count(*)::numeric
        from public.waypoint as waypoint_row
        join public.senderos as trail_row
          on trail_row.id = waypoint_row.sendero_id
        where trail_row.user_id = auth.uid()
      )
      when 'waypoints_guardados' then (
        select count(*)::numeric
        from public.waypoint as waypoint_row
        join public.senderos as trail_row
          on trail_row.id = waypoint_row.sendero_id
        where trail_row.user_id = auth.uid()
      )
      else null
    end;

    if current_value is null or current_value < achievement_row.valor_logro then
      continue;
    end if;

    inserted_id := null;
    insert into public.user_logros (user_id, logro_id)
    values (auth.uid(), achievement_row.id)
    on conflict (user_id, logro_id) do nothing
    returning id into inserted_id;

    if inserted_id is not null then
      logro_id := achievement_row.id;
      return next;
    end if;
  end loop;
end;
$$;

revoke all on function public.claim_eligible_achievements() from public, anon;
grant execute on function public.claim_eligible_achievements() to authenticated;

insert into public.logros (nombre, descripcion, requisito, valor_logro)
select 'Primer sendero', 'Publica tu primer sendero.', 'senderos_publicados', 1
where not exists (
  select 1 from public.logros
  where requisito = 'senderos_publicados' and valor_logro = 1
);

insert into public.logros (nombre, descripcion, requisito, valor_logro)
select 'Kilómetros recorridos', 'Publica senderos que sumen 25 km.', 'distancia_km', 25
where not exists (
  select 1 from public.logros
  where requisito = 'distancia_km' and valor_logro = 25
);

insert into public.logros (nombre, descripcion, requisito, valor_logro)
select 'Explorador de puntos', 'Guarda 5 waypoints en tus senderos.', 'waypoints', 5
where not exists (
  select 1 from public.logros
  where requisito = 'waypoints' and valor_logro = 5
);