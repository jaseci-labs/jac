"""Implementation of the @jaseci/runtime npm package builder."""

import re;
import json;
import jaclang;
import from pathlib { Path }
import from jaclang.publish.npm_tarball { pack_tarball }

# Caches keyed by the resolved runtime source path, so React and Solid builds
# (or any two frameworks) never clobber each other's compiled output.
glob _api_names_cache: dict[str, set] = {},
     _runtime_js_cache: dict[str, str] = {};

"""Absolute path to `framework`'s client runtime `.cl.jac` (`""` = active backend)."""
def _runtime_source_path(framework: str = "") -> Path {
    import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
    return Path(resolve_client_runtime_cl_path(framework));
}

impl runtime_pkg_name(framework: str = "") -> str {
    import from jaclang.runtimelib.runtime_source { client_runtime_cl_basename }
    base = client_runtime_cl_basename(framework);
    # React and Preact share `client_runtime.cl.jac` → the canonical package name.
    if base == "client_runtime.cl.jac" {
        return RUNTIME_PKG_NAME;
    }
    # Any other backend (`<fw>_runtime.cl.jac`) gets a suffixed package so a Solid
    # runtime never collides with the React one on the registry.
    suffix = base.split("_runtime.cl.jac")[0] or base;
    return f"{RUNTIME_PKG_NAME}-{suffix}";
}

impl runtime_api_names(framework: str = "") -> set {
    global _api_names_cache;
    src = _runtime_source_path(framework);
    key = str(src);
    cached = _api_names_cache.get(key);
    if cached is not None {
        return cached;
    }
    text = src.read_text(encoding="utf-8");
    names: set[str] = set();
    # Top-level `def`/`glob`, optionally `async` and/or an access tag (`:pub`).
    for m in re.finditer(
        r"(?m)^(?:async\s+)?(?:def|glob)(?::\w+)?\s+([A-Za-z_][A-Za-z0-9_]*)", text
    ) {
        names.add(m.group(1));
    }
    # Multi-line `glob` blocks list further bindings on indented continuation
    # lines (`     foo = bar,`). The header regex above only captures the first.
    for m in re.finditer(r"(?m)^\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", text) {
        names.add(m.group(1));
    }
    _api_names_cache[key] = names;
    return names;
}

"""Compile one `.cl.jac` source file to its single-module ESM JavaScript string.
Raises ValueError listing any compiler diagnostics for that file."""
def _compile_cl_to_js(src: Path) -> str {
    import from jaclang.jac0core.program { JacProgram }
    program = JacProgram();
    prev = len(program.errors_had);
    mod = program.compile(str(src));
    new_errors = program.errors_had[prev:];
    if new_errors {
        formatted = "\n".join(str(err) for err in new_errors);
        raise ValueError(f"Failed to compile {src.name}:\n{formatted}");
    }
    return (mod.gen.js if mod and mod.gen else "") or "";
}

impl compile_runtime_js(framework: str = "") -> str {
    global _runtime_js_cache;
    src = _runtime_source_path(framework);
    key = str(src);
    cached = _runtime_js_cache.get(key);
    if cached is not None {
        return cached;
    }
    js = _compile_cl_to_js(src);
    _runtime_js_cache[key] = js;
    return js;
}

"""Names the compiled JS already exports — via `export { a, b as c }` clauses
(the exported binding is the alias after `as`, else the name) and inline
`export function/const/...` declarations. Subtracted from the appended export
list so a runtime whose codegen already emits its own `export {...}` is not
double-exported (invalid ESM: "Duplicate export of ...")."""
def _already_exported(js: str) -> set[str] {
    names: set[str] = set();
    for block in re.finditer(r"export\s*\{([^}]*)\}", js) {
        for part in block.group(1).split(",") {
            piece = part.strip();
            if not piece {
                continue;
            }
            # `name as alias` exports `alias`; a bare `name` exports `name`.
            tokens = re.split(r"\s+as\s+", piece);
            names.add(tokens[-1].strip());
        }
    }
    for m in re.finditer(
        r"(?m)^export\s+(?:async\s+)?(?:function|const|let|var|class)\s+([A-Za-z_$][\w$]*)",
        js
    ) {
        names.add(m.group(1));
    }
    return names;
}

