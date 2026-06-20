"""Tests for the jaclang.publish npm pipeline.

Covers the npm-package counterparts of the wheel pipeline:
  package_json - package.json string generation from jac.toml
  jsdoc        - JSDoc block generation from typed Jac signatures
  npm_sources  - client-module collector + JS compilation + sv-boundary guard
  npm_builder  - NpmBuilder end-to-end (.tgz tarball)
  CLI          - `jac bundle --target npm`
"""

import io;
import os;
import re;
import json;
import tarfile;
import tempfile;
import shutil;
import from pathlib { Path }
import from subprocess { run }
import from jaclang.project.config { JacConfig }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.publish.package_json {
    generate_package_json,
    npm_package_name,
    npm_tarball_filename
}
import from jaclang.publish.jsdoc {
    jac_type_to_jsdoc,
    jac_type_to_ts,
    jsdoc_for_module,
    inject_jsdoc
}
import from jaclang.publish.dts { dts_for_module }
import from jaclang.publish.npm_sources { collect_npm_sources, NpmBoundaryError }
import from jaclang.publish.npm_builder { NpmBuilder }
import from jaclang.publish.runtime_npm {
    build_runtime_tarball,
    runtime_api_names,
    runtime_peer_deps,
    runtime_pkg_name,
    RUNTIME_PKG_NAME,
    CORE_RUNTIME_SYMBOLS
}


# Helpers --------------------------------------------------------------------------
"""Scaffold a minimal client library (jac.toml + a public .cl.jac module)."""
def _scaffold_lib(tmp_path: str, name: str = "mylib") {
    toml = (
        '[project]\nname = "' + name + '"\nversion = "1.0.0"\n'
        'description = "A handy Jac library"\nlicense = "MIT"\n\n'
        '[project.include]\npackages = ["' + name + '"]\n'
    );
    (Path(tmp_path) / "jac.toml").write_text(toml);
    pkg = Path(tmp_path) / name;
    pkg.mkdir(parents=True, exist_ok=True);
    (pkg / "index.cl.jac").write_text(
        'def:pub add(a: int, b: int) -> int {\n    return a + b;\n}\n\n'
        'def:pub greet(name: str) -> str {\n    return f"Hello, {name}!";\n}\n'
    );
}


"""All names a JS module exports: from `export { a, b as c }` clauses (the bound
name is the alias after `as`, else the name) plus inline `export function/const/...`
declarations. Used to assert the runtime emits each export exactly once — a
duplicate is invalid ESM (`SyntaxError: Duplicate export of '...'`)."""
def _exported_names(js: str) -> list[str] {
    names: list[str] = [];
    for block in re.finditer(r"export\s*\{([^}]*)\}", js) {
        for part in block.group(1).split(",") {
            piece = part.strip();
            if piece {
                names.append(re.split(r"\s+as\s+", piece)[-1].strip());
            }
        }
    }
    for m in re.finditer(
        r"(?m)^export\s+(?:async\s+)?(?:function|const|let|var|class)\s+([A-Za-z_$][\w$]*)",
        js
    ) {
        names.append(m.group(1));
    }
    return names;
}


# package_json --------------------------------------------------------------------------
test "npm_package_name normalizes and honours scoped override" {
    cfg = JacConfig.from_toml_str('[project]\nname = "My_Lib"\nversion = "1.0.0"\n');
    assert npm_package_name(cfg) == "my-lib";

    cfg2 = JacConfig.from_toml_str(
        '[project]\nname = "mylib"\nversion = "1.0.0"\n\n[npm]\nname = "@jaseci/mylib"\n'
    );
    assert npm_package_name(cfg2) == "@jaseci/mylib";
}

test "npm_tarball_filename flattens scope like npm pack" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "mylib"\nversion = "2.1.0"\n\n[npm]\nname = "@jaseci/mylib"\n'
    );
    assert npm_tarball_filename(cfg) == "jaseci-mylib-2.1.0.tgz";

    cfg2 = JacConfig.from_toml_str('[project]\nname = "plain"\nversion = "0.3.0"\n');
    assert npm_tarball_filename(cfg2) == "plain-0.3.0.tgz";
}

