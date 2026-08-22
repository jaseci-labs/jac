"""Inheritance + virtual dispatch fixture for the jac2c runtime-ABI backend.

`Dog` inherits `Animal`'s field, constructor, and `who` method, and overrides
`speak`. `who` is defined on the base but calls `self.speak()`, which must
dispatch through the vtable to the most-derived override at run time.
"""

obj Animal {
    has name: int;

    def init(nm: int) {
        self.name = nm;
    }

    def speak -> int {
        return 1;
    }

    def who -> int {
        return (self.speak() + self.name);
    }
}

obj Dog(Animal) {
    def speak -> int {
        return 2;
    }
}

def run_base -> int {
    a = Animal(10);
    return a.who();
}

def run_derived -> int {
    d = Dog(100);
    return d.who();
}
