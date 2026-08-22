#!/home/jac/repos/jac-python/.venv/bin/python
"""Generate deterministic CPython 3.14 generator-code goldens.

This file is intentionally standalone and uses only the host Python compiler.
It does not import or execute Jac code.
"""
from __future__ import annotations

import dis
import inspect
import json
from pathlib import Path
from types import CodeType

OUT = Path(__file__).resolve().parent

FIXTURES: list[tuple[str, str]] = [
    (
        "simplest_generator",
        "def g():\n    yield 1\n",
    ),
    (
        "yield_value_then_return",
        "def g():\n    yield 1\n    return\n",
    ),
    (
        "bare_yield",
        "def g():\n    yield\n",
    ),
    (
        "yield_from_iterable",
        "def g():\n    yield from [1, 2, 3]\n",
    ),
    (
        "yield_from_return_value",
        "def inner():\n    return 7\n    yield\n\ndef g():\n    x = yield from inner()\n    yield x\n",
    ),
    (
        "generator_return_value",
        "def g():\n    yield 1\n    return 42\n",
    ),
    (
        "yield_inside_try_finally",
        "def g():\n    try:\n        yield 1\n    finally:\n        cleanup = 2\n",
    ),
    (
        "yield_inside_try_except",
        "def g():\n    try:\n        yield 1\n    except ValueError:\n        yield 2\n",
    ),
    (
        "generator_expression",
        "gen = (x * 2 for x in range(3))\n",
    ),
    (
        "non_generator_control",
        "def g():\n    return 1\n",
    ),
]

# inspect exposes the canonical flag names on CPython.  Keep the explicit
# 0x-values in the output because these are the values consumed by the Jac
# compiler work, and include every coroutine-family bit even when absent.
FLAG_NAMES: list[tuple[str, int]] = [
    ("CO_GENERATOR", inspect.CO_GENERATOR),
    ("CO_COROUTINE", inspect.CO_COROUTINE),
    ("CO_ITERABLE_COROUTINE", inspect.CO_ITERABLE_COROUTINE),
    ("CO_ASYNC_GENERATOR", inspect.CO_ASYNC_GENERATOR),
    ("CO_OPTIMIZED", inspect.CO_OPTIMIZED),
    ("CO_NEWLOCALS", inspect.CO_NEWLOCALS),
    ("CO_VARARGS", inspect.CO_VARARGS),
    ("CO_VARKEYWORDS", inspect.CO_VARKEYWORDS),
    ("CO_NESTED", inspect.CO_NESTED),
    ("CO_NOFREE", inspect.CO_NOFREE),
    ("CO_HAS_DOCSTRING", inspect.CO_HAS_DOCSTRING),
]


def walk_code(code: CodeType, path: str = "module") -> list[tuple[str, CodeType]]:
    """Return code and all descendant code objects in co_consts order."""
    result: list[tuple[str, CodeType]] = []
    for index, const in enumerate(code.co_consts):
        if isinstance(const, CodeType):
            child_path = f"{path}.co_consts[{index}]<{const.co_name}>"
            result.append((child_path, const))
            result.extend(walk_code(const, child_path))
    return result


def flag_data(flags: int) -> dict[str, object]:
    named = {name: bool(flags & value) for name, value in FLAG_NAMES}
    return {
        "hex": f"0x{flags:x}",
        "decimal": flags,
        "named": named,
        "coroutine_family": {
            "CO_GENERATOR": {"value": inspect.CO_GENERATOR, "hex": f"0x{inspect.CO_GENERATOR:x}", "set": bool(flags & inspect.CO_GENERATOR)},
            "CO_COROUTINE": {"value": inspect.CO_COROUTINE, "hex": f"0x{inspect.CO_COROUTINE:x}", "set": bool(flags & inspect.CO_COROUTINE)},
            "CO_ITERABLE_COROUTINE": {"value": inspect.CO_ITERABLE_COROUTINE, "hex": f"0x{inspect.CO_ITERABLE_COROUTINE:x}", "set": bool(flags & inspect.CO_ITERABLE_COROUTINE)},
            "CO_ASYNC_GENERATOR": {"value": inspect.CO_ASYNC_GENERATOR, "hex": f"0x{inspect.CO_ASYNC_GENERATOR:x}", "set": bool(flags & inspect.CO_ASYNC_GENERATOR)},
        },
    }


def stable_repr(value: object) -> str:
    if isinstance(value, CodeType):
        return f"<code object {value.co_name}>"
    return repr(value)


def instruction_data(code: CodeType) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for inst in dis.get_instructions(code, show_caches=True, adaptive=False):
        result.append(
            {
                "offset": inst.offset,
                "opname": inst.opname,
                "opcode": inst.opcode,
                "arg": inst.arg,
                "argval": stable_repr(inst.argval),
                "argrepr": inst.argrepr,
                "starts_line": inst.starts_line,
                "is_jump_target": inst.is_jump_target,
            }
        )
    return result


