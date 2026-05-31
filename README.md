# Repotoire

Repotoire is a local-first Flutter score viewer for existing PDF sheet music. The long-term source of truth is a private GitHub repository with plain YAML metadata and append-only PDF versions.

## Current Implementation State

This repository contains the MVP foundation and first offline milestone:

- Domain model for scores, versions, artists, sync state, local operations, and conflicts.
- Import size policy: `<=1MB` normal, `1-20MB` warning, `>20MB` rejected.
- Repository path contract for `library.yml`, `artists/<id>.yml`, and `scores/<id>/...`.
- Drift schema for the local read model.
- Offline library UI skeleton with search/filter surfaces and PDF viewer screen.
- GitHub Git Database API client boundary for future pull/push sync.
- Semantic 3-way merge logic for score metadata.

This workspace uses `mise.toml` with Flutter 3.22.1 because that is the version available in the local mise Flutter plugin during setup. The dependencies are pinned to versions compatible with Dart 3.4.1. To verify the project:

```sh
mise x -- flutter pub get
mise x -- dart run build_runner build --delete-conflicting-outputs
mise x -- flutter analyze
mise x -- flutter test
mise x -- flutter run
```

## MVP Scope

The first shippable milestone is offline-only:

1. Import a PDF into local storage.
2. Register score metadata in SQLite.
3. List/search/filter the library.
4. Open cached PDFs in the viewer.
5. Logically delete scores with `deleted_at`.

GitHub auth, pull sync, push sync, and conflict UI are intentionally separated behind interfaces so they can be implemented without changing the local feature surfaces.
