import ast;
import from pathlib { Path }
import from jaclang.cli.console { console }


def emit_backend(
    backend_dir: Path,
    project_name: str,
    compiled: list,
    walkers: list,
    functions: list,
    remap: dict,
    db: dict
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

    sql = str(db.get("driver", "")).lower() in ["sqlalchemy", "sqlite", "sql"];
    db_basename = _default_db_basename(project_name) if sql else "";
    if sql {
        console.print(
            "  ✔ SQLAlchemy persistence (vendored runtime backend)", style="success"
        );
    }

    _emit_main_py(
        backend_dir, project_name, walkers_full, functions_full, sql, db_basename
    );

    import from jaclang.cli.commands.eject_targets.runtime_vendor {
        vendor_runtime,
        llm_requirements
    }
    uses_llm = _uses_llm(emitted_codes);
    sql_seeds = ["jaclang.runtimelib.storage.sqlalchemy_memory"] if sql else [];
    vendored = vendor_runtime(
        backend_dir, emitted_codes, include_byllm=uses_llm, extra_seeds=sql_seeds
    );
    if vendored < 0 {
        return 1;
    }
    console.print(
        f"  ✔ vendored jaclang runtime ({vendored} modules" + (
            ", incl. byllm" if uses_llm else ""
        ) + ")",
        style="success"
    );

    reqs: list[str] = [];
    if sql {
        reqs.append("SQLAlchemy>=2.0");
    }
    if uses_llm {
        reqs.extend(llm_requirements());
    }
    _emit_requirements(backend_dir, reqs);
    return 0;
}


def _default_db_basename(project_name: str) -> str {
    chars: list = [];
    for ch in project_name.lower() {
        chars.append(ch if ch.isalnum() else "_");
    }
    name = "".join(chars).strip("_");
    return name or "jac_db";
}


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


def _uses_llm(codes: list) -> bool {
    for code in codes {
        for raw in str(code).splitlines() {
            line = raw.strip();
            for m in ["byllm", "jaclang.byllm"] {
                if (line == "import " + m)
                or line.startswith("import " + m + " ")
                or line.startswith("import " + m + ".")
                or line.startswith("from " + m + " ")
                or line.startswith("from " + m + ".") {
                    return True;
                }
            }
        }
    }
    return False;
}


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


glob _RUNTIME_ARCH_BASES: set = {
         "Walker",
         "WalkerArchetype",
         "Archetype",
         "NodeArchetype",
         "EdgeArchetype",
         "Node",
         "Edge",
         "object"
     };


def _extract_walker_fields(py_code: str, walker_names: set) -> dict {
    result: dict = {};
    try {
        tree = ast.parse(py_code);
    } except Exception {
        return result;
    }
    class_map: dict[str, ast.ClassDef] = {};
    for n in tree.body {
        if isinstance(n, ast.ClassDef) {
            class_map[n.name] = n;
        }
    }
    for node in tree.body {
        if isinstance(node, ast.ClassDef) and (node.name in walker_names) {
            ordered: dict = {};
            unresolved: set = set();
            _collect_walker_fields(node, class_map, ordered, unresolved, set());
            result[node.name] = list(ordered.values());
            for b in sorted(list(unresolved)) {
                console.warning(
                    f"  backend: walker '{node.name}' inherits from '{b}', which "
                    "is not in the same module; any required fields it declares "
                    "will be missing from the generated request model."
                );
            }
        }
    }
    return result;
}


def _collect_walker_fields(
    cls_node: ast.ClassDef,
    class_map: dict[str, ast.ClassDef],
    ordered: dict,
    unresolved: set,
    visited: set
) {
    if cls_node.name in visited {
        return;
    }
    visited.add(cls_node.name);
    for base in cls_node.bases {
        bname = ast.unparse(base);
        if bname in class_map {
            _collect_walker_fields(
                class_map[bname], class_map, ordered, unresolved, visited
            );
        } elif bname not in _RUNTIME_ARCH_BASES {
            unresolved.add(bname);
        }
    }
    for stmt in cls_node.body {
        if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name) {
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
            ordered[fname] = {
                "name": fname,
                "type": ftype,
                "has_default": has_default,
                "default": default_src
            };
        }
    }
}


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


