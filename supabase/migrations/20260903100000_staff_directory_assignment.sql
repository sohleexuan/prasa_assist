-- Read-only preflight. Review these aggregate/catalog results before applying
-- this source manually. This migration must not be pushed or applied by Codex.
select
  pg_catalog.to_regclass('public.work_orders') is not null
    as work_orders_exists,
  pg_catalog.to_regclass('public.recommendations') is not null
    as recommendations_exists,
  exists (
    select 1
    from pg_catalog.pg_attribute a
    where a.attrelid = 'public.work_orders'::pg_catalog.regclass
      and a.attname = 'route_id'
      and not a.attisdropped
  ) as route_id_exists,
  pg_catalog.to_regprocedure(
    'public.enforce_work_order_schedule_integrity()'
  ) is not null as route_schedule_guard_exists;

select
  a.attname as assignment_column,
  pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type,
  not a.attnotnull as nullable
from pg_catalog.pg_attribute a
where a.attrelid = 'public.work_orders'::pg_catalog.regclass
  and a.attname in (
    'assigned_to', 'assigned_to_user_id', 'assigned_to_label_snapshot'
  )
  and not a.attisdropped
order by a.attname;

select
  c.conname,
  pg_catalog.pg_get_constraintdef(c.oid) as definition
from pg_catalog.pg_constraint c
where c.conrelid = 'public.work_orders'::pg_catalog.regclass
  and (
    c.conname ilike '%assign%'
    or c.conname ilike '%route%'
    or c.conname ilike '%schedule%'
  )
order by c.conname;

select
  n.nspname as schema_name,
  p.proname,
  pg_catalog.pg_get_function_identity_arguments(p.oid) as arguments
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'assign_work_order', 'assign_work_order_to_staff',
    'list_staff_directory', 'list_assignable_staff'
  )
order by p.proname, arguments;

select
  pg_catalog.to_regclass('public.staff_profiles') as staff_profiles_relation,
  count(*) filter (where p.proname like '%staff_profile%')
    as staff_profile_function_name_conflicts
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public';

select count(*) as auth_user_count from auth.users;

select
  count(*) filter (where assigned_to is not null) as assigned_row_count,
  count(distinct assigned_to) filter (where assigned_to is not null)
    as distinct_assigned_to_count,
  count(*) filter (
    where assigned_to is not null
      and assigned_to = created_by_label
  ) as assigned_to_creator_label_match_count,
  count(*) filter (
    where assigned_to is not null
      and assigned_to ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) as uuid_shaped_assigned_to_count,
  count(*) filter (
    where status in ('assigned', 'in_progress', 'completed')
      and assigned_to is not null
  ) as blocking_legacy_assignment_count
from public.work_orders;

select
  c.relname,
  c.relrowsecurity,
  c.relforcerowsecurity,
  c.relacl
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('work_orders', 'staff_profiles')
order by c.relname;

select
  grantee,
  table_name,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('work_orders', 'staff_profiles')
order by table_name, grantee, privilege_type;

begin;

create table public.staff_profiles (
  user_id uuid primary key
    references auth.users(id) on delete restrict,
  staff_code text unique not null,
  display_name text not null,
  role text not null,
  active boolean not null default false,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  version bigint not null default 1,
  constraint staff_profiles_staff_code_check check (
    staff_code = pg_catalog.upper(pg_catalog.btrim(staff_code))
    and staff_code <> ''
  ),
  constraint staff_profiles_display_name_check check (
    display_name = pg_catalog.btrim(display_name)
    and display_name <> ''
  ),
  constraint staff_profiles_role_check check (
    role in (
      'operations_staff', 'maintenance_staff',
      'supervisor', 'control_centre'
    )
  ),
  constraint staff_profiles_timestamp_order_check check (
    updated_at >= created_at
  ),
  constraint staff_profiles_version_check check (version >= 1)
);

create index staff_profiles_active_role_name_idx
  on public.staff_profiles(active, role, display_name, staff_code);

