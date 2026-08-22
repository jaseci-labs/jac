# Band 6 `raise ... from` oracle summary

## Scope

Generated with `/home/jac/repos/jac-python/.venv/bin/python` (CPython 3.14.7).
No Jac runtime was used. No file under `/home/jac/repos/jac-python` was modified.
The requested `/home/jac/repos/jac-python/context.md` and `plan.md` were not present;
`jac-py/BAND6_SLICE_LEARNINGS.md` was available and confirms these forms are deferred.

## Artifacts

- `dump.py` - deterministic host `compile()`/`dis` generator; recursively extracts function `f`.
- `goldens.json` - machine-readable records.
- `goldens.md` - source, flags, stack size, code/exception-table hex, disassembly, and decoded exception entries.

## Fixture results

All nested function code objects have `co_flags=0x1000003` and no
`LOAD_ASSERTION_ERROR`-like opcode.

| Fixture | Stack | `co_code` bytes | `co_exceptiontable.hex()` |
|---|---:|---:|---|
| `top_level_raise_instance_from_instance` | 4 | 44 | empty |
| `raise_instance_from_none` | 3 | 26 | empty |
| `raise_from_inside_except_explicit_cause` | 5 | 98 | `820b0d008d212e03` |
| `implicit_chaining_inside_except` | 4 | 78 | `820b0d008d172403` |
| `bare_raise_inside_except` | 4 | 58 | `820b0d008d0d1a03` |
| `raise_class_from_err` | 2 | 16 | empty |
| `raise_instance_from_err` | 3 | 26 | empty |
| `raise_from_inside_finally` | 6 | 100 | `8202190099162f03` |

The explicit cause and `None` suppression forms use `RAISE_VARARGS 2`.
The bare raise uses `RAISE_VARARGS 0`; class/instance distinction is visible in
load/call instructions before `RAISE_VARARGS`.

## Validation

- `dump.py` ran successfully with the pinned interpreter.
- `python -m py_compile dump.py` passed.
- `python -m json.tool goldens.json` passed.
- Schema validation found 8 fixtures, each with required bytecode, disassembly,
  and exception-entry fields.
- Two independent runs produced byte-identical `goldens.json` and `goldens.md`.
- `git diff --cached --quiet` passed; no staged repository files.

## Acceptance evidence

- Changed files: the three requested files in this directory only.
- Tests added/updated: none; this is a pure oracle-generation artifact.
- Residual risk: these are static CPython goldens and do not validate native Jac
  code generation; exception behavior remains runtime-only beyond the recorded
  bytecode shape.
