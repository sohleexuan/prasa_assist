begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pg_catalog;
select no_plan();

select has_table('public','work_orders','work_orders table exists');
select has_sequence('public','work_order_code_seq','six-digit allocation sequence exists');
select col_is_pk('public','work_orders','id','storage UUID is primary key');
select col_is_unique('public','work_orders','work_order_id','public work-order ID is unique');
select ok((select seqmax=999999 and not seqcycle from pg_sequence where seqrelid='public.work_order_code_seq'::regclass),'sequence provides at most 999999 allocated values and does not cycle');
select ok((select relrowsecurity from pg_class where oid='public.work_orders'::regclass),'RLS is enabled');
select policies_are('public','work_orders',array['work_orders_authenticated_read'],'only shared authenticated read policy exists');
select ok(not has_table_privilege('authenticated','public.work_orders','SELECT'),'authenticated has no table-wide SELECT grant');
select ok(has_column_privilege('authenticated','public.work_orders','work_order_id','SELECT'),'authenticated can read DTO identity columns');
select ok(has_column_privilege('authenticated','public.work_orders','route_id','SELECT'),'authenticated can read Route linkage');
select ok(not has_table_privilege('authenticated','public.work_orders','INSERT'),'direct authenticated insert is denied');
select ok(not has_table_privilege('authenticated','public.work_orders','UPDATE'),'direct authenticated update is denied');
select ok(not has_table_privilege('authenticated','public.work_orders','DELETE'),'direct authenticated delete is denied');
select ok(not has_column_privilege('authenticated','public.work_orders','publication_key','SELECT'),'publication key is private');
select ok(not has_column_privilege('authenticated','public.work_orders','publication_request_snapshot','SELECT'),'publication snapshot is private');
select ok(not has_column_privilege('authenticated','public.work_orders','publication_request_sha256','SELECT'),'publication hash is private');
select ok(not has_sequence_privilege('authenticated','public.work_order_code_seq','USAGE'),'sequence is RPC-private');
select function_returns('public','create_work_order',array['text','jsonb'],'jsonb','create RPC returns DTO JSON');
select function_returns('public','update_work_order',array['text','jsonb','bigint'],'jsonb','update RPC returns DTO JSON');
select function_returns('public','assign_work_order',array['text','text','bigint'],'jsonb','assignment RPC returns DTO JSON');
select function_returns('public','transition_work_order',array['text','text','bigint'],'jsonb','transition RPC returns DTO JSON');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname~*'delete.*work_order|work_order.*delete'),'no delete RPC exists');
select ok(exists(select 1 from pg_trigger where tgrelid='public.work_orders'::regclass and tgname='enforce_work_order_schedule_integrity' and tgenabled='O'),'lifecycle-aware schedule trigger is enabled');
select ok(not has_function_privilege('authenticated','public.enforce_work_order_schedule_integrity()','EXECUTE'),'schedule trigger function is not client-callable');

select ok((select bool_and(p.prosecdef and p.proconfig@>array['search_path=""']) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('create_work_order','update_work_order','assign_work_order','transition_work_order')),'all write RPCs are SECURITY DEFINER with empty search_path');
select ok((select bool_and(pg_get_functiondef(p.oid)!~'[^.]\m(work_orders|work_order_code_seq)\M' and pg_get_functiondef(p.oid)!~'[^.]\m(uid|jwt|digest)\s*\(') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('create_work_order','update_work_order','assign_work_order','transition_work_order')),'SECURITY DEFINER protected references are schema-qualified');
select ok((select bool_and(pg_get_functiondef(p.oid)!~*'\mexecute\M') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('create_work_order','update_work_order','assign_work_order','transition_work_order')),'write RPCs contain no dynamic SQL');

select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","email":"staff.one@example.com","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select count(*) from public.work_orders$$,'authenticated operations staff can read shared confirmed work orders');
select throws_ok($$select publication_key from public.work_orders$$,'42501',null,'authenticated staff cannot retrieve publication key');
select throws_ok($$select publication_request_snapshot from public.work_orders$$,'42501',null,'authenticated staff cannot retrieve publication snapshot');
select throws_ok($$select publication_request_sha256 from public.work_orders$$,'42501',null,'authenticated staff cannot retrieve publication hash');
select throws_ok($$insert into public.work_orders(id) values(extensions.gen_random_uuid())$$,'42501',null,'authenticated direct insert is denied');