impl runtime_export_names(js: str, framework: str = "") -> list[str] {
    api = runtime_api_names(framework);
    top_level: set[str] = set();
    for m in re.finditer(
        r"(?m)^(?:export\s+)?(?:async\s+)?(?:function|const|let|var|class)\s+([A-Za-z_$][\w$]*)",
        js
    ) {
        top_level.add(m.group(1));
    }
    # Exclude anything the compiled runtime already exports — its codegen emits its
    # own `export {...}` clause for `:pub` symbols, so re-listing them would yield a
    # duplicate export (invalid ESM: "Duplicate export of ...").
    return sorted((top_level & api) - _already_exported(js));
}

"""Package root of a bare import specifier (`solid-js/h` → `solid-js`,
`@hookform/resolvers/zod` → `@hookform/resolvers`); None for relative imports."""
def _pkg_root(spec: str) -> (str | None) {
    if spec.startswith(".") or spec.startswith("/") {
        return None;
    }
    parts = spec.split("/");
    if spec.startswith("@") {
        return "/".join(parts[:2]) if len(parts) >= 2 else spec;
    }
    return parts[0];
}

# Canonical npm version ranges for runtime peer packages. Kept in lockstep with
# the client-side dependency defaults in
# `runtimelib/client/impl/client_deps.impl.jac` (`_default_client_deps`) and
# `runtimelib/client/impl/config_loader.impl.jac` — the source of truth a project
# actually installs. Duplicated as a flat literal here (rather than imported) so
# the runtime-npm builder stays free of the client config/console dependency
# graph. Any imported package not listed must be added here (and in client_deps)
# — `_runtime_peer_deps` raises rather than emitting an unbounded `"*"`.
glob _PEER_VERSIONS: dict[str, str] = {
         "react": "^18.2.0",
         "react-dom": "^18.2.0",
         "react-router-dom": "^6.22.0",
         "react-error-boundary": "^5.0.0",
         "@tanstack/react-form": "^1.33.0",
         "@tanstack/solid-form": "^1.33.0",
         "solid-js": "^1.9.13",
         "@solidjs/router": "^0.16.1",
         "zod": "^4.3.6"
     };

"""peerDependencies for the runtime: the external npm packages the compiled
runtime module actually imports, versioned from `_PEER_VERSIONS`.

Scanning the compiled JS — rather than dumping a whole dep map — keeps the peer
list honest: `react-dom` lives in the generated entry script, not the runtime
module, so it is correctly absent here. Anything imported but not in the canonical
map raises `ValueError` so published packages never ship an unbounded peer."""
def _runtime_peer_deps(js: str) -> dict[str, str] {
    roots: set[str] = set();
    # Normalize single-quoted specifiers to double quotes so a single regex (with
    # no embedded single quote) covers both `from "spec"` and bare `import "spec"`.
    norm = js.replace("'", '"');
    for m in re.finditer('(?m)\\bfrom\\s+"([^"]+)"', norm) {
        pkg = _pkg_root(m.group(1));
        if pkg {
            roots.add(pkg);
        }
    }
    for m in re.finditer('(?m)^\\s*import\\s+"([^"]+)"', norm) {
        pkg = _pkg_root(m.group(1));
        if pkg {
            roots.add(pkg);
        }
    }
    peers: dict[str, str] = {};
    for pkg in sorted(roots) {
        version = _PEER_VERSIONS.get(pkg);
        if version is None {
            raise ValueError(
                f"runtime imports unknown peer package {pkg!r}; "
                "add it to _PEER_VERSIONS in runtime_npm.impl.jac and the "
                "client dependency defaults"
            );
        }
        peers[pkg] = version;
    }
    return peers;
}

impl runtime_peer_deps(js: str) -> dict[str, str] {
    return _runtime_peer_deps(js);
}

