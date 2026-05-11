edge MyEdge {
    has weight: int,
        label: str;
}

node NodeA {
    has val: int;
}

with entry {
    a_inst: NodeA = NodeA(0);
    b_inst: NodeA = NodeA(1);
    a_inst +>: MyEdge : weight=1, label="x" :+> b_inst;

    # Ok cases — comparing a field to a value of a compatible type.
    [a_inst ->:MyEdge:weight==1:-> ];                # Ok
    [a_inst ->:MyEdge:label=="x":-> ];               # Ok
    [a_inst ->:MyEdge:weight<=10:-> ];               # Ok
    a_inst del ->:MyEdge:weight==1:-> b_inst;        # Ok

    # `==` / `!=` are not flagged for cross-type operands — matches the
    # statement-level CompareExpr behavior (Python does not raise on
    # `1 == "x"`; it just returns False).
    [a_inst ->:MyEdge:weight=="x":-> ];              # Ok (no TypeError)

    # Error cases — ordered comparisons require operand types to support
    # the magic method against the other side; Python raises TypeError
    # for `int >= str` etc. These should be flagged with E1110.
    [a_inst ->:MyEdge:weight>="x":-> ];              # Error: int >= str
    [a_inst ->:MyEdge:label<1:-> ];                  # Error: str <  int
    [a_inst ->:MyEdge:weight>"x":-> ];               # Error: int >  str
    a_inst del ->:MyEdge:weight<="x":-> b_inst;      # Error inside del
}