select lives_ok($$select public.create_work_order(' local-b1023 ', '{"incident_id":"INC-B1023-ROUTE-300","recommendation_id":"REC-INSPECT-B1023","route_id":"300","vehicle_id":"b1023","task_type":"Inspection","description":"Inspect Bus B1023 after its Route 300 breakdown.","priority":"urgent","scheduled_start":"2026-08-30T08:00:00+08:00","scheduled_end":"2026-08-30T09:00:00+08:00","notes":"AI recommends. Staff decides."}'::jsonb)$$,'staff can explicitly publish a reviewed draft');
select throws_ok($$select public.create_work_order('spoof-label','{"vehicle_id":"B1023","task_type":"Inspection","description":"Attempt spoof","priority":"high","created_by_label":"spoof@example.com"}'::jsonb)$$,'22023','Publication payload is invalid.','client cannot submit a confirmed creator label');
select lives_ok($$select public.create_work_order('local-offset','{"vehicle_id":"B1023","task_type":"Inspection","description":"Offset accepted","priority":"high","scheduled_start":"2026-08-30T08:00:00+08:00","scheduled_end":"2026-08-30T09:00:00+08:00"}'::jsonb)$$,'numeric timezone offsets are accepted');
select throws_ok($$select public.create_work_order('bad-date','{"vehicle_id":"B1023","task_type":"Inspection","description":"Bad date","priority":"high","scheduled_start":"2026-08-30","scheduled_end":"2026-08-30"}'::jsonb)$$,'22007',null,'date-only timestamps are rejected');
select throws_ok($$select public.create_work_order('bad-local','{"vehicle_id":"B1023","task_type":"Inspection","description":"Bad local","priority":"high","scheduled_start":"2026-08-30T08:00:00","scheduled_end":"2026-08-30T09:00:00"}'::jsonb)$$,'22007',null,'timezone-free timestamps are rejected');
select throws_ok($$select public.create_work_order('bad-relative','{"vehicle_id":"B1023","task_type":"Inspection","description":"Bad relative","priority":"high","scheduled_start":"tomorrow","scheduled_end":"tomorrow"}'::jsonb)$$,'22007',null,'relative timestamps are rejected');
select throws_ok($$select public.create_work_order('half','{"vehicle_id":"B1023","task_type":"Inspection","description":"Half schedule","priority":"high","scheduled_start":"2026-08-30T08:00:00Z"}'::jsonb)$$,'22023','Provide a valid complete schedule.','half schedules are rejected');
select throws_ok($$select public.create_work_order('reverse','{"vehicle_id":"B1023","task_type":"Inspection","description":"Reverse schedule","priority":"high","scheduled_start":"2026-08-30T09:00:00Z","scheduled_end":"2026-08-30T08:00:00Z"}'::jsonb)$$,'22023','Scheduled end must be later than scheduled start.','reversed schedules are rejected');
select throws_ok($$select public.create_work_order('equal','{"vehicle_id":"B1023","task_type":"Inspection","description":"Equal schedule","priority":"high","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T08:00:00Z"}'::jsonb)$$,'22023','Scheduled end must be later than scheduled start.','equal schedules are rejected');
reset role;

select is((select created_by_user_id from public.work_orders where publication_key='local-b1023'),'11111111-1111-4111-8111-111111111111'::uuid,'creator UUID comes from auth.uid');
select is((select created_by_label from public.work_orders where publication_key='local-b1023'),'staff.one@example.com','creator label comes from JWT email');
select is((select vehicle_id from public.work_orders where publication_key='local-b1023'),'B1023','vehicle ID is normalized');
select is((select incident_id from public.work_orders where publication_key='local-b1023'),'INC-B1023-ROUTE-300','incident linkage is preserved');
select is((select recommendation_id from public.work_orders where publication_key='local-b1023'),'REC-INSPECT-B1023','recommendation linkage is preserved');
select is((select route_id from public.work_orders where publication_key='local-b1023'),'300','Route linkage is preserved');
select ok((select publication_request_snapshot->>'route_id'='300' and publication_request_sha256=extensions.digest(convert_to(publication_request_snapshot::text,'UTF8'),'sha256') from public.work_orders where publication_key='local-b1023'),'canonical publication snapshot and hash include Route linkage');
select is((select version from public.work_orders where publication_key='local-b1023'),1::bigint,'confirmed record starts at version one');
select is((select created_at from public.work_orders where publication_key='local-b1023'),(select updated_at from public.work_orders where publication_key='local-b1023'),'creation captures one timestamp');
select ok((select work_order_id~'^WO-[0-9]{8}-[0-9]{6}$' from public.work_orders where publication_key='local-b1023'),'server generates the public ID');
set local timezone='Pacific/Honolulu';
select is(substring((select work_order_id from public.work_orders where publication_key='local-b1023') from 4 for 8),to_char((select created_at at time zone 'UTC' from public.work_orders where publication_key='local-b1023'),'YYYYMMDD'),'business ID date is UTC and session-timezone independent');
set local timezone='UTC';