test "generate_package_json produces valid npm metadata" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "mylib"\nversion = "1.2.3"\n'
        'description = "desc"\nlicense = "MIT"\nkeywords = ["jac", "ui"]\n\n'
        '[project.urls]\nrepository = "https://github.com/you/mylib"\n\n'
        '[dependencies.npm]\nlodash = "^4.17.0"\n'
    );
    pj = json.loads(generate_package_json(cfg, main="index.js"));
    assert pj["name"] == "mylib";
    assert pj["version"] == "1.2.3";
    assert pj["description"] == "desc";
    assert pj["license"] == "MIT";
    assert pj["type"] == "module";
    assert pj["main"] == "index.js";
    assert pj["keywords"] == ["jac", "ui"];
    assert pj["dependencies"]["lodash"] == "^4.17.0";
    assert pj["repository"]["url"] == "https://github.com/you/mylib";
    assert pj["exports"]["."]["import"] == "./index.js";
}

test "generate_package_json raises when project name missing" {
    raised = False;
    try {
        generate_package_json(JacConfig());
    } except ValueError {
        raised = True;
    }
    assert raised;
}


# jsdoc --------------------------------------------------------------------------
test "jac_type_to_jsdoc maps scalars containers and unions" {
    assert jac_type_to_jsdoc("int") == "number";
    assert jac_type_to_jsdoc("str") == "string";
    assert jac_type_to_jsdoc("bool") == "boolean";
    assert jac_type_to_jsdoc("None", is_return=True) == "void";
    assert jac_type_to_jsdoc("list[int]") == "Array<number>";
    assert jac_type_to_jsdoc("dict[str, int]") == "Object<string, number>";
    assert jac_type_to_jsdoc("str | None") == "(string|null)";
    assert jac_type_to_jsdoc("MyClass") == "MyClass";
}

