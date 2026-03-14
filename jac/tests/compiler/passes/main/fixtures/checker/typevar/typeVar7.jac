"""Tests constrained TypeVars with operations.

Tests TypeVar("T", Foo, Bar) style constraints where T must be exactly one of the
specified types, and validates that operations are checked against all constraint types.

Known behaviors:
1. One error is emitted per constraint type that fails (provides detailed feedback).
2. False positive errors on `_ = a.__class__` and `_ = a.__doc__` because `_` was
   previously assigned an int type, not a TypeVar validation issue.
"""

import from typing { Generic, TypeVar }

class Foo {
    has var1: int;

    def __call__(self: Foo, val: int) {
        ;
    }

    def do_stuff(self: Foo) -> int {
        return 0;
    }

    def __add__(self: Foo, val: Foo) -> Foo {
        return val;
    }
}

class Bar {
    has var1: int;
    has var2: int;

    def __call__(self: Bar, val: int) {
        ;
    }

    def do_stuff(self: Bar) -> float {
        return 0;
    }

    def do_other_stuff(self: Bar) -> float {
        return 0;
    }

    def __add__(self: Bar, val: Bar) -> Bar {
        return val;
    }
}

with entry {
    _T1 = TypeVar("_T1", Foo, Bar);  # Constrained TypeVar
    _T2 = TypeVar("_T2", Foo, Bar, str);  # Constrained TypeVar with str
}

class ClassA(Generic[_T1, _T2]) {
    async def func1(self: ClassA, a: _T1) -> _T1 {
        _ = a.var1;  # Ok: both Foo and Bar have var1
        _ = a.var2;  # Error: Foo doesn't have var2
        _ = a(3.3);  # Error: both expect int
        _ = a[0];  # Error (two errors)
        _ = a + 1;  # Error: __add__ expects same type, not int
        _ = a + a;  # Ok: both support __add__ with same type
        a += a;  # Ok
        _ = -a;  # Error
        a += 3;  # Error
        _ = await a;  # Error
        for _ in a {  # Error (two errors)
            ;
        }
        a.do_stuff();  # Ok
        a.do_other_stuff();  # Error: Foo doesn't have it
        _ = a.__class__;  # Ok
        _ = a.__doc__;  # Ok
        return a;
    }

    async def func2(self: ClassA, a: _T2, b: _T1) -> _T1 {
        _ = a.var2;  # Error (two errors for Foo and str)
        _ = a(3.3);  # Error
        _ = a[0];  # Error (two errors)
        _ = a + 1;  # Error
        _ = a + a;  # Ok
        a += a;  # Ok
        _ = a + b;  # Error: can't mix _T2 and _T1
        _ = -a;  # Error
        a += 3;  # Error
        _ = await a;  # Error
        for _ in a {  # Error
            ;
        }
        a.do_other_stuff();  # Error
        _ = a.__class__;  # Ok
        _ = a.__doc__;  # Ok
        return b;
    }
}

with entry {
    _T3 = TypeVar("_T3", float, int, str);
    _T4 = TypeVar("_T4", float, int);
}

def custom_add(a: _T3, b: _T4) -> float {
    if isinstance(a, str) {
        return 0;
    }
    c = a + b;
    return c;
}

class Thing1 {
    def __add__(self: Thing1, value: float) -> Thing1 {
        return self;
    }
    def __radd__(self: Thing1, value: float) -> Thing1 {
        return self;
    }
}

class Thing2 {
    def __add__(self: Thing2, value: float) -> Thing2 {
        return self;
    }
    def __radd__(self: Thing2, value: float) -> Thing2 {
        return self;
    }
}

with entry {
    TThing = TypeVar("TThing", Thing1, Thing2);
}

def func1(x: TThing) -> TThing {
    if isinstance(x, Thing1) {
        return 2 + x;  # Ok
    } else {
        assert isinstance(x, Thing2);
        return 3 + x;  # Ok
    }
}

def func2(x: TThing) -> TThing {
    if isinstance(x, Thing1) {
        return x + 2;  # Ok
    } else {
        assert isinstance(x, Thing2);
        return x + 3;  # Ok
    }
}
