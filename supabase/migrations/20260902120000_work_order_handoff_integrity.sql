-- Read-only production preflight (documentation only; not executed here):
-- select count(*) as legacy_equal_schedule_rows
-- from public.work_orders
-- where scheduled_start is not null and scheduled_end = scheduled_start;
--
-- select w.id, w.work_order_id, w.recommendation_id, count(r.id) as matches
-- from public.work_orders w
-- left join public.recommendations r
--   on w.recommendation_id = r.id::text
-- where w.recommendation_id is not null
-- group by w.id, w.work_order_id, w.recommendation_id
-- having count(r.id) <> 1;

alter table public.work_orders
  add column route_id text;

alter table public.work_orders
  add constraint work_orders_route_not_blank
  check (route_id is null or btrim(route_id) <> '') not valid;

-- The migration owns these metadata-only updates. Disabling the authority
-- trigger avoids changing versions or audit timestamps during backfill.
alter table public.work_orders disable trigger enforce_work_order_update;

with unique_route_matches as (
  select w.id, min(r.route_id) as route_id
  from public.work_orders w
  join public.recommendations r
    on w.recommendation_id = r.id::text
  where w.route_id is null and r.route_id is not null
  group by w.id
  having count(r.id) = 1
)
update public.work_orders w
set route_id = matched.route_id
from unique_route_matches matched
where w.id = matched.id;

alter table public.work_orders enable trigger enforce_work_order_update;

create function public.enforce_work_order_schedule_integrity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  new_schedule_invalid boolean :=
    new.scheduled_start is not null
    and new.scheduled_end <= new.scheduled_start;
  old_schedule_invalid boolean;
  schedule_unchanged boolean;
begin
  if not new_schedule_invalid then
    return new;
  end if;
  if tg_op = 'INSERT' then
    raise exception using errcode = '23514',
      message = 'Scheduled end must be later than scheduled start.';
  end if;
  old_schedule_invalid :=
    old.scheduled_start is not null
    and old.scheduled_end <= old.scheduled_start;
  schedule_unchanged :=
    new.scheduled_start is not distinct from old.scheduled_start
    and new.scheduled_end is not distinct from old.scheduled_end;
  if not old_schedule_invalid or not schedule_unchanged then
    raise exception using errcode = '23514',
      message = 'Scheduled end must be later than scheduled start.';
  end if;
  if new.status = 'cancelled' then
    return new;
  end if;
  raise exception using errcode = '23514',
    message = 'Correct the legacy schedule before changing this work order.';
end
$$;

create trigger enforce_work_order_schedule_integrity
before insert or update on public.work_orders
for each row execute function public.enforce_work_order_schedule_integrity();

revoke all on function public.enforce_work_order_schedule_integrity()
  from public, anon, authenticated;

create index work_orders_route_idx
  on public.work_orders(route_id)
  where route_id is not null;

grant select(route_id) on public.work_orders to authenticated;

create or replace function public.work_order_result(p public.work_orders)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'id', p.id,
    'work_order_id', p.work_order_id,
    'incident_id', p.incident_id,
    'recommendation_id', p.recommendation_id,
    'route_id', p.route_id,
    'vehicle_id', p.vehicle_id,
    'task_type', p.task_type,
    'description', p.description,
    'priority', p.priority,
    'assigned_to', p.assigned_to,
    'scheduled_start', p.scheduled_start,
    'scheduled_end', p.scheduled_end,
    'status', p.status,
    'notes', p.notes,
    'created_by_user_id', p.created_by_user_id,
    'created_by_label', p.created_by_label,
    'created_at', p.created_at,
    'updated_at', p.updated_at,
    'completed_at', p.completed_at,
    'cancelled_at', p.cancelled_at,
    'version', p.version
  )
$$;

