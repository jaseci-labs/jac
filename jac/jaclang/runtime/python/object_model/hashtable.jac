import from c {
    def memset(target: ptr, value: i32, size: u64) -> ptr;  def PyMem_Malloc(
        size: u64
    ) -> ptr;  def PyMem_Free(block: ptr);  obj HashtableForeachCall {
        has call: Callable[[ptr, ptr, ptr, ptr], i32] = 0;
    }
}

glob:priv HASHTABLE_MIN_SIZE: Final[u64] = u64(16),
     HASHTABLE_HIGH: Final[f64] = 0.50,
     HASHTABLE_LOW: Final[f64] = 0.10,
     ENTRY_SIZE: Final[u64] = _Py_hashtable_entry_t_SIZE,
     TABLE_SIZE: Final[u64] = _Py_hashtable_t_SIZE,
     BUCKET_SIZE: Final[u64] = _Py_slist_t_SIZE;

def table_of(ht: ptr) -> ptr[_Py_hashtable_t];

def table_head(t: ptr[_Py_hashtable_t], bucket: u64) -> ptr[_Py_hashtable_entry_t];

def entry_next(ent: ptr[_Py_hashtable_entry_t]) -> ptr[_Py_hashtable_entry_t];

def _Py_slist_init(lst: ptr[_Py_slist_t]);

def _Py_slist_prepend(lst: ptr[_Py_slist_t], item: ptr[_Py_slist_item_t]);

def _Py_slist_remove(
    lst: ptr[_Py_slist_t], previous: ptr[_Py_slist_item_t], item: ptr[_Py_slist_item_t]
);

def round_size(s: u64) -> u64;

def _Py_hashtable_get_entry_ptr(
    t: ptr[_Py_hashtable_t], key: ptr
) -> ptr[_Py_hashtable_entry_t];

def hashtable_rehash(t: ptr[_Py_hashtable_t]) -> i32;

def _Py_hashtable_destroy_entry(
    t: ptr[_Py_hashtable_t], ent: ptr[_Py_hashtable_entry_t]
);

