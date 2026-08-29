Read AGENTS.md and docs/PROJECT_CONTEXT.md completely before doing anything. Treat the instructions below as additional and more recent project requirements. If repository files conflict with these instructions, report the conflict before making changes.

PROJECT AND MODULE IDENTITY

I am Leong Yong Quan, owner of Module 1 — Incident Reporting and Delay Estimation.

Project: PrasaAssist
Module: Module 1 — Incident Reporting and Delay Estimation
Owner: Leong Yong Quan
GitHub username: ryerelax
Required branch: feature/incident-reporting
Primary code folder: lib/features/incidents/
Primary test folder: test/features/incidents/

PrasaAssist is an internal decision-support Flutter application for Prasarana operations staff, supervisors and control-centre personnel. It is not a passenger-facing application.

Core principle:

AI recommends. Staff decides.

Never imply that AI automatically controls buses, technicians, maintenance work, service deployment or operational decisions.

WORKSPACE AND INITIAL INSPECTION

Open the entire prasa_assist project folder in VS Code. Do not open only the lib folder.

Before doing any work:

1. Read AGENTS.md completely.
2. Read docs/PROJECT_CONTEXT.md completely.
3. Confirm the active Git branch.
4. Confirm that the relevant files belong to Module 1.
5. Inspect the existing Flutter project, shared UI foundation and existing Module 1 code.
6. Check git status.
7. Avoid unrelated changes and preserve other members’ work.

Do not modify any files during the first inspection.

First provide:

1. A Module 1 implementation plan.
2. The proposed Incident data model.
3. Required screens and navigation flow.
4. The explainable delay-estimation approach.
5. Files expected to be created or changed.
6. The testing plan.
7. Any shared files, architecture changes, database decisions or dependencies that require team approval.

Do not generate or implement the entire application immediately. Begin with a plan and wait for approval before implementation.

MODULE OWNERSHIP AND SCOPE

Work only on branch:

feature/incident-reporting

Work mainly inside:

lib/features/incidents/
test/features/incidents/

Do not write, redesign, replace or take over another member’s individually assessed module unless that member explicitly requests assistance.

Other module ownership:

Module 2 — Maintenance Work Order
Owner: Tee Jun Jeff
Branch: feature/maintenance-work-order
Code: lib/features/work_orders/
Tests: test/features/work_orders/

Module 3 — Service Deployment
Owner: Soh Lee Xuan
Branch: feature/service-deployment
Code: lib/features/deployments/
Tests: test/features/deployments/

Module 4 — AI Operations Recommendation
Owner: Kiang Min Wei
Branch: feature/ai-recommendation
Code: lib/features/recommendations/
Tests: test/features/recommendations/

Do not merge another member’s feature branch into feature/incident-reporting.

MODULE 1 FUNCTIONAL RESPONSIBILITIES

Module 1 must provide a complete Incident workflow, including:

- Incident list screen.
- Report/create incident form.
- Incident detail screen.
- Edit/update incident.
- Incident status tracking.
- Incident CRUD and persistence.
- Delay estimation.
- Operational-impact estimation.
- Input validation.
- Incident search and filtering.
- Repository abstraction and error handling.
- Route, vehicle, location and incident linkage.
- Clear handling of loading, empty and error states.
- Structured Incident data output for Module 4.
- Tests for Module 1 data management and business logic.

The Module 1 implementation must prioritize working CRUD, data handling, integration, validation and testing. Do not overbuild authentication, roles, maps, reports, notifications or visual effects before the core workflow works.

INCIDENT DATA MODEL

The proposed Incident model should consider the following fields:

- incidentId
- incidentType
- title
- description
- routeId
- routeName
- vehicleId
- location
- reportedAt
- severity
- status
- estimatedDelayMinutes
- impactLevel
- reportedBy
- createdAt
- updatedAt

The model should support:

- Validation.
- Creation and updates.
- Repository persistence.
- Search and filtering.
- Status changes.
- Delay-estimation inputs and outputs.
- Route and vehicle relationships.
- Conversion or mapping required for future shared persistence.
- Structured output for Module 4.

