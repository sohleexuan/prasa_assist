begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;
select no_plan();

select has_table('public', 'incidents', 'incidents table exists');
select has_table(
  'public',
  'incident_status_history',
  'incident status history table exists'
);
select col_is_pk('public', 'incidents', 'id', 'internal UUID is primary key');
select col_is_unique(
  'public',
  'incidents',
  'incident_code',
  'public incident code is unique'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_info
    where constraint_info.conrelid =
        'public.incident_status_history'::regclass
      and constraint_info.contype = 'f'
      and constraint_info.confrelid = 'public.incidents'::regclass
      and constraint_info.confdeltype = 'r'
  ),
  'status history has a restrictive Incident foreign key'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.incidents'::regclass),
  'RLS is enabled on incidents'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.incident_status_history'::regclass
  ),
  'RLS is enabled on incident status history'
);
select ok(
  has_table_privilege('authenticated', 'public.incidents', 'SELECT'),
  'authenticated may select incidents'
);
select ok(
  not has_table_privilege('anon', 'public.incidents', 'SELECT'),
  'anon receives no Incident SELECT'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.incidents',
    'INSERT,UPDATE,DELETE'
  ),
  'authenticated direct Incident writes are denied'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.save_incident(jsonb,bigint)',
    'EXECUTE'
  ),
  'authenticated may execute save_incident'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.transition_incident(text,text,text,bigint)',
    'EXECUTE'
  ),
  'authenticated may execute transition_incident'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.save_incident(jsonb,bigint)',
    'EXECUTE'
  ),
  'anon cannot execute save_incident'
);
select is(
  (
    select proconfig
    from pg_proc
    where oid = 'public.save_incident(jsonb,bigint)'::regprocedure
  ),
  array['search_path=""']::text[],
  'save_incident fixes an empty search_path'
);

select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-1111-1111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","email":"incident.tester@example.com"}',
  true
);

set local role authenticated;
select lives_ok(
  $$ select count(*) from public.incidents $$,
  'authenticated staff can select incidents'
);
select throws_ok(
  $$
    insert into public.incidents (
      incident_code,
      incident_type,
      title,
      description,
      route_id,
      location,
      reported_at,
      severity,
      vehicle_condition,
      disruption_scope,
      estimated_delay_minutes,
      impact_level,
      estimation_reasons,
      reported_by_label,
      created_by,
      updated_by
    ) values (
      'DIRECT-INSERT',
      'other',
      'Direct write',
      'Direct writes must be rejected.',
      '300',
      'Test location',
      '2026-01-01T00:00:00Z',
      'low',
      'unknown',
      'unknown',
      5,
      'minor',
      array['Test reason'],
      'tester',
      '11111111-1111-1111-1111-111111111111',
      '11111111-1111-1111-1111-111111111111'
    )
  $$,
  '42501',
  null,
  'authenticated direct INSERT fails'
);
select lives_ok(
  $$
    select public.save_incident(
      '{
        "incident_type":"vehicle_breakdown",
        "title":"Test bus breakdown",
        "description":"A test bus is immobilised on the approved route.",
        "route_id":"TEST-300",
        "route_name":"Test Route 300",
        "vehicle_id":" test-bus-01 ",
        "location":"Test location",
        "reported_at":"2026-01-01T00:00:00Z",
        "severity":"high",
        "vehicle_condition":"immobilised",
        "disruption_scope":"partial_obstruction",
        "estimated_delay_minutes":75,
        "impact_level":"severe",
        "estimation_reasons":["Vehicle cannot move."]
      }'::jsonb,
      null
    )
  $$,
  'authenticated staff can create through save_incident'
);
reset role;

select ok(
  (
    select incident_code ~ '^INC-[0-9]{8}-[0-9]{6}$'
      and status = 'reported'
      and version = 1
      and vehicle_id = 'TEST-BUS-01'
      and reported_by_label = 'incident.tester@example.com'
    from public.incidents
    where route_id = 'TEST-300'
  ),
  'create normalizes values and owns code, status, audit label and version'
);
select is(
  (
    select count(*)
    from public.incident_status_history as history
    join public.incidents as incident on incident.id = history.incident_id
    where incident.route_id = 'TEST-300'
  ),
  1::bigint,
  'create writes the initial status history row'
);

select throws_ok(
  $$
    select public.save_incident(
      jsonb_build_object(
        'incident_code', incident_code,
        'incident_type', incident_type,
        'title', title,
        'description', description,
        'route_id', route_id,
        'route_name', route_name,
        'vehicle_id', vehicle_id,
        'location', location,
        'reported_at', reported_at,
        'severity', severity,
        'vehicle_condition', vehicle_condition,
        'disruption_scope', disruption_scope,
        'estimated_delay_minutes', estimated_delay_minutes,
        'impact_level', impact_level,
        'estimation_reasons', to_jsonb(estimation_reasons)
      ),
      0
    )
    from public.incidents where route_id = 'TEST-300'
  $$,
  '40001',
  'Incident version conflict.',
  'stale optimistic version is rejected'
);

select lives_ok(
  $$
    select public.save_incident(
      jsonb_build_object(
        'incident_code', incident_code,
        'incident_type', incident_type,
        'title', 'Updated test bus breakdown',
        'description', description,
        'route_id', route_id,
        'route_name', route_name,
        'vehicle_id', vehicle_id,
        'location', location,
        'reported_at', reported_at,
        'severity', severity,
        'vehicle_condition', vehicle_condition,
        'disruption_scope', disruption_scope,
        'estimated_delay_minutes', estimated_delay_minutes,
        'impact_level', impact_level,
        'estimation_reasons', to_jsonb(estimation_reasons)
      ),
      version
    )
    from public.incidents where route_id = 'TEST-300'
  $$,
  'valid Incident editing succeeds'
);
select is(
  (select version from public.incidents where route_id = 'TEST-300'),
  2::bigint,
  'editing increments version exactly once'
);

select lives_ok(
  $$
    select public.transition_incident(
      incident_code,
      'under_review',
      'Staff acknowledged the incident.',
      version
    )
    from public.incidents where route_id = 'TEST-300'
  $$,
  'reported to under_review succeeds'
);
select is(
  (select status from public.incidents where route_id = 'TEST-300'),
  'under_review',
  'status transition persists'
);
select is(
  (
    select count(*)
    from public.incident_status_history as history
    join public.incidents as incident on incident.id = history.incident_id
    where incident.route_id = 'TEST-300'
  ),
  2::bigint,
  'status transition appends history'
);
select throws_ok(
  $$
    select public.transition_incident(
      incident_code,
      'resolved',
      null,
      version
    )
    from public.incidents where route_id = 'TEST-300'
  $$,
  '22023',
  'Invalid incident status transition from under_review to resolved.',
  'unapproved status transition is rejected'
);

set local role authenticated;
select throws_ok(
  $$ delete from public.incidents where route_id = 'TEST-300' $$,
  '42501',
  null,
  'authenticated direct physical delete fails'
);
reset role;
select ok(
  not exists (
    select 1
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname ~* 'delete.*incident|incident.*delete'
  ),
  'no production physical-delete RPC exists'
);
select is(
  (
    select linked_incident_ref
    from public.deployments
    where deployment_code = 'DEP-120'
  ),
  'INC-20260828-001',
  'shared demo deployment references the approved Incident code'
);

select * from finish();
rollback;
