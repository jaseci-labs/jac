"""Regression tests for compiler-owned runtime import emission (#7546).

Codegen must inject required ``@jac/runtime`` imports through the ESTree import
mechanism so ``mod.gen.js`` is emission-ready without consumer-side finalizers.
"""

import os;
import re;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.backends.preact { PreactBackend }
import from jaclang.compiler.passes.ecmascript.backends.solid { SolidBackend }
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.cli.mcp.compiler_bridge { CompilerBridge }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     ),
     _MINIMAL_JSX = 'cl def:pub render(items: list) -> any {\n    return <div>{items}</div>;\n}\n';

"""Count named import bindings for a runtime symbol."""
def _count_runtime_imports(js: str, symbol: str) -> int {
    pattern = 'import\\s*\\{[^}]*\\b' + re.escape(symbol) + '\\b';
    return len(re.findall(pattern, js));
}

"""Compile a fixture through the production ``mod.gen.js`` path."""
def _compile_raw_js(path: str) -> str {
    prog = JacProgram();
    mod = prog.compile(file_path=path);
    assert not prog.errors_had , f"compile errors: {prog.errors_had}";
    js = (mod.gen.js if mod and mod.gen else "") or "";
    assert js.strip() , f"expected non-empty JS for {path}";
    return js;
}

"""Compile a fixture with an explicit framework backend (no finalizer)."""
def _compile_with_backend(path: str, backend: any) -> str {
    prog = JacProgram();
    ir = prog.compile(file_path=path, no_cgen=True);
    fatal = [
        e
        for e in prog.errors_had
        if not issubclass(e.from_pass, TypeCheckPass)
    ];
    assert not fatal , f"compile errors in {path}: {[str(e) for e in fatal]}";
    es_pass = EsastGenPass(ir_in=ir, prog=prog, backend=backend);
    return es_to_js(es_pass.ir_out.gen.es_ast);
}

"""Write inline Jac to a temp file and return its path."""
def _write_temp_jac(code: str) -> str {
    with tempfile.NamedTemporaryFile(mode="w", suffix=".cl.jac", delete=False) as tmp {
        tmp.write(code);
        return tmp.name;
    }
}

test "raw React JSX imports __jacJsx from @jac/runtime" {
    path = _write_temp_jac(_MINIMAL_JSX);
    try {
        js = _compile_raw_js(path);
        assert "__jacJsx(" in js , "React JSX lowering must reference __jacJsx";
        assert _count_runtime_imports(js, "__jacJsx") == 1 , (
            "React JSX must import __jacJsx exactly once:\n" + js[:400]
        );
        assert 'from "@jac/runtime"' in js , (
            "React JSX must import from @jac/runtime"
        );
    } finally {
        os.unlink(path);
    }
}

test "raw Preact JSX imports __jacJsx from @jac/runtime" {
    path = _write_temp_jac(_MINIMAL_JSX);
    try {
        js = _compile_with_backend(path, PreactBackend());
        assert "__jacJsx(" in js , "Preact JSX lowering must reference __jacJsx";
        assert _count_runtime_imports(js, "__jacJsx") == 1 , (
            "Preact JSX must import __jacJsx exactly once:\n" + js[:400]
        );
        assert 'from "@jac/runtime"' in js , (
            "Preact JSX must import from @jac/runtime"
        );
    } finally {
        os.unlink(path);
    }
}

test "raw Solid JSX does not reference or import __jacJsx" {
    path = _write_temp_jac(_MINIMAL_JSX);
    try {
        js = _compile_with_backend(path, SolidBackend());
        assert "__jacJsx" not in js , (
            "Solid JSX must not reference the React factory symbol"
        );
        assert "<" in js , "Solid JSX should lower to native JSX syntax";
    } finally {
        os.unlink(path);
    }
}

test "Solid compiler-created fragments stay backend-native" {
    js = _compile_with_backend(
        os.path.join(FIXTURES, "view_basic.cl.jac"), SolidBackend()
    );
    assert "__jacJsx" not in js , (
        "Solid slot fragments must not import the React JSX factory"
    );
    assert "<>" in js , (
        "Solid compiler-created fragments must lower to native JSX fragments"
    );
}

test "MCP CompilerBridge.jac_to_js emits runtime imports" {
    result = CompilerBridge.jac_to_js(_MINIMAL_JSX);
    assert not result["warnings"] , (f"MCP jac_to_js warnings: {result['warnings']}");
    js = result["js_code"];
    assert js.strip() , "MCP jac_to_js must produce non-empty JS output";
    assert _count_runtime_imports(js, "__jacJsx") == 1 , (
        "MCP jac_to_js must import __jacJsx exactly once:\n" + js[:400]
    );
    assert 'from "@jac/runtime"' in js , (
        "MCP jac_to_js must import from @jac/runtime"
    );
}

