"""Standalone FastAPI backend target for `jac eject` (`[eject].target = "backend"`).

Emits a self-contained backend directory with zero `.jac` files AND zero
`jaclang` runtime dependency. The compiler turns each `.jac` file into Python
that imports a handful of symbols from `jaclang.jac0core.jaclib`; this target
rewrites that single import to a vendored `_osp.py` micro-runtime and wraps
each Jac walker in a FastAPI endpoint, so the result runs with only
`fastapi` + `uvicorn` installed.

Stage 1 scope: walkers whose entry abilities fire on the spawn Root and
report values, plus module-level `def` abilities exposed as functions. Graph
persistence, multi-node traversal, permissions, and `by llm()` are out of
scope and grow in later stages.
"""

import ast;
import shutil;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.cli.commands.eject { _collect_jac_files, _strip_jac_suffix }


# Marker file written at the output root. Its presence tells a later eject run
# that the directory is ours and safe to regenerate without `--force`.
glob _EJECT_MARKER: str = ".jac-ejected";


# Module names we generate ourselves in the output; a compiled Jac module
# whose stem collides with one of these is renamed (e.g. main -> _jac_main)
# and references to it are rewritten across the other emitted modules.
glob _RESERVED_MODULES: set = {"main", "_osp"};


# The vendored Object-Spatial micro-runtime, written verbatim to <out>/_osp.py.
# Built as a line list (not a triple-quoted literal) so the Python docstrings
# inside it do not terminate the surrounding Jac string, matching how the
# default eject builds serve.py.
glob _OSP_RUNTIME_LINES: list[str] = [
    '"""Standalone Object-Spatial micro-runtime for ejected Jac backends.',
    '',
    'Dependency-free replacements for the jaclang runtime symbols the compiled',
    'walker modules import (Root, Walker, on_entry, set_trigger, spawn, root,',
    'log_report, ...), so the ejected backend runs with only fastapi + uvicorn',
    'installed -- no jaclang.',
    '',
    'Stage 1 scope: walkers whose entry abilities fire on the spawn Root and',
    'report values. No graph persistence, traversal, permissions, or LLM.',
    '"""',
    'from __future__ import annotations',
    '',
    'import threading',
    'from dataclasses import dataclass, field  # noqa: F401  (re-exported)',
    '',
    '_state = threading.local()',
    '',
    '',
    'def on_entry(func):',
    '    """Mark an ability as an entry ability (mirrors jaclib.on_entry)."""',
    '    func._osp_entry = True',
    '    return func',
    '',
    '',
    'def on_exit(func):',
    '    """Mark an ability as an exit ability (mirrors jaclib.on_exit)."""',
    '    func._osp_exit = True',
    '    return func',
    '',
    '',
    'def set_trigger(trigger_thunk):',
    '    """Stamp an ability with its compiler-known trigger thunk (lambda: T)."""',
    '    def deco(func):',
    '        func._osp_trigger = trigger_thunk',
    '        return func',
    '    return deco',
    '',
    '',
    'class _Archetype:',
    '    """Base for compiled archetypes: make each subclass a dataclass (so it',
    '    builds from its field annotations) and collect its entry/exit abilities,',
    '    mirroring the part of jaclang make_archetype the ejected code relies on."""',
    '',
    '    _osp_entries = ()',
    '    _osp_exits = ()',
    '',
    '    def __init_subclass__(cls, **kwargs):',
    '        super().__init_subclass__(**kwargs)',
    '        cls._osp_entries = tuple(',
    '            fn for fn in vars(cls).values()',
    '            if callable(fn) and getattr(fn, "_osp_entry", False)',
    '        )',
    '        cls._osp_exits = tuple(',
    '            fn for fn in vars(cls).values()',
    '            if callable(fn) and getattr(fn, "_osp_exit", False)',
    '        )',
    '        dataclass(eq=False)(cls)',
    '',
    '',
    'class Walker(_Archetype):',
    '    pass',
    '',
    '',
    'class Node(_Archetype):',
    '    pass',
    '',
    '',
    'class Obj(_Archetype):',
    '    pass',
    '',
    '',
    'class Edge(_Archetype):',
    '    pass',
    '',
    '',
    'class Root(Node):',
    '    pass',
    '',
    '',
    'class GenericEdge(Edge):',
    '    pass',
    '',
    '',
    'def root():',
    '    """Return a fresh in-memory root node (stage 1: no persistence)."""',
    '    return Root()',
    '',
    '',
    'def log_report(expr, custom=False):',
    '    """Collect a value reported by the active walker (Jac `report`)."""',
    '    walker = getattr(_state, "walker", None)',
    '    if walker is not None:',
    '        walker.reports.append(expr)',
    '',
    '',
    'def _trigger_matches(fn, location):',
    '    thunk = getattr(fn, "_osp_trigger", None)',
    '    if thunk is None:',
    '        return True',
    '    trig = thunk()',
    '    return trig is None or isinstance(location, trig)',
    '',
    '',
    'def spawn(op1, op2):',
    '    """Run a walker on a location and return the walker (Jac `spawn`).',
    '',
    '    Either operand may be the walker; the other is the spawn location.',
    '    Fires entry abilities whose trigger matches the location (in order),',
    '    then exit abilities, and returns the walker with `reports` populated.',
    '    Grows into the full DFS kernel (visit / connect / disengage) later.',
    '    """',
    '    if isinstance(op1, Walker):',
    '        walker, location = op1, op2',
    '    else:',
    '        walker, location = op2, op1',
    '    walker.reports = []',
    '    prev = getattr(_state, "walker", None)',
    '    _state.walker = walker',
    '    try:',
    '        for fn in type(walker)._osp_entries:',
    '            if _trigger_matches(fn, location):',
    '                fn(walker, location)',
    '        for fn in type(walker)._osp_exits:',
    '            if _trigger_matches(fn, location):',
    '                fn(walker, location)',
    '    finally:',
    '        _state.walker = prev',
    '    return walker',
    ''
];


