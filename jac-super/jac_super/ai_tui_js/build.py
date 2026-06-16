#!/usr/bin/env python
# ruff: noqa: T201
"""Compile the Jac sidecar (`*.cl.jac`) to runnable JS under `dist/`.

This bypasses the browser/Vite client bundler and uses the programmatic
ecmascript path directly, targeting bun/node. Each `*.cl.jac` compiles to a
sibling `dist/<name>.js`; local Jac imports emit `import ... from "./<name>.js"`,
so the flat `dist/` layout keeps those relative paths resolvable.

Run with the editable jaclang (see memory: jac-ai-tui-build-venv):

    ../../../.venv/bin/python build.py

Type-check diagnostics on `Unknown`-typed npm objects (e.g. `renderer.destroy()`)
are non-fatal and filtered out; anything else is a real parse/compile error.
"""

from pathlib import Path

from jaclang.compiler.passes.ecmascript import EsastGenPass
from jaclang.compiler.passes.ecmascript.es_unparse import es_to_js
from jaclang.compiler.passes.main.type_checker_pass import TypeCheckPass
from jaclang.jac0core.program import JacProgram

HERE = Path(__file__).resolve().parent
DIST = HERE / "dist"


def compile_one(src: Path) -> str:
    prog = JacProgram()
    ir = prog.compile(file_path=str(src), no_cgen=True, type_check=True)
    fatal = [e for e in prog.errors_had if not issubclass(e.from_pass, TypeCheckPass)]
    if fatal:
        msg = "\n".join(f"  {e}" for e in fatal)
        raise SystemExit(f"FATAL compiling {src.name}:\n{msg}")
    return es_to_js(EsastGenPass(ir_in=ir, prog=prog).ir_out.gen.es_ast)


def js_name(src: Path) -> str:
    # foo.cl.jac -> foo.js ; bar.test.cl.jac -> bar.test.js
    return src.name[: -len(".cl.jac")] + ".js"


def main() -> None:
    sources = sorted(HERE.glob("*.cl.jac"))
    if not sources:
        raise SystemExit("no *.cl.jac sources found")
    DIST.mkdir(exist_ok=True)
    for src in sources:
        out = DIST / js_name(src)
        out.write_text(compile_one(src))
        print(f"  {src.name} -> dist/{out.name}")
    print(f"built {len(sources)} module(s) into {DIST}")


if __name__ == "__main__":
    main()
