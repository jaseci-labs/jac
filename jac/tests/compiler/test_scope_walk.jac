import from jaclang.compiler.frontend.parser.frontend { parse }
import from jaclang.compiler.frontend.unitree { UniScopeNode }
import from jaclang.compiler.frontend.relations { ScopeChild }
import from jaclang.compiler.passes.scope_walk { ScopeWalker }
import from jaclang.compiler.tools.code_intel { SymbolCollector }
import from jaclang.compiler.driver.program { JacProgram }

walker RecordScopes(ScopeWalker) {
    has order: list[UniScopeNode] = [];

    can record with UniScopeNode entry {
        self.order.append(here);
    }
}

test "scope walker preserves depth first order and handles shared cycles" {
    (a, _) = parse("", "a.jac");
    (b, _) = parse("", "b.jac");
    (c, _) = parse("", "c.jac");
    (d, _) = parse("", "d.jac");
    a +>:ScopeChild:+> b;
    a +>:ScopeChild:+> c;
    b +>:ScopeChild:+> d;
    c +>:ScopeChild:+> d;
    d +>:ScopeChild:+> a;
    walk = RecordScopes();
    a spawn walk;
    assert walk.order == [a, b, d, c];
}

test "symbol collector includes nested scope names" {
    prog = JacProgram();
    mod = prog.compile(
        use_str="def f(a: int) -> int { local = a; return local; } with entry { f(1); }",
        file_path="collect_symbols.jac"
    );
    assert not prog.errors_had;
    collector = SymbolCollector();
    mod spawn collector;
    names = {symbol.sym_name for symbol in collector.symbols};
    assert {"f", "a", "local"}.issubset(names);
}
