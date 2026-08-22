#!/home/jac/repos/jac-python/.venv/bin/python
"""Generate CPython 3.14 async/coroutine oracle goldens.

This script intentionally uses only host compile()/disassembly.  It writes
 goldens.json and goldens.md next to itself and prints a short completion line.
"""
from __future__ import annotations

import dis
import inspect
import json
import re
import textwrap
from pathlib import Path
from types import CodeType
from typing import Any

OUT = Path(__file__).resolve().parent

FIXTURES: list[tuple[str, str]] = [
    (
        "minimal_async_pass",
        """\
async def f():
    pass
""",
    ),
    (
        "await_expr",
        """\
async def f(awaitable):
    await awaitable
""",
    ),
    (
        "await_and_return",
        """\
async def f(awaitable):
    result = await awaitable
    return result
""",
    ),
    (
        "async_for_loop",
        """\
async def f(it):
    total = 0
    async for x in it:
        total += x
    return total
""",
    ),
    (
        "async_with",
        """\
async def f(expr):
    async with expr as y:
        return y
""",
    ),
    (
        "await_in_try_except",
        """\
async def f(awaitable):
    try:
        return await awaitable
    except ValueError:
        return 0
""",
    ),
    (
        "async_generator_yield",
        """\
async def f(value):
    yield value
""",
    ),
    (
        "async_generator_yield_and_await",
        """\
async def f(awaitable, value):
    yield value
    result = await awaitable
    yield result
""",
    ),
    (
        "sync_control_comparison",
        """\
def f(value):
    return value
""",
    ),
]


def code_objects_recursive(root: CodeType) -> list[CodeType]:
    """Return every nested code object, recursively, in co_consts order."""
    found: list[CodeType] = []

    def visit(code: CodeType) -> None:
        found.append(code)
        for const in code.co_consts:
            if isinstance(const, CodeType):
                visit(const)

    visit(root)
    return found


def stable_repr(value: Any) -> str:
    """Remove process-address noise from dis's nested-code reprs."""
    return re.sub(r"0x[0-9a-fA-F]+", "0xADDR", repr(value))


def stable_argrepr(value: str) -> str:
    return re.sub(r"0x[0-9a-fA-F]+", "0xADDR", value)


def instruction_record(inst: dis.Instruction) -> dict[str, Any]:
    positions = inst.positions
    return {
        "offset": inst.offset,
        "opcode": inst.opcode,
        "opname": inst.opname,
        "arg": inst.arg,
        "argval": stable_repr(inst.argval),
        "argrepr": stable_argrepr(inst.argrepr),
        "starts_line": inst.starts_line,
        "is_jump_target": inst.is_jump_target,
        "positions": {
            "lineno": positions.lineno,
            "end_lineno": positions.end_lineno,
            "col_offset": positions.col_offset,
            "end_col_offset": positions.end_col_offset,
        },
    }


def exception_record(entry: Any) -> dict[str, Any]:
    return {
        "start": entry.start,
        "end": entry.end,
        "target": entry.target,
        "depth": entry.depth,
        "lasti": entry.lasti,
    }


def flag_constants() -> dict[str, int]:
    return {
        name: value
        for name, value in sorted(vars(inspect).items())
        if name.startswith("CO_") and isinstance(value, int)
    }


FLAGS = flag_constants()


def code_record(code: CodeType) -> dict[str, Any]:
    entries = list(dis.Bytecode(code).exception_entries)
    instructions = list(dis.get_instructions(code, show_caches=True))
    set_flags = [name for name, value in FLAGS.items() if code.co_flags & value]
    return {
        "name": code.co_name,
        "qualname": code.co_qualname,
        "filename": code.co_filename,
        "firstlineno": code.co_firstlineno,
        "co_flags": hex(code.co_flags),
        "co_flags_int": code.co_flags,
        "co_flags_set": set_flags,
        "co_flag_values": {name: hex(value) for name, value in FLAGS.items()},
        "co_stacksize": code.co_stacksize,
        "co_code": code.co_code.hex(),
        "co_exceptiontable": code.co_exceptiontable.hex(),
        "co_varnames": list(code.co_varnames),
        "co_cellvars": list(code.co_cellvars),
        "co_freevars": list(code.co_freevars),
        "instructions": [instruction_record(inst) for inst in instructions],
        "exception_entries": [exception_record(entry) for entry in entries],
    }


