# CPython oracle goldens for Band 6 deferrals + Band 7 pre-work

**Status:** generate-only pass complete; dumps promoted into
`jac-py/tools/oracle_goldens/`. Band 6 try/except/finally, raise-from, and multi-with
fixtures, plus Band 7 generator/async fixtures, are now covered in `compiler_slice.jac`.
**Generated:** 2026-08-21 session, via 6 parallel subagents. Zero jac runtime used
by the generators; promotion is additive files only.

## What this is

Pinned CPython 3.14.7 compile() goldens (`co_code` hex, `co_exceptiontable` hex,
`co_flags`, `co_stacksize`, full dis listing, decoded exception entries) for the
Band 6 deferral features and Band 7 generator/async pre-work.

Consumption pattern: when implementing a slice in `compiler_codegen.jac`, copy the
fixture's source + expected bytes from the relevant `goldens.json` into paired
tests in `compiler_slice.jac` (`compile_parsed_exec`) and
`layer9_product_exec.jac` (`product_exec`), asserting `exceptiontable` too when
non-empty (see `BAND6_SLICE_LEARNINGS.md` §2.1).

## Streams

| Dir under `jac-py/tools/oracle_goldens/` | Feature | Fixtures |
|---|---|---:|
| `b6_try_except_finally/` | try/except/finally combined | 8: normal, raised-caught, no-match-reraise, except-as+finally, return-in-try, raise-in-handler unwind, nested, break/continue in try-finally |
| `b6_bare_except_else/` | bare except, try/else | 8: bare handler, typed-then-bare chain, bare raise in handler, try/else normal, else-skipped-on-raise, except/else/finally combined, degenerate try, tuple-of-types handler |
| `b6_raise_from/` | raise ... from | 8: instance-from-instance, from None, from inside except, implicit chaining, bare raise, class-from, instance-from, from inside finally |
| `b6_multi_with/` | multi-item + bare with | 8: single-with baseline (matches §2.7), two-item both-as, mixed as/bare, bare with, three-item, nested with, with-inside-try |
| `b7_generators/` | yield / yield from | 10: minimal gen, yield+return, bare yield, yield from, yield-from-with-return-value, gen return value, yield-in-try-finally, yield-in-try-except, genexpr, non-gen control |
| `b7_async/` | async def / await | 9: minimal coroutine, await, await+return, async for, async with, await-in-try-except, async generator, async-gen yield+await, sync control |
| `b11_annotations/` | annotated assignments + PEP 695 type aliases | 10: module ann with value, module bare ann, class-body anns, function-local ann (with/bare), attr target, subscript target, simple TypeAlias, parametrized TypeAlias, plain-assign control |

Each dir contains:

- `dump.py` - self-contained deterministic printer (rerun to regenerate)
- `goldens.json` - machine-readable records (paste source from here)
- `goldens.md` - human-readable dump
- `SUMMARY.md` - per-stream agent report
- `paste_ready.json` - compact source + `co_code_hex` / `co_exceptiontable_hex` for pasting into slice tests
- `INDEX.md` - fixture size table

## Key facts captured

### Flags (CPython 3.14.7)

| Flag | Value | Note |
|---|---|---|
| CO_GENERATOR | 0x20 | generator fns carry flags `0x23` (OPTIMIZED\|NEWLOCALS\|GENERATOR) |
| CO_COROUTINE | 0x80 | async def |
| CO_ITERABLE_COROUTINE | 0x100 | |
| CO_ASYNC_GENERATOR | 0x200 | async def + yield |

### Band 6 deferrals

- Explicit cause (`raise E from cause`) and suppression (`from None`) both emit
  `RAISE_VARARGS 2`; bare re-raise is `RAISE_VARARGS 0`.
- Multi-item `with`: exception-table entries nest per item - 1 item = 2 entries,
  2 items = 6, 3 items = 10. Suppression fixture is byte-identical to plain
  single-with (suppression is runtime-only).
- Degenerate `try:` without except/finally is a SyntaxError:
  `"expected 'except' or 'finally' block (<filename>, line N)"`.
- Typed-then-bare handler chain: bare `except:` lands after the CHECK_EXC_MATCH
  chain as unconditional handler entry.

### Band 7 opcode inventory observed

`RETURN_GENERATOR`, `RESUME`, `YIELD_VALUE`, `SEND`, `END_SEND`,
`GET_AWAITABLE`, `CLEANUP_THROW`, `GET_AITER`, `GET_ANEXT`, `END_ASYNC_FOR`.
3.14 emits `LOAD_SPECIAL` for async context-manager enter/exit - there is **no
BEFORE_ASYNC_WITH** on this build.

Generators/coroutines that close over state will need `co_cellvars` /
`co_freevars` handling (recorded per fixture in goldens.json).

## Caveats

- Bytes are CPython-minor-specific: valid against the repo venv's 3.14.7 only.
  Re-run `dump.py` if the venv bumps Python minor versions.
- Static compile goldens only - they do not validate VM runtime behavior
  (exception chaining, **exit** suppression, generator resume are runtime).
- Canonical copies live under `jac-py/tools/oracle_goldens/`. Regenerate a stream
  with `.venv/bin/python jac-py/tools/oracle_goldens/<stream>/dump.py` if the
  venv's CPython minor changes. Do not edit `compiler_codegen.jac` /
  `compiler_slice.jac` / facade/libtest files from this tree without coordinating
  with whoever currently owns those dirty paths.
