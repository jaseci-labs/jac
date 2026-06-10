"""Standalone FastAPI backend emitter for `jac eject`: writes compiled Jac
modules (jaclib import rewritten to a vendored `_osp.py` in-memory runtime),
a `main.py` serving the @jac/runtime HTTP contract, and requirements.txt."""

import ast;
import from pathlib { Path }
import from jaclang.cli.console { console }


# The vendored Object-Spatial micro-runtime, written verbatim to backend/_osp.py.
# Built as a line list so the Python docstrings inside it do not terminate the
# surrounding Jac string.
glob _OSP_RUNTIME_LINES: list[str] = [
         '"""Standalone Object-Spatial micro-runtime for ejected Jac backends:',
         'jaclang-free walkers, in-memory graph (connect/visit/OPath) and report.',
         'The graph lives for the process lifetime; permissions/LLM unsupported."""',
         'from __future__ import annotations',
         '',
         'import threading',
         'import dataclasses',
         'from dataclasses import dataclass',
         '',
         '_state = threading.local()',
         '',
         '',
         'def field(factory=None, init=True):',
         '    """Mirror jaclib.field: factory -> default_factory, else plain field."""',
         '    if factory is not None:',
         '        return dataclasses.field(default_factory=factory)',
         '    return dataclasses.field(init=init)',
         '',
         '',
         'def on_entry(func):',
         '    func._osp_entry = True',
         '    return func',
         '',
         '',
         'def on_exit(func):',
         '    func._osp_exit = True',
         '    return func',
         '',
         '',
         'def set_trigger(trigger_thunk):',
         '    def deco(func):',
         '        func._osp_trigger = trigger_thunk',
         '        return func',
         '    return deco',
         '',
         '',
         'class _Archetype:',
         '    """Base for compiled archetypes: make each subclass a dataclass and',
         '    collect its entry/exit abilities (the part of jaclang make_archetype',
         '    the ejected code relies on)."""',
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
         '    def __post_init__(self):',
         '        # Per-instance graph adjacency (used by nodes; harmless on walkers).',
         '        self.__osp_out__ = []',
         '        self.__osp_in__ = []',
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
         '_ROOT = Root()',
         '',
         '',
         'def root():',
         '    """Return the process-shared in-memory root node (the graph',
         '    persists for the server process lifetime, not across restarts)."""',
         '    return _ROOT',
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
         'def _adj(node, attr):',
         '    edges = getattr(node, attr, None)',
         '    if edges is None:',
         '        edges = []',
         '        setattr(node, attr, edges)',
         '    return edges',
         '',
         '',
         'def connect(left=None, right=None, edge=None, undir=False, **kwargs):',
         '    """Create directed edges left -> right (Jac `++>`); return targets.',
         '    Edges are plain in-memory adjacency; typed `edge` archetypes are',
         '    accepted but not stored."""',
         '    sources = left if isinstance(left, (list, tuple)) else [left]',
         '    targets = right if isinstance(right, (list, tuple)) else [right]',
         '    made = []',
         '    for s in sources:',
         '        for t in targets:',
         '            _adj(s, "__osp_out__").append(t)',
         '            _adj(t, "__osp_in__").append(s)',
         '            if undir:',
         '                _adj(t, "__osp_out__").append(s)',
         '                _adj(s, "__osp_in__").append(t)',
         '            made.append(t)',
         '    return made',
         '',
         '',
         'def build_edge(*args, **kwargs):',
         '    """Edge-archetype factory placeholder (typed edges are not stored)."""',
         '    return None',
         '',
         '',
         'class OPath:',
         '    """Minimal path builder backing `[-->]` / `[<--]` traversals."""',
         '',
         '    def __init__(self, anchor):',
         '        if isinstance(anchor, (list, tuple)):',
         '            self._nodes = list(anchor)',
         '        else:',
         '            self._nodes = [anchor]',
         '',
         '    def edge_out(self):',
         '        nxt = []',
         '        for n in self._nodes:',
         '            nxt.extend(getattr(n, "__osp_out__", []))',
         '        self._nodes = nxt',
         '        return self',
         '',
         '    def edge_in(self):',
         '        nxt = []',
         '        for n in self._nodes:',
         '            nxt.extend(getattr(n, "__osp_in__", []))',
         '        self._nodes = nxt',
         '        return self',
         '',
         '    def edge_any(self):',
         '        nxt = []',
         '        for n in self._nodes:',
         '            nxt.extend(getattr(n, "__osp_out__", []))',
         '            nxt.extend(getattr(n, "__osp_in__", []))',
         '        self._nodes = nxt',
         '        return self',
         '',
         '    def visit(self):',
         '        return self',
         '',
         '    def __iter__(self):',
         '        return iter(self._nodes)',
         '',
         '',
         'def refs(obj):',
         '    """Resolve a path / iterable to a concrete list of nodes."""',
         '    if isinstance(obj, OPath):',
         '        return list(obj._nodes)',
         '    if isinstance(obj, (list, tuple)):',
         '        return list(obj)',
         '    return [obj]',
         '',
         '',
         'def visit(walker, targets):',
         '    """Enqueue targets onto the active walk (Jac `visit`)."""',
         '    if targets is None:',
         '        return False',
         '    queue = getattr(walker, "__osp_queue__", None)',
         '    if queue is None:',
         '        queue = []',
         '        walker.__osp_queue__ = queue',
         '    added = False',
         '    for t in refs(targets):',
         '        queue.append(t)',
         '        added = True',
         '    return added',
         '',
         '',
         'def disengage(walker):',
         '    """Halt the walk after the current ability (Jac `disengage`)."""',
         '    walker.__osp_queue__ = []',
         '    return True',
         '',
         '',
         'def spawn(op1, op2):',
         '    """Run a walker over the graph and return it (Jac `spawn`): fire',
         '    trigger-matched entry/exit abilities per location, grow the frontier',
         '    via `visit` (each node visited once), collect `reports`."""',
         '    if isinstance(op1, Walker):',
         '        walker, start = op1, op2',
         '    else:',
         '        walker, start = op2, op1',
         '    walker.reports = []',
         '    walker.__osp_queue__ = [start]',
         '    seen = set()',
         '    prev = getattr(_state, "walker", None)',
         '    _state.walker = walker',
         '    try:',
         '        while walker.__osp_queue__:',
         '            loc = walker.__osp_queue__.pop(0)',
         '            if id(loc) in seen:',
         '                continue',
         '            seen.add(id(loc))',
         '            for fn in type(walker)._osp_entries:',
         '                if _trigger_matches(fn, loc):',
         '                    fn(walker, loc)',
         '            for fn in type(walker)._osp_exits:',
         '                if _trigger_matches(fn, loc):',
         '                    fn(walker, loc)',
         '    finally:',
         '        _state.walker = prev',
         '    return walker',
         ''
     ];


