# Band 7 generator oracle dump - completion summary

## Deliverables

- `/tmp/oracle_goldens/b7_generators/dump.py`
  - Standalone CPython 3.14.7 host compiler dumper.
  - Recursively walks nested `CodeType` values in `co_consts`.
  - Emits flags, bytecode, exception tables, locals/cells/freevars, complete instruction records, and decoded exception entries.
  - Uses `compile(..., dont_inherit=True)` so the dumper's own future imports cannot contaminate oracle flags.
- `/tmp/oracle_goldens/b7_generators/goldens.json`
  - Machine-readable output for all 10 requested fixtures.
- `/tmp/oracle_goldens/b7_generators/goldens.md`
  - Human-readable output with source, hex values, disassembly, and exception entries.

## Fixtures and concrete results

| Fixture | Code objects | Generator result |
|---|---:|---|
| `simplest_generator` | 1 | `g`, flags `0x23`, `CO_GENERATOR` |
| `yield_value_then_return` | 1 | `g`, flags `0x23`, `CO_GENERATOR` |
| `bare_yield` | 1 | `g`, flags `0x23`, `CO_GENERATOR` |
| `yield_from_iterable` | 1 | `g`, flags `0x23`, `CO_GENERATOR` |
| `yield_from_return_value` | 2 | `inner` and `g`, both flags `0x23`, `CO_GENERATOR` |
| `generator_return_value` | 1 | `g`, flags `0x23`, `CO_GENERATOR` |
| `yield_inside_try_finally` | 1 | `g`, flags `0x23`, `CO_GENERATOR`, exception table present |
| `yield_inside_try_except` | 1 | `g`, flags `0x23`, `CO_GENERATOR`, exception table present |
| `generator_expression` | 1 | `<genexpr>`, flags `0x23`, `CO_GENERATOR` |
| `non_generator_control` | 1 | `g`, flags `0x3`, no generator-family flag |

## Exact CPython 3.14.7 flag values

- `inspect.CO_GENERATOR = 32 = 0x20`
- `inspect.CO_COROUTINE = 128 = 0x80`
- `inspect.CO_ITERABLE_COROUTINE = 256 = 0x100`
- `inspect.CO_ASYNC_GENERATOR = 512 = 0x200`
- Generator functions have `co_flags = 0x23` (`CO_OPTIMIZED | CO_NEWLOCALS | CO_GENERATOR`).
- The non-generator control function has `co_flags = 0x3` (`CO_OPTIMIZED | CO_NEWLOCALS`).
- No fixture sets `CO_COROUTINE`, `CO_ITERABLE_COROUTINE`, or `CO_ASYNC_GENERATOR`.

Python 3.14.7 exposes these `CO_*` constants through `inspect`; `dis` has no `CO_*` attributes on this interpreter. The JSON therefore records the canonical `inspect` values and named breakdown.

## Validation

- `dump.py` ran successfully and generated all 10 fixtures.
- JSON parsed with `json.loads` and `python -m json.tool`.
- Fresh `compile(source, ..., dont_inherit=True)` comparison passed for every emitted code object's `co_flags`, `co_code`, and `co_exceptiontable`.
- Two consecutive dump runs produced identical output hashes:
  - `goldens.json`: `e618f2df264f463e10e7fe5214971af973cc04421413b70e921d08e00848b4d9`
  - `goldens.md`: `142b758c80851bddda5f2eac8e0d5d674970e2c44baeb9d9a4d786fe8c1807c7`
- No Jac runtime, compiler loop, or repository file was used or modified.

## Review findings

- **Info:** `co_code`, exception tables, and flags are CPython-minor-version-specific; consume these goldens only with the stated CPython 3.14.7 oracle.
- **Info:** The requested `/home/jac/repos/jac-python/context.md` and `plan.md` were not present. This did not block the explicitly specified dump task.
- **Blockers:** none.

## Residual risks

- A different CPython 3.14 patch build may emit different bytecode or exception-table bytes.
- These are static compile goldens only; they do not execute generator iteration or validate VM runtime behavior.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Concrete CPython 3.14.7 findings and severity notes are recorded above; dump.py, goldens.md, and goldens.json exist under /tmp/oracle_goldens/b7_generators/."
    }
  ],
  "changedFiles": [
    "/tmp/oracle_goldens/b7_generators/dump.py",
    "/tmp/oracle_goldens/b7_generators/goldens.md",
    "/tmp/oracle_goldens/b7_generators/goldens.json",
    "/tmp/oracle_goldens/b7_generators/SUMMARY.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "/home/jac/repos/jac-python/.venv/bin/python dump.py",
      "result": "passed",
      "summary": "Generated all 10 fixtures."
    },
    {
      "command": "JSON parse and fresh compile comparison",
      "result": "passed",
      "summary": "All emitted flags, co_code, and exception tables matched fresh CPython compilation."
    },
    {
      "command": "python3 -m json.tool goldens.json",
      "result": "passed",
      "summary": "Machine-readable golden output is valid JSON."
    },
    {
      "command": "Two consecutive dump runs with SHA-256 comparison",
      "result": "passed",
      "summary": "goldens.json and goldens.md are reproducible."
    }
  ],
  "validationOutput": [
    "10 requested fixtures generated.",
    "Generator functions and generator expressions use co_flags 0x23.",
    "Non-generator comparison uses co_flags 0x3.",
    "CO_GENERATOR=0x20, CO_COROUTINE=0x80, CO_ITERABLE_COROUTINE=0x100, CO_ASYNC_GENERATOR=0x200."
  ],
  "residualRisks": [
    "Bytecode and exception-table bytes are specific to CPython 3.14.7.",
    "Static compilation was validated; runtime generator iteration was not exercised."
  ],
  "noStagedFiles": true,
  "diffSummary": "Added isolated generator oracle dumper plus Markdown and JSON goldens; no repository files changed.",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "The supplied context.md and plan.md paths did not exist. The dumper uses dont_inherit=True to prevent its own future annotations import from changing oracle co_flags."
}
```
