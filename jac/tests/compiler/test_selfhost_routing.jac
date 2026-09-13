"""A program's native stdlib dependencies live in that program, not in the
process-global self-host program the running compiler keeps for its own
modules."""
import os;
import jaclang;
import from jaclang.compiler.session.session { JacProgram }


def _pkg_path(rel: str) -> str {
    pkg = os.path.dirname(os.path.abspath(str(jaclang.__file__)));
    return os.path.join(pkg, *rel.split("/"));
}


test "a native stdlib module resolves into the program that imports it" {
    prog = JacProgram();
    cache = prog._get_compiler().selfhost;
    assert not cache.is_selfhost(prog);
    sock = _pkg_path("runtime/na_stdlib/socket.jac");
    assert os.path.isfile(sock) , sock;
    assert cache.owns(sock) , "the native stdlib ships inside the jaclang tree";
    assert cache.resolve(sock, prog) is prog , (
        "a checked program's socket import was routed into the self-host hub,"
        " where its type memos would outlive this program's compile closure"
    );
}


test "a compiler module still resolves into the self-host program" {
    prog = JacProgram();
    cache = prog._get_compiler().selfhost;
    log_mod = _pkg_path("compiler/pipeline/log.jac");
    assert os.path.isfile(log_mod) , log_mod;
    assert cache.resolve(log_mod, prog) is cache.program;
    assert cache.resolve(log_mod, prog, force=True) is prog;
}

test "client runtime modules retain their consumer compilation context" {
    prog = JacProgram();
    cache = prog._get_compiler().selfhost;
    for relative in ["client/client_mobui.jac", "client/client_runtime_native.jac"] {
        path = _pkg_path(relative);
        assert cache.resolve(path, prog) is prog;
        assert cache.resolve(path, cache.program) is cache.program;
    }
}

test "shared construction runtime resolves into its consumer program" {
    prog = JacProgram();
    cache = prog._get_compiler().selfhost;
    fragment = _pkg_path("runtime/graph_fragment.jac");
    assert cache.owns(fragment);
    assert cache.resolve(fragment, prog) is prog;
    assert cache.resolve(fragment, cache.program) is cache.program;
}


test "the self-host program keeps its own native stdlib imports" {
    prog = JacProgram();
    cache = prog._get_compiler().selfhost;
    sock = _pkg_path("runtime/na_stdlib/socket.jac");
    assert cache.resolve(sock, cache.program) is cache.program;
}

test "lazy compiler bytecode does not inherit the caller's analysis request" {
    import from jaclang.compiler.pipeline.contracts { PassIdentity }
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.compiler.session.compiler { JacCompiler }
    import from jaclang.compiler.bootstrap.selfhost { SelfHostCache }
    import from jaclang.compiler.session.options { CompileOptions }
    import jaclang.compiler.pipeline.executor as driver;
    # Ensure the codec is available so unnecessary interface work is observable.
    import jaclang.compiler.session.cache.interface_codec;
    with TemporaryDirectory() as directory {
        base_path = Path(directory);
        toolchain = base_path / "toolchain";
        toolchain.mkdir();
        helper = toolchain / "helper.jac";
        helper.write_text("def answer() -> int { return 42; }\n");
        app = base_path / "main.jac";
        app.write_text("def application() -> int { return 1; }\n");
        internal = JacProgram();
        compiler = JacCompiler(
            _selfhost=SelfHostCache(_program=internal, _jaclang_root=str(toolchain))
        );
        internal._compiler = compiler;
        program = JacProgram();
        program._compiler = compiler;
        loaded: list[any] = [];
        original: any = driver.run_pass;
        def load_helper(
            pass_id: PassIdentity, ir_in: any, prog: any, **kwargs: any
        ) -> any {
            if pass_id == PassIdentity.SymTabBuildPass
                and ir_in.loc.mod_path == str(app)
                and not loaded {
                assert compiler._reentrant_depth > 0;
                loaded.append(
                    compiler.get_bytecode(str(helper), target_program=program)
                );
            }
            return original(pass_id, ir_in, prog, **kwargs);
        }
        with patch.object(driver, "run_pass", load_helper) {
            program.compile(
                str(app), options=CompileOptions(no_cgen=True, need_full_ast=True)
            );
        }
        assert len(loaded) == 1 and loaded[0] is not None;
        assert internal.analysis.cache_events.get("iface_encode", 0) == 0 , (
            "the caller's type check forced interfaces into lazy compiler code generation"
        );
        assert sum(
            context.analysis.cache_events.get("iface_encode", 0)
            for context in [program] + list(program.contexts.values())
        )
            > 0 , "the outer application analysis lost its interface request";
        assert compiler._closure_opts is None;
        assert not program.errors_had;
    }
}

test "application analysis does not eagerly publish selfhost dependency interfaces" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.compiler.session.compiler { JacCompiler }
    import from jaclang.compiler.bootstrap.selfhost { SelfHostCache }
    import from jaclang.compiler.session.options { CompileOptions }
    import jaclang.compiler.session.cache.interface_codec;
    import jaclang.compiler.session.cache.artifact_codec as jir;
    with TemporaryDirectory() as directory {
        base_path = Path(directory);
        toolchain = base_path / "toolchain";
        toolchain.mkdir();
        (toolchain / "api.jac").write_text("obj Api { has value: int = 42; }\n");
        app = base_path / "main.jac";
        app.write_text(
            "import from .toolchain.api { Api }\n"
                + "def application() -> int { return Api().value; }\n"
        );
        internal = JacProgram();
        compiler = JacCompiler(
            _selfhost=SelfHostCache(_program=internal, _jaclang_root=str(toolchain))
        );
        internal._compiler = compiler;
        program = JacProgram();
        program._compiler = compiler;
        tracked = jir.is_compiler_tree_path;
        api = str(toolchain / "api.jac");
        # This private toolchain's API stands in for a compiler-digest member.
        # Other files owned by SelfHostCache remain ordinary dependencies.
        def compiler_member(path: str) -> bool {
            return os.path.realpath(path) == api or tracked(path);
        }
        with patch.object(jir, "is_compiler_tree_path", side_effect=compiler_member) {
            program.compile(str(app), options=CompileOptions(no_cgen=True));
        }
        assert not program.errors_had;
        assert internal.analysis.cache_events.get("iface_encode", 0) == 0 , (
            "a symbol-only selfhost import eagerly encoded its public type closure"
        );
        assert sum(
            context.analysis.cache_events.get("iface_encode", 0)
            for context in [program] + list(program.contexts.values())
        )
            > 0 , "application analysis must still publish its requested interface";
        plugin = toolchain / "plugin.jac";
        plugin.write_text("obj Plugin { has value: int = 42; }\n");
        consumer = base_path / "plugin_user.jac";
        consumer.write_text(
            "import from .toolchain.plugin { Plugin }\n"
                + "def application() -> int { return Plugin().value; }\n"
        );
        program.compile(str(consumer), options=CompileOptions(no_cgen=True));
        assert not program.errors_had;
        assert program.iface_registry().cached_interface(str(plugin)) is not None , (
            "bundled libraries outside the compiler fingerprint need dependency interfaces"
        );
        explicit = internal.iface_registry().ensure(str(toolchain / "api.jac"));
        assert explicit is not None;
        assert internal.analysis.cache_events.get("iface_encode", 0) > 0 , (
            "explicit selfhost interface requests must remain available to packaging"
        );
    }
}
