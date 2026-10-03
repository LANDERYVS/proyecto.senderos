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
    where lower(trim(requisito)) <> 'todos_los_logros'
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
      when 'amigos' then (
        select count(distinct case
          when friendship.users_id = auth.uid() then friendship.target_id
          else friendship.users_id
        end)::numeric
        from public.amistades as friendship
        where friendship.users_id = auth.uid()
          or friendship.target_id = auth.uid()
      )
      when 'espectador' then (
        select count(distinct spectator.amistad)::numeric
        from public.relaciones_espectadores as spectator
        where spectator.espectador_id = auth.uid()
          and spectator.enabled = true
      )
      else null
    end;

    if current_value is null or current_value < achievement_row.valor_logro then
      continue;
    end if;

    inserted_id := null;
    insert into public.user_logros (user_id, logro_id)
    values (auth.uid(), achievement_row.id)
    on conflict do nothing
    returning id into inserted_id;

    if inserted_id is not null then
      logro_id := achievement_row.id;
      return next;
    end if;
  end loop;

  for achievement_row in
    select id
    from public.logros
    where lower(trim(requisito)) = 'todos_los_logros'
  loop
    current_value := (
      select count(*)::numeric
      from public.user_logros as earned
      where earned.user_id = auth.uid()
        and earned.logro_id <> achievement_row.id
    );

    if current_value < (
      select count(*)::numeric
      from public.logros as achievement
      where achievement.id <> achievement_row.id
    ) then
      continue;
    end if;

    inserted_id := null;
    insert into public.user_logros (user_id, logro_id)
    values (auth.uid(), achievement_row.id)
    on conflict do nothing
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
select 'Amiguero', 'Consigue 5 amigos.', 'amigos', 5
where not exists (
  select 1 from public.logros where requisito = 'amigos' and valor_logro = 5
);

insert into public.logros (nombre, descripcion, requisito, valor_logro)
select 'Caminante de 10 km', 'Recorre senderos que sumen 10 km.', 'distancia_km', 10
where not exists (
  select 1 from public.logros where requisito = 'distancia_km' and valor_logro = 10
);

insert into public.logros (nombre, descripcion, requisito, valor_logro)
select 'Ojos en el camino', 'Sé espectador de alguien que comparte su ubicación contigo.', 'espectador', 1
where not exists (
  select 1 from public.logros where requisito = 'espectador' and valor_logro = 1
);

insert into public.logros (nombre, descripcion, requisito, valor_logro)
select 'Coleccionista de logros', 'Consigue todos los demás logros.', 'todos_los_logros', 1
where not exists (
  select 1 from public.logros where requisito = 'todos_los_logros'
);
