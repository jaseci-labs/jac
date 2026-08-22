"""Fixture: class-level attributes read through `self`.

`Kind` is the shape `types.jac::TypeBase.CATEGORY` carries: a class-level
constant declared on an abstract base and redefined by every subclass, read
back through an instance in a method the base declares. `Fixed` is the
uniform case, where nothing below the declaring class redefines it, and
`Tally` reads a `static has` the same way.
"""

enum Kind { UNKNOWN = 0, LEAF = 1, BRANCH = 2 }


obj Node {
    with entry {
        CATEGORY: ClassVar[Kind] = Kind.UNKNOWN;
        LABEL: ClassVar[str] = "node";
    }

    has n: int = 0;

    def category -> int {
        return int(self.CATEGORY);
    }

    def label -> str {
        return self.LABEL;
    }
}


obj Leaf(Node) {
    with entry {
        CATEGORY: ClassVar[Kind] = Kind.LEAF;
        LABEL: ClassVar[str] = "leaf";
    }
}


obj Branch(Node) {
    with entry {
        CATEGORY: ClassVar[Kind] = Kind.BRANCH;
        LABEL: ClassVar[str] = "branch";
    }
}


obj Fixed {
    with entry {
        WIDTH = 12;
    }

    has n: int = 0;

    def width -> int {
        return self.WIDTH;
    }
}


obj Tally {
    static has STEP: int = 5;
    has n: int = 0;

    def step -> int {
        return self.STEP;
    }
}


obj Metered {
    with entry {
        RATE: ClassVar[float] = 0;
    }

    has n: int = 0;

    def rate -> float {
        return self.RATE;
    }
}


obj Fast(Metered) {
    with entry {
        RATE: ClassVar[float] = 1.5;
    }
}


obj Shape {
    with entry {
        SIDES: ClassVar[int];
    }

    has n: int = 0;

    def sides -> int {
        return self.SIDES;
    }
}


obj Tri(Shape) {
    with entry {
        SIDES: ClassVar[int] = 3;
    }
}


obj Quad(Shape) {
    with entry {
        SIDES: ClassVar[int] = 4;
    }
}


def category_of(item: Node) -> int {
    return item.category();
}


def sides_of(item: Shape) -> int {
    return item.sides();
}


def rate_of(item: Metered) -> float {
    return item.rate();
}


def run -> int {
    print(category_of(Node(n=0)));
    print(category_of(Leaf(n=1)));
    print(category_of(Branch(n=2)));
    print(Node(n=0).label());
    print(Leaf(n=1).label());
    print(Branch(n=2).label());
    print(Fixed(n=0).width());
    print(Tally(n=0).step());
    print(sides_of(Tri(n=0)));
    print(sides_of(Quad(n=0)));
    print(rate_of(Metered(n=0)));
    print(rate_of(Fast(n=0)));
    print(Node.CATEGORY == Kind.UNKNOWN);
    return 0;
}


with entry {
    run();
}
