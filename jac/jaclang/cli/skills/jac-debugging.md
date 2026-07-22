---
name: jac-debugging
description: The Jac fix loop - reading `jac check` diagnostics (E/W code anatomy, `jac guide` pointers), `# jac:ignore[CODE]` suppression, stale-cache triage (`jac clean` vs `jac purge` vs `.jac/data`), cross-boundary drift after server-contract changes (W1101/W1051 in client files), `jac check --lint --fix` vs `jac fmt`, graph inspection with `jac dot`. Load when a build fails, errors look wrong, or behavior is stale/inexplicable.
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

## Stale-cache triage table

Compiled bytecode and persisted graph data both outlive your source edits. When behavior makes no sense, suspect staleness **before** suspecting your code:

| Symptom | Fix |
|---|---|
| `NodeAnchor <id> is not a valid reference` / `Invalid anchor id` | `jac clean --all --force` (stale persisted graph vs recompiled types) |
| Syntax/type errors on code you know is correct; edits seem ignored | `jac clean --cache` (project bytecode), then `jac purge` (global cache - survives even a corrupted cache; use after upgrading Jaseci packages) |
| A served app starts returning 500s with anchor/schema errors after model changes | Stop the server, `rm -rf .jac/data/`, restart (dev only - this deletes data; see `jac-sv-persistence` for migration-safe renames) |
| Tests green once, red on re-run with leftover nodes | `jac clean --all --force` before the run (see `jac-testing`) |

`jac clean` scopes: default = `.jac/data` only; `--cache` bytecode; `--all` data+cache+venv+client; `--force` skips the confirm prompt. `jac purge` clears the global (per-user) cache.

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

If `jac dot` itself throws `NodeAnchor ... is not a valid reference`, that's the triage table again: `jac clean --all --force` and re-run.

For a served app, `jac browse` drives a headless Chrome from the CLI (`jac browse open localhost:8000`, `snapshot`, `click @e1`, `screenshot`) - end-to-end checks without Playwright.

## After changing a server contract

Renamed or retyped a `def:pub` param, a walker `has` field, or a report shape? Run `jac check` project-wide and read the hits in client `.jac` files as **drift pointers to the stale callers**:

```
⚠ warning[W1101]: Cannot import name 'greet' from module '..services.api'
  --> components/App.jac:1:33
```

- `W1101` at a client's `sv import` - the imported endpoint/type no longer exists on the server (rename or removal).
- `W1051` (unresolvable expression) at a client call or spawn site - the caller is still feeding the old contract.
- A retyped param escalates to a hard `E1053` at the client call line (`Cannot assign Literal["world"] to parameter 'name' of type int`).

Measured on a real fullstack app (47 seeded contract mutations): `jac check` flagged the stale **client** line in 70% of cases at error level, 79% counting warnings - the equivalent TypeScript+Python twin caught 0% across the boundary, because tsc never sees the mutated server and mypy never sees the stale client. Caveat: W1101/W1051 also fire for ordinary typos - the signal is their **location** (client files, right after a server edit). `sv import` wiring rules: `jac-fullstack-patterns`.

## Pitfalls

- **Don't "fix" a type error by switching to `any`** - it defers the error to the next typed boundary (see `jac-types` for the real moves, including the `as` cast).
- **`W2003` unused-name warnings fail an otherwise clean check** - prefix intentionally-unused names with `_` (see `jac-core-cheatsheet`).
- **A diagnostic pointing at correct-looking code** usually means staleness (table above) or a wrong-dot relative import upstream resolving to `<Unknown>` - check the first error in the list, not the loudest one.

## See also

- `jac-testing` - running tests, the persisted-root gotcha
- `jac-types` - clearing E1xxx type errors properly
- `jac-fullstack-patterns` - the `sv import` / endpoint-registry rules behind contract drift
- `jac-config` - `[check.lint]`, `[run] diagnostics`
