"""Early native analysis preserves scopes, diagnostics, and pass scheduling."""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.frontend.parser.frontend { parse, parse_woven }
import from jaclang.compiler.frontend.unitree {
    ConditionalNode,
    Module,
    NameAtom,
    UniCFGNode,
    UniNode,
    UniScopeNode
}
import from jaclang.compiler.frontend.relations { CfgFalse, CfgSucc, CfgTrue }
import from jaclang.compiler.frontend.roles { ImplOf }
import from jaclang.compiler.native_compiler { ensure_loaded }
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.graph_lowering_pass { GraphLoweringPass }
import from jaclang.compiler.passes.early_passes { EARLY_PASSES }

test "native early analysis lowers graph construction before binding" {
    kernel = ensure_loaded();
    if kernel is not None {
        prog = JacProgram();
        (mod, failed) = parse_woven(
            "node N {} def build { return graph { N() ++> N(); }; }",
            "early_construction.jac",
            prog,
            [],
            early_context="client"
        );
        assert not failed;
        assert id(mod) in prog.analysis.early_passes;
        run_pass(GraphLoweringPass, mod, prog);
        run_pass(ASTValidationPass, mod, prog);
        run_pass(SymTabBuildPass, mod, prog);
        assert not prog.errors_had;
        imports = [
            name
            for scope in mod.flatten()
            if isinstance(scope, UniScopeNode)
            for (name, symbol) in scope.names_in_scope.items()
            if symbol.imported
        ];
        assert any(name.startswith("__jac_graph_builder_type_") for name in imports);
    }
}

test "native validation preserves client code context" {
    kernel = ensure_loaded();
    if kernel is not None {
        for (context, expected) in [("client", 0), ("server", 1)] {
            prog = JacProgram();
            (mod, failed) = parse_woven(
                "def f(`from: str) -> str { return `from; }",
                "early_context.jac",
                prog,
                [],
                early_context=context
            );
            assert not failed;
            run_pass(ASTValidationPass, mod, prog);
            errors = [
                e
                for e in prog.errors_had
                if e.code and e.code.code == "E0067"
            ];
            assert len(errors) == expected;
        }
    }
}

glob SOURCE: str = """
obj Item {
    has value: int = 0;
    def add(amount: int) -> int {
        result = self.value + amount;
        self.value = result;
        return result;
    }
}
def total(items: list[int]) -> int {
    result = 0;
    for item in items {
        result += item;
    }
    if result > 0 {
        copies = [item for item in items];
        result += len(copies);
    }
    return result;
}
@overload def choose(value: int) -> int;
@overload def choose(value: str) -> str;
""";

def scope_profile(mod: Module) -> list[any] {
    out: list[any] = [];
    for scope in [mod]
        + [
            n
            for n in mod._in_mod_nodes
            if isinstance(n, UniScopeNode) and n is not mod
        ] {
        names: list[any] = [];
        for (name, symbol) in scope.names_in_scope.items() {
            names.append((name, symbol.imported, [d.sym_name for d in symbol.defn]));
            assert symbol.parent_tab is scope;
            assert symbol.provider is None;
        }
        overloads: list[any] = [];
        for (name, symbols) in scope.names_in_scope_overload.items() {
            overloads.append((name, [[d.sym_name for d in s.defn] for s in symbols]));
            for symbol in symbols {
                assert symbol.parent_tab is scope;
            }
        }
        out.append(
            (
                type(scope).__name__,
                scope.scope_name,
                scope.parent_scope.scope_name if scope.parent_scope else None,
                [kid.scope_name for kid in scope.kid_scope],
                sorted(names),
                sorted(overloads)
            )
        );
    }
    return out;
}

test "native early passes preserve the store parser's symbol graph" {
    kernel = ensure_loaded();
    if kernel is not None {
        native = JacProgram();
        (nat_mod, failed) = parse_woven(
            SOURCE, "early_scopes.jac", native, [], early_context="server"
        );
        assert not failed;
        pending = native.analysis.early_passes[id(nat_mod)].results;
        assert sorted(pending) == sorted(p.__name__ for p in EARLY_PASSES);
        before = scope_profile(nat_mod);
        for early in EARLY_PASSES {
            run_pass(early, nat_mod, native);
        }
        assert id(nat_mod) not in native.analysis.early_passes;
        assert all(native.analysis.pass_runs[p.__name__] == 1 for p in EARLY_PASSES);
        assert scope_profile(nat_mod) == before;

        store = JacProgram();
        (store_mod, store_failed) = parse(SOURCE, "early_scopes.jac", store);
        assert not store_failed;
        for early in EARLY_PASSES {
            run_pass(early, store_mod, store);
        }
        assert scope_profile(nat_mod) == scope_profile(store_mod);
        assert not native.errors_had;
        assert not store.errors_had;
    }
}

test "native validation diagnostics retain inline suppression" {
    kernel = ensure_loaded();
    if kernel is not None {
        for (suffix, expected) in [("", 1), (" # jac:ignore[E0052]", 0)] {
            prog = JacProgram();
            source = "def missing(value) -> int { return 1; }" + suffix;
            (mod, failed) = parse_woven(
                source, "early_diagnostic.jac", prog, [], early_context="server"
            );
            assert not failed;
            run_pass(ASTValidationPass, mod, prog);
            errors = [
                e
                for e in prog.errors_had
                if e.code and e.code.code == "E0052"
            ];
            assert len(errors) == expected;
            if errors {
                assert errors[0].from_pass is ASTValidationPass;
                assert errors[0].loc.mod_path == "early_diagnostic.jac";
                assert errors[0].loc.first_line == 1;
            }
        }
    }
}

