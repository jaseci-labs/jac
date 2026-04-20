# Release Note Fragments

Every PR that changes package code must include a release note fragment file.

## How to add a release note

1. Create a file at `docs/docs/community/release_notes/unreleased/<package>/<PR#>.<category>.md`
   - **Packages**: `jaclang`, `byllm`, `jac-client`, `jac-scale`, `jac-super`, `jac-mcp`
   - **Categories**: `feature`, `bugfix`, `breaking`, `refactor`, or `docs`
   - **Example**: `docs/docs/community/release_notes/unreleased/jaclang/1234.bugfix.md`

2. Add one or more bullet points in the file.

## Fragment format

```markdown
- **Fix: Brief title**: Description of what changed.
```

## Examples

**Feature** (`docs/docs/community/release_notes/unreleased/jaclang/1234.feature.md`):

```markdown
- **Type Checker: Improved narrowing for AND/OR expressions**: Type narrowing now works correctly in nested ternary expressions and AND/OR chains.
```

**Bug fix** (`docs/docs/community/release_notes/unreleased/jaclang/1234.bugfix.md`):

```markdown
- **Fix: `by postinit` symbol resolution**: Fields declared with `by postinit` no longer show a false W2001 warning.
```

**Breaking change** (`docs/docs/community/release_notes/unreleased/jaclang/1234.breaking.md`):

```markdown
- **Breaking: Brief title**: What changed and what users need to do.
```

**Refactor** (`docs/docs/community/release_notes/unreleased/jaclang/1234.refactor.md`):

```markdown
- **Refactor: Brief title**: Description of the internal change.
```

**Documentation** (`docs/docs/community/release_notes/unreleased/jaclang/1234.docs.md`):

```markdown
- **Docs: Brief title**: Description of the documentation update.
```

## Skipping

To skip this check, add the `skip-release-notes-check` label to your PR.
