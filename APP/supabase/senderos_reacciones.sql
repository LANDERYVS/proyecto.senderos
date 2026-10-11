create or replace function public.increment_sendero_reaction(
  p_sendero_id bigint,
  p_reaction text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_likes bigint;
  v_dislikes bigint;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  if p_reaction is null or p_reaction not in ('like', 'dislike') then
    raise exception 'Reaction must be like or dislike'
      using errcode = '22023';
  end if;

  update public.senderos
  set likes = coalesce(likes, 0) +
        case when p_reaction = 'like' then 1 else 0 end,
      dislikes = coalesce(dislikes, 0) +
        case when p_reaction = 'dislike' then 1 else 0 end
  where id = p_sendero_id
  returning likes, dislikes into v_likes, v_dislikes;

  if not found then
    raise exception 'Trail not found'
      using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'likes', v_likes,
    'dislikes', v_dislikes
  );
end;
$$;

create or replace function public.decrement_sendero_reaction(
  p_sendero_id bigint,
  p_reaction text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_likes bigint;
  v_dislikes bigint;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  if p_reaction is null or p_reaction not in ('like', 'dislike') then
    raise exception 'Reaction must be like or dislike'
      using errcode = '22023';
  end if;

  update public.senderos
  set likes = case
        when p_reaction = 'like' then greatest(coalesce(likes, 0) - 1, 0)
        else coalesce(likes, 0)
      end,
      dislikes = case
        when p_reaction = 'dislike' then greatest(coalesce(dislikes, 0) - 1, 0)
        else coalesce(dislikes, 0)
      end
  where id = p_sendero_id
  returning likes, dislikes into v_likes, v_dislikes;

  if not found then
    raise exception 'Trail not found'
      using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'likes', v_likes,
    'dislikes', v_dislikes
  );
end;
$$;

revoke all on function public.increment_sendero_reaction(bigint, text)
  from public;
revoke all on function public.increment_sendero_reaction(bigint, text)
  from anon;
grant execute on function public.increment_sendero_reaction(bigint, text)
  to authenticated;

revoke all on function public.decrement_sendero_reaction(bigint, text)
  from public;
revoke all on function public.decrement_sendero_reaction(bigint, text)
  from anon;
grant execute on function public.decrement_sendero_reaction(bigint, text)
  to authenticated;
