edge MyEdge {
  has id: int;
}

node NodeA {
  has val: int;
}

node NodeB {
  has name: str;
}

obj Book {
    has title: str;
    has author: str;
    has year: int;
}

with entry {

    a_inst: NodeA = NodeA(0);
    b_inst: NodeB = NodeB("bob");
    a_inst +>:MyEdge:+> b_inst;
    edge_inst: MyEdge = MyEdge(1);

    a_inst +>:edge_inst:+> b_inst; # Ok
    a_inst +>:NodeA:+> b_inst;     # Error
    NodeA +>:MyEdge:+> b_inst;     # Error
    a_inst +>:MyEdge:+> NodeB;     # Error

    # Assign compr in edges
    a_inst +>:MyEdge:id=1, not_mem="some":+> b_inst; # Error

    # Assign compr
    lst: list[Book] = [];
    lst(=title="Parry Potter", author="K.J. Bowling", year=1997); # Ok
    lst(=not_exist="some");  # Error
    lst(=year="Type Error"); # Error

    [->:MyEdge:id == 1:->]; # Ok
    [->:MyEdge:not_exists >= 1:->]; # Error

}