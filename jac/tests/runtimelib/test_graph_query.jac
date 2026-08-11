"""Targeted tests for the closed, typed graph-query IR."""
import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }

node QA {
    has val: int = 0;
}

node QB {
    has tag: str = "";
}

edge QE {
    has weight: int = 0;
}


test "qpred validates ops and scalar values" {
    ok = QPred(field="val", op="==", value=2);
    assert ok.field == "val";

    blew = False;
    try {
        QPred(field="val", op="is", value=None);
    } except ValueError {
        blew = True;
    }
    assert blew;

    blew = False;
    try {
        QPred(field="val", op="==", value=[1, 2]);
    } except TypeError {
        blew = True;
    }
    assert blew;

    blew = False;
    try {
        QPred(field="val", op="in", value=7);
    } except TypeError {
        blew = True;
    }
    assert blew;
}


test "qpred matches reference semantics" {
    assert QPred(field="v", op="==", value=2).matches(2);
    assert not QPred(field="v", op="==", value=2).matches(3);
    assert QPred(field="v", op="!=", value=2).matches(3);
    assert QPred(field="v", op="<=", value=8).matches(8);
    assert QPred(field="v", op="<", value=8).matches(7);
    assert QPred(field="v", op=">", value=8).matches(9);
    assert QPred(field="v", op=">=", value=8).matches(8);
    assert QPred(field="v", op="in", value=("a", "b")).matches("a");
    assert not QPred(field="v", op="in", value=("a", "b")).matches("c");

    # None never satisfies ordering ops; ==/!= treat it as a value.
    assert not QPred(field="v", op="<", value=5).matches(None);
    assert QPred(field="v", op="==", value=None).matches(None);
    assert QPred(field="v", op="!=", value=None).matches(0);

    # Cross-type ordering is False, never a crash.
    assert not QPred(field="v", op="<", value=5).matches("x");
}


test "qhop merges node constraints structurally" {
    hop = QHop(dir=2, nd=QA);
    hop.add_node_constraint(None);
    assert hop.nd is QA;
    hop.add_node_constraint(QB);
    assert hop.nd == (QA, QB);
    assert "QA&QB" in hop.repr();
}


test "graphquery carries flags and is callable-free" {
    q = GraphQuery(
        [],
        hops=[
            QHop(
                dir=2,
                `edge=QE,
                nd=QA,
                epreds=[QPred(field="weight", op=">", value=0)],
                preds=[QPred(field="val", op="==", value=2)]
            )
        ],
        slc=slice(0, 25, None)
    );
    assert q.level == 'default';
    assert not q.from_visit;
    q.`visit();
    assert q.from_visit;
    assert q.slc.stop == 25;
    assert q.hops[0].`edge is QE;
    assert q.hops[0].preds[0].matches(2);
    assert "0:25" in q.repr();
}