def fixture_record(name: str, source: str) -> dict[str, Any]:
    source = textwrap.dedent(source)
    module = compile(source, f"<{name}>", "exec")
    all_codes = code_objects_recursive(module)
    function_codes = [code for code in all_codes if code.co_name == "f"]
    if len(function_codes) != 1:
        raise AssertionError(f"{name}: expected one function f, got {len(function_codes)}")
    return {
        "name": name,
        "source": source,
        "code_objects": [code_record(code) for code in all_codes],
        "function_code_index": all_codes.index(function_codes[0]),
    }


def dis_line(inst: dict[str, Any]) -> str:
    arg = "" if inst["arg"] is None else f" {inst['arg']}"
    target = " >>" if inst["is_jump_target"] else "   "
    return f"{inst['offset']:>4}{target} {inst['opname']:<24}{arg:<5} {inst['argrepr']}"


def render_markdown(data: dict[str, Any]) -> str:
    lines: list[str] = [
        "# Band 7 async/coroutine CPython 3.14.7 goldens",
        "",
        "Generated by `dump.py` with `/home/jac/repos/jac-python/.venv/bin/python`.",
        "All byte strings below are hexadecimal `co_code` or `co_exceptiontable`.",
        "",
        "## Coroutine-specific opcode notes",
        "",
        "- `RETURN_GENERATOR` initializes a suspended coroutine/generator frame.",
        "- `RESUME` marks entry/resumption points; its argument distinguishes resume states.",
        "- `GET_AWAITABLE` converts an await operand to an awaitable iterator.",
        "- `SEND` drives the awaitable; its jump argument targets the suspended/completed path.",
        "- `END_SEND` closes the send/await protocol after completion.",
        "- `CLEANUP_THROW` handles an exception thrown into an interrupted await.",
        "- Async iteration uses `GET_AITER`, `GET_ANEXT`, `SEND`, and `END_SEND`.",
        "- In CPython 3.14.7, async context managers here use `LOAD_SPECIAL` for `__aenter__`/`__aexit__`, then `GET_AWAITABLE`, `SEND`, and `END_SEND` (no `BEFORE_ASYNC_WITH`).",
        "- Exact argument values and exception-region boundaries are fixture-specific; use the structured JSON for machine consumption.",
        "",
        "## Flag constants observed",
        "",
    ]
    for name, value in FLAGS.items():
        lines.append(f"- `{name}` = `{hex(value)}`")
    lines.append("")

    for fixture in data["fixtures"]:
        lines.extend([f"## {fixture['name']}", "", "### Source", "", "```python", fixture["source"].rstrip(), "```", ""])
        for index, code in enumerate(fixture["code_objects"]):
            role = "module" if index == 0 else ("target function" if index == fixture["function_code_index"] else "nested")
            lines.extend(
                [
                    f"### Code object {index} ({role}): `{code['qualname']}`",
                    "",
                    f"- `co_flags`: `{code['co_flags']}`; set: `{', '.join(code['co_flags_set']) or '(none)'}`",
                    f"- `co_stacksize`: `{code['co_stacksize']}`",
                    f"- `co_code.hex()`: `{code['co_code']}`",
                    f"- `co_exceptiontable.hex()`: `{code['co_exceptiontable']}`",
                    f"- `co_varnames`: `{code['co_varnames']}`",
                    f"- `co_cellvars`: `{code['co_cellvars']}`",
                    f"- `co_freevars`: `{code['co_freevars']}`",
                    "",
                    "#### Disassembly",
                    "",
                    "```text",
                ]
            )
            lines.extend(dis_line(inst) for inst in code["instructions"])
            lines.extend(["```", "", "#### Decoded exception entries", "", "```text"])
            if code["exception_entries"]:
                lines.extend(
                    f"start={entry['start']} end={entry['end']} target={entry['target']} depth={entry['depth']} lasti={entry['lasti']}"
                    for entry in code["exception_entries"]
                )
            else:
                lines.append("(none)")
            lines.extend(["```", ""])
    return "\n".join(lines)


def main() -> None:
    data = {
        "interpreter": "/home/jac/repos/jac-python/.venv/bin/python",
        "python_version": __import__("sys").version,
        "fixtures": [fixture_record(name, source) for name, source in FIXTURES],
    }
    (OUT / "goldens.json").write_text(json.dumps(data, indent=2, sort_keys=False) + "\n")
    (OUT / "goldens.md").write_text(render_markdown(data))
    print(f"wrote {len(data['fixtures'])} fixtures to {OUT}")


if __name__ == "__main__":
    main()
