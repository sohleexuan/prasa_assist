create sequence public.incident_code_seq
  as bigint
  start with 2
  increment by 1
  no minvalue
  no maxvalue
  cache 1;

create table public.incidents (
  id uuid primary key default extensions.gen_random_uuid(),
  incident_code text unique not null,
  incident_type text not null,
  title text not null,
  description text not null,
  route_id text not null,
  route_name text null,
  vehicle_id text null,
  location text not null,
  reported_at timestamptz not null,
  severity text not null,
  status text not null default 'reported',
  vehicle_condition text not null,
  disruption_scope text not null,
  estimated_delay_minutes smallint not null,
  impact_level text not null,
  estimation_reasons text[] not null,
  estimation_model_version smallint not null default 1,
  data_source text not null default 'staff_entered',
  reported_by_label text not null,
  created_by uuid not null,
  updated_by uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  version bigint not null default 1,
  constraint incidents_code_not_blank check (btrim(incident_code) <> ''),
  constraint incidents_title_length check (
    char_length(btrim(title)) between 3 and 100
  ),
  constraint incidents_description_length check (
    char_length(btrim(description)) >= 10
  ),
  constraint incidents_route_id_not_blank check (btrim(route_id) <> ''),
  constraint incidents_route_name_not_blank check (
    route_name is null or btrim(route_name) <> ''
  ),
  constraint incidents_vehicle_id_not_blank check (
    vehicle_id is null or btrim(vehicle_id) <> ''
  ),
  constraint incidents_location_not_blank check (btrim(location) <> ''),
  constraint incidents_type_allowed check (
    incident_type in (
      'vehicle_breakdown',
      'accident',
      'service_disruption',
      'infrastructure_issue',
      'safety_incident',
      'other'
    )
  ),
  constraint incidents_vehicle_required check (
    incident_type not in ('vehicle_breakdown', 'accident')
    or vehicle_id is not null
  ),
  constraint incidents_severity_allowed check (
    severity in ('low', 'medium', 'high', 'critical')
  ),
  constraint incidents_status_allowed check (
    status in ('reported', 'under_review', 'active', 'resolved', 'cancelled')
  ),
  constraint incidents_vehicle_condition_allowed check (
    vehicle_condition in (
      'operational',
      'limited_operation',
      'immobilised',
      'unknown'
    )
  ),
  constraint incidents_disruption_scope_allowed check (
    disruption_scope in (
      'no_obstruction',
      'partial_obstruction',
      'full_obstruction',
      'unknown'
    )
  ),
  constraint incidents_delay_range check (
    estimated_delay_minutes between 5 and 120
  ),
  constraint incidents_impact_allowed check (
    impact_level in ('minor', 'moderate', 'major', 'severe')
  ),
  constraint incidents_reasons_present check (
    cardinality(estimation_reasons) >= 1
    and array_position(estimation_reasons, null) is null
  ),
  constraint incidents_reasons_not_blank check (
    array_position(estimation_reasons, '') is null
  ),
  constraint incidents_estimation_model_version_positive check (
    estimation_model_version >= 1
  ),
  constraint incidents_data_source_allowed check (
    data_source in (
      'staff_entered',
      'mock_demonstration',
      'live_government',
      'cached_government',
      'static_government'
    )
  ),
  constraint incidents_reporter_not_blank check (
    btrim(reported_by_label) <> ''
  ),
  constraint incidents_time_order check (updated_at >= created_at),
  constraint incidents_version_positive check (version >= 1)
);

create table public.incident_status_history (
  id bigint generated always as identity primary key,
  incident_id uuid not null,
  sequence_no smallint not null,
  from_status text null,
  to_status text not null,
  changed_at timestamptz not null default statement_timestamp(),
  changed_by uuid not null,
  changed_by_label text not null,
  note text null,
  constraint incident_status_history_incident_fkey foreign key (incident_id)
    references public.incidents (id) on delete restrict,
  constraint incident_status_history_sequence_unique
    unique (incident_id, sequence_no),
  constraint incident_status_history_sequence_positive check (sequence_no > 0),
  constraint incident_status_history_from_allowed check (
    from_status is null
    or from_status in (
      'reported',
      'under_review',
      'active',
      'resolved',
      'cancelled'
    )
  ),
  constraint incident_status_history_to_allowed check (
    to_status in (
      'reported',
      'under_review',
      'active',
      'resolved',
      'cancelled'
    )
  ),
  constraint incident_status_history_operator_not_blank check (
    btrim(changed_by_label) <> ''
  ),
  constraint incident_status_history_note_not_blank check (
    note is null or btrim(note) <> ''
  ),
  constraint incident_status_history_initial_shape check (
    (sequence_no = 1 and from_status is null and to_status = 'reported')
    or (sequence_no > 1 and from_status is not null)
  )
);

