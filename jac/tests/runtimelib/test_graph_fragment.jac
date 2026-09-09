"""Construction expressions preserve identity, topology and evaluation order."""

import from jaclang.runtime.graph_fragment { GraphFragment }

node FragmentNode {
    has value: int;
}

edge FragmentEdge {
    has weight: int = 0;
}

node OtherFragmentNode {
    has label: str;
}

def fragment_child -> GraphFragment[FragmentNode] {
    return graph { FragmentNode(2) +>:FragmentEdge(weight=7):+> FragmentNode(3); };
}

test "graph nesting grafts roots and records the actual edges" {
    a = FragmentNode(1);
    child = fragment_child();
    f = graph { a ++> [child, FragmentNode(4)]; };
    assert f.root is a;
    assert len(f.roots) == 1;
    assert len(f.nodes) == 4;
    assert len(f.edges) == 3;
    assert f.nodes[1] is child.root;
    assert f.edges[0] is child.edges[0];
    assert [a-->][0] is child.root;
    assert [child.root->:FragmentEdge:->][0] is child.tips[0];
    assert f.tips[0] is child.tips[0];
    del child.edges[0];
    assert len([child.root->:FragmentEdge:->]) == 0;
    assert len(f.edges) == 3;
}

test "graph fanout continuation connects every tip" {
    a = FragmentNode(1);
    b = FragmentNode(2);
    c = FragmentNode(3);
    d = FragmentNode(4);
    f = graph { a ++> [b, c] ++> d; };
    assert f.root is a;
    assert f.tips == [d];
    assert len(f.edges) == 4;
    assert [a-->] == [b, c];
    assert [b-->] == [d];
    assert [c-->] == [d];
}

test "graph repeated references share identity without cloning" {
    shared = FragmentNode(2);
    f = graph { FragmentNode(1) ++> [shared, shared]; };
    assert len(f.nodes) == 2;
    assert len(f.edges) == 1;
    assert f.tips[0] is shared;
}

test "graph supports forests and empty construction" {
    empty = graph { };
    assert empty.roots == [];
    assert empty.tips == [];
    assert empty.nodes == [];
    assert empty.edges == [];
    with testraises(ValueError) {
        empty.root;
    }
    a = FragmentNode(1);
    b = FragmentNode(2);
    forest = graph { a; b; };
    assert forest.roots == [a, b];
    assert forest.tips == [a, b];
    with testraises(ValueError) {
        forest.root;
    }
}

test "graph supports heterogeneous roots and interiors" {
    a = FragmentNode(1);
    b = OtherFragmentNode("other");
    f = graph { a ++> b; };
    assert f.root.value == 1;
    assert len(f.nodes) == 2;
    forest = graph { a; b; };
    assert len(forest.roots) == 2;
    assert forest.roots[0] is a;
    assert forest.roots[1] is b;
}

test "ordinary connect retains its existing result contract" {
    a = FragmentNode(1);
    b = FragmentNode(2);
    c = FragmentNode(3);
    assert (a ++> b) is b;
    targets = [c];
    assert (a ++> targets) is targets;
    assert (a <++ c) is a;
}

test "graph evaluates constructors once in source order" {
    calls: list[int] = [];
    def make(value: int) -> FragmentNode {
        calls.append(value);
        return FragmentNode(value);
    }
    f = graph { make(1) ++> [make(2) ++> make(3), make(4)]; };
    assert calls == [1, 2, 3, 4];
    assert f.root.value == 1;
    assert len(f.nodes) == 4;
}

test "graph evaluates an edge constructor per endpoint pair" {
    calls: list[int] = [];
    def weight -> int {
        calls.append(len(calls) + 1);
        return calls[-1];
    }
    a = FragmentNode(1);
    b = FragmentNode(2);
    c = FragmentNode(3);
    d = FragmentNode(4);
    f = graph { [a, b] +>:FragmentEdge(weight=weight()):+> [c, d]; };
    assert calls == [1, 2, 3, 4];
    assert len(f.edges) == 4;
    assert len({id(item) for item in f.edges}) == 4;
    assert [a-->] == [c, d];
    assert [b-->] == [c, d];
}

test "graph failures preserve earlier connection effects" {
    a = FragmentNode(1);
    b = FragmentNode(2);
    def fail -> FragmentNode {
        raise ValueError("construction failed");
    }
    with testraises(ValueError) {
        graph { a ++> b; fail(); };
    }
    assert [a-->] == [b];
}

test "graph accepts computed fanouts" {
    children = [FragmentNode(2), FragmentNode(3)];
    f = graph { FragmentNode(1) ++> children; };
    assert len(f.nodes) == 3;
    assert len(f.edges) == 2;
    g = graph {
        FragmentNode(0) ++> [FragmentNode(i) ++> FragmentNode(i + 10) for i in [1, 2]];
    };
    assert len(g.nodes) == 5;
    assert len(g.edges) == 4;
}

test "root projection preserves construction effects" {
    a = FragmentNode(1);
    b = FragmentNode(2);
    n = (graph { a ++> b; }).root;
    assert n is a;
    assert [a-->] == [b];
}

test "graph conditionals build only the selected branch and preserve its root" {
    calls: list[int] = [];
    def make(value: int) -> FragmentNode {
        calls.append(value);
        return FragmentNode(value);
    }
    for selected in [True, False] {
        calls.clear();
        f = graph {
            make(0) ++> (make(1) ++> make(2) if selected else make(3) ++> make(4));
        };
        assert calls == ([0, 1, 2] if selected else [0, 3, 4]);
        assert [f.root-->][0].value == (1 if selected else 3);
        tip = f.tips[0];
        assert isinstance(tip, FragmentNode);
        assert tip.value == (2 if selected else 4);
        assert len(f.edges) == 2;
    }
}
