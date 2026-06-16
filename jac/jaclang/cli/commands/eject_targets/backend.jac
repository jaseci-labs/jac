"""FastAPI backend emitter for `jac eject`: writes the compiled Jac modules
as-is (they import the real jaclang runtime) and a `main.py` that serves each
walker/function over the @jac/runtime HTTP contract, with jaclang-native auth."""

import ast;
import from pathlib { Path }
import from jaclang.cli.console { console }


# Modules we generate ourselves; a compiled module whose stem collides is
# renamed and references to it are rewritten across the other modules.
glob _RESERVED_MODULES: set = {"main"};


"""Emit the FastAPI backend into `backend_dir` from the orchestrator's
{module, py, server} units and [{name, module, pub}] walker/function
descriptors. `remap` renames module stems that collide with main.py."""
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
                "pub": bool(w["pub"]),
                "fields": walker_fields.get(wn, [])
            }
        );
    }
    functions_full: list = [];
    for f in functions {
        fn = str(f["name"]);
        functions_full.append(
            {
                "name": fn,
                "module": str(f["module"]),
                "pub": bool(f["pub"]),
                "params": func_params.get(fn, [])
            }
        );
    }

    _emit_main_py(backend_dir, project_name, walkers_full, functions_full);
    _emit_requirements(backend_dir);
    return 0;
}


