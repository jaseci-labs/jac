---
name: jac-debugging
description: Diagnose compiler errors, stale behavior, graph failures, and cross-boundary mismatches. Use for targeted repair and data-preserving cache or schema triage.
---

The core loop: write -> `jac check <paths>` -> read the diagnostic -> follow its guide pointer -> fix -> re-check -> `jac test`.

## Reading a diagnostic

```
error[E1001]: Cannot assign int to str
  --> app.jac:2:5
    2 |     y: str = x;
      |     ^^^^^^^^^^^
  → run 'jac guide jac-types' for guidance
```

- Severity letter: `E` error (check fails, exit 1) / `W` warning.
- First digit = category: `0` syntax, `1` type, `2` semantic, `3` lint, `4` import, `5` codegen, `9` internal compiler bug (file an issue).
- **When a `→ run 'jac guide <name>'` pointer appears, run it** - it names the exact reference guide for that error class.

`jac check` flags: `-i`/`--ignore <dirs...>` skip paths, `-p`/`--parse_only` syntax only (NOT `--parse-only` - hyphen form is rejected), `-n`/`--nowarn` hide warnings, `-d`/`--disable-error-code E1030 no-print` suppress codes for the run.

## Suppressing a diagnostic (last resort)

Same-line comment, comma-separated for several codes:

```
x = some_func();  # jac:ignore[E1030,W2003]
```

Prefer fixing the cause; suppression hides real regressions later. Project-wide lint selection lives in `[check.lint]` (`select` / `ignore` / `exclude`) in jac.toml.

`jac run` reports diagnostics too: `-e all` shows warnings, `-e none` silences everything (default `error`); the default comes from `[run] diagnostics`.

## Diagnose state and cache errors

Start with the first diagnostic, the selected app, and the active storage configuration. An invalid anchor is evidence of an unresolved reference, not proof that the compiler cache or database is stale.

| Symptom | Next check |
|---|---|
| Invalid anchor or missing node | Check the ID, app/store selection, deletion history, and access context. After schema edits, inspect migration aliases and quarantined records with the persistence guide. |
| Edits appear ignored | Confirm which source and compiler version are running; restart the server after server changes. If compiled artifacts are stale, use `jac clean --cache`. |
| Tests depend on run order or old nodes | Create isolated fixtures, identify the nodes each test creates, and clean up those fixtures. Do not assert totals on a shared root. |
| A server returns 500 after a model change | Read the server traceback and compare the stored schema with the current declarations before choosing a migration or repair. |

`jac clean` removes configured project directories: by default the data directory; `--cache` selects compiled artifacts; `--all` also includes data, packages, and client output; `--force` bypasses confirmation. It is not a general reset for an external database. Reset data only when it is explicitly disposable or its deletion is authorized; name the exact target and preserve anything needed for migration or diagnosis. See `jac-sv-persistence` for schema evolution.

## `jac check --lint --fix` vs `jac fmt`

- `jac fmt <paths>` - whitespace/layout only. `-s` previews to stdout; `--check` exits 1 if anything is unformatted (CI). If formatting would displace comments, it emits `E5051` and **refuses to save** - inspect with `-s`.
- `jac check <paths> --lint` - reports rule violations with kebab names (`[combine-has]`, `[no-print]`); add `--fix` to apply the auto-fixable ones and report the rest (`N fixed, M unfixable`).
- `jac fmt <paths> -l` formats and lint-fixes in one pass.

## Inspecting the graph

When walker logic misbehaves, look at the actual graph instead of guessing:

```
jac dot app.jac -p              # print DOT to stdout (after the entry runs)
jac dot app.jac -o graph.dot    # save (render with graphviz)
jac dot app.jac -d 3            # limit traversal depth
```

If `jac dot` reports an invalid anchor, apply the reference and storage checks above before retrying.

For a served app, `jac browse` drives a headless Chrome from the CLI (`jac browse open localhost:8000`, `snapshot`, `click @e1`, `screenshot`) - end-to-end checks without Playwright.

## After changing a server contract

Renamed or retyped a `def:pub` param, a walker `has` field, or a report shape? Run `jac check` project-wide and read the hits in client `.jac` files as **drift pointers to the stale callers**:

```
⚠ warning[W1101]: Cannot import name 'greet' from module '.store'
  --> components/App.jac:1:33
```

- `W1101` at a client's server-module import - the imported endpoint/type no longer exists on the server (rename or removal).
- `W1051` (unresolvable expression) at a client call or spawn site - the caller is still feeding the old contract.
- A retyped param escalates to a hard `E1053` at the client call line (`Cannot assign Literal["world"] to parameter 'name' of type int`).

Measured on a real fullstack app (47 seeded contract mutations): `jac check` flagged the stale **client** line in 70% of cases at error level, 79% counting warnings - the equivalent TypeScript+Python twin caught 0% across the boundary, because tsc never sees the mutated server and mypy never sees the stale client. Caveat: W1101/W1051 also fire for ordinary typos - the signal is their **location** (client files, right after a server edit). Cross-boundary import wiring rules: `jac-fullstack-patterns`.

## Pitfalls

- **Don't "fix" a type error by switching to `any`** - it defers the error to the next typed boundary (see `jac-types` for the real moves, including the `as` cast).
- **`W2003` unused-name warnings fail an otherwise clean check** - prefix intentionally-unused names with `_` (see `jac-core-cheatsheet`).
- **A diagnostic pointing at correct-looking code** can originate in an upstream import or unresolved type. Check the first error and the resolved source before changing caches.

## See also

- `jac-testing` - running tests, the persisted-root gotcha
- `jac-types` - clearing E1xxx type errors properly
- `jac-fullstack-patterns` - the import / endpoint-registry rules behind contract drift
- `jac-config` - `[check.lint]`, `[run] diagnostics`
