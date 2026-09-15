"""Graph construction syntax and shared lowering contracts."""

import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.parser { parse as rd_parse }
import from jaclang.compiler.passes.graph_lowering_pass { GraphLoweringPass }
import from jaclang.compiler.tools.unparse_pass { UnparsePass }
import from jaclang.compiler.driver.program { JacProgram }

test "graph keyword supports escaped identifiers" {
    (module, errors) = rd_parse(
        "def `graph(x: int) -> int { return x; } with entry { y = `graph(1); f = graph { a ++> b; }; }",
        "graph_keyword.jac"
    );
    assert not errors;
    assert len(module.get_all_sub_nodes(uni.GraphExpr)) == 1;
}

test "graph preserves its surface for syntax tools" {
    (module, errors) = rd_parse(
        "with entry { f = graph { a ++> [b ++> c, d]; }; }", "graph_roundtrip.jac"
    );
    assert not errors;
    UnparsePass(ir_in=module);
    (again, errors2) = rd_parse(module.gen.jac, "graph_again.jac");
    assert not errors2;
    assert len(again.get_all_sub_nodes(uni.GraphExpr)) == 1;
    assert len(again.get_all_sub_nodes(uni.ConnectOp)) == 2;
}

test "graph formatting preserves comments and is stable" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from jaclang.compiler.driver.program { JacProgram }
    with TemporaryDirectory() as directory {
        path = Path(directory) / "graph_comments.jac";
        path.write_text(
            "with entry { f = graph { # opening\n a ++> b; # edge\n # closing\n }; }"
        );
        first = JacProgram.jac_file_formatter(str(path)).mod.main.gen.jac;
        for comment in ["# opening", "# edge", "# closing"] {
            assert first.count(comment) == 1;
        }
        path.write_text(first);
        second = JacProgram.jac_file_formatter(str(path)).mod.main.gen.jac;
        assert first == second;
        (_, errors) = rd_parse(second, str(path));
        assert not errors;
    }
}

test "graph lowers into existing control flow and captures connects" {
    (module, errors) = rd_parse(
        "with entry { f = graph { a ++> [b ++> c, d]; }; }", "graph_lower.jac"
    );
    assert not errors;
    lowered = GraphLoweringPass(ir_in=module);
    assert not lowered.errors_had;
    assert not module.get_all_sub_nodes(uni.GraphExpr);
    imports = module.get_all_sub_nodes(uni.Import);
    assert len(imports) == 1;
    assert isinstance(imports[0].parent, uni.LambdaExpr);
    assert len(module.get_all_sub_nodes(uni.InForStmt)) == 4;
    assert all(op.capture_edges for op in module.get_all_sub_nodes(uni.ConnectOp));
}

test "graph rejects unsupported directions with a source diagnostic" {
    for arrow in ["<++", "<++>"] {
        (module, errors) = rd_parse(
            "with entry { f = graph { a " + arrow + " b; }; }", "graph_direction.jac"
        );
        assert not errors;
        lowered = GraphLoweringPass(ir_in=module);
        assert any(e.code?.code == "E0084" for e in lowered.errors_had);
    }
}

test "generated construction imports inherit their enclosing codespace" {
    import from jaclang.compiler.frontend.constant { CodeContext }
    (module, errors) = rd_parse(
        "def build { return graph { a ++> b; }; }", "graph_context.jac"
    );
    assert not errors;
    GraphLoweringPass(ir_in=module);
    ability = module.get_all_sub_nodes(uni.Ability)[0];
    imp = module.get_all_sub_nodes(uni.Import)[0];
    for context in [CodeContext.CLIENT, CodeContext.NATIVE, CodeContext.SERVER] {
        ability.code_context = context;
        assert imp.code_context == context;
    }
}

test "graph roots retain their node type" {
    import from jaclang.compiler.driver.program { JacProgram }
    prog = JacProgram();
    prog.compile(
        "graph_root_type.jac",
        use_str='node N { has value: int; } def wrong -> str { f = graph { N(1) ++> N(2); }; return f.root.value; }',
        no_cgen=True
    );
    assert prog.errors_had , "returning an int as str must not disappear through an unknown fragment type";
}

test "graph refuses non-node roots" {
    import from jaclang.compiler.driver.program { JacProgram }
    prog = JacProgram();
    prog.compile(
        "graph_bad_root.jac", use_str="with entry { f = graph { 42; }; }", no_cgen=True
    );
    assert prog.errors_had , "graph construction must require node operands";
}

