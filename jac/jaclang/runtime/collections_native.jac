def __jac_array_grow(
    data_slot: int, capacity_slot: int, length: int, stride: int, release_storage: int
) -> int {
    capacity = __mem_load_i64(capacity_slot);
    if stride < 0 or length < 0 or capacity < length {
        raise ValueError("Invalid contiguous storage layout");
    }
    limit = 9223372036854775807 // stride if stride > 0 else 9223372036854775807;
    if length >= limit {
        raise MemoryError("Collection capacity exceeds the addressable size");
    }
    next_capacity = capacity * 2 if capacity <= limit // 2 else limit;
    if next_capacity < 8 {
        next_capacity = min(8, limit);
    }
    if next_capacity <= length {
        next_capacity = length + 1;
    }
    destination = __mem_alloc(next_capacity * stride if stride > 0 else 1);
    if destination == 0 {
        raise MemoryError("Cannot grow collection storage");
    }
    source = __mem_load_ptr(data_slot);
    if length > 0 and stride > 0 {
        __mem_copy(destination, source, length * stride);
    }
    __mem_call_dtor(release_storage, source);
    __mem_store_ptr(data_slot, destination);
    __mem_store_i64(capacity_slot, next_capacity);
    return destination;
}

def __jac_array_append(
    data_slot: int,
    capacity_slot: int,
    length_slot: int,
    stride: int,
    value_slot: int,
    retain_element: int,
    release_storage: int
) {
    length = __mem_load_i64(length_slot);
    if length >= __mem_load_i64(capacity_slot) {
        __jac_array_grow(data_slot, capacity_slot, length, stride, release_storage);
    }
    if retain_element != 0 {
        __mem_call_dtor(retain_element, value_slot);
    }
    if stride > 0 {
        data = __mem_load_ptr(data_slot);
        __mem_copy(data + length * stride, value_slot, stride);
    }
    __mem_store_i64(length_slot, length + 1);
}
