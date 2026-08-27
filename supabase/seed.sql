delete from public.deployments where deployment_code = 'DEP-120';

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
  'INC-B1023-ROUTE-300',
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
