begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;
select no_plan();

select has_table('public', 'deployments', 'deployments table exists');
select has_table(
  'public',
  'deployment_vehicles',
  'deployment_vehicles table exists'
);

select ok(
  not exists (
    select required.column_name
    from unnest(array[
      'id',
      'deployment_code',
      'linked_incident_ref',
      'linked_recommendation_ref',
      'route_id',
      'route_name',
      'start_time',
      'end_time',
      'status',
      'purpose',
      'created_by',
      'updated_by',
      'created_at',
      'updated_at',
      'version'
    ]) as required(column_name)
    where not exists (
      select 1
      from information_schema.columns as column_info
      where column_info.table_schema = 'public'
        and column_info.table_name = 'deployments'
        and column_info.column_name = required.column_name
    )
  ),
  'deployments has every approved column'
);

select ok(
  not exists (
    select required.column_name
    from unnest(array[
      'deployment_id',
      'vehicle_id',
      'assigned_at',
      'sequence_no'
    ]) as required(column_name)
    where not exists (
      select 1
      from information_schema.columns as column_info
      where column_info.table_schema = 'public'
        and column_info.table_name = 'deployment_vehicles'
        and column_info.column_name = required.column_name
    )
  ),
  'deployment_vehicles has every approved column'
);

select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'deployments'
      and column_name = 'requested_vehicle_count'
  ),
  'requested_vehicle_count is not stored'
);

select col_type_is('public', 'deployments', 'id', 'uuid', 'id is uuid');
select col_type_is(
  'public',
  'deployments',
  'deployment_code',
  'text',
  'deployment_code is text'
);
select col_type_is(
  'public',
  'deployments',
  'version',
  'bigint',
  'version is bigint'
);
select col_type_is(
  'public',
  'deployment_vehicles',
  'sequence_no',
  'smallint',
  'sequence_no is smallint'
);
select col_is_pk('public', 'deployments', 'id', 'internal UUID is primary key');
select col_is_pk(
  'public',
  'deployment_vehicles',
  array['deployment_id', 'vehicle_id'],
  'deployment vehicle identity is composite'
);
select col_is_unique(
  'public',
  'deployments',
  'deployment_code',
  'public deployment code is unique'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_info
    join pg_class as relation
      on relation.oid = constraint_info.conrelid
    join pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'deployment_vehicles'
      and constraint_info.contype = 'f'
      and constraint_info.confdeltype = 'c'
      and constraint_info.confrelid = 'public.deployments'::regclass
  ),
  'vehicle parent foreign key cascades on deployment deletion'
);

select ok(
  (
    select count(*) >= 7
    from pg_constraint
    where conrelid = 'public.deployments'::regclass
      and contype = 'c'
  ),
  'deployment validation constraints exist'
);
select ok(
  (
    select count(*) >= 2
    from pg_constraint
    where conrelid = 'public.deployment_vehicles'::regclass
      and contype = 'c'
  ),
  'vehicle validation constraints exist'
);

select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.deployments'::regclass
  ),
  'RLS is enabled on deployments'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.deployment_vehicles'::regclass
  ),
  'RLS is enabled on deployment_vehicles'
);

select ok(
  has_table_privilege('authenticated', 'public.deployments', 'SELECT'),
  'authenticated receives deployment SELECT'
);
select ok(
  has_table_privilege('authenticated', 'public.deployment_vehicles', 'SELECT'),
  'authenticated receives vehicle SELECT'
);
select ok(
  not has_table_privilege('anon', 'public.deployments', 'SELECT'),
  'anon receives no deployment SELECT'
);
select ok(
  not has_table_privilege('anon', 'public.deployment_vehicles', 'SELECT'),
  'anon receives no vehicle SELECT'
);

