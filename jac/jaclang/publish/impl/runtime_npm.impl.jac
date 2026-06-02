"""Implementation of the @jaseci/runtime npm package builder."""

import re;
import json;
import jaclang;
import from pathlib { Path }
import from jaclang.publish.npm_tarball { pack_tarball }

glob _api_names_cache: set | None = None,
     _runtime_js_cache: str | None = None;

def _runtime_source_path -> Path {
    return Path(jaclang.__file__).parent / "runtimelib" / "client_runtime.cl.jac";
}

impl runtime_api_names -> set {
    global _api_names_cache;
    if _api_names_cache is not None {
        return _api_names_cache;
    }
    text = _runtime_source_path().read_text(encoding="utf-8");
    names: set = set();
    for m in re.finditer(r"(?m)^(?:def|glob)\s+([A-Za-z_][A-Za-z0-9_]*)", text) {
        names.add(m.group(1));
    }
    _api_names_cache = names;
    return names;
}

impl compile_runtime_js -> str {
    global _runtime_js_cache;
    if _runtime_js_cache is not None {
        return _runtime_js_cache;
    }
    import from jaclang.jac0core.program { JacProgram }
    src = _runtime_source_path();
    program = JacProgram();
    prev = len(program.errors_had);
    mod = program.compile(str(src));
    new_errors = program.errors_had[prev:];
    if new_errors {
        formatted = "\n".join(str(err) for err in new_errors);
        raise ValueError(f"Failed to compile the Jac client runtime:\n{formatted}");
    }
    js = (mod.gen.js if mod and mod.gen else "") or "";
    _runtime_js_cache = js;
    return js;
}

impl runtime_export_names(js: str) -> list[str] {
    api = runtime_api_names();
    top_level: set = set();
    for m in re.finditer(
        r"(?m)^(?:export\s+)?(?:async\s+)?(?:function|const|let|var|class)\s+([A-Za-z_$][\w$]*)",
        js
    ) {
        top_level.add(m.group(1));
    }
    return sorted(top_level & api);
}

def _runtime_package_json(version: str, pkg_name: str) -> str {
    doc: dict[str, any] = {
        "name": pkg_name,
        "version": version,
        "description": "Jac client runtime (JSX factory + reactive primitives) for "
        "npm-published Jac libraries.",
        "license": "MIT",
        "type": "module",
        "main": "index.js",
        "module": "index.js",
        "exports": {".": {"import": "./index.js"}},

    };
    return json.dumps(doc, indent=2) + "\n";
}

impl build_runtime_tarball(version: str, pkg_name: str = RUNTIME_PKG_NAME) -> bytes {
    js = compile_runtime_js();
    exports = runtime_export_names(js);
    if exports {
        js = js.rstrip("\n") + "\nexport { " + ", ".join(exports) + " };\n";
    }
    pj = _runtime_package_json(version, pkg_name);
    members: list[tuple[str, bytes]] = [
        ("package/package.json", pj.encode("utf-8")),
        ("package/index.js", js.encode("utf-8")),

    ];
    return pack_tarball(members);
}

impl build_runtime_to(
    output_dir: Path, version: str, pkg_name: str = RUNTIME_PKG_NAME
) -> Path {
    output_dir.mkdir(parents=True, exist_ok=True);
    flat = pkg_name.lstrip("@").replace("/", "-");
    dest = output_dir / f"{flat}-{version}.tgz";
    dest.write_bytes(build_runtime_tarball(version, pkg_name));
    return dest;
}