"""Eject a Jac project to a standalone FastAPI backend.

Called by the eject command when jac.toml declares `[eject].target = "backend"`.
`out` is the project-internal output directory (e.g. `<project>/dist`). It is
regenerated on every run when it carries our marker file; a pre-existing
directory without the marker is only overwritten when `force` is set, so we
never clobber a folder we did not create.
"""
def eject_backend(src: Path, out: Path, force: bool, metadata: dict) -> int {
    project_name = str(metadata["project_name"]);

    marker = out / _EJECT_MARKER;
    if out.exists() {
        if force or marker.exists() {
            try {
                shutil.rmtree(out);
            } except Exception as e {
                console.error(f"Failed to remove existing output directory: {e}");
                return 1;
            }
        } else {
            console.error(f"Output directory already exists: {out}");
            console.print(
                "  It was not created by eject. Use --force to overwrite.",
                style="muted"
            );
            return 1;
        }
    }

    # Collect sources, skipping anything inside the output directory itself
    # (so re-running over a project-internal output dir never re-ingests it).
    jac_files = [f for f in _collect_jac_files(src) if out not in Path(str(f)).parents];
    if not jac_files {
        console.error("No .jac source files found to eject.");
        return 1;
    }

    import from jaclang.jac0core.program { JacProgram }
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.constant { SymbolType }

    out.mkdir(parents=True);

    console.print(
        f"\n📦 Ejecting '{project_name}' → standalone FastAPI backend",
        style="bold cyan"
    );
    console.print(f"  Source: {src}");
    console.print(f"  Output: {out}\n");

    # Pass one: compile every file, decide its emitted module name, harvest
    # walker / function names, and stash the generated Python for pass two.
    compiled: list[dict] = [];
    remap: dict[str, str] = {};
    walker_names: set[str] = set();
    func_names: set[str] = set();
    walker_module: dict[str, str] = {};
    func_module: dict[str, str] = {};
    error_count = 0;

    for jac_file in jac_files {
        rel = Path(str(jac_file)).relative_to(src);
        if len(rel.parts) > 1 {
            console.warning(
                f"  {rel}: nested modules are not supported yet; emitting flat."
            );
        }
        try {
            prog = JacProgram();
            ir = prog.compile(file_path=str(jac_file));
        } except Exception as e {
            console.error(f"  ✗ {rel}: compile failed: {e}");
            error_count += 1;
            continue;
        }
        if prog.errors_had {
            for err in prog.errors_had {
                console.error(f"  ✗ {rel}: {err}");
            }
            error_count += 1;
            continue;
        }
        py_code = ir.gen.py or "";
        if not py_code.strip() {
            console.print(f"  · {rel} (no output)", style="muted");
            continue;
        }
        stem = str(_strip_jac_suffix(rel.name));
        module = stem;
        if stem in _RESERVED_MODULES {
            module = f"_jac_{stem}";
            remap[stem] = module;
        }
        for item in ir.body {
            if isinstance(item, uni.Archetype)
            and item.sym_category == SymbolType.WALKER_ARCH {
                wname = str(item.name.sym_name);
                walker_names.add(wname);
                walker_module[wname] = module;
            } elif isinstance(item, uni.Ability) and item.name_ref is not None {
                fname = str(item.name_ref.sym_name);
                func_names.add(fname);
                func_module[fname] = module;
            }
        }
        compiled.append({"rel": rel, "module": module, "py": py_code});
    }

    if error_count > 0 {
        console.error(
            f"\n{error_count} file(s) failed to compile. Output is incomplete."
        );
        return 1;
    }
    if not compiled {
        console.error("No Python output produced; nothing to eject.");
        return 1;
    }

    # Pass two: rewrite imports (jaclib -> _osp, remapped module names), write
    # each module, and harvest fields / params from the final Python.
    walker_fields: dict = {};
    func_params: dict = {};
    for unit in compiled {
        rel_disp = unit["rel"];
        module = str(unit["module"]);
        code = _rewrite_imports(str(unit["py"]), remap);
        (out / f"{module}.py").write_text(code, encoding="utf-8");
        walker_fields.update(_extract_walker_fields(code, walker_names));
        func_params.update(_extract_func_params(code, func_names));
        console.print(f"  ✔ {rel_disp} → {module}.py", style="success");
    }

    walkers: list[dict] = [];
    for wname in sorted(list(walker_names)) {
        walkers.append({
            "name": wname,
            "module": walker_module[wname],
            "fields": walker_fields.get(wname, [])
        });
    }
    functions: list[dict] = [];
    for fname in sorted(list(func_names)) {
        functions.append({
            "name": fname,
            "module": func_module[fname],
            "params": func_params.get(fname, [])
        });
    }

    _emit_osp_runtime(out);
    _emit_main_py(out, project_name, walkers, functions);
    _emit_requirements(out);
    _emit_readme(out, project_name);
    (out / _EJECT_MARKER).write_text(
        "Generated by `jac eject` (target = backend). Safe to delete.\n",
        encoding="utf-8"
    );

    console.print();
    console.success(f"Ejected '{project_name}' → {out}");
    console.print(
        f"  {len(walkers)} walker endpoint(s), {len(functions)} function endpoint(s)",
        style="muted"
    );
    console.print();
    console.print("Next steps:", style="bold");
    console.print(f"  cd {out}");
    console.print("  pip install -r requirements.txt");
    console.print("  uvicorn main:app --reload");
    console.print();
    return 0;
}