test "parameterless lambda bodies validate bounded generic calls" {
    import from jaclang.compiler.driver.program { JacProgram }
    prog = JacProgram();
    prog.compile(
        "lambda_bound.jac",
        use_str="def identity[T: Node](value: T) -> T { return value; } with entry { f = (lambda { return identity(42); })(); }",
        no_cgen=True
    );
    assert any(e.code?.code == "E1053" for e in prog.errors_had);
}

test "root projection does not capture membership" {
    (module, errors) = rd_parse(
        "with entry { n = (graph { a ++> b; }).root; }", "graph_project.jac"
    );
    assert not errors;
    lowered = GraphLoweringPass(ir_in=module);
    assert not lowered.errors_had;
    assert all(not op.capture_edges for op in module.get_all_sub_nodes(uni.ConnectOp));
}

test "client regeneration retains construction imports" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    prog = JacProgram();
    module = prog.compile(
        "graph_client_regeneration.jac",
        use_str="import type from jaclang.runtime.graph_fragment { GraphFragment } node N { has value: int; } def build -> GraphFragment[N] { return graph { N(1) ++> N(2); }; }",
        options=CompileOptions(force_codespace="client", no_cgen=True)
    );
    EsastGenPass(ir_in=module, prog=prog);
    first = module.gen.js;
    assert not prog.errors_had , [str(error) for error in prog.errors_had];
    assert "import { GraphBuilder" in first;
    module.gen.js = "";
    module.gen.es_ast = None;
    EsastGenPass(ir_in=module, prog=prog);
    assert not prog.errors_had , [str(error) for error in prog.errors_had];
    assert module.gen.js == first;
}

test "native construction runtime sharing does not include compiler internals" {
    import from jaclang.compiler.frontend.codeinfo {
        is_shared_runtime_module,
        resolve_native_module
    }
    import from jaclang.project.modresolver { resolve_relative_path }
    import from tempfile { gettempdir }
    (_, runtime) = resolve_native_module(
        "jaclang.runtime.graph_fragment", gettempdir()
    );
    assert runtime is not None;
    assert is_shared_runtime_module(runtime);
    compiler = resolve_relative_path("jaclang.cli.cli", gettempdir() + "/probe.jac");
    assert not is_shared_runtime_module(compiler);
}

test "graph rejects suspension before backend lowering" {
    (module, errors) = rd_parse(
        "async def build { f = graph { await child(); }; }", "graph_async.jac"
    );
    assert not errors;
    lowered = GraphLoweringPass(ir_in=module);
    assert any(e.code?.code == "E0085" for e in lowered.errors_had);
}

test "graph is reserved in declarations" {
    for source in ["def graph {}", "obj X { has graph: int; }"] {
        (_, errors) = rd_parse(source, "graph_reserved.jac");
        assert errors;
    }
}

test "graph expressions work directly in block heads" {
    (module, errors) = rd_parse(
        "with entry { if graph { a; }.root {} while graph { a; }.root { break; } for item in graph { a; }.nodes {} }",
        "graph_block_head.jac"
    );
    assert not errors;
    assert len(module.get_all_sub_nodes(uni.GraphExpr)) == 3;
}

test "graph expressions nested in block heads remain available" {
    (module, errors) = rd_parse(
        "with entry { if check(graph { a ++> b; }) {} if (graph { a; }).root {} }",
        "graph_nested_head.jac"
    );
    assert not errors;
    assert len(module.get_all_sub_nodes(uni.GraphExpr)) == 2;
}

test "nested bytecode compilation does not inherit the caller's analysis request" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import jaclang.compiler.driver.pass_driver as driver;
    # Ensure the codec is available so unnecessary interface work is observable.
    import jaclang.compiler.types.stubcat.modiface;
    with TemporaryDirectory() as directory {
        base_path = Path(directory);
        toolchain = base_path / "toolchain";
        toolchain.mkdir();
        helper = toolchain / "helper.jac";
        helper.write_text("def answer() -> int { return 42; }\n");
        app = base_path / "main.jac";
        app.write_text("def application() -> int { return 1; }\n");
        internal = JacProgram();
        compiler = JacCompiler();
        internal._compiler = compiler;
        program = JacProgram();
        program._compiler = compiler;
        loaded: list[any] = [];
        original: any = driver.run_pass;
        def load_helper(pass_cls: any, ir_in: any, prog: any, **kwargs: any) -> any {
            if pass_cls.__name__ == "SymTabBuildPass"
                and ir_in.loc.mod_path == str(app)
                and not loaded {
                assert compiler._reentrant_depth > 0;
                loaded.append(
                    compiler.get_bytecode(str(helper), target_program=internal)
                );
            }
            return original(pass_cls, ir_in, prog, **kwargs);
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
