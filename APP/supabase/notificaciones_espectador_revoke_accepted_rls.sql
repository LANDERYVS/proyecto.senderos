DROP POLICY IF EXISTS "requesters_can_revoke_accepted_location_requests"
ON public.notificaciones_espectador;
CREATE POLICY "requesters_can_revoke_accepted_location_requests"
ON public.notificaciones_espectador
FOR DELETE
TO authenticated
USING (
  user_id = (SELECT auth.uid())
  AND estado = 'aceptada'
);
