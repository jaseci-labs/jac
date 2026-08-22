#!/home/jac/repos/jac-python/.venv/bin/python
"""Emit CPython 3.14 oracle goldens for Band 6 bare-except/else cases."""
from __future__ import annotations

import dis
import json
from pathlib import Path
from types import CodeType

OUT = Path(__file__).parent

FIXTURES = [
    (
        "bare_except_body",
        '''def f():
    try:
        raise ValueError("x")
    except:
        return "caught"
''',
    ),
    (
        "typed_then_bare_except",
        '''def f():
    try:
        raise RuntimeError("x")
    except ValueError:
        return "value"
    except:
        return "bare"
''',
    ),
    (
        "bare_except_reraise",
        '''def f():
    try:
        raise ValueError("x")
    except:
        raise
''',
    ),
    (
        "try_else_normal",
        '''def f():
    try:
        value = 1
    except ValueError:
        value = 2
    else:
        value = 3
    return value
''',
    ),
    (
        "try_except_else_exception",
        '''def f():
    try:
        raise ValueError("x")
    except ValueError:
        value = 2
    else:
        value = 3
    return value
''',
    ),
    (
        "try_except_else_finally",
        '''def f():
    try:
        value = 1
    except ValueError:
        value = 2
    else:
        value = 3
    finally:
        value = 4
    return value
''',
    ),
    (
        "try_without_except_or_finally",
        '''def f():
    try:
        pass
''',
    ),
    (
        "tuple_except_as",
        '''def f():
    try:
        raise KeyError("x")
    except (ValueError, KeyError) as error:
        return error
''',
    ),
]


def _stable_argval(value: object) -> str:
    if isinstance(value, CodeType):
        return f"<code object {value.co_name!r}, file {value.co_filename!r}, line {value.co_firstlineno}>"
    return repr(value)


def _instructions(code: CodeType) -> list[dict[str, object]]:
    return [
        {
            "offset": ins.offset,
            "opname": ins.opname,
            "opcode": ins.opcode,
            "arg": ins.arg,
            "argval": _stable_argval(ins.argval),
            "argrepr": _stable_argval(ins.argval) if isinstance(ins.argval, CodeType) else ins.argrepr,
            "starts_line": ins.starts_line,
            "is_jump_target": ins.is_jump_target,
        }
        for ins in dis.get_instructions(code)
    ]


def _exception_entries(code: CodeType) -> list[dict[str, object]]:
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


def _code_record(code: CodeType, path: str) -> dict[str, object]:
    return {
        "path": path,
        "name": code.co_name,
        "qualname": code.co_qualname,
        "filename": code.co_filename,
        "firstlineno": code.co_firstlineno,
        "co_flags": hex(code.co_flags),
        "co_stacksize": code.co_stacksize,
        "co_code_hex": code.co_code.hex(),
        "co_exceptiontable_hex": code.co_exceptiontable.hex(),
        "instructions": _instructions(code),
        "exception_entries": _exception_entries(code),
    }


def _walk_code(code: CodeType, path: str = "module") -> list[dict[str, object]]:
    records = [_code_record(code, path)]
    for index, const in enumerate(code.co_consts):
        if isinstance(const, CodeType):
            records.extend(_walk_code(const, f"{path}.co_consts[{index}]"))
    return records


def _compile_fixture(name: str, source: str) -> dict[str, object]:
    result: dict[str, object] = {"name": name, "source": source}
    try:
        module_code = compile(source, f"<{name}>", "exec")
    except SyntaxError as error:
        result.update(
            {
                "status": "syntax_error",
                "syntax_error": {
                    "type": type(error).__name__,
                    "message": str(error),
                    "msg": error.msg,
                    "filename": error.filename,
                    "lineno": error.lineno,
                    "offset": error.offset,
                    "text": error.text,
                    "end_lineno": error.end_lineno,
                    "end_offset": error.end_offset,
                },
                "code_objects": [],
            }
        )
        return result

    records = _walk_code(module_code)
    function = next((record for record in records[1:] if record["name"] == "f"), records[0])
    result.update(
        {
            "status": "ok",
            "co_flags": function["co_flags"],
            "co_stacksize": function["co_stacksize"],
            "co_code_hex": function["co_code_hex"],
            "co_exceptiontable_hex": function["co_exceptiontable_hex"],
            "instructions": function["instructions"],
            "exception_entries": function["exception_entries"],
            "function_path": function["path"],
            "code_objects": records,
        }
    )
    return result


def _markdown(payload: dict[str, object]) -> str:
    lines = [
        "# Band 6 bare-except and try/else CPython 3.14 goldens",
        "",
        f"Interpreter: `{payload['implementation']} {payload['python'].split()[0]}`",
        "",
    ]
    for fixture in payload["fixtures"]:
        lines.extend([f"## `{fixture['name']}`", "", "### Source", "", "```python", fixture["source"].rstrip("\\n"), "```", ""])
        if fixture["status"] == "syntax_error":
            error = fixture["syntax_error"]
            lines.extend(["### Compile result", "", f"- status: `{fixture['status']}`", f"- message: `{error['message']}`", ""])
            continue
        lines.extend(
            [
                "### Function code object",
                "",
                f"- path: `{fixture['function_path']}`",
                f"- co_flags: `{fixture['co_flags']}`",
                f"- co_stacksize: `{fixture['co_stacksize']}`",
                f"- co_code: `{fixture['co_code_hex']}`",
                f"- co_exceptiontable: `{fixture['co_exceptiontable_hex']}`",
                "",
                "### Disassembly",
                "",
                "```text",
            ]
        )
        for ins in fixture["instructions"]:
            lines.append(
                f"{ins['offset']:04d} {ins['opname']:<24} "
                f"arg={ins['arg']!r} argrepr={ins['argrepr']!r}"
            )
        lines.extend(["```", "", "### Exception entries", "", "```text"])
        for entry in fixture["exception_entries"]:
            lines.append(
                f"{entry['start']:04d}..{entry['end']:04d} -> {entry['target']:04d} "
                f"depth={entry['depth']} lasti={entry['lasti']}"
            )
        lines.extend(["```", ""])
    return "\n".join(lines)


def main() -> None:
    results = [_compile_fixture(name, source) for name, source in FIXTURES]
    payload = {
        "python": __import__("sys").version,
        "implementation": __import__("platform").python_implementation(),
        "fixtures": results,
    }
    (OUT / "goldens.json").write_text(json.dumps(payload, indent=2) + "\n")
    (OUT / "goldens.md").write_text(_markdown(payload))

    for fixture in results:
        print(f"=== {fixture['name']} [{fixture['status']}] ===")
        print(fixture["source"], end="")
        if fixture["status"] == "syntax_error":
            print("syntax_error.message:", repr(fixture["syntax_error"]["message"]))
            print()
            continue
        print("co_flags:", fixture["co_flags"])
        print("co_stacksize:", fixture["co_stacksize"])
        print("co_code:", fixture["co_code_hex"])
        print("co_exceptiontable:", fixture["co_exceptiontable_hex"])
        print("-- dis --")
        for ins in fixture["instructions"]:
            print(
                f"{ins['offset']:04d} {ins['opname']:<24} "
                f"arg={ins['arg']!r} argrepr={ins['argrepr']!r}"
            )
        print("-- exception entries --")
        for entry in fixture["exception_entries"]:
            print(
                f"{entry['start']:04d}..{entry['end']:04d} -> {entry['target']:04d} "
                f"depth={entry['depth']} lasti={entry['lasti']}"
            )
        print()


if __name__ == "__main__":
    main()