import from c {
    def _Py_hashtable_hash_ptr(key: ptr) -> u64 {
        x = u64.wrap(int(key));
        return (x >> u64(4)) | wrapping_shl(x, u64(60));
    }  def _Py_hashtable_compare_direct(key1: ptr, key2: ptr) -> i32 {
        return i32(int(key1) == int(key2));
    }  def _Py_hashtable_size(ht: ptr) -> u64 {
        t = table_of(ht);
        size = TABLE_SIZE;

        size += t.view(1)[0].nbuckets * BUCKET_SIZE;

        size += t.view(1)[0].nentries * ENTRY_SIZE;
        return size;
    }  def _Py_hashtable_len(ht: ptr) -> u64 {
        return table_of(ht).view(1)[0].nentries;
    }  def _Py_hashtable_get_entry_generic(ht: ptr, key: ptr) -> ptr {
        t = table_of(ht);
        key_hash: u64 = t.view(1)[0].hash_func(key);
        index = key_hash & (t.view(1)[0].nbuckets - u64(1));
        ent = table_head(t, index);
        while True {
            if not ent {
                return ptr();
            }
            if ent.view(1)[0].key_hash == key_hash
                and t.view(1)[0].compare_func(key, ent.view(1)[0].key) != 0 {
                break;
            }
            ent = entry_next(ent);
        }
        return ptr(ent);
    }  def _Py_hashtable_steal(ht: ptr, key: ptr) -> ptr {
        t = table_of(ht);
        key_hash: u64 = t.view(1)[0].hash_func(key);
        index = key_hash & (t.view(1)[0].nbuckets - u64(1));
        ent = table_head(t, index);
        previous = ptr[_Py_hashtable_entry_t]();
        while True {
            if not ent {
                return ptr();
            }
            if ent.view(1)[0].key_hash == key_hash
                and t.view(1)[0].compare_func(key, ent.view(1)[0].key) != 0 {
                break;
            }
            previous = ent;
            ent = entry_next(ent);
        }

        _Py_slist_remove(
            t.view(1)[0].buckets + i64.wrap(index),
            ptr[_Py_slist_item_t](previous),
            ptr[_Py_slist_item_t](ent)
        );
        t.view(1)[0].nentries -= u64(1);

        value = ent.view(1)[0].value;
        t.view(1)[0].alloc.free(ptr(ent));

        if f64(t.view(1)[0].nentries) / f64(t.view(1)[0].nbuckets) < HASHTABLE_LOW {
            hashtable_rehash(t);
        }
        return value;
    }  def _Py_hashtable_set(ht: ptr, key: ptr, value: ptr) -> i32 {
        t = table_of(ht);
        ent = ptr[_Py_hashtable_entry_t](t.view(1)[0].alloc.malloc(ENTRY_SIZE));
        if not ent {
            return i32(-1);
        }

        ent.view(1)[0].key_hash: u64 = t.view(1)[0].hash_func(key);
        ent.view(1)[0].key = key;
        ent.view(1)[0].value = value;

        t.view(1)[0].nentries += u64(1);
        if f64(t.view(1)[0].nentries) / f64(t.view(1)[0].nbuckets) > HASHTABLE_HIGH {
            if hashtable_rehash(t) < 0 {
                t.view(1)[0].nentries -= u64(1);
                t.view(1)[0].alloc.free(ptr(ent));
                return i32(-1);
            }
        }

        index = ent.view(1)[0].key_hash & (t.view(1)[0].nbuckets - u64(1));
        _Py_slist_prepend(
            t.view(1)[0].buckets + i64.wrap(index), ptr[_Py_slist_item_t](ent)
        );
        return i32(0);
    }  def _Py_hashtable_get(ht: ptr, key: ptr) -> ptr {
        t = table_of(ht);
        ent = ptr[_Py_hashtable_entry_t](t.view(1)[0].get_entry_func(t, key));
        if ent {
            return ent.view(1)[0].value;
        }
        return ptr();
    }  def _Py_hashtable_foreach(ht: ptr, func: ptr, user_data: ptr) -> i32 {
        t = table_of(ht);
        callback = HashtableForeachCall();
        callback.call = int(func);
        hv = u64(0);
        while hv < t.view(1)[0].nbuckets {
            ent = table_head(t, hv);
            while ent {
                res = callback.call(
                    ht, ent.view(1)[0].key, ent.view(1)[0].value, user_data
                );
                if res != 0 {
                    return res;
                }
                ent = entry_next(ent);
            }
            hv += u64(1);
        }
        return i32(0);
    }  def _Py_hashtable_new_full(
        hash_func: ptr,
        compare_func: ptr,
        key_destroy_func: ptr,
        value_destroy_func: ptr,
        allocator: ptr
    ) -> ptr {
        alloc_malloc: int = 0;
        alloc_free: int = 0;
        if not allocator {
            alloc_malloc = int(ptr(PyMem_Malloc));
            alloc_free = int(ptr(PyMem_Free));
        } else {
            given = ptr[_Py_hashtable_allocator_t](allocator);
            alloc_malloc = int(given.view(1)[0].malloc);
            alloc_free = int(given.view(1)[0].free);
        }
        alloc = _Py_hashtable_allocator_t(malloc=alloc_malloc, free=alloc_free);

        t = ptr[_Py_hashtable_t](alloc.malloc(TABLE_SIZE));
        if not t {
            return ptr();
        }

        t.view(1)[0].nbuckets = HASHTABLE_MIN_SIZE;
        t.view(1)[0].nentries = u64(0);

        buckets_size = t.view(1)[0].nbuckets * BUCKET_SIZE;
        t.view(1)[0].buckets = ptr[_Py_slist_t](alloc.malloc(buckets_size));
        if not t.view(1)[0].buckets {
            alloc.free(ptr(t));
            return ptr();
        }
        memset(ptr(t.view(1)[0].buckets), i32(0), buckets_size);

        t.view(1)[0].get_entry_func = int(ptr(_Py_hashtable_get_entry_generic));
        t.view(1)[0].hash_func = int(hash_func);
        t.view(1)[0].compare_func = int(compare_func);
        t.view(1)[0].key_destroy_func = int(key_destroy_func);
        t.view(1)[0].value_destroy_func = int(value_destroy_func);
        t.view(1)[0].alloc.malloc = alloc_malloc;
        t.view(1)[0].alloc.free = alloc_free;

        if int(hash_func) == int(ptr(_Py_hashtable_hash_ptr))
            and int(compare_func) == int(ptr(_Py_hashtable_compare_direct)) {
            t.view(1)[0].get_entry_func = int(ptr(_Py_hashtable_get_entry_ptr));
        }
        return ptr(t);
    }  def _Py_hashtable_new(hash_func: ptr, compare_func: ptr) -> ptr {
        return _Py_hashtable_new_full(hash_func, compare_func, ptr(), ptr(), ptr());
    }  def _Py_hashtable_clear(ht: ptr) {
        t = table_of(ht);
        i = u64(0);
        while i < t.view(1)[0].nbuckets {
            ent = table_head(t, i);
            while ent {
                next = entry_next(ent);
                _Py_hashtable_destroy_entry(t, ent);
                ent = next;
            }
            _Py_slist_init(t.view(1)[0].buckets + i64.wrap(i));
            i += u64(1);
        }
        t.view(1)[0].nentries = u64(0);

        hashtable_rehash(t);
    }  def _Py_hashtable_destroy(ht: ptr) {
        t = table_of(ht);
        i = u64(0);
        while i < t.view(1)[0].nbuckets {
            ent = table_head(t, i);
            while ent {
                entry_next_ = entry_next(ent);
                _Py_hashtable_destroy_entry(t, ent);
                ent = entry_next_;
            }
            i += u64(1);
        }
        t.view(1)[0].alloc.free(ptr(t.view(1)[0].buckets));
        t.view(1)[0].alloc.free(ptr(t));
    }
}

