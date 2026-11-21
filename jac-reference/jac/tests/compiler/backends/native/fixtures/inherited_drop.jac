"""Inherited destruction follows method resolution even before wrappers exist."""
glob base_drops: int = 0,
     override_drops: int = 0;
obj Base {
    has amount: int;

    def drop {
        base_drops += self.amount;
    }
}

obj Child(Base) {}
obj Grandchild(Child) {}
obj Override(Base) {
    def drop {
        override_drops += self.amount;
    }
}

obj OverrideChild(Override) {}
def probe -> int {
    first = Child(2);
    second = Grandchild(3);
    third = OverrideChild(7);
    return first.amount + second.amount + third.amount;
}

def base_count -> int {
    return base_drops;
}
def override_count -> int {
    return override_drops;
}

with entry {
    print(probe());
    print(base_count());
    print(override_count());
}
