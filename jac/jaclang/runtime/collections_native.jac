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

def __jac_hash_rehash(
    capacity_slot: int,
    keys_slot: int,
    values_slot: int,
    control_slot: int,
    order_slot: int,
    used_slot: int,
    length: int,
    key_stride: int,
    value_stride: int,
    hash_key: int,
    release_storage: int
) {
    capacity = __mem_load_i64(capacity_slot);
    if capacity <= 0
        or (capacity & (capacity - 1)) != 0
        or length < 0
        or length > capacity
        or key_stride < 0
        or value_stride < 0 {
        raise ValueError("Invalid ordered hash storage layout");
    }
    limit = 9223372036854775807 // max(8, key_stride, value_stride);
    if capacity > limit // 2 {
        raise MemoryError("Hash capacity exceeds the addressable size");
    }
    next_capacity = capacity * 2;
    mask = next_capacity - 1;
    keys = __mem_alloc(max(1, next_capacity * key_stride));
    has_values = values_slot != 0;
    values = __mem_alloc(max(1, next_capacity * value_stride)) if has_values else 0;
    control = __mem_alloc_zeroed(next_capacity);
    order = __mem_alloc(next_capacity * 8);
    if keys == 0 or control == 0 or order == 0 or (has_values and values == 0) {
        __mem_call_dtor(release_storage, keys);
        __mem_call_dtor(release_storage, values);
        __mem_call_dtor(release_storage, control);
        __mem_call_dtor(release_storage, order);
        raise MemoryError("Cannot grow hash storage");
    }
    old_keys = __mem_load_ptr(keys_slot);
    old_values = __mem_load_ptr(values_slot) if has_values else 0;
    old_control = __mem_load_ptr(control_slot);
    old_order = __mem_load_ptr(order_slot);
    index = 0;
    while index < length {
        old_slot = __mem_load_i64(old_order + index * 8);
        key = old_keys + old_slot * key_stride;
        hashed = __mem_call_i64(hash_key, key);
        slot = hashed & mask;
        while __mem_load_u8(control + slot) != 0 {
            slot = (slot + 1) & mask;
        }
        __mem_copy(keys + slot * key_stride, key, key_stride);
        if has_values {
            __mem_copy(
                values + slot * value_stride,
                old_values + old_slot * value_stride,
                value_stride
            );
        }
        __mem_store_u8(control + slot, u8(((hashed >> 57) & 127) | 128));
        __mem_store_i64(order + index * 8, slot);
        index += 1;
    }
    __mem_store_ptr(keys_slot, keys);
    if has_values {
        __mem_store_ptr(values_slot, values);
    }
    __mem_store_ptr(control_slot, control);
    __mem_store_ptr(order_slot, order);
    __mem_store_i64(capacity_slot, next_capacity);
    __mem_store_i64(used_slot, length);
    __mem_call_dtor(release_storage, old_keys);
    __mem_call_dtor(release_storage, old_values);
    __mem_call_dtor(release_storage, old_control);
    __mem_call_dtor(release_storage, old_order);
}
