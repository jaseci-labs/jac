"""LSP acceptance and performance gates for lazy .pyi JIR caching."""

import contextlib;
import os;
import shutil;
import tempfile;
import time;
import pytest;
import jaclang.lsp.types as lspt;
import from jaclang.jac0core.jir { get_module_cache_path, parse_header, }
import from jaclang.jac0core.jir_passes { JirReader }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.langserve.engine { JacLangServer }
import from jaclang.lsp { uris }
import from jaclang.lsp.server { Workspace }
import from tests.support { JAC_ROOT }

glob FIXTURE_DIR = os.path.join(
         os.path.dirname(os.path.abspath(__file__)), "fixtures"
     ),
     _active_servers: list = [];

obj LazyJirMetrics {
    has pyi_compile_calls: int = 0,
        pyi_compile_paths: list[str] = [],
        jir_reads: int = 0,
        jir_hydrated_nodes: int = 0;
}

"""Return absolute path to a langserve fixture file."""
def _fixture(name: str) -> str {
    return os.path.join(FIXTURE_DIR, name);
}

"""Return path to a vendored typeshed stdlib stub, or skip the test."""
def _require_typeshed_stub(rel_path: str) -> str {
    stub = os.path.join(JAC_ROOT, "jaclang", "vendor", "typeshed", "stdlib", rel_path);
    if not os.path.isfile(stub) {
        pytest.skip(
            "typeshed stub missing at "
                + stub
                + " (run launcher/payload fetch-typeshed)"
        );
    }
    return stub;
}

"""Create a JacLangServer wired to the given workspace."""
def _create_server(workspace_path: str) -> JacLangServer {
    lsp = JacLangServer();
    workspace_val = Workspace(root_uri=uris.from_fs_path(workspace_path));
    lsp.lsp._workspace = workspace_val;
    _active_servers.append(lsp);
    return lsp;
}

def _setup_test {
    _active_servers.clear();
}

def _teardown_test {
    for server in _active_servers {
        with contextlib.suppress(Exception) as _s {
            server.shutdown();
        }
        server.clear_type_system(clear_hub=True);
    }
    _active_servers.clear();
}

"""Install compile/JIR counters; returns (metrics, restore)."""
def _install_lazy_jir_counters -> tuple[LazyJirMetrics, object] {
    import from pathlib { Path }
    import from jaclang.jac0core.jir { read_module_jir_cache }

    metrics = LazyJirMetrics();
    orig_compile = JacProgram.compile;
    orig_load = JacProgram.load_dependency_module;
    orig_read = JirReader.read_module;

    def counting_compile(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        no_cgen: bool = False,
        type_check: bool = False,
        symtab_ir_only: bool = False,
        cancel_token = None,
        options = None
    ) -> object {
        if file_path.endswith(".pyi") {
            metrics.pyi_compile_calls += 1;
            metrics.pyi_compile_paths.append(file_path);
        }
        return orig_compile(
            self,
            file_path,
            use_str=use_str,
            no_cgen=no_cgen,
            type_check=type_check,
            symtab_ir_only=symtab_ir_only,
            cancel_token=cancel_token,
            options=options
        );
    }

    def counting_load(
        self: JacProgram,
        source_path: str,
        importer_path: (str | None) = None,
        use_str: (str | None) = None
    ) -> object {
        source_build = False;
        if source_path.endswith(".pyi") {
            resolved_path = str(Path(source_path).resolve());
            compiler = self._get_compiler();
            target_hub = compiler._resolve_program(resolved_path, self).mod.hub;
            if (
                resolved_path not in self.mod.hub
                and resolved_path not in target_hub
                and read_module_jir_cache(resolved_path) is None
            ) {
                source_build = True;
            }
        }
        mod = orig_load(
            self, source_path, importer_path=importer_path, use_str=use_str
        );
        if source_build {
            metrics.pyi_compile_calls += 1;
            metrics.pyi_compile_paths.append(source_path);
        }
        return mod;
    }

    def counting_read(self: JirReader, data: bytes) -> object {
        hdr = parse_header(data);
        if hdr is not None {
            metrics.jir_hydrated_nodes += hdr.node_count;
        }
        mod = orig_read(self, data);
        if mod is not None {
            metrics.jir_reads += 1;
        }
        return mod;
    }

    JacProgram.compile = counting_compile;
    JacProgram.load_dependency_module = counting_load;
    JirReader.read_module = counting_read;

    def restore {
        JacProgram.compile = orig_compile;
        JacProgram.load_dependency_module = orig_load;
        JirReader.read_module = orig_read;
    }

    return (metrics, restore);
}

"""Return True when a source path matches the target stub path."""
def _same_source_path(left: str, right: str) -> bool {
    return os.path.realpath(left) == os.path.realpath(right);
}