set local role authenticated;
select is((public.create_work_order('local-b1023','{"incident_id":"INC-B1023-ROUTE-300","recommendation_id":"REC-INSPECT-B1023","route_id":"300","vehicle_id":"B1023","task_type":"Inspection","description":"Inspect Bus B1023 after its Route 300 breakdown.","priority":"urgent","scheduled_start":"2026-08-30T00:00:00Z","scheduled_end":"2026-08-30T01:00:00Z","notes":"AI recommends. Staff decides."}'::jsonb)->>'work_order_id'),(select work_order_id from public.work_orders where description='Inspect Bus B1023 after its Route 300 breakdown.'),'same canonical publication returns the same work order');
select throws_ok($$select public.create_work_order('local-b1023','{"vehicle_id":"B9999","task_type":"Inspection","description":"Different","priority":"urgent"}'::jsonb)$$,'40001','Publication key was already used for different content.','same publication key cannot represent different content');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Inspect Bus B1023 after its Route 300 breakdown.'),'open',1)$$,'scheduled Draft can become Open');
select lives_ok($$select public.assign_work_order((select work_order_id from public.work_orders where description='Inspect Bus B1023 after its Route 300 breakdown.'),'Technician A',2)$$,'Open can be explicitly assigned');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Inspect Bus B1023 after its Route 300 breakdown.'),'in_progress',3)$$,'Assigned can start');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Inspect Bus B1023 after its Route 300 breakdown.'),'completed',4)$$,'In Progress can complete');
select throws_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Inspect Bus B1023 after its Route 300 breakdown.'),'cancelled',5)$$,'22023','Invalid work-order status transition.','Completed is terminal');
reset role;

select is((select version from public.work_orders where publication_key='local-b1023'),5::bigint,'each accepted mutation increments version exactly once');
select is((select completed_at from public.work_orders where publication_key='local-b1023'),(select updated_at from public.work_orders where publication_key='local-b1023'),'completion and update use the same operation timestamp');
select is((select created_by_label from public.work_orders where publication_key='local-b1023'),'staff.one@example.com','creator label remains immutable');
select is((select incident_id from public.work_orders where publication_key='local-b1023'),'INC-B1023-ROUTE-300','linkage remains immutable through workflow');
select throws_ok($$update public.work_orders set created_by_label='spoof' where publication_key='local-b1023'$$,'22023','Terminal work orders cannot be changed.','direct creator mutation is rejected by authority trigger');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.create_work_order('uuid-label','{"vehicle_id":"B1023","task_type":"Inspection","description":"UUID label fallback","priority":"low"}'::jsonb)$$,'publication succeeds without an email claim');
reset role;
select is((select created_by_label from public.work_orders where publication_key='uuid-label'),'22222222-2222-4222-8222-222222222222','creator label falls back to authenticated UUID');

