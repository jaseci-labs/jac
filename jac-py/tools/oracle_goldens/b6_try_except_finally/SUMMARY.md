# Summary: Band 6 combined try/except/finally oracle goldens

Implemented the requested generate-only CPython oracle stream under `/tmp/oracle_goldens/b6_try_except_finally/`.

## Changed files

- `dump.py` - deterministic CPython 3.14.7 dumper using `compile(..., '<f>', 'exec')`, recursive code-object discovery, cache-aware `dis.get_instructions(..., show_caches=True)`, and decoded exception entries.
- `goldens.json` - machine-readable output.
- `goldens.md` - readable output with source, flags, stack size, bytecode hex, exception-table hex, instructions, and exception entries.

Fixtures included:

1. normal try/except/finally
2. raised-and-caught try/except/finally
3. unmatched exception re-raised through finally
4. except-as binding with finally
5. return from try with finally
6. exception raised inside handler with finally
7. nested try/except/finally
8. try/finally loop break and continue

## Validation

- CPython interpreter: `/home/jac/repos/jac-python/.venv/bin/python` → `3.14.7`
- `dump.py --write` passed.
- `dump.py` stdout parsed successfully with `python -m json.tool`.
- `goldens.json` parsed successfully with `python -m json.tool`.
- Structural checks passed for all 8 fixture names, bytecode, cache-aware instruction fields, and exception-entry fields.
- Repeated generation produced byte-for-byte identical `goldens.json` and `goldens.md`.
- `git diff --cached --quiet` passed; no staged repository files.
- No files under `/home/jac/repos/jac-python` were modified by this task.

## Context note

The requested `/home/jac/repos/jac-python/context.md` and `plan.md` files were not present; generation proceeded from the explicit task contract.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Created only the three requested oracle artifacts under /tmp/oracle_goldens/b6_try_except_finally; no repository files were modified."
    }
  ],
  "changedFiles": [
    "/tmp/oracle_goldens/b6_try_except_finally/dump.py",
    "/tmp/oracle_goldens/b6_try_except_finally/goldens.md",
    "/tmp/oracle_goldens/b6_try_except_finally/goldens.json",
    "/tmp/oracle_goldens/b6_try_except_finally/SUMMARY.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python dump.py --write",
      "result": "passed",
      "summary": "Generated deterministic Markdown and JSON goldens for 8 fixtures."
    },
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python -m json.tool goldens.json",
      "result": "passed",
      "summary": "Machine-readable golden output parses successfully."
    },
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python dump.py | python -m json.tool",
      "result": "passed",
      "summary": "Self-contained printer emits valid JSON on stdout."
    },
    {
      "command": "repeat dump and cmp goldens.json/goldens.md",
      "result": "passed",
      "summary": "Outputs are byte-for-byte deterministic."
    },
    {
      "command": "git diff --cached --quiet",
      "result": "passed",
      "summary": "No staged repository files."
    }
  ],
  "validationOutput": [
    "8 expected fixture names validated.",
    "Every fixture has co_flags, co_stacksize, co_code, co_exceptiontable, cache-aware instructions, and decoded exception entries."
  ],
  "residualRisks": [],
  "noStagedFiles": true,
  "diffSummary": "Added isolated CPython 3.14.7 oracle generator and generated JSON/Markdown goldens; repository remains untouched.",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "The supplied context.md and plan.md paths did not exist. Existing repository worktree modifications were pre-existing and left unchanged."
}
```
