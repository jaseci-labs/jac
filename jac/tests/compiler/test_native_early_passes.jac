"""Early native analysis preserves scopes, diagnostics, and pass scheduling."""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.frontend.parser.frontend { parse, parse_woven }
import from jaclang.compiler.frontend.unitree { Module, UniScopeNode }
import from jaclang.compiler.native_compiler { ensure_loaded }
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.graph_lowering_pass { GraphLoweringPass }

test "native early symbols wait for construction lowering" {
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
        assert id(mod) not in prog.analysis.early_passes;
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
        assert kernel.supports_early;
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

def scope_profile(mod: Module) -> list {
    out: list = [];
    for scope in [mod]
        + [
            n
            for n in mod._in_mod_nodes
            if isinstance(n, UniScopeNode) and n is not mod
        ] {
        names: list = [];
        for (name, symbol) in scope.names_in_scope.items() {
            names.append((name, symbol.imported, [d.sym_name for d in symbol.defn]));
            assert symbol.parent_tab is scope;
            assert symbol.provider is None;
        }
        overloads: list = [];
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
        assert kernel.supports_early , "rebuild the compiler kernel for early analysis";
        native = JacProgram();
        (nat_mod, failed) = parse_woven(
            SOURCE, "early_scopes.jac", native, [], early_context="server"
        );
        assert not failed;
        assert "SymTabBuildPass" in native.analysis.early_passes[id(nat_mod)].results;
        before = scope_profile(nat_mod);
        run_pass(ASTValidationPass, nat_mod, native);
        run_pass(SymTabBuildPass, nat_mod, native);
        assert id(nat_mod) not in native.analysis.early_passes;
        assert native.analysis.pass_runs["SymTabBuildPass"] == 1;
        assert scope_profile(nat_mod) == before;

        store = JacProgram();
        (store_mod, store_failed) = parse(SOURCE, "early_scopes.jac", store);
        assert not store_failed;
        run_pass(ASTValidationPass, store_mod, store);
        run_pass(SymTabBuildPass, store_mod, store);
        assert scope_profile(nat_mod) == scope_profile(store_mod);
        assert not native.errors_had;
        assert not store.errors_had;
    }
}

test "native validation diagnostics retain inline suppression" {
    kernel = ensure_loaded();
    if kernel is not None {
        assert kernel.supports_early;
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