"""Rewrite a compiled module's imports for the standalone output.

Maps the single `from jaclang.jac0core.jaclib import ...` line to the vendored
`_osp` runtime, then renames any references to remapped sibling modules (a Jac
module whose stem collided with one of our generated files)."""
def _rewrite_imports(py_code: str, remap: dict) -> str {
    jaclib_prefix = "from jaclang.jac0core.jaclib import ";
    out_lines: list[str] = [];
    for raw in py_code.splitlines() {
        line = raw;
        if line.startswith(jaclib_prefix) {
            line = "from _osp import " + line[len(jaclib_prefix):];
        }
        for (orig, new) in remap.items() {
            orig_s = str(orig);
            new_s = str(new);
            if line.startswith("from " + orig_s + " import ") {
                line = "from " + new_s + " import " + line[len("from " + orig_s + " import "):];
            } elif (line == "import " + orig_s) or line.startswith("import " + orig_s + " ") {
                line = "import " + new_s + line[len("import " + orig_s):];
            }
        }
        out_lines.append(line);
    }
    return "\n".join(out_lines);
}


"""Extract each walker's request fields from the compiled Python.

Reads the top-level `name: type` annotations of every class whose name is a
known walker. Skips private names and the runtime-injected `reports` field.
Returns {walker_name: [{name, type, has_default, default}]}.
"""
def _extract_walker_fields(py_code: str, walker_names: set) -> dict {
    result: dict = {};
    try {
        tree = ast.parse(py_code);
    } except Exception {
        return result;
    }
    for node in tree.body {
        if isinstance(node, ast.ClassDef) and (node.name in walker_names) {
            fields: list = [];
            for stmt in node.body {
                if isinstance(stmt, ast.AnnAssign)
                and isinstance(stmt.target, ast.Name) {
                    fname = stmt.target.id;
                    if fname.startswith("_") or (fname == "reports") {
                        continue;
                    }
                    ftype = ast.unparse(stmt.annotation);
                    if ftype.startswith("ClassVar") {
                        continue;
                    }
                    has_default = stmt.value is not None;
                    default_src = ast.unparse(stmt.value) if stmt.value is not None else None;
                    fields.append({
                        "name": fname,
                        "type": ftype,
                        "has_default": has_default,
                        "default": default_src
                    });
                }
            }
            result[node.name] = fields;
        }
    }
    return result;
}


