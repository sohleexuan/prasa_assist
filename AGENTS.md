# PrasaAssist Project Instructions

## Project Overview

PrasaAssist is a Flutter mobile application for Prasarana operations staff, supervisors, and control-centre personnel.

It is an internal decision-support application, not a passenger-facing application.

The project supports SDG 9 and must use real-time or static Malaysian Government open data from data.gov.my.

Core principle:

> AI recommends. Staff decides.

The application must never imply that AI automatically controls buses, technicians, maintenance work, or operational decisions.

## Team Modules and Ownership

Each member is individually responsible for their own module:

- Module 1 — Incident Reporting and Delay Estimation
  - Owner: Leong Yong Quan
  - Branch: `feature/incident-reporting`
  - Main folder: `lib/features/incidents/`

- Module 2 — Maintenance Work Order
  - Owner: Tee Jun Jeff
  - Branch: `feature/maintenance-work-order`
  - Main folder: `lib/features/work_orders/`

- Module 3 — Service Deployment
  - Owner: Soh Lee Xuan
  - Branch: `feature/service-deployment`
  - Main folder: `lib/features/deployments/`

- Module 4 — AI Operations Recommendation
  - Owner: Kiang Min Wei
  - Branch: `feature/ai-recommendation`
  - Main folder: `lib/features/recommendations/`

Shared and reusable code should be placed under:

- `lib/core/`
- `lib/shared/`

Do not write, redesign, or replace another member's individually assessed module unless that member explicitly requests assistance.

## Git Workflow

- `main` must always contain stable and runnable code.
- Do not develop new features directly on `main`.
- Each member must work on their assigned feature branch.
- Pull the latest `main` before starting new work.
- Use clear and meaningful commit messages.
- Commit regularly so GitHub shows active contributions from every member.
- Use Pull Requests to merge feature branches into `main`.
- Review and test changes before merging.
- Do not overwrite or delete another member's work.
- Avoid squash-merging members' full contribution history unless the team agrees.

## Shared Demo Scenario

Use this scenario unless the whole team agrees to change it:

During peak hour, Bus B1023 breaks down while operating on Route 300.

The intended flow is:

1. Staff reports the incident.
2. The system estimates the delay and operational impact.
3. Module 4 analyses the incident, service, demand, and capacity data.
4. The system recommends inspecting Bus B1023 and deploying two replacement buses.
5. Staff reviews the recommendation and supporting evidence.
6. Staff accepts or rejects the recommendation.
7. If accepted, the relevant Work Order or Service Deployment form is pre-filled.
8. Staff confirms the action and tracks its status.
9. The incident is eventually resolved.

## Data Rules

- Use verified data from data.gov.my.
- Do not invent API endpoints, dataset fields, or real-time capabilities.
- Prasarana GTFS Realtime currently provides bus vehicle-position data only.
- Do not claim that realtime occupancy, realtime rail positions, trip updates, or service alerts are available unless verified.
- Daily ridership data must not be presented as real-time or hourly demand.
- Clearly label mock, sample, cached, and live data.

## AI Recommendation Rules

- Module 4 must use an explainable rule-based or scoring-based approach.
- Do not claim that the application uses trained machine learning unless it actually does.
- Do not require a paid LLM API for the core application.
- Every recommendation must show understandable evidence or reasons.
- Staff must explicitly accept or reject recommendations.

## Database and Security

- The planned shared backend is Supabase.
- SQLite may be used for local or offline caching if required.
- Do not commit passwords, API keys, service-role keys, access tokens, or `.env` files.
- Never place a Supabase service-role key inside the Flutter application.
- Confirm shared database schema changes with the team before implementing them.

## Development Rules

Before changing code:

1. Confirm the active Git branch.
2. Confirm which module owns the files.
3. Inspect existing code before editing.
4. Avoid unrelated changes.
5. Ask before adding a new production dependency or changing shared architecture.

After changing code:

1. Format the Dart code.
2. Run `flutter analyze`.
3. Run `flutter test`.
4. Verify that the application still starts successfully.
5. Report which files changed and what was tested.

## Assignment Integrity

- Preserve clear individual authorship for all four members.
- AI may assist with brainstorming, explanation, debugging, and coding support.
- Every member must understand and verify their submitted code.
- Record AI tool usage, important prompts, and verification steps for Appendix A.
- Helpful comments may remain during development.
- Remove code comments only during the final submission clean-up.
- Do not fabricate test results, data sources, completed features, or team contributions.

## Scope Control

- Prioritize working CRUD, data handling, integration, testing, and clear module ownership.
- Do not overbuild authentication, roles, maps, reports, or visual effects before core functionality works.
- Do not change the Bus B1023 and Route 300 scenario without team agreement.
- Do not change another member's module boundaries without team agreement.