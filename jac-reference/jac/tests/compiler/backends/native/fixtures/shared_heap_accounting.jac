"""An opaque managed object reports allocations through the shared native ABI."""
import from c {
    def jac_heap_size(address: u64) -> i64;  def jac_list_heap_size(
        address: u64
    ) -> i64;
}

obj Owned {
    has values: list[int] = [];
}

def:pub make_owned -> Owned {
    return Owned();
}
def:pub grow_owned(value: Owned) {
    for i in range(1024) {
        value.values.append(i);
    }
}

def:pub owned_size(value: Owned) -> i64 {
    return jac_heap_size(u64(id(value))) + jac_list_heap_size(u64(id(value.values)));
}