-- Authority, DTO boundary, idempotency, and lifecycle regression coverage.
set local role authenticated;
select throws_ok($$update public.work_orders set notes='direct update'$$,'42501',null,'authenticated direct UPDATE fails at runtime');
select throws_ok($$delete from public.work_orders$$,'42501',null,'authenticated direct DELETE fails at runtime');
select throws_ok($$select * from public.work_orders$$,'42501',null,'wildcard SELECT cannot expose private publication metadata');
select lives_ok($$select work_order_id from public.work_orders where description='Inspect Bus B1023 after its Route 300 breakdown.'$$,'second authenticated staff member can read another creator work order');
reset role;
set local role anon;
select throws_ok($$select count(*) from public.work_orders$$,'42501',null,'anonymous read is denied');
select throws_ok($$select public.create_work_order('anon-test','{"vehicle_id":"B1023","task_type":"Inspection","description":"Anon","priority":"low"}'::jsonb)$$,'42501',null,'anonymous create is denied');
select throws_ok($$select public.update_work_order('missing','{}'::jsonb,1)$$,'42501',null,'anonymous update is denied');
select throws_ok($$select public.assign_work_order('missing','Technician A',1)$$,'42501',null,'anonymous assignment is denied');
select throws_ok($$select public.transition_work_order('missing','cancelled',1)$$,'42501',null,'anonymous transition is denied');
reset role;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","email":"staff.one@example.com","role":"authenticated"}',true);
set local role authenticated;
select lives_ok(
  $$select public.create_work_order('shared-edit','{"incident_id":"INC-B1023-ROUTE-300","recommendation_id":"REC-INSPECT-B1023","route_id":"300","vehicle_id":"B1023","task_type":"Inspection","description":"Created by first staff member","priority":"high","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T09:00:00Z"}'::jsonb)$$,
  'first authenticated staff member creates a shared work order'
);
reset role;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
set local role authenticated;
select lives_ok(
  $$select public.update_work_order((select work_order_id from public.work_orders where description='Created by first staff member'),'{"vehicle_id":"B1023","task_type":"Inspection","description":"Reviewed by second staff member","priority":"urgent","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T09:00:00Z","notes":"Staff reviewed"}'::jsonb,1)$$,
  'second authenticated staff member can update a shared work order'
);
reset role;
select ok(
  (select created_by_user_id='11111111-1111-4111-8111-111111111111'::uuid
    and description='Reviewed by second staff member'
    and incident_id='INC-B1023-ROUTE-300'
    and recommendation_id='REC-INSPECT-B1023'
    and route_id='300'
    and version=2
   from public.work_orders where publication_key='shared-edit'),
  'shared update preserves immutable creator and linkage while advancing version'
);
select throws_ok($$update public.work_orders set route_id='999' where publication_key='shared-edit'$$,'22023','Identity, linkage and audit fields are immutable.','Route linkage cannot be mutated');
set local role authenticated;

select ok(
  not (
    public.create_work_order(
      'dto-boundary',
      '{"vehicle_id":"B1023","task_type":"Inspection","description":"DTO response","priority":"low"}'::jsonb
    ) ?| array['publication_key','publication_request_snapshot','publication_request_sha256']
  ),
  'create RPC DTO JSON excludes all publication metadata'
);
select lives_ok(
  $$select public.create_work_order(' trim-key ','{"vehicle_id":"B1023","task_type":"Inspection","description":"Trimmed publication key","priority":"low"}'::jsonb)$$,
  'publication key accepts surrounding whitespace'
);
reset role;
select is((select publication_key from public.work_orders where description='Trimmed publication key'),'trim-key','publication key is trimmed before storage');
set local role authenticated;
select lives_ok(
  $$select public.create_work_order('local-b1023','{"vehicle_id":"B1023","task_type":"Inspection","description":"Second creator key","priority":"low"}'::jsonb)$$,
  'different creators may use the same publication key'
);
reset role;
select is((select count(*) from public.work_orders where publication_key='local-b1023'),2::bigint,'creator-scoped publication key remains unique per creator');
select ok(
  pg_get_functiondef('public.create_work_order(text,jsonb)'::regprocedure)
    ~ 'pg_advisory_xact_lock.*hashtextextended',
  'create RPC uses an advisory transaction lock'
);
set local role authenticated;
select lives_ok(
  $$select public.create_work_order('simulated-race','{"vehicle_id":"B1023","task_type":"Inspection","description":"Simulated competing publication","priority":"low"}'::jsonb)$$,
  'first simulated competing publication succeeds'
);
select lives_ok(
  $$select public.create_work_order('simulated-race','{"vehicle_id":"B1023","task_type":"Inspection","description":"Simulated competing publication","priority":"low"}'::jsonb)$$,
  'second simulated competing publication returns the existing record'
);
reset role;
select is((select count(*) from public.work_orders where publication_key='simulated-race'),1::bigint,'simulated competing publication results in exactly one Work Order');
set local role authenticated;
select is(
  public.create_work_order(
    'canonical-optionals',
    '{"incident_id":" ","recommendation_id":null,"route_id":" ","vehicle_id":" b1023 ","task_type":" Inspection ","description":" Canonical optional values ","priority":" HIGH ","scheduled_start":"2026-08-30T08:00:00+08:00","scheduled_end":"2026-08-30T09:00:00+08:00","notes":" "}'::jsonb
  )->>'work_order_id',
  public.create_work_order(
    'canonical-optionals',
    '{"vehicle_id":"B1023","task_type":"Inspection","description":"Canonical optional values","priority":"high","scheduled_start":"2026-08-30T00:00:00Z","scheduled_end":"2026-08-30T01:00:00Z"}'::jsonb
  )->>'work_order_id',
  'canonical comparison normalizes optional blanks, text, and equivalent offset/Z timestamps'
);

