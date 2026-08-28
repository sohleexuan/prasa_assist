delete from public.deployments where deployment_code = 'DEP-120';

delete from public.incident_status_history
where incident_id in (
  select id from public.incidents where incident_code = 'INC-20260828-001'
);
delete from public.incidents where incident_code = 'INC-20260828-001';

insert into public.incidents (
  id,
  incident_code,
  incident_type,
  title,
  description,
  route_id,
  route_name,
  vehicle_id,
  location,
  reported_at,
  severity,
  status,
  vehicle_condition,
  disruption_scope,
  estimated_delay_minutes,
  impact_level,
  estimation_reasons,
  estimation_model_version,
  data_source,
  reported_by_label,
  created_by,
  updated_by,
  created_at,
  updated_at,
  version
) values (
  '00000000-0000-0000-0000-000000000001',
  'INC-20260828-001',
  'vehicle_breakdown',
  'Bus B1023 breakdown',
  'Bus B1023 became immobilised during the Route 300 peak-hour demonstration scenario.',
  '300',
  'Route 300',
  'B1023',
  'Route 300 demonstration location',
  '2026-08-28 07:55:00+08',
  'high',
  'reported',
  'immobilised',
  'partial_obstruction',
  75,
  'severe',
  array[
    'Vehicle Breakdown base: 10 minutes.',
    'High severity adjustment: +15 minutes.',
    'Immobilised vehicle adjustment: +25 minutes.',
    'Partial Obstruction adjustment: +10 minutes.',
    'Weekday peak-hour multiplier: ×1.25.'
  ],
  1,
  'mock_demonstration',
  'Demo Operations Staff',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '2026-08-28 08:00:00+08',
  '2026-08-28 08:00:00+08',
  1
);

insert into public.incident_status_history (
  incident_id,
  sequence_no,
  from_status,
  to_status,
  changed_at,
  changed_by,
  changed_by_label,
  note
) values (
  '00000000-0000-0000-0000-000000000001',
  1,
  null,
  'reported',
  '2026-08-28 08:00:00+08',
  '00000000-0000-0000-0000-000000000001',
  'Demo Operations Staff',
  'Mock incident for the shared demonstration scenario.'
);

insert into public.deployments (
  id,
  deployment_code,
  linked_incident_ref,
  linked_recommendation_ref,
  route_id,
  route_name,
  start_time,
  end_time,
  status,
  purpose,
  created_by,
  updated_by,
  created_at,
  updated_at,
  version
) values (
  '00000000-0000-0000-0000-000000000120',
  'DEP-120',
  'INC-20260828-001',
  'REC-B1023-ROUTE-300',
  '300',
  'Route 300',
  '2026-08-28 08:00:00+08',
  '2026-08-28 10:00:00+08',
  'scheduled',
  'Deploy 2 replacement buses to replace unavailable Bus B1023 and restore service capacity',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '2026-08-28 07:45:00+08',
  '2026-08-28 07:45:00+08',
  1
);

insert into public.deployment_vehicles (
  deployment_id,
  vehicle_id,
  assigned_at,
  sequence_no
) values
  (
    '00000000-0000-0000-0000-000000000120',
    'REPLACEMENT-BUS-01',
    '2026-08-28 07:45:00+08',
    1
  ),
  (
    '00000000-0000-0000-0000-000000000120',
    'REPLACEMENT-BUS-02',
    '2026-08-28 07:45:00+08',
    2
  );

select setval(
  'public.deployment_code_seq',
  greatest(
    120,
    coalesce(
      (
        select max(substring(deployment_code from '^DEP-([0-9]+)$')::bigint)
        from public.deployments
        where deployment_code ~ '^DEP-[0-9]+$'
      ),
      120
    )
  ),
  true
);

select setval(
  'public.incident_code_seq',
  greatest(
    1,
    coalesce(
      (
        select max(
          substring(incident_code from '^INC-[0-9]{8}-([0-9]+)$')::bigint
        )
        from public.incidents
        where incident_code ~ '^INC-[0-9]{8}-[0-9]+$'
      ),
      1
    )
  ),
  true
);