select ok(
  not has_table_privilege('authenticated', 'public.deployments', 'INSERT'),
  'authenticated direct deployment INSERT is denied'
);
select ok(
  not has_table_privilege('authenticated', 'public.deployments', 'UPDATE'),
  'authenticated direct deployment UPDATE is denied'
);
select ok(
  not has_table_privilege('authenticated', 'public.deployments', 'DELETE'),
  'authenticated direct deployment DELETE is denied'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.deployment_vehicles',
    'INSERT,UPDATE,DELETE'
  ),
  'authenticated direct vehicle writes are denied'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.save_deployment(jsonb,bigint)',
    'EXECUTE'
  ),
  'authenticated may execute save_deployment'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.transition_deployment(text,text,bigint)',
    'EXECUTE'
  ),
  'authenticated may execute transition_deployment'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.save_deployment(jsonb,bigint)',
    'EXECUTE'
  ),
  'anon cannot execute save_deployment'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.transition_deployment(text,text,bigint)',
    'EXECUTE'
  ),
  'anon cannot execute transition_deployment'
);
select ok(
  not exists (
    select 1
    from pg_proc as function_info
    cross join lateral aclexplode(
      coalesce(
        function_info.proacl,
        acldefault('f', function_info.proowner)
      )
    ) as privilege
    where function_info.oid = 'public.save_deployment(jsonb,bigint)'::regprocedure
      and privilege.grantee = 0
      and privilege.privilege_type = 'EXECUTE'
  ),
  'public cannot execute save_deployment'
);
select ok(
  not exists (
    select 1
    from pg_proc as function_info
    cross join lateral aclexplode(
      coalesce(
        function_info.proacl,
        acldefault('f', function_info.proowner)
      )
    ) as privilege
    where function_info.oid =
      'public.transition_deployment(text,text,bigint)'::regprocedure
      and privilege.grantee = 0
      and privilege.privilege_type = 'EXECUTE'
  ),
  'public cannot execute transition_deployment'
);

select is(
  (
    select proconfig
    from pg_proc
    where oid = 'public.save_deployment(jsonb,bigint)'::regprocedure
  ),
  array['search_path=""']::text[],
  'save_deployment fixes an empty search_path'
);
select is(
  (
    select proconfig
    from pg_proc
    where oid = 'public.transition_deployment(text,text,bigint)'::regprocedure
  ),
  array['search_path=""']::text[],
  'transition_deployment fixes an empty search_path'
);
select ok(
  pg_get_functiondef('public.save_deployment(jsonb,bigint)'::regprocedure)
    !~* '\mexecute\M',
  'save_deployment contains no dynamic SQL'
);
select ok(
  pg_get_functiondef(
    'public.transition_deployment(text,text,bigint)'::regprocedure
  ) !~* '\mexecute\M',
  'transition_deployment contains no dynamic SQL'
);

select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-1111-1111-111111111111',
  true
);

set local role authenticated;
select lives_ok(
  $$ select count(*) from public.deployments $$,
  'authenticated staff can select deployments'
);
select throws_ok(
  $$
    insert into public.deployments (
      deployment_code,
      route_id,
      route_name,
      start_time,
      end_time,
      purpose,
      created_by,
      updated_by
    ) values (
      'DIRECT-INSERT',
      '300',
      'Route 300',
      now(),
      now() + interval '1 hour',
      'Direct write must fail',
      '11111111-1111-1111-1111-111111111111',
      '11111111-1111-1111-1111-111111111111'
    )
  $$,
  '42501',
  null,
  'authenticated direct INSERT fails'
);
select throws_ok(
  $$ update public.deployments set purpose = 'Direct update' where deployment_code = 'DEP-120' $$,
  '42501',
  null,
  'authenticated direct UPDATE fails'
);
select throws_ok(
  $$ delete from public.deployments where deployment_code = 'DEP-120' $$,
  '42501',
  null,
  'authenticated direct DELETE fails'
);
select lives_ok(
  $$
    select public.save_deployment(
      '{
        "route_id":"TEST-300",
        "route_name":"Test Route 300",
        "start_time":"2026-09-01T08:00:00+08:00",
        "end_time":"2026-09-01T09:00:00+08:00",
        "purpose":"Create through authenticated RPC",
        "vehicle_ids":[" test-bus-01 ","TEST-BUS-02"]
      }'::jsonb,
      null
    )
  $$,
  'authenticated staff can create through save_deployment'
);
reset role;

