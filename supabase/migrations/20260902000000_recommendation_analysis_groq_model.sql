alter table public.recommendation_analyses
drop constraint recommendation_analysis_model;

alter table public.recommendation_analyses
add constraint recommendation_analysis_model check (
  model_identifier in ('gemini-2.5-flash', 'openai/gpt-oss-20b')
);