test "jsdoc_for_module builds typed blocks and inject places them" {
    tmpdir = tempfile.mkdtemp();
    try {
        src = Path(tmpdir) / "m.cl.jac";
        src.write_text(
            'def:pub add(a: int, b: int) -> int { return a + b; }\n'
            'def:pub label(s: str, n: float) -> str { return s; }\n'
        );
        mod = JacProgram().compile(str(src));
        blocks = jsdoc_for_module(mod);
        assert "add" in blocks;
        assert "@param {number} a" in blocks["add"];
        assert "@param {number} b" in blocks["add"];
        assert "@returns {number}" in blocks["add"];
        assert "@param {string} s" in blocks["label"];

        js = "function add(a, b) {\n  return (a + b);\n}\n";
        out = inject_jsdoc(js, blocks);
        assert "/**" in out;
        assert out.index("@returns {number}") < out.index("function add");
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


# npm_sources --------------------------------------------------------------------------
test "collect_npm_sources compiles client modules to JS with .js paths" {
    tmpdir = tempfile.mkdtemp();
    try {
        _scaffold_lib(tmpdir, "mylib");
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "mylib"\nversion = "1.0.0"\n\n'
            '[project.include]\npackages = ["mylib"]\n'
        );
        cfg.project_root = Path(tmpdir);
        files = collect_npm_sources(cfg, project_root=Path(tmpdir));
        paths = [f.npm_path for f in files];
        assert "mylib/index.js" in paths;
        idx = [
            f
            for f in files
            if f.npm_path == "mylib/index.js"
        ][0];
        assert "export" in idx.js;
        assert "function add" in idx.js;
        assert "@returns {number}" in idx.js;  # JSDoc injected during collection
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


# npm_builder - end-to-end --------------------------------------------------------------------------
test "NpmBuilder.build produces a valid npm tarball with package.json and JS" {
    tmpdir = tempfile.mkdtemp();
    try {
        _scaffold_lib(tmpdir, "mylib");
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "mylib"\nversion = "1.0.0"\n\n'
            '[project.include]\npackages = ["mylib"]\n'
        );
        cfg.project_root = Path(tmpdir);
        data = NpmBuilder(config=cfg, project_root=Path(tmpdir)).build();

        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
            names = tf.getnames();
            assert "package/package.json" in names;
            assert any(n.endswith("index.js") for n in names);
            assert all(n.startswith("package/") for n in names);
            pj = json.loads(tf.extractfile("package/package.json").read().decode());
            assert pj["name"] == "mylib";
            assert pj["version"] == "1.0.0";
            assert pj["main"] == "mylib/index.js";
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "NpmBuilder.build_to writes file with npm-style name and is reproducible" {
    tmpdir = tempfile.mkdtemp();
    try {
        _scaffold_lib(tmpdir, "testlib");
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "testlib"\nversion = "2.0.0"\n\n'
            '[project.include]\npackages = ["testlib"]\n'
        );
        cfg.project_root = Path(tmpdir);
        builder = NpmBuilder(config=cfg, project_root=Path(tmpdir));
        result = builder.build_to(Path(tmpdir) / "dist");
        assert result.exists();
        assert result.name == npm_tarball_filename(cfg);
        assert builder.build() == builder.build();  # reproducible
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "NpmBuilder rejects modules that cross a server boundary" {
    tmpdir = tempfile.mkdtemp();
    try {
        pkg = Path(tmpdir) / "svlib";
        pkg.mkdir(parents=True, exist_ok=True);
        (pkg / "api.sv.jac").write_text('def:pub fetch_count() -> int { return 7; }\n');
        (pkg / "index.cl.jac").write_text(
            'sv import from api { fetch_count }\n\n'
            'def:pub show() -> int { return fetch_count(); }\n'
        );
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "svlib"\nversion = "1.0.0"\n\n'
            '[project.include]\npackages = ["svlib"]\n'
        );
        cfg.project_root = Path(tmpdir);
        raised = False;
        try {
            NpmBuilder(config=cfg, project_root=Path(tmpdir)).build();
        } except NpmBoundaryError {
            raised = True;
        }
        assert raised;
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


# Phase 2: runtime + react ------------------------------------------------------------
test "JSX module wires the runtime import and adds @jaseci/runtime dependency" {
    tmpdir = tempfile.mkdtemp();
    try {
        pkg = Path(tmpdir) / "ui";
        pkg.mkdir(parents=True, exist_ok=True);
        (pkg / "index.cl.jac").write_text(
            'def:pub Button(label: str) -> any {\n'
            '    return <button class="btn">{label}</button>;\n'
            '}\n'
        );
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "ui"\nversion = "1.0.0"\n\n'
            '[project.include]\npackages = ["ui"]\n'
        );
        cfg.project_root = Path(tmpdir);
        data = NpmBuilder(config=cfg, project_root=Path(tmpdir)).build();
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
            pj = json.loads(tf.extractfile("package/package.json").read().decode());
            assert RUNTIME_PKG_NAME in pj["dependencies"];
            js = tf.extractfile("package/ui/index.js").read().decode();
            assert f'from "{RUNTIME_PKG_NAME}"' in js;
            assert "__jacJsx" in js;
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "build_runtime_tarball packages the runtime with exports" {
    data = build_runtime_tarball("1.2.3");
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
        names = tf.getnames();
        assert "package/package.json" in names;
        pj = json.loads(tf.extractfile("package/package.json").read().decode());
        assert pj["name"] == RUNTIME_PKG_NAME;
        assert pj["version"] == "1.2.3";
        # The split-out shared core must travel inside the package, or it fails to
        # load at runtime (ERR_MODULE_NOT_FOUND on `./jaclang/.../client_runtime_core.js`).
        assert "package/index.js" in names;
        assert "package/jaclang/runtimelib/client_runtime_core.js" in names;
        js = tf.extractfile("package/index.js").read().decode();
        assert "export {" in js;
        # The public API is exported exactly once — no duplicate export (invalid ESM).
        exported = _exported_names(js);
        assert "__jacJsx" in exported;
        assert "__jacSpawn" in exported;
        assert len(exported) == len(set(exported)) , (
            f"duplicate export in runtime index.js: {sorted(exported)}"
        );
        # The entry imports the core's symbols from the bundled sibling module.
        assert "./jaclang/runtimelib/client_runtime_core.js" in js;
        # The runtime is built on @tanstack/react-form, so NO `.js` in the package
        # pulls in the legacy react-hook-form library (checked across the entry
        # AND the bundled core).
        for member in names {
            if member.endswith(".js") {
                src = tf.extractfile(member).read().decode();
                assert "react-hook-form" not in src , f"{member} imports react-hook-form";
                assert "@hookform" not in src , f"{member} imports @hookform";
            }
        }
        # peerDependencies reflect the packages the runtime actually imports,
        # versioned from the canonical React client-dep set. `react-dom` lives in
        # the generated entry script (not this module), so it is absent here.
        peers = pj["peerDependencies"];
        assert peers["react"] == "^18.2.0";
        assert peers["react-router-dom"] == "^6.22.0";
        assert peers["@tanstack/react-form"] == "^1.33.0";
        assert peers["zod"] == "^4.3.6";
        assert "react-dom" not in peers;
        assert "react-hook-form" not in peers;
    }
}

test "runtime_peer_deps raises for unknown imported packages" {
    raised = False;
    try {
        runtime_peer_deps('import foo from "left-pad";\n');
    } except ValueError {
        raised = True;
    }
    assert raised;
    peers = runtime_peer_deps('import { useState } from "react";\n');
    assert peers["react"] == "^18.2.0";
}

test "runtime_pkg_name suffixes non-react backends so packages never collide" {
    # React and Preact share `client_runtime.cl.jac` → the canonical package name.
    assert runtime_pkg_name("react") == RUNTIME_PKG_NAME;
    assert runtime_pkg_name("preact") == RUNTIME_PKG_NAME;
    # Solid compiles its own shim → a suffixed package.
    assert runtime_pkg_name("solid") == f"{RUNTIME_PKG_NAME}-solid";
}

test "build_runtime_tarball packages the Solid runtime with no React ecosystem" {
    data = build_runtime_tarball("1.2.3", framework="solid");
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
        names = tf.getnames();
        pj = json.loads(tf.extractfile("package/package.json").read().decode());
        assert pj["name"] == f"{RUNTIME_PKG_NAME}-solid";
        assert pj["version"] == "1.2.3";
        # The shared core travels in the package at its relative import path.
        assert "package/index.js" in names;
        assert "package/jaclang/runtimelib/client_runtime_core.js" in names;
        js = tf.extractfile("package/index.js").read().decode();
        # Branch 5: solid-js/h hyperscript import removed; user component code
        # uses the JSX compiler path (vite-plugin-solid). Core symbols are present.
        assert "solid-js/h" not in js;
        assert "jacIsLoggedIn" in js;
        assert "JacClientErrorBoundary" in js;
        # __jacJsx is NOT part of the public surface; it must not appear in
        # the export clause (impl-JSX may still call it internally).
        exported = _exported_names(js);
        assert "jacIsLoggedIn" in exported;
        assert "__jacJsx" not in exported;
        assert len(exported) == len(set(exported)) , (
            f"duplicate export in solid index.js: {sorted(exported)}"
        );
        # The whole point of the split: NO `.js` in the package pulls in a React
        # ecosystem package (checked across the entry AND the bundled core).
        for member in names {
            if member.endswith(".js") {
                src = tf.extractfile(member).read().decode();
                assert 'from "react"' not in src , f"{member} imports react";
                assert "react-dom" not in src , f"{member} imports react-dom";
                assert "react-router" not in src , f"{member} imports react-router";
            }
        }
        # Solid peerDependencies — Solid-native packages only, versioned from the
        # canonical Solid client-dep set; no React-ecosystem peer.
        peers = pj["peerDependencies"];
        assert peers["solid-js"] == "^1.9.13";
        assert peers["@solidjs/router"] == "^0.16.1";
        assert peers["@tanstack/solid-form"] == "^1.33.0";
        assert peers["zod"] == "^4.3.6";
        assert "react" not in peers;
        assert "react-dom" not in peers;
    }
}

test "@jac/runtime surface-parity: all core symbols appear in React and Solid shims" {
    react_names = runtime_api_names("react");
    solid_names = runtime_api_names("solid");
    for sym in CORE_RUNTIME_SYMBOLS {
        assert sym in react_names , f"React shim missing core symbol: {sym}";
        assert sym in solid_names , f"Solid shim missing core symbol: {sym}";
    }
    # Each shim exposes framework-specific extras beyond the shared core.
    assert len(react_names) > len(CORE_RUNTIME_SYMBOLS);
    assert len(solid_names) > len(CORE_RUNTIME_SYMBOLS);
}

test "react import is recorded as a peerDependency" {
    tmpdir = tempfile.mkdtemp();
    try {
        pkg = Path(tmpdir) / "rx";
        pkg.mkdir(parents=True, exist_ok=True);
        (pkg / "index.cl.jac").write_text(
            'import from react { useState }\n\n'
            'def:pub useCounter() -> any { return useState(0); }\n'
        );
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "rx"\nversion = "1.0.0"\n\n'
            '[project.include]\npackages = ["rx"]\n'
        );
        cfg.project_root = Path(tmpdir);
        data = NpmBuilder(config=cfg, project_root=Path(tmpdir)).build();
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
            pj = json.loads(tf.extractfile("package/package.json").read().decode());
            assert "react" in pj["peerDependencies"];
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


# Phase 3: TypeScript declarations ----------------------------------------------------
test "jac_type_to_ts emits idiomatic TypeScript" {
    assert jac_type_to_ts("int") == "number";
    assert jac_type_to_ts("None", is_return=True) == "void";
    assert jac_type_to_ts("list[int]") == "Array<number>";
    assert jac_type_to_ts("dict[str, int]") == "Record<string, number>";
    assert jac_type_to_ts("any") == "any";
}

test "dts_for_module declares exported functions, classes, and globals" {
    tmpdir = tempfile.mkdtemp();
    try {
        src = Path(tmpdir) / "lib.cl.jac";
        src.write_text(
            'glob:pub VERSION: str = "1.0.0";\n\n'
            'obj:pub Point {\n    has x: int = 0,\n        y: int = 0;\n}\n\n'
            'def:pub add(a: int, b: int) -> int { return a + b; }\n'
            'def:pub names(items: list[str]) -> int { return len(items); }\n'
        );
        mod = JacProgram().compile(str(src));
        dts = dts_for_module(mod);
        assert "export declare function add(a: number, b: number): number;" in dts;
        assert "export declare function names(items: Array<string>): number;" in dts;
        assert "export declare class Point {" in dts;
        assert "x: number;" in dts;
        assert "export declare const VERSION: string;" in dts;
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "NpmBuilder emits .d.ts files and sets package.json types" {
    tmpdir = tempfile.mkdtemp();
    try {
        _scaffold_lib(tmpdir, "mylib");
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "mylib"\nversion = "1.0.0"\n\n'
            '[project.include]\npackages = ["mylib"]\n'
        );
        cfg.project_root = Path(tmpdir);
        data = NpmBuilder(config=cfg, project_root=Path(tmpdir)).build();
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
            names = tf.getnames();
            assert "package/mylib/index.d.ts" in names;
            pj = json.loads(tf.extractfile("package/package.json").read().decode());
            assert pj["types"] == "mylib/index.d.ts";
            assert pj["exports"]["."]["types"] == "./mylib/index.d.ts";
            dts = tf.extractfile("package/mylib/index.d.ts").read().decode();
            assert "export declare function add(a: number, b: number): number;" in dts;
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


# CLI --------------------------------------------------------------------------
test "jac bundle --target npm writes a tarball to dist/" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _scaffold_lib(tmp_path, "mylib");
        result = run(
            ["jac", "bundle", "--target", "npm"], capture_output=True, text=True
        );
        assert result.returncode == 0 , (
            f"exit {result.returncode}\nstdout: {result.stdout}\nstderr: {result.stderr}"
        );
        tgz_files = list((Path(tmp_path) / "dist").glob("*.tgz"));
        assert len(tgz_files) == 1;
        assert tgz_files[0].name == "mylib-1.0.0.tgz";
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}