select lives_ok(
  $$select public.create_work_order('legacy-proven-route','{"recommendation_id":"REC-INSPECT-B1023","route_id":"300","vehicle_id":"B1023","task_type":"Inspection","description":"Legacy proven route retry","priority":"high"}'::jsonb)$$,
  'creates a row used to simulate legacy publication evidence'
);
select lives_ok(
  $$select public.create_work_order('legacy-unproven-route','{"vehicle_id":"B1023","task_type":"Inspection","description":"Legacy unproven route retry","priority":"high"}'::jsonb)$$,
  'creates a row used to simulate unproven legacy Route evidence'
);
reset role;
alter table public.work_orders disable trigger enforce_work_order_update;
update public.work_orders
set publication_request_snapshot=publication_request_snapshot-'route_id',
    publication_request_sha256=extensions.digest(convert_to((publication_request_snapshot-'route_id')::text,'UTF8'),'sha256')
where publication_key in ('legacy-proven-route','legacy-unproven-route');
alter table public.work_orders enable trigger enforce_work_order_update;
create temporary table legacy_publication_evidence_before as
select publication_key,publication_request_snapshot,publication_request_sha256
from public.work_orders
where publication_key in ('legacy-proven-route','legacy-unproven-route');
set local role authenticated;
select lives_ok(
  $$select public.create_work_order('legacy-proven-route','{"recommendation_id":"REC-INSPECT-B1023","vehicle_id":"B1023","task_type":"Inspection","description":"Legacy proven route retry","priority":"high"}'::jsonb)$$,
  'old-client retry without Route matches legacy publication evidence'
);
select lives_ok(
  $$select public.create_work_order('legacy-proven-route','{"recommendation_id":"REC-INSPECT-B1023","route_id":"300","vehicle_id":"B1023","task_type":"Inspection","description":"Legacy proven route retry","priority":"high"}'::jsonb)$$,
  'new-client retry with the proven matching Route succeeds'
);
select throws_ok(
  $$select public.create_work_order('legacy-proven-route','{"recommendation_id":"REC-INSPECT-B1023","route_id":"301","vehicle_id":"B1023","task_type":"Inspection","description":"Legacy proven route retry","priority":"high"}'::jsonb)$$,
  '40001','Publication key was already used for different content.','legacy retry with a conflicting Route fails closed'
);
select lives_ok(
  $$select public.create_work_order('legacy-unproven-route','{"vehicle_id":"B1023","task_type":"Inspection","description":"Legacy unproven route retry","priority":"high"}'::jsonb)$$,
  'old-client null Route retry succeeds when legacy fields match'
);
select throws_ok(
  $$select public.create_work_order('legacy-unproven-route','{"route_id":"300","vehicle_id":"B1023","task_type":"Inspection","description":"Legacy unproven route retry","priority":"high"}'::jsonb)$$,
  '40001','Publication key was already used for different content.','unproven non-null Route retry fails closed'
);
reset role;
select ok(
  (select bool_and(w.publication_request_snapshot is not distinct from b.publication_request_snapshot and w.publication_request_sha256 is not distinct from b.publication_request_sha256)
   from public.work_orders w join legacy_publication_evidence_before b using(publication_key)),
  'legacy retries preserve historical snapshot JSON and SHA-256 bytes exactly'
);
select ok(
  (select publication_request_snapshot?'route_id' and publication_request_snapshot->>'route_id'='300' from public.work_orders where publication_key='local-b1023'),
  'new publications explicitly store Route in their canonical snapshot'
);
set local role authenticated;

select lives_ok($$select public.create_work_order('update-open','{"vehicle_id":"B1023","task_type":"Inspection","description":"Update conflict record","priority":"high","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T09:00:00Z"}'::jsonb)$$,'creates scheduled update record');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Update conflict record'),'open',1)$$,'opens update record');
reset role;
create temporary table update_before as
  select version,updated_at,vehicle_id,incident_id,recommendation_id,description
  from public.work_orders where publication_key='update-open';
