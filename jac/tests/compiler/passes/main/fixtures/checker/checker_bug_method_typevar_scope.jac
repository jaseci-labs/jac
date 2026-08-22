"""A method's own TypeVar must not be bound by an inherited class solution."""

obj Node {}

obj Alpha(Node) {}

obj Beta(Node) {}

obj Carrier[T: Node, R: Node] {
    def move(x: T) -> R;
}

glob T = TypeVar('T', bound=Node);

obj Mid(Carrier[Alpha, Beta]) {}

obj Leaf(Mid) {
    static def pick(nd: Node, typ: type[T]) -> list[T] {
        return [];
    }

    def take(nd: Node, typ: type[T]) -> list[T] {
        return [];
    }

    def scoped[T2](typ: type[T2]) -> list[T2] {
        return [];
    }
}

def use(nd: Node, lf: Leaf) -> None {
    for a in Leaf.pick(nd, Alpha) {
        print(a);
    }
    for b in Leaf.pick(nd, Beta) {
        print(b);
    }
    for c in lf.take(nd, Beta) {
        print(c);
    }
    for d in lf.scoped(Alpha) {
        print(d);
    }
}
