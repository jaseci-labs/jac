# bundle_patch.py → Jac Migration Plan

Migrate `jac-super/jac_super/ink_compile/bundle_patch.py` to Jac source. The compiled
Python output should behave identically to the current hand-written module — pure
string/regex manipulation on compiled JS bundles, no jaclang runtime dependencies
beyond what `compile.py` already loads.

---

## What We're Migrating

`bundle_patch.py` is a good first candidate:

- ~224 lines, stdlib `re` only
- No jaclang runtime APIs
- Pure string transforms on compiled JS bundles
- Already has solid pytest coverage in `tests/test_ink_compile.py`

### Public API (used by `compile.py`)

```python
from jac_super.ink_compile.bundle_patch import (
    consolidate_bundle_imports,
    fix_broken_nullish_or,
    hoist_jac_runtime,
)
```

### Internal helpers

| Function | Role |
|----------|------|
| `_skip_string` | Skip quoted strings when scanning JS |
| `_extract_brace_block` | Brace-aware block extraction (strings, comments, templates) |
| `_is_theme_module_marker` | Detect inlined theme module markers |
| `_end_of_jac_runtime_block` | Find end of `const _jac = { ... };` block |
| Module-level `re.compile(...)` patterns | Regex for imports, runtime blocks, nullish-or fix |

The hard parts are not the regex one-liners — they're the stateful line scanners
(`consolidate_bundle_imports`) and the brace-aware JS parser (`_extract_brace_block` /
`_skip_string`).

---

## Two Different "Compiles" — Keep Them Separate

| Stage | What | Tool |
|-------|------|------|
| **A. Source migration** | Python → Jac source | `jac py2jac` (draft) + manual cleanup |
| **B. Runtime delivery** | Jac source → executable Python | `jac jac2py` or `Jac.jac_import()` at runtime |

Stage A is the authoring workflow. Stage B is how `compile.py` actually gets the
functions. Don't conflate them.

**Recommended runtime path:** `Jac.jac_import("bundle_patch", ...)` from `compile.py`,
since `compile.py` already loads jaclang for `ClientBundleBuilder`. No chicken-and-egg
problem.

---

## What `py2jac` Actually Produces

Running `jac py2jac bundle_patch.py` gives a structurally useful draft, but
`jac check` fails without manual fixes.