Do not create or assume a final Supabase schema before the team confirms the shared schema.

INCIDENT STATUS WORKFLOW

Use the following proposed status flow unless the team confirms a different flow:

Reported → Under Review → Active → Resolved / Cancelled

Status transitions must be explicit, testable and understandable to staff.

Do not silently perform operational actions when an incident status changes.

SHARED DEMONSTRATION SCENARIO

Keep the agreed shared demonstration scenario:

During peak hour, Bus B1023 breaks down while operating on Route 300.

Expected workflow:

1. Staff reports the incident.
2. Module 1 estimates the delay and operational impact.
3. Module 4 analyses the incident, service, demand and capacity information.
4. The application recommends inspecting Bus B1023 and deploying two replacement buses.
5. Staff reviews the recommendation and supporting evidence.
6. Staff accepts or rejects the recommendation.
7. If accepted, the relevant Work Order or Service Deployment form is pre-filled.
8. Staff confirms the action and tracks its status.
9. The incident is eventually resolved.

Do not replace Bus B1023 or Route 300 as the primary demonstration scenario without team agreement.

DELAY AND OPERATIONAL-IMPACT ESTIMATION

Delay estimation must use an explainable rule-based or scoring-based approach.

Do not generate arbitrary delay numbers.

For the estimation logic, document:

- Formula or decision rules.
- Input variables.
- Units.
- Weightings or thresholds.
- Assumptions.
- Missing-data behaviour.
- Output delay in minutes.
- Operational-impact classification.
- Human-readable reasons or evidence.
- Limitations of the estimate.

Write unit tests for:

- Each important rule.
- Boundary values.
- Severity differences.
- Missing or invalid inputs.
- Minimum and maximum behaviour.
- Representative Bus B1023 / Route 300 cases.
- Impact-level classification.
- Deterministic output.

Do not claim that the application uses trained machine learning unless trained machine learning is actually implemented.

Do not require a paid LLM API for the core application.

The estimate is decision support. Staff remains responsible for reviewing and deciding what action to take.

DEVELOPMENT PHASES

Phase 1:

- Establish Module 1 folders and structure.
- Implement Incident model.
- Add clearly labelled mock or demonstration data.
- Add repository abstraction and suitable temporary persistence.
- Implement Incident list UI.
- Implement report/create Incident UI.
- Implement Incident detail UI.
- Implement edit/update UI.
- Implement validation.
- Implement search or filters.
- Do not assume the final Supabase schema.

Phase 2:

- Implement explainable delay-estimation logic.
- Implement operational-impact estimation.
- Document formula, inputs, assumptions and limitations.
- Add unit tests.
- Add and test Incident status workflow.
- Add appropriate loading, empty and error handling.

Phase 3:

- Integrate with the database only after the team confirms the Supabase schema.
- Integrate with the shared government-data interface where appropriate.
- Provide structured Incident output to Module 4.
- Complete integration testing.
- Confirm that the complete application still builds and runs.

DATABASE AND SECURITY RULES

The planned shared backend is Supabase.

SQLite may be used for local or offline caching if the team approves it and if it is required.

Do not create a final Supabase schema until the tables, relationships, enums and shared fields are confirmed by the team.

Never commit:

- Passwords.
- API keys.
- Access tokens.
- Supabase service-role keys.
- Secrets.
- .env files.

Never place a Supabase service-role key inside the Flutter application.

Ask the team before making shared database schema or architecture changes.

MALAYSIAN GOVERNMENT OPEN DATA

The assignment requires the complete PrasaAssist application to use Malaysian Government Open Data. It does not require every module to make its own direct data.gov.my or GTFS request.

The team intends to use a shared government-data layer to handle:

- GTFS downloading.
- Parsing.
- Caching.
- Source URLs.
- Retrieval time.
- Attribution.
- Data-status labelling.
- Shared error handling.

