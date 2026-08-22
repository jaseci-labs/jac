#!/usr/bin/env python3
"""Generate deterministic CPython 3.14 annotated-assignment / type-alias goldens.

This file is intentionally standalone and uses only the host Python compiler.
It does not import or execute Jac code.
"""
from __future__ import annotations

import dis
import inspect
import json
import re
import sys
from pathlib import Path
from types import CodeType

OUT = Path(__file__).resolve().parent

FIXTURES: list[tuple[str, str]] = [
    (
        "module_annotated_with_value",
        "x: int = 5\n",
    ),
    (
        "module_bare_annotation",
        "x: list\n",
    ),
    (
        "class_body_annotations",
        "class C:\n    y: str = 'a'\n    z: dict\n",
    ),
    (
        "function_local_annotated",
        "def f():\n    q: int = 3\n",
    ),
    (
        "function_local_bare_annotation",
        "def f():\n    q: list\n",
    ),
    (
        "annotated_attribute_target",
        "def f(o):\n    o.k: int = 1\n",
    ),
    (
        "annotated_subscript_target",
        'def f(d):\n    d["k"]: int = 1\n',
    ),
    (
        "type_alias_simple",
        "type Pair = tuple[int, int]\n",
    ),
    (
        "type_alias_parametrized",
        "type Box[T] = list[T]\n",
    ),
    (
        "plain_assign_control",
        "x = 5\n",
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
    """Return the root code object followed by all descendants in co_consts order."""
    result: list[tuple[str, CodeType]] = [(path, code)]
    for index, const in enumerate(code.co_consts):
        if isinstance(const, CodeType):
            child_path = f"{path}.co_consts[{index}]<{const.co_name}>"
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


def stable_argrepr(argrepr: str) -> str:
    """Erase memory addresses from `<code object X at 0x...>` dis reprs."""
    return re.sub(r" at 0x[0-9a-f]+", " at 0xADDR", argrepr)


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
                "argrepr": stable_argrepr(inst.argrepr),
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


def const_summary(code: CodeType) -> list[str]:
    """Stable reprs of co_consts so nested code objects are visible without recursion."""
    return [stable_repr(const) for const in code.co_consts]


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
        "co_consts": const_summary(code),
        "instructions": instruction_data(code),
        "exception_entries": exception_data(code),
    }


def build() -> dict[str, object]:
    fixtures: list[dict[str, object]] = []
    for name, source in FIXTURES:
        # Avoid inheriting this dumper's future-import flags into the oracle.
        module = compile(source, "<b11-annotations>", "exec", dont_inherit=True)
        fixtures.append(
            {
                "name": name,
                "source": source,
                "code_objects": [code_data(path, code) for path, code in walk_code(module)],
            }
        )
    return {
        "interpreter": "CPython "
        + ".".join(str(part) for part in sys.version_info[:3]),
        "python_version": sys.version,
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
        "- named flags: " + ", ".join(name for name, set_ in flags["named"].items() if set_) + "",
        "- coroutine-family: " + (", ".join(name for name, data in flags["coroutine_family"].items() if data["set"]) or "(none)") + "",
        f"- `co_stacksize`: `{obj['co_stacksize']}`",
        f"- `co_code.hex()`: `{obj['co_code_hex']}`",
        f"- `co_exceptiontable.hex()`: `{obj['co_exceptiontable_hex']}`",
        f"- `co_varnames`: `{obj['co_varnames']}`",
        f"- `co_cellvars`: `{obj['co_cellvars']}`",
        f"- `co_freevars`: `{obj['co_freevars']}`",
        f"- `co_consts`: `{obj['co_consts']}`",
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
        "# Band 11 annotated assignment / type alias CPython oracle goldens",
        "",
        f"Interpreter: `{data['interpreter']}` ({data['python_version'].splitlines()[0]})",
        "",
        "All byte strings below are from host `compile(source, '<b11-annotations>', 'exec')`; the root module code object is listed first, then nested code objects are walked recursively through `co_consts`. Unlike the Band 6/7 streams, the root module scope is included because PEP 649 puts the annotation bytes there.",
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


def render_paste_ready(data: dict[str, object]) -> list[dict[str, object]]:
    out: list[dict[str, object]] = []
    for fixture in data["fixtures"]:
        entry: dict[str, object] = {"name": fixture["name"], "source": fixture["source"]}
        for index, obj in enumerate(fixture["code_objects"]):
            compact = {
                "path": obj["path"],
                "co_flags": obj["co_flags"]["hex"],
                "co_stacksize": obj["co_stacksize"],
                "co_code_hex": obj["co_code_hex"],
                "co_exceptiontable_hex": obj["co_exceptiontable_hex"],
                "exception_entries": obj["exception_entries"],
            }
            if index == 0:
                entry.update(compact)
            else:
                entry.setdefault("nested", []).append(compact)
        out.append(entry)
    return out


def render_index(data: dict[str, object]) -> str:
    lines = [
        "# b11_annotations paste index",
        "",
        "Compact view of `b11_annotations/goldens.json` for pasting into slice tests.",
        "Prefer `paste_ready.json` (source + hex bytes + decoded exception entries);",
        "`nested` entries there carry each `__annotate__` / type-alias code object.",
        "",
        "| Fixture | code objs | stack | code B | table B |",
        "|---|---:|---:|---:|---:|",
    ]
    for fixture in data["fixtures"]:
        objs = fixture["code_objects"]
        root = objs[0]
        lines.append(
            f"| `{fixture['name']}` | {len(objs)} | {root['co_stacksize']} "
            f"| {len(root['co_code_hex']) // 2} | {len(root['co_exceptiontable_hex']) // 2} |"
        )
    return "\n".join(lines) + "\n"


def main() -> None:
    data = build()
    (OUT / "goldens.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    (OUT / "goldens.md").write_text(render_markdown(data))
    (OUT / "paste_ready.json").write_text(json.dumps(render_paste_ready(data), indent=2, ensure_ascii=False) + "\n")
    (OUT / "INDEX.md").write_text(render_index(data))
    print(f"wrote {len(data['fixtures'])} fixtures to {OUT}")
    for fixture in data["fixtures"]:
        print(f"{fixture['name']}: {len(fixture['code_objects'])} code object(s)")


if __name__ == "__main__":
    main()
