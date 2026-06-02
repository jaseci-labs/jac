"""Implementation of the npm client-module collector."""

import re;
import fnmatch;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.publish.sources { EXCLUDED_DIRS }
import from jaclang.publish.jsdoc { jsdoc_for_module, inject_jsdoc }
import from jaclang.publish.dts { dts_for_module }
import from jaclang.publish.runtime_npm { runtime_api_names }

glob _DEFAULT_RUNTIME_PKG: str = "@jaseci/runtime";

impl runtime_pkg_name(config: JacConfig) -> str {
    npm = config._raw_data.get("npm", {});
    if isinstance(npm, dict) and npm.get("runtime") {
        return npm["runtime"];
    }
    return _DEFAULT_RUNTIME_PKG;
}

def _top_level_decls(js: str) -> set {
    names: set = set();
    for m in re.finditer(
        r"(?m)^(?:export\s+)?(?:async\s+)?(?:function|const|let|var|class)\s+([A-Za-z_$][\w$]*)",
        js
    ) {
        names.add(m.group(1));
    }
    return names;
}

"""Prepend a runtime import for any runtime symbols the module uses, and report
   the npm packages it depends on (runtime + react/react-dom)."""
def _wire_externals(js: str, runtime_pkg: str) -> tuple[str, list[str]] {
    externals: list[str] = [];
    local = _top_level_decls(js);
    api = runtime_api_names();

    used: list[str] = [];
    for name in sorted(api) {
        if name in local {
            continue;
        }
        if re.search(r"\b" + re.escape(name) + r"\b", js) {
            used.append(name);
        }
    }
    out = js;
    if used {
        out = f'import {{ {", ".join(used)} }} from "{runtime_pkg}";\n' + out;
        externals.append(runtime_pkg);
    }

    # Detect bare-package imports of react / react-dom (peerDependencies).
    for m in re.finditer(r'from\s+["\']([^"\']+)["\']', js) {
        spec = m.group(1);
        base = spec;
        if spec.startswith("react/") {
            base = "react";
        } elif spec.startswith("react-dom/") {
            base = "react-dom";
        }
        if base in ("react", "react-dom") and base not in externals {
            externals.append(base);
        }
    }
    return (out, externals);
}

impl npm_js_path(rel_path: str) -> str {
    p = rel_path.replace("\\", "/");
    if p.endswith(".cl.jac") {
        return p[:-7] + ".js";
    }
    if p.endswith(".jac") {
        return p[:-4] + ".js";
    }
    return p;
}

def _in_excluded_dir(file_path: Path, pkg_root: Path) -> bool {
    try {
        rel = file_path.relative_to(pkg_root);
    } except ValueError {
        return False;
    }
    for part in rel.parts[:-1] {
        if part in EXCLUDED_DIRS or part.endswith(".egg-info") {
            return True;
        }
    }
    return False;
}

def _package_dirs(config: JacConfig, proj_root: Path) -> list[Path] {
    package_patterns = config.project.include.packages;
    if not package_patterns and config.project.name {
        package_patterns = [config.project.name.replace("-", "_")];
    }
    candidates = sorted(
        c
        for c in proj_root.iterdir()
        if c.is_dir() and c.name not in EXCLUDED_DIRS
    );
    dirs: list[Path] = [];
    for pkg_glob in package_patterns {
        for candidate in candidates {
            if fnmatch.fnmatch(candidate.name, pkg_glob) and candidate not in dirs {
                dirs.append(candidate);
            }
        }
    }
    return dirs;
}

def _crosses_server_boundary(mod: any) -> bool {
    im = mod.gen.interop_manifest if mod and mod.gen else None;
    if im is None {
        return False;
    }
    if im?.bindings {
        return True;
    }
    if im?.server_exports_to_client {
        return True;
    }
    return False;
}

def _compile_module(program: any, path: Path) -> any {
    source_key = str(path);
    prev = len(program.errors_had);
    mod = program.compile(source_key);
    new_errors = program.errors_had[prev:];
    if new_errors {
        formatted = "\n".join(str(err) for err in new_errors);
        raise ValueError(f"Failed to compile '{path}' for npm bundle:\n{formatted}");
    }
    import from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
    if mod and mod.gen and not mod.gen.js {
        EsastGenPass(ir_in=mod, prog=program);
    }
    return mod;
}

impl collect_npm_sources(
    config: JacConfig, project_root: Path | None = None,
) -> list[NpmSourceFile] {
    proj_root = project_root or config.project_root;
    if proj_root is None {
        raise ValueError(
            "project_root is required: pass it explicitly or ensure "
            "config.project_root is set."
        );
    }
    if not config.project.name {
        raise ValueError(
            "Cannot collect npm sources: [project] name is missing in jac.toml."
        );
    }

    import from jaclang.jac0core.program { JacProgram }
    program = JacProgram();

    runtime_pkg = runtime_pkg_name(config);
    result: list[NpmSourceFile] = [];
    seen: set = set();

    for pkg_dir in _package_dirs(config, proj_root) {
        for src in sorted(pkg_dir.rglob("*.jac")) {
            if not src.is_file() or _in_excluded_dir(src, pkg_dir) {
                continue;
            }
            if any(src.name.endswith(suf) for suf in NON_CLIENT_SUFFIXES) {
                continue;
            }
            rel = str(src.relative_to(proj_root)).replace("\\", "/");
            npm_path = npm_js_path(rel);
            if npm_path in seen {
                continue;
            }

            mod = _compile_module(program, src);
            js = (mod.gen.js if mod and mod.gen else "") or "";
            if not js.strip() {
                continue;  # no client output (e.g. a server-only plain .jac)
            }
            if _crosses_server_boundary(mod) {
                raise NpmBoundaryError(
                    f"'{rel}' crosses a server boundary and cannot be published as a "
                    "standalone npm package. npm packages must be pure client code "
                    "(no `sv` imports/calls)."
                );
            }
            blocks = jsdoc_for_module(mod);
            js = inject_jsdoc(js, blocks);
            (js, externals) = _wire_externals(js, runtime_pkg);
            dts = dts_for_module(mod);
            seen.add(npm_path);
            result.append(
                NpmSourceFile(
                    npm_path=npm_path,
                    source_path=src,
                    js=js,
                    dts=dts,
                    external_imports=externals,
                )
            );
        }
    }

    return result;
}

impl resolve_npm_entry(config: JacConfig, files: list[NpmSourceFile],) -> str | None {
    if not files {
        return None;
    }
    paths = {f.npm_path for f in files};

    npm = config._raw_data.get("npm", {});
    entry = npm.get("entry", "") if isinstance(npm, dict) else "";
    if entry {
        candidate = npm_js_path(entry.replace("\\", "/"));
        if candidate in paths {
            return candidate;
        }
    }

    # Prefer the shallowest index.js (fewest path segments).
    index_files = sorted(
        [
            p
            for p in paths
            if p.endswith("index.js")
        ],
        key=lambda p: any : p.count("/")
    );
    if index_files {
        return index_files[0];
    }

    if len(files) == 1 {
        return files[0].npm_path;
    }
    return None;
}