| py2jac output | Correct Jac |
|---------------|-------------|
| Module constants inside `with entry { ... }` | `glob _RE = re.compile(...),` at module level (see `cl_test_runner.jac`) |
| `` `match ``, `` `list(`, `` `set( `` | Rename loop var (`m` instead of `match`); bare `list()` / `set()` |
| `import from __future__ { annotations }` | Drop it — Jac doesn't need it |
| `re.compile(..., re.MULTILINE)` | Type checker chokes; use inline `(?m)^...` instead |
| `tuple[(str, int)]` | `tuple[str, int]` |
| `f'import {{ {{ ... }} }} from ...'` | Single braces in f-strings |

**Verdict:** use py2jac as a **scaffold**, not as the final source. Expect ~30–45 min
of cleanup, not zero-touch conversion.

---

## Recommended File Layout

```
jac-super/jac_super/ink_compile/
  bundle_patch.jac          ← source of truth
  bundle_patch.py           ← delete once import path switches (or keep generated during transition)
  compile.py                ← change import only
```

No `.impl.jac` split needed at this size. No OSP (nodes/walkers) — this is plain
module-level functions.

---

## Jac Idioms to Follow

### Module-level regex

Mirror `jac/jaclang/runtimelib/cl_test_runner.jac`:

```jac
import re;

glob _JAC_RUNTIME_START = re.compile(r"(?m)^\s*const _jac = \{\s*$"),
     _IMPORT_LINE_RE = re.compile(
         r'^import\s+\{([^}]+)\}\s+from\s+(["\'])([^"\']+)\2;\s*$'
     ),
     _THEME_IMPORT_RE = re.compile(r"^\./(?:.*/)?theme\.js$"),
     _MODULE_MARKER = re.compile(
         r"(?m)^//\s*(?:Imported \.jac module:|Client module:)\s*(.+?)\s*$"
     ),
     _BROKEN_NULLISH_OR = re.compile(
         r'(\w+(?:\[\w+\])?\s*\?\?\s*""\s*)\|\|\s*""'
     );

glob _IMPORT_ORDER: list[str] = [
    "./runtime_shim.mjs",
    "./jac_runtime_shim.mjs",
    "./jac_builtin_runtime.mjs",
    "ink",
    "@inkjs/ui",
    "./jac_pi_runtime_shim.mjs",
];
```

### Function bodies

Semicolons, braces, parenthesized enumerate:

```jac
def hoist_jac_runtime(code: str) -> tuple[str, str | None] {
    matches = list(_JAC_RUNTIME_START.finditer(code));
    ...
    for (idx, m) in enumerate(matches) {
        start = m.start();
        ...
    }
}
```

Everything else in this file (dict/set, comprehensions, f-strings, `re.sub`, slicing)
maps 1:1.

---

## Phased Migration Plan

### Phase 0 — Baseline

Existing pytest suite is the contract. Don't change behavior.

- `tests/test_ink_compile.py` — unit tests for all patch functions
- `TestCompileIntegration` — full Ink compile smoke test

### Phase 1 — Port Bottom-Up (Easiest → Hardest)

| Order | Function | Why this order |
|-------|----------|----------------|
| 1 | `fix_broken_nullish_or` | One-liner; validates glob + regex + jac2py round-trip |
| 2 | `_skip_string` | Small loop; needed by brace parser |
| 3 | `_extract_brace_block` | Most tested; preserve known `${}` limitation |
| 4 | `_is_theme_module_marker` | Trivial |
| 5 | `_end_of_jac_runtime_block` | Uses brace parser |
| 6 | `consolidate_bundle_imports` | Largest state machine |
| 7 | `hoist_jac_runtime` | Orchestrates the above |

After each function: `jac check bundle_patch.jac`.

### Phase 2 — Semi-Automated Draft Workflow

```bash
jac py2jac jac-super/jac_super/ink_compile/bundle_patch.py > /tmp/bundle_patch.draft.jac

# Cleanup checklist:
# □ Move constants from with entry → glob
# □ Remove backtick-escaped match/list/set
# □ Replace re.MULTILINE with (?m) in patterns
# □ Fix f-string brace doubling
# □ Fix tuple[...] syntax
# □ Drop __future__ import
# □ jac check until clean
# □ jac jac2py → diff against original .py (optional sanity)
```

### Phase 3 — Wire Into Compile Pipeline

#### Option A (recommended): runtime Jac import

```python
# compile.py
from jaclang import JacRuntime as Jac

(mod,) = Jac.jac_import("bundle_patch", str(Path(__file__).parent))
consolidate_bundle_imports = mod.consolidate_bundle_imports
fix_broken_nullish_or = mod.fix_broken_nullish_or
hoist_jac_runtime = mod.hoist_jac_runtime
```

#### Option B: build-time `jac jac2py`

Generate `bundle_patch.py` in packaging/CI. Keeps plain Python imports but adds a
build step.

Start with A; switch to B only if zero runtime Jac import for the patcher is desired.

#### Update build invalidation

In `jac_super/ai_agent/impl/run_tui_session.impl.jac`, change mtime watch from
`bundle_patch.py` to `bundle_patch.jac` (or watch both during transition):

```jac
bundle_patch_jac = ink_compile / "bundle_patch.jac";
sources = [ink_source, compile_py, bundle_patch_jac];
```

### Phase 4 — Verify

1. `pytest jac-super/tests/test_ink_compile.py` — all existing tests pass unchanged
2. `TestCompileIntegration` smoke test — full Ink compile still works
3. Optional: add `bundle_patch.test.jac` for `jac test` parity (not required if pytest
   stays the contract)

---

## Python → Jac Construct Map

| Python | Jac | Gotcha |
|--------|-----|--------|
| `from __future__ import annotations` | omit | Jac handles forward refs |
| module `_CONST = ...` | `glob _CONST = ...` | not inside `with entry` |
| `def _foo(...):` | `def _foo(...) { ... }` | semicolons on every statement |
| `for i, x in enumerate(...)` | `for (i, x) in enumerate(...)` | parens required |
| `match` as variable name | rename to `m` | `match` is a keyword |
| `re.compile(p, re.MULTILINE)` | `re.compile(r"(?m)^...")` | type checker issue with 2-arg compile |
| `list[str]`, `dict[str, set[str]]` | same | works |
| `path \| None` | same | union syntax works |
| `parts = [*a, *b]` | same | works |

---

## Behavior Contracts (from tests — must preserve)

### `_extract_brace_block`

- Skip strings (`'` / `"`), `//` line comments, `/* */` block comments, template literals
- **Do not** track `${}` inside template literals (documented limitation in tests)
- `start` is index **after** opening `{`; returns body between braces and `end` past closing `}`

### `fix_broken_nullish_or`

- Regex: `(\w+(?:\[\w+\])?\s*\?\?\s*""\s*)\|\|\s*""`
- Matches `foo[key]` but **not** `foo["key"]` (quoted bracket keys unchanged)

### `consolidate_bundle_imports`

- Theme block hoisting (first theme block wins)
- Import merge by spec; theme.js imports excluded from merge
- Symbol detection adds missing imports: `Static`, `Spinner`, `Box`, `Text`, `useInput`
- Import order follows `_IMPORT_ORDER`, then alphabetical for remainder

### `hoist_jac_runtime`

- First `const _jac = { ... }` block becomes standalone module with `export { _jac };`
- All runtime blocks removed from main bundle
- Returns `(stripped_code, runtime_module | None)`

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| py2jac emits broken Jac | Treat as draft only; hand-fix with checklist |
| `re.MULTILINE` type errors | Inline `(?m)` flags (validated — passes `jac check`) |
| Subtle semantic drift | Keep pytest as source of truth; no test changes initially |
| Stale Ink bundles | Update mtime watch to `.jac` |
| Future `compile.py` migration | Prove pattern on `bundle_patch` first; `compile.py` is 500+ lines with jaclang internals |

---

## Success Criteria

1. `bundle_patch.jac` passes `jac check`
2. All `test_ink_compile.py` tests green (no test edits unless fixing a pre-existing bug)
3. `compile_ink_app` integration test still produces valid `module.mjs`
4. `bundle_patch.py` removed or clearly marked generated
5. `jac jac2py bundle_patch.jac` produces Python that is semantically equivalent (exact
   text match not required)

---

## Suggested Next Step

Start with a **spike on `fix_broken_nullish_or` + `_skip_string`** (~40 lines Jac).
That validates the full loop:

1. Write Jac
2. `jac check`
3. Wire import in `compile.py`
4. Run pytest

If that passes, port the rest in Phase 1 order.
