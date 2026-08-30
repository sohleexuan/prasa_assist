create sequence public.work_order_code_seq as bigint start 1 increment 1 minvalue 1 maxvalue 999999 no cycle cache 1;

create table public.work_orders (
 id uuid primary key default extensions.gen_random_uuid(), work_order_id text not null unique,
 publication_key text not null, publication_request_snapshot jsonb not null, publication_request_sha256 bytea not null,
 incident_id text, recommendation_id text, vehicle_id text not null, task_type text not null, description text not null,
 priority text not null, assigned_to text, scheduled_start timestamptz, scheduled_end timestamptz,
 status text not null default 'draft', notes text, created_by_user_id uuid not null, created_by_label text not null,
 created_at timestamptz not null, updated_at timestamptz not null, completed_at timestamptz, cancelled_at timestamptz,
 version bigint not null default 1,
 constraint work_orders_id_format check (work_order_id ~ '^WO-[0-9]{8}-[0-9]{6}$'),
 constraint work_orders_publication_key_check check (publication_key=btrim(publication_key) and char_length(publication_key) between 1 and 200),
 constraint work_orders_publication_object_check check (jsonb_typeof(publication_request_snapshot)='object'),
 constraint work_orders_publication_hash_check check (octet_length(publication_request_sha256)=32),
 constraint work_orders_creator_publication_unique unique(created_by_user_id,publication_key),
 constraint work_orders_required_text_check check (btrim(vehicle_id)<>'' and btrim(task_type)<>'' and btrim(description)<>'' and btrim(created_by_label)<>''),
 constraint work_orders_optional_text_check check ((incident_id is null or btrim(incident_id)<>'') and (recommendation_id is null or btrim(recommendation_id)<>'') and (assigned_to is null or btrim(assigned_to)<>'') and (notes is null or btrim(notes)<>'')),
 constraint work_orders_priority_check check (priority in ('low','medium','high','urgent')),
 constraint work_orders_status_check check (status in ('draft','open','assigned','in_progress','completed','cancelled')),
 constraint work_orders_schedule_pair_check check ((scheduled_start is null)=(scheduled_end is null)),
 constraint work_orders_schedule_order_check check (scheduled_start is null or scheduled_end>=scheduled_start),
 constraint work_orders_schedule_lifecycle_check check (status in ('draft','cancelled') or scheduled_start is not null),
 constraint work_orders_assignment_lifecycle_check check ((status in ('draft','open') and assigned_to is null) or (status in ('assigned','in_progress','completed') and assigned_to is not null) or status='cancelled'),
 constraint work_orders_terminal_check check ((status='completed' and completed_at is not null and cancelled_at is null) or (status='cancelled' and cancelled_at is not null and completed_at is null) or (status not in ('completed','cancelled') and completed_at is null and cancelled_at is null)),
 constraint work_orders_timestamp_order_check check (updated_at>=created_at and (completed_at is null or completed_at between created_at and updated_at) and (cancelled_at is null or cancelled_at between created_at and updated_at)),
 constraint work_orders_version_check check (version>=1)
);
create index work_orders_status_idx on public.work_orders(status);
create index work_orders_priority_idx on public.work_orders(priority);
create index work_orders_updated_idx on public.work_orders(updated_at desc);
create index work_orders_vehicle_idx on public.work_orders(vehicle_id);
create index work_orders_assignee_idx on public.work_orders(assigned_to) where assigned_to is not null;
create index work_orders_incident_idx on public.work_orders(incident_id) where incident_id is not null;
create index work_orders_recommendation_idx on public.work_orders(recommendation_id) where recommendation_id is not null;

alter table public.work_orders enable row level security;
create policy work_orders_authenticated_read on public.work_orders for select to authenticated using ((select auth.uid()) is not null);
revoke all on public.work_orders from public,anon,authenticated;
grant select(id,work_order_id,incident_id,recommendation_id,vehicle_id,task_type,description,priority,assigned_to,scheduled_start,scheduled_end,status,notes,created_by_user_id,created_by_label,created_at,updated_at,completed_at,cancelled_at,version) on public.work_orders to authenticated;
revoke all on sequence public.work_order_code_seq from public,anon,authenticated;

