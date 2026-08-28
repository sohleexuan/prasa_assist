create extension if not exists pgcrypto with schema extensions;

create sequence public.deployment_code_seq
  as bigint
  start with 121
  increment by 1
  no minvalue
  no maxvalue
  cache 1;

create table public.deployments (
  id uuid primary key default extensions.gen_random_uuid(),
  deployment_code text unique not null,
  linked_incident_ref text null,
  linked_recommendation_ref text null,
  route_id text not null,
  route_name text not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  status text not null default 'draft',
  purpose text not null,
  created_by uuid not null,
  updated_by uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  version bigint not null default 1,
  constraint deployments_code_not_blank check (btrim(deployment_code) <> ''),
  constraint deployments_route_id_not_blank check (btrim(route_id) <> ''),
  constraint deployments_route_name_not_blank check (btrim(route_name) <> ''),
  constraint deployments_purpose_not_blank check (btrim(purpose) <> ''),
  constraint deployments_time_order check (end_time > start_time),
  constraint deployments_status_allowed check (
    status in ('draft', 'scheduled', 'active', 'completed', 'cancelled')
  ),
  constraint deployments_version_positive check (version >= 1)
);

create table public.deployment_vehicles (
  deployment_id uuid not null,
  vehicle_id text not null,
  assigned_at timestamptz not null default statement_timestamp(),
  sequence_no smallint not null,
  constraint deployment_vehicles_pkey primary key (deployment_id, vehicle_id),
  constraint deployment_vehicles_deployment_fkey foreign key (deployment_id)
    references public.deployments (id) on delete cascade,
  constraint deployment_vehicles_vehicle_id_not_blank
    check (btrim(vehicle_id) <> ''),
  constraint deployment_vehicles_sequence_positive check (sequence_no > 0),
  constraint deployment_vehicles_sequence_unique
    unique (deployment_id, sequence_no)
);

create index deployments_route_start_idx
  on public.deployments (route_id, start_time);
create index deployments_status_idx on public.deployments (status);
create index deployment_vehicles_vehicle_idx
  on public.deployment_vehicles (vehicle_id);

create function public.enforce_deployment_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.deployment_code is distinct from old.deployment_code
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at then
    raise exception 'Immutable deployment fields cannot be changed.'
      using errcode = '22023';
  end if;

  if new.version is distinct from old.version then
    raise exception 'Deployment version is maintained by the database.'
      using errcode = '22023';
  end if;

  if new.status is distinct from old.status and not (
    (old.status = 'draft' and new.status in ('scheduled', 'cancelled'))
    or (old.status = 'scheduled' and new.status in ('active', 'cancelled'))
    or (old.status = 'active' and new.status in ('completed', 'cancelled'))
  ) then
    raise exception 'Invalid deployment status transition from % to %.',
      old.status,
      new.status
      using errcode = '22023';
  end if;

  new.updated_by := auth.uid();
  if new.updated_by is null then
    raise exception 'An authenticated staff session is required.'
      using errcode = '42501';
  end if;

  new.updated_at := clock_timestamp();
  new.version := old.version + 1;
  return new;
end;
$$;

create trigger deployments_before_update
before update on public.deployments
for each row execute function public.enforce_deployment_update();