"""Emit the FastAPI backend into `backend_dir` from the orchestrator's
{module, py, server} units and [{name, module}] walker/function descriptors.
`remap` renames module stems that collide with generated files (main/_osp)."""
def emit_backend(
    backend_dir: Path,
    project_name: str,
    compiled: list,
    walkers: list,
    functions: list,
    remap: dict
) -> int {
    backend_dir.mkdir(parents=True, exist_ok=True);

    walker_names: set = set();
    for w in walkers {
        walker_names.add(str(w["name"]));
    }
    func_names: set = set();
    for f in functions {
        func_names.add(str(f["name"]));
    }

    walker_fields: dict = {};
    func_params: dict = {};
    written = 0;
    for unit in compiled {
        if not unit["server"] {
            continue;
        }
        module = str(unit["module"]);
        code = _rewrite_imports(str(unit["py"]), remap);
        (backend_dir / f"{module}.py").write_text(code, encoding="utf-8");
        written += 1;
        walker_fields.update(_extract_walker_fields(code, walker_names));
        func_params.update(_extract_func_params(code, func_names));
    }
    if written == 0 {
        console.error("  backend: no server-side Python to emit.");
        return 1;
    }

    walkers_full: list = [];
    for w in walkers {
        wn = str(w["name"]);
        walkers_full.append(
            {
                "name": wn,
                "module": str(w["module"]),
                "fields": walker_fields.get(wn, [])
            }
        );
    }
    functions_full: list = [];
    for f in functions {
        fn = str(f["name"]);
        functions_full.append(
            {"name": fn, "module": str(f["module"]), "params": func_params.get(fn, [])}
        );
    }

    _emit_osp_runtime(backend_dir);
    _emit_main_py(backend_dir, project_name, walkers_full, functions_full);
    _emit_requirements(backend_dir);
    return 0;
}


