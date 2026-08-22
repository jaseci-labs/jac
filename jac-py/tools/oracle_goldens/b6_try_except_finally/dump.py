#!/home/jac/repos/jac-python/.venv/bin/python
"""Deterministic CPython 3.14 oracle dump for combined try/except/finally."""
from __future__ import annotations

import dis
import json
import sys
from pathlib import Path
from types import CodeType

FIXTURES = [
    {
        "name": "try_except_finally_normal",
        "source": '''def f():
    try:
        value = 1
    except ValueError:
        value = 2
    finally:
        finished = 3
''',
    },
    {
        "name": "try_except_finally_raised_caught",
        "source": '''def f():
    try:
        raise ValueError("body")
    except ValueError:
        handled = 1
    finally:
        finished = 2
''',
    },
    {
        "name": "try_except_finally_raised_unmatched",
        "source": '''def f():
    try:
        raise KeyError("body")
    except ValueError:
        handled = 1
    finally:
        finished = 2
''',
    },
    {
        "name": "try_except_as_finally",
        "source": '''def f():
    try:
        raise ValueError("body")
    except ValueError as error:
        handled = 1
    finally:
        finished = 2
''',
    },
    {
        "name": "return_inside_try_finally",
        "source": '''def f():
    try:
        return 7
    finally:
        finished = 1
''',
    },
    {
        "name": "exception_inside_handler_finally",
        "source": '''def f():
    try:
        raise ValueError("body")
    except ValueError:
        raise RuntimeError("handler")
    finally:
        finished = 1
''',
    },
    {
        "name": "nested_try_except_finally",
        "source": '''def f():
    try:
        try:
            value = 1
        except ValueError:
            value = 2
        finally:
            inner_finished = 3
    except KeyError:
        outer_handled = 4
    finally:
        outer_finished = 5
''',
    },
    {
        "name": "try_finally_loop_break_continue",
        "source": '''def f(items):
    total = 0
    for item in items:
        try:
            if item == 0:
                break
            if item < 0:
                continue
            total += item
        finally:
            cleaned = item
    return total
''',
    },
]


def code_objects(code: CodeType) -> list[CodeType]:
    """Return nested code objects in deterministic co_consts traversal order."""
    result: list[CodeType] = []

    def walk(current: CodeType) -> None:
        result.append(current)
        for const in current.co_consts:
            if isinstance(const, CodeType):
                walk(const)

    walk(code)
    return result


def function_code(module_code: CodeType) -> CodeType:
    for code in code_objects(module_code)[1:]:
        if code.co_name == "f":
            return code
    raise AssertionError("fixture has no function named f")


def instruction_record(instruction: dis.Instruction) -> dict[str, object]:
    # cache_offset/start_offset/end_offset preserve the 3.14 cache-aware view;
    # show_caches=True below ensures CACHE instructions are not hidden.
    return {
        "offset": instruction.offset,
        "start_offset": instruction.start_offset,
        "end_offset": instruction.end_offset,
        "cache_offset": instruction.cache_offset,
        "opname": instruction.opname,
        "oparg": instruction.oparg,
        "argrepr": instruction.argrepr,
    }


def code_record(code: CodeType) -> dict[str, object]:
    instructions = [
        instruction_record(item)
        for item in dis.get_instructions(code, show_caches=True, adaptive=False)
    ]
    exception_entries = [
        {
            "start": entry.start,
            "end": entry.end,
            "target": entry.target,
            "depth": entry.depth,
            "lasti": entry.lasti,
        }
        for entry in dis.Bytecode(code).exception_entries
    ]
    return {
        "qualname": code.co_qualname,
        "name": code.co_name,
        "co_flags": hex(code.co_flags),
        "co_stacksize": code.co_stacksize,
        "co_code": code.co_code.hex(),
        "co_exceptiontable": code.co_exceptiontable.hex(),
        "instructions": instructions,
        "exception_entries": exception_entries,
    }


def build() -> dict[str, object]:
    records = []
    for fixture in FIXTURES:
        module = compile(fixture["source"], "<f>", "exec")
        target = function_code(module)
        nested = [code_record(code) for code in code_objects(target)[1:]]
        record = {
            **code_record(target),
            "name": fixture["name"],
            "source": fixture["source"],
            "nested_code_objects": nested,
        }
        records.append(record)
    return {"python": sys.version.split()[0], "fixtures": records}


def markdown(data: dict[str, object]) -> str:
    lines = [
        "# Band 6 try/except/finally combined CPython goldens",
        "",
        f"Generated with CPython {data['python']} using `compile(source, '<f>', 'exec')`.",
        "Instruction listings use `dis.get_instructions(..., show_caches=True, adaptive=False)`.",
        "",
    ]
    for fixture in data["fixtures"]:
        lines.extend([
            f"## `{fixture['name']}`",
            "",
            "### Source",
            "",
            "```python",
            fixture["source"].rstrip("\n"),
            "```",
            "",
            "### Code object",
            "",
            f"- `qualname`: `{fixture['qualname']}`",
            f"- `co_flags`: `{fixture['co_flags']}`",
            f"- `co_stacksize`: `{fixture['co_stacksize']}`",
            f"- `co_code`: `{fixture['co_code']}`",
            f"- `co_exceptiontable`: `{fixture['co_exceptiontable']}`",
            "",
            "### Instructions",
            "",
            "```text",
            "offset  cache  opname                       oparg  argrepr",
        ])
        for ins in fixture["instructions"]:
            lines.append(
                f"{ins['offset']:>6}  {ins['cache_offset']!s:>5}  "
                f"{ins['opname']:<28} {str(ins['oparg']):>5}  {ins['argrepr']}"
            )
        lines.extend(["```", "", "### Exception entries", "", "```text"])
        if fixture["exception_entries"]:
            lines.append("start  end  target  depth  lasti")
            for entry in fixture["exception_entries"]:
                lines.append(
                    f"{entry['start']:>5} {entry['end']:>4} {entry['target']:>7} "
                    f"{entry['depth']:>6} {entry['lasti']}"
                )
        else:
            lines.append("(none)")
        lines.extend(["```", ""])
        for nested in fixture["nested_code_objects"]:
            lines.extend([
                f"### Nested code object `{nested['qualname']}`",
                "",
                f"- `co_flags`: `{nested['co_flags']}`",
                f"- `co_stacksize`: `{nested['co_stacksize']}`",
                f"- `co_code`: `{nested['co_code']}`",
                f"- `co_exceptiontable`: `{nested['co_exceptiontable']}`",
                "",
            ])
    return "\n".join(lines)


def main() -> None:
    data = build()
    text = json.dumps(data, indent=2, sort_keys=False) + "\n"
    if "--write" in sys.argv[1:]:
        root = Path(__file__).resolve().parent
        (root / "goldens.json").write_text(text, encoding="utf-8")
        (root / "goldens.md").write_text(markdown(data), encoding="utf-8")
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
