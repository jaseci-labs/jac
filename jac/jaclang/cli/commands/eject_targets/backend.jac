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
    db: dict,
    project_deps: (list | None) = None,
    has_env: bool = False,
    entry_module: str = "",
    mtir_map: (dict | None) = None
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
        if not unit["emit"] {
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
        backend_dir,
        project_name,
        walkers_full,
        functions_full,
        sql,
        db_basename,
        has_env,
        entry_module
    );

    import from jaclang.publish.runtime_vendor { vendor_runtime }
    uses_llm = _uses_llm(emitted_codes);
    sql_seeds = ["jaclang.runtimelib.storage.sqlalchemy_memory"] if sql else [];
    try {
        vendored = vendor_runtime(
            backend_dir, emitted_codes, include_byllm=uses_llm, extra_seeds=sql_seeds
        );
    } except ValueError as e {
        console.error(f"  {e}");
        return 1;
    }
    console.print(
        f"  ✔ vendored jaclang runtime ({vendored} modules" + (
            ", incl. byllm" if uses_llm else ""
        ) + ")",
        style="success"
    );

    needs_kv = _emit_scale_adapters(backend_dir, emitted_codes);

    if mtir_map {
        (backend_dir / "mtir_data.py").write_text(
            _mtir_module_source(mtir_map), encoding="utf-8"
        );
        console.print(
            f"  ✔ meaning-typed metadata ({len(mtir_map)} scopes -> mtir_data.py)",
            style="success"
        );
    }

    uses_upload = _uses_upload(walkers_full, functions_full);

    detected_caps: set = set();
    if sql {
        detected_caps.add("data.sql");
    }
    if uses_llm {
        detected_caps.add("llm");
    }
    if has_env {
        detected_caps.add("env");
    }
    if uses_upload {
        detected_caps.add("upload");
    }
    if needs_kv {
        detected_caps.add("data.redis");
    }
    reqs: list[str] = [str(dep) for dep in (project_deps or [])];
    reqs.extend(_capability_requirements(detected_caps));
    _emit_requirements(backend_dir, reqs);
    return 0;
}


