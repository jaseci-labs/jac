"""Tests that the type checker is using synthesized type variables for self and cls.

From Pyright sample: typeVar2.py
"""

class BaseClass {
    @classmethod
    def c(cls: Any) -> object {
        return cls;
    }

    def f(self: BaseClass) -> object {
        return self;
    }
}

class SubClass(BaseClass) {}

def requires_subclass(p1: SubClass) -> object {
    ;
}

with entry {
    x = SubClass().f();
    requires_subclass(x);  # Ok

    y = SubClass().c();
    requires_subclass(y());  # Ok
}