"""Rewrite a compiled module's imports for the standalone output."""
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
                line = "from " + new_s + " import " + line[len(
                    "from " + orig_s + " import "
                ):];
            } elif (line == "import " + orig_s)
            or line.startswith("import " + orig_s + " ") {
                line = "import " + new_s + line[len("import " + orig_s):];
            }
        }
        out_lines.append(line);
    }
    return "\n".join(out_lines);
}


"""Extract each walker's request fields from the compiled Python, skipping
private names and the runtime-managed `reports` field. Returns
{walker_name: [{name, type, has_default, default}]}."""
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
                    default_src = ast.unparse(stmt.value)
                        if stmt.value is not None
                        else None;
                    fields.append(
                        {
                            "name": fname,
                            "type": ftype,
                            "has_default": has_default,
                            "default": default_src
                        }
                    );
                }
            }
            result[node.name] = fields;
        }
    }
    return result;
}


"""Extract each public function's parameters from the compiled Python."""
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
                ptype = ast.unparse(arg.annotation)
                    if arg.annotation is not None
                    else "object";
                params.append({"name": arg.arg, "type": ptype});
            }
            result[node.name] = params;
        }
    }
    return result;
}


"""Write the vendored micro-runtime to backend/_osp.py."""
def _emit_osp_runtime(backend_dir: Path) {
    (backend_dir / "_osp.py").write_text(
        "\n".join(_OSP_RUNTIME_LINES), encoding="utf-8"
    );
}


"""Pydantic request-model name for a walker / function (Square -> SquareIn)."""
def _model_class_name(name: str) -> str {
    return name[:1].upper() + name[1:] + "In";
}


