create table public.recommendations (
  id uuid primary key default extensions.gen_random_uuid(),
  owner_user_id uuid not null default auth.uid(),
  incident_id text null,
  vehicle_id text not null,
  route_id text null,
  actions_snapshot jsonb not null,
  evidence_snapshot jsonb not null,
  score smallint not null,
  confidence_details jsonb not null,
  status text not null default 'pending_review',
  decision_user_id uuid null,
  decision_at timestamptz null,
  decision_note text null,
  version bigint not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint recommendations_vehicle_not_blank check (btrim(vehicle_id) <> ''),
  constraint recommendations_incident_not_blank check (incident_id is null or btrim(incident_id) <> ''),
  constraint recommendations_route_not_blank check (route_id is null or btrim(route_id) <> ''),
  constraint recommendations_actions_array check (jsonb_typeof(actions_snapshot) = 'array' and jsonb_array_length(actions_snapshot) > 0),
  constraint recommendations_evidence_array check (jsonb_typeof(evidence_snapshot) = 'array' and jsonb_array_length(evidence_snapshot) > 0),
  constraint recommendations_score_range check (score between 0 and 100),
  constraint recommendations_confidence_object check (jsonb_typeof(confidence_details) = 'object'),
  constraint recommendations_status_allowed check (status in ('pending_review', 'accepted', 'rejected')),
  constraint recommendations_version_positive check (version >= 1),
  constraint recommendations_id_owner_unique unique (id, owner_user_id),
  constraint recommendations_time_order check (updated_at >= created_at),
  constraint recommendations_decision_shape check (
    (status = 'pending_review' and decision_user_id is null and decision_at is null and decision_note is null)
    or (status in ('accepted', 'rejected') and decision_user_id is not null and decision_at is not null)
  ),
  constraint recommendations_note_not_blank check (decision_note is null or btrim(decision_note) <> '')
);

create table public.recommendation_analyses (
  recommendation_id uuid primary key,
  owner_user_id uuid not null,
  model_identifier text not null,
  schema_version smallint not null,
  summary text not null,
  rationale text[] not null,
  limitations text[] not null,
  staff_review_checklist text[] not null,
  generated_at timestamptz not null default statement_timestamp(),
  constraint recommendation_analysis_owner_fkey
    foreign key (recommendation_id, owner_user_id)
    references public.recommendations(id, owner_user_id) on delete restrict,
  constraint recommendation_analysis_model check (model_identifier = 'gemini-2.5-flash'),
  constraint recommendation_analysis_schema check (schema_version = 1),
  constraint recommendation_analysis_summary check (btrim(summary) <> ''),
  constraint recommendation_analysis_lists check (
    cardinality(rationale) between 1 and 8 and cardinality(limitations) between 1 and 8
    and cardinality(staff_review_checklist) between 1 and 8
    and array_position(rationale, null) is null and array_position(limitations, null) is null
    and array_position(staff_review_checklist, null) is null
  )
);

create index recommendations_owner_updated_idx on public.recommendations(owner_user_id, updated_at desc);
create index recommendations_owner_status_idx on public.recommendations(owner_user_id, status);
create index recommendation_analyses_owner_idx on public.recommendation_analyses(owner_user_id);

create function public.enforce_recommendation_update() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.id is distinct from old.id or new.owner_user_id is distinct from old.owner_user_id
    or new.incident_id is distinct from old.incident_id or new.vehicle_id is distinct from old.vehicle_id
    or new.route_id is distinct from old.route_id or new.actions_snapshot is distinct from old.actions_snapshot
    or new.evidence_snapshot is distinct from old.evidence_snapshot or new.score is distinct from old.score
    or new.confidence_details is distinct from old.confidence_details or new.created_at is distinct from old.created_at then
    raise exception 'Deterministic recommendation fields are immutable.' using errcode = '22023';
  end if;
  if new.version is distinct from old.version then
    raise exception 'Recommendation version is maintained by the database.' using errcode = '22023';
  end if;
  new.updated_at := clock_timestamp();
  new.version := old.version + 1;
  return new;
end; $$;

create trigger recommendations_before_update before update on public.recommendations
for each row execute function public.enforce_recommendation_update();

create function public.enforce_analysis_immutable() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  raise exception 'Saved recommendation analysis is immutable.' using errcode = '22023';
end; $$;
create trigger recommendation_analyses_immutable before update or delete on public.recommendation_analyses
for each row execute function public.enforce_analysis_immutable();

create function public.decide_recommendation(
  p_recommendation_id uuid, p_decision text, p_note text, p_expected_version bigint
) returns public.recommendations
language plpgsql security definer set search_path = '' as $$
declare v_record public.recommendations; v_decision text := lower(btrim(coalesce(p_decision, '')));
begin
  if auth.uid() is null then raise exception 'Authentication required.' using errcode = '42501'; end if;
  if v_decision not in ('accepted', 'rejected') then raise exception 'Invalid decision.' using errcode = '22023'; end if;
  select * into v_record from public.recommendations r
    where r.id = p_recommendation_id and r.owner_user_id = auth.uid() for update;
  if not found then raise exception 'Recommendation not found.' using errcode = 'P0002'; end if;
  if v_record.version <> p_expected_version then raise exception 'Recommendation version conflict.' using errcode = '40001'; end if;
  if v_record.status <> 'pending_review' then raise exception 'Recommendation is already decided.' using errcode = '22023'; end if;
  update public.recommendations set status = v_decision, decision_user_id = auth.uid(),
    decision_at = clock_timestamp(), decision_note = nullif(btrim(p_note), '')
    where id = p_recommendation_id returning * into v_record;
  return v_record;
end; $$;

alter table public.recommendations enable row level security;
alter table public.recommendation_analyses enable row level security;
create policy recommendations_owner_select on public.recommendations for select to authenticated using (owner_user_id = auth.uid());
create policy recommendations_owner_insert on public.recommendations for insert to authenticated with check (owner_user_id = auth.uid() and status = 'pending_review');
create policy recommendation_analyses_owner_select on public.recommendation_analyses for select to authenticated using (owner_user_id = auth.uid());
revoke update, delete on public.recommendations from authenticated;
revoke insert, update, delete on public.recommendation_analyses from authenticated;
grant select, insert on public.recommendations to authenticated;
grant select on public.recommendation_analyses to authenticated;
grant execute on function public.decide_recommendation(uuid, text, text, bigint) to authenticated;
