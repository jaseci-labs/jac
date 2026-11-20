"""Test: self.attr: TypeVar assignments in generic classes propagate type correctly.

When a generic class assigns a typed attribute via `self.attr: T = value` in __init__,
the type should be accessible through the full inheritance chain with proper
TypeVar specialization.
"""

import from abc { ABC }

class Item {}

class Container[K, V](ABC) {
    def init(self: Container[K, V], key: K) -> None {
        self.value: V = key;
    }
}

class TypedContainer[T: Item, R: Item](Container[T, R]) {}

class ItemStore(TypedContainer[Item, Item]) {}


class FinalStore(ItemStore) {
    def get_value(self: FinalStore) -> Item;
}


# Previously caused E1030: Type "FinalStore" has no attribute "value"
# because self.value: V in Container wasn't propagating the type
impl FinalStore.get_value(self: FinalStore) -> Item {
    return self.value;
}
