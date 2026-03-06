"""Tests covariant and contravariant TypeVars usage in method parameters and return types.

From Pyright sample: typeVar4.py
"""

import from typing { Callable, Generic, TypeVar }

with entry {
    _T = TypeVar("_T");
    _T_co = TypeVar("_T_co", covariant=True);
    _T_contra = TypeVar("_T_contra", contravariant=True);
}

class ClassA(Generic[_T, _T_co, _T_contra]) {
    def func1(self: ClassA, a: _T) {
        ;
    }

    # Error: covariant TypeVars are not allowed for input parameters
    def func2(self: ClassA, a: _T_co) -> Callable {  # Error
        def inner(b: _T_co) -> None {
            ;
        }
        return inner;
    }

    def func3(self: ClassA, a: int | _T_co) {  # Error
        ;
    }

    def func4(self: ClassA, a: list[_T_co]) {  # Ok (nested in invariant position)
        ;
    }

    def func5(self: ClassA, a: _T_contra) {  # Ok
        ;
    }

    def func6(self: ClassA) -> _T | None {  # Ok
        ;
    }

    def func7(self: ClassA) -> _T_co | None {  # Ok
        ;
    }

    # Error: contravariant TypeVars are not allowed for return parameters
    def func8(self: ClassA) -> _T_contra {  # Error
        ...;
    }

    # Error: contravariant TypeVars are not allowed for return parameters
    def func9(self: ClassA) -> _T_contra | int {  # Error
        return 3;
    }

    # Error: contravariant TypeVars are not allowed for return parameters
    def func10(self: ClassA, x: _T_contra)  {  # Error (inferred return type)
        return x;
    }

    def func11(self: ClassA) -> list[_T_contra] {  # Ok (nested in invariant position)
        return [];
    }
}

class ClassB {
    def func1(self: ClassB, a: _T_co) -> _T_co {  # Ok (not class-scoped)
        return a;
    }

    def func2(self: ClassB, a: _T_contra) -> _T_contra {  # Ok (not class-scoped)
        return a;
    }
}