"""Relative `.js` import specifiers in `js` (those starting with `.` and ending
in `.js`) — the sibling runtime modules that must travel inside the tarball."""
def _relative_dep_specs(js: str) -> list[str] {
    specs: list[str] = [];
    norm = js.replace("'", '"');
    for m in re.finditer('(?m)\\bfrom\\s+"(\\.[^"]+)"', norm) {
        if m.group(1).endswith(".js") {
            specs.append(m.group(1));
        }
    }
    for m in re.finditer('(?m)^\\s*import\\s+"(\\.[^"]+)"', norm) {
        if m.group(1).endswith(".js") {
            specs.append(m.group(1));
        }
    }
    return specs;
}

"""Compile and collect every sibling runtime module the entry transitively
imports via relative paths, as `(tarball_relpath, js)` pairs.

The runtime split (`client_runtime_core.cl.jac`) means the framework shim no
longer compiles to a single self-contained module — its codegen emits
`import ... from "./jaclang/runtimelib/client_runtime_core.js"`. Those siblings
must be compiled and shipped at the same relative layout or the published package
fails to load (`ERR_MODULE_NOT_FOUND`). Walks the relative-import graph breadth
-first (resolving each spec against the importing module's own dir) so arbitrary
depth is handled, not just the current single core dependency."""
def _collect_dep_modules(entry_js: str) -> list[tuple[str, str]] {
    import jaclang;
    import posixpath;
    base = Path(jaclang.__file__).parent.parent;
    seen: set[str] = set();
    out: list[tuple[str, str]] = [];
    # worklist entries: (dir of the importing module relative to package root, js)
    worklist: list[tuple[str, str]] = [("", entry_js)];
    while worklist {
        (cur_dir, js) = worklist.pop();
        for spec in _relative_dep_specs(js) {
            rel = posixpath.normpath(posixpath.join(cur_dir, spec));
            if rel in seen {
                continue;
            }
            seen.add(rel);
            src = base / (rel[:-3] + ".cl.jac");
            dep_js = _compile_cl_to_js(src);
            out.append((rel, dep_js));
            worklist.append((posixpath.dirname(rel), dep_js));
        }
    }
    return out;
}

def _runtime_package_json(
    version: str, pkg_name: str, peers: dict[str, str] = {}
) -> str {
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
    if peers {
        doc["peerDependencies"] = peers;
    }
    return json.dumps(doc, indent=2) + "\n";
}

impl build_runtime_tarball(
    version: str, pkg_name: str = "", framework: str = ""
) -> bytes {
    name = pkg_name or runtime_pkg_name(framework);
    entry_js = compile_runtime_js(framework);
    # Compile + ship every sibling module the entry imports relatively (the split
    # `client_runtime_core` etc.), or the package fails to load at runtime.
    deps = _collect_dep_modules(entry_js);
    # Append only the public API the entry's codegen did not already export.
    exports = runtime_export_names(entry_js, framework);
    if exports {
        entry_js = entry_js.rstrip("\n") + "\nexport { " + ", ".join(exports) + " };\n";
    }
    # peerDependencies span the whole graph — the core module imports external
    # packages too (e.g. `zod`), not just the framework shim.
    all_js = "\n".join([entry_js] + [dep_js for (_, dep_js) in deps]);
    peers = _runtime_peer_deps(all_js);
    pj = _runtime_package_json(version, name, peers);
    members: list[tuple[str, bytes]] = [
        ("package/package.json", pj.encode("utf-8")),
        ("package/index.js", entry_js.encode("utf-8"))
    ];
    for (rel, dep_js) in deps {
        members.append((f"package/{rel}", dep_js.encode("utf-8")));
    }
    return pack_tarball(members);
}

impl build_runtime_to(
    output_dir: Path, version: str, pkg_name: str = "", framework: str = ""
) -> Path {
    name = pkg_name or runtime_pkg_name(framework);
    output_dir.mkdir(parents=True, exist_ok=True);
    flat = name.lstrip("@").replace("/", "-");
    dest = output_dir / f"{flat}-{version}.tgz";
    dest.write_bytes(build_runtime_tarball(version, name, framework));
    return dest;
}
