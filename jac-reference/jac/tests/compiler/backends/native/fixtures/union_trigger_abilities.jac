node A {
    has v: int = 1;
}

node B {
    has v: int = 2;
}

node C {}

walker Both {
    has log: list[str] = [];

    can on_ab with A | B entry {
        self.log.append("ab");
    }

    can on_a with A entry {
        self.log.append("a");
    }

    can on_rootish with Root | C entry {
        self.log.append("root-or-c");
    }
}

with entry {
    a = A();
    b = B();
    c = C();
    wa = a spawn Both();
    wb = b spawn Both();
    wc = c spawn Both();
    print(wa.log, wb.log, wc.log);
}

node Base {}

node Derived(Base) {}

walker Family {
    has log: list[str] = [];

    can either with Base | Derived entry {
        self.log.append("either");
    }

    can leaving with Derived | Base exit {
        self.log.append("leaving");
    }
}

with entry {
    fd = Derived() spawn Family();
    fb = Base() spawn Family();
    print(fd.log, fb.log);
}