def _mtir_literal(val: object, indent: int, classes: set) -> str {
    pad = "    " * indent;
    if val is None {
        return "None";
    }
    if isinstance(val, bool) {
        return "True" if val else "False";
    }
    if isinstance(val, (str, int, float)) {
        return repr(val);
    }
    if isinstance(val, `tuple) {
        if not val {
            return "()";
        }
        inner = ", ".join([_mtir_literal(x, indent, classes) for x in val]);
        if len(val) == 1 {
            return "(" + inner + ",)";
        }
        return "(" + inner + ")";
    }
    if isinstance(val, list) {
        if not val {
            return "[]";
        }
        items = [pad + "    " + _mtir_literal(x, indent + 1, classes) for x in val];
        return "[\n" + ",\n".join(items) + "\n" + pad + "]";
    }
    cls = type(val).__name__;
    fields = val?.__dict__;
    if fields is None {
        raise ValueError(f"eject: cannot lower MTIR value of type {cls} to source");
    }
    classes.add(cls);
    parts = [];
    for key in sorted(fields.keys()) {
        parts.append(
            pad + "    " + str(key) + "=" + _mtir_literal(
                fields[key], indent + 1, classes
            )
        );
    }
    if not parts {
        return cls + "()";
    }
    return cls + "(\n" + ",\n".join(parts) + "\n" + pad + ")";
}


def _mtir_module_source(mtir_map: dict) -> str {
    classes: set = set();
    entries = [];
    for scope in sorted(mtir_map.keys()) {
        entries.append(
            "    " + repr(str(scope)) + ": " + _mtir_literal(
                mtir_map[scope], 1, classes
            )
        );
    }
    header = [
        '"""Meaning-typed metadata captured at build time.',
        "",
        "The compiler records the semstrings, parameter and return-type structure",
        "behind every `by llm()` call. That pass does not exist in a converted app,",
        "so the map is emitted here as plain source and hydrated at boot.",
        '"""',
        ""
    ];
    if classes {
        header.append("from jaclang.jac0core.mtp import " + ", ".join(sorted(classes)));
        header.append("");
    }
    body = "MTIR_DATA = {\n" + ",\n".join(entries) + "\n}\n";
    return "\n".join(header) + "\n" + body;
}


def _emit_scale_adapters(backend_dir: Path, emitted_codes: list) -> bool {
    needs_kv = False;
    needs_events = False;
    for code in emitted_codes {
        for raw in str(code).splitlines() {
            line = raw.strip();
            if line.startswith("from jaclang.scale.persistence.lib import") {
                needs_kv = True;
            }
            if line.startswith("from jaclang.scale.events.") {
                needs_events = True;
            }
        }
    }
    if not needs_kv and not needs_events {
        return False;
    }
    scale_dir = backend_dir / "jaclang" / "scale";
    scale_dir.mkdir(parents=True, exist_ok=True);
    (scale_dir / "__init__.py").write_text("", encoding="utf-8");
    if needs_kv {
        pdir = scale_dir / "persistence";
        pdir.mkdir(parents=True, exist_ok=True);
        (pdir / "__init__.py").write_text("", encoding="utf-8");
        (pdir / "lib.py").write_text(_KV_ADAPTER, encoding="utf-8");
        console.print("  ✔ kvstore adapter (redis-py)", style="success");
    }
    if needs_events {
        edir = scale_dir / "events";
        edir.mkdir(parents=True, exist_ok=True);
        (edir / "__init__.py").write_text("", encoding="utf-8");
        (edir / "broker.py").write_text(_EVENTS_BROKER, encoding="utf-8");
        (edir / "subscriber.py").write_text(_EVENTS_SUBSCRIBER, encoding="utf-8");
        (edir / "publisher.py").write_text(_EVENTS_PUBLISHER, encoding="utf-8");
        console.print("  ✔ events adapter (in-process broker)", style="success");
    }
    return needs_kv;
}


glob _KV_ADAPTER: str = (
         '"""Ejected adapter for jaclang.scale.persistence.lib: redis-py kvstore."""\n'
         "import json\n"
         "import os\n"
         "\n"
         "\n"
         "class RedisKv:\n"
         "    def __init__(self, client, db_name):\n"
         "        self._r = client\n"
         "        self._prefix = db_name\n"
         "\n"
         "    def _k(self, key, col_name):\n"
         '        return self._prefix + ":" + col_name + ":" + key\n'
         "\n"
         '    def set(self, key, value, col_name="default"):\n'
         "        self._r.set(self._k(key, col_name), json.dumps(value))\n"
         "        return key\n"
         "\n"
         '    def get(self, key, col_name="default"):\n'
         "        raw = self._r.get(self._k(key, col_name))\n"
         "        return json.loads(raw) if raw is not None else None\n"
         "\n"
         '    def delete(self, key, col_name="default"):\n'
         "        return int(self._r.delete(self._k(key, col_name)))\n"
         "\n"
         "\n"
         'def kvstore(db_name="jac_db", db_type="redis", uri=None):\n'
         '    if db_type != "redis":\n'
         "        raise RuntimeError(\n"
         '            "ejected kvstore supports db_type=\'redis\' only (got %r)" % db_type\n'
         "        )\n"
         '    url = uri or os.environ.get("REDIS_URL")\n'
         "    if not url:\n"
         '        raise RuntimeError("Redis URL not found in configuration")\n'
         "    import redis\n"
         "    return RedisKv(redis.Redis.from_url(url), db_name)\n"
     ),
     _EVENTS_BROKER: str = (
         '"""Ejected adapter for jaclang.scale.events.broker."""\n'
         "import time\n"
         "import uuid\n"
         "\n"
         "\n"
         "class Event:\n"
         "    def __init__(self, event_type='', data=None, key=None, id=None, ts=None):\n"
         "        self.event_type = event_type\n"
         "        self.data = data if data is not None else {}\n"
         "        self.key = key\n"
         "        self.id = id or uuid.uuid4().hex\n"
         "        self.ts = ts or time.time()\n"
     ),
     _EVENTS_SUBSCRIBER: str = (
         '"""Ejected adapter for jaclang.scale.events.subscriber."""\n'
         "_subscriptions = []\n"
         "\n"
         "\n"
         "class _Subscription:\n"
         "    def __init__(self, topic, handler, group=None, retry=None):\n"
         "        self.topic = topic\n"
         "        self.handler = handler\n"
         "        self.group = group\n"
         "        self.retry = retry\n"
         "\n"
         "\n"
         "def subscribe(topic, group=None, retry=None):\n"
         "    def _register(handler):\n"
         "        _subscriptions.append(_Subscription(topic, handler, group, retry))\n"
         "        return handler\n"
         "    return _register\n"
         "\n"
         "\n"
         "def get_subscriptions():\n"
         "    return list(_subscriptions)\n"
     ),
     _EVENTS_PUBLISHER: str = (
         '"""Ejected adapter for jaclang.scale.events.publisher: in-process\n'
         'dispatch to @subscribe handlers (single-process parity with the\n'
         'LocalEventStream default)."""\n'
         "import logging\n"
         "\n"
         "from jaclang.scale.events.subscriber import get_subscriptions\n"
         "\n"
         "logger = logging.getLogger(__name__)\n"
         "_broker = None\n"
         "\n"
         "\n"
         "def set_broker(broker):\n"
         "    global _broker\n"
         "    _broker = broker\n"
         "\n"
         "\n"
         "def publish(topic, event, key=None):\n"
         "    delivered = False\n"
         "    for sub in get_subscriptions():\n"
         "        if sub.topic == topic:\n"
         "            try:\n"
         "                sub.handler(event)\n"
         "                delivered = True\n"
         "            except Exception:\n"
         '                logger.exception("event handler for %r failed", topic)\n'
         "    return delivered\n"
     );


def _capability_requirements(caps: set) -> list[str] {
    import from jaclang.project.capabilities {
        RUNTIME,
        get_capability_registry,
        resolve_closure
    }
    import from jaclang.project.pyvenv { make_pip_spec }
    if not caps {
        return [];
    }
    closure = resolve_closure(caps, RUNTIME);
    registry = get_capability_registry();
    lines: list[str] = [];
    for cap_name in closure.capabilities {
        for (pkg, ver) in sorted(registry[cap_name].deps.items()) {
            lines.append(f"{make_pip_spec(pkg, ver)}  # via capability:{cap_name}");
        }
    }
    return lines;
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


def _is_upload_type(ptype: str) -> bool {
    return "UploadFile" in str(ptype);
}


def _uses_upload(walkers: list, functions: list) -> bool {
    for f in functions {
        for p in f["params"] {
            if _is_upload_type(str(p["type"])) {
                return True;
            }
        }
    }
    for w in walkers {
        for fld in w["fields"] {
            if _is_upload_type(str(fld["type"])) {
                return True;
            }
        }
    }
    return False;
}


glob _JSON_SAFE_TYPE_NAMES: set = {
         "str",
         "int",
         "float",
         "bool",
         "bytes",
         "complex",
         "list",
         "dict",
         "tuple",
         "set",
         "frozenset",
         "None",
         "Any",
         "object",
         "Optional",
         "Union",
         "List",
         "Dict",
         "Tuple",
         "Set",
         "Sequence",
         "Mapping",
         "Iterable",
         "Literal"
     };


def _safe_model_type(ftype: str) -> str {
    try {
        tree = ast.parse(ftype, mode="eval");
    } except Exception {
        return "Any";
    }
    for sub in ast.walk(tree) {
        if isinstance(sub, ast.Name) and (sub.id not in _JSON_SAFE_TYPE_NAMES) {
            return "Any";
        }
    }
    return ftype;
}


def _safe_model_default(default_src: str) -> str {
    try {
        expr = ast.parse(default_src, mode="eval").body;
    } except Exception {
        return "None";
    }
    if isinstance(expr, ast.Call)
    and isinstance(expr.func, ast.Name)
    and (expr.func.id == "field") {
        inner = None;
        for kw in expr.keywords {
            if (kw.arg in ["factory", "default_factory"])
            and isinstance(kw.value, ast.Lambda) {
                inner = kw.value.body;
            } elif kw.arg == "default" {
                inner = kw.value;
            }
        }
        if inner is None {
            return "None";
        }
        expr = inner;
    }
    try {
        ast.literal_eval(expr);
    } except Exception {
        return "None";
    }
    return ast.unparse(expr);
}


def _emit_main_py(
    backend_dir: Path,
    project_name: str,
    walkers: list,
    functions: list,
    sql: bool,
    db_basename: str,
    has_env: bool,
    entry_module: str
) {
    uses_upload = _uses_upload(walkers, functions);
    fastapi_import = (
        "from fastapi import FastAPI, Header, HTTPException, "
        "Path as _PathParam, Query, "
        "Request, WebSocket, WebSocketDisconnect"
    );
    if uses_upload {
        fastapi_import += ", File, Form, UploadFile";
    }
    lines: list[str] = [
        f'"""Auto-generated FastAPI app for the ejected Jac project {project_name!r}:',
        'runs the compiled walkers on the jaclang runtime with jaclang-native auth',
        '(register/login via UserManager; :pub walkers open, others token-gated)."""',
        'import datetime',
        'import hashlib',
        'import hmac',
        'import inspect',
        'import json',
        'import os',
        'import re',
        'import secrets',
        'import sqlite3',
        'import time',
        'import traceback',
        'from typing import '
        'Any, Dict, Iterable, List, Literal, Mapping, '
        'Optional, Sequence, Set, Tuple, Union',
        '',
        fastapi_import,
        'from fastapi.middleware.cors import CORSMiddleware',
        'from fastapi.responses import JSONResponse, StreamingResponse',
        'from pydantic import BaseModel',
        '',
        '_BASE = os.path.dirname(os.path.abspath(__file__))'
    ];

    if has_env {
        lines += [
            '',
            '# Load .env (backend/.env first, then the project root) before the',
            '# project modules import: they may read os.environ at import time.',
            'try:',
            '    from dotenv import load_dotenv',
            'except ImportError:',
            '    load_dotenv = None',
            'if load_dotenv is not None:',
            '    for _env_file in (',
            '        os.path.join(_BASE, ".env"),',
            '        os.path.join(_BASE, "..", ".env"),',
            '    ):',
            '        if os.path.isfile(_env_file):',
            '            load_dotenv(_env_file)'
        ];
    }

    lines += [
        '',
        'from jaclang.runtimelib.server import UserManager, ExecutionManager',
        'from jaclang.runtimelib.serializer import Serializer as _Serializer',
        'from jaclang.runtimelib.scheduler import Scheduler as _Scheduler',
        'from jaclang.jac0core.mtp import MTIR_OVERLAY as _MTIR_OVERLAY',
        '',
        '# Meaning-typed metadata: prompts/schemas for `by llm()` calls are',
        '# synthesized from this compiler-captured map; without it the runtime',
        '# falls back to bare introspection and prompts silently drift.',
        'try:',
        '    from mtir_data import MTIR_DATA as _MTIR_DATA',
        'except ImportError:',
        '    _MTIR_DATA = {}',
        '_MTIR_OVERLAY.update(_MTIR_DATA)'
    ];

    if entry_module {
        lines += [
            '',
            '# Import the entry module for its side effects: its `with entry`',
            '# code runs at server boot, as it would under `jac start`.',
            'import ' + entry_module
        ];
    }

    for w in walkers {
        wn = str(w["name"]);
        lines.append("from " + str(w["module"]) + " import " + wn + " as _W_" + wn);
    }
    for f in functions {
        fn = str(f["name"]);
        lines.append("from " + str(f["module"]) + " import " + fn + " as _F_" + fn);
    }

    if sql {
        lines += [
            'from jaclang.jac0core.runtime import JacRuntime as _Jac',
            'from jaclang.runtimelib.storage.sqlalchemy_memory import SqlAlchemyMemory',
            '',
            '_DB_URL = os.environ.get("JAC_DB_URL") or (',
            '    "sqlite:///" + os.path.join(_BASE, ' + repr(
                str(db_basename) + ".db"
            ) + ')',
            ')',
            '',
            '',
            '_Jac.set_persistent_memory_provider(',
            '    lambda config: SqlAlchemyMemory(_DB_URL)',
            ')'
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
        '@app.post("/user/register", status_code=201)',
        'def register(req: _RegisterReq) -> dict:',
        '    username, password = _creds_from_register(req)',
        '    if not username or not password:',
        '        raise HTTPException(status_code=422, detail="username and password required")',
        '    res = _um.create_user(username, password)',
        '    if res.get("error"):',
        '        raise HTTPException(status_code=400, detail=res["error"])',
        '    return _envelope(',
        '        {"user_id": res.get("root_id"), "message": "User registered successfully"},',
        '        201,',
        '    )',
        '',
        '',
        '@app.post("/user/login")',
        'def login(req: _LoginReq) -> dict:',
        '    username, password = _creds_from_login(req)',
        '    res = _um.authenticate(username, password) if username and password else None',
        '    if not res:',
        '        raise HTTPException(status_code=401, detail="Invalid credentials")',
        '    return _envelope({',
        '        "user_id": res.get("root_id"),',
        '        "root_id": res.get("root_id"),',
        '        "role": "user",',
        '        "token": res.get("token"),',
        '    })',
        '',
        '',
        '_APIKEY_DB = os.path.join(_BASE, ".jac", "data", "apikeys.db")',
        '',
        '',
        'def _apikey_conn():',
        '    os.makedirs(os.path.dirname(_APIKEY_DB), exist_ok=True)',
        '    conn = sqlite3.connect(_APIKEY_DB)',
        '    conn.execute(',
        '        "CREATE TABLE IF NOT EXISTS api_keys ("',
        '        "key_id TEXT PRIMARY KEY, api_key TEXT UNIQUE, user TEXT, "',
        '        "name TEXT, signing_secret TEXT, created_at TEXT, expires_at TEXT)"',
        '    )',
        '    return conn',
        '',
        '',
        'class _ApiKeyReq(BaseModel):',
        '    name: str',
        '    expiry_days: int | None = None',
        '    allowed_walkers: str | None = None',
        '',
        '',
        '@app.post("/api-key/create", status_code=201)',
        'def create_api_key(req: _ApiKeyReq, authorization: str = Header(default=None)):',
        '    user = _username(authorization, True)',
        '    key_id = secrets.token_hex(16)',
        '    api_key = secrets.token_urlsafe(32)',
        '    signing_secret = secrets.token_hex(32)',
        '    now = datetime.datetime.now(datetime.timezone.utc)',
        '    expires = (',
        '        now + datetime.timedelta(days=req.expiry_days) if req.expiry_days else None',
        '    )',
        '    conn = _apikey_conn()',
        '    with conn:',
        '        conn.execute(',
        '            "INSERT INTO api_keys VALUES (?, ?, ?, ?, ?, ?, ?)",',
        '            (',
        '                key_id, api_key, user, req.name, signing_secret,',
        '                now.isoformat(), expires.isoformat() if expires else None,',
        '            ),',
        '        )',
        '    conn.close()',
        '    return _envelope({',
        '        "api_key": api_key,',
        '        "api_key_id": key_id,',
        '        "name": req.name,',
        '        "created_at": now.isoformat(),',
        '        "expires_at": expires.isoformat() if expires else None,',
        '        "signing_secret": signing_secret,',
        '    }, 201)',
        '',
        '',
        'def _resolve_api_key(api_key):',
        '    conn = _apikey_conn()',
        '    row = conn.execute(',
        '        "SELECT user, signing_secret, expires_at FROM api_keys WHERE api_key = ?",',
        '        (api_key,),',
        '    ).fetchone()',
        '    conn.close()',
        '    if not row:',
        '        return None',
        '    user, signing_secret, expires_at = row',
        '    if expires_at:',
        '        try:',
        '            expiry = datetime.datetime.fromisoformat(expires_at)',
        '            if expiry < datetime.datetime.now(datetime.timezone.utc):',
        '                return None',
        '        except ValueError:',
        '            pass',
        '    return {"user": user, "signing_secret": signing_secret}',
        '',
        '',
        'def _mount_webhook(cls, name):',
        '    """HMAC-verified webhook: X-API-Key resolves the caller, the',
        '    signature covers b"{timestamp}." + raw_body (sha256 hexdigest),',
        '    and stale timestamps outside 300s are rejected."""',
        '',
        '    async def _hook_handler(request: Request):',
        '        api_key = request.headers.get("X-API-Key")',
        '        if not api_key:',
        '            return _error_envelope(',
        '                "UNAUTHORIZED", "Missing X-API-Key header", status=401',
        '            )',
        '        key_doc = _resolve_api_key(api_key)',
        '        if not key_doc:',
        '            return _error_envelope(',
        '                "UNAUTHORIZED", "Invalid or expired API key", status=401',
        '            )',
        '        raw_body = await request.body()',
        '        signature = request.headers.get("X-Webhook-Signature")',
        '        timestamp = request.headers.get("X-Webhook-Timestamp")',
        '        if not signature or not timestamp:',
        '            return _error_envelope(',
        '                "UNAUTHORIZED", "Missing webhook signature headers", status=401',
        '            )',
        '        try:',
        '            request_ts = int(timestamp)',
        '        except ValueError:',
        '            return _error_envelope(',
        '                "UNAUTHORIZED", "Invalid webhook timestamp", status=401',
        '            )',
        '        if abs(int(time.time()) - request_ts) > 300:',
        '            return _error_envelope(',
        '                "UNAUTHORIZED",',
        '                "Webhook timestamp outside allowed window",',
        '                status=401,',
        '            )',
        '        signed = (str(request_ts) + ".").encode() + raw_body',
        '        expected = hmac.new(',
        '            key_doc["signing_secret"].encode(), signed, hashlib.sha256',
        '        ).hexdigest()',
        '        given = signature.split("=", 1)[-1].strip()',
        '        if not hmac.compare_digest(given.lower(), expected.lower()):',
        '            return _error_envelope(',
        '                "UNAUTHORIZED", "Invalid webhook signature", status=401',
        '            )',
        '        try:',
        '            fields = json.loads(raw_body.decode("utf-8") or "{}")',
        '        except (ValueError, UnicodeDecodeError):',
        '            fields = {}',
        '        if not isinstance(fields, dict):',
        '            fields = {}',
        '        return await _run_walker(cls, fields, key_doc["user"])',
        '',
        '    app.add_api_route("/webhook/" + name, _hook_handler, methods=["POST"])',
        '',
        '',
        'def _envelope(data, status=200):',
        '    """Transport envelope byte-compatible with the `jac start` server."""',
        '    return {',
        '        "ok": True,',
        '        "type": "response",',
        '        "data": data,',
        '        "error": None,',
        '        "meta": {"extra": {"http_status": status}},',
        '    }',
        '',
        '',
        'def _error_envelope(code, message, details="", status=500):',
        '    return JSONResponse(',
        '        status_code=status,',
        '        content={',
        '            "ok": False,',
        '            "type": "error",',
        '            "data": None,',
        '            "error": {"code": code, "message": message, "details": details},',
        '            "meta": {"extra": {"http_status": status}},',
        '        },',
        '    )',
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
        '    yield b"event: end\\ndata: {}\\n\\n"',
        '',
        '',
        'def _sse_line(chunk):',
        '    """Frame any chunk as a Server-Sent Event (`data: <json>` per line)."""',
        '    if isinstance(chunk, (bytes, bytearray)):',
        '        text = bytes(chunk).decode("utf-8", "replace")',
        '    else:',
        '        text = json.dumps(chunk)',
        '    framed = "".join("data: " + line + "\\n" for line in text.split("\\n"))',
        '    return (framed + "\\n").encode("utf-8")',
        '',
        '',
        'async def _run_walker(cls, fields, user):',
        '    try:',
        '        result = await _em.spawn_walker(cls, fields, user)',
        '    except HTTPException:',
        '        raise',
        '    except Exception as exc:',
        '        return _error_envelope("EXECUTION_ERROR", str(exc), traceback.format_exc())',
        '    if isinstance(result, dict) and "error" in result and "result" not in result:',
        '        return _error_envelope(',
        '            "EXECUTION_ERROR",',
        '            str(result.get("error") or ""),',
        '            str(result.get("traceback") or ""),',
        '        )',
        '    if inspect.isgenerator(result) or inspect.isasyncgen(result):',
        '        return StreamingResponse(_sse(result), media_type="text/event-stream")',
        '    spec = getattr(cls, "restspec", None)',
        '    if (',
        '        spec is not None',
        '        and isinstance(result, dict)',
        '        and isinstance(result.get("result"), dict)',
        '    ):',
        '        result["result"]["restspec"] = _Serializer.serialize(spec, api_mode=True)',
        '    return _envelope(result)',
        '',
        '',
        'async def _run_function(fn, fields, user):',
        '    try:',
        '        result = await _em.execute_function(fn, fields, user)',
        '    except HTTPException:',
        '        raise',
        '    except Exception as exc:',
        '        return _error_envelope("EXECUTION_ERROR", str(exc), traceback.format_exc())',
        '    if isinstance(result, dict) and "error" in result and "result" not in result:',
        '        return _error_envelope(',
        '            "EXECUTION_ERROR",',
        '            str(result.get("error") or ""),',
        '            str(result.get("traceback") or ""),',
        '        )',
        '    if inspect.isgenerator(result) or inspect.isasyncgen(result):',
        '        return StreamingResponse(_sse(result), media_type="text/event-stream")',
        '    return _envelope(result)',
        '',
        '',
        '_scheduler = _Scheduler.instance()',
        '',
        '_ws_peers = {}',
        '',
        '',
        'def _mount_ws(cls, name, required):',
        '    """WebSocket walker: ?token= pre-accept auth, one result frame per',
        '    JSON message; broadcast=True fans every frame out to all peers."""',
        '    spec = getattr(cls, "restspec", None)',
        '    broadcast = bool(getattr(spec, "broadcast", False))',
        '    peers = _ws_peers.setdefault(name, set())',
        '',
        '    async def _ws_handler(websocket: WebSocket):',
        '        token = websocket.query_params.get("token")',
        '        username = _um.validate_token(token) if token else None',
        '        if required and not username:',
        '            await websocket.close(code=4401)',
        '            return',
        '        user = username or _GUEST',
        '        await websocket.accept()',
        '        peers.add(websocket)',
        '        try:',
        '            while True:',
        '                try:',
        '                    fields = await websocket.receive_json()',
        '                except WebSocketDisconnect:',
        '                    break',
        '                except (ValueError, TypeError):',
        '                    await websocket.send_json({',
        '                        "ok": False,',
        '                        "error": {',
        '                            "code": "BAD_FRAME",',
        '                            "message": "frames must be JSON objects",',
        '                        },',
        '                    })',
        '                    continue',
        '                fields = dict(fields) if isinstance(fields, dict) else {}',
        '                fields.pop("token", None)',
        '                try:',
        '                    result = await _em.spawn_walker(cls, fields, user)',
        '                    if (',
        '                        spec is not None',
        '                        and isinstance(result, dict)',
        '                        and isinstance(result.get("result"), dict)',
        '                    ):',
        '                        result["result"]["restspec"] = _Serializer.serialize(',
        '                            spec, api_mode=True',
        '                        )',
        '                    frame = {"ok": True, "data": result}',
        '                except Exception as exc:',
        '                    frame = {',
        '                        "ok": False,',
        '                        "error": {',
        '                            "code": "EXECUTION_ERROR",',
        '                            "message": str(exc),',
        '                        },',
        '                    }',
        '                targets = list(peers) if broadcast else [websocket]',
        '                for peer in targets:',
        '                    try:',
        '                        await peer.send_json(frame)',
        '                    except Exception:',
        '                        peers.discard(peer)',
        '        except WebSocketDisconnect:',
        '            pass',
        '        finally:',
        '            peers.discard(websocket)',
        '',
        '    app.add_api_websocket_route("/ws/" + name, _ws_handler)',
        '',
        '',
        'def _query_route(handler, model, path):',
        '    """Bind a body model\'s fields as individual query parameters, except',
        '    those named by a `{placeholder}` in the route, which bind as path',
        '    params. Mirrors how `jac start` classifies a GET symbol\'s fields',
        '    (path before query). Instantiating the model bare would 500 on any',
        '    required field and would drop caller input even when all fields',
        '    had defaults."""',
        '    in_path = set(re.findall(r"{([^}:]+)", path))',
        '    params = []',
        '    for (fname, finfo) in model.model_fields.items():',
        '        ann = finfo.annotation if finfo.annotation is not None else str',
        '        if fname in in_path:',
        '            default = _PathParam(...)',
        '        elif finfo.is_required():',
        '            default = Query(...)',
        '        else:',
        '            default = Query(finfo.default)',
        '        params.append(',
        '            inspect.Parameter(',
        '                fname,',
        '                inspect.Parameter.KEYWORD_ONLY,',
        '                default=default,',
        '                annotation=ann,',
        '            )',
        '        )',
        '    params.append(',
        '        inspect.Parameter(',
        '            "authorization",',
        '            inspect.Parameter.KEYWORD_ONLY,',
        '            default=Header(default=None),',
        '            annotation=str,',
        '        )',
        '    )',
        '',
        '    async def _route(**kwargs):',
        '        auth = kwargs.pop("authorization", None)',
        '        return await handler(model(**kwargs), authorization=auth)',
        '',
        '    _route.__signature__ = inspect.Signature(params)',
        '    _route.__name__ = getattr(handler, "__name__", "_route")',
        '    return _route',
        '',
        '',
        'def _mount_endpoint(obj, handler, model, default_paths, name="", required=False):',
        '    """Mount at @restspec(path=...) when declared, REPLACING the default',
        '    /walker|/function path (parity with `jac start`); else the defaults.',
        '    @schedule symbols become scheduler jobs; protocol=WEBSOCKET walkers',
        '    become /ws/ routes; neither gets an HTTP endpoint."""',
        '    sched = getattr(obj, "schedule_spec", None)',
        '    if sched is not None:',
        '        job = getattr(obj, "__name__", str(obj))',
        '        _scheduler.register(job, obj, sched, inspect.isclass(obj))',
        '        return',
        '    spec = getattr(obj, "restspec", None)',
        '    raw_proto = getattr(spec, "protocol", None)',
        '    proto = str(getattr(raw_proto, "value", raw_proto) or "").lower()',
        '    if proto == "websocket" and inspect.isclass(obj):',
        '        _mount_ws(obj, name or getattr(obj, "__name__", ""), required)',
        '        return',
        '    if proto == "webhook" and inspect.isclass(obj):',
        '        _mount_webhook(obj, name or getattr(obj, "__name__", ""))',
        '        return',
        '    path = str(getattr(spec, "path", "") or "")',
        '    if path:',
        '        if not path.startswith("/"):',
        '            path = "/" + path',
        '        raw_method = getattr(spec, "method", None)',
        '        method = str(getattr(raw_method, "value", raw_method) or "POST").upper()',
        '        if method in ("GET", "HEAD") and model is not None:',
        '            app.add_api_route(',
        '                path, _query_route(handler, model, path), methods=[method]',
        '            )',
        '        else:',
        '            app.add_api_route(path, handler, methods=[method])',
        '        return',
        '    for p in default_paths:',
        '        app.add_api_route(p, handler, methods=["POST"])'
    ];

    for w in walkers {
        wn = str(w["name"]);
        required = "False" if w["pub"] else "True";
        has_upload = False;
        for fld in w["fields"] {
            if _is_upload_type(str(fld["type"])) {
                has_upload = True;
            }
        }
        if has_upload {
            sig: list[str] = [];
            for fld in w["fields"] {
                fname = str(fld["name"]);
                if _is_upload_type(str(fld["type"])) {
                    utype = "list[UploadFile]"
                        if "list" in str(fld["type"]).lower()
                        else "UploadFile";
                    sig.append(fname + ": " + utype + " = File(...)");
                } else {
                    ftype = _safe_model_type(str(fld["type"]));
                    default = _safe_model_default(str(fld["default"]))
                        if fld["has_default"]
                        else "...";
                    sig.append(fname + ": " + ftype + " = Form(" + default + ")");
                }
            }
            sig.append('node_id: str = ""');
            sig.append("authorization: str = Header(default=None)");
            kw = ", ".join(
                [
                    repr(str(fld["name"])) + ": " + str(fld["name"])
                    for fld in w["fields"]
                ]
            );
            lines.append("");
            lines.append("");
            lines.append("async def run_" + wn + "(" + ", ".join(sig) + "):");
            lines.append("    user = _username(authorization, " + required + ")");
            lines.append("    fields = {" + kw + "}");
            lines.append("    if node_id:");
            lines.append('        fields["_jac_spawn_node"] = node_id');
            lines.append("    return await _run_walker(_W_" + wn + ", fields, user)");
            lines.append("");
            lines.append("");
            lines.append(
                "_mount_endpoint(_W_" + wn + ", run_" + wn + ", None, " + '["/walker/' + wn + '", "/walker/' + wn + '/{node_id}"], ' + repr(
                    wn
                ) + ", " + required + ")"
            );
            continue;
        }
        model = _model_class_name(wn, "In");
        lines.append("");
        lines.append("");
        lines.append("class " + model + "(BaseModel):");
        if w["fields"] {
            for fld in w["fields"] {
                fname = str(fld["name"]);
                ftype = _safe_model_type(str(fld["type"]));
                if fld["has_default"] {
                    lines.append(
                        "    " + fname + ": " + ftype + " = " + _safe_model_default(
                            str(fld["default"])
                        )
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
        lines.append(
            "async def run_" + wn + "(body: " + model + ", node_id: str = \"\", authorization: str = Header(default=None)):"
        );
        lines.append("    user = _username(authorization, " + required + ")");
        lines.append("    fields = dict(body.model_dump())");
        lines.append("    if node_id:");
        lines.append('        fields["_jac_spawn_node"] = node_id');
        lines.append("    return await _run_walker(_W_" + wn + ", fields, user)");
        lines.append("");
        lines.append("");
        lines.append(
            "_mount_endpoint(_W_" + wn + ", run_" + wn + ", " + model + ", " + '["/walker/' + wn + '", "/walker/' + wn + '/{node_id}"], ' + repr(
                wn
            ) + ", " + required + ")"
        );
    }

    for f in functions {
        fn = str(f["name"]);
        required = "False" if f["pub"] else "True";
        has_upload = False;
        for p in f["params"] {
            if _is_upload_type(str(p["type"])) {
                has_upload = True;
            }
        }
        if has_upload {
            sig: list[str] = [];
            for p in f["params"] {
                pname = str(p["name"]);
                if _is_upload_type(str(p["type"])) {
                    utype = "list[UploadFile]"
                        if "list" in str(p["type"]).lower()
                        else "UploadFile";
                    sig.append(pname + ": " + utype + " = File(...)");
                } else {
                    ftype = _safe_model_type(str(p["type"]));
                    default = _safe_model_default(str(p["default"]))
                        if p["has_default"]
                        else "...";
                    sig.append(pname + ": " + ftype + " = Form(" + default + ")");
                }
            }
            sig.append("authorization: str = Header(default=None)");
            kw = ", ".join(
                [repr(str(p["name"])) + ": " + str(p["name"]) for p in f["params"]]
            );
            lines.append("");
            lines.append("");
            lines.append("async def call_" + fn + "(" + ", ".join(sig) + "):");
            lines.append("    user = _username(authorization, " + required + ")");
            lines.append("    fields = {" + kw + "}");
            lines.append("    return await _run_function(_F_" + fn + ", fields, user)");
            lines.append("");
            lines.append("");
            lines.append(
                "_mount_endpoint(_F_" + fn + ", call_" + fn + ", None, " + '["/function/' + fn + '"])'
            );
            continue;
        }
        model = _model_class_name(fn, "FnIn");
        lines.append("");
        lines.append("");
        lines.append("class " + model + "(BaseModel):");
        if f["params"] {
            for p in f["params"] {
                pname = str(p["name"]);
                ptype = _safe_model_type(str(p["type"]));
                if p["has_default"] {
                    lines.append(
                        "    " + pname + ": " + ptype + " = " + _safe_model_default(
                            str(p["default"])
                        )
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
        lines.append(
            "async def call_" + fn + "(body: " + model + ", authorization: str = Header(default=None)):"
        );
        lines.append("    user = _username(authorization, " + required + ")");
        lines.append(
            "    return await _run_function(_F_" + fn + ", dict(body.model_dump()), user)"
        );
        lines.append("");
        lines.append("");
        lines.append(
            "_mount_endpoint(_F_" + fn + ", call_" + fn + ", " + model + ", " + '["/function/' + fn + '"])'
        );
    }

    walker_list_lit = "[" + ", ".join([repr(str(w["name"])) for w in walkers]) + "]";
    func_list_lit = "[" + ", ".join([repr(str(f["name"])) for f in functions]) + "]";
    lines += [
        '',
        '',
        'if _scheduler.has_pending():',
        '    _scheduler.start()',
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


def _req_key(req: str) -> str {
    name = str(req).strip();
    for i in range(len(name)) {
        if name[i] in "<>=!~[; " {
            name = name[:i];
            break;
        }
    }
    return name.strip().lower().replace("_", "-");
}


def _emit_requirements(backend_dir: Path, extra_reqs: list) {
    lines: list[str] = ["fastapi>=0.110", "uvicorn[standard]>=0.27"];
    seen: set = {_req_key(r) for r in lines};
    for req in extra_reqs {
        key = _req_key(str(req));
        if (not key) or (key in seen) {
            continue;
        }
        seen.add(key);
        lines.append(str(req));
    }
    (backend_dir / "requirements.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    );
}
