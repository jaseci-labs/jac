# Band 6 multi-item and bare `with` oracle summary

Generated with `/home/jac/repos/jac-python/.venv/bin/python` (CPython 3.14.7).

## Outputs

- `dump.py` - standalone deterministic generator; recursively walks `co_consts` to find function `f`.
- `goldens.md` - readable source, metadata, full disassembly, and decoded exception entries.
- `goldens.json` - machine-readable equivalent.

## Fixtures

| Fixture | `co_stacksize` | Exception entries |
|---|---:|---:|
| `single_with_as` | 7 | 2 |
| `two_with_as` | 9 | 6 |
| `two_first_as_second_bare` | 9 | 6 |
| `single_with_bare` | 7 | 2 |
| `three_with_as` | 11 | 10 |
| `nested_with` | 9 | 6 |
| `with_inside_try_except` | 7 | 8 |
| `with_exit_suppresses` | 7 | 2 |

All fixtures have non-empty `co_exceptiontable` values. Multi-item lowering adds nested per-item handler regions. The nested-statement fixture and two-item fixture have the same static bytecode shape in CPython 3.14. The suppression fixture is byte-identical to `single_with_as`; runtime `__exit__` behavior is not executed by this dump.

## Acceptance report

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Created only the requested isolated CPython oracle artifacts under /tmp/oracle_goldens/b6_multi_with; no Jac compiler or runtime files were modified."
    }
  ],
  "changedFiles": [
    "/tmp/oracle_goldens/b6_multi_with/dump.py",
    "/tmp/oracle_goldens/b6_multi_with/goldens.md",
    "/tmp/oracle_goldens/b6_multi_with/goldens.json",
    "/tmp/oracle_goldens/b6_multi_with/SUMMARY.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python --version",
      "result": "passed",
      "summary": "Python 3.14.7"
    },
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python /tmp/oracle_goldens/b6_multi_with/dump.py",
      "result": "passed",
      "summary": "Generated all 8 fixtures and 42 exception entries."
    },
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python - <<'PY' ... json.loads(...) ... PY",
      "result": "passed",
      "summary": "Parsed JSON; verified fixture names, instruction lists, and exception boundaries."
    },
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python - <<'PY' ... suppression equivalence ... PY",
      "result": "passed",
      "summary": "Verified suppression fixture matches baseline co_code, exceptiontable, and stacksize."
    },
    {
      "command": "git diff --cached --quiet",
      "result": "passed",
      "summary": "No staged files."
    }
  ],
  "validationOutput": [
    "8 fixtures generated",
    "42 decoded exception-table entries",
    "All exception entries satisfy start < end and have valid targets",
    "goldens.json parses successfully",
    "single_with_as and with_exit_suppresses are byte-identical"
  ],
  "residualRisks": [
    "These are static compile-time goldens; context-manager runtime suppression is intentionally not executed."
  ],
  "noStagedFiles": true,
  "diffSummary": "Added an isolated CPython 3.14.7 dump generator plus Markdown and JSON goldens for eight multi-item, bare, nested, and try/except with fixtures.",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "The supplied context.md and plan.md paths did not exist. No files under /home/jac/repos/jac-python were modified."
}
```