test "remote spawn imports __jacSpawn from @jac/runtime" {
    js = _compile_raw_js(os.path.join(FIXTURES, "typed_walker_spawn.jac"));
    assert "__jacSpawn(" in js , "spawn lowering must reference __jacSpawn";
    assert _count_runtime_imports(js, "__jacSpawn") == 1 , (
        "spawn must import __jacSpawn exactly once:\n" + js[:400]
    );
    assert 'from "@jac/runtime"' in js , (
        "spawn must import __jacSpawn from @jac/runtime"
    );
}

test "runtime source does not self-import @jac/runtime" {
    import importlib;
    plugin = importlib.import_module("jaclang.runtimelib.client");
    paths = list(getattr(plugin, "__path__", []) or []);
    assert paths , "jaclang.runtimelib.client must be importable";
    core_src = os.path.join(paths[0], "client_runtime_core.cl.jac");
    assert os.path.isfile(core_src) , (
        "client_runtime_core.cl.jac is part of jaclang and must be present"
    );
    js = _compile_raw_js(core_src);
    assert "function __jacJsx" in js , "runtime core must define __jacJsx";
    assert _count_runtime_imports(js, "__jacJsx") == 0 , (
        "runtime core must not import __jacJsx from itself"
    );
    assert _count_runtime_imports(js, "__jacSpawn") == 0 , (
        "runtime core must not import __jacSpawn from itself"
    );
    assert "@jac/runtime" not in js , ("runtime core must not reference @jac/runtime");
}

test "runtime_peer_deps rejects @jac/runtime self-import" {
    import from jaclang.publish.runtime_npm { runtime_peer_deps }
    raised = False;
    try {
        runtime_peer_deps('import {__jacJsx} from "@jac/runtime";\n');
    } except ValueError {
        raised = True;
    }
    assert raised , (
        "peer dependency collection must reject @jac/runtime self-imports"
    );
}

test "build_runtime_tarball React runtime does not self-import @jac/runtime" {
    import from jaclang.publish.runtime_npm { build_runtime_tarball }
    data = build_runtime_tarball("1.2.3");
    assert data , "expected non-empty React runtime tarball";
    import io;
    import json;
    import tarfile;
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
        index_js = tf.extractfile("package/index.js").read().decode();
        assert "@jac/runtime" not in index_js , (
            "runtime package must not import from itself"
        );
        pj = json.loads(tf.extractfile("package/package.json").read().decode());
        assert "@jac/runtime" not in pj.get("peerDependencies", {}) , (
            "runtime package must not list itself as a peer dependency"
        );
    }
}

test "build_runtime_tarball Solid runtime does not self-import @jac/runtime" {
    import from jaclang.publish.runtime_npm { build_runtime_tarball }
    data = build_runtime_tarball("1.2.3", framework="solid");
    assert data , "expected non-empty Solid runtime tarball";
    import io;
    import json;
    import tarfile;
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
        index_js = tf.extractfile("package/index.js").read().decode();
        assert "@jac/runtime" not in index_js , (
            "Solid runtime package must not import from itself"
        );
        pj = json.loads(tf.extractfile("package/package.json").read().decode());
        assert "@jac/runtime" not in pj.get("peerDependencies", {}) , (
            "Solid runtime package must not list itself as a peer dependency"
        );
    }
}

test "published npm JS remaps the runtime import exactly once" {
    import from jaclang.project.config { JacConfig }
    import from jaclang.publish.npm_sources { collect_npm_sources }
    import from jaclang.publish.runtime_npm { RUNTIME_PKG_NAME }
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
        files = collect_npm_sources(cfg, project_root=Path(tmpdir));
        assert len(files) == 1 , f"expected one npm source, got {len(files)}";
        js = files[0].js;
        assert _count_runtime_imports(js, "__jacJsx") == 1 , (
            "published JSX must import __jacJsx exactly once:\n" + js[:400]
        );
        assert f'from "{RUNTIME_PKG_NAME}"' in js , (
            f"published JSX must import from {RUNTIME_PKG_NAME}"
        );
        assert "@jac/runtime" not in js , (
            "published JSX must not retain compiler-internal @jac/runtime"
        );
    } finally {
        import shutil;
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}