set local role anon;
select throws_ok(
  $$ select count(*) from public.deployments $$,
  '42501',
  null,
  'anon SELECT is denied by privileges'
);
select throws_ok(
  $$
    select public.save_deployment(
      '{"route_id":"X"}'::jsonb,
      null
    )
  $$,
  '42501',
  null,
  'anon RPC execution is denied'
);
reset role;

select is(
  (
    select status
    from public.deployments
    where route_id = 'TEST-300'
  ),
  'draft',
  'create always starts at draft'
);
select is(
  (
    select version
    from public.deployments
    where route_id = 'TEST-300'
  ),
  1::bigint,
  'create always starts at version 1'
);
select ok(
  (
    select deployment_code ~ '^DEP-[0-9]+$'
      and deployment_code <> id::text
      and deployment_code <> 'DEP-120'
    from public.deployments
    where route_id = 'TEST-300'
  ),
  'public deployment code remains separate from internal UUID and seed code'
);
select is(
  (
    select array_agg(vehicle.vehicle_id order by vehicle.sequence_no)
    from public.deployment_vehicles as vehicle
    join public.deployments as deployment
      on deployment.id = vehicle.deployment_id
    where deployment.route_id = 'TEST-300'
  ),
  array['TEST-BUS-01', 'TEST-BUS-02']::text[],
  'save inserts ordered, normalized vehicle rows'
);

select throws_ok(
  $$
    select public.save_deployment(
      '{
        "route_id":"DUPLICATE",
        "route_name":"Duplicate test",
        "start_time":"2026-09-01T08:00:00+08:00",
        "end_time":"2026-09-01T09:00:00+08:00",
        "purpose":"Reject duplicates",
        "vehicle_ids":["BUS-1"," bus-1 "]
      }'::jsonb,
      null
    )
  $$,
  '22023',
  'Vehicle IDs must be unique after normalization.',
  'duplicate normalized vehicles are rejected'
);
select throws_ok(
  $$
    select public.save_deployment(
      '{
        "route_id":"BLANK",
        "route_name":"Blank vehicle test",
        "start_time":"2026-09-01T08:00:00+08:00",
        "end_time":"2026-09-01T09:00:00+08:00",
        "purpose":"Reject blank vehicle",
        "vehicle_ids":["  "]
      }'::jsonb,
      null
    )
  $$,
  '22023',
  'Vehicle IDs cannot be blank.',
  'blank vehicle IDs are rejected'
);
select throws_ok(
  $$
    select public.save_deployment(
      '{
        "route_id":"EMPTY",
        "route_name":"Empty vehicle test",
        "start_time":"2026-09-01T08:00:00+08:00",
        "end_time":"2026-09-01T09:00:00+08:00",
        "purpose":"Reject empty vehicle list",
        "vehicle_ids":[]
      }'::jsonb,
      null
    )
  $$,
  '22023',
  'At least one text vehicle ID is required.',
  'at least one vehicle is required'
);
select throws_ok(
  $$
    select public.save_deployment(
      jsonb_build_object(
        'deployment_code', deployment_code,
        'route_id', route_id,
        'route_name', route_name,
        'start_time', start_time,
        'end_time', end_time,
        'purpose', purpose,
        'vehicle_ids', '["TEST-BUS-01"]'::jsonb,
        'status', 'active'
      ),
      version
    )
    from public.deployments
    where route_id = 'TEST-300'
  $$,
  '22023',
  'Payload contains database-managed deployment fields.',
  'save_deployment cannot change status'
);
select throws_ok(
  $$
    select public.save_deployment(
      jsonb_build_object(
        'deployment_code', deployment_code,
        'route_id', route_id,
        'route_name', route_name,
        'start_time', start_time,
        'end_time', end_time,
        'purpose', purpose,
        'vehicle_ids', '["TEST-BUS-01"]'::jsonb
      ),
      0
    )
    from public.deployments
    where route_id = 'TEST-300'
  $$,
  '40001',
  'Deployment version conflict.',
  'stale expected_version is rejected'
);