def _model_class_name(name: str, suffix: str) -> str {
    return name[:1].upper() + name[1:] + suffix;
}


def _emit_main_py(
    backend_dir: Path,
    project_name: str,
    walkers: list,
    functions: list,
    sql: bool,
    db_basename: str
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

    for w in walkers {
        wn = str(w["name"]);
        lines.append("from " + str(w["module"]) + " import " + wn + " as _W_" + wn);
    }
    for f in functions {
        fn = str(f["name"]);
        lines.append("from " + str(f["module"]) + " import " + fn + " as _F_" + fn);
    }

    lines += ['', '_BASE = os.path.dirname(os.path.abspath(__file__))'];

    if sql {
        lines += [
            'from jaclang.jac0core.runtime import hookimpl, plugin_manager',
            'from jaclang.runtimelib.storage.sqlalchemy_memory import SqlAlchemyMemory',
            '',
            '_DB_URL = os.environ.get("JAC_DB_URL") or (',
            '    "sqlite:///" + os.path.join(_BASE, ' + repr(
                str(db_basename) + ".db"
            ) + ')',
            ')',
            '',
            '',
            'class _EjectSqlPlugin:',
            '    @hookimpl',
            '    def get_persistent_memory(self, config):',
            '        return SqlAlchemyMemory(_DB_URL)',
            '',
            '',
            'plugin_manager.register(_EjectSqlPlugin())'
        ];
    }

    lines += [
        '',
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
        '# Auth wire format matches the @jac/runtime client: register/login send',
        '# {identit(y|ies), credential} and login replies {"data":{"token":...}}.',
        '# Flat {username,password} is also accepted so curl/other clients work.',
        'class _Identity(BaseModel):',
        '    type: str = "username"',
        '    value: str',
        '',
        '',
        'class _Credential(BaseModel):',
        '    type: str = "password"',
        '    password: str',
        '',
        '',
        'class _RegisterReq(BaseModel):',
        '    identities: list[_Identity] | None = None',
        '    credential: _Credential | None = None',
        '    username: str | None = None',
        '    password: str | None = None',
        '    profile: dict | None = None',
        '',
        '',
        'class _LoginReq(BaseModel):',
        '    identity: _Identity | None = None',
        '    credential: _Credential | None = None',
        '    username: str | None = None',
        '    password: str | None = None',
        '',
        '',
        'def _creds_from_register(req):',
        '    if req.identities and req.credential:',
        '        return req.identities[0].value, req.credential.password',
        '    return req.username, req.password',
        '',
        '',
        'def _creds_from_login(req):',
        '    if req.identity and req.credential:',
        '        return req.identity.value, req.credential.password',
        '    return req.username, req.password',
        '',
        '',
        '@app.post("/user/register")',
        'def register(req: _RegisterReq) -> dict:',
        '    username, password = _creds_from_register(req)',
        '    if not username or not password:',
        '        raise HTTPException(status_code=422, detail="username and password required")',
        '    res = _um.create_user(username, password)',
        '    if res.get("error"):',
        '        raise HTTPException(status_code=400, detail=res["error"])',
        '    return {"data": res}',
        '',
        '',
        '@app.post("/user/login")',
        'def login(req: _LoginReq) -> dict:',
        '    username, password = _creds_from_login(req)',
        '    res = _um.authenticate(username, password) if username and password else None',
        '    if not res:',
        '        raise HTTPException(status_code=401, detail="Invalid credentials")',
        '    return {"data": res}',
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


def _emit_requirements(backend_dir: Path, extra_reqs: list) {
    lines: list[str] = ["fastapi>=0.110", "uvicorn[standard]>=0.27"];
    for req in extra_reqs {
        lines.append(str(req));
    }
    (backend_dir / "requirements.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    );
}