create or replace function public.enforce_work_order_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  operation_time timestamptz := pg_catalog.clock_timestamp();
begin
  if auth.uid() is null then
    raise exception using errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if old.status in ('completed', 'cancelled') then
    raise exception using errcode = '22023',
      message = 'Terminal work orders cannot be changed.';
  end if;
  if new.id is distinct from old.id
    or new.work_order_id is distinct from old.work_order_id
    or new.publication_key is distinct from old.publication_key
    or new.publication_request_snapshot
      is distinct from old.publication_request_snapshot
    or new.publication_request_sha256
      is distinct from old.publication_request_sha256
    or new.incident_id is distinct from old.incident_id
    or new.recommendation_id is distinct from old.recommendation_id
    or new.route_id is distinct from old.route_id
    or new.created_by_user_id is distinct from old.created_by_user_id
    or new.created_by_label is distinct from old.created_by_label
    or new.created_at is distinct from old.created_at then
    raise exception using errcode = '22023',
      message = 'Identity, linkage and audit fields are immutable.';
  end if;
  if new.version is distinct from old.version
    or new.updated_at is distinct from old.updated_at
    or new.completed_at is distinct from old.completed_at
    or new.cancelled_at is distinct from old.cancelled_at then
    raise exception using errcode = '22023',
      message = 'Version and lifecycle timestamps are server controlled.';
  end if;
  if new.status is distinct from old.status
    and not (
      (old.status = 'draft' and new.status in ('open', 'cancelled'))
      or (old.status = 'open' and new.status in ('assigned', 'cancelled'))
      or (
        old.status = 'assigned'
        and new.status in ('in_progress', 'cancelled')
      )
      or (
        old.status = 'in_progress'
        and new.status in ('completed', 'cancelled')
      )
    ) then
    raise exception using errcode = '22023',
      message = 'Invalid work-order status transition.';
  end if;
  if new.assigned_to is distinct from old.assigned_to
    and not (
      old.status = 'open'
      and new.status = 'assigned'
      and old.assigned_to is null
      and new.assigned_to is not null
      and pg_catalog.btrim(new.assigned_to) <> ''
    ) then
    raise exception using errcode = '22023',
      message = 'Assignment is allowed only while moving Open to Assigned.';
  end if;
  if old.status = 'open'
    and new.status = 'assigned'
    and new.assigned_to is not distinct from old.assigned_to then
    raise exception using errcode = '22023',
      message = 'Assignment requires responsible staff.';
  end if;
  new.updated_at := operation_time;
  new.version := old.version + 1;
  if new.status = 'completed' then
    new.completed_at := operation_time;
    new.cancelled_at := null;
  elsif new.status = 'cancelled' then
    new.cancelled_at := operation_time;
    new.completed_at := null;
  else
    new.completed_at := null;
    new.cancelled_at := null;
  end if;
  return new;
end
$$;

