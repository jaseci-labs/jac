"""Tests that the type checker enforces TypeVar name matching and constraints.

From Pyright sample: typeVar1.py
"""

import from typing { Any, TypeVar }

with entry {
    T1 = TypeVar("T1");  # Ok

    # TypeVar name does not match variable name
    T2 = TypeVar("T3");  # Error

    T4: Any = TypeVar("T4");  # Ok

    my_dict = {};

    # TypeVars cannot be assigned to an index expression
    my_dict["var"] = TypeVar("T5");  # Error

    # TypeVar with a single constraint is an error
    T5 = TypeVar("T5", str);  # Error
}