impl table_of(ht: ptr) -> ptr[_Py_hashtable_t] {
    return ptr[_Py_hashtable_t](ht);
}

impl table_head(t: ptr[_Py_hashtable_t], bucket: u64) -> ptr[_Py_hashtable_entry_t] {
    return ptr[_Py_hashtable_entry_t](
        (t.view(1)[0].buckets + i64.wrap(bucket)).view(1)[0].head
    );
}

impl entry_next(ent: ptr[_Py_hashtable_entry_t]) -> ptr[_Py_hashtable_entry_t] {
    return ptr[_Py_hashtable_entry_t](ent.view(1)[0]._Py_slist_item.next);
}

impl _Py_slist_init(lst: ptr[_Py_slist_t]) {
    lst.view(1)[0].head = ptr[_Py_slist_item_t]();
}

impl _Py_slist_prepend(lst: ptr[_Py_slist_t], item: ptr[_Py_slist_item_t]) {
    item.view(1)[0].next = ptr[_Py_slist_item_s](lst.view(1)[0].head);
    lst.view(1)[0].head = item;
}

impl _Py_slist_remove(
    lst: ptr[_Py_slist_t], previous: ptr[_Py_slist_item_t], item: ptr[_Py_slist_item_t]
) {
    if previous {
        previous.view(1)[0].next = item.view(1)[0].next;
    } else {
        lst.view(1)[0].head = ptr[_Py_slist_item_t](item.view(1)[0].next);
    }
}

impl round_size(s: u64) -> u64 {
    if s < HASHTABLE_MIN_SIZE {
        return HASHTABLE_MIN_SIZE;
    }
    i = u64(1);
    while i < s {
        i = i << u64(1);
    }
    return i;
}

impl _Py_hashtable_get_entry_ptr(
    t: ptr[_Py_hashtable_t], key: ptr
) -> ptr[_Py_hashtable_entry_t] {
    key_hash = _Py_hashtable_hash_ptr(key);
    index = key_hash & (t.view(1)[0].nbuckets - u64(1));
    ent = table_head(t, index);
    while True {
        if not ent {
            return ptr[_Py_hashtable_entry_t]();
        }
        if int(ent.view(1)[0].key) == int(key) {
            break;
        }
        ent = entry_next(ent);
    }
    return ent;
}

impl hashtable_rehash(t: ptr[_Py_hashtable_t]) -> i32 {
    new_size = round_size(
        u64(f64(t.view(1)[0].nentries) * 2.0 / (HASHTABLE_LOW + HASHTABLE_HIGH))
    );
    if new_size == t.view(1)[0].nbuckets {
        return i32(0);
    }

    buckets_size = new_size * BUCKET_SIZE;
    new_buckets = ptr[_Py_slist_t](t.view(1)[0].alloc.malloc(buckets_size));
    if not new_buckets {
        return i32(-1);
    }
    memset(ptr(new_buckets), i32(0), buckets_size);

    bucket = u64(0);
    while bucket < t.view(1)[0].nbuckets {
        ent = table_head(t, bucket);
        while ent {
            next = entry_next(ent);
            entry_index = ent.view(1)[0].key_hash & (new_size - u64(1));
            _Py_slist_prepend(
                new_buckets + i64.wrap(entry_index), ptr[_Py_slist_item_t](ent)
            );
            ent = next;
        }
        bucket += u64(1);
    }

    t.view(1)[0].alloc.free(ptr(t.view(1)[0].buckets));
    t.view(1)[0].nbuckets = new_size;
    t.view(1)[0].buckets = new_buckets;
    return i32(0);
}

impl _Py_hashtable_destroy_entry(
    t: ptr[_Py_hashtable_t], ent: ptr[_Py_hashtable_entry_t]
) {
    if int(t.view(1)[0].key_destroy_func) != 0 {
        t.view(1)[0].key_destroy_func(ent.view(1)[0].key);
    }
    if int(t.view(1)[0].value_destroy_func) != 0 {
        t.view(1)[0].value_destroy_func(ent.view(1)[0].value);
    }
    t.view(1)[0].alloc.free(ptr(ent));
}
