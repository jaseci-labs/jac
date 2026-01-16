import from jaclang { JacRuntime as Jac }

node A {
    has id: int;
}

node B {
    has id: int;
}

node C {
    has id: int;
}

node D {
    has id: int;
}

node E {
    has id: int;
}

walker populate {
    can setup1 with `root entry {
        for i in range(2) {
            here ++> A(id=i);
        }
        visit [-->];
    }

    can setup2 with A entry {
        for i in range(2) {
            here ++> B(id=i);
        }
        visit [-->];
    }

    can setup3 with B entry {
        for i in range(2) {
            here ++> C(id=i);
        }
        visit [-->];
    }

    can setup4 with C entry {
        for i in range(2) {
            here ++> D(id=i);
        }
        visit [-->];
    }

    can setup5 with D entry {
        for i in range(2) {
            here ++> E(id=i);
        }
        visit [-->];
    }
}

walker traverse {
    can enter1 with `root entry {
        print(here);
        visit [-->];
    }

    can enter2 with A entry {
        print(here);
        visit [-->];
    }

    can enter3 with B entry {
        print(here);
        visit [-->];
    }

    can enter4 with C entry {
        print(here);
        visit [-->];
    }

    can enter5 with D entry {
        print(here);
        visit [-->];
    }

    can enter6 with E entry {
        print(here);
        visit [-->];
    }
}

walker purge {
    can purge with `root entry {
        print(Jac.reset_graph());
    }
}

walker check {
    can enter with `root entry {
        # Count rows in SQLite database
        l3 = Jac.get_context().mem.l3;
        cursor = l3.__conn__.execute("SELECT COUNT(*) FROM anchors");
        print(cursor.fetchone()[0]);
    }
}
