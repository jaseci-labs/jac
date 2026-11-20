# A bare name in a method body resolves the way Python resolves it at run time:
# local, enclosing function, module, builtins. A class body is not an enclosing
# scope, so a method named like a module function does not shadow it.
def lookup(n: int) -> int {
    return n + 1;
}

obj Toolbox {
    has seed: int = 41;

    obj Part {
        has v: int = 5;
    }

    def lookup -> int {
        return lookup(self.seed);
    }

    def from_impl -> int;

    # Signature positions still see the class's names, as in Python.
    def part_value(p: Part) -> int {
        return p.v;
    }

    def helper -> int {
        return 1;
    }

    # A local assigned in the method body is a local, even when a field
    # shares its name.
    def local_shadows_field -> int {
        seed = 2;
        return seed + 1;
    }

    def from_impl_local -> int;

    # `helper` is a member, not a name in scope: W2001 with a `self.` hint.
    def calls_helper_bare {
        helper();
    }

    static def make -> int {
        return 1;
    }

    # In a static method the hint qualifies through the class, in a class
    # method through `cls`.
    static def static_bare {
        make();
    }

    class def class_bare {
        make();
    }
}

impl Toolbox.from_impl -> int {
    return lookup(self.seed);
}

impl Toolbox.from_impl_local -> int {
    seed = self.seed;
    return seed + 1;
}

# A class type parameter stays visible inside its methods.
obj Box[T] {
    has item: T;

    def get -> T {
        out: T = self.item;
        return out;
    }
}

with entry {
    print(Toolbox().lookup());
}