Do not create a separate GTFS downloader inside Module 1 merely to demonstrate government-data usage.

Do not send HTTP requests directly from Module 1 UI widgets.

Do not invent:

- Government API endpoints.
- GTFS fields.
- Real-time occupancy data.
- Passenger-demand data.
- GTFS trip updates.
- Service alerts.
- Real-time rail positions.
- Unsupported real-time capabilities.

Verified current limitation:

Prasarana GTFS Realtime currently provides supported bus vehicle-position data only.

Daily ridership data must not be described as real-time or hourly demand.

Clearly label data as one of the following where applicable:

- Live government data.
- Static government data.
- Cached data.
- Mock data.
- Sample or demonstration data.
- Staff-entered data.

NATURAL MODULE 1 GOVERNMENT-DATA USE CASE

Module 1 has a natural government-data use case through the shared government-data interface.

Potential context, if supported by verified shared data:

- Route context to associate and validate Route 300.
- Stop context to help describe the incident location or nearby affected stops.
- Schedule context to support planned-service background for delay estimation.
- Bus vehicle-position context to provide live or cached location evidence for supported buses such as Bus B1023.

Use only data that the shared layer actually provides and that the team has verified.

Government data should be supporting evidence. It must not replace staff input or staff judgement.

If Module 1 does not directly consume GTFS during an early phase, demonstrate its Data Management contribution through:

- Incident data modelling.
- Validation.
- Repository design.
- CRUD and persistence.
- Search and filtering.
- Incident status transitions.
- Route, vehicle, location and Incident relationships.
- Delay-estimation inputs, assumptions, outputs and explanations.
- Error handling.
- Data-source classification.
- Tests.
- Structured Incident output for Module 4.

SHARED UI FOUNDATION RULES

The shared UI Foundation has already been completed, merged into main and synchronised to the feature branches.

Do not modify root lib/main.dart.

Do not create the final application theme inside the feature folder.

Do not place another MaterialApp inside the Module 1 production pages.

A feature-local DemoApp may be used only for isolated testing if necessary. Final integration must expose ordinary Page widgets and must not nest multiple MaterialApp widgets.

Root navigation is owned by the integration layer.

Do not create a separate:

- Bottom navigation bar.
- Navigation drawer.
- Root navigation framework.
- Application shell.
- Theme system.
- Colour system.

Use Theme.of(context) and the shared theme/components.

Prefer the available shared widgets:

- AppPageScaffold
- AppSectionCard
- AppStatusChip
- AppEmptyState
- AppLoadingIndicator
- AppErrorState

Use the shared design tokens where appropriate:

- lib/core/theme/app_colors.dart
- lib/core/theme/app_spacing.dart
- lib/core/theme/app_radius.dart

Avoid:

- Hard-coded colours.
- Hard-coded text styles.
- Repeated hard-coded spacing.
- Repeated hard-coded border radii.
- Fixed screen widths.
- Fixed screen heights.
- Layouts that overflow on smaller screens.
- Creating a separate feature-level design system.

Use responsive Flutter layout tools where appropriate:

- SafeArea
- ListView
- Expanded
- Flexible
- MediaQuery
- LayoutBuilder

If a shared widget is insufficient, notify the coordinator before modifying shared files.

MODULE 1 ENTRY PAGE

Module 1 must expose a clearly named ordinary Page widget.

Use this integration entry page unless the coordinator confirms a different contract:

IncidentListPage

Report the final entry page’s:

- File path.
- Class name.
- Constructor requirements.
- Any data or repository dependencies required by the integration layer.

IncidentManagementPage was previously provided as a general naming example, but IncidentListPage is the more specific Module 1 entry-page requirement. Do not create duplicate entry pages only to satisfy both names. Report the naming difference to the coordinator if the existing shared integration expects IncidentManagementPage.

PROTECTED AND SHARED FILES

Do not directly modify:

