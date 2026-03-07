"""Tests TypeVar as runtime object vs type parameter.

From Pyright sample: typeVar8.py (originally typeVar7.py)
"""

import typing as t;
import typing_extensions as te;

with entry {
    T1 = t.TypeVar("T1");
    S1 = t.TypeVar("S1", bound=str);
    Ts1 = t.TypeVarTuple("Ts1");
    P1 = t.ParamSpec("P1");

    # TypeVar symbol as runtime object (accessing __name__, __bound__)
    T1.__name__;  # Ok
    S1.__name__;  # Ok
    S1.__bound__;  # Ok
    Ts1.__name__;  # Ok
    P1.__name__;  # Ok
}

def func1(x: bool, a: T1, b: S1) -> T1 | S1 {
    T1___name__ = T1.__name__;
    S1___name__ = S1.__name__;
    Ts1___name__ = Ts1.__name__;
    P1___name__ = P1.__name__;

    # Error: TypeVar used as type parameter doesn't have __name__
    a.__name__;  # Error
    b.__name__;  # Error

    if x {
        return a;
    } else {
        return b;
    }
}

with entry {
    T2 = te.TypeVar("T2");
    S2 = te.TypeVar("S2", bound=str);
    Ts2 = te.TypeVarTuple("Ts2");
    P2 = te.ParamSpec("P2");

    T2.__name__;  # Ok
    S2.__name__;  # Ok
    S2.__bound__;  # Ok
    Ts2.__name__;  # Ok
    P2.__name__;  # Ok
}

def func2(x: bool, a: T2, b: S2) -> T2 | S2 {
    T2___name__ = T2.__name__;
    S2___name__ = S2.__name__;
    Ts2___name__ = Ts2.__name__;
    P2___name__ = P2.__name__;

    if x {
        return a;
    } else {
        return b;
    }
}

def func3(tv: t.TypeVar, tvt: t.TypeVarTuple = ..., ps: t.ParamSpec = ...) -> None {
    ...;
}

with entry {
    func3(T1, Ts1, P1);  # Ok

    # Error: typing.TypeVar is not the same as typing_extensions.TypeVar
    func3(T2);  # Error
}

def func4(tv: te.TypeVar, tvt: te.TypeVarTuple = ..., ps: te.ParamSpec = ...) -> None {
    ...;
}

with entry {
    func4(T2, Ts2, P2);  # Ok

    # Error: typing_extensions.TypeVar is not the same as typing.TypeVar
    func4(T1);  # Error
}
