"""clinic2jac - emit Jac method signatures from Argument Clinic blocks.

P3.1d backend for CPython libclinic (PLAN.md). Reuses
reference/cpython/Tools/clinic/libclinic to parse Clinic DSL, then emits
checked-in Jac impl + converter glue for Objects/ excerpts.

Usage:
    python jac-py/tools/clinic2jac.py
    python jac-py/tools/clinic2jac.py --check
    python jac-py/tools/clinic2jac.py --stdout
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import TYPE_CHECKING, Iterable

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(os.path.dirname(_HERE))
_CLINIC = os.path.join(_REPO, "reference", "cpython", "Tools", "clinic")
sys.path.insert(0, _CLINIC)

from libclinic import fail, unspecified  # noqa: E402
from libclinic.app import Clinic  # noqa: E402
from libclinic.converters import defining_class_converter, self_converter  # noqa: E402
from libclinic.function import (  # noqa: E402
    Class,
    Function,
    METHOD_NEW,
    Module,
    Parameter,
)
from libclinic.language import Language  # noqa: E402

if TYPE_CHECKING:
    from libclinic.app import Clinic as ClinicType

FIXTURE_PATH = os.path.join(
    _REPO, "jac-py", "tools", "p3_object_core", "clinic_fixtures", "bool_new.c"
)
OUT_PATH = os.path.join(_REPO, "jac-py", "Objects", "_clinic", "bool_new.jac")
FIXTURE_PROVENANCE = "jac-py/tools/p3_object_core/clinic_fixtures/bool_new.c"

C_TO_JAC: dict[str, str] = {
    "PyTypeObject *": "PyTypeObject",
    "PyObject *": "PyObj",
    "int": "int",
    "long": "int",
}


class JacLanguage(Language):
    """Jac emit backend for Argument Clinic (spike: METHOD_NEW positional-only)."""

    language = "Jac"
    start_line = "/*[{dsl_name} input]"
    body_prefix = ""
    stop_line = "[{dsl_name} start generated code]*/"
    checksum_line = "/*[{dsl_name} end generated code: {arguments}]*/"

    def render(
        self,
        clinic: ClinicType,
        signatures: Iterable[Module | Class | Function],
    ) -> str:
        function: Function | None = None
        for obj in signatures:
            if isinstance(obj, Function):
                if function is not None:
                    fail(
                        "clinic2jac supports at most one function per block; "
                        f"found {function.full_name!r} and {obj.full_name!r}"
                    )
                function = obj
        if function is None:
            return ""
        return render_function(function)


def jac_type(c_type: str, *, optional: bool = False) -> str:
    base = C_TO_JAC.get(c_type, c_type.replace(" *", "").replace("*", ""))
    if optional:
        return f"{base} | None"
    return base


def _impl_parameters(func: Function) -> list[Parameter]:
    params = list(func.render_parameters)
    if params and isinstance(params[0].converter, (self_converter, defining_class_converter)):
        return params[1:]
    return params


def _jac_docstring_literal(doc: str) -> str:
    escaped = (
        doc.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
    )
    return f'"{escaped}"'


def render_impl_prototype(func: Function) -> str:
    params = func.render_parameters
    arg_parts: list[str] = []
    for p in params:
        is_self = isinstance(p.converter, (self_converter, defining_class_converter))
        opt = (not is_self) and (
            p.is_optional() or getattr(p.converter, "c_default", None) == "NULL"
        )
        arg_parts.append(f"{p.name}: {jac_type(p.converter.type, optional=opt)}")
        if opt and p.default is not unspecified:
            if p.default is None or getattr(p.converter, "c_default", None) == "NULL":
                arg_parts[-1] += " = None"
    ret = jac_type(func.return_converter.type)
    args = ", ".join(arg_parts)
    return f"def {func.c_basename}_impl({args}) -> {ret} {{"


def render_impl_body(func: Function) -> list[str]:
    """Emit impl body for supported spike patterns."""
    impl_params = _impl_parameters(func)
    if func.kind is METHOD_NEW and len(impl_params) == 1:
        p = impl_params[0]
        if p.name == "object" and p.converter.type == "PyObject *":
            return [
                "    x = object if object is not None else Py_False;",
                "    ok = PyObject_IsTrue(x);",
                "    if ok < 0 {",
                "        return 0;",
                "    }",
                "    return PyBool_FromLong(ok);",
            ]
    fail(f"clinic2jac has no impl body template for {func.full_name!r}")


def render_parser_glue(func: Function) -> list[str]:
    """Emit tuple/kwds converter glue matching libclinic METHOD_NEW output."""
    if func.kind is not METHOD_NEW:
        fail(f"clinic2jac parser glue supports METHOD_NEW only, not {func.kind!r}")

    impl_params = _impl_parameters(func)
    name = func.displayname
    lines: list[str] = []
    lines.append(f"def {func.c_basename}(type: PyTypeObject, args: PyObj, kwds: PyObj) -> PyObj {{")

    for p in impl_params:
        if p.is_optional():
            lines.append(f"    {p.name}: {jac_type(p.converter.type, optional=True)} = None;")

    lines.extend(
        [
            f'    if not _PyArg_NoKeywords("{name}", kwds) {{',
            "        return 0;",
            "    }",
            f'    if not _PyArg_CheckPositional("{name}", PyTuple_GET_SIZE(args), 0, {len(impl_params)}) {{',
            "        return 0;",
            "    }",
        ]
    )

    if impl_params and impl_params[-1].is_optional():
        p = impl_params[-1]
        lines.extend(
            [
                "    if PyTuple_GET_SIZE(args) >= 1 {",
                f"        {p.name} = PyTuple_GET_ITEM(args, 0);",
                "    }",
            ]
        )

    impl_args = ", ".join(["type", *[p.name for p in impl_params]])
    lines.append(f"    return {func.c_basename}_impl({impl_args});")
    lines.append("}")
    return lines


def render_docstring_glob(func: Function) -> str:
    return f"glob {func.c_basename}__doc__: str = {_jac_docstring_literal(func.docstring)};"


def render_function(func: Function) -> str:
    out: list[str] = []
    out.append(render_impl_prototype(func))
    out.extend(render_impl_body(func))
    out.append("}")
    out.append("")
    out.extend(render_parser_glue(func))
    out.append("")
    out.append(render_docstring_glob(func))
    return "\n".join(out)


def iter_functions(clinic: Clinic) -> list[Function]:
    found: list[Function] = []

    def walk_class(cls: Class) -> None:
        found.extend(cls.functions)
        for nested in cls.classes.values():
            walk_class(nested)

    found.extend(clinic.functions)
    for mod in clinic.modules.values():
        found.extend(mod.functions)
        for cls in mod.classes.values():
            walk_class(cls)
    for cls in clinic.classes.values():
        walk_class(cls)
    return found


def parse_fixture(source: str, *, filename: str) -> list[Function]:
    lang = JacLanguage(filename)
    clinic = Clinic(lang, verify=False, filename=filename, limited_capi=False)
    clinic.parse(source)
    funcs = iter_functions(clinic)
    if not funcs:
        fail(f"no clinic functions found in {filename!r}")
    return funcs


def generate_text() -> str:
    with open(FIXTURE_PATH, encoding="utf-8") as fh:
        source = fh.read()
    funcs = parse_fixture(source, filename=FIXTURE_PATH)
    out: list[str] = []
    out.append('"""Argument Clinic → Jac signatures.')
    out.append("")
    out.append(f"GENERATED by jac-py/tools/clinic2jac.py from {FIXTURE_PROVENANCE}")
    out.append("(CPython pin: see CURRENT.md). Do not edit by hand — regenerate instead.")
    out.append('"""')
    out.append("")
    for func in funcs:
        out.append(render_function(func))
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Emit Jac from Argument Clinic fixtures")
    parser.add_argument("--stdout", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    text = generate_text()
    if args.stdout:
        sys.stdout.write(text)
        return 0
    if args.check:
        try:
            with open(OUT_PATH, encoding="utf-8") as fh:
                on_disk = fh.read()
        except FileNotFoundError:
            print(f"{OUT_PATH} missing; run clinic2jac.py to generate it", file=sys.stderr)
            return 1
        if on_disk != text:
            print(f"{OUT_PATH} is stale; regenerate with clinic2jac.py", file=sys.stderr)
            return 1
        print(f"{OUT_PATH} up to date ({len(text.splitlines())} lines)")
        return 0
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"wrote {OUT_PATH} ({len(text.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