select lives_ok(
  $$
    select public.save_deployment(
      jsonb_build_object(
        'deployment_code', deployment_code,
        'route_id', route_id,
        'route_name', route_name,
        'start_time', start_time,
        'end_time', end_time,
        'purpose', 'Updated exactly once',
        'vehicle_ids', '["TEST-BUS-03"]'::jsonb
      ),
      version
    )
    from public.deployments
    where route_id = 'TEST-300'
  $$,
  'valid draft editing succeeds'
);
select is(
  (
    select version
    from public.deployments
    where route_id = 'TEST-300'
  ),
  2::bigint,
  'the BEFORE UPDATE trigger increments version exactly once'
);

create temporary table transition_cases (
  case_name text primary key,
  deployment_code text not null,
  version bigint not null
);

insert into transition_cases
select
  transition_case.case_name,
  response ->> 'deployment_code',
  (response ->> 'version')::bigint
from unnest(array[
  'draft-scheduled',
  'draft-cancelled',
  'scheduled-active',
  'scheduled-cancelled',
  'active-completed',
  'active-cancelled'
]) with ordinality as transition_case(case_name, ordinal)
cross join lateral public.save_deployment(
  jsonb_build_object(
    'route_id', 'TRANSITION-' || transition_case.ordinal,
    'route_name', 'Transition route',
    'start_time', '2026-09-02T08:00:00+08:00',
    'end_time', '2026-09-02T09:00:00+08:00',
    'purpose', 'Transition coverage',
    'vehicle_ids', jsonb_build_array('TRANSITION-BUS-' || transition_case.ordinal)
  ),
  null
) as response;

select lives_ok(
  $$
    select public.transition_deployment(deployment_code, 'scheduled', version)
    from transition_cases where case_name = 'draft-scheduled'
  $$,
  'draft to scheduled succeeds'
);
select lives_ok(
  $$
    select public.transition_deployment(deployment_code, 'cancelled', version)
    from transition_cases where case_name = 'draft-cancelled'
  $$,
  'draft to cancelled succeeds'
);

update transition_cases
set version = (
  public.transition_deployment(deployment_code, 'scheduled', version)
  ->> 'version'
)::bigint
where case_name in (
  'scheduled-active',
  'scheduled-cancelled',
  'active-completed',
  'active-cancelled'
);

select lives_ok(
  $$
    select public.transition_deployment(deployment_code, 'active', version)
    from transition_cases where case_name = 'scheduled-active'
  $$,
  'scheduled to active succeeds'
);
select lives_ok(
  $$
    select public.transition_deployment(deployment_code, 'cancelled', version)
    from transition_cases where case_name = 'scheduled-cancelled'
  $$,
  'scheduled to cancelled succeeds'
);

update transition_cases
set version = (
  public.transition_deployment(deployment_code, 'active', version)
  ->> 'version'
)::bigint
where case_name in ('active-completed', 'active-cancelled');

select lives_ok(
  $$
    select public.transition_deployment(deployment_code, 'completed', version)
    from transition_cases where case_name = 'active-completed'
  $$,
  'active to completed succeeds'
);
select lives_ok(
  $$
    select public.transition_deployment(deployment_code, 'cancelled', version)
    from transition_cases where case_name = 'active-cancelled'
  $$,
  'active to cancelled succeeds'
);

