"""Python-backend portable drop timing (#7491 R4).

The native backend runs a region's dtor-log at the handle's static drop
point. On the Python backend memory stays GC-managed, but drop-hooked
objects constructed under an open register with the handle and their hooks
run LIFO when the handle dies: at the closing brace for an anonymous open
(the lowering nulls the hidden temp in a finally), and at the last
reference's death for a named handle.
"""

glob log: list[int] = [];

obj Res {
    has id: int = 0;

    def drop {
        log.append(self.id);
    }
}

test "python backend: anonymous open runs drop hooks LIFO at the brace" {
    log.clear();
    in Region() {
        a = Res(id=1);
        b = Res(id=2);
    }
    assert log == [2, 1];
}

test "python backend: named handle runs hooks when the handle dies" {
    log.clear();
    # (Region | None): nulling the name is the idiomatic way to kill the last
    # reference on the Python backend, so the annotation must admit None.
    r: (Region | None) = Region();
    in r {
        c = Res(id=3);
    }
    assert log == [];
    r = None;
    assert log == [3];
}

test "python backend: objects made outside any open never register" {
    log.clear();
    d = Res(id=9);
    in Region() {
        e = Res(id=4);
    }
    assert log == [4];
}

node Item {
    has v: int = 0;

    def drop {
        log.append(self.v);
    }
}

walker Sum {
    can add with Item entry {
        visit [-->];
    }
}

test "python backend: an inferred anonymous open runs drop hooks LIFO too" {
    log.clear();
    a = Item(v=1);
    b = Item(v=2);
    c = Item(v=3);
    a ++> b;
    b ++> c;
    Sum() spawn a;
    assert log == [3, 2, 1] , f"log={log}";
}
