# PrasaAssist Project Context

Last updated: 26 August 2026

## 1. Project Summary

PrasaAssist is an AI-powered public transport operations assistant developed as a Flutter mobile application.

The application is designed for Prasarana operations staff, supervisors, and control-centre personnel. It is not intended for passengers.

Its purpose is to combine incident handling, maintenance work orders, service deployment, and explainable AI recommendations into one staff-controlled workflow.

Core principle:

> AI recommends. Staff decides.

## 2. Assignment Information

Course: BMIT2073 Mobile Application Development  
Academic Session: 202605  
Project theme: SDG 9 — Industry, Innovation and Infrastructure

The application must use real-time or static data from Malaysia's official open-data platform, data.gov.my.

Important submission requirements include:

- A complete Flutter project in a private GitHub repository.
- Active GitHub contributions from all four members.
- Final presentation slides in PDF format.
- Live application demonstration.
- Structured code walkthrough by every member.
- Appendix A, including AI usage disclosure.
- Appendix B assignment evaluation form.
- Appendix C peer evaluation form from every member.
- Appendix D individual task description from every member.
- All code comments must be removed before final submission.

Comments may remain during development and should only be removed during the final submission clean-up.

## 3. Repository

Official repository:

`https://github.com/sohleexuan/prasa_assist`

Visibility: Private  
Default branch: `main`  
Repository owner and project coordinator: Soh Lee Xuan

The formal team lead name used for final submission filenames must still be confirmed by the team.

## 4. Team Responsibilities

| Module | Owner | GitHub Username | Feature Branch |
|---|---|---|---|
| Module 1 — Incident Reporting and Delay Estimation | Leong Yong Quan | `ryerelax` | `feature/incident-reporting` |
| Module 2 — Maintenance Work Order | Tee Jun Jeff | `teeji-wp23` | `feature/maintenance-work-order` |
| Module 3 — Service Deployment | Soh Lee Xuan | `sohleexuan` | `feature/service-deployment` |
| Module 4 — AI Operations Recommendation | Kiang Min Wei | `MW0302` | `feature/ai-recommendation` |

Every member must develop, understand, test, commit, and present their own module.

Members should not take over another member's individually assessed technical work unless the module owner explicitly requests assistance.

## 5. Current Status

As of 26 August 2026:

- Flutter 3.47.1 and Dart 3.13.1 are installed.
- Android development environment is working.
- Android emulator is working.
- The default Flutter application builds and runs successfully.
- The private GitHub repository has been created.
- The initial Flutter project has been pushed to `main`.
- GitHub invitations have been sent to the other three members.
- Common repository instructions are stored in `AGENTS.md`.
- Development of all four functional modules has not started.

There is no previous module code that needs to be migrated.

## 6. Shared Demonstration Scenario

The agreed demonstration scenario is:

> During peak hour, Bus B1023 breaks down while operating on Route 300.

Expected workflow:

1. A staff member reports the Bus B1023 incident.
2. Module 1 estimates the delay and operational impact.
3. Module 4 analyses the incident, service, demand, and capacity information.
4. Module 4 recommends inspecting Bus B1023.
5. Module 4 recommends deploying two replacement buses on Route 300.
6. Staff reviews the reasons and supporting evidence.
7. Staff accepts or rejects the recommendation.
8. If accepted, the application opens a pre-filled Work Order or Service Deployment form.
9. Staff confirms and tracks the action.
10. The incident is eventually resolved.

Do not replace this scenario without agreement from all four members.

## 7. Module Scope

### Module 1 — Incident Reporting and Delay Estimation

Responsible for:

- Creating incident reports.
- Recording affected vehicle, route, time, location, and severity.
- Estimating delay and operational impact.
- Updating and resolving incident status.
- Providing incident information to Module 4.

### Module 2 — Maintenance Work Order

Responsible for:

- Creating maintenance work orders.
- Assigning vehicle, technician, task, priority, and schedule.
- Tracking work-order status.
- Completing or cancelling work orders.
- Receiving accepted maintenance recommendations from Module 4.

### Module 3 — Service Deployment

Responsible for:

- Creating additional or replacement service deployments.
- Selecting routes and vehicles.
- Setting service start and end times.
- Tracking deployment status.
- Completing or cancelling deployments.
- Receiving accepted deployment recommendations from Module 4.

Suggested status flow:

`Draft → Scheduled → Active → Complete / Cancel`

### Module 4 — AI Operations Recommendation

Responsible for:

- Analysing incident, service, demand, and capacity information.
- Producing explainable rule-based recommendations.
- Showing reasons, evidence, and confidence or priority.
- Allowing staff to accept or reject each recommendation.
- Passing accepted recommendations to Module 2 or Module 3.

Module 4 must not automatically execute an operational action.

## 8. Data Direction

Primary government-data source:

`https://data.gov.my`

Verified limitations:

- Prasarana GTFS Realtime currently provides vehicle-position data for supported bus services.
- It does not currently provide verified real-time occupancy data.
- It does not currently provide verified real-time rail vehicle positions.
- Daily ridership datasets are not real-time or hourly demand data.
- The team must not invent unsupported API endpoints or fields.

Every data display must clearly identify whether the data is:

- Live government data.
- Static government data.
- Cached data.
- Mock or demonstration data.

## 9. Database Direction

Current planned database:

- Supabase for shared online data.
- SQLite may be considered for offline caching.

The final Supabase schema has not yet been confirmed.

Database tables, relationships, enums, and shared fields must be agreed by the team before module development depends on them.

Never commit secrets, passwords, API keys, access tokens, service-role keys, or `.env` files to GitHub.

## 10. Git Collaboration Workflow

1. Pull the latest `main`.
2. Create or switch to the assigned feature branch.
3. Work only within the assigned module scope.
4. Commit small and meaningful changes regularly.
5. Push the feature branch to GitHub.
6. Open a Pull Request into `main`.
7. Review and test the Pull Request.
8. Merge only when the project still builds and runs.

Direct feature development on `main` should be avoided.

## 11. Verification Requirements

Before merging code:

- Run `dart format`.
- Run `flutter analyze`.
- Run `flutter test`.
- Launch the application.
- Test the modified workflow manually.
- Confirm that no unrelated module was broken.
- Record what was tested.

Do not claim that a test passed unless it was actually run.

## 12. AI Usage Record

The assignment allows AI-supported work, but all AI use must be disclosed.

Each member should continuously record:

- AI tool name.
- Date used.
- Purpose.
- Important prompts.
- Generated or suggested output.
- How the member verified or changed the output.

Do not wait until submission week to reconstruct the AI usage record from memory.

## 13. Open Decisions

The team still needs to confirm:

- Formal team lead for submission filename.
- Final Supabase schema.
- Authentication approach.
- Exact user roles and permissions.
- Offline caching and synchronisation strategy.
- Module 1 delay-estimation formula.
- Final application navigation and visual design.
- Exact use of maps.
- Notification implementation.
- Final integration schedule.
- Week 12 submission date.
- Week 13 and Week 14 presentation dates.

These decisions must not be guessed or changed by one member without team agreement.

## 14. Immediate Next Steps

1. All invited members accept the GitHub invitation.
2. Every member clones the repository.
3. Every member creates and pushes their assigned feature branch.
4. The team agrees on shared Flutter folder structure.
5. The team agrees on the initial Supabase schema.
6. Each member begins their own module.
7. All members commit progress regularly.