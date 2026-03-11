"""Tests various diagnostics related to TypeVar usage and scoping.

From Pyright sample: typeVar3.py
"""

import from typing { Callable, Generic, TypeVar, AnyStr }

with entry {
    _T = TypeVar("_T");
    _S = TypeVar("_S");
}

class OuterClass(Generic[_T, AnyStr]) {
    has my_var1: _S;  # Error: _S isn't defined in this context
    has my_var2: AnyStr;  # Ok

    # Error: _T is already in use
    class InnerClass1(Generic[_T]) {}

    # Error: AnyStr is already in use
    class InnerClass2(Generic[_S, AnyStr]) {
        has my_var1: _S;  # Ok

        # Error: _T is already in use in the outer class
        has my_var2: _T;  # Error
    }

    class InnerClass3 {
        # Error: _T is not in scope
        has x: list[_T];  # Error

        def f(self: InnerClass3, x: _T, y: _S, z: _S) -> _T {
            ...;
        }

        def g(self: InnerClass3, x: AnyStr) -> None {
            # Error: _T is not in scope
            y: list[_T];  # Error
        }
    }
}

def func1(a: _T) -> _T | None {
    my_var1: _T;  # Ok

    # Error: _S isn't used in function scope
    my_var2: _S;  # Error

    # Error: _T is already in use
    class InnerClass3(Generic[_T]) {}  # Error
}

with entry {
    # Error: TypeVar used outside of function/class scope
    a: _S = 3;  # Error

    # Error: TypeVar used outside of function/class scope
    b: list[_T] = [];  # Error

    # Error: TypeVar used outside of function/class scope
    c: list[AnyStr] = [];  # Error

    T = TypeVar("T");
}

def foo() -> Callable[[T], T] {
    def inner(v: T) -> T {
        return v;
    }
    return inner;
}

with entry {
    # Error: defnot use type variable in runtime context
    list[T]();  # Error
}