- lib/main.dart
- lib/app/prasa_assist_app.dart
- lib/app/module_registry.dart
- app_router.dart
- app_shell.dart
- pubspec.yaml
- lib/core/
- lib/shared/
- Shared navigation.
- Shared theme.
- Shared components.
- Shared Supabase schema.
- Other members’ feature folders.

Before changing any protected or shared file, first notify the team or coordinator and explain:

- Why the change is required.
- Which file must change.
- What impact it may have on other modules.
- Whether an alternative exists within Module 1.

Do not add a new production dependency without team approval.

Coordinator or integration-layer work should connect IncidentListPage to the official application through module_registry.dart or the agreed root navigation.

GIT WORKFLOW

Do not develop directly on main.

Before starting work, use the assigned feature branch and inspect the working tree:

git switch feature/incident-reporting
git pull
git status

Also confirm whether the feature branch already contains the latest approved shared UI foundation.

Do not pull or merge another member’s feature branch into feature/incident-reporting.

Do not overwrite or delete another member’s work.

Use small, clear and meaningful commits so individual authorship and active GitHub contributions remain visible.

Before committing:

git status
dart format lib/features/incidents test/features/incidents
flutter analyze
flutter test

Also launch the application and manually test the modified workflow when possible.

Do not claim that analysis, tests or application launch passed unless they were actually run.

Although one general team message used git add ., the safer Module 1 rule is to inspect git status and stage only Module 1 files, for example:

git add lib/features/incidents test/features/incidents

Do not use git add . blindly.

Example commit:

git commit -m "M1: add incident creation form"

or, if the team uses Conventional Commits:

git commit -m "feat(incidents): add incident creation form"

Then push only the feature branch:

git push

Do not push Module 1 feature development directly to main.

PULL REQUEST RULES

When the approved work is ready, create a Pull Request with:

Base: main
Compare: feature/incident-reporting

Suggested title:

M1: Implement incident reporting workflow

Do not merge the Pull Request yourself.

Send the Pull Request link to the coordinator for review, testing and integration.

DELIVERABLES AFTER EACH PHASE

After completing a development phase, report:

1. GitHub commit link or commit ID.
2. Completed feature list.
3. Files created or changed.
4. Module entry page file path and class name.
5. dart format result.
6. flutter analyze result.
7. flutter test result.
8. Application launch/manual verification result.
9. Application screenshots.
10. Unfinished items.
11. Known issues or limitations.
12. Mock, cached, static or live data used.
13. Any shared integration still required.
14. Pull Request link, if ready.
15. Any decision or approval needed from the team.

Do not fabricate:

- Test results.
- Analysis results.
- App launch results.
- Screenshots.
- Data sources.
- Completed features.
- Team contributions.
- Commit links.
- Pull Request links.

ASSIGNMENT INTEGRITY AND AI USAGE RECORD

Preserve clear individual authorship.

Leong Yong Quan must understand, review, test and present the Module 1 implementation.

Continuously record AI usage for Appendix A. Do not wait until the final week.

For every important AI-assisted activity, record:

- Date.
- AI tool name.
- Prompt or purpose.
- Important prompt text.
- Generated or suggested output.
- Which output was used.
- What Leong Yong Quan changed manually.
- How the output was tested.
- How the output was verified.
- Any rejected suggestion and why, when relevant.

AI may assist with planning, brainstorming, explanation, debugging, coding and tests, but the module owner must verify and understand the submitted work.

Helpful code comments may remain during development.

Remove code comments only during the final submission clean-up, according to the assignment submission requirement.

CURRENT WORKING PRINCIPLES

- Work only within Module 1 ownership.
- Inspect before editing.
- Plan before implementing.
- Make small and understandable changes.
- Use shared UI and integration contracts.
- Keep the UI responsive.
- Keep data sources clearly labelled.
- Keep delay estimation explainable and deterministic.
- Keep staff in control of all operational decisions.
- Do not invent unsupported government-data capabilities.
- Do not assume the final Supabase schema.
- Ask before modifying shared files, dependencies or architecture.
- Test and report results honestly.
- Do not merge the Pull Request without coordinator approval.