create index incidents_route_reported_idx
  on public.incidents (route_id, reported_at desc);
create index incidents_vehicle_idx on public.incidents (vehicle_id)
  where vehicle_id is not null;
create index incidents_status_idx on public.incidents (status);
create index incidents_updated_idx on public.incidents (updated_at desc);
create index incident_status_history_incident_idx
  on public.incident_status_history (incident_id, sequence_no);

create function public.enforce_incident_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.incident_code is distinct from old.incident_code
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
    or new.reported_by_label is distinct from old.reported_by_label
    or new.data_source is distinct from old.data_source
    or new.estimation_model_version is distinct from old.estimation_model_version then
    raise exception 'Immutable incident fields cannot be changed.'
      using errcode = '22023';
  end if;

  if new.version is distinct from old.version then
    raise exception 'Incident version is maintained by the database.'
      using errcode = '22023';
  end if;

  if new.status is distinct from old.status and not (
    (old.status = 'reported' and new.status in ('under_review', 'cancelled'))
    or (old.status = 'under_review' and new.status in ('active', 'cancelled'))
    or (old.status = 'active' and new.status in ('resolved', 'cancelled'))
  ) then
    raise exception 'Invalid incident status transition from % to %.',
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

create trigger incidents_before_update
before update on public.incidents
for each row execute function public.enforce_incident_update();