"""Write main.py: the FastAPI app implementing the @jac/runtime HTTP contract."""
def _emit_main_py(
    backend_dir: Path, project_name: str, walkers: list, functions: list
) {
    lines: list[str] = [
        f'"""Auto-generated FastAPI app for ejected Jac project {project_name!r}:',
        'standalone (no jaclang), serves the @jac/runtime walker/function HTTP',
        'contract plus the built frontend (../frontend/dist) when present."""',
        'import os',
        'import dataclasses',
        '',
        'from fastapi import FastAPI',
        'from fastapi.middleware.cors import CORSMiddleware',
        'from pydantic import BaseModel',
        '',
        'from _osp import spawn, root'
    ];

    # Group walker/function imports by their source module.
    by_module: dict = {};
    order: list = [];
    for w in walkers {
        m = str(w["module"]);
        if m not in by_module {
            by_module[m] = [];
            order.append(m);
        }
        by_module[m].append(str(w["name"]));
    }
    for f in functions {
        m = str(f["module"]);
        if m not in by_module {
            by_module[m] = [];
            order.append(m);
        }
        by_module[m].append(str(f["name"]));
    }
    for m in order {
        names_here = [str(x) for x in by_module[m]];
        lines.append("from " + str(m) + " import " + ", ".join(names_here));
    }

    lines.append("");
    lines.append("app = FastAPI(title=" + repr(project_name) + ")");
    lines.append("app.add_middleware(");
    lines.append("    CORSMiddleware,");
    lines.append('    allow_origins=["*"],');
    lines.append('    allow_methods=["*"],');
    lines.append('    allow_headers=["*"],');
    lines.append(")");
    lines.append("");
    lines.append("");
    lines.append("def _walker_data(w):");
    lines.append(
        '    """Serialize a spawned walker for the client `{data}` envelope."""'
    );
    lines.append(
        "    data = {f.name: getattr(w, f.name) for f in dataclasses.fields(w)}"
    );
    lines.append('    data["reports"] = list(getattr(w, "reports", []))');
    lines.append("    return data");

    for w in walkers {
        wn = str(w["name"]);
        model = _model_class_name(wn);
        lines.append("");
        lines.append("");
        lines.append("class " + model + "(BaseModel):");
        if w["fields"] {
            for fld in w["fields"] {
                fname = str(fld["name"]);
                ftype = str(fld["type"]);
                if fld["has_default"] {
                    lines.append(
                        "    " + fname + ": " + ftype + " = " + str(fld["default"])
                    );
                } else {
                    lines.append("    " + fname + ": " + ftype);
                }
            }
        } else {
            lines.append("    pass");
        }
        lines.append("");
        lines.append("");
        lines.append('@app.post("/walker/' + wn + '")');
        lines.append('@app.post("/walker/' + wn + '/{node_id}")');
        lines.append(
            "def run_" + wn + "(body: " + model + ", node_id: str = \"\") -> dict:"
        );
        lines.append("    walker = spawn(root(), " + wn + "(**body.model_dump()))");
        lines.append('    return {"data": _walker_data(walker)}');
    }

    for f in functions {
        fn = str(f["name"]);
        model = _model_class_name(fn);
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
        lines.append('@app.post("/function/' + fn + '")');
        lines.append("def call_" + fn + "(body: " + model + ") -> dict:");
        lines.append(
            "    return {\"ok\": True, \"data\": {\"result\": " + fn + "(**body.model_dump())}}"
        );
    }

    walker_list_lit = "[" + ", ".join([repr(str(w["name"])) for w in walkers]) + "]";
    func_list_lit = "[" + ", ".join([repr(str(f["name"])) for f in functions]) + "]";
    lines.append("");
    lines.append("");
    lines.append('@app.get("/__health")');
    lines.append("def __health() -> dict:");
    lines.append(
        '    return {"project": ' + repr(project_name) + ', "walkers": ' + walker_list_lit + ', "functions": ' + func_list_lit + "}"
    );
    lines.append("");
    lines.append("");
    lines.append(
        "# Serve the built frontend (../frontend/dist) when present so a single"
    );
    lines.append(
        "# `uvicorn main:app` serves API + UI on one origin. Mounted last so the"
    );
    lines.append("# API routes above take precedence.");
    lines.append("_FRONTEND_DIST = os.path.join(");
    lines.append(
        '    os.path.dirname(os.path.abspath(__file__)), "..", "frontend", "dist"'
    );
    lines.append(")");
    lines.append("if os.path.isdir(_FRONTEND_DIST):");
    lines.append("    from fastapi.staticfiles import StaticFiles");
    lines.append(
        '    app.mount("/", StaticFiles(directory=_FRONTEND_DIST, html=True), name="frontend")'
    );
    lines.append("");
    lines.append("");
    lines.append('if __name__ == "__main__":');
    lines.append("    import uvicorn");
    lines.append('    uvicorn.run(');
    lines.append(
        '        app, host="0.0.0.0", port=int(os.environ.get("PORT", "8000"))'
    );
    lines.append("    )");
    lines.append("");

    (backend_dir / "main.py").write_text("\n".join(lines), encoding="utf-8");
}


"""Write backend/requirements.txt: only fastapi + uvicorn (no jaclang)."""
def _emit_requirements(backend_dir: Path) {
    lines: list[str] = ["fastapi>=0.110", "uvicorn[standard]>=0.27"];
    (backend_dir / "requirements.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    );
}
