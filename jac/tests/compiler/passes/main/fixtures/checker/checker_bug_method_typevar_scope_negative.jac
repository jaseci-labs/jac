"""A class type parameter must still be solved from the inherited specialization."""

obj Node {}

obj Alpha(Node) {}

obj Beta(Node) {}

obj Carrier[T: Node, R: Node] {
    static def build(x: T) -> R;
    def move(x: T) -> R;
}

obj Mid(Carrier[Alpha, Beta]) {}

obj Leaf(Mid) {}

def use(lf: Leaf, b: Beta) -> None {
    lf.move(b);
    Leaf.build(b);
}