set local role authenticated;
select throws_ok(
  $$select public.update_work_order((select work_order_id from public.work_orders where description='Update conflict record'),'{"vehicle_id":"B9999","task_type":"Inspection","description":"Stale write","priority":"high","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T09:00:00Z"}'::jsonb,1)$$,
  '40001','Work order changed. Refresh before saving.','stale expectedVersion rejects update'
);
select throws_ok(
  $$select public.update_work_order((select work_order_id from public.work_orders where description='Update conflict record'),'{"vehicle_id":"B1023","task_type":"Inspection","description":"Equal schedule","priority":"high","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T08:00:00Z"}'::jsonb,2)$$,
  '22023','Scheduled end must be later than scheduled start.','update rejects an equal schedule'
);
reset role;
select ok(
  (select row(version,updated_at,vehicle_id,incident_id,recommendation_id,description) is not distinct from
    (select row(version,updated_at,vehicle_id,incident_id,recommendation_id,description) from update_before)
   from public.work_orders where publication_key='update-open'),
  'rejected stale update preserves version, timestamps, linkage and editable fields'
);
set local role authenticated;
select throws_ok(
  $$select public.update_work_order((select work_order_id from public.work_orders where description='Update conflict record'),'{"vehicle_id":"B1023","task_type":"Inspection","description":"Injection","priority":"high","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T09:00:00Z","incident_id":"INJECT","recommendation_id":"INJECT","route_id":"INJECT","status":"completed","created_by_user_id":"11111111-1111-4111-8111-111111111111","created_at":"2026-08-30T08:00:00Z","updated_at":"2026-08-30T08:00:00Z","version":99}'::jsonb,2)$$,
  '22023','Update payload is invalid.','update payload cannot inject linkage, identity, status, audit fields or version'
);
select throws_ok(
  $$select public.update_work_order('WO-NOT-FOUND','{"vehicle_id":"B1023","task_type":"Inspection","description":"Missing","priority":"low"}'::jsonb,1)$$,
  'P0002','Work order was not found.','update reports not-found safely'
);
select throws_ok(
  $$select public.assign_work_order('WO-NOT-FOUND','Technician A',1)$$,
  'P0002','Work order was not found.','assignment reports not-found safely'
);
select throws_ok(
  $$select public.transition_work_order('WO-NOT-FOUND','cancelled',1)$$,
  'P0002','Work order was not found.','transition reports not-found safely'
);
select throws_ok(
  $$select public.update_work_order((select work_order_id from public.work_orders where description='Update conflict record'),'{"vehicle_id":"B1023","task_type":"Inspection","description":"Clear schedule","priority":"high"}'::jsonb,2)$$,
  '22023','This status requires a schedule.','Open work order cannot clear its schedule'
);

reset role;
alter table public.work_orders disable trigger enforce_work_order_schedule_integrity;
insert into public.work_orders(work_order_id,publication_key,publication_request_snapshot,publication_request_sha256,vehicle_id,task_type,description,priority,scheduled_start,scheduled_end,status,created_by_user_id,created_by_label,created_at,updated_at,version)
values
  ('WO-20260830-999996','legacy-equality-cancel','{}'::jsonb,extensions.digest('{}','sha256'),'B1023','Inspection','Legacy equality cancellation','high','2026-08-30T08:00:00Z','2026-08-30T08:00:00Z','draft','11111111-1111-4111-8111-111111111111','staff','2026-08-30T07:00:00Z','2026-08-30T07:00:00Z',1),
  ('WO-20260830-999997','legacy-equality-correct','{}'::jsonb,extensions.digest('{}','sha256'),'B1023','Inspection','Legacy equality correction','high','2026-08-30T08:00:00Z','2026-08-30T08:00:00Z','draft','11111111-1111-4111-8111-111111111111','staff','2026-08-30T07:00:00Z','2026-08-30T07:00:00Z',1);
alter table public.work_orders enable trigger enforce_work_order_schedule_integrity;
set local role authenticated;
select throws_ok(
  $$select public.transition_work_order('WO-20260830-999996','open',1)$$,
  '23514','Correct the legacy schedule before changing this work order.','legacy equality row cannot Open'
);
select lives_ok(
  $$select public.transition_work_order('WO-20260830-999996','cancelled',1)$$,
  'legacy equality row can be cancelled with its schedule unchanged'
);
select lives_ok(
  $$select public.update_work_order('WO-20260830-999997','{"vehicle_id":"B1023","task_type":"Inspection","description":"Legacy equality correction","priority":"high","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T09:00:00Z"}'::jsonb,1)$$,
  'legacy equality row can be corrected to a strict schedule'
);
reset role;
select ok((select status='cancelled' and scheduled_end=scheduled_start from public.work_orders where publication_key='legacy-equality-cancel'),'legacy cancellation preserves the historical schedule');
select ok((select scheduled_end>scheduled_start from public.work_orders where publication_key='legacy-equality-correct'),'legacy correction stores a strict schedule');
select throws_ok(
  $$insert into public.work_orders(work_order_id,publication_key,publication_request_snapshot,publication_request_sha256,vehicle_id,task_type,description,priority,scheduled_start,scheduled_end,status,created_by_user_id,created_by_label,created_at,updated_at,cancelled_at,version)
    values('WO-20260830-999995','new-invalid-cancelled','{}'::jsonb,extensions.digest('{}','sha256'),'B1023','Inspection','Invalid cancelled creation','high','2026-08-30T08:00:00Z','2026-08-30T08:00:00Z','cancelled','11111111-1111-4111-8111-111111111111','staff','2026-08-30T07:00:00Z','2026-08-30T07:00:00Z','2026-08-30T07:00:00Z',1)$$,
  '23514','Scheduled end must be later than scheduled start.','new invalid row cannot bypass strict ordering by starting Cancelled'
);
set local role authenticated;

