-- Run this migration in the Supabase SQL Editor.
begin;

alter table public.usuarios
  add column if not exists kilometros_caminados double precision
  not null default 0;

revoke update on table public.usuarios from public, anon, authenticated;
grant update (name, telefono, user_photo)
  on table public.usuarios to authenticated;

drop function if exists public.record_walking_distance(uuid, double precision);

create or replace function public.claim_eligible_achievements()
returns table (logro_id bigint)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_published_trails bigint;
  v_distance_km double precision;
  v_waypoints bigint;
  v_friends bigint;
  v_spectator bigint;
  v_achievement_count bigint;
  v_earned_count bigint;
  v_new_ids bigint[];
  v_new_id bigint;
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesión autenticada.'
      using errcode = '28000';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );

  select count(*)
    into v_published_trails
    from public.senderos as s
    where s.user_id = v_user_id;

  select coalesce(u.kilometros_caminados, 0)
    into v_distance_km
    from public.usuarios as u
    where u.id = v_user_id;

  select count(*)
    into v_waypoints
    from public.waypoint as w
    join public.senderos as s on s.id = w.sendero_id
    where s.user_id = v_user_id;

  select count(*)
    into v_friends
    from public.amistades as a
    where a.users_id = v_user_id or a.target_id = v_user_id;

  select count(*)
    into v_spectator
    from public.relaciones_espectadores as r
    where r.espectador_id = v_user_id
      and r.enabled is true;

  select count(*)
    into v_achievement_count
    from public.logros;

  loop
    select count(*)
      into v_earned_count
      from public.user_logros as ul
      where ul.user_id = v_user_id;

    with eligible as (
      select
        l.id,
        lower(btrim(coalesce(l.requisito, ''))) as requirement,
        case
          when lower(btrim(coalesce(l.requisito, ''))) = 'todos_los_logros'
            then greatest(v_achievement_count - 1, 0)::double precision
          else coalesce(l.valor_logro, 0)
        end as target
      from public.logros as l
    ),
    inserted as (
      insert into public.user_logros (user_id, logro_id)
      select v_user_id, e.id
      from eligible as e
      where case e.requirement
        when 'senderos_publicados' then v_published_trails >= e.target
        when 'rutas_publicadas' then v_published_trails >= e.target
        when 'distancia_km' then v_distance_km >= e.target
        when 'distancia_total_km' then v_distance_km >= e.target
        when 'waypoints' then v_waypoints >= e.target
        when 'waypoints_guardados' then v_waypoints >= e.target
        when 'amigos' then v_friends >= e.target
        when 'espectador' then v_spectator >= e.target
        when 'todos_los_logros' then v_earned_count >= e.target
        else false
      end
      and not exists (
        select 1
        from public.user_logros as existing
        where existing.user_id = v_user_id
          and existing.logro_id = e.id
      )
      returning user_logros.logro_id
    )
    select array_agg(inserted.logro_id)
      into v_new_ids
      from inserted;

    exit when v_new_ids is null;

    foreach v_new_id in array v_new_ids loop
      logro_id := v_new_id;
      return next;
    end loop;
  end loop;
end;
$function$;

create or replace function public.record_walking_distance(
  p_distance_km double precision
)
returns double precision
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_total_distance double precision;
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesión autenticada.'
      using errcode = '28000';
  end if;

  if p_distance_km is null
    or p_distance_km <= 0
    or p_distance_km >= 'Infinity'::double precision then
    raise exception 'La distancia debe ser válida y mayor que cero.'
      using errcode = '22023';
  end if;

  update public.usuarios as u
    set kilometros_caminados =
      coalesce(u.kilometros_caminados, 0) + p_distance_km
    where u.id = v_user_id
    returning u.kilometros_caminados into v_total_distance;

  if not found then
    raise exception 'No existe el perfil del usuario autenticado.'
      using errcode = 'P0002';
  end if;

  perform *
    from public.claim_eligible_achievements();

  return v_total_distance;
end;
$function$;

revoke all on function public.claim_eligible_achievements() from public, anon;
grant execute on function public.claim_eligible_achievements() to authenticated;

revoke all on function public.record_walking_distance(double precision)
  from public, anon;
grant execute on function public.record_walking_distance(double precision)
  to authenticated;

commit;