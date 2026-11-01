"""The scope graph and the per-node sub-node tables, read off analysed trees."""

walker RecordScopes(ScopeWalker) {
    has order: list[UniScopeNode] = [];

    can record with UniScopeNode entry {
        self.order.append(here);
    }
}

def walk_order_is_depth_first {
    a = parse_text("", "a.jac");
    b = parse_text("", "b.jac");
    c = parse_text("", "c.jac");
    d = parse_text("", "d.jac");
    a +>:ScopeChild:+> b;
    a +>:ScopeChild:+> c;
    b +>:ScopeChild:+> d;
    c +>:ScopeChild:+> d;
    d +>:ScopeChild:+> a;
    walk = RecordScopes();
    a spawn walk;
    assert walk.order == [a, b, d, c];
}

def collector_includes_nested_names {
    analysis = analyse(
        "def f(a: int) -> int { local = a; return local; } with entry { f(1); }",
        "collect_symbols.jac"
    );
    assert not analysis.error_codes() , analysis.messages();
    collector = SymbolCollector();
    analysis.module spawn collector;
    names = {symbol.sym_name for symbol in collector.symbols};
    assert {"f", "a", "local"}.issubset(names);
}

def sub_node_tables_match_their_nodes {
    analysis = analyse(
        "obj Circle {\n    has radius: float = 1.0;\n    def area -> float { return 3.14 * self.radius * self.radius; }\n}\nwith entry { print(Circle().area()); }\n",
        "circle.jac"
    );
    assert not analysis.error_codes() , analysis.messages();
    for kid in [[analysis.module->:Kid:->][1]->:Kid:->] {
        for (kind, held) in kid._sub_node_tab.items() {
            for found in held {
                assert found in kid.get_all_sub_nodes(kind);
            }
        }
    }
}

def scope_cases -> list[KernelCase] {
    return [
        KernelCase(
            "scope walker preserves depth first order and handles shared cycles",
            walk_order_is_depth_first
        ),
        KernelCase(
            "symbol collector includes nested scope names",
            collector_includes_nested_names
        ),
        KernelCase(
            "every sub-node table entry is a sub-node of its node",
            sub_node_tables_match_their_nodes
        )
    ];
}
