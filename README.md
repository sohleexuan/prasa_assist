# PrasaAssist

PrasaAssist is an internal decision-support application for Prasarana
operations staff. AI recommends. Staff decides.

## Local Supabase configuration

Copy `config/supabase.example.json` to `config/supabase.local.json` and replace
the placeholders with the local project URL and its publishable key. Never put
a service-role or secret key in Flutter configuration.

Run the app with:

```sh
flutter run --dart-define-from-file=config/supabase.local.json
```

The local file and common secret-file variants are ignored by Git. The checked
in example deliberately contains placeholders only.

## Hosted Supabase security and ownership

`supabase/config.toml` controls local Supabase only. Before connecting the
hosted project, the coordinator must disable both **Allow new users to sign
up** and **Allow anonymous sign-ins** in Supabase Dashboard. Staff accounts
must be created or invited deliberately through the Dashboard. Any
authenticated account currently receives the approved staff database
permissions, so public signup must remain disabled.

The coordinator owns the Supabase project and applies the migrations kept in
`supabase/migrations/`. Teammates must not make undocumented schema changes
directly in the hosted Dashboard.

Only the project URL and publishable key may enter Flutter. Secret keys and
service-role keys must never enter Flutter, configuration JSON, Git,
screenshots, chat, or commits. `config/supabase.local.json` must stay local and
ignored.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
