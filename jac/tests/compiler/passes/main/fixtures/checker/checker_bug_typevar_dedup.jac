"""Test for TypeVar deduplication in _extract_type_params.

When a class inherits from multiple generic bases that share TypeVars,
_extract_type_params must deduplicate by name. Without dedup, positional
mismatches cause TypeVar specialization to fail.

Example: BaseMapping(BaseCollection[K], Generic[K, V]) collects
type_params = [K, K, V] (3 entries) but type_args only has 2 entries,
so V at index 2 never gets matched.
"""

import from typing { TypeVar, Generic }

glob K = TypeVar('K');
glob V = TypeVar('V');
glob T = TypeVar('T');

obj BaseCollection(Generic[T]) {
    def first_key -> T {}
}

obj BaseMapping(BaseCollection[K], Generic[K, V]) {
    """Class with overlapping TypeVars in multiple bases.

    Without dedup, type_params = [K, K, V] (K from BaseCollection, K+V from Generic).
    With dedup, type_params = [K, V] which correctly matches type_args.
    """
    def lookup(key: K) -> V {}
}

obj ConcreteMap(BaseMapping[str, int]) {}

with entry {
    m = ConcreteMap();
    # If TypeVar dedup works, lookup returns int (V=int).
    # Without dedup, V is unresolved -> Unknown, and this assignment should error.
    good: int = m.lookup("key");  # <-- Should be OK (V resolved to int)
    bad: str = m.lookup("key");   # <-- Should be Error (int not assignable to str)
}
