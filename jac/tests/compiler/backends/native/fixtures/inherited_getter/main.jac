"""A getter a class inherits from another unit is reachable through its vtable."""
import from .middle { Middle }

obj Leaf(Middle) {
    has more: int = 10;

    def total -> int {
        return self.doubled + self.extra + self.more;
    }
}

def chk_inherited_getter -> int {
    leaf = Leaf(start=5);
    via_base: Middle = leaf;
    return leaf.total() * 100 + via_base.total();
}

with entry {
    print(chk_inherited_getter());
}