create function public.work_order_result(p public.work_orders) returns jsonb language sql stable set search_path='' as $$
 select pg_catalog.jsonb_build_object('id',p.id,'work_order_id',p.work_order_id,'incident_id',p.incident_id,'recommendation_id',p.recommendation_id,'vehicle_id',p.vehicle_id,'task_type',p.task_type,'description',p.description,'priority',p.priority,'assigned_to',p.assigned_to,'scheduled_start',p.scheduled_start,'scheduled_end',p.scheduled_end,'status',p.status,'notes',p.notes,'created_by_user_id',p.created_by_user_id,'created_by_label',p.created_by_label,'created_at',p.created_at,'updated_at',p.updated_at,'completed_at',p.completed_at,'cancelled_at',p.cancelled_at,'version',p.version)
$$;

create function public.work_order_timestamp(p_value jsonb,p_label text) returns timestamptz language plpgsql immutable set search_path='' as $$
declare v text; begin
 if p_value is null or p_value='null'::jsonb then return null; end if;
 if pg_catalog.jsonb_typeof(p_value)<>'string' then raise exception using errcode='22007',message=p_label||' must be an ISO-8601 string with a timezone.'; end if;
 v:=p_value#>>'{}';
 if v!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-][0-9]{2}:[0-9]{2})$' then raise exception using errcode='22007',message=p_label||' must include an explicit timezone.'; end if;
 begin return v::timestamptz; exception when others then raise exception using errcode='22007',message=p_label||' is not a valid timestamp.'; end;
end $$;

create function public.enforce_work_order_update() returns trigger language plpgsql set search_path='' as $$
declare t timestamptz:=pg_catalog.clock_timestamp(); begin
 if auth.uid() is null then raise exception using errcode='42501',message='Authentication is required.'; end if;
 if old.status in ('completed','cancelled') then raise exception using errcode='22023',message='Terminal work orders cannot be changed.'; end if;
 if new.id is distinct from old.id or new.work_order_id is distinct from old.work_order_id or new.publication_key is distinct from old.publication_key or new.publication_request_snapshot is distinct from old.publication_request_snapshot or new.publication_request_sha256 is distinct from old.publication_request_sha256 or new.incident_id is distinct from old.incident_id or new.recommendation_id is distinct from old.recommendation_id or new.created_by_user_id is distinct from old.created_by_user_id or new.created_by_label is distinct from old.created_by_label or new.created_at is distinct from old.created_at then raise exception using errcode='22023',message='Identity, linkage and audit fields are immutable.'; end if;
 if new.version is distinct from old.version or new.updated_at is distinct from old.updated_at or new.completed_at is distinct from old.completed_at or new.cancelled_at is distinct from old.cancelled_at then raise exception using errcode='22023',message='Version and lifecycle timestamps are server controlled.'; end if;
 if new.status is distinct from old.status and not ((old.status='draft' and new.status in ('open','cancelled')) or (old.status='open' and new.status in ('assigned','cancelled')) or (old.status='assigned' and new.status in ('in_progress','cancelled')) or (old.status='in_progress' and new.status in ('completed','cancelled'))) then raise exception using errcode='22023',message='Invalid work-order status transition.'; end if;
 if new.assigned_to is distinct from old.assigned_to and not(old.status='open' and new.status='assigned' and old.assigned_to is null and new.assigned_to is not null and pg_catalog.btrim(new.assigned_to)<>'') then raise exception using errcode='22023',message='Assignment is allowed only while moving Open to Assigned.'; end if;
 if old.status='open' and new.status='assigned' and new.assigned_to is not distinct from old.assigned_to then raise exception using errcode='22023',message='Assignment requires responsible staff.'; end if;
 new.updated_at:=t; new.version:=old.version+1;
 if new.status='completed' then new.completed_at:=t;new.cancelled_at:=null; elsif new.status='cancelled' then new.cancelled_at:=t;new.completed_at:=null; else new.completed_at:=null;new.cancelled_at:=null; end if;
 return new; end $$;
create trigger enforce_work_order_update before update on public.work_orders for each row execute function public.enforce_work_order_update();

