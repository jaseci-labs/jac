# A destroyed graph object is dead, not gone, per issue #8774. The Python
# object survives; its anchor has no edges, is not in the store, and does not
# come back: connecting, spawning on, or visiting it is refused, and a walker
# whose queue already holds it skips it.
#
# Everything hangs off a fresh `base` node rather than root, because root is
# persistent and a rerun would otherwise see the survivors of the last run.
node Item {
    has n: int;
}

walker Sweep {
    has seen: list[int] = [];

    can look with Item entry {
        if here.n == 0 {
            visit [-->];
            return;
        }
        self.seen.append(here.n);
        if here.n == 1 {
            # destroy a sibling that is already queued behind us
            parent = [<--][0];
            for other in [parent-->] {
                if other.n == 2 {
                    del other;
                }
            }
        }
    }
}

walker Purge {
    can purge with Item entry {
        if here.n == 0 {
            visit [-->];
        } elif here.n == 3 {
            del here;
        }
    }
}

def main {
    base = Item(0);
    root ++> base;
    a = Item(1);
    b = Item(2);
    c = Item(3);
    base ++> a;
    base ++> b;
    base ++> c;
    # a queued dead node is skipped
    w = base spawn Sweep();
    assert w.seen == [1, 3] , f"queued dead node was visited: {w.seen}";
    assert len([base-->]) == 2 , "sibling not destroyed";
    # fields still read, the anchor is dead
    assert b.n == 2 , "fields of a dead object must still read";
    assert len([b-->]) == 0 , "dead anchor has edges";
    assert len([b<--]) == 0 , "dead anchor has incoming edges";
    # reconnecting a dead node raises
    raised = False;
    try {
        base ++> b;
    } except RuntimeError {
        raised = True;
    }
    assert raised , "reconnecting a destroyed node did not raise";
    assert len([base-->]) == 2 , "reconnect changed the graph";
    # spawning on a dead node raises
    raised = False;
    try {
        b spawn Sweep();
    } except RuntimeError {
        raised = True;
    }
    assert raised , "spawning on a destroyed node did not raise";
    # del here mid-walk is legal and the walk completes
    base spawn Purge();
    assert len([base-->]) == 1 , "del here did not destroy";
    assert [base-->][0].n == 1 , "wrong survivor";
    # destroying twice is a no-op
    del c;
    assert len([base-->]) == 1 , "double destroy changed the graph";
    # tidy up so a rerun starts from the same shape
    del base;
    print("del dead anchor: all cases ok");
}

with entry {
    main();
}
