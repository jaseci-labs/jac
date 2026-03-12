# Jac Diagnostic System -- Full Implementation Plan

## Purpose

This document is a **self-contained execution plan** for implementing a centralized diagnostic code system for the Jac language compiler. It replaces three parallel error systems (`ParseError`, `LexerError`, `Alert`) with a single unified system featuring enumerated error codes, template-based messages, multi-span support, help text, and suppression via `jac.toml` and inline comments.

---

## How To Use This Plan

Feed this entire document as context in a single prompt with the instruction:

> Implement the Jac diagnostic system as described in `_planning/diagnostic_system.md`. Work through every phase in order. After completing each phase, update the status in this file, re-read it to re-orient, and continue to the next phase. Do not stop until all phases are complete.

### Agent Protocol

**Looping**: After completing each phase:

1. Edit this file -- change the phase status from `STATUS: PENDING` to `STATUS: DONE`
2. If you made design decisions that differ from the plan, add a `> DEVIATION:` blockquote under that phase explaining what changed and why
3. Re-read this file to find the next `PENDING` phase
4. Continue

**When you discover something that contradicts the plan**:

1. Do NOT silently improvise -- document the issue
2. Add a `> BLOCKER:` blockquote under the current phase describing what you found
3. Write your proposed alternative approach in the blockquote
4. Implement the alternative (don't stop to ask -- your judgment is trusted here)
5. Continue to the next phase

**When a phase is harder than expected**:

- If a phase balloons beyond ~30 file edits, split your work into sub-commits
- If tests fail after a phase, fix them BEFORE moving on -- add a `> FIX:` note

**Re-orientation**: If context gets long, run:

```bash
grep -n 'STATUS:' _planning/diagnostic_system.md
```

This shows you which phases are DONE vs PENDING at a glance.

**Test command** (run after every phase):

```bash
cd /home/marsninja/repos/jaseci/jac && python -m pytest tests/ -x -q --timeout=60 2>&1 | tail -30
```

---

## Architecture Overview

### New File

- `jac/jaclang/jac0core/diagnostics.jac` -- The single registry of every error/warning code

### Core Design Decisions

1. **Alert gets optional `code` field** -- `code=None` means un-migrated callsite, full backward compat
2. **`Transform.emit(diag, **kwargs)`** -- new preferred API, formats template + checks suppression
3. **`log_error`/`log_warning` stay** -- they become thin wrappers or escape hatches, not deleted
4. **ParseError/LexerError eliminated** -- parser/lexer write Alerts directly via prog
5. **LintRule enum replaced** -- by W3xxx codes with alias mapping for jac.toml backward compat
6. **DiagnosticCallback bridge removed** -- TypeEvaluator gets direct emit path

### Code Convention

```
{E|W}{category_digit}{sequence:03d}
E = error, W = warning
0 = syntax, 1 = type, 2 = semantic, 3 = lint, 4 = import, 5 = codegen, 9 = ICE
```

---

## Phase 1: Foundation -- Registry + Alert Evolution

STATUS: DONE

### Goal

Create `diagnostics.jac` with all codes. Evolve `Alert` to accept optional `code`/`related`/`help_text`. Add `Transform.emit()`. Add suppression config. **Zero callsite changes** -- everything backward compatible via defaults.

### What to create

**`jac/jaclang/jac0core/diagnostics.jac`** containing:

- `enum Severity { ERROR, WARNING, NOTE, HELP }`
- `enum Category { SYNTAX, TYPE, SEMANTIC, LINT, IMPORT, CODEGEN, RUNTIME, ICE }`
- `obj DiagnosticInfo { code, severity, category, message_template, help_text?, url_slug? }`
- `glob DIAGNOSTICS: dict[str, DiagnosticInfo]` -- populated by `_reg()` helper
- `glob LINT_ALIASES: dict[str, str]` -- maps old kebab names to W3xxx codes
- All E0xxx, E1xxx, W2xxx/E2xxx, W3xxx, E5xxx, E9xxx codes

**IMPORTANT**: Do not guess error messages. Read each source file listed below and extract the exact message strings to build templates from:

- `jac/jaclang/jac0core/parser/impl/parser.impl.jac` -- all `self.error(...)` calls → E0xxx
- `jac/jaclang/jac0core/parser/impl/lexer.impl.jac` -- all `self.error(...)` calls → E0xxx
- `jac/jaclang/compiler/passes/main/impl/type_checker_pass.impl.jac` -- all `log_error`/`log_warning` → E1xxx
- `jac/jaclang/compiler/type_system/type_evaluator.impl/` -- all `add_diagnostic` calls → E1xxx
- `jac/jaclang/compiler/passes/main/impl/static_analysis_pass.impl.jac` → W2xxx
- `jac/jaclang/jac0core/passes/impl/semantic_analysis_pass.impl.jac` → E2xxx/W2xxx
- `jac/jaclang/jac0core/passes/impl/def_impl_match_pass.impl.jac` → E2xxx/W2xxx
- `jac/jaclang/compiler/passes/tool/impl/jac_auto_lint_pass.impl.jac` → W3xxx
- `jac/jaclang/jac0core/passes/impl/pyast_gen_pass.impl.jac` → E5xxx
- `jac/jaclang/compiler/passes/ecmascript/impl/esast_gen_pass.impl.jac` → E5xxx
- `jac/jaclang/compiler/passes/native/impl/na_compile_pass.impl.jac` → E5xxx/W5xxx
- `jac/jaclang/compiler/passes/main/impl/layout_pass.impl.jac` → E5xxx/W5xxx
- `jac/jaclang/jac0core/passes/impl/pybc_gen_pass.impl.jac` → E5xxx
- `jac/jaclang/compiler/passes/main/impl/pyast_load_pass.impl.jac` → E5xxx
- `jac/jaclang/compiler/passes/tool/impl/comment_injection_pass.impl.jac` → W5xxx
- `jac/jaclang/compiler/passes/native/na_ir_gen_pass.impl/core.impl.jac` → E5xxx
- `jac/jaclang/langserve/impl/engine.impl.jac` → E5xxx/W5xxx

### What to modify

**`jac/jaclang/jac0core/passes/transform.jac`** -- Alert gains:

```jac
def init(self, msg, loc, from_pass,
    code: DiagnosticInfo | None = None,
    related: list[tuple[str, CodeLocInfo]] | None = None,
    help_text: str | None = None) -> None;
```

Transform gains:

```jac
def emit(self, diag: DiagnosticInfo,
    node_override: UniNode | None = None,
    related: list[tuple[str, UniNode]] | None = None,
    help_text: str | None = None,
    **kwargs: Any) -> None;
```

**`jac/jaclang/jac0core/passes/impl/transform.impl.jac`** -- implement new Alert fields, emit(), _is_suppressed()

**`jac/jaclang/jac0core/helpers.jac`** -- add `format_related_spans()` helper, enhance pretty_print output

**`jac/jaclang/project/config.jac`** -- add `suppress: list[str]` and `suppress_categories: list[str]` to CheckConfig

**`jac/jaclang/project/impl/config.impl.jac`** -- parse new fields from TOML `[check]` section

### Enhanced pretty_print format (when code is present)

```
error[E1001]: Cannot assign 'str' to 'int'
  --> example.jac:42:5
   |
40 |     x: int = 0;
41 |     name = get_name();
42 |     x = name;
   |         ^^^^ expected 'int', found 'str'
   |
note: variable declared as 'int' here
  --> example.jac:40:5
   |
40 |     x: int = 0;
   |     ^ declared here
   |
help: use an explicit conversion: int(name)
```

When code is None (un-migrated), falls back to current format.

### Acceptance criteria

- All existing tests pass with zero changes (code=None default means backward compat)
- `from jaclang.jac0core.diagnostics import E1001` works
- `Alert(msg, loc, pass, code=E1001).pretty_print()` shows the new format
- `Transform.emit(E1001, actual="str", expected="int")` creates correct Alert

### Commit

"Feat: Add diagnostic code registry and evolve Alert for structured errors"

---

## Phase 2: Migrate Parser and Lexer

STATUS: DONE

> DEVIATION: Lexer keeps `self.error()` calls instead of `self.emit_diag()` because `lexer.na.jac` is used for native LLVM compilation and `DiagnosticInfo` is a Python-only class. Lexer errors still propagate to `prog.errors_had` as Alert objects via improved `error()` implementation. Parser fully migrated to 38 diagnostic codes via `self.emit_diag()`/`self.emit_warn()`.
>
> DEVIATION: `ParseError`/`LexerError` classes fully removed. `parse()` returns `(Module, bool)` instead of `(Module, list[ParseError], list[LexerError])`. All callers updated.

### Goal

Move parser and lexer to emit diagnostic codes. Remove `ParseError`, `LexerError` classes and the bridge code. Simplify `parse()` return type.

### Steps

1. **Add `Parser.emit_diag()`** method -- formats template, creates Alert, appends to `self.prog.errors_had`. Also temporarily keeps `self.errors` list for callers that read it.

2. **Migrate all ~41 `self.error(...)` calls in parser.impl.jac** to `self.emit_diag(E0xxx, ...)`. Read the file to find every callsite -- don't rely on the list from Phase 1, the file is authoritative.

3. **Pass `prog` to Lexer** -- modify Lexer class to accept optional `prog` parameter. Add `Lexer.emit_diag()`. Migrate all ~11 `self.error(...)` calls.

4. **Simplify `parse()` return** -- errors are now in prog directly. Change return type. Update all callers (compiler.impl.jac and anywhere else that destructures the tuple). Search for all callsites first.

5. **Remove `ParseError` class** from parser.jac, `LexerError` class from lexer.na.jac, `parser.errors` list, `lexer.errors` list.

6. **Remove bridge code** -- the UniToken/CodeLocInfo creation in old `Parser.error()`, `Parser.error_at()`, `Parser.warn_at()`.

### Likely discoveries that may require plan deviation

- Other files may import `ParseError` or `LexerError` (tests, langserve, etc.) -- search and fix
- The `parse()` return tuple shape may be assumed in more places than just compiler.impl.jac
- Some parser tests check `len(parser.errors)` -- these need to check `prog.errors_had` instead

### Acceptance criteria

- `grep -r 'ParseError' jac/jaclang/` returns zero hits
- `grep -r 'LexerError' jac/jaclang/` returns zero hits
- Parser tests pass
- Full test suite passes

### Commit

"Refactor: Migrate parser/lexer to diagnostic codes, remove ParseError/LexerError"

---

## Phase 3: Migrate Type Checker

STATUS: DONE

> DEVIATION: Chose Option A variant -- TypeEvaluator gets `_pass: object | None` reference (set by TypeCheckPass in `before_pass()`). TypeEvaluator calls `self._pass.emit()` directly via duck typing, avoiding circular imports. No new callback type needed.
>
> DEVIATION: Also migrated `operations.jac` (12 `evaluator.add_diagnostic` calls) and `enum_utils.impl.jac` (1 call) which were not listed in the plan but call `add_diagnostic` on the evaluator. Added E1099 code for union attribute access with missing types info.
>
> DEVIATION: One escape hatch remains: `self._pass.log_error(str(e), ...)` in `parameter_type_check.impl.jac` for catch-all exception messages during argument matching -- these are dynamic exception strings that can't be templated.

### Goal

Replace all `log_error`/`log_warning` in type checker with `emit()`. Remove the `DiagnosticCallback` bridge between TypeEvaluator and TypeCheckPass.

### Steps

1. **Migrate type_checker_pass.impl.jac** -- ~22 `log_error`/`log_warning` calls → `self.emit(E1xxx, ...)`

2. **Decide how TypeEvaluator emits diagnostics**:
   - Option A: Give TypeEvaluator a reference to Transform and call `transform.emit()` directly
   - Option B: Keep a callback but typed as `Callable[[DiagnosticInfo, UniNode, dict], None]`
   - Option C: Have TypeEvaluator return diagnostics and let the pass emit them
   - Choose based on what the import graph allows. Document choice in a `> DEVIATION:` note.

3. **Migrate all `add_diagnostic()` calls in type_evaluator.impl/\*.impl.jac** -- find them all with grep, assign E1xxx codes.

4. **Remove DiagnosticCallback** type alias, `_add_diagnostic()` method, callback setup in `before_pass()`.

### Likely discoveries

- TypeEvaluator is in `compiler/type_system/` which may not be able to import from `jac0core/diagnostics.jac` without circular deps. If so, pass DiagnosticInfo objects from the caller or use the callback approach.
- Some type error messages are constructed deep in utility functions with complex logic -- may need to read the surrounding code carefully.

### Acceptance criteria

- `grep -r 'DiagnosticCallback' jac/jaclang/` returns zero hits
- `grep -r 'add_diagnostic' jac/jaclang/` returns zero hits (except any new emit wrapper)
- Type checker tests pass
- Full test suite passes

### Commit

"Refactor: Migrate type checker to diagnostic codes, remove DiagnosticCallback bridge"

---

## Phase 4: Migrate All Remaining Passes

STATUS: DONE

> DEVIATION: `langserve/engine.impl.jac` callsites were NOT migrated because `JacLangServer` extends `JacProgram` + `LanguageServer` (not `Transform`). Its `log_error`/`log_warning` are LSP message display methods, not compiler diagnostics.
>
> DEVIATION: `jac_auto_lint_pass.impl.jac` callsites are intentionally deferred to Phase 5 (LintRule replacement).
>
> FIX: 4 test assertions in `test_checker_pass.jac`, `test_typevar.jac`, and `test_compilation.jac` were updated to match the new pretty-printed diagnostic message format from Phase 3.

### Goal

Migrate every remaining `log_error`/`log_warning` call across all passes to `emit()`.

### Files to migrate (read each one, find all callsites):

- `static_analysis_pass.impl.jac` -- 3 warnings → W2001/W2002/W2003
- `semantic_analysis_pass.impl.jac` -- 3 errors, 2 warnings → E2xxx/W2xxx
- `def_impl_match_pass.impl.jac` -- 3 errors, 1 warning → E2xxx/W2xxx
- `pyast_gen_pass.impl.jac` -- ~8 errors → E5xxx
- `esast_gen_pass.impl.jac` -- ~3 errors, ~2 warnings → E5xxx/W5xxx
- `na_compile_pass.impl.jac` -- ~1 error, ~6 warnings → E5xxx/W5xxx
- `layout_pass.impl.jac` -- ~1 error, ~2 warnings → E5xxx/W5xxx
- `pybc_gen_pass.impl.jac` -- ~1 error → E5xxx
- `pyast_load_pass.impl.jac` -- ~2 errors → E5xxx
- `comment_injection_pass.impl.jac` -- ~1 warning → W5xxx
- `na_ir_gen core.impl.jac` -- ~1 error → E5xxx
- `langserve engine.impl.jac` -- ~2 errors, ~1 warning → E5xxx/W5xxx
- `Transform.ice()` -- use E9001

### Note

The counts above are estimates from a prior audit. The actual files are authoritative -- read each one and find ALL callsites. If new codes are needed beyond what Phase 1 registered, add them to diagnostics.jac.

### Acceptance criteria

- `grep -rn 'self.log_error\|self.log_warning' jac/jaclang/` returns only:
  - The method definitions in transform.impl.jac
  - Any intentional escape-hatch usage (document in DEVIATION note)
- Full test suite passes

### Commit

"Refactor: Migrate all remaining passes to diagnostic codes"

---

## Phase 5: Replace LintRule System

STATUS: DONE

> DEVIATION: `LintConfig` was kept in config.jac for backward compatibility with jac.toml `[check.lint]` config parsing. Only `LintRule` enum was removed.
>
> DEVIATION: Lint select/ignore/default/all semantics moved into `_is_suppressed()` in transform.impl.jac rather than a separate config loading step. This unified all suppression logic into one place.

### Goal

Remove the `LintRule` enum, `LintConfig` object, `_load_lint_config()`, `is_rule_enabled()`, and 79 guard calls. Lint suppression flows through the unified `emit()` → `_is_suppressed()` path.

### Mapping (old → new)

```
staticmethod-to-static   → W3001
combine-has              → W3002
combine-glob             → W3003
init-to-can              → W3004
remove-empty-parens      → W3005
remove-kwesc             → W3006
hasattr-to-null-ok       → W3007
simplify-ternary         → W3008
remove-future-annotations → W3009
fix-impl-signature       → W3010
remove-import-semi       → W3011
no-print                 → W3012
```

### Steps

1. **Migrate jac_auto_lint_pass.impl.jac** -- every `if self.is_rule_enabled(LR.XXX) { ... self.log_warning(...) }` becomes just the body with `self.emit(W3xxx, ...)`. The suppression check is implicit in emit().

2. **Update jac_auto_lint_pass.jac** -- remove LintRule import, remove method declarations.

3. **Ensure `_is_suppressed()` supports**:
   - Codes: `"W3001"`
   - Old kebab names: `"combine-has"` via LINT_ALIASES lookup
   - Categories: `"lint"` suppresses all W3xxx
   - `"all"` / `"default"` group semantics mapped to suppress/un-suppress sets

4. **Update config.jac** -- remove `LintRule` enum, remove `LintConfig`. `CheckConfig` keeps `lint: LintConfig` temporarily as deprecated alias OR replace with:

   ```jac
   obj CheckConfig {
       has print_errs: bool = True,
           suppress: list[str] = [],
           suppress_categories: list[str] = [];
   }
   ```

   Decide based on how much test/config breakage the full removal causes vs. a shim.

5. **Update config.impl.jac TOML parsing** -- `[check] suppress = [...]` is the new path. `[check.lint] select/ignore` can be mapped for backward compat if needed.

6. **Update tests** that reference LintRule, LintConfig, or the old config shape.

### Likely discoveries

- The auto-lint pass does more than just warn -- some rules also TRANSFORM the AST (auto-fix). The `is_rule_enabled` guard controls both the warning AND the fix. When replacing with `emit()`, the guard logic for the transform part still needs to exist. Solution: `emit()` returns bool (True if not suppressed) and the transform is gated on that return value.
- `jac.toml` files in the repo and tests use `[check.lint] select = [...]` syntax -- need backward compat or migration.

### Acceptance criteria

- `grep -r 'LintRule' jac/jaclang/` returns zero hits
- `grep -r 'is_rule_enabled' jac/jaclang/` returns zero hits
- `grep -r '_load_lint_config' jac/jaclang/` returns zero hits
- Lint tests pass
- Full test suite passes

### Commit

"Refactor: Replace LintRule enum with W3xxx diagnostic codes"

---

## Phase 6: LSP + CLI Polish

STATUS: DONE

> DEVIATION: Added `code` and `source` optional fields to `lsp/types.jac` Diagnostic class since they were missing from the minimal LSP types implementation.

### Goal

Wire diagnostic codes into LSP and improve CLI output formatting.

### Steps

1. **LSP**: Edit `jac/jaclang/langserve/impl/utils.impl.jac` `gen_diagnostics()`:
   - Set `code=error.code.code if error.code else None`
   - Set `source="jac"`
   - If `error.related` non-empty, populate `related_information` with `lspt.DiagnosticRelatedInformation`

2. **CLI check**: Edit `jac/jaclang/cli/impl/check_report.impl.jac`:
   - Use `e.pretty_print()` instead of `f"{e}"` for errors
   - Use `w.pretty_print()` instead of `f"{w}"` for warnings

3. **CLI run**: Verify `jac/jaclang/cli/commands/impl/execution.impl.jac` uses `pretty_print()` consistently for both errors and warnings.

### Acceptance criteria

- LSP diagnostic in VS Code shows `jac(E1001)` style codes
- `jac check` output shows `error[E1001]: ...` format
- Warnings in `jac check` show source context (not just one-line format)
- Full test suite passes

### Commit

"Feat: Populate LSP diagnostic codes and improve CLI error display"

---

## Phase 7: Cleanup Sweep

STATUS: DONE

> All legacy APIs verified removed: ParseError, LexerError, DiagnosticCallback, LintRule -- zero hits. LintConfig kept for backward compat (4 hits). log_error/log_warning only in Transform definitions + langserve LSP methods. 140 diagnostic codes registered. Full test suite: 2781 passed, 1 xfailed.

### Goal

Verify nothing legacy remains. Clean up imports. Final validation.

### Steps

1. Run these greps and fix any remaining hits:

   ```
   grep -r 'ParseError' jac/jaclang/       → should be zero
   grep -r 'LexerError' jac/jaclang/       → should be zero
   grep -r 'DiagnosticCallback' jac/jaclang/ → should be zero
   grep -r 'LintRule' jac/jaclang/          → should be zero
   grep -r 'LintConfig' jac/jaclang/        → should be zero (unless backward compat shim)
   ```

2. Verify `log_error`/`log_warning` only appear in Transform method definitions (kept as escape hatch for third-party plugins).

3. Remove any unused imports across all modified files.

4. Run full test suite one final time.

5. Count registered codes: `grep -c '_reg(' jac/jaclang/jac0core/diagnostics.jac`

### Acceptance criteria

- All greps clean
- Full test suite passes
- diagnostics.jac has codes covering every compiler diagnostic

### Commit

"Cleanup: Remove legacy error APIs and unused imports"

---

## Phase 8: Inline Suppression (Stretch Goal)

STATUS: DONE

### Goal

Support `# jac:ignore[CODE]` comments to suppress diagnostics on a per-line basis.

### Steps

1. During parsing, detect comments matching `# jac:ignore[...]` pattern. Extract code list.
2. Store line→suppressed_codes mapping on the Module node.
3. In `Transform.emit()`, before appending Alert, check if the node's line has a matching ignore.
4. Write tests:
   - `# jac:ignore[W2001]` suppresses undefined name warning
   - Wrong code in ignore → warning still fires
   - Multiple codes: `# jac:ignore[W2001, W2003]`

### Acceptance criteria

- Inline suppression works end-to-end
- Tests pass

### Commit

"Feat: Add inline # jac:ignore[CODE] suppression"

---

## Decision Log

Use this section to record major decisions made during implementation that deviate from or clarify the plan. The agent should append entries here as work proceeds.

| Phase | Decision | Rationale |
|-------|----------|-----------|
| 1 | All 139 diagnostic codes registered in diagnostics.jac with glob declarations | jac-format required `glob` prefix for module-level variables |
| 2 | Lexer keeps `self.error()` calls instead of `self.emit_diag()` | `lexer.na.jac` is used for native LLVM compilation; `DiagnosticInfo` is a Python class that can't be compiled to IR. Lexer errors still propagate to prog via improved `error()` implementation. |
| 2 | `prog` set dynamically on Lexer (`lexer.prog = prog`) rather than as a declared field | Native lexer can't have `object` type fields; Python side sets it dynamically via `hasattr` guard |
| 2 | `ParseError`/`LexerError` classes removed; `parse()` returns `(Module, bool)` | Errors propagate directly to `prog.errors_had` as `Alert` objects; callers check the bool flag |
| 2 | Parser diagnostic codes imported in head file `parser.jac` not just impl | jac0 doesn't merge impl file imports into head module namespace |
