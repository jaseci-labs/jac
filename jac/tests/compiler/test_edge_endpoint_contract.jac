"""Endpoint contracts use the same types for connection checking and traversal."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Name, Module }

def check_endpoint(source: str) -> tuple[JacProgram, Module] {
    program = JacProgram();
    mod = program.compile(
        file_path="edge_contract.jac",
        use_str="node Base {}\nnode A(Base) {}\nnode B {}\nnode C {}\n"
        "edge Link: A --> B {}\nedge Free: any --> any {}\n"
            + source,
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    return (program, mod);
}

test "every tuple target is checked against the endpoint" {
    (program, mod) = check_endpoint(
        "def probe(a: A, b: B, c: C) { a +>:Link:+> (b, c); }"
    );
    assert [
        e.code.code
        for e in program.errors_had
        if e.code
    ]
        == ["E1136"];
}

test "collection unions preserve their element types" {
    (program, mod) = check_endpoint(
        "def probe(a: list[A] | A, b: B) { a +>:Link:+> b; }"
    );
    assert not program.errors_had , str(program.errors_had);
    assert not [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W2081"
    ];
}

test "partial overlap with a declared union is unproven rather than impossible" {
    (program, mod) = check_endpoint(
        "edge Mixed: A | C --> B {}\n" "def probe(a: Base, b: B) { a +>:Mixed:+> b; }"
    );
    assert not program.errors_had , str(program.errors_had);
    assert len(
        [
            w
            for w in program.warnings_had
            if w.code and w.code.code == "W2081"
        ]
    )
        == 1;
}

test "bidirectional connections satisfy the declaration in both directions" {
    (program, mod) = check_endpoint("def probe(a: A, b: B) { a <+:Link:+> b; }");
    assert [
        e.code.code
        for e in program.errors_had
        if e.code
    ]
        == ["E1136", "E1136"];
    (program, mod) = check_endpoint(
        "edge Peer: A --> A {}\n" "def probe(a: A, other: A) { a <+:Peer:+> other; }"
    );
    assert not program.errors_had , str(program.errors_had);
}

test "reverse connections and inherited declarations keep their orientation" {
    (program, mod) = check_endpoint(
        "edge Child(Link) {}\n" "def probe(a: A, b: B) { b <+:Child:<+ a; }"
    );
    assert not program.errors_had , str(program.errors_had);
}

test "an unconstrained hop discards the previous hop's narrowed result" {
    (program, mod) = check_endpoint(
        "def probe(a: A) { result = [a ->:Link:-> ->:Free:->]; }"
    );
    assert not program.errors_had , str(program.errors_had);
    results = [
        str(n.type)
        for n in mod.get_all_sub_nodes(Name)
        if n.value == "result"
    ];
    assert results == ["list[<any>]"] , str(results);
}