"""Extract each public function's parameters from the compiled Python.

Returns {func_name: [{name, type}]}, skipping `self`."""
def _extract_func_params(py_code: str, func_names: set) -> dict {
    result: dict = {};
    try {
        tree = ast.parse(py_code);
    } except Exception {
        return result;
    }
    for node in tree.body {
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        and (node.name in func_names) {
            params: list = [];
            for arg in node.args.args {
                if arg.arg == "self" {
                    continue;
                }
                ptype = ast.unparse(arg.annotation) if arg.annotation is not None else "object";
                params.append({"name": arg.arg, "type": ptype});
            }
            result[node.name] = params;
        }
    }
    return result;
}


"""Write the vendored micro-runtime to <out>/_osp.py."""
def _emit_osp_runtime(out: Path) {
    (out / "_osp.py").write_text("\n".join(_OSP_RUNTIME_LINES), encoding="utf-8");
}


"""Pydantic request-model name for a walker / function (greeter -> GreeterIn)."""
def _model_class_name(name: str) -> str {
    return name[:1].upper() + name[1:] + "In";
}


"""Write main.py: the FastAPI app exposing each walker and function."""
def _emit_main_py(out: Path, project_name: str, walkers: list, functions: list) {
    lines: list[str] = [
        f'"""Auto-generated FastAPI app for the ejected Jac project {project_name!r}.',
        '',
        'Standalone: depends only on fastapi + uvicorn (no jaclang). Each Jac',
        'walker is exposed as POST /walker/<name> with its fields as the request',
        'body; each public function as POST /function/<name>. Run with:',
        '    uvicorn main:app --reload',
        '"""',
        'from fastapi import FastAPI',
        'from pydantic import BaseModel',
        '',
        'from _osp import spawn, root'
    ];

    seen: set = set();
    for w in walkers {
        imp = "from " + str(w["module"]) + " import " + str(w["name"]);
        if imp not in seen {
            lines.append(imp);
            seen.add(imp);
        }
    }
    for f in functions {
        imp = "from " + str(f["module"]) + " import " + str(f["name"]);
        if imp not in seen {
            lines.append(imp);
            seen.add(imp);
        }
    }

    lines.append("");
    lines.append('app = FastAPI(title=' + repr(project_name) + ')');

    for w in walkers {
        wnm = str(w["name"]);
        model = _model_class_name(wnm);
        lines.append("");
        lines.append("");
        lines.append("class " + model + "(BaseModel):");
        if w["fields"] {
            for fld in w["fields"] {
                fname = str(fld["name"]);
                ftype = str(fld["type"]);
                if fld["has_default"] {
                    lines.append("    " + fname + ": " + ftype + " = " + str(fld["default"]));
                } else {
                    lines.append("    " + fname + ": " + ftype);
                }
            }
        } else {
            lines.append("    pass");
        }
        lines.append("");
        lines.append("");
        lines.append('@app.post("/walker/' + wnm + '")');
        lines.append("def run_" + wnm + "(body: " + model + ") -> dict:");
        lines.append("    walker = spawn(root(), " + wnm + "(**body.model_dump()))");
        lines.append('    return {"reports": getattr(walker, "reports", [])}');
    }

    for f in functions {
        fnm = str(f["name"]);
        model = _model_class_name(fnm);
        lines.append("");
        lines.append("");
        lines.append("class " + model + "(BaseModel):");
        if f["params"] {
            for p in f["params"] {
                lines.append("    " + str(p["name"]) + ": " + str(p["type"]));
            }
        } else {
            lines.append("    pass");
        }
        lines.append("");
        lines.append("");
        lines.append('@app.post("/function/' + fnm + '")');
        lines.append("def call_" + fnm + "(body: " + model + ") -> dict:");
        lines.append('    return {"result": ' + fnm + "(**body.model_dump())}");
    }

    walker_list_lit = "[" + ", ".join([repr(w["name"]) for w in walkers]) + "]";
    func_list_lit = "[" + ", ".join([repr(f["name"]) for f in functions]) + "]";
    lines.append("");
    lines.append("");
    lines.append('@app.get("/")');
    lines.append("def index() -> dict:");
    lines.append(
        '    return {"project": ' + repr(project_name)
        + ', "walkers": ' + walker_list_lit
        + ', "functions": ' + func_list_lit + "}"
    );
    lines.append("");
    lines.append("");
    lines.append('if __name__ == "__main__":');
    lines.append("    import uvicorn");
    lines.append('    uvicorn.run(app, host="0.0.0.0", port=8000)');
    lines.append("");

    (out / "main.py").write_text("\n".join(lines), encoding="utf-8");
}


