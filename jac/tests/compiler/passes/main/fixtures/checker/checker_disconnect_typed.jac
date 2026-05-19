edge MyEdge {
    has id: int;
}

node NodeA {
    has val: int;
}

node NodeB {
    has name: str;
}

with entry {
    a_inst: NodeA = NodeA(0);
    b_inst: NodeB = NodeB("bob");
    a_inst +>: MyEdge :+> b_inst;
    edge_inst: MyEdge = MyEdge(1);

    # Ok cases — typed disconnect using actual edge type / instance.
    a_inst del ->:MyEdge:-> b_inst;  # Ok
    a_inst del ->:edge_inst:-> b_inst;  # Ok
    a_inst del <-:MyEdge:<- b_inst;  # Ok

    # Error: NodeA is a node, not an edge.
    a_inst del ->:NodeA:-> b_inst;  # Error
    # Error: NodeB is a node, not an edge (in-direction form).
    a_inst del <-:NodeB:<- b_inst;  # Error

    # Untyped disconnect — no f_type — should not emit E1098.
    a_inst del --> b_inst;  # Ok
}