select throws_ok(
  $$
    select public.transition_deployment(deployment_code, 'completed', 2)
    from transition_cases where case_name = 'draft-scheduled'
  $$,
  '22023',
  'Invalid deployment status transition from scheduled to completed.',
  'an unapproved transition is rejected'
);
select throws_ok(
  $$
    select public.transition_deployment(deployment_code, 'active', version)
    from transition_cases where case_name = 'scheduled-cancelled'
  $$,
  '40001',
  'Deployment version conflict.',
  'transition requires the expected version'
);
select throws_ok(
  $$
    select public.transition_deployment(
      deployment_code,
      'active',
      (select version from public.deployments where deployments.deployment_code = transition_cases.deployment_code)
    )
    from transition_cases where case_name = 'draft-cancelled'
  $$,
  '22023',
  'Invalid deployment status transition from cancelled to active.',
  'cancelled is terminal'
);
select throws_ok(
  $$
    select public.transition_deployment(
      deployment_code,
      'cancelled',
      (select version from public.deployments where deployments.deployment_code = transition_cases.deployment_code)
    )
    from transition_cases where case_name = 'active-completed'
  $$,
  '22023',
  'Invalid deployment status transition from completed to cancelled.',
  'completed is terminal'
);

select ok(
  (
    select deployment.route_id = 'TRANSITION-5'
      and deployment.route_name = 'Transition route'
      and deployment.purpose = 'Transition coverage'
      and deployment.start_time = '2026-09-02T08:00:00+08:00'::timestamptz
      and deployment.end_time = '2026-09-02T09:00:00+08:00'::timestamptz
      and deployment.created_by = '11111111-1111-1111-1111-111111111111'::uuid
      and deployment.updated_by = '11111111-1111-1111-1111-111111111111'::uuid
      and deployment.updated_at > deployment.created_at
      and deployment.version = 4
      and deployment.status = 'completed'
      and (
        select count(*)
        from public.deployment_vehicles as vehicle
        where vehicle.deployment_id = deployment.id
      ) = 1
    from public.deployments as deployment
    join transition_cases as transition_case
      on transition_case.deployment_code = deployment.deployment_code
    where transition_case.case_name = 'active-completed'
  ),
  'transition changes only status, update audit values and version'
);

select throws_ok(
  $$
    update public.deployments
    set deployment_code = deployment_code || '-CHANGED'
    where route_id = 'TEST-300'
  $$,
  '22023',
  'Immutable deployment fields cannot be changed.',
  'trigger protects immutable deployment fields'
);

select is(
  (
    select route_id from public.deployments where deployment_code = 'DEP-120'
  ),
  '300',
  'DEP-120 seed uses Route 300'
);
select is(
  (
    select purpose from public.deployments where deployment_code = 'DEP-120'
  ),
  'Deploy 2 replacement buses to replace unavailable Bus B1023 and restore service capacity',
  'DEP-120 has the exact approved purpose'
);
select is(
  (
    select status from public.deployments where deployment_code = 'DEP-120'
  ),
  'scheduled',
  'DEP-120 represents the accepted and scheduled demo deployment'
);
select is(
  (
    select count(*)
    from public.deployment_vehicles as vehicle
    join public.deployments as deployment on deployment.id = vehicle.deployment_id
    where deployment.deployment_code = 'DEP-120'
  ),
  2::bigint,
  'DEP-120 contains exactly two replacement vehicles'
);
select is(
  (
    select count(*)
    from public.deployment_vehicles as vehicle
    join public.deployments as deployment on deployment.id = vehicle.deployment_id
    where deployment.deployment_code = 'DEP-120'
      and vehicle.vehicle_id = 'B1023'
  ),
  0::bigint,
  'unavailable B1023 is not a deployed replacement vehicle'
);

select ok(
  not exists (
    select 1
    from pg_constraint as constraint_info
    where constraint_info.conrelid = 'public.deployments'::regclass
      and constraint_info.contype = 'f'
  ),
  'incident and recommendation references have no physical foreign keys'
);
select ok(
  not exists (
    select 1
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname ~* 'delete.*deployment|deployment.*delete'
  ),
  'no production physical-delete RPC exists'
);

select * from finish();
rollback;