create or replace function public.create_work_order(
  p_publication_key text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  staff_user_id uuid := auth.uid();
  canonical_key text := pg_catalog.btrim(p_publication_key);
  operation_time timestamptz := pg_catalog.clock_timestamp();
  schedule_start timestamptz;
  schedule_end timestamptz;
  canonical_snapshot jsonb;
  snapshot_hash bytea;
  legacy_snapshot jsonb;
  legacy_hash bytea;
  incoming_route_id text;
  existing public.work_orders;
  result_record public.work_orders;
  creator_label text;
  sequence_number bigint;
begin
  if staff_user_id is null then
    raise exception using errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if canonical_key is null
    or pg_catalog.char_length(canonical_key) not between 1 and 200 then
    raise exception using errcode = '22023',
      message = 'Publication key is required.';
  end if;
  if p_payload is null
    or pg_catalog.jsonb_typeof(p_payload) <> 'object'
    or exists (
      select 1
      from pg_catalog.jsonb_object_keys(p_payload) payload_key
      where payload_key not in (
        'incident_id', 'recommendation_id', 'route_id', 'vehicle_id',
        'task_type', 'description', 'priority', 'scheduled_start',
        'scheduled_end', 'notes'
      )
    ) then
    raise exception using errcode = '22023',
      message = 'Publication payload is invalid.';
  end if;
  schedule_start := public.work_order_timestamp(
    p_payload -> 'scheduled_start',
    'Scheduled start'
  );
  schedule_end := public.work_order_timestamp(
    p_payload -> 'scheduled_end',
    'Scheduled end'
  );
  if (schedule_start is null) <> (schedule_end is null) then
    raise exception using errcode = '22023',
      message = 'Provide a valid complete schedule.';
  end if;
  if schedule_start is not null and schedule_end <= schedule_start then
    raise exception using errcode = '22023',
      message = 'Scheduled end must be later than scheduled start.';
  end if;
  if coalesce(pg_catalog.btrim(p_payload ->> 'vehicle_id'), '') = ''
    or coalesce(pg_catalog.btrim(p_payload ->> 'task_type'), '') = ''
    or coalesce(pg_catalog.btrim(p_payload ->> 'description'), '') = '' then
    raise exception using errcode = '22023',
      message = 'Vehicle, task type and description are required.';
  end if;
  if pg_catalog.lower(pg_catalog.btrim(p_payload ->> 'priority'))
    not in ('low', 'medium', 'high', 'urgent') then
    raise exception using errcode = '22023',
      message = 'Priority is invalid.';
  end if;
  canonical_snapshot := pg_catalog.jsonb_build_object(
    'incident_id', nullif(pg_catalog.btrim(p_payload ->> 'incident_id'), ''),
    'recommendation_id',
      nullif(pg_catalog.btrim(p_payload ->> 'recommendation_id'), ''),
    'route_id', nullif(pg_catalog.btrim(p_payload ->> 'route_id'), ''),
    'vehicle_id', pg_catalog.upper(pg_catalog.btrim(p_payload ->> 'vehicle_id')),
    'task_type', pg_catalog.btrim(p_payload ->> 'task_type'),
    'description', pg_catalog.btrim(p_payload ->> 'description'),
    'priority', pg_catalog.lower(pg_catalog.btrim(p_payload ->> 'priority')),
    'scheduled_start', case
      when schedule_start is null then null
      else pg_catalog.to_char(
        schedule_start at time zone 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
      )
    end,
    'scheduled_end', case
      when schedule_end is null then null
      else pg_catalog.to_char(
        schedule_end at time zone 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
      )
    end,
    'notes', nullif(pg_catalog.btrim(p_payload ->> 'notes'), '')
  );
  snapshot_hash := extensions.digest(
    pg_catalog.convert_to(canonical_snapshot::text, 'UTF8'),
    'sha256'
  );
  incoming_route_id := canonical_snapshot ->> 'route_id';
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      staff_user_id::text || E'\x1f' || canonical_key,
      0
    )
  );
  select * into existing
  from public.work_orders
  where created_by_user_id = staff_user_id
    and publication_key = canonical_key
  for update;
  if found then
    if existing.publication_request_snapshot ? 'route_id' then
      if existing.publication_request_snapshot = canonical_snapshot
        and existing.publication_request_sha256 = snapshot_hash then
        return public.work_order_result(existing);
      end if;
    else
      legacy_snapshot := canonical_snapshot - 'route_id';
      legacy_hash := extensions.digest(
        pg_catalog.convert_to(legacy_snapshot::text, 'UTF8'),
        'sha256'
      );
      if existing.publication_request_snapshot = legacy_snapshot
        and existing.publication_request_sha256 = legacy_hash
        and (
          incoming_route_id is null
          or (
            existing.route_id is not null
            and existing.route_id = incoming_route_id
          )
        ) then
        return public.work_order_result(existing);
      end if;
    end if;
    raise exception using errcode = '40001',
      message = 'Publication key was already used for different content.';
  end if;
  sequence_number := pg_catalog.nextval(
    'public.work_order_code_seq'::pg_catalog.regclass
  );
  creator_label := coalesce(
    nullif(pg_catalog.btrim(auth.jwt() ->> 'email'), ''),
    staff_user_id::text
  );
  insert into public.work_orders(
    work_order_id, publication_key, publication_request_snapshot,
    publication_request_sha256, incident_id, recommendation_id, route_id,
    vehicle_id, task_type, description, priority, scheduled_start,
    scheduled_end, notes, created_by_user_id, created_by_label, created_at,
    updated_at
  ) values (
    'WO-' || pg_catalog.to_char(operation_time at time zone 'UTC', 'YYYYMMDD')
      || '-' || pg_catalog.lpad(sequence_number::text, 6, '0'),
    canonical_key, canonical_snapshot, snapshot_hash,
    canonical_snapshot ->> 'incident_id',
    canonical_snapshot ->> 'recommendation_id',
    canonical_snapshot ->> 'route_id',
    canonical_snapshot ->> 'vehicle_id',
    canonical_snapshot ->> 'task_type',
    canonical_snapshot ->> 'description',
    canonical_snapshot ->> 'priority',
    schedule_start, schedule_end, canonical_snapshot ->> 'notes',
    staff_user_id, creator_label, operation_time, operation_time
  ) returning * into result_record;
  return public.work_order_result(result_record);
