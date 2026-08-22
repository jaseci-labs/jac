# Band 6 bare-except / try-else oracle dump

Implemented the requested host-only CPython 3.14.7 oracle fixtures. No files under `/home/jac/repos/jac-python` were modified.

## Changed files

- `/tmp/oracle_goldens/b6_bare_except_else/dump.py`
  - Deterministic compiler/disassembler printer.
  - Recursively walks `co_consts` code objects.
  - Emits JSON and Markdown artifacts.
- `/tmp/oracle_goldens/b6_bare_except_else/goldens.json`
  - Eight fixture records with source, flags, stack size, bytecode hex, exception-table hex, complete instruction records, and decoded exception entries.
- `/tmp/oracle_goldens/b6_bare_except_else/goldens.md`
  - Human-readable source, bytecode, disassembly, and exception-entry goldens.

## Fixtures

1. Bare `except:` body.
2. Typed handler followed by bare handler.
3. Bare handler with bare `raise`.
4. `try`/`else` normal path.
5. `try`/`except`/`else` with raised exception.
6. `try`/`except`/`else`/`finally`.
7. Degenerate try without `except` or `finally`.
8. Tuple-of-types `except (...) as e`.

The degenerate form records this exact CPython message:

```text
expected 'except' or 'finally' block (<try_without_except_or_finally>, line 3)
```

## Validation

- Required venv interpreter: CPython 3.14.7.
- `dump.py` ran successfully.
- `python -m json.tool goldens.json` passed.
- Required-field and exact-SyntaxError assertions passed.
- Two consecutive runs produced identical JSON, Markdown, and stdout hashes/content.
- `git diff --cached --quiet` passed; no staged files.

## Acceptance report

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Created only the requested oracle artifacts under /tmp/oracle_goldens/b6_bare_except_else; no repository files were modified."
    }
  ],
  "changedFiles": [
    "/tmp/oracle_goldens/b6_bare_except_else/dump.py",
    "/tmp/oracle_goldens/b6_bare_except_else/goldens.md",
    "/tmp/oracle_goldens/b6_bare_except_else/goldens.json",
    "/tmp/oracle_goldens/b6_bare_except_else/SUMMARY.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python dump.py",
      "result": "passed",
      "summary": "Generated deterministic JSON, Markdown, and stdout oracle dumps."
    },
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python -m json.tool goldens.json",
      "result": "passed",
      "summary": "Generated JSON parses successfully."
    },
    {
      "command": "venv Python schema and exact SyntaxError assertion script",
      "result": "passed",
      "summary": "Eight fixtures and required fields validated; exact degenerate-try message matched."
    },
    {
      "command": "git diff --cached --quiet",
      "result": "passed",
      "summary": "No staged files."
    }
  ],
  "validationOutput": [
    "7 compilable fixtures contain function bytecode and decoded exception entries.",
    "1 degenerate fixture captures SyntaxError exactly.",
    "Repeated generation is byte-for-byte deterministic."
  ],
  "residualRisks": [
    "Goldens reflect CPython 3.14.7 only."
  ],
  "noStagedFiles": true,
  "diffSummary": "Added isolated CPython oracle generator and generated artifacts for bare except, try/else, degenerate try, and tuple handlers.",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "The requested context.md and plan.md were absent; BAND6_SLICE_LEARNINGS.md was read successfully."
}
```
