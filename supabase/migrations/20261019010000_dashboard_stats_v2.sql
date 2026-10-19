-- ==============================================================================
-- AgroTrade Direct — Migración 0011: Estadísticas agregadas del panel (v2)
-- REQ-47 / D1: el personal solo ve agregados de las negociaciones.
-- REQ-37: datos para el dashboard de KPIs.
--
-- admin_dashboard_stats() conserva sus claves anteriores (compatibles con
-- DashboardStats de Flutter) y agrega conteos por estado, métricas por
-- producto, desempeño y una serie mensual.
--
-- Protección contra la reidentificación: un promedio o total sobre muy pocos
-- tratos revela el precio de un trato concreto. Por eso los MONTOS (precio
-- promedio, volumen, valor) y los promedios de desempeño solo se entregan
-- cuando el grupo tiene al menos 3 tratos confirmados (minGroupSize); si no,
-- llegan como null. Los conteos siempre se entregan.
--
-- Supresión complementaria: si algún producto tiene entre 1 y 2 tratos, los
-- totales generales también se ocultan; si no, "total − café" revelaría el
-- valor exacto de los tratos de cacao.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS JSON AS $$
DECLARE
  c_min CONSTANT INT := 3;
  v_confirmed INT;
  v_closed INT;
  v_show_totals BOOLEAN;
BEGIN
  IF NOT public.has_permission('dashboard') THEN
    RAISE EXCEPTION 'Requiere el permiso dashboard';
  END IF;

  SELECT count(*) FILTER (WHERE status = 'confirmed'),
         count(*) FILTER (WHERE status IN ('confirmed', 'rejected', 'cancelled'))
  INTO v_confirmed, v_closed
  FROM public.negotiations;

  -- Totales generales: al menos c_min tratos y ningún producto con 1 a c_min-1
  -- tratos (supresión complementaria).
  SELECT v_confirmed >= c_min AND NOT EXISTS (
    SELECT 1
    FROM public.negotiations n
    JOIN public.offers o ON o.id = n.offer_id
    WHERE n.status = 'confirmed'
    GROUP BY o.crop_type
    HAVING count(*) < c_min
  ) INTO v_show_totals;

  RETURN json_build_object(
    'minGroupSize', c_min,

    -- Claves anteriores (DashboardStats)
    'totalUsers', (SELECT count(*) FROM public.profiles WHERE role IN ('exportador', 'importador')),
    'activeOffers', (SELECT count(*) FROM public.offers WHERE status IN ('activa', 'negociando')),
    'activeNegotiations', (SELECT count(*) FROM public.negotiations WHERE status IN ('pending', 'countered', 'accepted')),
    'blockedUsers', (SELECT count(*) FROM public.blocked_users),
    'pendingAlerts', (SELECT count(*) FROM public.suspicious_activities WHERE status = 'pendiente'),
    'totalVolumeMt', CASE WHEN v_show_totals THEN
      (SELECT sum(requested_volume_mt) FROM public.negotiations WHERE status = 'confirmed') END,
    'totalValueUsd', CASE WHEN v_show_totals THEN
      (SELECT round(sum(requested_volume_mt * proposed_price_per_mt), 2) FROM public.negotiations WHERE status = 'confirmed') END,

    -- Conteos (siempre visibles)
    'usersByRole', json_build_object(
      'exportador', (SELECT count(*) FROM public.profiles WHERE role = 'exportador'),
      'importador', (SELECT count(*) FROM public.profiles WHERE role = 'importador')
    ),
    'offersByStatus', (
      SELECT json_object_agg(s.status, COALESCE(c.n, 0) ORDER BY s.pos)
      FROM unnest(ARRAY['activa', 'negociando', 'confirmada', 'enTransito', 'cerrada'])
           WITH ORDINALITY AS s(status, pos)
      LEFT JOIN (SELECT status, count(*) AS n FROM public.offers GROUP BY status) c
        ON c.status = s.status
    ),
    'negotiationsByStatus', (
      SELECT json_object_agg(s.status, COALESCE(c.n, 0) ORDER BY s.pos)
      FROM unnest(ARRAY['pending', 'countered', 'accepted', 'confirmed', 'rejected', 'cancelled'])
           WITH ORDINALITY AS s(status, pos)
      LEFT JOIN (SELECT status, count(*) AS n FROM public.negotiations GROUP BY status) c
        ON c.status = s.status
    ),
    'pendingReports', (SELECT count(*) FROM public.user_reports WHERE status = 'pendiente'),
    'pendingCertifications', (SELECT count(*) FROM public.certifications WHERE status = 'pending'),

    -- Por producto: montos solo con al menos c_min tratos
    'confirmedByCrop', (
      SELECT json_agg(json_build_object(
        'cropType', g.crop,
        'deals', g.deals,
        'volumeMt', CASE WHEN g.deals >= c_min THEN g.volume END,
        'valueUsd', CASE WHEN g.deals >= c_min THEN round(g.value, 2) END,
        'avgPricePerMt', CASE WHEN g.deals >= c_min THEN round(g.value / g.volume, 2) END
      ) ORDER BY g.pos)
      FROM (
        SELECT k.crop, k.pos,
               count(n.id) AS deals,
               sum(n.requested_volume_mt) AS volume,
               sum(n.requested_volume_mt * n.proposed_price_per_mt) AS value
        FROM unnest(ARRAY['cafe', 'cacao']) WITH ORDINALITY AS k(crop, pos)
        LEFT JOIN public.offers o ON o.crop_type = k.crop
        LEFT JOIN public.negotiations n ON n.offer_id = o.id AND n.status = 'confirmed'
        GROUP BY k.crop, k.pos
      ) g
    ),

    -- Desempeño
    'closeRate', CASE WHEN v_closed > 0 THEN round(v_confirmed::NUMERIC / v_closed, 3) END,
    'avgRoundsToClose', CASE WHEN v_confirmed >= c_min THEN
      (SELECT round(avg(round_count), 1) FROM public.negotiations WHERE status = 'confirmed') END,
    'avgHoursToConfirm', CASE WHEN v_confirmed >= c_min THEN
      (SELECT round((avg(extract(epoch FROM confirmed_at - created_at)) / 3600)::NUMERIC, 1)
       FROM public.negotiations WHERE status = 'confirmed') END,

    -- Serie mensual (últimos 6 meses, incluido el actual): solo conteos
    'confirmedByMonth', (
      SELECT json_agg(json_build_object(
        'month', to_char(m.month, 'YYYY-MM'),
        'deals', (SELECT count(*) FROM public.negotiations n
                  WHERE n.status = 'confirmed'
                    AND date_trunc('month', n.confirmed_at) = m.month)
      ) ORDER BY m.month)
      FROM generate_series(
        date_trunc('month', timezone('utc'::text, now())) - INTERVAL '5 months',
        date_trunc('month', timezone('utc'::text, now())),
        INTERVAL '1 month'
      ) AS m(month)
    )
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;