create function public.create_work_order(p_publication_key text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); k text:=pg_catalog.btrim(p_publication_key); now_at timestamptz:=pg_catalog.clock_timestamp(); s timestamptz;e timestamptz;snap jsonb;h bytea;existing public.work_orders;r public.work_orders;label text;n bigint;
begin
 if u is null then raise exception using errcode='42501',message='Authentication is required.'; end if;
 if k is null or pg_catalog.char_length(k) not between 1 and 200 then raise exception using errcode='22023',message='Publication key is required.'; end if;
 if p_payload is null or pg_catalog.jsonb_typeof(p_payload)<>'object' or exists(select 1 from pg_catalog.jsonb_object_keys(p_payload) x where x not in ('incident_id','recommendation_id','vehicle_id','task_type','description','priority','scheduled_start','scheduled_end','notes')) then raise exception using errcode='22023',message='Publication payload is invalid.'; end if;
 s:=public.work_order_timestamp(p_payload->'scheduled_start','Scheduled start'); e:=public.work_order_timestamp(p_payload->'scheduled_end','Scheduled end');
 if (s is null)<>(e is null) or (s is not null and e<s) then raise exception using errcode='22023',message='Provide a valid complete schedule.'; end if;
 if coalesce(pg_catalog.btrim(p_payload->>'vehicle_id'),'')='' or coalesce(pg_catalog.btrim(p_payload->>'task_type'),'')='' or coalesce(pg_catalog.btrim(p_payload->>'description'),'')='' then raise exception using errcode='22023',message='Vehicle, task type and description are required.'; end if;
 if pg_catalog.lower(pg_catalog.btrim(p_payload->>'priority')) not in ('low','medium','high','urgent') then raise exception using errcode='22023',message='Priority is invalid.'; end if;
 snap:=pg_catalog.jsonb_build_object('incident_id',nullif(pg_catalog.btrim(p_payload->>'incident_id'),''),'recommendation_id',nullif(pg_catalog.btrim(p_payload->>'recommendation_id'),''),'vehicle_id',pg_catalog.upper(pg_catalog.btrim(p_payload->>'vehicle_id')),'task_type',pg_catalog.btrim(p_payload->>'task_type'),'description',pg_catalog.btrim(p_payload->>'description'),'priority',pg_catalog.lower(pg_catalog.btrim(p_payload->>'priority')),'scheduled_start',case when s is null then null else pg_catalog.to_char(s at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') end,'scheduled_end',case when e is null then null else pg_catalog.to_char(e at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') end,'notes',nullif(pg_catalog.btrim(p_payload->>'notes'),''));
 h:=extensions.digest(pg_catalog.convert_to(snap::text,'UTF8'),'sha256');
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(u::text||E'\x1f'||k,0));
 select * into existing from public.work_orders where created_by_user_id=u and publication_key=k for update;
 if found then if existing.publication_request_snapshot=snap and existing.publication_request_sha256=h then return public.work_order_result(existing); end if; raise exception using errcode='40001',message='Publication key was already used for different content.'; end if;
 n:=pg_catalog.nextval('public.work_order_code_seq'::pg_catalog.regclass);
 label:=coalesce(nullif(pg_catalog.btrim(auth.jwt()->>'email'),''),u::text);
 insert into public.work_orders(work_order_id,publication_key,publication_request_snapshot,publication_request_sha256,incident_id,recommendation_id,vehicle_id,task_type,description,priority,scheduled_start,scheduled_end,notes,created_by_user_id,created_by_label,created_at,updated_at)
 values('WO-'||pg_catalog.to_char(now_at at time zone 'UTC','YYYYMMDD')||'-'||pg_catalog.lpad(n::text,6,'0'),k,snap,h,snap->>'incident_id',snap->>'recommendation_id',snap->>'vehicle_id',snap->>'task_type',snap->>'description',snap->>'priority',s,e,snap->>'notes',u,label,now_at,now_at) returning * into r;
 return public.work_order_result(r); end $$;