create function public.enforce_staff_profile_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  operation_time timestamptz := pg_catalog.clock_timestamp();
begin
  new.staff_code := pg_catalog.upper(pg_catalog.btrim(new.staff_code));
  new.display_name := pg_catalog.btrim(new.display_name);
  if tg_op = 'INSERT' then
    new.created_at := operation_time;
    new.updated_at := operation_time;
    new.version := 1;
    return new;
  end if;
  if new.user_id is distinct from old.user_id
    or new.created_at is distinct from old.created_at then
    raise exception using
      errcode = '22023',
      message = 'Staff profile identity and creation time are immutable.';
  end if;
  if new.updated_at is distinct from old.updated_at
    or new.version is distinct from old.version then
    raise exception using
      errcode = '22023',
      message = 'Staff profile version and update time are database controlled.';
  end if;
  new.updated_at := operation_time;
  new.version := old.version + 1;
  return new;
end
$$;

create trigger enforce_staff_profile_write
before insert or update on public.staff_profiles
for each row execute function public.enforce_staff_profile_write();

alter table public.staff_profiles enable row level security;

revoke all on table public.staff_profiles from public, anon, authenticated;
revoke all on table public.staff_profiles from service_role;
revoke all on function public.enforce_staff_profile_write()
  from public, anon, authenticated;

