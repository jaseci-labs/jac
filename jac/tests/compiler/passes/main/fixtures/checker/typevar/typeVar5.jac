"""Tests that unbounded TypeVars properly generate errors for operations.

From Pyright sample: typeVar5.py
"""

import from typing { Generic, TypeVar }

with entry {
    _T1 = TypeVar("_T1");
    _T2 = TypeVar("_T2");
}

class ClassA(Generic[_T1, _T2]) {
    async def func1(self: ClassA, a: _T1) {
        _ = a.temp;  # Error: unbounded TypeVar has no member 'temp'
        _ = a(3);  # Error: unbounded TypeVar is not callable
        _ = a[0];  # Error: unbounded TypeVar is not subscriptable
        _ = a.temp;  # Error
        _ = a + 1;  # Error: unbounded TypeVar doesn't support '+'
        _ = -a;  # Error: unbounded TypeVar doesn't support unary '-'
        a += 3;  # Error
        _ = await a;  # Error: unbounded TypeVar is not awaitable
        for _ in a {  # Error: unbounded TypeVar is not iterable
        }
        _ = a.__class__;  # Ok: all objects have __class__
        _ = a.__doc__;  # Ok: all objects have __doc__
    }

    async def func2(self: ClassA, a: _T2) {
        _ = a.temp;  # Error
        _ = a(3);  # Error
        _ = a[0];  # Error
        _ = a.temp;  # Error
        _ = a + 1;  # Error
        _ = -a;  # Error
        a += 3;  # Error
        _ = await a;  # Error
        for _ in a {  # Error
        }
        _ = a.__class__;  # Ok
        _ = a.__doc__;  # Ok
    }
}