"""Rewrite references to remapped sibling modules (a Jac module whose stem
collided with main.py). The jaclang runtime imports are left untouched."""
def _rewrite_imports(py_code: str, remap: dict) -> str {
    if not remap {
        return py_code;
    }
    out_lines: list[str] = [];
    for raw in py_code.splitlines() {
        line = raw;
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


"""Pydantic request-model name for a walker / function (Square -> SquareIn)."""
def _model_class_name(name: str) -> str {
    return name[:1].upper() + name[1:] + "In";
}


"""Write main.py: a FastAPI app running the walkers on the jaclang runtime
with jaclang-native auth (UserManager / ExecutionManager)."""
def _emit_main_py(
    backend_dir: Path, project_name: str, walkers: list, functions: list
) {
    lines: list[str] = [
        f'"""Auto-generated FastAPI app for the ejected Jac project {project_name!r}:',
        'runs the compiled walkers on the jaclang runtime with jaclang-native auth',
        '(register/login via UserManager; :pub walkers open, others token-gated)."""',
        'import inspect',
        'import json',
        'import os',
        '',
        'from fastapi import FastAPI, Header, HTTPException',
        'from fastapi.middleware.cors import CORSMiddleware',
        'from fastapi.responses import StreamingResponse',
        'from pydantic import BaseModel',
        '',
        'from jaclang.runtimelib.server import UserManager, ExecutionManager'
    ];

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

    lines += [
        '',
        '_BASE = os.path.dirname(os.path.abspath(__file__))',
        '_um = UserManager(base_path=_BASE)',
        '_em = ExecutionManager(base_path=_BASE, user_manager=_um)',
        '_GUEST = "__guest__"',
        '',
        '# Create the guest user (used by :pub endpoints) once at startup so',
        '# request handlers never race to create it. Swallow the duplicate error',
        '# when several workers start against the same database.',
        'try:',
        '    if not _um.user_exists(_GUEST):',
        '        _um.create_user(_GUEST, "__no_password__")',
        'except Exception:',
        '    pass',
        '',
        "app = FastAPI(title=" + repr(project_name) + ")",
        '# WARNING: wide-open CORS for local dev. Restrict allow_origins before',
        '# deploying this app to production.',
        'app.add_middleware(',
        '    CORSMiddleware,',
        '    allow_origins=["*"],',
        '    allow_methods=["*"],',
        '    allow_headers=["*"],',
        ')',
        '',
        '',
        'def _username(authorization, required):',
        '    """Resolve the caller: token -> user, else 401 (secured) or guest (:pub)."""',
        '    token = None',
        '    if authorization and authorization.startswith("Bearer "):',
        '        token = authorization[7:]',
        '    username = _um.validate_token(token) if token else None',
        '    if username:',
        '        return username',
        '    if required:',
        '        raise HTTPException(status_code=401, detail="Unauthorized")',
        '    return _GUEST',
        '',
        '',
        'class _Creds(BaseModel):',
        '    username: str',
        '    password: str',
        '',
        '',
        '@app.post("/user/register")',
        'def register(creds: _Creds) -> dict:',
        '    res = _um.create_user(creds.username, creds.password)',
        '    if res.get("error"):',
        '        raise HTTPException(status_code=400, detail=res["error"])',
        '    return res',
        '',
        '',
        '@app.post("/user/login")',
        'def login(creds: _Creds) -> dict:',
        '    res = _um.authenticate(creds.username, creds.password)',
        '    if not res:',
        '        raise HTTPException(status_code=401, detail="Invalid credentials")',
        '    return res',
        '',
        '',
        'async def _sse(stream):',
        '    """Stream a (sync or async) generator result as Server-Sent Events."""',
        '    if inspect.isasyncgen(stream):',
        '        async for chunk in stream:',
        '            yield _sse_line(chunk)',
        '    else:',
        '        for chunk in stream:',
        '            yield _sse_line(chunk)',
        '',
        '',
        'def _sse_line(chunk):',
        '    if isinstance(chunk, (bytes, bytearray)):',
        '        return bytes(chunk)',
        '    if isinstance(chunk, str):',
        '        return chunk.encode("utf-8")',
        '    return f"data: {json.dumps(chunk)}\\n\\n".encode("utf-8")',
        '',
        '',
        'def _respond(result):',
        '    """A streaming walker returns a generator; stream it as SSE.',
        '    Everything else is the normal JSON envelope."""',
        '    if inspect.isgenerator(result) or inspect.isasyncgen(result):',
        '        return StreamingResponse(_sse(result), media_type="text/event-stream")',
        '    return {"data": result}',
        '',
        '',
        'def _respond_fn(result):',
        '    """Function variant of _respond ({"ok": True, "data": ...} envelope)."""',
        '    if inspect.isgenerator(result) or inspect.isasyncgen(result):',
        '        return StreamingResponse(_sse(result), media_type="text/event-stream")',
        '    return {"ok": True, "data": result}'
    ];

    for w in walkers {
        wn = str(w["name"]);
        model = _model_class_name(wn);
        required = "False" if w["pub"] else "True";
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
            "async def run_" + wn + "(body: " + model + ", node_id: str = \"\", authorization: str = Header(default=None)):"
        );
        lines.append("    user = _username(authorization, " + required + ")");
        lines.append("    fields = dict(body.model_dump())");
        lines.append("    if node_id:");
        lines.append('        fields["_jac_spawn_node"] = node_id');
        lines.append(
            "    return _respond(await _em.spawn_walker(" + wn + ", fields, user))"
        );
    }

    for f in functions {
        fn = str(f["name"]);
        model = _model_class_name(fn);
        required = "False" if f["pub"] else "True";
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
        lines.append(
            "async def call_" + fn + "(body: " + model + ", authorization: str = Header(default=None)):"
        );
        lines.append("    user = _username(authorization, " + required + ")");
        lines.append(
            "    return _respond_fn(await _em.execute_function(" + fn + ", dict(body.model_dump()), user))"
        );
    }

    walker_list_lit = "[" + ", ".join([repr(str(w["name"])) for w in walkers]) + "]";
    func_list_lit = "[" + ", ".join([repr(str(f["name"])) for f in functions]) + "]";
    lines += [
        '',
        '',
        '@app.get("/__health")',
        'def __health() -> dict:',
        '    return {"project": ' + repr(project_name) + ', "walkers": ' + walker_list_lit + ', "functions": ' + func_list_lit + "}",
        '',
        '',
        '# Serve the built frontend (../frontend/dist) when present so one',
        '# `uvicorn main:app` serves API + UI on one origin. Mounted last.',
        '_FRONTEND_DIST = os.path.join(',
        '    os.path.dirname(os.path.abspath(__file__)), "..", "frontend", "dist"',
        ')',
        'if os.path.isdir(_FRONTEND_DIST):',
        '    from fastapi.staticfiles import StaticFiles',
        '    app.mount("/", StaticFiles(directory=_FRONTEND_DIST, html=True), name="frontend")',
        '',
        '',
        'if __name__ == "__main__":',
        '    import uvicorn',
        '    uvicorn.run(',
        '        app, host="0.0.0.0", port=int(os.environ.get("PORT", "8000"))',
        '    )',
        ''
    ];

    (backend_dir / "main.py").write_text("\n".join(lines), encoding="utf-8");
}


"""Resolve the jaclang requirement line, pinned to the build version."""
def _jaclang_req -> str {
    version = "";
    try {
        import jaclang;
        version = str(getattr(jaclang, "__version__", "") or "");
    } except Exception {
        version = "";
    }
    if version {
        return f"jaclang>={version}";
    }
    return "jaclang";
}


"""Write backend/requirements.txt: jaclang runtime + fastapi + uvicorn."""
def _emit_requirements(backend_dir: Path) {
    lines: list[str] = [_jaclang_req(), "fastapi>=0.110", "uvicorn[standard]>=0.27"];
    (backend_dir / "requirements.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    );
}
