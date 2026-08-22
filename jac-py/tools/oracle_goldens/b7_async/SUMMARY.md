# Band 7 async/coroutine oracle summary

Generated with `/home/jac/repos/jac-python/.venv/bin/python` (CPython 3.14.7).
No Jac runtime, compiler, tests, or repository files were used or modified.

## Artifacts

- `dump.py` - reproducible host `compile()`/`dis` generator.
- `goldens.json` - machine-readable records for 9 fixtures.
- `goldens.md` - readable source, flags, bytecode, disassembly, and exception tables.

Each fixture includes recursive code-object extraction, `co_flags` and named flags,
stack size, code/exception-table hex, variable/cell/free names, full instruction
records, and decoded exception entries.

Fixtures cover minimal coroutine, await, await+return, async-for, async-with,
await in try/except, async generator yield, async generator yield+await, and a
sync control comparison.

Observed flags include `CO_COROUTINE=0x80` and `CO_ASYNC_GENERATOR=0x200`.
Observed async protocol opcodes include `RETURN_GENERATOR`, `RESUME`,
`GET_AWAITABLE`, `SEND`, `END_SEND`, `CLEANUP_THROW`, `GET_AITER`, `GET_ANEXT`,
`END_ASYNC_FOR`, and `YIELD_VALUE`. CPython 3.14.7 emits `LOAD_SPECIAL` for
async context-manager enter/exit in this fixture; no `BEFORE_ASYNC_WITH` is
present.

## Validation

- Script executed successfully with the mandated interpreter.
- JSON parsed with `python -m json.tool`.
- Required fixture, flag, opcode, bytecode, and exception-table assertions passed.
- Two consecutive generations were byte-for-byte identical.
- Repository status was unchanged; no staged files.
- Supplied `/home/jac/repos/jac-python/context.md` and `plan.md` were absent.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Created only isolated host-compile oracle artifacts under /tmp/oracle_goldens/b7_async; no Jac/compiler files changed."
    }
  ],
  "changedFiles": [
    "/tmp/oracle_goldens/b7_async/dump.py",
    "/tmp/oracle_goldens/b7_async/goldens.md",
    "/tmp/oracle_goldens/b7_async/goldens.json",
    "/tmp/oracle_goldens/b7_async/SUMMARY.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python --version",
      "result": "passed",
      "summary": "Python 3.14.7"
    },
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python /tmp/oracle_goldens/b7_async/dump.py",
      "result": "passed",
      "summary": "Generated all 9 fixtures"
    },
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python -m json.tool /tmp/oracle_goldens/b7_async/goldens.json",
      "result": "passed",
      "summary": "JSON parses successfully"
    },
    {
      "command": "Python fixture/flag/opcode assertions",
      "result": "passed",
      "summary": "All requested fixture and protocol checks passed"
    },
    {
      "command": "Run dump twice and cmp goldens.json/goldens.md",
      "result": "passed",
      "summary": "Outputs are byte-for-byte deterministic"
    },
    {
      "command": "git diff --cached --quiet",
      "result": "passed",
      "summary": "No staged repository files"
    }
  ],
  "validationOutput": [
    "9 fixtures present and JSON-valid",
    "CO_COROUTINE and CO_ASYNC_GENERATOR flags confirmed",
    "Async await, async-for, async-with, and async-generator opcode patterns confirmed",
    "Only dump.py, goldens.md, goldens.json, and SUMMARY.md exist in the output directory"
  ],
  "residualRisks": [
    "Goldens are specific to CPython 3.14.7 host bytecode conventions"
  ],
  "noStagedFiles": true,
  "diffSummary": "Added reproducible CPython async/coroutine oracle generator and 9-fixture JSON/Markdown goldens in the isolated output directory.",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "The supplied context.md and plan.md files did not exist. Async-with uses LOAD_SPECIAL in the observed CPython 3.14.7 output rather than BEFORE_ASYNC_WITH."
}
```
