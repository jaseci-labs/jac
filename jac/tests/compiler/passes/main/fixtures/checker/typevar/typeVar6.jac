"""Tests that bounded TypeVars properly generate errors respecting bound type.

From Pyright sample: typeVar6.py

TODO: Known differences from Pyright:
1. UnionType bounds (bound=Union[Foo, Bar]) are not yet supported - _T2 is treated
   as unbounded, causing incorrect "Type _T2 is not callable/subscriptable/etc" errors
   instead of checking against the Union members. This affects func2 (lines 63-81).
2. False positive errors on `_ = a.__class__` and `_ = a.__doc__` because `_` was
   previously assigned an int type, not a TypeVar validation issue.
"""

import from typing { Generic, TypeVar, Union }

class Foo {
    has var1: int;

    def __call__(self: Foo, val: int) {}

    def do_stuff(self: Foo) -> int {
        return 0;
    }
}

class Bar {
    has var1: int;
    has var2: int;

    def __call__(self: Bar, val: int) {}

    def do_stuff(self: Bar) -> float {
        return 0;
    }

    def do_other_stuff(self: Bar) -> float {
        return 0;
    }
}

with entry {
    _T1 = TypeVar("_T1", bound=Foo);
    _T2 = TypeVar("_T2", bound=Union[Foo, Bar]);
}

class ClassA(Generic[_T1]) {
    async def func1(self: ClassA, a: _T1) -> _T1 {
        _ = a.var1;          # Ok: Foo has var1
        _ = a.var2;          # Error: Foo doesn't have var2
        _ = a(3);            # Ok: Foo is callable with int
        _ = a(3.3);          # Error: Foo.__call__ expects int, not float
        _ = a[0];            # Error: Foo is not subscriptable
        _ = a + 1;           # Error: Foo doesn't support '+'
        _ = -a;              # Error: Foo doesn't support unary '-'
        a += 3;              # Error: Foo doesn't support '+='
        _ = await a;         # Error: Foo is not awaitable
        for _ in a {}       # Error: Foo is not iterable
        a.do_stuff();        # Ok
        a.do_other_stuff();  # Error: Foo doesn't have do_other_stuff
        _ = a.__class__;     # Ok
        _ = a.__doc__;       # Ok
        return a;
    }

    async def func2(self: ClassA, a: _T2) -> _T2 {
        _ = a.var1;          # Ok: both Foo and Bar have var1
        _ = a.var2;          # Error: only Bar has var2 (Foo doesn't)
        _ = a(3);            # Ok (treated as unbounded - error)
        _ = a(3.3);          # Error
        _ = a[0];            # Error
        _ = a + 1;           # Error
        _ = -a;              # Error
        a += 3;              # Error
        _ = await a;         # Error
        for _ in a {}       # Error
        a.do_stuff();        # Ok
        a.do_other_stuff();  # Error: Foo doesn't have do_other_stuff
        _ = a.__class__;     # Ok
        _ = a.__doc__;       # Ok
        return a;
    }
}