test "application modules run their early passes in the kernel" {
    import from tempfile { TemporaryDirectory }
    import from pathlib { Path }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    kernel = ensure_loaded();
    if kernel is not None {
        with TemporaryDirectory() as td {
            path = Path(td) / "app.jac";
            path.write_text("def double(x: int) -> int { return x * 2; }\n");
            prog = JacProgram();
            recorded: list[str] = [];
            record = prog.analysis.record_early;
            def spy(module: Module, results: dict[str, any]) {
                recorded.extend(results.keys());
                record(module, results);
            }
            prog.analysis.record_early = spy;
            prog.compile(str(path), options=CompileOptions(no_cgen=True));
            assert not prog.errors_had;
            assert sorted(recorded) == sorted(p.__name__ for p in EARLY_PASSES);
            assert not prog.analysis.early_passes;
        }
    }
}

glob FLOW_SOURCE: str = """
obj Point {
    has x: int = 0,
        tags: set[str] = set();

    def shift(step: int) -> int;
}

impl Point.shift(step: int) -> int {
    moved = self.x + step;
    self.x = moved;
    return moved;
}

sem Point.x = "horizontal position";

sem Point.x = "Horizontal position.";

def lookup(d: dict[str, set[str]], k: str) -> set[str] {
    cur = d.get(k);
    if cur is None {
        return set();
    }
    if len(cur) > 1 and k in cur {
        cur = {k};
    }
    return cur;
}

def walk(items: list[int]) -> int {
    total = 0;
    for item in items {
        if item > 3 {
            total += item;
        } elif item < 0 {
            continue;
        } else {
            total -= 1;
        }
    }
    while total > 100 {
        total = total // 2;
    }
    try {
        total = 10 // total;
    } except ZeroDivisionError as err {
        total = 0;
    }
    total = total + 1 if total > 0 else total - 1;
    match total {
        case 0:
            total = 1;
        case _:
            total = 2;
    }
    return total;
}
""";

def _node_key(nd: UniNode) -> tuple[str, int, int, int, int] {
    return (
        type(nd).__name__,
        nd.loc.first_line,
        nd.loc.col_start,
        nd.loc.last_line,
        nd.loc.col_end
    );
}

def _keys(nodes: list[UniNode]) -> list[tuple[str, int, int, int, int]] {
    return [_node_key(n) for n in nodes];
}

def flow_profile(mod: Module) -> list[any] {
    out: list[any] = [];
    for nd in mod.flatten() {
        if isinstance(nd, UniCFGNode) {
            short_circuit: list[any] = [];
            if isinstance(nd, ConditionalNode) {
                short_circuit = [_keys([nd->:CfgTrue:->]), _keys([nd->:CfgFalse:->])];
            }
            out.append(
                (
                    "cfg",
                    _node_key(nd),
                    sorted(nd.affected_symbols),
                    _keys([nd->:CfgSucc:->]),
                    short_circuit,
                    _keys(nd.bb_in),
                    _keys(nd.bb_out)
                )
            );
        }
        impls = [nd->:ImplOf:->];
        if impls {
            out.append(("impl", _node_key(nd), _keys(impls)));
        }
        if isinstance(nd, NameAtom) {
            sym = nd.sym;
            out.append(
                (
                    "name",
                    _node_key(nd),
                    nd.expr_ctx.name,
                    sym.sym_name if sym else None,
                    sym.sym_type.name if sym else None,
                    len(sym.uses) if sym else 0,
                    sym.semstr if sym else None
                )
            );
        }
    }
    return out;
}

test "kernel early passes match the store parser's flow, impl, and semantic facts" {
    kernel = ensure_loaded();
    if kernel is not None {
        native = JacProgram();
        (nat_mod, failed) = parse_woven(
            FLOW_SOURCE, "early_flow.jac", native, [], early_context="server"
        );
        assert not failed;
        assert kernel.skipped() == 0;
        for early in EARLY_PASSES {
            run_pass(early, nat_mod, native);
        }
        store = JacProgram();
        (store_mod, store_failed) = parse(FLOW_SOURCE, "early_flow.jac", store);
        assert not store_failed;
        for early in EARLY_PASSES {
            run_pass(early, store_mod, store);
        }
        nat_profile = flow_profile(nat_mod);
        store_profile = flow_profile(store_mod);
        assert any(row[0] == "cfg" and row[2] for row in store_profile);
        assert any(
            row[0] == "cfg" and row[4] and row[4][0] and row[4][1]
            for row in store_profile
        );
        assert any(row[0] == "impl" for row in store_profile);
        assert any(row[0] == "name" and row[2] == "STORE" for row in store_profile);
        assert any(
            row[0] == "name" and row[6] == "horizontal position"
            for row in store_profile
        );
        assert nat_profile == store_profile;
        for nd in nat_mod.flatten() {
            if isinstance(nd, UniCFGNode) {
                assert isinstance(nd.affected_symbols, set);
            }
        }
        assert not native.errors_had;
        assert not store.errors_had;
    }
}
