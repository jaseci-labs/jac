"""FastAPI backend emitter for `jac eject`: writes the compiled Jac modules
as-is (they import the real jaclang runtime) and a `main.py` that serves each
walker/function over the @jac/runtime HTTP contract, with jaclang-native auth."""

import ast;
import from pathlib { Path }
import from jaclang.cli.console { console }


# jaclang companion packages a compiled module may import implicitly (not in
# jac.toml). Detected in the emitted Python and added to requirements.txt so
# `pip install` produces a runnable backend.
glob _IMPLICIT_PY_DEPS: dict = {
         "byllm": "byllm"
     };


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
    emitted_codes: list = [];
    written = 0;
    for unit in compiled {
        if not unit["server"] {
            continue;
        }
        module = str(unit["module"]);
        code = _rewrite_imports(str(unit["py"]), remap);
        # Dotted module (pkg.util) -> pkg/util.py, with __init__.py in each
        # package dir so the compiler's dotted imports resolve at runtime.
        dest = backend_dir / (module.replace(".", "/") + ".py");
        dest.parent.mkdir(parents=True, exist_ok=True);
        pkg_dir = dest.parent;
        while pkg_dir != backend_dir {
            init_file = pkg_dir / "__init__.py";
            if not init_file.exists() {
                init_file.write_text("", encoding="utf-8");
            }
            pkg_dir = pkg_dir.parent;
        }
        dest.write_text(code, encoding="utf-8");
        emitted_codes.append(code);
        written += 1;
        walker_fields.update(_extract_walker_fields(code, walker_names));
        func_params.update(_extract_func_params(code, func_names));
    }
    if written == 0 {
        console.error("  backend: no server-side Python to emit.");
        return 1;
    }

    # Each walker/function name maps 1:1 to an HTTP route and a main.py import,
    # so a name reused across modules would shadow the import and collide routes.
    dup = _first_duplicate([str(w["name"]) for w in walkers]);
    if dup {
        console.error(
            f"  backend: duplicate walker name '{dup}' across modules; "
            "walker names must be unique to expose them as endpoints."
        );
        return 1;
    }
    dup = _first_duplicate([str(f["name"]) for f in functions]);
    if dup {
        console.error(
            f"  backend: duplicate function name '{dup}' across modules; "
            "function names must be unique to expose them as endpoints."
        );
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
    _emit_requirements(backend_dir, _detect_plugins(emitted_codes));
    return 0;
}


"""Return the first name that repeats in `names`, or "" if all are unique."""
def _first_duplicate(names: list) -> str {
    seen: set = set();
    for n in names {
        s = str(n);
        if s in seen {
            return s;
        }
        seen.add(s);
    }
    return "";
}


"""Scan emitted backend Python for imports of known jaclang companion
packages (byllm, ...) and return the pip names to add."""
def _detect_plugins(codes: list) -> list {
    found: set = set();
    for code in codes {
        for raw in str(code).splitlines() {
            line = raw.strip();
            for (mod, pkg) in _IMPLICIT_PY_DEPS.items() {
                m = str(mod);
                if (line == "import " + m)
                or line.startswith("import " + m + " ")
                or line.startswith("import " + m + ".")
                or line.startswith("from " + m + " ")
                or line.startswith("from " + m + ".") {
                    found.add(str(pkg));
                }
            }
        }
    }
    return sorted(list(found));
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


"""Extract each public function's parameters (with defaults) from the
compiled Python. Returns {func_name: [{name, type, has_default, default}]}."""
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
            all_args = node.args.args;
            defaults = node.args.defaults;
            # Python aligns the defaults list to the LAST len(defaults) args.
            first_default = len(all_args) - len(defaults);
            params: list = [];
            for i in range(len(all_args)) {
                arg = all_args[i];
                if arg.arg == "self" {
                    continue;
                }
                ptype = ast.unparse(arg.annotation)
                    if arg.annotation is not None
                    else "object";
                has_default = i >= first_default;
                default_src = ast.unparse(defaults[i - first_default])
                    if has_default
                    else None;
                params.append(
                    {
                        "name": arg.arg,
                        "type": ptype,
                        "has_default": has_default,
                        "default": default_src
                    }
                );
            }
            result[node.name] = params;
        }
    }
    return result;
}


"""Pydantic request-model name. The `suffix` keeps walker and function models
in separate namespaces so a name reused across both kinds does not collide
(walker Square -> SquareIn, function Square -> SquareFnIn)."""
def _model_class_name(name: str, suffix: str) -> str {
    return name[:1].upper() + name[1:] + suffix;
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

    # Import each walker/function under a kind-prefixed alias (_W_ / _F_) so a
    # name reused across a walker and a function (or modules) never shadows.
    for w in walkers {
        wn = str(w["name"]);
        lines.append("from " + str(w["module"]) + " import " + wn + " as _W_" + wn);
    }
    for f in functions {
        fn = str(f["name"]);
        lines.append("from " + str(f["module"]) + " import " + fn + " as _F_" + fn);
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
        '    """Frame any chunk as a Server-Sent Event (`data: ...` per line)."""',
        '    if isinstance(chunk, (bytes, bytearray)):',
        '        text = bytes(chunk).decode("utf-8", "replace")',
        '    elif isinstance(chunk, str):',
        '        text = chunk',
        '    else:',
        '        text = json.dumps(chunk)',
        '    framed = "".join("data: " + line + "\\n" for line in text.split("\\n"))',
        '    return (framed + "\\n").encode("utf-8")',
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
        model = _model_class_name(wn, "In");
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
            "    return _respond(await _em.spawn_walker(_W_" + wn + ", fields, user))"
        );
    }

    for f in functions {
        fn = str(f["name"]);
        model = _model_class_name(fn, "FnIn");
        required = "False" if f["pub"] else "True";
        lines.append("");
        lines.append("");
        lines.append("class " + model + "(BaseModel):");
        if f["params"] {
            for p in f["params"] {
                pname = str(p["name"]);
                ptype = str(p["type"]);
                if p["has_default"] {
                    lines.append(
                        "    " + pname + ": " + ptype + " = " + str(p["default"])
                    );
                } else {
                    lines.append("    " + pname + ": " + ptype);
                }
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
            "    return _respond_fn(await _em.execute_function(_F_" + fn + ", dict(body.model_dump()), user))"
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


"""Write backend/requirements.txt: jaclang + fastapi + uvicorn, plus any
implicit jaclang companion packages detected in the emitted Python."""
def _emit_requirements(backend_dir: Path, plugins: list) {
    lines: list[str] = [_jaclang_req(), "fastapi>=0.110", "uvicorn[standard]>=0.27"];
    for p in plugins {
        lines.append(str(p));
    }
    (backend_dir / "requirements.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    );
}
