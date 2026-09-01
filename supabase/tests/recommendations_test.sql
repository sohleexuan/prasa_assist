begin;
select plan(20);
select has_table('public', 'recommendations', 'recommendations table exists');
select has_table('public', 'recommendation_analyses', 'analysis table exists');
select col_is_pk('public', 'recommendation_analyses', 'recommendation_id', 'one analysis per recommendation');
select policies_are('public', 'recommendations', array['recommendations_owner_select', 'recommendations_owner_insert']);
select policies_are('public', 'recommendation_analyses', array['recommendation_analyses_owner_select']);
select function_returns('public', 'decide_recommendation', array['uuid','text','text','bigint'], 'recommendations');
select col_has_check('public', 'recommendations', 'status', 'status is constrained');
select col_has_check('public', 'recommendations', 'score', 'score is constrained');
select ok(has_schema_privilege('service_role', 'public', 'USAGE'), 'service_role has USAGE on public schema');
select ok(has_table_privilege('service_role', 'public.recommendations', 'SELECT'), 'service_role can SELECT recommendations');
select ok(not has_table_privilege('service_role', 'public.recommendations', 'INSERT'), 'service_role cannot INSERT recommendations');
select ok(not has_table_privilege('service_role', 'public.recommendations', 'UPDATE'), 'service_role cannot UPDATE recommendations');
select ok(not has_table_privilege('service_role', 'public.recommendations', 'DELETE'), 'service_role cannot DELETE recommendations');
select ok(has_table_privilege('service_role', 'public.recommendation_analyses', 'SELECT'), 'service_role can SELECT recommendation analyses');
select ok(has_table_privilege('service_role', 'public.recommendation_analyses', 'INSERT'), 'service_role can INSERT recommendation analyses');
select ok(not has_table_privilege('service_role', 'public.recommendation_analyses', 'UPDATE'), 'service_role cannot UPDATE recommendation analyses');
select ok(not has_table_privilege('service_role', 'public.recommendation_analyses', 'DELETE'), 'service_role cannot DELETE recommendation analyses');
select lives_ok($sql$
  do $body$
  begin
    insert into public.recommendations (id, owner_user_id, vehicle_id, actions_snapshot, evidence_snapshot, score, confidence_details)
    values ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'B1023', '[{"type":"inspect"}]'::jsonb, '[{"rule":"breakdown"}]'::jsonb, 85, '{"factors":[]}'::jsonb);
    insert into public.recommendation_analyses (recommendation_id, owner_user_id, model_identifier, schema_version, summary, rationale, limitations, staff_review_checklist)
    values ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'gemini-2.5-flash', 1, 'Historical Gemini analysis.', array['Stored facts.'], array['Staff decides.'], array['Review facts.']);
  end $body$
$sql$, 'historical Gemini analysis remains valid');
select lives_ok($sql$
  do $body$
  begin
    insert into public.recommendations (id, owner_user_id, vehicle_id, actions_snapshot, evidence_snapshot, score, confidence_details)
    values ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'B1023', '[{"type":"inspect"}]'::jsonb, '[{"rule":"breakdown"}]'::jsonb, 85, '{"factors":[]}'::jsonb);
    insert into public.recommendation_analyses (recommendation_id, owner_user_id, model_identifier, schema_version, summary, rationale, limitations, staff_review_checklist)
    values ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'openai/gpt-oss-20b', 1, 'Groq analysis.', array['Stored facts.'], array['Staff decides.'], array['Review facts.']);
  end $body$
$sql$, 'Groq analysis model is valid');
select throws_ok($sql$
  do $body$
  begin
    insert into public.recommendations (id, owner_user_id, vehicle_id, actions_snapshot, evidence_snapshot, score, confidence_details)
    values ('33333333-3333-4333-8333-333333333333', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'B1023', '[{"type":"inspect"}]'::jsonb, '[{"rule":"breakdown"}]'::jsonb, 85, '{"factors":[]}'::jsonb);
    insert into public.recommendation_analyses (recommendation_id, owner_user_id, model_identifier, schema_version, summary, rationale, limitations, staff_review_checklist)
    values ('33333333-3333-4333-8333-333333333333', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'unknown/model', 1, 'Unknown analysis.', array['Stored facts.'], array['Staff decides.'], array['Review facts.']);
  end $body$
$sql$, '23514', '.*recommendation_analysis_model.*', 'unknown analysis model is rejected');
select * from finish();
rollback;
