grant usage on schema public to service_role;

grant select
on table public.recommendations
to service_role;

grant select, insert
on table public.recommendation_analyses
to service_role;
