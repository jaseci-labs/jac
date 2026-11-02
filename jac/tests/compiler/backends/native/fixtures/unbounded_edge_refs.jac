"""Graph refs reached through an unbounded class value keep node identity."""

node Box {
    has n: int = 0;

    def link(t: Box, role: type[Role]) {
        self +>:role:+> t;
    }

    def replace(old: Box, new: Box) {
        roles: list[type] = [];
        for e in [edge self->:Role:->] {
            if type(e) not in roles {
                roles.append(type(e));
            }
        }
        for role in roles {
            targets = [self->:role:->];
            if not any(t is old for t in targets) {
                continue;
            }
            del [edge self->:role:->];
            for t in targets {
                self.link(new if t is old else t, role);
            }
        }
    }
}

edge Role: Box --> Box {}

edge ExprRole(Role): Box --> Box {}

edge BodyRole(Role): Box --> Box {}

def probe(a: Box, x: Box, y: Box) {
    roles: list[type] = [];
    for e in [edge a->:Role:->] {
        if type(e) not in roles {
            roles.append(type(e));
        }
    }
    for role in roles {
        targets = [a->:role:->];
        print(
            "unbounded",
            [t is x for t in targets],
            [t is not y for t in targets],
            [t == x for t in targets],
            x in targets,
            y in targets,
            len(targets)
        );
        print("edges", len([edge a->:role:->]));
    }
    plain = [a-->];
    print("plain", [t is x for t in plain], [t == x for t in plain], x in plain);
    bound: type[Edge] = ExprRole;
    print("edge-bound", [t is x for t in [a->:bound:->]], y in [a->:bound:->]);
}

def truthy(items: list[int]) {
    print(any(i > 2 for i in items), all(i > 0 for i in items));
    print(any([]), all([]), any(items), all([0, 1]));
    found = any(i == 3 for i in items);
    print(f"{found} {all(i < 3 for i in items)!r}", str(any(items)), repr(all(items)));
    if found and not all(i > 5 for i in items) {
        print("branch", found == True);
    }
}

with entry {
    a = Box(n=0);
    x = Box(n=1);
    y = Box(n=2);
    z = Box(n=3);
    a +>:ExprRole:+> x;
    a +>:BodyRole:+> y;
    probe(a, x, y);
    a.replace(x, z);
    print(
        sorted([type(e).__name__ for e in [edge a->:Role:->]]),
        [t.n for t in [a->:ExprRole:->]],
        [t.n for t in [a->:BodyRole:->]]
    );
    truthy([1, 2, 3]);
}