"""Assert the target stub was not source-compiled during the measured window."""
def _assert_stub_not_recompiled(metrics: LazyJirMetrics, stub_path: str) {
    for compiled in metrics.pyi_compile_paths {
        assert not _same_source_path(compiled, stub_path) , (
            "warm .pyi cache should skip source compile for "
            + stub_path
            + "; recompiled via "
            + compiled
        );
    }
}

"""Delete on-disk JIR cache for a source path if present."""
def _unlink_cache(source_path: str) {
    cache_path = get_module_cache_path(source_path);
    if cache_path.exists() {
        cache_path.unlink();
    }
}

"""Warm the on-disk JIR cache for a .pyi stub."""
def _warm_pyi_cache(stub_path: str) {
    past = time.time() - 2;
    os.utime(stub_path, (past, past));
    prog = JacProgram();
    prog.load_dependency_module(stub_path);
    cache_path = get_module_cache_path(stub_path);
    assert cache_path.exists() , "expected JIR cache after warming " + stub_path;
}

"""Run one LSP type-check pass and collect lazy-JIR metrics."""
def _lsp_typecheck_with_metrics(
    workspace: str, jac_file: str
) -> tuple[JacLangServer, LazyJirMetrics, float] {
    (metrics, restore) = _install_lazy_jir_counters();
    try {
        t0 = time.perf_counter();
        lsp = _create_server(workspace);
        lsp.type_check_file(uris.from_fs_path(jac_file));
        elapsed_ms = (time.perf_counter() - t0) * 1000.0;
        return (lsp, metrics, elapsed_ms);
    } finally {
        restore();
    }
}

test "lsp warm local pyi cache skips stub recompile" {
    _setup_test();
    try {
        stub_path = _fixture("lazy_jir_local_stub.pyi");
        client_path = _fixture("lazy_jir_local_stub_client.jac");
        _warm_pyi_cache(stub_path);

        (lsp, metrics, _elapsed) = _lsp_typecheck_with_metrics(
            FIXTURE_DIR, client_path
        );
        _assert_stub_not_recompiled(metrics, stub_path);
        assert metrics.jir_reads >= 1 , "expected at least one JIR cache read";
        assert lsp.diagnostics.get(uris.from_fs_path(client_path), []) == [] , (
            "unexpected diagnostics on warm-cache LSP run"
        );
    } finally {
        _teardown_test();
        _unlink_cache(_fixture("lazy_jir_local_stub.pyi"));
    }
}

test "lsp warm pyi cache preserves goto-def semantics" {
    _setup_test();
    try {
        stub_path = _fixture("lazy_jir_local_stub.pyi");
        client_path = _fixture("lazy_jir_local_stub_client.jac");
        client_uri = uris.from_fs_path(client_path);
        _warm_pyi_cache(stub_path);

        (lsp, _metrics, _elapsed) = _lsp_typecheck_with_metrics(
            FIXTURE_DIR, client_path
        );

        count_def = lsp.get_definition(client_uri, lspt.Position(4, 14));
        assert count_def is not None , "go-to-def for stub field count should resolve";
        assert stub_path in uris.to_fs_path(count_def.uri) , (
            "count definition must point at original .pyi, got: " + str(count_def.uri)
        );
        assert count_def.range.start.line >= 2 , (
            "count definition should land on the stub declaration, got range "
            + str(count_def.range)
        );
    } finally {
        _teardown_test();
        _unlink_cache(_fixture("lazy_jir_local_stub.pyi"));
    }
}

test "lsp pyi cache invalidates after stub edit" {
    _setup_test();
    backup_dir = tempfile.mkdtemp(prefix="lazy_jir_stub_backup_");
    stub_path = _fixture("lazy_jir_local_stub.pyi");
    client_path = _fixture("lazy_jir_local_stub_client.jac");
    backup_path = os.path.join(backup_dir, "lazy_jir_local_stub.pyi");
    try {
        shutil.copy2(stub_path, backup_path);
        _warm_pyi_cache(stub_path);

        with open(stub_path, "a") as f {
            f.write("\nclass ExtraProbe:\n    flag: bool\n");
        }
        future = time.time() + 5;
        os.utime(stub_path, (future, future));

        (lsp, metrics, _elapsed) = _lsp_typecheck_with_metrics(
            FIXTURE_DIR, client_path
        );
        recompiled = False;
        for compiled in metrics.pyi_compile_paths {
            if _same_source_path(compiled, stub_path) {
                recompiled = True;
                break;
            }
        }
        assert recompiled , "edited local stub should be source-compiled";
        assert lsp.diagnostics.get(uris.from_fs_path(client_path), []) == [] , (
            "type-check should succeed after stub invalidation"
        );
    } finally {
        shutil.copy2(backup_path, stub_path);
        past = time.time() - 2;
        os.utime(stub_path, (past, past));
        shutil.rmtree(backup_dir, ignore_errors=True);
        _teardown_test();
        _unlink_cache(stub_path);
    }
}

