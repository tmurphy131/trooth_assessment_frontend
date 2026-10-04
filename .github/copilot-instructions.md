# T[root]H Discipleship: AI Agent Instructions (Flutter frontend)

Read these first. They are kept current; this file only points to them.

1. **[.specify/memory/constitution.md](../.specify/memory/constitution.md)**: the rules (MUST/SHOULD)
   for architecture, security, errors, accessibility, testing and releases. It is the source of truth.
2. **[CLAUDE.md](../CLAUDE.md)**: project layout, environments, the spec-driven workflow and skills.
3. **[CONTRIBUTING.md](../CONTRIBUTING.md)**: branches, commit format, PRs, and test commands.

Feature specs live in `specs/NNN-name/`. The backend is the sibling repo `trooth_assessment_backend`,
and API contracts live in its `specs/NNN-name/contracts/`.

## Domain essentials

- **Two roles.** Every user is a **mentor** or an **apprentice**; the role is chosen at signup and
  can't be changed afterwards. Never show one role's features to the other. The backend enforces
  access; client checks only control what the UI shows.
- **Firebase Auth** handles sign-in, and **Firestore** holds only the onboarding data (`role`,
  `onboarded`). All core data lives in the backend's PostgreSQL database and is reached through
  `ApiService`.
- **Assessments** go through three stages: a **template** (reusable, has a `published` flag),
  then a **draft** (the apprentice's work in progress, auto-saved), then a submitted
  **assessment** (AI-scored and immutable). Mentors read the scored reports.
- **Agreements** are created and submitted by the mentor. The apprentice then signs, followed
  by a parent when `parent_required` is set (for example, a minor apprentice). Signing works through public, token-based links:
  `/agreements/sign/:tokenType/:token`.
