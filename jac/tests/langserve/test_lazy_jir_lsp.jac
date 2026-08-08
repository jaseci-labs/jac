"""LSP acceptance and performance gates for lazy .pyi JIR caching."""

import contextlib;
import os;
import shutil;
import tempfile;
import time;
import pytest;
import jaclang.lsp.types as lspt;
import from jaclang.jac0core.jir { get_module_cache_path, }
import from jaclang.jac0core.jir_passes { JirReader, JirWriter }
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
        mod = orig_read(self, data);
        if mod is not None {
            metrics.jir_reads += 1;
            # Count nodes actually materialized by this read, not the header's
            # total. Under lazy hydration (v19 stubs) this is the eager tier
            # only; the two coincide for fully-hydrated (.jac / legacy) reads.
            metrics.jir_hydrated_nodes += self.hydrated_node_count;
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

        # Warm run with the memo still cold: typing.pyi (use_str=None) is a
        # first-class disk-cache citizen and must hydrate from JIR. builtins.pyi
        # is patched via use_str, so its disk entry is inert (the read is skipped
        # whenever use_str is set); it is covered by the memo gate below.
        _stub_module_memo.clear();
        (_warm_lsp, warm_metrics, warm_ms) = _lsp_typecheck_with_metrics(
            FIXTURE_DIR, client_path
        );
        _assert_stub_not_recompiled(warm_metrics, typing_stub);
        assert warm_metrics.jir_reads >= cold_metrics.jir_reads , (
            "warm run should hydrate at least as many JIR modules from disk"
        );
        assert warm_metrics.jir_hydrated_nodes > 0 , (
            "warm run should hydrate JIR nodes from cache"
        );

        # Memo gate: builtins.pyi is patched via use_str and disk-inert, so in
        # production it is served warm by the process-wide _stub_module_memo
        # (content-hash keyed). Populate the memo, then a second run with the
        # memo intact must not re-source-compile builtins.
        _stub_module_memo.clear();
        _lsp_typecheck_with_metrics(FIXTURE_DIR, client_path);
        (_memo_warm_lsp, memo_warm_metrics, memo_warm_ms) = _lsp_typecheck_with_metrics(
            FIXTURE_DIR, client_path
        );
        _assert_stub_not_recompiled(memo_warm_metrics, builtins_stub);

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
                + " memo_warm_pyi_compiles="
                + str(memo_warm_metrics.pyi_compile_calls)
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

"""Round-trip a stub through JIR and return (blob, total_node_count)."""
def _stub_jir_blob(stub_path: str) -> tuple[bytes, int] {
    prog = JacProgram();
    mod = prog.load_dependency_module(stub_path);
    writer = JirWriter();
    blob = writer.write_module(mod, sections={});
    return (blob, len(writer._nodes));
}

test "lazy jir hydrates stub declarations on demand" {
    # A class-heavy stub must load only its eager tier (module shell + symbol
    # table) up front, then materialize each class/function subtree the first
    # time it is touched -- with results identical to a full hydrate.
    import from pathlib { Path }
    builtins_stub = _require_typeshed_stub("builtins.pyi");
    resolved = str(Path(builtins_stub).resolve());
    (blob, total) = _stub_jir_blob(builtins_stub);
    assert total > 0 , "expected a non-empty stub";

    prev_flag = os.environ.get("JAC_LAZY_JIR");

    def _restore {
        if prev_flag is None {
            os.environ.pop("JAC_LAZY_JIR", None);
        } else {
            os.environ["JAC_LAZY_JIR"] = prev_flag;
        }
    }
    try {
        # Full-hydrate reference.
        os.environ["JAC_LAZY_JIR"] = "0";
        full_reader = JirReader(_source_path=resolved);
        full_mod = full_reader.read_module(blob);
        assert full_mod is not None;
        assert full_reader.hydrated_node_count == total ,
            "full-hydrate read must materialize every node";
        ref_syms = sorted(full_mod.names_in_scope.keys());

        # Lazy read: eager tier only.
        os.environ["JAC_LAZY_JIR"] = "1";
        lazy_reader = JirReader(_source_path=resolved);
        lazy_mod = lazy_reader.read_module(blob);
        assert lazy_mod is not None;
        eager = lazy_reader.hydrated_node_count;
        assert eager < total // 2 ,
            "lazy eager tier should be well under half of the stub ("
                + str(eager) + " / " + str(total) + ")";

        # The full symbol table is available without hydrating any body.
        assert sorted(lazy_mod.names_in_scope.keys()) == ref_syms ,
            "lazy symbol table must match full hydrate";
        assert lazy_reader.hydrated_node_count == eager ,
            "listing symbols must not hydrate declaration bodies";

        # Typed cold shells: module.kid classes are the right node type before
        # any hydration.
        assert [type(k).__name__ for k in lazy_mod.kid]
            == [type(k).__name__ for k in full_mod.kid] ,
            "lazy kid node types must match full hydrate";

        # Touch one class: only its subtree hydrates, and its members match.
        target = None;
        for (nm, sym) in full_mod.names_in_scope.items() {
            if type(sym.decl.name_of).__name__ == "Archetype" {
                target = nm;
                break;
            }
        }
        assert target is not None , "expected at least one class in builtins";
        full_arch = full_mod.names_in_scope[target].decl.name_of;

        before = lazy_reader.hydrated_node_count;
        lazy_arch = lazy_mod.names_in_scope[target].decl.name_of;
        assert type(lazy_arch).__name__ == "Archetype";
        touched = lazy_reader.hydrated_node_count;
        assert touched > before , "touching a class should hydrate its chunk";
        assert touched < total ,
            "touching one class must not hydrate the whole module";
        assert sorted(lazy_arch.names_in_scope.keys())
            == sorted(full_arch.names_in_scope.keys()) ,
            "hydrated class members must match full hydrate";
        # Parent chain / scope link restored through in-place hydration.
        assert lazy_arch.parent is lazy_mod;
        assert lazy_arch.parent_scope is lazy_mod;

        print(
            "\nLazy-JIR hydration: total="
                + str(total)
                + " eager="
                + str(eager)
                + " after_one_class="
                + str(touched)
        );
    } finally {
        _restore();
    }
}
