"""Targeted tests for the closed, typed graph-query IR."""
import from jaclang.runtime.graph_query { GraphQuery, QHop, QPred }

node QA {
    has val: int = 0;
}

node QB {
    has tag: str = "";
}

edge QE: any --> any {
    has weight: int = 0;
}

edge QLight: QA --> QA | QB {}

edge QLightSub(QLight): QA --> QA {}


test "lightweight filtered hops match the general traversal" {
    import from jaclang.runtime.runtime { JacRuntime }
    import from jaclang.runtime.graph_walk { origin_anchors, walk_nodes }

    a = QA();
    b = QA(val=1);
    c = QA(val=2);
    d = QB(tag="other");
    a +>:QLight:+> b;
    a +>:QLightSub:+> b;
    a +>:QLightSub:+> c;
    a +>:QLight:+> d;
    c +>:QLight:+> a;
    a +>:QLight:+> a;
    for dir in [1, 2, 3] {
        for cls in [None, QLight, QLightSub] {
            for nd_type in [None, QA, (QA, QB)] {
                for preds in [[], [QPred(field="val", op=">=", value=1)]] {
                    for bounded in [False, True] {
                        q = GraphQuery(
                            a,
                            hops=[QHop(dir=dir, `edge=cls, nd=nd_type, preds=preds)],
                            slc=slice(1, 3) if bounded else None
                        );
                        expected = [
                            n.archetype for n in walk_nodes(origin_anchors(q), q, False)
                        ];
                        assert JacRuntime.refs(q) == expected;
                        if not bounded {
                            for visit_mode in [False, True] {
                                assert JacRuntime.hop(
                                    a,
                                    dir,
                                    cls,
                                    nd=nd_type,
                                    preds=preds,
                                    from_visit=visit_mode
                                )
                                    == expected;
                                assert JacRuntime.hop(
                                    [a],
                                    dir,
                                    cls,
                                    nd=nd_type,
                                    preds=preds,
                                    from_visit=visit_mode
                                )
                                    == expected;
                            }
                        }
                        q.`visit();
                        assert JacRuntime.refs(q) == expected;
                    }
                }
            }
        }
    }
    limited = GraphQuery(
        a,
        hops=[QHop(dir=2, nd=QA, preds=[QPred(field="val", op=">", value=0)])],
        limit=1,
        offset=1
    );
    assert JacRuntime.refs(limited) == [c];
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
    slc = q.slc;
    assert slc is not None;
    assert slc.stop == 25;
    assert q.hops[0].`edge is QE;
    assert q.hops[0].preds[0].matches(2);
    assert "0:25" in q.repr();
}


walker FilteredHopProbe {
    has seen: list[int] = [];

    can traverse with QA entry {
        self.seen.append(here.val);
        visit:0: [here->:QLight:->[?:QA, val>=1]];
    }
}

test "single filtered hops and visits do not allocate a general query" {
    import from unittest.mock { patch }
    a = QA();
    b = QA(val=1);
    c = QA(val=2);
    a +>:QLight:+> b;
    a +>:QLight:+> QB();
    b +>:QLight:+> c;
    with patch.object(
        GraphQuery,
        '__init__',
        side_effect=AssertionError('a simple transient hop needs no general query')
    ) {
        assert [a->:QLight:->[?:QA, val>=1]] == [b];
        assert [c<-:QLight:<-[?:QA, val>=1]] == [b];
        walked = a spawn FilteredHopProbe();
        assert walked.seen == [0, 1, 2];
    }
}


walker EdgeHopProbe {
    has seen: list[str] = [];

    can nodes with QA entry {
        self.seen.append(str(here.val));
        visit:0: [edge here->:QLight:->];
    }

    can edges with QLight entry {
        self.seen.append("edge");
    }
}

test "edge visits include each destination after its edge" {
    import from jaclang.runtime.runtime { JacRuntime }
    a = QA();
    b = QA(val=1);
    c = QA(val=2);
    a +>:QLight:+> b;
    b +>:QLight:+> c;
    for dir in [1, 2, 3] {
        q = GraphQuery(b, hops=[QHop(dir=dir, `edge=QLight)], edges_only=True);
        q.`visit();
        assert JacRuntime.hop(b, dir, QLight, edges_only=True, from_visit=True)
            == JacRuntime.refs(q);
    }
    walked = a spawn EdgeHopProbe();
    assert walked.seen == ["0", "edge", "1", "edge", "2"];
}
