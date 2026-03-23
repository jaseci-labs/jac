"""Test for Generic[] base class establishing canonical TypeVar order.

When a class inherits from both parameterized bases and Generic[...],
the Generic[] declaration is the authoritative source of type parameter
ordering (PEP 484). Without this fix, TypeVars are collected in encounter
order across all bases, which can produce the wrong positional mapping.

Example: dict_values(ValuesView[_VT_co], Generic[_KT_co, _VT_co])
  Without fix: type_params = [_VT_co, _KT_co] (encounter order)
  With fix:    type_params = [_KT_co, _VT_co] (Generic[] order)

This matters because type_args are positional: dict_values[int, str]
maps type_args[0] -> type_params[0], so wrong order swaps K and V.
"""

with entry {
    d: dict[(int, str)] = {1: "hello", 2: "world"};

    # dict.values() returns dict_values[int, str].
    # With correct ordering (_KT_co=int, _VT_co=str), iteration yields str.
    # With wrong ordering (_VT_co=int, _KT_co=str), iteration yields int.
    for v in d.values() {
        good: str = v;   # <-- Should be OK (values are str)
        bad: int = v;    # <-- Should be Error (str not assignable to int)
    }

    # Same test for keys: dict.keys() returns dict_keys[int, str].
    for k in d.keys() {
        good2: int = k;  # <-- Should be OK (keys are int)
        bad2: str = k;   # <-- Should be Error (int not assignable to str)
    }
}
