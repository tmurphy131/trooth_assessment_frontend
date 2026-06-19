---
name: bump-version
description: Use when bumping the app version, updating the version number, releasing a new version, or incrementing the build number.
argument-hint: <new-version> e.g. 1.0.36
---

## What This Skill Does

Updates the app version in all required files and creates a git commit. Takes the new version as `$ARGUMENTS`.

**Files updated:**
- `pubspec.yaml` — `version:` line (format: `X.Y.Z+N`)
- `ios/Runner/Info.plist` — `CFBundleShortVersionString` and `CFBundleVersion`

Android reads version from `pubspec.yaml` automatically — no separate Android file needed.

---

## Step 1 — Parse the Version Argument

`$ARGUMENTS` will be one of:
- `1.0.36` — semver only; derive build number as the patch number (36)
- `1.0.36+36` — explicit semver+build; use both as given
- `1.0.36+42` — semver with a different build number; use both as given

Extract:
- `SEMVER` = the part before `+` (e.g., `1.0.36`)
- `BUILD` = the part after `+`, or the patch number if no `+` given (e.g., `36`)

If `$ARGUMENTS` is empty or unparseable, stop and ask the user: "What version should I bump to? (e.g. 1.0.36)"

---

## Step 2 — Read Current Version

Read the current version from `pubspec.yaml` line starting with `version:` and report it to the user:

```
Current version: 1.0.35+35
New version:     1.0.36+36
```

---

## Step 3 — Update pubspec.yaml

File: `/Users/tmoney/Developer/trooth_assessment/pubspec.yaml`

Find the line: `version: <anything>`
Replace it with: `version: SEMVER+BUILD`

Use the Edit tool. Do not change any other lines.

---

## Step 4 — Update Info.plist

File: `/Users/tmoney/Developer/trooth_assessment/ios/Runner/Info.plist`

There are two values to update:

**CFBundleShortVersionString** (the human-readable version):
Find the `<string>` tag immediately after `<key>CFBundleShortVersionString</key>`.
Replace its value with `SEMVER`.

**CFBundleVersion** (the build number):
Find the `<string>` tag immediately after `<key>CFBundleVersion</key>`.
Replace its value with `BUILD`.

Use the Edit tool for each replacement. Do not change any other lines.

---

## Step 5 — Commit

Stage only the two changed files and create a commit:

```
git -C "/Users/tmoney/Developer/trooth_assessment" add pubspec.yaml ios/Runner/Info.plist
```

```
git -C "/Users/tmoney/Developer/trooth_assessment" commit -m "chore: bump version to SEMVER (build BUILD)"
```

If the commit fails (e.g. pre-commit hook), report the error and stop.

---

## Final Report

```
## Version bump complete

- Old version: X.Y.Z+N
- New version: SEMVER+BUILD
- Files updated: pubspec.yaml, ios/Runner/Info.plist
- Committed: chore: bump version to SEMVER (build BUILD)
```