create function public.save_incident(
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
  v_staff_label text := coalesce(
    nullif(btrim(auth.jwt() ->> 'email'), ''),
    auth.uid()::text
  );
  v_incident_id uuid;
  v_incident_code text;
  v_current_status text;
  v_current_version bigint;
  v_incident_type text := lower(btrim(coalesce(p_payload ->> 'incident_type', '')));
  v_title text := btrim(coalesce(p_payload ->> 'title', ''));
  v_description text := btrim(coalesce(p_payload ->> 'description', ''));
  v_route_id text := btrim(coalesce(p_payload ->> 'route_id', ''));
  v_route_name text := nullif(btrim(p_payload ->> 'route_name'), '');
  v_vehicle_id text := nullif(upper(btrim(p_payload ->> 'vehicle_id')), '');
  v_location text := btrim(coalesce(p_payload ->> 'location', ''));
  v_reported_at timestamptz;
  v_severity text := lower(btrim(coalesce(p_payload ->> 'severity', '')));
  v_vehicle_condition text := lower(
    btrim(coalesce(p_payload ->> 'vehicle_condition', ''))
  );
  v_disruption_scope text := lower(
    btrim(coalesce(p_payload ->> 'disruption_scope', ''))
  );
  v_estimated_delay_minutes smallint;
  v_impact_level text := lower(btrim(coalesce(p_payload ->> 'impact_level', '')));
  v_reason_values jsonb := p_payload -> 'estimation_reasons';
  v_estimation_reasons text[];
  v_reason_count integer;
  v_string_reason_count integer;
  v_is_create boolean;
  v_saved_at timestamptz;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'An authenticated staff session is required.'
      using errcode = '42501';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Incident payload must be a JSON object.'
      using errcode = '22023';
  end if;

  if p_payload ?| array[
    'id',
    'status',
    'data_source',
    'reported_by_label',
    'created_by',
    'updated_by',
    'created_at',
    'updated_at',
    'version',
    'status_history',
    'estimation_model_version'
  ] then
    raise exception 'Payload contains database-managed incident fields.'
      using errcode = '22023';
  end if;

  begin
    v_reported_at := (p_payload ->> 'reported_at')::timestamptz;
    v_estimated_delay_minutes :=
      (p_payload ->> 'estimated_delay_minutes')::smallint;
  exception when others then
    raise exception 'Valid reported_at and estimated delay values are required.'
      using errcode = '22007';
  end;

  if v_reason_values is null or jsonb_typeof(v_reason_values) <> 'array' then
    raise exception 'estimation_reasons must be an array.'
      using errcode = '22023';
  end if;

  select
    count(*),
    count(*) filter (where jsonb_typeof(reason.value) = 'string')
  into v_reason_count, v_string_reason_count
  from jsonb_array_elements(v_reason_values) as reason(value);

  if v_reason_count < 1 or v_string_reason_count <> v_reason_count then
    raise exception 'At least one text estimation reason is required.'
      using errcode = '22023';
  end if;

  select array_agg(btrim(reason.value #>> '{}') order by reason.ordinality)
  into v_estimation_reasons
  from jsonb_array_elements(v_reason_values) with ordinality
    as reason(value, ordinality);

  if exists (
    select 1 from unnest(v_estimation_reasons) as reason where reason = ''
  ) then
    raise exception 'Estimation reasons cannot be blank.'
      using errcode = '22023';
  end if;

  if v_reported_at > clock_timestamp() then
    raise exception 'Reported time cannot be in the future.'
      using errcode = '22023';
  end if;

  v_is_create := not (p_payload ? 'incident_code');

  if v_is_create then
    if p_expected_version is not null then
      raise exception 'expected_version is not accepted when creating.'
        using errcode = '22023';
    end if;

    v_incident_code := 'INC-'
      || to_char(clock_timestamp(), 'YYYYMMDD')
      || '-'
      || lpad(nextval('public.incident_code_seq'::regclass)::text, 6, '0');
    v_saved_at := clock_timestamp();

    insert into public.incidents (
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
      v_incident_code,
      v_incident_type,
      v_title,
      v_description,
      v_route_id,
      v_route_name,
      v_vehicle_id,
      v_location,
      v_reported_at,
      v_severity,
      'reported',
      v_vehicle_condition,
      v_disruption_scope,
      v_estimated_delay_minutes,
      v_impact_level,
      v_estimation_reasons,
      1,
      'staff_entered',
      v_staff_label,
      v_user_id,
      v_user_id,
      v_saved_at,
      v_saved_at,
      1
    )
    returning id into v_incident_id;

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
      v_incident_id,
      1,
      null,
      'reported',
      v_saved_at,
      v_user_id,
      v_staff_label,
      'Incident reported by staff.'
    );
  else
    v_incident_code := btrim(coalesce(p_payload ->> 'incident_code', ''));
    if v_incident_code = '' or p_expected_version is null then
      raise exception 'incident_code and expected_version are required when updating.'
        using errcode = '22023';
    end if;

    select incident.id, incident.status, incident.version
    into v_incident_id, v_current_status, v_current_version
    from public.incidents as incident
    where incident.incident_code = v_incident_code
    for update;

    if not found then
      raise exception 'Incident % was not found.', v_incident_code
        using errcode = 'P0002';
    end if;

    if v_current_version <> p_expected_version then
      raise exception 'Incident version conflict.' using errcode = '40001';
    end if;

    if v_current_status in ('resolved', 'cancelled') then
      raise exception 'Resolved or Cancelled incidents are read-only.'
        using errcode = '22023';
    end if;

    update public.incidents
    set incident_type = v_incident_type,
        title = v_title,
        description = v_description,
        route_id = v_route_id,
        route_name = v_route_name,
        vehicle_id = v_vehicle_id,
        location = v_location,
        reported_at = v_reported_at,
        severity = v_severity,
        vehicle_condition = v_vehicle_condition,
        disruption_scope = v_disruption_scope,
        estimated_delay_minutes = v_estimated_delay_minutes,
        impact_level = v_impact_level,
        estimation_reasons = v_estimation_reasons
    where id = v_incident_id;
  end if;

  select jsonb_build_object(
    'id', incident.id,
    'incident_code', incident.incident_code,
    'incident_type', incident.incident_type,
    'title', incident.title,
    'description', incident.description,
    'route_id', incident.route_id,
    'route_name', incident.route_name,
    'vehicle_id', incident.vehicle_id,
    'location', incident.location,
    'reported_at', incident.reported_at,
    'severity', incident.severity,
    'status', incident.status,
    'vehicle_condition', incident.vehicle_condition,
    'disruption_scope', incident.disruption_scope,
    'estimated_delay_minutes', incident.estimated_delay_minutes,
    'impact_level', incident.impact_level,
    'estimation_reasons', to_jsonb(incident.estimation_reasons),
    'estimation_model_version', incident.estimation_model_version,
    'data_source', incident.data_source,
    'reported_by_label', incident.reported_by_label,
    'created_at', incident.created_at,
    'updated_at', incident.updated_at,
    'version', incident.version,
    'incident_status_history', (
      select jsonb_agg(
        jsonb_build_object(
          'sequence_no', history.sequence_no,
          'from_status', history.from_status,
          'to_status', history.to_status,
          'changed_at', history.changed_at,
          'changed_by_label', history.changed_by_label,
          'note', history.note
        ) order by history.sequence_no
      )
      from public.incident_status_history as history
      where history.incident_id = incident.id
    )
  )
  into v_result
  from public.incidents as incident
  where incident.id = v_incident_id;

  return v_result;
end;
$$;

create function public.transition_incident(
  p_incident_code text,
  p_to_status text,
  p_note text,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_staff_label text := coalesce(
    nullif(btrim(auth.jwt() ->> 'email'), ''),
    auth.uid()::text
  );
  v_incident_id uuid;
  v_current_status text;
  v_current_version bigint;
  v_target_status text := lower(btrim(coalesce(p_to_status, '')));
  v_note text := nullif(btrim(p_note), '');
  v_changed_at timestamptz;
  v_next_sequence smallint;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'An authenticated staff session is required.'
      using errcode = '42501';
  end if;

  if btrim(coalesce(p_incident_code, '')) = ''
    or p_expected_version is null then
    raise exception 'incident_code and expected_version are required.'
      using errcode = '22023';
  end if;

  select incident.id, incident.status, incident.version
  into v_incident_id, v_current_status, v_current_version
  from public.incidents as incident
  where incident.incident_code = btrim(p_incident_code)
  for update;

  if not found then
    raise exception 'Incident % was not found.', btrim(p_incident_code)
      using errcode = 'P0002';
  end if;

  if v_current_version <> p_expected_version then
    raise exception 'Incident version conflict.' using errcode = '40001';
  end if;

  if not (
    (v_current_status = 'reported' and v_target_status in ('under_review', 'cancelled'))
    or (v_current_status = 'under_review' and v_target_status in ('active', 'cancelled'))
    or (v_current_status = 'active' and v_target_status in ('resolved', 'cancelled'))
  ) then
    raise exception 'Invalid incident status transition from % to %.',
      v_current_status,
      v_target_status
      using errcode = '22023';
  end if;

  update public.incidents
  set status = v_target_status
  where id = v_incident_id
  returning updated_at into v_changed_at;

  select (count(*) + 1)::smallint
  into v_next_sequence
  from public.incident_status_history
  where incident_id = v_incident_id;

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
    v_incident_id,
    v_next_sequence,
    v_current_status,
    v_target_status,
    v_changed_at,
    v_user_id,
    v_staff_label,
    v_note
  );

  select jsonb_build_object(
    'id', incident.id,
    'incident_code', incident.incident_code,
    'incident_type', incident.incident_type,
    'title', incident.title,
    'description', incident.description,
    'route_id', incident.route_id,
    'route_name', incident.route_name,
    'vehicle_id', incident.vehicle_id,
    'location', incident.location,
    'reported_at', incident.reported_at,
    'severity', incident.severity,
    'status', incident.status,
    'vehicle_condition', incident.vehicle_condition,
    'disruption_scope', incident.disruption_scope,
    'estimated_delay_minutes', incident.estimated_delay_minutes,
    'impact_level', incident.impact_level,
    'estimation_reasons', to_jsonb(incident.estimation_reasons),
    'estimation_model_version', incident.estimation_model_version,
    'data_source', incident.data_source,
    'reported_by_label', incident.reported_by_label,
    'created_at', incident.created_at,
    'updated_at', incident.updated_at,
    'version', incident.version,
    'incident_status_history', (
      select jsonb_agg(
        jsonb_build_object(
          'sequence_no', history.sequence_no,
          'from_status', history.from_status,
          'to_status', history.to_status,
          'changed_at', history.changed_at,
          'changed_by_label', history.changed_by_label,
          'note', history.note
        ) order by history.sequence_no
      )
      from public.incident_status_history as history
      where history.incident_id = incident.id
    )
  )
  into v_result
  from public.incidents as incident
  where incident.id = v_incident_id;

  return v_result;
end;
$$;

alter table public.incidents enable row level security;
alter table public.incident_status_history enable row level security;

create policy incidents_authenticated_select
on public.incidents
for select
to authenticated
using ((select auth.uid()) is not null);

create policy incident_status_history_authenticated_select
on public.incident_status_history
for select
to authenticated
using ((select auth.uid()) is not null);

revoke all on table public.incidents from public, anon, authenticated;
revoke all on table public.incident_status_history
  from public, anon, authenticated;
grant select on table public.incidents to authenticated;
grant select on table public.incident_status_history to authenticated;

revoke all on sequence public.incident_code_seq
  from public, anon, authenticated;
revoke all on sequence public.incident_status_history_id_seq
  from public, anon, authenticated;

revoke all on function public.enforce_incident_update()
  from public, anon, authenticated;
revoke all on function public.save_incident(jsonb, bigint)
  from public, anon, authenticated;
revoke all on function public.transition_incident(text, text, text, bigint)
  from public, anon, authenticated;
grant execute on function public.save_incident(jsonb, bigint)
  to authenticated;
grant execute on function public.transition_incident(text, text, text, bigint)
  to authenticated;