select ok(
  (select status='draft' and scheduled_start is null and scheduled_end is null from public.work_orders where description='UUID label fallback'),
  'unscheduled Draft is allowed'
);
select throws_ok(
  $$select public.transition_work_order((select work_order_id from public.work_orders where description='UUID label fallback'),'open',1)$$,
  '22023','A schedule is required before opening.','Draft cannot open without a complete schedule'
);
reset role;
select ok((select status='draft' and version=1 and scheduled_start is null from public.work_orders where publication_key='uuid-label'),'rejected Open transition preserves unscheduled Draft');
set local role authenticated;

select lives_ok($$select public.create_work_order('assign-open','{"vehicle_id":"B1023","task_type":"Inspection","description":"Assignment record","priority":"high","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T09:00:00Z"}'::jsonb)$$,'creates assignment record');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Assignment record'),'open',1)$$,'opens assignment record');
select throws_ok($$select public.assign_work_order((select work_order_id from public.work_orders where description='Assignment record'),' ',2)$$,'22023','Assignment input is invalid.','blank assignment is rejected');
select throws_ok($$select public.assign_work_order((select work_order_id from public.work_orders where description='Assignment record'),'Technician A',1)$$,'40001','Work order changed. Refresh before assigning.','stale expectedVersion rejects assignment');
select lives_ok($$select public.assign_work_order((select work_order_id from public.work_orders where description='Assignment record'),'Technician A',2)$$,'Open record can be assigned once');
select throws_ok($$select public.assign_work_order((select work_order_id from public.work_orders where description='Assignment record'),'Technician B',3)$$,'22023','Only an unassigned Open work order can be assigned.','reassignment is rejected');
select throws_ok($$select public.update_work_order((select work_order_id from public.work_orders where description='Assignment record'),'{"vehicle_id":"B1023","task_type":"Inspection","description":"Clear Assigned schedule","priority":"high"}'::jsonb,3)$$,'22023','This status requires a schedule.','Assigned work order cannot clear its schedule');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Assignment record'),'in_progress',3)$$,'assigned record starts through stored status');
select throws_ok($$select public.update_work_order((select work_order_id from public.work_orders where description='Assignment record'),'{"vehicle_id":"B1023","task_type":"Inspection","description":"Clear In Progress schedule","priority":"high"}'::jsonb,4)$$,'22023','This status requires a schedule.','In Progress work order cannot clear its schedule');
select throws_ok($$select public.assign_work_order((select work_order_id from public.work_orders where description='Assignment record'),'Technician C',4)$$,'22023','Only an unassigned Open work order can be assigned.','assignment from non-Open status is rejected');
select throws_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Update conflict record'),'assigned',2)$$,'22023','Status transition input is invalid.','Open to Assigned cannot use the transition RPC');
select throws_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Update conflict record'),'in_progress',2)$$,'22023','Invalid work-order status transition.','transition decision uses stored database status');
select throws_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Update conflict record'),'cancelled',1)$$,'40001','Work order changed. Refresh before continuing.','stale expectedVersion rejects transition');
reset role;
select ok((select status='in_progress' and version=4 and assigned_to='Technician A' from public.work_orders where publication_key='assign-open'),'rejected assignment and lifecycle operations leave the stored row unchanged');
set local role authenticated;