create function public.update_work_order(p_work_order_id text,p_payload jsonb,p_expected_version bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.work_orders;s timestamptz;e timestamptz; begin
 if auth.uid() is null then raise exception using errcode='42501',message='Authentication is required.'; end if;
 if p_expected_version is null or p_expected_version<1 then raise exception using errcode='22023',message='Expected version is invalid.'; end if;
 if p_payload is null or pg_catalog.jsonb_typeof(p_payload)<>'object' or exists(select 1 from pg_catalog.jsonb_object_keys(p_payload) x where x not in ('vehicle_id','task_type','description','priority','scheduled_start','scheduled_end','notes')) then raise exception using errcode='22023',message='Update payload is invalid.'; end if;
 s:=public.work_order_timestamp(p_payload->'scheduled_start','Scheduled start');e:=public.work_order_timestamp(p_payload->'scheduled_end','Scheduled end');
 if (s is null)<>(e is null) or (s is not null and e<s) then raise exception using errcode='22023',message='Provide a valid complete schedule.'; end if;
 if coalesce(pg_catalog.btrim(p_payload->>'vehicle_id'),'')='' or coalesce(pg_catalog.btrim(p_payload->>'task_type'),'')='' or coalesce(pg_catalog.btrim(p_payload->>'description'),'')='' or pg_catalog.lower(pg_catalog.btrim(p_payload->>'priority')) not in ('low','medium','high','urgent') then raise exception using errcode='22023',message='Required work-order fields are invalid.'; end if;
 select * into r from public.work_orders where work_order_id=pg_catalog.btrim(p_work_order_id) for update;
 if not found then raise exception using errcode='P0002',message='Work order was not found.'; end if;
 if r.version<>p_expected_version then raise exception using errcode='40001',message='Work order changed. Refresh before saving.'; end if;
 if r.status in ('completed','cancelled') then raise exception using errcode='22023',message='Terminal work orders cannot be edited.'; end if;
 if r.status in ('open','assigned','in_progress') and s is null then raise exception using errcode='22023',message='This status requires a schedule.'; end if;
 update public.work_orders set vehicle_id=pg_catalog.upper(pg_catalog.btrim(p_payload->>'vehicle_id')),task_type=pg_catalog.btrim(p_payload->>'task_type'),description=pg_catalog.btrim(p_payload->>'description'),priority=pg_catalog.lower(pg_catalog.btrim(p_payload->>'priority')),scheduled_start=s,scheduled_end=e,notes=nullif(pg_catalog.btrim(p_payload->>'notes'),'') where id=r.id returning * into r;
 return public.work_order_result(r); end $$;

create function public.assign_work_order(p_work_order_id text,p_assigned_to text,p_expected_version bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.work_orders;a text:=pg_catalog.btrim(p_assigned_to); begin
 if auth.uid() is null then raise exception using errcode='42501',message='Authentication is required.'; end if;
 if coalesce(a,'')='' or p_expected_version is null or p_expected_version<1 then raise exception using errcode='22023',message='Assignment input is invalid.'; end if;
 select * into r from public.work_orders where work_order_id=pg_catalog.btrim(p_work_order_id) for update;
 if not found then raise exception using errcode='P0002',message='Work order was not found.'; end if;
 if r.version<>p_expected_version then raise exception using errcode='40001',message='Work order changed. Refresh before assigning.'; end if;
 if r.status<>'open' or r.assigned_to is not null then raise exception using errcode='22023',message='Only an unassigned Open work order can be assigned.'; end if;
 update public.work_orders set assigned_to=a,status='assigned' where id=r.id returning * into r; return public.work_order_result(r); end $$;

create function public.transition_work_order(p_work_order_id text,p_to_status text,p_expected_version bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.work_orders;t text:=pg_catalog.lower(pg_catalog.btrim(p_to_status)); begin
 if auth.uid() is null then raise exception using errcode='42501',message='Authentication is required.'; end if;
 if p_expected_version is null or p_expected_version<1 or t not in ('open','in_progress','completed','cancelled') then raise exception using errcode='22023',message='Status transition input is invalid.'; end if;
 select * into r from public.work_orders where work_order_id=pg_catalog.btrim(p_work_order_id) for update;
 if not found then raise exception using errcode='P0002',message='Work order was not found.'; end if;
 if r.version<>p_expected_version then raise exception using errcode='40001',message='Work order changed. Refresh before continuing.'; end if;
 if not((r.status='draft' and t in ('open','cancelled')) or (r.status='open' and t='cancelled') or (r.status='assigned' and t in ('in_progress','cancelled')) or (r.status='in_progress' and t in ('completed','cancelled'))) then raise exception using errcode='22023',message='Invalid work-order status transition.'; end if;
 if t='open' and r.scheduled_start is null then raise exception using errcode='22023',message='A schedule is required before opening.'; end if;
 update public.work_orders set status=t where id=r.id returning * into r; return public.work_order_result(r); end $$;

revoke all on function public.work_order_result(public.work_orders) from public,anon,authenticated;
revoke all on function public.work_order_timestamp(jsonb,text) from public,anon,authenticated;
revoke all on function public.create_work_order(text,jsonb) from public,anon,authenticated;
revoke all on function public.update_work_order(text,jsonb,bigint) from public,anon,authenticated;
revoke all on function public.assign_work_order(text,text,bigint) from public,anon,authenticated;
revoke all on function public.transition_work_order(text,text,bigint) from public,anon,authenticated;
grant execute on function public.create_work_order(text,jsonb) to authenticated;
grant execute on function public.update_work_order(text,jsonb,bigint) to authenticated;
grant execute on function public.assign_work_order(text,text,bigint) to authenticated;
grant execute on function public.transition_work_order(text,text,bigint) to authenticated;