create function public.save_deployment(
  p_payload jsonb,
  p_expected_version bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_deployment_id uuid;
  v_deployment_code text;
  v_current_status text;
  v_current_version bigint;
  v_route_id text;
  v_route_name text;
  v_purpose text;
  v_start_time timestamptz;
  v_end_time timestamptz;
  v_vehicle_values jsonb;
  v_vehicle_ids text[];
  v_vehicle_count integer;
  v_string_vehicle_count integer;
  v_distinct_vehicle_count integer;
  v_is_create boolean;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'An authenticated staff session is required.'
      using errcode = '42501';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Deployment payload must be a JSON object.'
      using errcode = '22023';
  end if;

  if p_payload ?| array[
    'id',
    'status',
    'created_by',
    'updated_by',
    'created_at',
    'updated_at',
    'version',
    'expected_version',
    'requested_vehicle_count'
  ] then
    raise exception 'Payload contains database-managed deployment fields.'
      using errcode = '22023';
  end if;

  v_route_id := btrim(coalesce(p_payload ->> 'route_id', ''));
  v_route_name := btrim(coalesce(p_payload ->> 'route_name', ''));
  v_purpose := btrim(coalesce(p_payload ->> 'purpose', ''));

  if v_route_id = '' or v_route_name = '' or v_purpose = '' then
    raise exception 'Route ID, route name and purpose are required.'
      using errcode = '22023';
  end if;

  begin
    v_start_time := (p_payload ->> 'start_time')::timestamptz;
    v_end_time := (p_payload ->> 'end_time')::timestamptz;
  exception when others then
    raise exception 'Valid start_time and end_time values are required.'
      using errcode = '22007';
  end;

  if v_start_time is null or v_end_time is null or v_end_time <= v_start_time then
    raise exception 'end_time must be after start_time.'
      using errcode = '22023';
  end if;

  v_vehicle_values := p_payload -> 'vehicle_ids';
  if v_vehicle_values is null or jsonb_typeof(v_vehicle_values) <> 'array' then
    raise exception 'vehicle_ids must be an array.' using errcode = '22023';
  end if;

  select
    count(*),
    count(*) filter (where jsonb_typeof(vehicle.value) = 'string')
  into v_vehicle_count, v_string_vehicle_count
  from jsonb_array_elements(v_vehicle_values) as vehicle(value);

  if v_vehicle_count < 1 or v_string_vehicle_count <> v_vehicle_count then
    raise exception 'At least one text vehicle ID is required.'
      using errcode = '22023';
  end if;

  select
    array_agg(upper(btrim(vehicle.value #>> '{}')) order by vehicle.ordinality),
    count(distinct upper(btrim(vehicle.value #>> '{}')))
  into v_vehicle_ids, v_distinct_vehicle_count
  from jsonb_array_elements(v_vehicle_values) with ordinality
    as vehicle(value, ordinality);

  if exists (
    select 1 from unnest(v_vehicle_ids) as vehicle_id where vehicle_id = ''
  ) then
    raise exception 'Vehicle IDs cannot be blank.' using errcode = '22023';
  end if;

  if v_distinct_vehicle_count <> v_vehicle_count then
    raise exception 'Vehicle IDs must be unique after normalization.'
      using errcode = '22023';
  end if;

  v_is_create := not (p_payload ? 'deployment_code');

  if v_is_create then
    if p_expected_version is not null then
      raise exception 'expected_version is not accepted when creating.'
        using errcode = '22023';
    end if;

    v_deployment_code := 'DEP-' || nextval('public.deployment_code_seq'::regclass);

    insert into public.deployments (
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
      version
    ) values (
      v_deployment_code,
      nullif(btrim(p_payload ->> 'linked_incident_ref'), ''),
      nullif(btrim(p_payload ->> 'linked_recommendation_ref'), ''),
      v_route_id,
      v_route_name,
      v_start_time,
      v_end_time,
      'draft',
      v_purpose,
      v_user_id,
      v_user_id,
      1
    )
    returning id into v_deployment_id;
  else
    v_deployment_code := btrim(coalesce(p_payload ->> 'deployment_code', ''));
    if v_deployment_code = '' then
      raise exception 'deployment_code cannot be blank.' using errcode = '22023';
    end if;

    if p_expected_version is null then
      raise exception 'expected_version is required when updating.'
        using errcode = '22023';
    end if;

    select deployment.id, deployment.status, deployment.version
    into v_deployment_id, v_current_status, v_current_version
    from public.deployments as deployment
    where deployment.deployment_code = v_deployment_code
    for update;

    if not found then
      raise exception 'Deployment % was not found.', v_deployment_code
        using errcode = 'P0002';
    end if;

    if v_current_version <> p_expected_version then
      raise exception 'Deployment version conflict.' using errcode = '40001';
    end if;

    if v_current_status not in ('draft', 'scheduled') then
      raise exception 'Only draft or scheduled deployments can be edited.'
        using errcode = '22023';
    end if;

    update public.deployments
    set linked_incident_ref = nullif(btrim(p_payload ->> 'linked_incident_ref'), ''),
        linked_recommendation_ref = nullif(
          btrim(p_payload ->> 'linked_recommendation_ref'),
          ''
        ),
        route_id = v_route_id,
        route_name = v_route_name,
        start_time = v_start_time,
        end_time = v_end_time,
        purpose = v_purpose
    where id = v_deployment_id;

    delete from public.deployment_vehicles
    where deployment_id = v_deployment_id;
  end if;

  insert into public.deployment_vehicles (
    deployment_id,
    vehicle_id,
    assigned_at,
    sequence_no
  )
  select
    v_deployment_id,
    vehicle.vehicle_id,
    clock_timestamp(),
    vehicle.ordinality::smallint
  from unnest(v_vehicle_ids) with ordinality as vehicle(vehicle_id, ordinality);

  select jsonb_build_object(
    'deployment_code', deployment.deployment_code,
    'linked_incident_ref', deployment.linked_incident_ref,
    'linked_recommendation_ref', deployment.linked_recommendation_ref,
    'route_id', deployment.route_id,
    'route_name', deployment.route_name,
    'start_time', deployment.start_time,
    'end_time', deployment.end_time,
    'status', deployment.status,
    'purpose', deployment.purpose,
    'vehicle_ids', (
      select jsonb_agg(vehicle.vehicle_id order by vehicle.sequence_no)
      from public.deployment_vehicles as vehicle
      where vehicle.deployment_id = deployment.id
    ),
    'created_by', deployment.created_by,
    'updated_by', deployment.updated_by,
    'created_at', deployment.created_at,
    'updated_at', deployment.updated_at,
    'version', deployment.version
  )
  into v_result
  from public.deployments as deployment
  where deployment.id = v_deployment_id;

  return v_result;
end;
$$;

create function public.transition_deployment(
  p_deployment_code text,
  p_to_status text,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_deployment_id uuid;
  v_current_status text;
  v_current_version bigint;
  v_code text := btrim(coalesce(p_deployment_code, ''));
  v_target_status text := lower(btrim(coalesce(p_to_status, '')));
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'An authenticated staff session is required.'
      using errcode = '42501';
  end if;

  if v_code = '' or p_expected_version is null then
    raise exception 'deployment_code and expected_version are required.'
      using errcode = '22023';
  end if;

  select deployment.id, deployment.status, deployment.version
  into v_deployment_id, v_current_status, v_current_version
  from public.deployments as deployment
  where deployment.deployment_code = v_code
  for update;

  if not found then
    raise exception 'Deployment % was not found.', v_code
      using errcode = 'P0002';
  end if;

  if v_current_version <> p_expected_version then
    raise exception 'Deployment version conflict.' using errcode = '40001';
  end if;

  if not (
    (v_current_status = 'draft' and v_target_status in ('scheduled', 'cancelled'))
    or (v_current_status = 'scheduled' and v_target_status in ('active', 'cancelled'))
    or (v_current_status = 'active' and v_target_status in ('completed', 'cancelled'))
  ) then
    raise exception 'Invalid deployment status transition from % to %.',
      v_current_status,
      v_target_status
      using errcode = '22023';
  end if;

  update public.deployments
  set status = v_target_status
  where id = v_deployment_id;

  select jsonb_build_object(
    'deployment_code', deployment.deployment_code,
    'linked_incident_ref', deployment.linked_incident_ref,
    'linked_recommendation_ref', deployment.linked_recommendation_ref,
    'route_id', deployment.route_id,
    'route_name', deployment.route_name,
    'start_time', deployment.start_time,
    'end_time', deployment.end_time,
    'status', deployment.status,
    'purpose', deployment.purpose,
    'vehicle_ids', (
      select jsonb_agg(vehicle.vehicle_id order by vehicle.sequence_no)
      from public.deployment_vehicles as vehicle
      where vehicle.deployment_id = deployment.id
    ),
    'created_by', deployment.created_by,
    'updated_by', deployment.updated_by,
    'created_at', deployment.created_at,
    'updated_at', deployment.updated_at,
    'version', deployment.version
  )
  into v_result
  from public.deployments as deployment
  where deployment.id = v_deployment_id;

  return v_result;
end;
$$;

alter table public.deployments enable row level security;
alter table public.deployment_vehicles enable row level security;

create policy deployments_authenticated_select
on public.deployments
for select
to authenticated
using ((select auth.uid()) is not null);

create policy deployment_vehicles_authenticated_select
on public.deployment_vehicles
for select
to authenticated
using ((select auth.uid()) is not null);

revoke all on table public.deployments from public, anon, authenticated;
revoke all on table public.deployment_vehicles from public, anon, authenticated;
grant select on table public.deployments to authenticated;
grant select on table public.deployment_vehicles to authenticated;

revoke all on sequence public.deployment_code_seq from public, anon, authenticated;

revoke all on function public.enforce_deployment_update() from public, anon, authenticated;
revoke all on function public.save_deployment(jsonb, bigint) from public, anon, authenticated;
revoke all on function public.transition_deployment(text, text, bigint)
  from public, anon, authenticated;
grant execute on function public.save_deployment(jsonb, bigint) to authenticated;
grant execute on function public.transition_deployment(text, text, bigint)
  to authenticated;
