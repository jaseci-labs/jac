"""A method defined on a generic base, called through a subclass."""
obj Registry[T] {
    def names -> list[str] abst;
    def first -> str {
        return self.names()[0];
    }

    def count -> int {
        return len(self.names());
    }
}

obj IntRegistry(Registry[int]) {
    def names -> list[str] {
        return ["alpha", "beta"];
    }
}

obj Leaf(IntRegistry) {}

def through_base(r: Registry[int]) -> int {
    return r.count();
}

def through_leaf -> str {
    leaf = Leaf();
    return leaf.first() + "/" + str(leaf.count());
}

with entry {
    print(through_base(Leaf()));
    print(through_leaf());
}