select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='UUID label fallback'),'cancelled',1)$$,'unscheduled Draft can be cancelled');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Update conflict record'),'cancelled',2)$$,'Open work order can be cancelled');
select lives_ok($$select public.create_work_order('assigned-cancel','{"vehicle_id":"B1023","task_type":"Inspection","description":"Assigned cancellation","priority":"high","scheduled_start":"2026-08-30T08:00:00Z","scheduled_end":"2026-08-30T09:00:00Z"}'::jsonb)$$,'creates Assigned cancellation record');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Assigned cancellation'),'open',1)$$,'opens Assigned cancellation record');
select lives_ok($$select public.assign_work_order((select work_order_id from public.work_orders where description='Assigned cancellation'),'Technician A',2)$$,'assigns cancellation record');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Assigned cancellation'),'cancelled',3)$$,'Assigned work order can be cancelled');
select lives_ok($$select public.transition_work_order((select work_order_id from public.work_orders where description='Assignment record'),'cancelled',4)$$,'In Progress work order can be cancelled');
reset role;
select ok((select status='cancelled' and scheduled_start is null and scheduled_end is null and cancelled_at=updated_at from public.work_orders where publication_key='uuid-label'),'Cancelled supports the unscheduled Draft lifecycle shape and exact cancellation time');
select ok((select status='cancelled' and scheduled_start is not null and scheduled_end is not null and cancelled_at=updated_at from public.work_orders where publication_key='update-open'),'Cancelled supports the scheduled lifecycle shape and exact cancellation time');
select ok((select status='cancelled' and cancelled_at between created_at and updated_at from public.work_orders where publication_key='assign-open'),'terminal timestamp ordering is enforced for cancellation');
select throws_ok($$update public.work_orders set notes='terminal mutation' where publication_key='uuid-label'$$,'22023','Terminal work orders cannot be changed.','Cancelled is terminal and immutable');

select throws_ok(
  $$insert into public.work_orders(work_order_id,publication_key,publication_request_snapshot,publication_request_sha256,vehicle_id,task_type,description,priority,assigned_to,scheduled_start,scheduled_end,status,created_by_user_id,created_by_label,created_at,updated_at,completed_at,version)
    values('WO-20260830-999999','ordering-check','{}'::jsonb,extensions.digest('ordering','sha256'),'B1023','Inspection','Invalid terminal order','low','Technician A','2026-08-30T08:00:00Z','2026-08-30T09:00:00Z','completed','11111111-1111-4111-8111-111111111111','staff','2026-08-30T08:00:00Z','2026-08-30T08:00:00Z','2026-08-30T07:59:59Z',1)$$,
  '23514',null,'table rejects terminal timestamps before creation'
);
select throws_ok(
  $$insert into public.work_orders(work_order_id,publication_key,publication_request_snapshot,publication_request_sha256,vehicle_id,task_type,description,priority,assigned_to,status,created_by_user_id,created_by_label,created_at,updated_at,completed_at,version)
    values('WO-20260830-999998','completed-no-schedule','{}'::jsonb,extensions.digest('completed-no-schedule','sha256'),'B1023','Inspection','Completed without schedule','low','Technician A','completed','11111111-1111-4111-8111-111111111111','staff','2026-08-30T08:00:00Z','2026-08-30T08:00:00Z','2026-08-30T08:00:00Z',1)$$,
  '23514',null,'table rejects Completed work orders without a schedule'
);

set local role authenticated;
select lives_ok($$select public.create_work_order('rollback-create','{"vehicle_id":"B1023","task_type":"Inspection","description":"Rollback creation","priority":"low"}'::jsonb)$$,'creates a reference row for real create rollback');
reset role;
create temporary table failed_create_probe(sequence_before bigint, public_id text);
insert into failed_create_probe
select (substring(work_order_id from 13)::bigint), work_order_id from public.work_orders where publication_key='rollback-create';
select setval('public.work_order_code_seq',(select sequence_before from failed_create_probe),false);
set local role authenticated;
select throws_ok($$select public.create_work_order('rollback-create-fail','{"vehicle_id":"B1023","task_type":"Inspection","description":"Real failed create","priority":"low"}'::jsonb)$$,'23505',null,'real create failure after sequence allocation rolls back the row');
reset role;
select ok(not exists(select 1 from public.work_orders where publication_key='rollback-create-fail'),'failed create transaction leaves no Work Order row');
select ok(nextval('public.work_order_code_seq')>(select sequence_before from failed_create_probe),'sequence value allocated by rolled-back create is not reused');

create temporary table sequence_probe(value bigint);
insert into sequence_probe values(nextval('public.work_order_code_seq'));
do $$begin perform nextval('public.work_order_code_seq');raise exception 'rollback probe';exception when others then null;end$$;
select ok(nextval('public.work_order_code_seq')>(select value+1 from sequence_probe),'rolled-back or failed allocations may leave a gap and are not reused');

select * from finish();
rollback;