"""Write requirements.txt: only fastapi + uvicorn (no jaclang)."""
def _emit_requirements(out: Path) {
    lines: list[str] = ["fastapi>=0.110", "uvicorn[standard]>=0.27"];
    (out / "requirements.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    );
}


"""Write a short README for the standalone backend."""
def _emit_readme(out: Path, project_name: str) {
    lines: list[str] = [
        f"# {project_name} (ejected standalone backend)",
        "",
        "Generated by `jac eject` with `[eject].target = \"backend\"`. Contains zero",
        "`.jac` files and no dependency on `jaclang`: every walker was compiled to",
        "Python whose runtime imports were rewritten to the vendored `_osp.py`, and",
        "each walker is exposed as a FastAPI endpoint.",
        "",
        "## Run it",
        "",
        "```bash",
        "pip install -r requirements.txt",
        "uvicorn main:app --reload",
        "```",
        "",
        "## Layout",
        "",
        "```",
        "main.py            FastAPI app, one POST /walker/<name> per walker",
        "_osp.py            standalone Object-Spatial micro-runtime",
        "<module>.py        compiled Jac modules (jaclib import rewritten to _osp)",
        "requirements.txt   fastapi + uvicorn",
        "```",
        "",
        "## Caveats (stage 1)",
        "",
        "- In-memory only: a fresh root node is created per request, with no",
        "  persistence between calls.",
        "- Walkers run their entry abilities on the spawn root; multi-node",
        "  traversal (`visit`/`connect`), permissions, and `by llm()` abilities",
        "  are not supported yet.",
        ""
    ];
    (out / "README.md").write_text("\n".join(lines), encoding="utf-8");
}
