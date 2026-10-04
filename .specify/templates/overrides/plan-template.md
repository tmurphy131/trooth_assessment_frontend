# Implementation Plan: [FEATURE]

**Branch**: `feature/[name]` (or `fix/`, `chore/`) | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Dart / Flutter (version pinned in `.github/workflows/release.yml`)

**Primary Dependencies**: [existing packages used; any NEW package + justification (Principle IX)]

**Backend Endpoints**: [method + path for each endpoint used; link to backend contract or N/A]

**Storage**: [backend API / Firestore (onboarding only) / shared_preferences / N/A]

**Testing**: `flutter test` (unit/widget), `integration_test/` (device, against dev), `test/firestore_rules` (emulator)

**Target Platform**: iOS and Android (store builds)

**Project Type**: mobile-app (backend: `trooth_assessment_backend`)

**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]

**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]

**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Source: `.specify/memory/constitution.md`. Mark each ✅ / ❌ / N/A; every ❌ needs a row in
Complexity Tracking.

- [ ] **I. API gateway**: backend calls via `ApiService` extensions in `lib/services/api/`; typed exceptions only
- [ ] **II. Environment**: no hardcoded URLs; verified on dev before release
- [ ] **III. Security & privacy**: no token/body/PII logging; no secrets in git; backend enforces access; Firestore rules + emulator tests if touched; `PrivacyInfo.xcprivacy` updated if new data collected
- [ ] **IV. Errors**: `friendlyError()` for user text; `mounted` checks after `await`
- [ ] **V. Session**: sign-in/out side effects only via `SessionController`
- [ ] **VI. Structure**: setState + singletons (no new state package); app-level routes in `lib/router.dart`; no `pushNamed`; naming conventions; theme constants
- [ ] **VII. Accessibility**: tooltips, 48 px targets, ≥11 px text, works at 1.5x text scale
- [ ] **VIII. Tests**: unit tests for service/parser/model changes; analyze + test pass; integration test if auth/session touched
- [ ] **IX. Dependencies**: each new package justified below; SPM only; narrow pins commented
- [ ] **X. Logging**: no new `print`
- [ ] **XI. Release**: version bump via `/bump-version` only
- [ ] **XII. Cross-repo**: every backend endpoint named and confirmed in `trooth_assessment_backend` (contract in its `specs/NNN/contracts/`); deployed to prod before this ships

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: List the real files this feature adds or changes.
-->

```text
lib/
├── router.dart                 # app-level / deep-link routes (go_router)
├── screens/                    # *_screen.dart (+ *_widgets.dart part files)
├── features/<feature>/         # optional feature folder (models/, screens/, widgets/, data/)
├── services/api/<domain>.dart  # extension <Domain>Api on ApiService
├── models/
├── widgets/
└── utils/
test/                           # unit + widget tests
integration_test/               # device tests (auth/session)
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