def exception_data(code: CodeType) -> list[dict[str, object]]:
    return [
        {
            "start": entry.start,
            "end": entry.end,
            "target": entry.target,
            "depth": entry.depth,
            "lasti": entry.lasti,
        }
        for entry in dis.Bytecode(code).exception_entries
    ]


def code_data(path: str, code: CodeType) -> dict[str, object]:
    return {
        "path": path,
        "co_name": code.co_name,
        "co_qualname": code.co_qualname,
        "co_flags": flag_data(code.co_flags),
        "co_stacksize": code.co_stacksize,
        "co_code_hex": code.co_code.hex(),
        "co_exceptiontable_hex": code.co_exceptiontable.hex(),
        "co_varnames": list(code.co_varnames),
        "co_cellvars": list(code.co_cellvars),
        "co_freevars": list(code.co_freevars),
        "instructions": instruction_data(code),
        "exception_entries": exception_data(code),
    }


def build() -> dict[str, object]:
    fixtures: list[dict[str, object]] = []
    for name, source in FIXTURES:
        # Avoid inheriting this dumper's future-import flags into the oracle.
        module = compile(source, "<b7-generators>", "exec", dont_inherit=True)
        fixtures.append(
            {
                "name": name,
                "source": source,
                "code_objects": [code_data(path, code) for path, code in walk_code(module)],
            }
        )
    return {
        "interpreter": "CPython 3.14.7",
        "python_version": __import__("sys").version,
        "flag_constants": {
            name: {"decimal": value, "hex": f"0x{value:x}"}
            for name, value in FLAG_NAMES
        },
        "fixtures": fixtures,
    }


def md_code(obj: dict[str, object]) -> str:
    flags = obj["co_flags"]
    lines = [
        f"### `{obj['path']}` (`{obj['co_name']}`)",
        "",
        f"- `co_flags`: `{flags['hex']}` ({flags['decimal']})",
        f"- named flags: " + ", ".join(name for name, set_ in flags["named"].items() if set_) + "",
        f"- coroutine-family: {', '.join(name for name, data in flags['coroutine_family'].items() if data['set']) or '(none)'}",
        f"- `co_stacksize`: `{obj['co_stacksize']}`",
        f"- `co_code.hex()`: `{obj['co_code_hex']}`",
        f"- `co_exceptiontable.hex()`: `{obj['co_exceptiontable_hex']}`",
        f"- `co_varnames`: `{obj['co_varnames']}`",
        f"- `co_cellvars`: `{obj['co_cellvars']}`",
        f"- `co_freevars`: `{obj['co_freevars']}`",
        "",
        "Instructions:",
        "",
        "```text",
        "offset  opcode                         arg  argrepr",
    ]
    for inst in obj["instructions"]:
        lines.append(f"{inst['offset']:>6}  {inst['opname']:<29} {str(inst['arg']):>3}  {inst['argrepr']} [argval={inst['argval']}]")
    lines.extend(["```", "", "Exception entries:", "", "```text"])
    if obj["exception_entries"]:
        for entry in obj["exception_entries"]:
            lines.append(f"{entry['start']:>4}..{entry['end']:<4} -> {entry['target']:>4} depth={entry['depth']} lasti={entry['lasti']}")
    else:
        lines.append("(none)")
    lines.extend(["```", ""])
    return "\n".join(lines)


def render_markdown(data: dict[str, object]) -> str:
    lines = [
        "# Band 7 generator CPython oracle goldens",
        "",
        f"Interpreter: `{data['interpreter']}` ({data['python_version'].splitlines()[0]})",
        "",
        "All byte strings below are from host `compile(source, '<b7-generators>', 'exec')`; nested code objects are walked recursively through `co_consts`.",
        "",
        "## Flag constants",
        "",
        "| Name | Decimal | Hex |",
        "|---|---:|---:|",
    ]
    for name, value in data["flag_constants"].items():
        lines.append(f"| `{name}` | {value['decimal']} | `{value['hex']}` |")
    lines.extend(["", "## Fixtures", ""])
    for fixture in data["fixtures"]:
        lines.extend([f"## {fixture['name']}", "", "### Source", "", "```python", fixture["source"].rstrip("\n"), "```", ""])
        for obj in fixture["code_objects"]:
            lines.append(md_code(obj))
    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    data = build()
    (OUT / "goldens.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    (OUT / "goldens.md").write_text(render_markdown(data))
    print(f"wrote {len(data['fixtures'])} fixtures to {OUT}")
    for fixture in data["fixtures"]:
        print(f"{fixture['name']}: {len(fixture['code_objects'])} code object(s)")


if __name__ == "__main__":
    main()
