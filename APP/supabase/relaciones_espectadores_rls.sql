DROP POLICY IF EXISTS "sharers_can_update_relations"
ON public.relaciones_espectadores;
CREATE POLICY "sharers_can_update_relations"
ON public.relaciones_espectadores
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.amistades AS friendship
    WHERE friendship.id = relaciones_espectadores.amistad
      AND (
        (friendship.users_id = (SELECT auth.uid())
          AND friendship.target_id = relaciones_espectadores.espectador_id)
        OR
        (friendship.target_id = (SELECT auth.uid())
          AND friendship.users_id = relaciones_espectadores.espectador_id)
      )
  )
  AND EXISTS (
    SELECT 1
    FROM public.notificaciones_espectador AS request
    WHERE request.user_id = (SELECT auth.uid())
      AND request.target_id = relaciones_espectadores.espectador_id
      AND request.estado = 'aceptada'
  )
)
WITH CHECK (
  enabled IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM public.amistades AS friendship
    WHERE friendship.id = relaciones_espectadores.amistad
      AND (
        (friendship.users_id = (SELECT auth.uid())
          AND friendship.target_id = relaciones_espectadores.espectador_id)
        OR
        (friendship.target_id = (SELECT auth.uid())
          AND friendship.users_id = relaciones_espectadores.espectador_id)
      )
  )
  AND EXISTS (
    SELECT 1
    FROM public.notificaciones_espectador AS request
    WHERE request.user_id = (SELECT auth.uid())
      AND request.target_id = relaciones_espectadores.espectador_id
      AND request.estado = 'aceptada'
  )
);

DROP POLICY IF EXISTS "sharers_can_delete_relations"
ON public.relaciones_espectadores;
CREATE POLICY "sharers_can_delete_relations"
ON public.relaciones_espectadores
FOR DELETE
TO authenticated
USING (
  enabled IS FALSE
  AND EXISTS (
    SELECT 1
    FROM public.amistades AS friendship
    WHERE friendship.id = relaciones_espectadores.amistad
      AND (
        (friendship.users_id = (SELECT auth.uid())
          AND friendship.target_id = relaciones_espectadores.espectador_id)
        OR
        (friendship.target_id = (SELECT auth.uid())
          AND friendship.users_id = relaciones_espectadores.espectador_id)
      )
  )
);