end
$$;

create or replace function public.update_work_order(
  p_work_order_id text,
  p_payload jsonb,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result_record public.work_orders;
  schedule_start timestamptz;
  schedule_end timestamptz;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_expected_version is null or p_expected_version < 1 then
    raise exception using errcode = '22023',
      message = 'Expected version is invalid.';
  end if;
  if p_payload is null
    or pg_catalog.jsonb_typeof(p_payload) <> 'object'
    or exists (
      select 1
      from pg_catalog.jsonb_object_keys(p_payload) payload_key
      where payload_key not in (
        'vehicle_id', 'task_type', 'description', 'priority',
        'scheduled_start', 'scheduled_end', 'notes'
      )
    ) then
    raise exception using errcode = '22023',
      message = 'Update payload is invalid.';
  end if;
  schedule_start := public.work_order_timestamp(
    p_payload -> 'scheduled_start',
    'Scheduled start'
  );
  schedule_end := public.work_order_timestamp(
    p_payload -> 'scheduled_end',
    'Scheduled end'
  );
  if (schedule_start is null) <> (schedule_end is null) then
    raise exception using errcode = '22023',
      message = 'Provide a valid complete schedule.';
  end if;
  if schedule_start is not null and schedule_end <= schedule_start then
    raise exception using errcode = '22023',
      message = 'Scheduled end must be later than scheduled start.';
  end if;
  if coalesce(pg_catalog.btrim(p_payload ->> 'vehicle_id'), '') = ''
    or coalesce(pg_catalog.btrim(p_payload ->> 'task_type'), '') = ''
    or coalesce(pg_catalog.btrim(p_payload ->> 'description'), '') = ''
    or pg_catalog.lower(pg_catalog.btrim(p_payload ->> 'priority'))
      not in ('low', 'medium', 'high', 'urgent') then
    raise exception using errcode = '22023',
      message = 'Required work-order fields are invalid.';
  end if;
  select * into result_record
  from public.work_orders
  where work_order_id = pg_catalog.btrim(p_work_order_id)
  for update;
  if not found then
    raise exception using errcode = 'P0002',
      message = 'Work order was not found.';
  end if;
  if result_record.version <> p_expected_version then
    raise exception using errcode = '40001',
      message = 'Work order changed. Refresh before saving.';
  end if;
  if result_record.status in ('completed', 'cancelled') then
    raise exception using errcode = '22023',
      message = 'Terminal work orders cannot be edited.';
  end if;
  if result_record.status in ('open', 'assigned', 'in_progress')
    and schedule_start is null then
    raise exception using errcode = '22023',
      message = 'This status requires a schedule.';
  end if;
  update public.work_orders
  set vehicle_id = pg_catalog.upper(pg_catalog.btrim(p_payload ->> 'vehicle_id')),
      task_type = pg_catalog.btrim(p_payload ->> 'task_type'),
      description = pg_catalog.btrim(p_payload ->> 'description'),
      priority = pg_catalog.lower(pg_catalog.btrim(p_payload ->> 'priority')),
      scheduled_start = schedule_start,
      scheduled_end = schedule_end,
      notes = nullif(pg_catalog.btrim(p_payload ->> 'notes'), '')
  where id = result_record.id
  returning * into result_record;
  return public.work_order_result(result_record);
end
$$;