test "lsp corrupt pyi jir falls back to source compile" {
    _setup_test();
    try {
        stub_path = _fixture("lazy_jir_local_stub.pyi");
        client_path = _fixture("lazy_jir_local_stub_client.jac");
        _warm_pyi_cache(stub_path);
        cache_path = get_module_cache_path(stub_path);
        cache_path.write_bytes(b"corrupt-jir-data");

        (lsp, metrics, _elapsed) = _lsp_typecheck_with_metrics(
            FIXTURE_DIR, client_path
        );
        recompiled = False;
        for compiled in metrics.pyi_compile_paths {
            if _same_source_path(compiled, stub_path) {
                recompiled = True;
                break;
            }
        }
        assert recompiled , "corrupt cache should fall back to source compile";
        assert lsp.get_definition(uris.from_fs_path(client_path), lspt.Position(4, 14))
            is not None , "go-to-def should still work after corrupt-cache fallback";
    } finally {
        _teardown_test();
        _unlink_cache(_fixture("lazy_jir_local_stub.pyi"));
    }
}

test "lsp typeshed warm cache preserves builtins and typing goto-def" {
    _setup_test();
    try {
        builtins_stub = _require_typeshed_stub("builtins.pyi");
        typing_stub = _require_typeshed_stub("typing.pyi");
        _warm_pyi_cache(builtins_stub);
        _warm_pyi_cache(typing_stub);

        client_path = _fixture("any_goto_def_tests.jac");
        (lsp, metrics, _elapsed) = _lsp_typecheck_with_metrics(
            FIXTURE_DIR, client_path
        );
        _assert_stub_not_recompiled(metrics, builtins_stub);
        _assert_stub_not_recompiled(metrics, typing_stub);

        client_uri = uris.from_fs_path(client_path);
        bt_any = str(lsp.get_definition(client_uri, lspt.Position(1, 13)));
        assert "builtins.pyi" in bt_any , f"Unexpected builtins go-to-def: {bt_any}";

        bare_any = str(lsp.get_definition(client_uri, lspt.Position(4, 8)));
        assert "typing.pyi" in bare_any , f"Unexpected typing go-to-def: {bare_any}";
    } finally {
        _teardown_test();
    }
}

test "lazy jir performance gate cold versus warm pyi cache" {
    import from jaclang.compiler.type_system.type_evaluator { _stub_module_memo }

    _setup_test();
    try {
        builtins_stub = _require_typeshed_stub("builtins.pyi");
        typing_stub = _require_typeshed_stub("typing.pyi");
        client_path = _fixture("any_goto_def_tests.jac");

        _unlink_cache(builtins_stub);
        _unlink_cache(typing_stub);
        _stub_module_memo.clear();

        (_cold_lsp, cold_metrics, cold_ms) = _lsp_typecheck_with_metrics(
            FIXTURE_DIR, client_path
        );
        assert cold_metrics.pyi_compile_calls >= 2 , (
            "cold run should compile typeshed stubs; got "
            + str(cold_metrics.pyi_compile_calls)
        );

        _stub_module_memo.clear();
        (_warm_lsp, warm_metrics, warm_ms) = _lsp_typecheck_with_metrics(
            FIXTURE_DIR, client_path
        );
        _assert_stub_not_recompiled(warm_metrics, builtins_stub);
        _assert_stub_not_recompiled(warm_metrics, typing_stub);
        assert warm_metrics.jir_reads >= cold_metrics.jir_reads , (
            "warm run should hydrate at least as many JIR modules from disk"
        );
        assert warm_metrics.jir_hydrated_nodes > 0 , (
            "warm run should hydrate JIR nodes from cache"
        );

        print(
            "\nLazy-JIR perf gate:"
                + " cold_ms="
                + str(round(cold_ms, 1))
                + " warm_ms="
                + str(round(warm_ms, 1))
                + " cold_pyi_compiles="
                + str(cold_metrics.pyi_compile_calls)
                + " warm_pyi_compiles="
                + str(warm_metrics.pyi_compile_calls)
                + " warm_jir_reads="
                + str(warm_metrics.jir_reads)
                + " warm_jir_nodes="
                + str(warm_metrics.jir_hydrated_nodes)
        );

        # Timing can fluctuate in CI; the hard gate is compile avoidance.
        if warm_ms > cold_ms * 2.0 {
            print(
                "note: warm LSP pass slower than 2x cold; "
                    + "compile-skip invariant still holds"
            );
        }
    } finally {
        _teardown_test();
    }
}
