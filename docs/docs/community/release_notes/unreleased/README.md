# Release Note Fragments

Each PR that changes package code should include a release note fragment file.

## How to add a release note

1. Pick the right **package** folder (e.g., `jaclang/`, `jac-scale/`, `byllm/`)
2. Pick the right **category** subfolder:
   - `feature/` - New features, enhancements, improvements
   - `bugfix/` - Bug fixes, cleanups, corrections
3. Create a file named `<PR#>.md` (e.g., `5354.md`)
4. Write one or more bullet point entries

## Fragment format

```markdown
- **Category: Brief title**: Description of the change.
```

## Examples

**Feature** (`jaclang/feature/5400.md`):

```markdown
- **Type Checker: Improved narrowing for AND/OR expressions**: Type narrowing now works correctly in nested ternary expressions and AND/OR chains.
```

**Bug fix** (`jaclang/bugfix/5354.md`):

```markdown
- **Fix: `by postinit` symbol resolution**: Fields declared with `by postinit` no longer show a false W2001 warning.
```

## What happens at release time

A script collects all fragments, groups them by category (New Features / Bug Fixes),
inserts them into the package's release notes file, and deletes the fragment files.

## Skipping

To skip this check: `SKIP=check-release-notes git commit ...`
