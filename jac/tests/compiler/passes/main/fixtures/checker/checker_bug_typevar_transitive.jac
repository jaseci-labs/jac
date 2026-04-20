"""Test for transitive TypeVar propagation through base_classes.

When build_type_var_solution walks the MRO for a specialized class like
ChildMap[str, int], it must propagate TypeVar bindings through the
base_classes chain to resolve TypeVars defined on ancestor classes.

Example chain: ChildMap[str, int] -> MiddleMap[K, V] -> BaseReader[K, V2]
BaseReader defines read(key: K) -> V2, so V2 must be transitively resolved
through MiddleMap's base_classes entry BaseReader[K, V] to get V2=V=int.
"""

import from typing { TypeVar, Generic }

glob K = TypeVar('K');
glob V = TypeVar('V');
glob V2 = TypeVar('V2');

obj BaseReader(Generic[K, V2]) {
    """Defines a method using its own TypeVar V2."""
    def read(key: K) -> V2 {}
}

obj MiddleMap(BaseReader[K, V]) {
    """Inherits BaseReader, mapping V2 -> V through base_classes parameterization.

    MiddleMap's base_classes contains BaseReader[K, V], so BaseReader's
    type_params [K, V2] map to type_args [K, V].
    When MiddleMap is specialized as MiddleMap[str, int], we need:
      K=str, V=int (from MiddleMap's own params)
      V2=int (transitively, because V2 maps to V which maps to int)
    """
    def write(key: K, value: V) -> None {}
}

obj ChildMap(MiddleMap[str, int]) {}

with entry {
    c = ChildMap();
    # If transitive propagation works, read returns int (V2=V=int).
    # Without it, V2 is unresolved -> Unknown, and no error would be raised.
    good: int = c.read("key");   # <-- Should be OK (V2 resolved to int)
    bad: str = c.read("key");    # <-- Should be Error (int not assignable to str)
}