create function public.list_staff_directory()
returns table (
  user_id uuid,
  staff_code text,
  display_name text,
  role text,
  version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null or not exists (
    select 1
    from public.staff_profiles caller
    where caller.user_id = caller_id
      and caller.active
  ) then
    raise exception using
      errcode = '42501',
      message = 'An active authenticated staff profile is required.';
  end if;

  return query
  select
    profile.user_id,
    profile.staff_code,
    profile.display_name,
    profile.role,
    profile.version
  from public.staff_profiles profile
  where profile.active
  order by profile.display_name, profile.staff_code;
end
$$;

create function public.list_assignable_staff()
returns table (
  user_id uuid,
  staff_code text,
  display_name text,
  role text,
  version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null or not exists (
    select 1
    from public.staff_profiles caller
    where caller.user_id = caller_id
      and caller.active
  ) then
    raise exception using
      errcode = '42501',
      message = 'An active authenticated staff profile is required.';
  end if;

  return query
  select
    profile.user_id,
    profile.staff_code,
    profile.display_name,
    profile.role,
    profile.version
  from public.staff_profiles profile
  where profile.active
    and profile.role = 'maintenance_staff'
  order by profile.display_name, profile.staff_code;
end
$$;

revoke all on function public.list_staff_directory()
  from public, anon, authenticated;
revoke all on function public.list_assignable_staff()
  from public, anon, authenticated;
grant execute on function public.list_staff_directory() to authenticated;
grant execute on function public.list_assignable_staff() to authenticated;

alter table public.work_orders
  add column assigned_to_user_id uuid null,
  add column assigned_to_label_snapshot text null;

alter table public.work_orders
  add constraint work_orders_assigned_to_user_fkey
    foreign key (assigned_to_user_id)
    references public.staff_profiles(user_id)
    on delete restrict,
  add constraint work_orders_assignment_snapshot_pair_check check (
    (assigned_to_user_id is null) = (assigned_to_label_snapshot is null)
  ),
  add constraint work_orders_assignment_snapshot_not_blank_check check (
    assigned_to_label_snapshot is null
    or pg_catalog.btrim(assigned_to_label_snapshot) <> ''
  );

create index work_orders_assigned_to_user_idx
  on public.work_orders(assigned_to_user_id)
  where assigned_to_user_id is not null;

grant select(assigned_to_user_id, assigned_to_label_snapshot)
  on public.work_orders to authenticated;

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
    'assigned_to_user_id', p.assigned_to_user_id,
    'assigned_to_label_snapshot', p.assigned_to_label_snapshot,
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
  assignment_changed boolean;
  expected_assignment_label text;
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

  assignment_changed :=
    new.assigned_to is distinct from old.assigned_to
    or new.assigned_to_user_id is distinct from old.assigned_to_user_id
    or new.assigned_to_label_snapshot
      is distinct from old.assigned_to_label_snapshot;

  if assignment_changed then
    if not (
      old.status = 'open'
      and new.status = 'assigned'
      and old.assigned_to is null
      and old.assigned_to_user_id is null
      and old.assigned_to_label_snapshot is null
      and new.assigned_to is not null
      and new.assigned_to_user_id is not null
      and new.assigned_to_label_snapshot is not null
    ) then
      raise exception using errcode = '22023',
        message = 'Assignment is allowed only while moving Open to Assigned.';
    end if;

    if not exists (
      select 1
      from public.staff_profiles caller
      where caller.user_id = auth.uid()
        and caller.active
        and caller.role in ('supervisor', 'control_centre')
    ) then
      raise exception using errcode = '42501',
        message = 'Only active supervisors or control-centre staff can assign work orders.';
    end if;

    select profile.display_name || ' (' || profile.staff_code || ')'
    into expected_assignment_label
    from public.staff_profiles profile
    where profile.user_id = new.assigned_to_user_id
      and profile.active
      and profile.role = 'maintenance_staff';

    if expected_assignment_label is null then
      raise exception using errcode = '22023',
        message = 'The selected assignee is not active maintenance staff.';
    end if;
    if new.assigned_to_label_snapshot <> expected_assignment_label
      or new.assigned_to <> expected_assignment_label then
      raise exception using errcode = '22023',
        message = 'The assignment label must be generated by the database.';
    end if;
  elsif old.status = 'open' and new.status = 'assigned' then
    raise exception using errcode = '22023',
      message = 'Assignment requires a verified staff profile.';
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

create or replace function public.assign_work_order(
  p_work_order_id text,
  p_assigned_to text,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '42501',
      message = 'Authentication is required.';
  end if;
  raise exception using errcode = '0A000',
    message = 'Free-text assignment is disabled. Upgrade and use assign_work_order_to_staff.';
end
$$;

create function public.assign_work_order_to_staff(
  p_work_order_id text,
  p_assigned_to_user_id uuid,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  assignee_label text;
  result_record public.work_orders;
begin
  if caller_id is null then
    raise exception using errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if not exists (
    select 1
    from public.staff_profiles caller
    where caller.user_id = caller_id
      and caller.active
      and caller.role in ('supervisor', 'control_centre')
  ) then
    raise exception using errcode = '42501',
      message = 'Only active supervisors or control-centre staff can assign work orders.';
  end if;
  if p_assigned_to_user_id is null
    or p_expected_version is null
    or p_expected_version < 1 then
    raise exception using errcode = '22023',
      message = 'Assignment input is invalid.';
  end if;

  select profile.display_name || ' (' || profile.staff_code || ')'
  into assignee_label
  from public.staff_profiles profile
  where profile.user_id = p_assigned_to_user_id
    and profile.active
    and profile.role = 'maintenance_staff';
  if assignee_label is null then
    raise exception using errcode = '22023',
      message = 'The selected assignee is not active maintenance staff.';
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
      message = 'Work order changed. Refresh before assigning.';
  end if;
  if result_record.status <> 'open'
    or result_record.assigned_to is not null
    or result_record.assigned_to_user_id is not null then
    raise exception using errcode = '22023',
      message = 'Only an unassigned Open work order can be assigned.';
  end if;

  update public.work_orders
  set assigned_to = assignee_label,
      assigned_to_user_id = p_assigned_to_user_id,
      assigned_to_label_snapshot = assignee_label,
      status = 'assigned'
  where id = result_record.id
  returning * into result_record;

  return public.work_order_result(result_record);
end
$$;

revoke all on function public.work_order_result(public.work_orders)
  from public, anon, authenticated;
revoke all on function public.enforce_work_order_update()
  from public, anon, authenticated;
revoke all on function public.assign_work_order(text, text, bigint)
  from public, anon, authenticated;
revoke all on function public.assign_work_order_to_staff(text, uuid, bigint)
  from public, anon, authenticated;
grant execute on function public.assign_work_order(text, text, bigint)
  to authenticated;
grant execute on function public.assign_work_order_to_staff(text, uuid, bigint)
  to authenticated;

commit;
