import from c {
    glob PyType_Type: PyTypeObject; def _PyErr_SetKeyError(key: ptr[PyObject]);  def _PySet_NextEntryRef(
        set: ptr[PyObject], pos: &mut i64, key: &mut ptr[PyObject], hash: &mut i64
    ) -> i32;  def _PySet_Update(set: ptr[PyObject], iterable: ptr[PyObject]) -> i32;  def _PyDebugAllocatorStats(
        out: ptr, block_name: str, num_blocks: i32, sizeof_block: u64
    );  def _PyErr_FormatNote(format: str, *args: any);  def _PyUnicode_FromId(
        id: ptr
    ) -> ptr[PyObject];  def _PyUnicode_InternImmortal(
        interp: ptr, p: &mut ptr[PyObject]
    );  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def PyEval_GetBuiltins -> ptr[PyObject];  def PyObject_Size(
        o: ptr[PyObject]
    ) -> i64;  def _PyType_AllocNoTrack(
        type: ptr[PyObject], nitems: i64
    ) -> ptr[PyObject];  obj DictCall {
        has predicate: Callable[[ptr[PyObject], ptr], i32] = 0,
            free: Callable[[ptr], None] = 0,
            alloc: Callable[[ptr[PyObject], i64], ptr[PyObject]] = 0,
            watcher:
                Callable[[i32, ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0;
    }  obj EmptyKeys {
        has refcnt: i64 = 0,
            log2_size: u8 = 0,
            log2_index_bytes: u8 = 0,
            kind: u8 = 0,
            padding: u8 = 0,
            version: u32 = 0,
            usable: i64 = 0,
            nentries: i64 = 0,
            indices: u64 = 0;
    }  glob:priv empty_keys_struct: EmptyKeys = EmptyKeys(
             refcnt=-9223372036854775807 - 1,
             log2_size=0,
             log2_index_bytes=3,
             kind=1,
             padding=0,
             version=1,
             usable=0,
             nentries=0,
             indices=0xFFFFFFFFFFFFFFFF
         ),
         missing_key: ptr[PyObject] = ptr[PyObject](),
         keys_key: ptr[PyObject] = ptr[PyObject]();
}

def interned_name(which: i32) -> ptr[PyObject];

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

def object_xincref(op: ptr[PyObject]);

def freelist_pop_mem(offset: i64) -> ptr;

def freelist_push_mem(offset: i64, block: ptr, maxsize: i64) -> bool;

def jacpy_memory_fill(target: ptr, value: i32, size: i64);

glob:priv STACKREF_NULL: u64 = u64(1);

def object_is_immortal(op: ptr[PyObject]) -> bool;

def stackref_new(op: ptr[PyObject]) -> u64;

def stackref_steal(op: ptr[PyObject]) -> u64;

def stackref_close(bits: u64);

def stackref_clear(slot: ptr[u64]);

glob:priv PyDict_LOG_MINSIZE: i64 = 3,
     PyDict_MINSIZE: i64 = 8,
     PERTURB_SHIFT: u64 = u64(5),
     DKIX_EMPTY: i64 = -1,
     DKIX_DUMMY: i64 = -2,
     DKIX_ERROR: i64 = -3,
     DKIX_KEY_CHANGED: i64 = -4,
     DICT_KEYS_GENERAL: i64 = 0,
     DICT_KEYS_UNICODE: i64 = 1,
     DICT_KEYS_SPLIT: i64 = 2,
     SHARED_KEYS_MAX_SIZE: i64 = 30,
     NEXT_LOG2_SHARED_KEYS_MAX_SIZE: i64 = 6,
     KEY_ENTRY_SIZE: i64 = 24,
     UNICODE_ENTRY_SIZE: i64 = 16,
     PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     DICT_IMMORTAL_REFCNT: i64 = -0x7FFFFFFFFFFFFFFF - 1,
     EVENT_ADDED: i32 = 0,
     EVENT_MODIFIED: i32 = 1,
     EVENT_DELETED: i32 = 2,
     EVENT_CLONED: i32 = 3,
     EVENT_CLEARED: i32 = 4,
     EVENT_DEALLOCATED: i32 = 5,
     DICT_MAX_WATCHERS: i64 = 8,
     MANAGED_DICT_OFFSET: i64 = -24;

def keys_i64(k: ptr[u8], offset: i64) -> i64;

def set_keys_i64(k: ptr[u8], offset: i64, value: i64);

def dk_refcnt(k: ptr[u8]) -> i64;

def dk_log2_size(k: ptr[u8]) -> i64;

def dk_log2_index_bytes(k: ptr[u8]) -> i64;

def dk_kind(k: ptr[u8]) -> i64;

def set_dk_kind(k: ptr[u8], kind: i64);

def dk_version(k: ptr[u8]) -> u32;

def set_dk_version(k: ptr[u8], version: u32);

def dk_usable(k: ptr[u8]) -> i64;

def set_dk_usable(k: ptr[u8], usable: i64);

def dk_nentries(k: ptr[u8]) -> i64;

def set_dk_nentries(k: ptr[u8], nentries: i64);

def dk_size(k: ptr[u8]) -> i64;

def dk_is_unicode(k: ptr[u8]) -> bool;

def dk_entries(k: ptr[u8]) -> ptr[u8];

def key_entry(k: ptr[u8], ix: i64) -> ptr[i64];

def unicode_entry(k: ptr[u8], ix: i64) -> ptr[i64];

def entry_key(k: ptr[u8], ix: i64) -> ptr[PyObject];

def entry_value(k: ptr[u8], ix: i64) -> ptr[PyObject];

def set_entry_key(k: ptr[u8], ix: i64, key: ptr[PyObject]);

def set_entry_value(k: ptr[u8], ix: i64, value: ptr[PyObject]);

def entry_hash(k: ptr[u8], ix: i64) -> i64;

def set_entry_hash(k: ptr[u8], ix: i64, hash: i64);

def dictkeys_get_index(k: ptr[u8], i: i64) -> i64;

def dictkeys_set_index(k: ptr[u8], i: i64, ix: i64);

def usable_fraction(n: i64) -> i64;

def calculate_log2_keysize(minsize_in: i64) -> i64;

def estimate_log2_keysize(n: i64) -> i64;

def growth_rate(mp: ptr[PyObject]) -> i64;

def empty_keys -> ptr[u8];

def dictkeys_incref(k: ptr[u8]);

def dictkeys_decref(k: ptr[u8]);

def new_keys_object(log2_size: i64, unicode: bool) -> ptr[u8];

def free_keys_object(k: ptr[u8]);

def keys_size(k: ptr[u8]) -> i64;

def values_capacity(v: ptr[u8]) -> i64;

def values_size(v: ptr[u8]) -> i64;

def set_values_size(v: ptr[u8], size: i64);

def values_embedded(v: ptr[u8]) -> bool;

def values_valid(v: ptr[u8]) -> bool;

def set_values_valid(v: ptr[u8], valid: bool);

def value_at(v: ptr[u8], ix: i64) -> ptr[PyObject];

def set_value_at(v: ptr[u8], ix: i64, value: ptr[PyObject]);

def insertion_order(v: ptr[u8]) -> ptr[u8];

def add_to_insertion_order(v: ptr[u8], ix: i64);

def delete_index_from_values(v: ptr[u8], ix: i64);

def values_size_from_count(count: i64) -> i64;

def new_values(size: i64) -> ptr[u8];

def free_values(v: ptr[u8]);

def shared_keys_usable_size(k: ptr[u8]) -> i64;

def dict_of(op: ptr[PyObject]) -> ptr[PyDictObject];

def dict_keys_of(mp: ptr[PyObject]) -> ptr[u8];

def set_dict_keys(mp: ptr[PyObject], k: ptr[u8]);

def dict_values_of(mp: ptr[PyObject]) -> ptr[u8];

def set_dict_values(mp: ptr[PyObject], v: ptr[u8]);

def dict_used(mp: ptr[PyObject]) -> i64;

def set_dict_used(mp: ptr[PyObject], used: i64);

def has_split_table(mp: ptr[PyObject]) -> bool;

def dict_check(op: ptr[PyObject]) -> bool;

def dict_check_exact(op: ptr[PyObject]) -> bool;

def unicode_check_exact(op: ptr[PyObject]) -> bool;

def unicode_get_hash(op: ptr[PyObject]) -> i64;

def hash_fast(op: ptr[PyObject]) -> i64;

def hash_unicode_key(key: ptr[PyObject]) -> i64;

def unicode_eq(a: ptr[PyObject], b: ptr[PyObject]) -> bool;

def notify_event(
    event: i32, mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
);

def index_from_order(mp: ptr[PyObject], i: i64) -> i64;

def next_probe(i: u64, perturb: u64, mask: u64) -> u64;

def lookdict_index(k: ptr[u8], hash: i64, index: i64) -> i64;

glob:priv CHECK_UNICODE_UNICODE: i64 = 0,
     CHECK_UNICODE_GENERIC: i64 = 1,
     CHECK_GENERIC: i64 = 2;

def check_lookup(
    mode: i64, mp: ptr[PyObject], k: ptr[u8], ix: i64, key: ptr[PyObject], hash: i64
) -> i64;

def do_lookup(
    mode: i64, mp: ptr[PyObject], k: ptr[u8], key: ptr[PyObject], hash: i64
) -> i64;

def unicodekeys_lookup_unicode(k: ptr[u8], key: ptr[PyObject], hash: i64) -> i64;

def check_keys_unicode(k: ptr[u8], key: ptr[PyObject]) -> bool;

def dict_lookup(
    mp: ptr[PyObject], key: ptr[PyObject], hash: i64
) -> tuple[i64, ptr[PyObject]];

def find_empty_slot(k: ptr[u8], hash: i64) -> i64;

def insertion_resize(mp: ptr[PyObject], unicode: bool) -> i32;

def insert_combined_dict(
    mp: ptr[PyObject], hash: i64, key: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def insert_split_key(k: ptr[u8], key: ptr[PyObject], hash: i64) -> i64;

def insert_split_value(
    mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], ix: i64
);

def insertdict(
    mp: ptr[PyObject], key: ptr[PyObject], hash: i64, value: ptr[PyObject]
) -> i32;

def insert_to_emptydict(
    mp: ptr[PyObject], key: ptr[PyObject], hash: i64, value: ptr[PyObject]
) -> i32;

def build_indices(k: ptr[u8], n: i64);

def invalidate_and_clear_inline_values(values: ptr[u8]);

def copy_combined_entries(oldkeys: ptr[u8], newkeys: ptr[u8], numentries: i64);

def dictresize(mp: ptr[PyObject], log2_newsize: i64, unicode_in: bool) -> i32;

def new_dict(
    k: ptr[u8], values: ptr[u8], used: i64, free_values_on_failure: bool
) -> ptr[PyObject];

def new_dict_with_shared_keys(k: ptr[u8]) -> ptr[PyObject];

def clone_combined_dict_keys(orig: ptr[PyObject]) -> ptr[u8];

def dict_new_presized(minused: i64, unicode: bool) -> ptr[PyObject];

def dict_unhashable_type(key: ptr[PyObject]);

def setitem_take2(mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]) -> i32;

def setitem_lock_held(
    mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def delitem_common(mp: ptr[PyObject], hash: i64, ix: i64, old_value: ptr[PyObject]);

def dict_getitem(op: ptr[PyObject], key: ptr[PyObject], warnmsg: str) -> ptr[PyObject];

def get_item_ref_known_hash(
    op: ptr[PyObject], key: ptr[PyObject], hash: i64
) -> tuple[i32, ptr[PyObject]];

def store_result(result: ptr[ptr[PyObject]], value: ptr[PyObject]);

import from c {
    def _PyDict_DebugMallocStats(out: ptr) {
        _PyDebugAllocatorStats(
            out,
            "free PyDictObject",
            i32(freelist(_Py_freelists_DICTS).view(1)[0].size),
            u64(PyDictObject_SIZE)
        );
        _PyDebugAllocatorStats(
            out,
            "free PyDictKeysObject",
            i32(freelist(_Py_freelists_DICTKEYS).view(1)[0].size),
            u64(PyDictKeysObject_INDICES)
        );
    }  def _PyDict_CheckConsistency(op: ptr[PyObject], check_content: i32) -> i32 {
        return i32(1);
    }  def PyDict_New -> ptr[PyObject] {
        return new_dict(empty_keys(), ptr[u8](), 0, False);
    }  def _PyDictKeys_StringLookup(k: ptr[u8], key: ptr[PyObject]) -> i64 {
        if not check_keys_unicode(k, key) {
            return DKIX_ERROR;
        }
        return unicodekeys_lookup_unicode(k, key, hash_unicode_key(key));
    }  def _PyDictKeys_StringLookupAndVersion(
        k: ptr[u8], key: ptr[PyObject], version: ptr[u32]
    ) -> i64 {
        if not check_keys_unicode(k, key) {
            return DKIX_ERROR;
        }
        ix = unicodekeys_lookup_unicode(k, key, hash_unicode_key(key));
        version.view(1)[0] = _PyDictKeys_GetVersionForCurrentState(
            ptr(current_interp()), k
        );
        return ix;
    }  def _PyDictKeys_StringLookupSplit(k: ptr[u8], key: ptr[PyObject]) -> i64 {
        hash = unicode_get_hash(key);
        if hash == -1 {
            hash = PyObject_Hash(key);
            if hash == -1 {
                PyErr_Clear();
                return DKIX_ERROR;
            }
        }
        return unicodekeys_lookup_unicode(k, key, hash);
    }  def _Py_dict_lookup(
        mp: ptr[PyObject], key: ptr[PyObject], hash: i64, value_addr: ptr[ptr[PyObject]]
    ) -> i64 {
        (ix, value) = dict_lookup(mp, key, hash);
        value_addr.view(1)[0] = value;
        return ix;
    }  def _Py_dict_lookup_threadsafe(
        mp: ptr[PyObject], key: ptr[PyObject], hash: i64, value_addr: ptr[ptr[PyObject]]
    ) -> i64 {
        (ix, value) = dict_lookup(mp, key, hash);
        value_addr.view(1)[0] = object_xnew_ref(value);
        return ix;
    }  def _Py_dict_lookup_threadsafe_stackref(
        mp: ptr[PyObject], key: ptr[PyObject], hash: i64, value_addr: ptr[u64]
    ) -> i64 {
        (ix, value) = dict_lookup(mp, key, hash);
        value_addr.view(1)[0] = stackref_new(value);
        return ix;
    }  def _PyDict_GetMethodStackRef(
        mp: ptr[PyObject], key: ptr[PyObject], method: ptr[u64]
    ) -> i32 {
        hash = hash_unicode_key(key);
        object_incref(mp);
        (ix, value) = dict_lookup(mp, key, hash);
        found = object_xnew_ref(value);
        object_decref(mp);
        if ix == DKIX_ERROR {
            stackref_clear(method);
            return i32(-1);
        }
        if ix >= 0 and found {
            old = method.view(1)[0];
            method.view(1)[0] = stackref_steal(found);
            stackref_close(old);
            return i32(1);
        }
        return i32(0);
    }  def _PyDict_HasOnlyStringKeys(dict: ptr[PyObject]) -> i32 {
        if dk_kind(dict_keys_of(dict)) != DICT_KEYS_GENERAL {
            return i32(1);
        }
        pos: i64 = 0;
        while True {
            (found, pos, key, value, hash) = next_with_hash(dict, pos);
            if not found {
                return i32(1);
            }
            if not type_has_feature(object_type(key), Py_TPFLAGS_UNICODE_SUBCLASS) {
                return i32(0);
            }
        }
        return i32(1);
    }  def _PyDict_EnablePerThreadRefcounting(op: ptr[PyObject]) -> None {
        return;
    }  def _PyDict_NewPresized(minused: i64) -> ptr[PyObject] {
        return dict_new_presized(minused, False);
    }  def _PyDict_FromItems(
        keys: ptr[ptr[PyObject]],
        keys_offset: i64,
        values: ptr[ptr[PyObject]],
        values_offset: i64,
        length: i64
    ) -> ptr[PyObject] {
        unicode = True;
        ks = keys;
        for i in range(length) {
            if not unicode_check_exact(ks.view(1)[0]) {
                unicode = False;
                break;
            }
            ks = ks + keys_offset;
        }
        dict = dict_new_presized(length, unicode);
        if not dict {
            return NULL;
        }
        ks = keys;
        vs = values;
        for i in range(length) {
            if setitem_lock_held(dict, ks.view(1)[0], vs.view(1)[0]) < 0 {
                object_decref(dict);
                return NULL;
            }
            ks = ks + keys_offset;
            vs = vs + values_offset;
        }
        return dict;
    }  def PyDict_GetItem(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
        return dict_getitem(
            op,
            key,
            "Exception ignored in PyDict_GetItem(); consider using PyDict_GetItemRef() or PyDict_GetItemWithError()"
        );
    }  def _PyDict_LookupIndex(mp: ptr[PyObject], key: ptr[PyObject]) -> i64 {
        hash = hash_fast(key);
        if hash == -1 {
            dict_unhashable_type(key);
            return -1;
        }
        (ix, value) = dict_lookup(mp, key, hash);
        return ix;
    }  def _PyDict_GetItem_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64
    ) -> ptr[PyObject] {
        if not dict_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        (ix, value) = dict_lookup(op, key, hash);
        return value;
    }  def _PyDict_GetItemRef_KnownHash_LockHeld(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64, result: ptr[ptr[PyObject]]
    ) -> i32 {
        (status, value) = get_item_ref_known_hash(op, key, hash);
        result.view(1)[0] = value;
        return status;
    }  def _PyDict_GetItemRef_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64, result: ptr[ptr[PyObject]]
    ) -> i32 {
        (status, value) = get_item_ref_known_hash(op, key, hash);
        result.view(1)[0] = value;
        return status;
    }  def PyDict_GetItemRef(
        op: ptr[PyObject], key: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32 {
        if not dict_check(op) {
            PyErr_BadInternalCall();
            result.view(1)[0] = NULL;
            return i32(-1);
        }
        hash = hash_fast(key);
        if hash == -1 {
            dict_unhashable_type(key);
            result.view(1)[0] = NULL;
            return i32(-1);
        }
        (status, value) = get_item_ref_known_hash(op, key, hash);
        result.view(1)[0] = value;
        return status;
    }  def _PyDict_GetItemRef_Unicode_LockHeld(
        op: ptr[PyObject], key: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32 {
        hash = hash_fast(key);
        if hash == -1 {
            dict_unhashable_type(key);
            result.view(1)[0] = NULL;
            return i32(-1);
        }
        (status, value) = get_item_ref_known_hash(op, key, hash);
        result.view(1)[0] = value;
        return status;
    }  def PyDict_GetItemWithError(
        op: ptr[PyObject], key: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not dict_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        hash = hash_fast(key);
        if hash == -1 {
            dict_unhashable_type(key);
            return NULL;
        }
        (ix, value) = dict_lookup(op, key, hash);
        return value;
    }  def _PyDict_GetItemWithError(
        dp: ptr[PyObject], kv: ptr[PyObject]
    ) -> ptr[PyObject] {
        hash = PyObject_Hash(kv);
        if hash == -1 {
            return NULL;
        }
        return _PyDict_GetItem_KnownHash(dp, kv, hash);
    }  def _PyDict_GetItemIdWithError(dp: ptr[PyObject], key: ptr) -> ptr[PyObject] {
        kv = _PyUnicode_FromId(key);
        if not kv {
            return NULL;
        }
        return _PyDict_GetItem_KnownHash(dp, kv, unicode_get_hash(kv));
    }  def _PyDict_GetItemStringWithError(
        v: ptr[PyObject], key: ptr[u8]
    ) -> ptr[PyObject] {
        kv = PyUnicode_FromString(key);
        if not kv {
            return NULL;
        }
        rv = PyDict_GetItemWithError(v, kv);
        object_decref(kv);
        return rv;
    }  def _PyDict_LoadGlobal(
        globals: ptr[PyObject], builtins: ptr[PyObject], key: ptr[PyObject]
    ) -> ptr[PyObject] {
        hash = hash_fast(key);
        if hash == -1 {
            return NULL;
        }
        (ix, value) = dict_lookup(globals, key, hash);
        if ix == DKIX_ERROR {
            return NULL;
        }
        if ix != DKIX_EMPTY and value {
            return object_new_ref(value);
        }
        (ix2, value2) = dict_lookup(builtins, key, hash);
        return object_xnew_ref(value2);
    }  def _PyDict_LoadGlobalStackRef(
        globals: ptr[PyObject],
        builtins: ptr[PyObject],
        key: ptr[PyObject],
        res: ptr[u64]
    ) {
        hash = hash_fast(key);
        if hash == -1 {
            res.view(1)[0] = STACKREF_NULL;
            return;
        }
        (ix, value) = dict_lookup(globals, key, hash);
        if ix == DKIX_ERROR {
            res.view(1)[0] = STACKREF_NULL;
            return;
        }
        if ix != DKIX_EMPTY and value {
            res.view(1)[0] = stackref_new(value);
            return;
        }
        (ix2, value2) = dict_lookup(builtins, key, hash);
        res.view(1)[0] = stackref_new(value2);
    }  def _PyDict_LoadBuiltinsFromGlobals(globals: ptr[PyObject]) -> ptr[PyObject] {
        if not dict_check(globals) {
            PyErr_BadInternalCall();
            return NULL;
        }
        key = PyUnicode_InternFromString(ptr[u8]("__builtins__"));
        if not key {
            return NULL;
        }
        (ix, builtins) = dict_lookup(globals, key, unicode_get_hash(key));
        object_decref(key);
        if ix == DKIX_ERROR {
            return NULL;
        }
        if not builtins {
            return object_new_ref(PyEval_GetBuiltins());
        }
        if object_type_check(builtins, ptr[PyTypeObject](addressof(PyModule_Type))) {
            builtins = PyModule_GetDict(builtins);
        }
        return object_new_ref(builtins);
    }  def _PyDict_SetItem_Take2(
        mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
    ) -> i32 {
        return setitem_take2(mp, key, value);
    }  def PyDict_SetItem(
        op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
    ) -> i32 {
        if not dict_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        return setitem_take2(op, object_new_ref(key), object_new_ref(value));
    }  def _PyDict_SetItem_KnownHash_LockHeld(
        mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], hash: i64
    ) -> i32 {
        if dict_keys_of(mp) == empty_keys() {
            return insert_to_emptydict(
                mp, object_new_ref(key), hash, object_new_ref(value)
            );
        }
        return insertdict(mp, object_new_ref(key), hash, object_new_ref(value));
    }  def _PyDict_SetItem_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], hash: i64
    ) -> i32 {
        if not dict_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        return _PyDict_SetItem_KnownHash_LockHeld(op, key, value, hash);
    }  def PyDict_DelItem(op: ptr[PyObject], key: ptr[PyObject]) -> i32 {
        hash = hash_fast(key);
        if hash == -1 {
            dict_unhashable_type(key);
            return i32(-1);
        }
        return _PyDict_DelItem_KnownHash(op, key, hash);
    }  def _PyDict_DelItem_KnownHash_LockHeld(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64
    ) -> i32 {
        if not dict_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        (ix, old_value) = dict_lookup(op, key, hash);
        if ix == DKIX_ERROR {
            return i32(-1);
        }
        if ix == DKIX_EMPTY or not old_value {
            _PyErr_SetKeyError(key);
            return i32(-1);
        }
        notify_event(EVENT_DELETED, op, key, NULL);
        delitem_common(op, hash, ix, old_value);
        return i32(0);
    }  def _PyDict_DelItem_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64
    ) -> i32 {
        return _PyDict_DelItem_KnownHash_LockHeld(op, key, hash);
    }  def _PyDict_DelItemIf(
        op: ptr[PyObject], key: ptr[PyObject], predicate: ptr, arg: ptr
    ) -> i32 {
        hash = PyObject_Hash(key);
        if hash == -1 {
            return i32(-1);
        }
        (ix, old_value) = dict_lookup(op, key, hash);
        if ix == DKIX_ERROR {
            return i32(-1);
        }
        if ix == DKIX_EMPTY or not old_value {
            return i32(0);
        }
        calls = ptr[DictCall](
            __thread_local_block("jac_object_model_dict_call_slot", 32)
        );
        calls.view(1)[0].predicate = int(predicate);
        res = calls.view(1)[0].predicate(old_value, arg);
        if res == -1 {
            return i32(-1);
        }
        if res > 0 {
            notify_event(EVENT_DELETED, op, key, NULL);
            delitem_common(op, hash, ix, old_value);
            return i32(1);
        }
        return i32(0);
    }  def _PyDict_Clear_LockHeld(op: ptr[PyObject]) {
        clear_lock_held(op);
    }  def PyDict_Clear(op: ptr[PyObject]) {
        clear_lock_held(op);
    }  def _PyDict_Next(
        op: ptr[PyObject],
        ppos: ptr[i64],
        pkey: ptr[ptr[PyObject]],
        pvalue: ptr[ptr[PyObject]],
        phash: ptr[i64]
    ) -> i32 {
        (found, pos, key, value, hash) = next_with_hash(op, ppos.view(1)[0]);
        if not found {
            return i32(0);
        }
        ppos.view(1)[0] = pos;
        store_result(pkey, key);
        store_result(pvalue, value);
        if phash {
            phash.view(1)[0] = hash;
        }
        return i32(1);
    }  def PyDict_Next(
        op: ptr[PyObject],
        ppos: ptr[i64],
        pkey: ptr[ptr[PyObject]],
        pvalue: ptr[ptr[PyObject]]
    ) -> i32 {
        return _PyDict_Next(op, ppos, pkey, pvalue, ptr[i64]());
    }  def _PyDict_Pop_KnownHash(
        mp: ptr[PyObject], key: ptr[PyObject], hash: i64, result: ptr[ptr[PyObject]]
    ) -> i32 {
        if dict_used(mp) == 0 {
            store_result(result, NULL);
            return i32(0);
        }
        (ix, old_value) = dict_lookup(mp, key, hash);
        if ix == DKIX_ERROR {
            store_result(result, NULL);
            return i32(-1);
        }
        if ix == DKIX_EMPTY or not old_value {
            store_result(result, NULL);
            return i32(0);
        }
        notify_event(EVENT_DELETED, mp, key, NULL);
        delitem_common(mp, hash, ix, object_new_ref(old_value));
        if result {
            result.view(1)[0] = old_value;
        } else {
            object_decref(old_value);
        }
        return i32(1);
    }  def PyDict_Pop(
        op: ptr[PyObject], key: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32 {
        if not dict_check(op) {
            store_result(result, NULL);
            PyErr_BadInternalCall();
            return i32(-1);
        }
        if dict_used(op) == 0 {
            store_result(result, NULL);
            return i32(0);
        }
        hash = hash_fast(key);
        if hash == -1 {
            dict_unhashable_type(key);
            store_result(result, NULL);
            return i32(-1);
        }
        return _PyDict_Pop_KnownHash(op, key, hash, result);
    }  def PyDict_PopString(
        op: ptr[PyObject], key: ptr[u8], result: ptr[ptr[PyObject]]
    ) -> i32 {
        key_obj = PyUnicode_FromString(key);
        if not key_obj {
            store_result(result, NULL);
            return i32(-1);
        }
        res = PyDict_Pop(op, key_obj, result);
        object_decref(key_obj);
        return res;
    }  def _PyDict_Pop(
        dict: ptr[PyObject], key: ptr[PyObject], default_value: ptr[PyObject]
    ) -> ptr[PyObject] {
        return dict_pop_default(dict, key, default_value);
    }  def _PyDict_FromKeys(
        cls: ptr[PyObject], iterable: ptr[PyObject], value: ptr[PyObject]
    ) -> ptr[PyObject] {
        d = PyObject_CallNoArgs(cls);
        if not d {
            return NULL;
        }
        if dict_check_exact(d) {
            if dict_check_exact(iterable) {
                return dict_dict_fromkeys(d, iterable, value);
            }
            if anyset_check_exact(iterable) {
                return dict_set_fromkeys(d, iterable, value);
            }
        }
        it = PyObject_GetIter(iterable);
        if not it {
            object_decref(d);
            return NULL;
        }
        exact = dict_check_exact(d);
        while True {
            key = PyIter_Next(it);
            if not key {
                break;
            }
            status = setitem_lock_held(d, key, value)
                if exact
                else PyObject_SetItem(d, key, value);
            object_decref(key);
            if status < 0 {
                object_decref(it);
                object_decref(d);
                return NULL;
            }
        }
        object_decref(it);
        if PyErr_Occurred() {
            object_decref(d);
            return NULL;
        }
        return d;
    }
}

def clear_embedded_values(values: ptr[u8], nentries: i64);

def clear_lock_held(op: ptr[PyObject]);

def dict_pop_default(
    dict: ptr[PyObject], key: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject];

def dict_dict_fromkeys(
    mp: ptr[PyObject], iterable: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def dict_set_fromkeys(
    mp: ptr[PyObject], iterable: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def next_with_hash(
    op: ptr[PyObject], pos: i64
) -> tuple[bool, i64, ptr[PyObject], ptr[PyObject], i64];

def set_refcount(op: ptr[PyObject], refcnt: i64);

def dict_dealloc(self: ptr[PyObject]);

def free_object(op: ptr[PyObject]);

def dict_repr(self: ptr[PyObject]) -> ptr[PyObject];

def dict_length(self: ptr[PyObject]) -> i64;

def dict_subscript(self: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];

def dict_ass_sub(mp: ptr[PyObject], v: ptr[PyObject], w: ptr[PyObject]) -> i32;

def dict_to_list(dict: ptr[PyObject], what: i32) -> ptr[PyObject];

def dict_fromkeys(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def dict_update_arg(self: ptr[PyObject], arg: ptr[PyObject]) -> i32;

def dict_update_common(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], methname: ptr[u8]
) -> i32;

def dict_update(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def merge_from_seq2(d: ptr[PyObject], seq2: ptr[PyObject], override_mode: i32) -> i32;

def dict_dict_merge(mp: ptr[PyObject], other: ptr[PyObject], override_in: i32) -> i32;

def dict_merge(a: ptr[PyObject], b: ptr[PyObject], override_mode: i32) -> i32;

def copy_values(values: ptr[u8]) -> ptr[u8];

def copy_lock_held(o: ptr[PyObject]) -> ptr[PyObject];

def dict_equal(a: ptr[PyObject], b: ptr[PyObject]) -> i32;

def dict_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject];

def dict___contains__(self: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];

def dict_get(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def setdefault_ref(
    d: ptr[PyObject],
    key: ptr[PyObject],
    default_value: ptr[PyObject],
    incref_result: bool
) -> tuple[i32, ptr[PyObject]];

def dict_setdefault(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def dict_clear(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dict_pop(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def dict_popitem(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dict_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def dict_tp_clear(op: ptr[PyObject]) -> i32;

def dict___sizeof__(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dict_or(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def dict_ior(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def dict_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def dict_init(self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

def dict_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def dict_iter(self: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyDict_SizeOf_LockHeld(mp: ptr[PyObject]) -> i64 {
        res = object_type(mp).view(1)[0].tp_basicsize;
        if has_split_table(mp) {
            res += shared_keys_usable_size(dict_keys_of(mp)) * 8;
        }

        if dk_refcnt(dict_keys_of(mp)) == 1 {
            res += i64(_PyDict_KeysSize(dict_keys_of(mp)));
        }
        return res;
    }  def _PyDict_SizeOf(mp: ptr[PyObject]) -> i64 {
        return _PyDict_SizeOf_LockHeld(mp);
    }  def _PyDict_KeysSize(k: ptr[u8]) -> u64 {
        es = KEY_ENTRY_SIZE if dk_kind(k) == DICT_KEYS_GENERAL else UNICODE_ENTRY_SIZE;
        return u64(
            PyDictKeysObject_INDICES
                + (1 << dk_log2_index_bytes(k))
                + usable_fraction(dk_size(k)) * es
        );
    }  def PyDict_Keys(dict: ptr[PyObject]) -> ptr[PyObject] {
        return dict_to_list(dict, i32(0));
    }  def PyDict_Values(dict: ptr[PyObject]) -> ptr[PyObject] {
        return dict_to_list(dict, i32(1));
    }  def PyDict_Items(dict: ptr[PyObject]) -> ptr[PyObject] {
        return dict_to_list(dict, i32(2));
    }  def PyDict_MergeFromSeq2(
        d: ptr[PyObject], seq2: ptr[PyObject], override_mode: i32
    ) -> i32 {
        return merge_from_seq2(d, seq2, override_mode);
    }  def PyDict_Update(a: ptr[PyObject], b: ptr[PyObject]) -> i32 {
        return dict_merge(a, b, i32(1));
    }  def PyDict_Merge(a: ptr[PyObject], b: ptr[PyObject], override_mode: i32) -> i32 {
        return dict_merge(a, b, i32(1) if override_mode != 0 else i32(0));
    }  def _PyDict_MergeEx(
        a: ptr[PyObject], b: ptr[PyObject], override_mode: i32
    ) -> i32 {
        return dict_merge(a, b, override_mode);
    }  def PyDict_Copy(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o or not dict_check(o) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return copy_lock_held(o);
    }  def PyDict_Size(mp: ptr[PyObject]) -> i64 {
        if not mp or not dict_check(mp) {
            PyErr_BadInternalCall();
            return -1;
        }
        return dict_used(mp);
    }  def PyDict_SetDefaultRef(
        d: ptr[PyObject],
        key: ptr[PyObject],
        default_value: ptr[PyObject],
        result: ptr[ptr[PyObject]]
    ) -> i32 {
        (status, value) = setdefault_ref(d, key, default_value, bool(result));
        store_result(result, value);
        return status;
    }  def PyDict_SetDefault(
        d: ptr[PyObject], key: ptr[PyObject], defaultobj: ptr[PyObject]
    ) -> ptr[PyObject] {
        (status, value) = setdefault_ref(d, key, defaultobj, False);
        return value;
    }  def PyDict_Contains(op: ptr[PyObject], key: ptr[PyObject]) -> i32 {
        hash = hash_fast(key);
        if hash == -1 {
            dict_unhashable_type(key);
            return i32(-1);
        }
        return _PyDict_Contains_KnownHash(op, key, hash);
    }  def PyDict_ContainsString(op: ptr[PyObject], key: ptr[u8]) -> i32 {
        key_obj = PyUnicode_FromString(key);
        if not key_obj {
            return i32(-1);
        }
        res = PyDict_Contains(op, key_obj);
        object_decref(key_obj);
        return res;
    }  def _PyDict_Contains_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64
    ) -> i32 {
        (ix, value) = dict_lookup(op, key, hash);
        if ix == DKIX_ERROR {
            return i32(-1);
        }
        return i32(1) if ix != DKIX_EMPTY and value else i32(0);
    }  def _PyDict_ContainsId(op: ptr[PyObject], key: ptr) -> i32 {
        kv = _PyUnicode_FromId(key);
        if not kv {
            return i32(-1);
        }
        return PyDict_Contains(op, kv);
    }  def PyDict_GetItemString(v: ptr[PyObject], key: ptr[u8]) -> ptr[PyObject] {
        kv = PyUnicode_FromString(key);
        if not kv {
            PyErr_FormatUnraisable(
                "Exception ignored in PyDict_GetItemString(); consider using PyDict_GetItemStringRef()"
            );
            return NULL;
        }

        rv = dict_getitem(
            v,
            kv,
            "Exception ignored in PyDict_GetItemString(); consider using PyDict_GetItemStringRef()"
        );
        object_decref(kv);
        return rv;
    }  def PyDict_GetItemStringRef(
        v: ptr[PyObject], key: ptr[u8], result: ptr[ptr[PyObject]]
    ) -> i32 {
        key_obj = PyUnicode_FromString(key);
        if not key_obj {
            result.view(1)[0] = NULL;
            return i32(-1);
        }
        res = PyDict_GetItemRef(v, key_obj, result);
        object_decref(key_obj);
        return res;
    }  def _PyDict_SetItemId(v: ptr[PyObject], key: ptr, item: ptr[PyObject]) -> i32 {
        kv = _PyUnicode_FromId(key);
        if not kv {
            return i32(-1);
        }
        return PyDict_SetItem(v, kv, item);
    }  def PyDict_SetItemString(
        v: ptr[PyObject], key: ptr[u8], item: ptr[PyObject]
    ) -> i32 {
        kv = PyUnicode_FromString(key);
        if not kv {
            return i32(-1);
        }
        _PyUnicode_InternImmortal(ptr(current_interp()), &mut kv);
        err = PyDict_SetItem(v, kv, item);
        object_decref(kv);
        return err;
    }  def _PyDict_DelItemId(v: ptr[PyObject], key: ptr) -> i32 {
        kv = _PyUnicode_FromId(key);
        if not kv {
            return i32(-1);
        }
        return PyDict_DelItem(v, kv);
    }  def PyDict_DelItemString(v: ptr[PyObject], key: ptr[u8]) -> i32 {
        kv = PyUnicode_FromString(key);
        if not kv {
            return i32(-1);
        }
        err = PyDict_DelItem(v, kv);
        object_decref(kv);
        return err;
    }
}

def iter_of(op: ptr[PyObject]) -> ptr[dictiterobject];

def iter_dict(op: ptr[PyObject]) -> ptr[PyObject];

def is_iter_type(op: ptr[PyObject], type: ptr[PyTypeObject]) -> bool;

def dictiter_new(dict: ptr[PyObject], itertype: ptr[PyTypeObject]) -> ptr[PyObject];

def dictiter_dealloc(self: ptr[PyObject]);

def dictiter_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def dictiter_len(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def iter_exhaust(self: ptr[PyObject], d: ptr[PyObject]);

def iter_step(self: ptr[PyObject]) -> tuple[ptr[PyObject], ptr[PyObject]];

def dictiter_iternextkey(self: ptr[PyObject]) -> ptr[PyObject];

def dictiter_iternextvalue(self: ptr[PyObject]) -> ptr[PyObject];

def item_result(
    self: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def dictiter_iternextitem(self: ptr[PyObject]) -> ptr[PyObject];

def dictreviter_iternext(self: ptr[PyObject]) -> ptr[PyObject];

def dict___reversed__(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dictiter_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def view_dict(op: ptr[PyObject]) -> ptr[PyObject];

def is_keys_view(op: ptr[PyObject]) -> bool;

def is_items_view(op: ptr[PyObject]) -> bool;

def is_set_view(op: ptr[PyObject]) -> bool;

def anyset_check(op: ptr[PyObject]) -> bool;

def anyset_check_exact(op: ptr[PyObject]) -> bool;

def dictview_dealloc(self: ptr[PyObject]);

def dictview_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def dictview_len(self: ptr[PyObject]) -> i64;

def dictview_mapping(view: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def all_contained_in(self: ptr[PyObject], other: ptr[PyObject]) -> i32;

def dictview_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject];

def dictview_repr(self: ptr[PyObject]) -> ptr[PyObject];

def view_iter(self: ptr[PyObject], itertype: ptr[PyTypeObject]) -> ptr[PyObject];

def dictkeys_iter(self: ptr[PyObject]) -> ptr[PyObject];

def dictitems_iter(self: ptr[PyObject]) -> ptr[PyObject];

def dictvalues_iter(self: ptr[PyObject]) -> ptr[PyObject];

def dictkeys_reversed(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dictitems_reversed(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dictvalues_reversed(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dictkeys_contains(self: ptr[PyObject], ob: ptr[PyObject]) -> i32;

def dictitems_contains(self: ptr[PyObject], ob: ptr[PyObject]) -> i32;

def dictviews_to_set(self: ptr[PyObject]) -> ptr[PyObject];

def set_method_result(
    self: ptr[PyObject], name: str, other: ptr[PyObject]
) -> ptr[PyObject];

def dictviews_sub(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def dictviews_or(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def dictitems_xor(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def dictviews_xor(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def dictviews_isdisjoint(
    self_in: ptr[PyObject], other_in: ptr[PyObject]
) -> ptr[PyObject];

def dict_keys(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dict_items(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dict_values(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def dict_copy(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyDictView_New(dict: ptr[PyObject], type: ptr[PyTypeObject]) -> ptr[PyObject] {
        if not dict {
            PyErr_BadInternalCall();
            return NULL;
        }
        if not dict_check(dict) {
            PyErr_Format(
                PyExc_TypeError,
                "%s() requires a dict argument, not '%s'",
                type.view(1)[0].tp_name,
                object_type(dict).view(1)[0].tp_name
            );
            return NULL;
        }
        dv = _PyObject_GC_New(ptr[PyObject](type));
        if not dv {
            return NULL;
        }
        ptr[_PyDictViewObject](dv).view(1)[0].dv_dict = ptr[PyDictObject](
            object_new_ref(dict)
        );
        object_gc_track(dv);
        return dv;
    }  def _PyDictView_Intersect(
        self_in: ptr[PyObject], other_in: ptr[PyObject]
    ) -> ptr[PyObject] {
        self = self_in;
        other = other_in;
        if not is_set_view(self) {
            tmp = other;
            other = self;
            self = tmp;
        }
        len_self = dictview_len(self);

        if object_is_type(other, ptr[PyTypeObject](addressof(PySet_Type)))
            and len_self <= PyObject_Size(other) {
            name = PyUnicode_InternFromString(ptr[u8]("intersection"));
            if not name {
                return NULL;
            }
            res = PyObject_CallMethodObjArgs(other, name, self, ptr());
            object_decref(name);
            return res;
        }

        if is_set_view(other) and dictview_len(other) > len_self {
            tmp = other;
            other = self;
            self = tmp;
        }
        result = PySet_New(NULL);
        if not result {
            return NULL;
        }
        it = PyObject_GetIter(other);
        if not it {
            object_decref(result);
            return NULL;
        }
        keys = is_keys_view(self);
        while True {
            key = PyIter_Next(it);
            if not key {
                break;
            }
            rv = dictkeys_contains(self, key)
                if keys
                else dictitems_contains(self, key);
            if rv < 0 or (rv > 0 and PySet_Add(result, key) != 0) {
                object_decref(key);
                object_decref(it);
                object_decref(result);
                return NULL;
            }
            object_decref(key);
        }
        object_decref(it);
        if PyErr_Occurred() {
            object_decref(result);
            return NULL;
        }
        return result;
    }
}

def inline_values(ob: ptr[PyObject]) -> ptr[u8];

def managed_dict_slot(ob: ptr[PyObject]) -> ptr[ptr[PyObject]];

def managed_dict(ob: ptr[PyObject]) -> ptr[PyObject];

def set_managed_dict(ob: ptr[PyObject], dict: ptr[PyObject]);

def cached_keys(tp: ptr[PyTypeObject]) -> ptr[u8];

def computed_dict_pointer(ob: ptr[PyObject]) -> ptr[ptr[PyObject]];

def make_dict_from_instance_attributes(k: ptr[u8], values: ptr[u8]) -> ptr[PyObject];

def set_item_or_delete(
    dict: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def store_instance_attr(
    ob: ptr[PyObject], values: ptr[u8], name: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def store_instance_attr_dict(
    ob: ptr[PyObject], dict: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def clear_inline_values(values: ptr[u8]);

def set_dict_inline_values(ob: ptr[PyObject], new_dict: ptr[PyObject]);

def detach_dict_from_object(mp: ptr[PyObject], ob: ptr[PyObject]) -> i32;

def ensure_managed_dict(ob: ptr[PyObject]) -> ptr[PyObject];

def ensure_nonmanaged_dict(
    ob: ptr[PyObject], dictptr: ptr[ptr[PyObject]]
) -> ptr[PyObject];

def watcher_slot(watcher_id: i64) -> ptr[int];

def validate_watcher_id(watcher_id: i32) -> i32;

def dict_event_name(event: i32) -> str;

import from c {
    def _PyDict_NewKeysForClass(cls: ptr[PyTypeObject]) -> ptr[u8] {
        k = new_keys_object(NEXT_LOG2_SHARED_KEYS_MAX_SIZE, True);
        if not k {
            PyErr_Clear();
        } else {
            set_dk_usable(k, SHARED_KEYS_MAX_SIZE);
            set_dk_kind(k, DICT_KEYS_SPLIT);
        }
        tp_dict = ptr[PyObject](cls.view(1)[0].tp_dict);
        if tp_dict {
            name = PyUnicode_InternFromString(ptr[u8]("__static_attributes__"));
            attrs = PyDict_GetItem(tp_dict, name) if name else NULL;
            object_xdecref(name);
            if attrs
                and type_has_feature(object_type(attrs), Py_TPFLAGS_TUPLE_SUBCLASS) {
                for i in range(object_size(attrs)) {
                    key = tuple_get_item(attrs, i);
                    if unicode_check_exact(key) {
                        hash = unicode_get_hash(key);
                        if hash != -1
                            and insert_split_key(k, key, hash) == DKIX_EMPTY {
                            break;
                        }
                    }
                }
            }
        }
        return k;
    }  def _PyObject_InitInlineValues(ob: ptr[PyObject], tp: ptr[PyTypeObject]) {
        k = cached_keys(tp);
        if dk_usable(k) > 1 {
            set_dk_usable(k, dk_usable(k) - 1);
        }
        size = shared_keys_usable_size(k);
        values = inline_values(ob);
        values.view(1)[0] = u8(size);
        (values + 1).view(1)[0] = u8(0);
        (values + 2).view(1)[0] = u8(1);
        (values + 3).view(1)[0] = u8(1);
        for i in range(size) {
            set_value_at(values, i, NULL);
        }
        set_managed_dict(ob, NULL);
    }  def _PyObject_MaterializeManagedDict_LockHeld(
        ob: ptr[PyObject]
    ) -> ptr[PyObject] {
        values = inline_values(ob);
        dict = make_dict_from_instance_attributes(cached_keys(object_type(ob)), values)
            if values_valid(values)
            else PyDict_New();
        set_managed_dict(ob, dict);
        return dict;
    }  def _PyObject_MaterializeManagedDict(ob: ptr[PyObject]) -> ptr[PyObject] {
        dict = managed_dict(ob);
        if dict {
            return dict;
        }
        return _PyObject_MaterializeManagedDict_LockHeld(ob);
    }  def _PyDict_SetItem_LockHeld(
        dict: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
    ) -> i32 {
        if not value {
            hash = hash_fast(name);
            if hash == -1 {
                dict_unhashable_type(name);
                return i32(-1);
            }
            return _PyDict_DelItem_KnownHash_LockHeld(dict, name, hash);
        }
        return setitem_lock_held(dict, name, value);
    }  def _PyObject_StoreInstanceAttribute(
        ob: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
    ) -> i32 {
        values = inline_values(ob);
        if not values_valid(values) {
            dict = managed_dict(ob);
            if not dict {
                dict = PyObject_GenericGetDict(ob, ptr());
                if not dict {
                    return i32(-1);
                }
                res = store_instance_attr_dict(ob, dict, name, value);
                object_decref(dict);
                return res;
            }
            return store_instance_attr_dict(ob, dict, name, value);
        }
        return store_instance_attr(ob, values, name, value);
    }  def _PyObject_TryGetInstanceAttribute(
        ob: ptr[PyObject], name: ptr[PyObject], attr: ptr[ptr[PyObject]]
    ) -> bool {
        values = inline_values(ob);
        if not values_valid(values) {
            return False;
        }
        ix = _PyDictKeys_StringLookupSplit(cached_keys(object_type(ob)), name);
        if ix == DKIX_EMPTY {
            attr.view(1)[0] = NULL;
            return True;
        }
        attr.view(1)[0] = object_xnew_ref(value_at(values, ix));
        return True;
    }  def _PyObject_IsInstanceDictEmpty(ob: ptr[PyObject]) -> i32 {
        tp = object_type(ob);
        if tp.view(1)[0].tp_dictoffset == 0 {
            return i32(1);
        }
        dict: ptr[PyObject] = NULL;
        if type_has_feature(tp, Py_TPFLAGS_INLINE_VALUES) {
            values = inline_values(ob);
            if values_valid(values) {
                k = cached_keys(tp);
                for i in range(dk_nentries(k)) {
                    if value_at(values, i) {
                        return i32(0);
                    }
                }
                return i32(1);
            }
            dict = managed_dict(ob);
        } elif type_has_feature(tp, Py_TPFLAGS_MANAGED_DICT) {
            dict = managed_dict(ob);
        } else {
            dict = computed_dict_pointer(ob).view(1)[0];
        }
        if not dict {
            return i32(1);
        }
        return i32(1) if dict_used(dict) == 0 else i32(0);
    }  def PyObject_VisitManagedDict(ob: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
        tp = object_type(ob);
        if not type_has_feature(tp, Py_TPFLAGS_MANAGED_DICT) {
            return i32(0);
        }
        dict = managed_dict(ob);
        if dict {
            return visit_reference(dict, visitor, arg);
        }
        if type_has_feature(tp, Py_TPFLAGS_INLINE_VALUES) {
            values = inline_values(ob);
            if values_valid(values) {
                for i in range(values_capacity(values)) {
                    status = visit_reference(value_at(values, i), visitor, arg);
                    if status != 0 {
                        return status;
                    }
                }
            }
        }
        return i32(0);
    }  def _PyObject_SetManagedDict(ob: ptr[PyObject], new_dict: ptr[PyObject]) -> i32 {
        if type_has_feature(object_type(ob), Py_TPFLAGS_INLINE_VALUES) {
            dict = managed_dict(ob);
            if not dict {
                set_dict_inline_values(ob, new_dict);
                return i32(0);
            }
            if detach_dict_from_object(dict, ob) == 0 {
                set_managed_dict(ob, object_xnew_ref(new_dict));
                object_decref(dict);
                return i32(0);
            }
            return i32(-1);
        }
        dict = managed_dict(ob);
        set_managed_dict(ob, object_xnew_ref(new_dict));
        object_xdecref(dict);
        return i32(0);
    }  def PyObject_ClearManagedDict(ob: ptr[PyObject]) {
        if type_has_feature(object_type(ob), Py_TPFLAGS_INLINE_VALUES) {
            dict = managed_dict(ob);
            if not dict {
                clear_inline_values(inline_values(ob));
                return;
            }
            if dict_values_of(dict) == inline_values(ob)
                and detach_dict_from_object(dict, ob) != 0 {
                PyErr_FormatUnraisable(
                    "Exception ignored while clearing an object managed dict"
                );
                oldkeys = dict_keys_of(dict);
                set_dict_keys(dict, empty_keys());
                set_dict_values(dict, ptr[u8]());
                dictkeys_decref(oldkeys);
                set_dict_used(dict, 0);
                clear_inline_values(inline_values(ob));
            }
        }
        dict = managed_dict(ob);
        set_managed_dict(ob, NULL);
        object_xdecref(dict);
    }  def _PyDict_DetachFromObject(mp: ptr[PyObject], ob: ptr[PyObject]) -> i32 {
        return detach_dict_from_object(mp, ob);
    }  def PyObject_GenericGetDict(ob: ptr[PyObject], context: ptr) -> ptr[PyObject] {
        if type_has_feature(object_type(ob), Py_TPFLAGS_MANAGED_DICT) {
            return object_xnew_ref(ensure_managed_dict(ob));
        }
        dictptr = computed_dict_pointer(ob);
        if not dictptr {
            PyErr_SetString(PyExc_AttributeError, "This object has no __dict__");
            return NULL;
        }
        return object_xnew_ref(ensure_nonmanaged_dict(ob, dictptr));
    }  def _PyObjectDict_SetItem(
        tp: ptr[PyTypeObject],
        ob: ptr[PyObject],
        dictptr: ptr[ptr[PyObject]],
        key: ptr[PyObject],
        value: ptr[PyObject]
    ) -> i32 {
        dict = ensure_nonmanaged_dict(ob, dictptr);
        if not dict {
            return i32(-1);
        }
        return _PyDict_SetItem_LockHeld(dict, key, value);
    }  def _PyDictKeys_DecRef(k: ptr[u8]) {
        dictkeys_decref(k);
    }  def _PyDictKeys_GetVersionForCurrentState(interp: ptr, k: ptr[u8]) -> u32 {
        version = dk_version(k);
        if version != u32(0) {
            return version;
        }

        slot = ptr[u32](ptr[u8](interp) + PyInterpreterState_DICT_NEXT_KEYS_VERSION);
        version = slot.view(1)[0];
        if version != u32(0) {
            slot.view(1)[0] = version + u32(1);
        }
        set_dk_version(k, version);
        return version;
    }  def _PyDict_GetKeysVersionForCurrentState(
        interp: ptr, dict: ptr[PyObject]
    ) -> u32 {
        return _PyDictKeys_GetVersionForCurrentState(interp, dict_keys_of(dict));
    }  def PyDict_Watch(watcher_id: i32, dict: ptr[PyObject]) -> i32 {
        if not dict_check(dict) {
            PyErr_SetString(PyExc_ValueError, "Cannot watch non-dictionary");
            return i32(-1);
        }
        if validate_watcher_id(watcher_id) != 0 {
            return i32(-1);
        }
        d = dict_of(dict);
        d.view(1)[0]._ma_watcher_tag = d.view(1)[0]._ma_watcher_tag
            | (u64(1) << u64(watcher_id));
        return i32(0);
    }  def PyDict_Unwatch(watcher_id: i32, dict: ptr[PyObject]) -> i32 {
        if not dict_check(dict) {
            PyErr_SetString(PyExc_ValueError, "Cannot watch non-dictionary");
            return i32(-1);
        }
        if validate_watcher_id(watcher_id) != 0 {
            return i32(-1);
        }
        d = dict_of(dict);
        d.view(1)[0]._ma_watcher_tag = d.view(1)[0]._ma_watcher_tag
            & ~(u64(1) << u64(watcher_id));
        return i32(0);
    }  def PyDict_AddWatcher(callback: ptr) -> i32 {
        for i in range(2, DICT_MAX_WATCHERS) {
            slot = watcher_slot(i);
            if slot.view(1)[0] == 0 {
                slot.view(1)[0] = int(callback);
                return i32(i);
            }
        }
        PyErr_SetString(PyExc_RuntimeError, "no more dict watcher IDs available");
        return i32(-1);
    }  def PyDict_ClearWatcher(watcher_id: i32) -> i32 {
        if validate_watcher_id(watcher_id) != 0 {
            return i32(-1);
        }
        watcher_slot(i64(watcher_id)).view(1)[0] = 0;
        return i32(0);
    }  def _PyDict_SendEvent(
        watcher_bits_in: i32,
        event: i32,
        mp: ptr[PyObject],
        key: ptr[PyObject],
        value: ptr[PyObject]
    ) {
        watcher_bits = watcher_bits_in;
        calls = ptr[DictCall](
            __thread_local_block("jac_object_model_dict_call_slot", 32)
        );
        for i in range(DICT_MAX_WATCHERS) {
            if watcher_bits & i32(1) != 0 {
                cb = watcher_slot(i).view(1)[0];
                if cb != 0 {
                    calls.view(1)[0].watcher = cb;
                    if calls.view(1)[0].watcher(event, mp, key, value) < 0 {
                        PyErr_FormatUnraisable(
                            "Exception ignored in %s watcher callback for <dict at %p>",
                            dict_event_name(event),
                            ptr(mp)
                        );
                    }
                }
            }
            watcher_bits = watcher_bits >> i32(1);
        }
    }
}

import from c {
    glob:priv dict_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=dict_length,
             mp_subscript=dict_subscript,
             mp_ass_subscript=dict_ass_sub
         ),
         dict_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_contains=PyDict_Contains
         ),
         dict_as_number: PyNumberMethods = PyNumberMethods(
             nb_or=dict_or, nb_inplace_or=dict_ior
         ),
         mapp_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__contains__"),
                 ml_meth=ptr(dict___contains__),
                 ml_flags=METH_O | METH_COEXIST,
                 ml_doc=ptr[u8](
                     "__contains__($self, key, /)\n--\n\n"
                     "True if the dictionary has the specified key, else False."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__getitem__"),
                 ml_meth=ptr(dict_subscript),
                 ml_flags=METH_O | METH_COEXIST,
                 ml_doc=ptr[u8]("__getitem__($self, key, /)\n--\n\nReturn self[key].")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(dict___sizeof__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__sizeof__($self, /)\n--\n\n"
                     "Return the size of the dict in memory, in bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get"),
                 ml_meth=ptr(dict_get),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "get($self, key, default=None, /)\n--\n\n"
                     "Return the value for key if key is in the dictionary, else default."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("setdefault"),
                 ml_meth=ptr(dict_setdefault),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "setdefault($self, key, default=None, /)\n--\n\n"
                     "Insert key with a value of default if key is not in the dictionary.\n\n"
                     "Return the value for key if key is in the dictionary, else default."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("pop"),
                 ml_meth=ptr(dict_pop),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "pop($self, key, default=<unrepresentable>, /)\n--\n\n"
                     "D.pop(k[,d]) -> v, remove specified key and return the corresponding value.\n\n"
                     "If the key is not found, return the default if given; otherwise,\n"
                     "raise a KeyError."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("popitem"),
                 ml_meth=ptr(dict_popitem),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "popitem($self, /)\n--\n\n"
                     "Remove and return a (key, value) pair as a 2-tuple.\n\n"
                     "Pairs are returned in LIFO (last-in, first-out) order.\n"
                     "Raises KeyError if the dict is empty."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("keys"),
                 ml_meth=ptr(dict_keys),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "keys($self, /)\n--\n\n"
                     "Return a set-like object providing a view on the dict's keys."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("items"),
                 ml_meth=ptr(dict_items),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "items($self, /)\n--\n\n"
                     "Return a set-like object providing a view on the dict's items."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("values"),
                 ml_meth=ptr(dict_values),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "values($self, /)\n--\n\n"
                     "Return an object providing a view on the dict's values."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("update"),
                 ml_meth=ptr(dict_update),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "D.update([E, ]**F) -> None.  Update D from mapping/iterable E and F.\n"
                     "If E is present and has a .keys() method, then does:  for k in E.keys(): D[k] = E[k]\n"
                     "If E is present and lacks a .keys() method, then does:  for k, v in E: D[k] = v\n"
                     "In either case, this is followed by: for k in F:  D[k] = F[k]"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("fromkeys"),
                 ml_meth=ptr(dict_fromkeys),
                 ml_flags=METH_FASTCALL | METH_CLASS,
                 ml_doc=ptr[u8](
                     "fromkeys($type, iterable, value=None, /)\n--\n\n"
                     "Create a new dictionary with keys from iterable and values set to value."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("clear"),
                 ml_meth=ptr(dict_clear),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "clear($self, /)\n--\n\nRemove all items from the dict."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy"),
                 ml_meth=ptr(dict_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "copy($self, /)\n--\n\nReturn a shallow copy of the dict."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(dict___reversed__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__reversed__($self, /)\n--\n\n"
                     "Return a reverse iterator over the dict keys."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "dicts are generic over two types, signifying (respectively) the types of their keys and values"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         dictiter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(dictiter_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(dictiter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         dictview_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("mapping"),
                 get=dictview_mapping,
                 doc=ptr[u8]("dictionary that this view refers to")
             ),
             PyGetSetDef()
         ],
         dictviews_as_number: PyNumberMethods = PyNumberMethods(
             nb_subtract=dictviews_sub,
             nb_and=_PyDictView_Intersect,
             nb_xor=dictviews_xor,
             nb_or=dictviews_or
         ),
         dictkeys_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_length=dictview_len, sq_contains=dictkeys_contains
         ),
         dictitems_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_length=dictview_len, sq_contains=dictitems_contains
         ),
         dictvalues_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_length=dictview_len
         ),
         dictkeys_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("isdisjoint"),
                 ml_meth=ptr(dictviews_isdisjoint),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Return True if the view and the given iterable have a null intersection."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(dictkeys_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return a reverse iterator over the dict keys.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         dictitems_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("isdisjoint"),
                 ml_meth=ptr(dictviews_isdisjoint),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Return True if the view and the given iterable have a null intersection."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(dictitems_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return a reverse iterator over the dict items.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         dictvalues_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(dictvalues_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return a reverse iterator over the dict values.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyDict_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict"),
             tp_basicsize=PyDictObject_SIZE,
             tp_dealloc=dict_dealloc,
             tp_repr=dict_repr,
             tp_as_number=addressof(dict_as_number),
             tp_as_sequence=addressof(dict_as_sequence),
             tp_as_mapping=addressof(dict_as_mapping),
             tp_hash=PyObject_HashNotImplemented,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_DICT_SUBCLASS
                 | _Py_TPFLAGS_MATCH_SELF
                 | Py_TPFLAGS_MAPPING,
             tp_doc=ptr[u8](
                 "dict() -> new empty dictionary\n"
                 "dict(mapping) -> new dictionary initialized from a mapping object's\n"
                 "    (key, value) pairs\n"
                 "dict(iterable) -> new dictionary initialized as if via:\n"
                 "    d = {}\n"
                 "    for k, v in iterable:\n"
                 "        d[k] = v\n"
                 "dict(**kwargs) -> new dictionary initialized with the name=value pairs\n"
                 "    in the keyword argument list.  For example:  dict(one=1, two=2)"
             ),
             tp_traverse=dict_traverse,
             tp_clear=dict_tp_clear,
             tp_richcompare=dict_richcompare,
             tp_iter=dict_iter,
             tp_methods=addressof(mapp_methods),
             tp_init=dict_init,
             tp_alloc=_PyType_AllocNoTrack,
             tp_new=dict_new,
             tp_free=PyObject_GC_Del,
             tp_vectorcall=dict_vectorcall,
             tp_version_tag=_Py_TYPE_VERSION_DICT
         ),
         PyDictIterKey_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict_keyiterator"),
             tp_basicsize=dictiterobject_SIZE,
             tp_dealloc=dictiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=dictiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=dictiter_iternextkey,
             tp_methods=addressof(dictiter_methods)
         ),
         PyDictIterValue_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict_valueiterator"),
             tp_basicsize=dictiterobject_SIZE,
             tp_dealloc=dictiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=dictiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=dictiter_iternextvalue,
             tp_methods=addressof(dictiter_methods)
         ),
         PyDictIterItem_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict_itemiterator"),
             tp_basicsize=dictiterobject_SIZE,
             tp_dealloc=dictiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=dictiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=dictiter_iternextitem,
             tp_methods=addressof(dictiter_methods)
         ),
         PyDictRevIterKey_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict_reversekeyiterator"),
             tp_basicsize=dictiterobject_SIZE,
             tp_dealloc=dictiter_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=dictiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=dictreviter_iternext,
             tp_methods=addressof(dictiter_methods)
         ),
         PyDictRevIterItem_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict_reverseitemiterator"),
             tp_basicsize=dictiterobject_SIZE,
             tp_dealloc=dictiter_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=dictiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=dictreviter_iternext,
             tp_methods=addressof(dictiter_methods)
         ),
         PyDictRevIterValue_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict_reversevalueiterator"),
             tp_basicsize=dictiterobject_SIZE,
             tp_dealloc=dictiter_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=dictiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=dictreviter_iternext,
             tp_methods=addressof(dictiter_methods)
         ),
         PyDictKeys_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict_keys"),
             tp_basicsize=_PyDictViewObject_SIZE,
             tp_dealloc=dictview_dealloc,
             tp_repr=dictview_repr,
             tp_as_number=addressof(dictviews_as_number),
             tp_as_sequence=addressof(dictkeys_as_sequence),
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=dictview_traverse,
             tp_richcompare=dictview_richcompare,
             tp_iter=dictkeys_iter,
             tp_methods=addressof(dictkeys_methods),
             tp_getset=addressof(dictview_getset)
         ),
         PyDictItems_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict_items"),
             tp_basicsize=_PyDictViewObject_SIZE,
             tp_dealloc=dictview_dealloc,
             tp_repr=dictview_repr,
             tp_as_number=addressof(dictviews_as_number),
             tp_as_sequence=addressof(dictitems_as_sequence),
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=dictview_traverse,
             tp_richcompare=dictview_richcompare,
             tp_iter=dictitems_iter,
             tp_methods=addressof(dictitems_methods),
             tp_getset=addressof(dictview_getset)
         ),
         PyDictValues_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("dict_values"),
             tp_basicsize=_PyDictViewObject_SIZE,
             tp_dealloc=dictview_dealloc,
             tp_repr=dictview_repr,
             tp_as_sequence=addressof(dictvalues_as_sequence),
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=dictview_traverse,
             tp_iter=dictvalues_iter,
             tp_methods=addressof(dictvalues_methods),
             tp_getset=addressof(dictview_getset)
         );
}

impl interned_name(which: i32) -> ptr[PyObject] {
    if which == 0 {
        if not missing_key {
            missing_key = PyUnicode_InternFromString(ptr[u8]("__missing__"));
        }
        return missing_key;
    }
    if not keys_key {
        keys_key = PyUnicode_InternFromString(ptr[u8]("keys"));
    }
    return keys_key;
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl object_xincref(op: ptr[PyObject]) {
    if op {
        object_incref(op);
    }
}

impl freelist_pop_mem(offset: i64) -> ptr {
    fl = freelist(offset);
    block = fl.view(1)[0].freelist;
    if block {
        fl.view(1)[0].freelist = ptr[ptr](block).view(1)[0];
        fl.view(1)[0].size -= 1;
    }
    return block;
}

impl freelist_push_mem(offset: i64, block: ptr, maxsize: i64) -> bool {
    fl = freelist(offset);
    size = fl.view(1)[0].size;
    if size < maxsize and size >= 0 {
        ptr[ptr](block).view(1)[0] = fl.view(1)[0].freelist;
        fl.view(1)[0].freelist = block;
        fl.view(1)[0].size = size + 1;
        return True;
    }
    return False;
}

impl jacpy_memory_fill(target: ptr, value: i32, size: i64) {
    memset(target, value, u64(size));
}

impl object_is_immortal(op: ptr[PyObject]) -> bool {
    return (ptr[_object](op).view(1)[0].ob_refcnt_full & i64(0x80000000)) != 0;
}

impl stackref_new(op: ptr[PyObject]) -> u64 {
    if not op {
        return STACKREF_NULL;
    }
    if object_is_immortal(op) {
        return u64(int(op)) | u64(1);
    }
    object_incref(op);
    return u64(int(op));
}

impl stackref_steal(op: ptr[PyObject]) -> u64 {
    tag = u64(1) if object_is_immortal(op) else u64(0);
    return u64(int(op)) | tag;
}

impl stackref_close(bits: u64) {
    if (bits & u64(1)) == u64(0) {
        object_decref(ptr[PyObject](i64.wrap(bits)));
    }
}

impl stackref_clear(slot: ptr[u64]) {
    old = slot.view(1)[0];
    slot.view(1)[0] = STACKREF_NULL;
    stackref_close(old);
}

impl keys_i64(k: ptr[u8], offset: i64) -> i64 {
    return ptr[i64](k + offset).view(1)[0];
}

impl set_keys_i64(k: ptr[u8], offset: i64, value: i64) {
    ptr[i64](k + offset).view(1)[0] = value;
}

impl dk_refcnt(k: ptr[u8]) -> i64 {
    return keys_i64(k, PyDictKeysObject_REFCNT);
}

impl dk_log2_size(k: ptr[u8]) -> i64 {
    return i64((k + PyDictKeysObject_LOG2_SIZE).view(1)[0]);
}

impl dk_log2_index_bytes(k: ptr[u8]) -> i64 {
    return i64((k + PyDictKeysObject_LOG2_INDEX_BYTES).view(1)[0]);
}

impl dk_kind(k: ptr[u8]) -> i64 {
    return i64((k + PyDictKeysObject_KIND).view(1)[0]);
}

impl set_dk_kind(k: ptr[u8], kind: i64) {
    (k + PyDictKeysObject_KIND).view(1)[0] = u8(kind);
}

impl dk_version(k: ptr[u8]) -> u32 {
    return ptr[u32](k + PyDictKeysObject_VERSION).view(1)[0];
}

impl set_dk_version(k: ptr[u8], version: u32) {
    ptr[u32](k + PyDictKeysObject_VERSION).view(1)[0] = version;
}

impl dk_usable(k: ptr[u8]) -> i64 {
    return keys_i64(k, PyDictKeysObject_USABLE);
}

impl set_dk_usable(k: ptr[u8], usable: i64) {
    set_keys_i64(k, PyDictKeysObject_USABLE, usable);
}

impl dk_nentries(k: ptr[u8]) -> i64 {
    return keys_i64(k, PyDictKeysObject_NENTRIES);
}

impl set_dk_nentries(k: ptr[u8], nentries: i64) {
    set_keys_i64(k, PyDictKeysObject_NENTRIES, nentries);
}

impl dk_size(k: ptr[u8]) -> i64 {
    return 1 << dk_log2_size(k);
}

impl dk_is_unicode(k: ptr[u8]) -> bool {
    return dk_kind(k) != DICT_KEYS_GENERAL;
}

impl dk_entries(k: ptr[u8]) -> ptr[u8] {
    return k + PyDictKeysObject_INDICES + (1 << dk_log2_index_bytes(k));
}

impl key_entry(k: ptr[u8], ix: i64) -> ptr[i64] {
    return ptr[i64](dk_entries(k) + ix * KEY_ENTRY_SIZE);
}

impl unicode_entry(k: ptr[u8], ix: i64) -> ptr[i64] {
    return ptr[i64](dk_entries(k) + ix * UNICODE_ENTRY_SIZE);
}

impl entry_key(k: ptr[u8], ix: i64) -> ptr[PyObject] {
    if dk_is_unicode(k) {
        return ptr[PyObject](unicode_entry(k, ix).view(1)[0]);
    }
    return ptr[PyObject](key_entry(k, ix).view(2)[1]);
}

impl entry_value(k: ptr[u8], ix: i64) -> ptr[PyObject] {
    if dk_is_unicode(k) {
        return ptr[PyObject](unicode_entry(k, ix).view(2)[1]);
    }
    return ptr[PyObject](key_entry(k, ix).view(3)[2]);
}

impl set_entry_key(k: ptr[u8], ix: i64, key: ptr[PyObject]) {
    if dk_is_unicode(k) {
        unicode_entry(k, ix).view(1)[0] = int(key);
    } else {
        key_entry(k, ix).view(2)[1] = int(key);
    }
}

impl set_entry_value(k: ptr[u8], ix: i64, value: ptr[PyObject]) {
    if dk_is_unicode(k) {
        unicode_entry(k, ix).view(2)[1] = int(value);
    } else {
        key_entry(k, ix).view(3)[2] = int(value);
    }
}

impl entry_hash(k: ptr[u8], ix: i64) -> i64 {
    if dk_is_unicode(k) {
        return unicode_get_hash(entry_key(k, ix));
    }
    return key_entry(k, ix).view(1)[0];
}

impl set_entry_hash(k: ptr[u8], ix: i64, hash: i64) {
    key_entry(k, ix).view(1)[0] = hash;
}

impl dictkeys_get_index(k: ptr[u8], i: i64) -> i64 {
    log2size = dk_log2_size(k);
    indices = k + PyDictKeysObject_INDICES;
    if log2size < 8 {
        return i64(ptr[i8](indices + i).view(1)[0]);
    }
    if log2size < 16 {
        return i64(ptr[i16](indices + i * 2).view(1)[0]);
    }
    if log2size >= 32 {
        return ptr[i64](indices + i * 8).view(1)[0];
    }
    return i64(ptr[i32](indices + i * 4).view(1)[0]);
}

impl dictkeys_set_index(k: ptr[u8], i: i64, ix: i64) {
    log2size = dk_log2_size(k);
    indices = k + PyDictKeysObject_INDICES;
    if log2size < 8 {
        ptr[i8](indices + i).view(1)[0] = i8(ix);
    } elif log2size < 16 {
        ptr[i16](indices + i * 2).view(1)[0] = i16(ix);
    } elif log2size >= 32 {
        ptr[i64](indices + i * 8).view(1)[0] = ix;
    } else {
        ptr[i32](indices + i * 4).view(1)[0] = i32(ix);
    }
}

impl usable_fraction(n: i64) -> i64 {
    return (n << 1) // 3;
}

impl calculate_log2_keysize(minsize_in: i64) -> i64 {
    minsize = max(minsize_in, PyDict_MINSIZE);

    n = u64.wrap(minsize - 1);
    bits = 0;
    while n != u64(0) {
        bits += 1;
        n = n >> u64(1);
    }
    return bits;
}

impl estimate_log2_keysize(n: i64) -> i64 {
    return calculate_log2_keysize((n * 3 + 1) // 2);
}

impl growth_rate(mp: ptr[PyObject]) -> i64 {
    return dict_used(mp) * 3;
}

impl empty_keys -> ptr[u8] {
    return ptr[u8](addressof(empty_keys_struct));
}

impl dictkeys_incref(k: ptr[u8]) {
    if dk_refcnt(k) < 0 {
        return;
    }
    set_keys_i64(k, PyDictKeysObject_REFCNT, dk_refcnt(k) + 1);
}

impl dictkeys_decref(k: ptr[u8]) {
    refcnt = dk_refcnt(k);
    if refcnt < 0 {
        return;
    }
    set_keys_i64(k, PyDictKeysObject_REFCNT, refcnt - 1);
    if refcnt == 1 {
        n = dk_nentries(k);
        for i in range(n) {
            object_xdecref(entry_key(k, i));
            object_xdecref(entry_value(k, i));
        }
        free_keys_object(k);
    }
}

impl new_keys_object(log2_size: i64, unicode: bool) -> ptr[u8] {
    entry_size = UNICODE_ENTRY_SIZE if unicode else KEY_ENTRY_SIZE;
    usable = usable_fraction(1 << log2_size);
    log2_bytes = log2_size;
    if log2_size >= 32 {
        log2_bytes = log2_size + 3;
    } elif log2_size >= 16 {
        log2_bytes = log2_size + 2;
    } elif log2_size >= 8 {
        log2_bytes = log2_size + 1;
    }
    dk = ptr[u8]();
    if log2_size == PyDict_LOG_MINSIZE and unicode {
        dk = ptr[u8](freelist_pop_mem(_Py_freelists_DICTKEYS));
    }
    if not dk {
        dk = ptr[u8](
            PyMem_Malloc(
                u64(PyDictKeysObject_INDICES + (1 << log2_bytes) + entry_size * usable)
            )
        );
        if not dk {
            PyErr_NoMemory();
            return ptr[u8]();
        }
    }
    set_keys_i64(dk, PyDictKeysObject_REFCNT, 1);
    (dk + PyDictKeysObject_LOG2_SIZE).view(1)[0] = u8(log2_size);
    (dk + PyDictKeysObject_LOG2_INDEX_BYTES).view(1)[0] = u8(log2_bytes);
    set_dk_kind(dk, DICT_KEYS_UNICODE if unicode else DICT_KEYS_GENERAL);
    set_dk_nentries(dk, 0);
    set_dk_usable(dk, usable);
    set_dk_version(dk, u32(0));

    jacpy_memory_fill(ptr(dk + PyDictKeysObject_INDICES), 255, 1 << log2_bytes);
    jacpy_memory_zero(
        ptr(dk + PyDictKeysObject_INDICES + (1 << log2_bytes)), entry_size * usable
    );
    return dk;
}

impl free_keys_object(k: ptr[u8]) {
    if dk_log2_size(k) == PyDict_LOG_MINSIZE and dk_kind(k) == DICT_KEYS_UNICODE {
        if freelist_push_mem(_Py_freelists_DICTKEYS, ptr(k), Py_dictkeys_MAXFREELIST) {
            return;
        }
    }
    PyMem_Free(ptr(k));
}

impl keys_size(k: ptr[u8]) -> i64 {
    es = KEY_ENTRY_SIZE if dk_kind(k) == DICT_KEYS_GENERAL else UNICODE_ENTRY_SIZE;
    return PyDictKeysObject_INDICES
        + (1 << dk_log2_index_bytes(k))
        + usable_fraction(dk_size(k)) * es;
}

impl values_capacity(v: ptr[u8]) -> i64 {
    return i64(v.view(1)[0]);
}

impl values_size(v: ptr[u8]) -> i64 {
    return i64((v + 1).view(1)[0]);
}

impl set_values_size(v: ptr[u8], size: i64) {
    (v + 1).view(1)[0] = u8(size);
}

impl values_embedded(v: ptr[u8]) -> bool {
    return (v + 2).view(1)[0] != u8(0);
}

impl values_valid(v: ptr[u8]) -> bool {
    return (v + 3).view(1)[0] != u8(0);
}

impl set_values_valid(v: ptr[u8], valid: bool) {
    (v + 3).view(1)[0] = u8(1) if valid else u8(0);
}

impl value_at(v: ptr[u8], ix: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](v + PyDictValues_VALUES + ix * 8).view(1)[0];
}

impl set_value_at(v: ptr[u8], ix: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](v + PyDictValues_VALUES + ix * 8).view(1)[0] = value;
}

impl insertion_order(v: ptr[u8]) -> ptr[u8] {
    return v + PyDictValues_VALUES + values_capacity(v) * 8;
}

impl add_to_insertion_order(v: ptr[u8], ix: i64) {
    size = values_size(v);
    (insertion_order(v) + size).view(1)[0] = u8(ix);
    set_values_size(v, size + 1);
}

impl delete_index_from_values(v: ptr[u8], ix: i64) {
    order = insertion_order(v);
    size = values_size(v);
    i = 0;
    while i64((order + i).view(1)[0]) != ix {
        i += 1;
    }
    size -= 1;
    while i < size {
        (order + i).view(1)[0] = (order + (i + 1)).view(1)[0];
        i += 1;
    }
    set_values_size(v, size);
}

impl values_size_from_count(count: i64) -> i64 {
    suffix_size = ((count + 7) // 8) * 8;
    return (count + 1) * 8 + suffix_size;
}

impl new_values(size: i64) -> ptr[u8] {
    res = ptr[u8](PyMem_Malloc(u64(values_size_from_count(size))));
    if not res {
        return ptr[u8]();
    }
    (res + 2).view(1)[0] = u8(0);
    set_values_size(res, 0);
    res.view(1)[0] = u8(size);
    return res;
}

impl free_values(v: ptr[u8]) {
    PyMem_Free(ptr(v));
}

impl shared_keys_usable_size(k: ptr[u8]) -> i64 {
    usable = dk_usable(k);
    return dk_nentries(k) + usable;
}

impl dict_of(op: ptr[PyObject]) -> ptr[PyDictObject] {
    return ptr[PyDictObject](op);
}

impl dict_keys_of(mp: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](dict_of(mp).view(1)[0].ma_keys);
}

impl set_dict_keys(mp: ptr[PyObject], k: ptr[u8]) {
    dict_of(mp).view(1)[0].ma_keys = ptr[PyDictKeysObject](k);
}

impl dict_values_of(mp: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](dict_of(mp).view(1)[0].ma_values);
}

impl set_dict_values(mp: ptr[PyObject], v: ptr[u8]) {
    dict_of(mp).view(1)[0].ma_values = ptr[PyDictValues](v);
}

impl dict_used(mp: ptr[PyObject]) -> i64 {
    return dict_of(mp).view(1)[0].ma_used;
}

impl set_dict_used(mp: ptr[PyObject], used: i64) {
    dict_of(mp).view(1)[0].ma_used = used;
}

impl has_split_table(mp: ptr[PyObject]) -> bool {
    return bool(dict_values_of(mp));
}

impl dict_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}

impl dict_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyDict_Type));
}

impl unicode_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyUnicode_Type)));
}

impl unicode_get_hash(op: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](op) + PyASCIIObject_HASH).view(1)[0];
}

impl hash_fast(op: ptr[PyObject]) -> i64 {
    if unicode_check_exact(op) {
        hash = unicode_get_hash(op);
        if hash != -1 {
            return hash;
        }
    }
    return PyObject_Hash(op);
}

impl hash_unicode_key(key: ptr[PyObject]) -> i64 {
    hash = unicode_get_hash(key);
    if hash == -1 {
        hash = PyObject_Hash(key);
    }
    return hash;
}

impl unicode_eq(a: ptr[PyObject], b: ptr[PyObject]) -> bool {
    length = ptr[i64](ptr[u8](a) + PyASCIIObject_LENGTH).view(1)[0];
    if ptr[i64](ptr[u8](b) + PyASCIIObject_LENGTH).view(1)[0] != length {
        return False;
    }
    kind = jacpy_unicode_kind(a);
    if jacpy_unicode_kind(b) != kind {
        return False;
    }
    return memcmp(jacpy_unicode_data(a), jacpy_unicode_data(b), u64(length * kind))
        == 0;
}

impl notify_event(
    event: i32, mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) {
    watcher_bits = dict_of(mp).view(1)[0]._ma_watcher_tag & u64(0xFF);
    if watcher_bits != u64(0) {
        _PyDict_SendEvent(i32(i64.wrap(watcher_bits)), event, mp, key, value);
    }
}

impl index_from_order(mp: ptr[PyObject], i: i64) -> i64 {
    return i64((insertion_order(dict_values_of(mp)) + i).view(1)[0]);
}

impl next_probe(i: u64, perturb: u64, mask: u64) -> u64 {
    return wrapping_add(wrapping_add(wrapping_mul(i, u64(5)), perturb), u64(1)) & mask;
}

impl lookdict_index(k: ptr[u8], hash: i64, index: i64) -> i64 {
    mask = u64.wrap(dk_size(k) - 1);
    perturb = u64.wrap(hash);
    i = perturb & mask;
    while True {
        ix = dictkeys_get_index(k, i64.wrap(i));
        if ix == index {
            return i64.wrap(i);
        }
        if ix == DKIX_EMPTY {
            return DKIX_EMPTY;
        }
        perturb = perturb >> PERTURB_SHIFT;
        i = next_probe(i, perturb, mask);
    }
    return DKIX_EMPTY;
}

impl check_lookup(
    mode: i64, mp: ptr[PyObject], k: ptr[u8], ix: i64, key: ptr[PyObject], hash: i64
) -> i64 {
    if mode == CHECK_UNICODE_UNICODE {
        ep_key = entry_key(k, ix);
        if ep_key == key
            or (unicode_get_hash(ep_key) == hash and unicode_eq(ep_key, key)) {
            return 1;
        }
        return 0;
    }
    ep_key = entry_key(k, ix);
    if mode == CHECK_GENERIC {
        if ep_key == key {
            return 1;
        }
        if key_entry(k, ix).view(1)[0] != hash {
            return 0;
        }
    } elif unicode_get_hash(ep_key) != hash {
        return 0;
    }
    startkey = ep_key;
    object_incref(startkey);
    cmp = PyObject_RichCompareBool(startkey, key, Py_EQ);
    object_decref(startkey);
    if cmp < 0 {
        return DKIX_ERROR;
    }
    if k == dict_keys_of(mp) and entry_key(k, ix) == startkey {
        return i64(cmp);
    }

    return DKIX_KEY_CHANGED;
}

impl do_lookup(
    mode: i64, mp: ptr[PyObject], k: ptr[u8], key: ptr[PyObject], hash: i64
) -> i64 {
    mask = u64.wrap(dk_size(k) - 1);
    perturb = u64.wrap(hash);
    i = perturb & mask;
    while True {
        ix = dictkeys_get_index(k, i64.wrap(i));
        if ix >= 0 {
            cmp = check_lookup(mode, mp, k, ix, key, hash);
            if cmp < 0 {
                return cmp;
            }
            if cmp != 0 {
                return ix;
            }
        } elif ix == DKIX_EMPTY {
            return DKIX_EMPTY;
        }
        perturb = perturb >> PERTURB_SHIFT;
        i = next_probe(i, perturb, mask);
    }
    return DKIX_EMPTY;
}

impl unicodekeys_lookup_unicode(k: ptr[u8], key: ptr[PyObject], hash: i64) -> i64 {
    return do_lookup(CHECK_UNICODE_UNICODE, NULL, k, key, hash);
}

impl check_keys_unicode(k: ptr[u8], key: ptr[PyObject]) -> bool {
    return unicode_check_exact(key) and dk_kind(k) != DICT_KEYS_GENERAL;
}

impl dict_lookup(
    mp: ptr[PyObject], key: ptr[PyObject], hash: i64
) -> tuple[i64, ptr[PyObject]] {
    while True {
        k = dict_keys_of(mp);
        kind = dk_kind(k);
        ix: i64 = 0;
        if kind != DICT_KEYS_GENERAL {
            if unicode_check_exact(key) {
                ix = unicodekeys_lookup_unicode(k, key, hash);
            } else {
                ix = do_lookup(CHECK_UNICODE_GENERIC, mp, k, key, hash);
                if ix == DKIX_KEY_CHANGED {
                    continue;
                }
            }
            if ix >= 0 {
                if kind == DICT_KEYS_SPLIT {
                    return (ix, value_at(dict_values_of(mp), ix));
                }
                return (ix, entry_value(k, ix));
            }
            return (ix, NULL);
        }
        ix = do_lookup(CHECK_GENERIC, mp, k, key, hash);
        if ix == DKIX_KEY_CHANGED {
            continue;
        }
        if ix >= 0 {
            return (ix, entry_value(k, ix));
        }
        return (ix, NULL);
    }
    return (DKIX_EMPTY, NULL);
}

impl find_empty_slot(k: ptr[u8], hash: i64) -> i64 {
    mask = u64.wrap(dk_size(k) - 1);
    i = u64.wrap(hash) & mask;
    ix = dictkeys_get_index(k, i64.wrap(i));
    perturb = u64.wrap(hash);
    while ix >= 0 {
        perturb = perturb >> PERTURB_SHIFT;
        i = next_probe(i, perturb, mask);
        ix = dictkeys_get_index(k, i64.wrap(i));
    }
    return i64.wrap(i);
}

impl insertion_resize(mp: ptr[PyObject], unicode: bool) -> i32 {
    return dictresize(mp, calculate_log2_keysize(growth_rate(mp)), unicode);
}

impl insert_combined_dict(
    mp: ptr[PyObject], hash: i64, key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if dk_is_unicode(dict_keys_of(mp)) and not unicode_check_exact(key) {
        if insertion_resize(mp, False) < 0 {
            return i32(-1);
        }
    }
    if dk_usable(dict_keys_of(mp)) <= 0 {
        if insertion_resize(mp, True) < 0 {
            return i32(-1);
        }
    }
    notify_event(EVENT_ADDED, mp, key, value);
    k = dict_keys_of(mp);
    set_dk_version(k, u32(0));
    hashpos = find_empty_slot(k, hash);
    n = dk_nentries(k);
    dictkeys_set_index(k, hashpos, n);
    set_entry_key(k, n, key);
    set_entry_value(k, n, value);
    if not dk_is_unicode(k) {
        set_entry_hash(k, n, hash);
    }
    set_dk_usable(k, dk_usable(k) - 1);
    set_dk_nentries(k, n + 1);
    return i32(0);
}

impl insert_split_key(k: ptr[u8], key: ptr[PyObject], hash: i64) -> i64 {
    ix = unicodekeys_lookup_unicode(k, key, hash);
    if ix == DKIX_EMPTY and dk_usable(k) > 0 {
        set_dk_version(k, u32(0));
        hashpos = find_empty_slot(k, hash);
        ix = dk_nentries(k);
        dictkeys_set_index(k, hashpos, ix);
        unicode_entry(k, ix).view(1)[0] = int(object_new_ref(key));
        set_dk_usable(k, dk_usable(k) - 1);
        set_dk_nentries(k, ix + 1);
    }
    return ix;
}

impl insert_split_value(
    mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], ix: i64
) {
    values = dict_values_of(mp);
    old_value = value_at(values, ix);
    if not old_value {
        notify_event(EVENT_ADDED, mp, key, value);
        set_value_at(values, ix, object_new_ref(value));
        add_to_insertion_order(values, ix);
        set_dict_used(mp, dict_used(mp) + 1);
    } else {
        notify_event(EVENT_MODIFIED, mp, key, value);
        set_value_at(values, ix, object_new_ref(value));
        object_decref(old_value);
    }
}

impl insertdict(
    mp: ptr[PyObject], key: ptr[PyObject], hash: i64, value: ptr[PyObject]
) -> i32 {
    old_value = NULL;
    ix: i64 = DKIX_EMPTY;
    if has_split_table(mp) and unicode_check_exact(key) {
        ix = insert_split_key(dict_keys_of(mp), key, hash);
        if ix != DKIX_EMPTY {
            insert_split_value(mp, key, value, ix);
            object_decref(key);
            object_decref(value);
            return i32(0);
        }
    } else {
        (ix, old_value) = dict_lookup(mp, key, hash);
        if ix == DKIX_ERROR {
            object_decref(value);
            object_decref(key);
            return i32(-1);
        }
    }
    if not old_value {
        if insert_combined_dict(mp, hash, key, value) < 0 {
            object_decref(value);
            object_decref(key);
            return i32(-1);
        }
        set_dict_used(mp, dict_used(mp) + 1);
        return i32(0);
    }
    if old_value != value {
        notify_event(EVENT_MODIFIED, mp, key, value);
        if has_split_table(mp) {
            set_value_at(dict_values_of(mp), ix, value);
        } else {
            set_entry_value(dict_keys_of(mp), ix, value);
        }
    }

    object_xdecref(old_value);
    object_decref(key);
    return i32(0);
}

impl insert_to_emptydict(
    mp: ptr[PyObject], key: ptr[PyObject], hash: i64, value: ptr[PyObject]
) -> i32 {
    unicode = unicode_check_exact(key);
    newkeys = new_keys_object(PyDict_LOG_MINSIZE, unicode);
    if not newkeys {
        object_decref(key);
        object_decref(value);
        return i32(-1);
    }
    notify_event(EVENT_ADDED, mp, key, value);
    hashpos = i64.wrap(u64.wrap(hash) & u64(PyDict_MINSIZE - 1));
    dictkeys_set_index(newkeys, hashpos, 0);
    set_entry_key(newkeys, 0, key);
    set_entry_value(newkeys, 0, value);
    if not unicode {
        set_entry_hash(newkeys, 0, hash);
    }
    set_dict_used(mp, dict_used(mp) + 1);
    set_dk_usable(newkeys, dk_usable(newkeys) - 1);
    set_dk_nentries(newkeys, dk_nentries(newkeys) + 1);

    set_dict_keys(mp, newkeys);
    return i32(0);
}

impl build_indices(k: ptr[u8], n: i64) {
    mask = u64.wrap(dk_size(k) - 1);
    for ix in range(n) {
        hash = entry_hash(k, ix);
        i = u64.wrap(hash) & mask;
        perturb = u64.wrap(hash);
        while dictkeys_get_index(k, i64.wrap(i)) != DKIX_EMPTY {
            perturb = perturb >> PERTURB_SHIFT;
            i = next_probe(i, perturb, mask);
        }
        dictkeys_set_index(k, i64.wrap(i), ix);
    }
}

impl invalidate_and_clear_inline_values(values: ptr[u8]) {
    set_values_valid(values, False);
    for i in range(values_capacity(values)) {
        set_value_at(values, i, NULL);
    }
}

impl copy_combined_entries(oldkeys: ptr[u8], newkeys: ptr[u8], numentries: i64) {
    old_unicode = dk_is_unicode(oldkeys);
    new_unicode = dk_is_unicode(newkeys);
    if old_unicode == new_unicode and dk_nentries(oldkeys) == numentries {
        es = UNICODE_ENTRY_SIZE if new_unicode else KEY_ENTRY_SIZE;
        jacpy_memory_copy(
            ptr(dk_entries(newkeys)), ptr(dk_entries(oldkeys)), numentries * es
        );
        return;
    }
    j = 0;
    for i in range(numentries) {
        while not entry_value(oldkeys, j) {
            j += 1;
        }
        key = entry_key(oldkeys, j);
        set_entry_key(newkeys, i, key);
        set_entry_value(newkeys, i, entry_value(oldkeys, j));
        if not new_unicode {
            set_entry_hash(newkeys, i, entry_hash(oldkeys, j));
        }
        j += 1;
    }
}

impl dictresize(mp: ptr[PyObject], log2_newsize: i64, unicode_in: bool) -> i32 {
    if log2_newsize >= 64 {
        PyErr_NoMemory();
        return i32(-1);
    }
    oldkeys = dict_keys_of(mp);
    oldvalues = dict_values_of(mp);
    unicode = unicode_in and dk_is_unicode(oldkeys);

    newkeys = new_keys_object(log2_newsize, unicode);
    if not newkeys {
        return i32(-1);
    }
    numentries = dict_used(mp);
    if oldvalues {
        for i in range(numentries) {
            index = index_from_order(mp, i);
            key = entry_key(oldkeys, index);
            set_entry_key(newkeys, i, object_new_ref(key));
            set_entry_value(newkeys, i, value_at(oldvalues, index));
            if not dk_is_unicode(newkeys) {
                set_entry_hash(newkeys, i, unicode_get_hash(key));
            }
        }
        build_indices(newkeys, numentries);
        set_dict_keys(mp, newkeys);
        dictkeys_decref(oldkeys);
        set_dict_values(mp, ptr[u8]());
        if values_embedded(oldvalues) {
            invalidate_and_clear_inline_values(oldvalues);
        } else {
            free_values(oldvalues);
        }
    } else {
        copy_combined_entries(oldkeys, newkeys, numentries);
        build_indices(newkeys, numentries);
        set_dict_keys(mp, newkeys);
        if oldkeys != empty_keys() {
            free_keys_object(oldkeys);
        }
    }
    k = dict_keys_of(mp);
    set_dk_usable(k, dk_usable(k) - numentries);
    set_dk_nentries(k, numentries);
    return i32(0);
}

impl new_dict(
    k: ptr[u8], values: ptr[u8], used: i64, free_values_on_failure: bool
) -> ptr[PyObject] {
    mp = freelist_pop(_Py_freelists_DICTS);
    if not mp {
        mp = _PyObject_GC_New(ptr[PyObject](addressof(PyDict_Type)));
        if not mp {
            dictkeys_decref(k);
            if free_values_on_failure {
                free_values(values);
            }
            return NULL;
        }
    }
    set_dict_keys(mp, k);
    set_dict_values(mp, values);
    set_dict_used(mp, used);
    dict_of(mp).view(1)[0]._ma_watcher_tag = u64(0);
    object_gc_track(mp);
    return mp;
}

impl new_dict_with_shared_keys(k: ptr[u8]) -> ptr[PyObject] {
    size = shared_keys_usable_size(k);
    values = new_values(size);
    if not values {
        return PyErr_NoMemory();
    }
    dictkeys_incref(k);
    for i in range(size) {
        set_value_at(values, i, NULL);
    }
    return new_dict(k, values, 0, True);
}

impl clone_combined_dict_keys(orig: ptr[PyObject]) -> ptr[u8] {
    ok = dict_keys_of(orig);
    size = keys_size(ok);
    k = ptr[u8](PyMem_Malloc(u64(size)));
    if not k {
        PyErr_NoMemory();
        return ptr[u8]();
    }
    jacpy_memory_copy(ptr(k), ptr(ok), size);
    for i in range(dk_nentries(k)) {
        value = entry_value(k, i);
        if value {
            object_incref(value);
            object_incref(entry_key(k, i));
        }
    }
    return k;
}

impl dict_new_presized(minused: i64, unicode: bool) -> ptr[PyObject] {
    log2_max_presize = 17;
    if minused <= usable_fraction(PyDict_MINSIZE) {
        return PyDict_New();
    }

    log2_newsize = log2_max_presize;
    if minused <= usable_fraction(1 << log2_max_presize) {
        log2_newsize = estimate_log2_keysize(minused);
    }
    new_keys = new_keys_object(log2_newsize, unicode);
    if not new_keys {
        return NULL;
    }
    return new_dict(new_keys, ptr[u8](), 0, False);
}

impl dict_unhashable_type(key: ptr[PyObject]) {
    exc = PyErr_GetRaisedException();
    if not object_is_type(exc, ptr[PyTypeObject](PyExc_TypeError)) {
        PyErr_SetRaisedException(exc);
        return;
    }
    PyErr_Format(PyExc_TypeError, "cannot use '%T' as a dict key (%S)", key, exc);
    object_decref(exc);
}

impl setitem_take2(mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    hash = hash_fast(key);
    if hash == -1 {
        dict_unhashable_type(key);
        object_decref(key);
        object_decref(value);
        return i32(-1);
    }
    if dict_keys_of(mp) == empty_keys() {
        return insert_to_emptydict(mp, key, hash, value);
    }
    return insertdict(mp, key, hash, value);
}

impl setitem_lock_held(
    mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    return setitem_take2(mp, object_new_ref(key), object_new_ref(value));
}

impl delitem_common(mp: ptr[PyObject], hash: i64, ix: i64, old_value: ptr[PyObject]) {
    k = dict_keys_of(mp);
    hashpos = lookdict_index(k, hash, ix);
    set_dict_used(mp, dict_used(mp) - 1);
    if has_split_table(mp) {
        set_value_at(dict_values_of(mp), ix, NULL);
        delete_index_from_values(dict_values_of(mp), ix);
    } else {
        set_dk_version(k, u32(0));
        dictkeys_set_index(k, hashpos, DKIX_DUMMY);
        old_key = entry_key(k, ix);
        set_entry_key(k, ix, NULL);
        set_entry_value(k, ix, NULL);
        if not dk_is_unicode(k) {
            set_entry_hash(k, ix, 0);
        }
        object_decref(old_key);
    }
    object_decref(old_value);
}

impl dict_getitem(
    op: ptr[PyObject], key: ptr[PyObject], warnmsg: str
) -> ptr[PyObject] {
    if not dict_check(op) {
        return NULL;
    }
    hash = hash_fast(key);
    if hash == -1 {
        PyErr_FormatUnraisable(warnmsg);
        return NULL;
    }
    exc = PyErr_GetRaisedException();
    (ix, value) = dict_lookup(op, key, hash);

    exc2 = PyErr_Occurred();
    if exc2 and PyErr_GivenExceptionMatches(exc2, PyExc_KeyError) == 0 {
        PyErr_FormatUnraisable(warnmsg);
    }
    PyErr_SetRaisedException(exc);
    return value;
}

impl get_item_ref_known_hash(
    op: ptr[PyObject], key: ptr[PyObject], hash: i64
) -> tuple[i32, ptr[PyObject]] {
    (ix, value) = dict_lookup(op, key, hash);
    if ix == DKIX_ERROR {
        return (i32(-1), NULL);
    }
    if not value {
        return (i32(0), NULL);
    }
    return (i32(1), object_new_ref(value));
}

impl store_result(result: ptr[ptr[PyObject]], value: ptr[PyObject]) {
    if result {
        result.view(1)[0] = value;
    }
}

impl clear_embedded_values(values: ptr[u8], nentries: i64) {
    refs = ptr[ptr[PyObject]](PyMem_Malloc(u64(max(nentries, 1) * 8)));
    for i in range(nentries) {
        if refs {
            (refs + i).view(1)[0] = value_at(values, i);
        } else {
            object_xdecref(value_at(values, i));
        }
        set_value_at(values, i, NULL);
    }
    set_values_size(values, 0);
    if refs {
        for i in range(nentries) {
            object_xdecref((refs + i).view(1)[0]);
        }
        PyMem_Free(ptr(refs));
    }
}

impl clear_lock_held(op: ptr[PyObject]) {
    if not dict_check(op) {
        return;
    }
    oldkeys = dict_keys_of(op);
    oldvalues = dict_values_of(op);
    if oldkeys == empty_keys() {
        return;
    }
    notify_event(EVENT_CLEARED, op, NULL, NULL);
    set_dict_used(op, 0);
    if not oldvalues {
        set_dict_keys(op, empty_keys());
        dictkeys_decref(oldkeys);
    } elif values_embedded(oldvalues) {
        clear_embedded_values(oldvalues, dk_nentries(oldkeys));
    } else {
        set_dict_values(op, ptr[u8]());
        set_dict_keys(op, empty_keys());
        for i in range(dk_nentries(oldkeys)) {
            old = value_at(oldvalues, i);
            set_value_at(oldvalues, i, NULL);
            object_xdecref(old);
        }
        free_values(oldvalues);
        dictkeys_decref(oldkeys);
    }
}

impl dict_pop_default(
    dict: ptr[PyObject], key: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject] {
    slot = ptr[ptr[PyObject]](PyMem_Calloc(1, 8));
    if not slot {
        return PyErr_NoMemory();
    }
    status = PyDict_Pop(dict, key, slot);
    result = slot.view(1)[0];
    PyMem_Free(ptr(slot));
    if status == 0 {
        if default_value {
            return object_new_ref(default_value);
        }
        _PyErr_SetKeyError(key);
        return NULL;
    }
    return result;
}

impl dict_dict_fromkeys(
    mp: ptr[PyObject], iterable: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    unicode = dk_is_unicode(dict_keys_of(iterable));
    new_size = max(
        estimate_log2_keysize(dict_used(iterable)), dk_log2_size(dict_keys_of(mp))
    );
    if dictresize(mp, new_size, unicode) != 0 {
        object_decref(mp);
        return NULL;
    }
    pos: i64 = 0;
    while True {
        (found, pos, key, oldvalue, hash) = next_with_hash(iterable, pos);
        if not found {
            break;
        }
        if insertdict(mp, object_new_ref(key), hash, object_new_ref(value)) != 0 {
            object_decref(mp);
            return NULL;
        }
    }
    return mp;
}

impl dict_set_fromkeys(
    mp: ptr[PyObject], iterable: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    new_size = max(
        estimate_log2_keysize(PySet_Size(iterable)), dk_log2_size(dict_keys_of(mp))
    );
    if dictresize(mp, new_size, False) != 0 {
        object_decref(mp);
        return NULL;
    }
    pos: i64 = 0;
    key: ptr[PyObject] = NULL;
    hash: i64 = 0;
    while _PySet_NextEntryRef(iterable, &mut pos, &mut key, &mut hash) != 0 {
        if insertdict(mp, key, hash, object_new_ref(value)) != 0 {
            object_decref(mp);
            return NULL;
        }
    }
    return mp;
}

impl next_with_hash(
    op: ptr[PyObject], pos: i64
) -> tuple[bool, i64, ptr[PyObject], ptr[PyObject], i64] {
    i = pos;
    if not dict_check(op) {
        return (False, i, NULL, NULL, 0);
    }
    k = dict_keys_of(op);
    if has_split_table(op) {
        if i < 0 or i >= dict_used(op) {
            return (False, i, NULL, NULL, 0);
        }
        index = index_from_order(op, i);
        key = entry_key(k, index);
        return (
            True,
            i + 1,
            key,
            value_at(dict_values_of(op), index),
            unicode_get_hash(key)
        );
    }
    n = dk_nentries(k);
    if i < 0 or i >= n {
        return (False, i, NULL, NULL, 0);
    }
    while i < n and not entry_value(k, i) {
        i += 1;
    }
    if i >= n {
        return (False, i, NULL, NULL, 0);
    }
    return (True, i + 1, entry_key(k, i), entry_value(k, i), entry_hash(k, i));
}

impl set_refcount(op: ptr[PyObject], refcnt: i64) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    header.view(1)[0].ob_refcnt_full = (full & ~i64(4294967295))
        | (refcnt & i64(4294967295));
}

impl dict_dealloc(self: ptr[PyObject]) {
    if dict_of(self).view(1)[0]._ma_watcher_tag & u64(0xFF) != u64(0) {
        set_refcount(self, 1);
        notify_event(EVENT_DEALLOCATED, self, NULL, NULL);
        refcnt = object_refcount(self) - 1;
        set_refcount(self, refcnt);
        if refcnt != 0 {
            return;
        }
    }
    values = dict_values_of(self);
    k = dict_keys_of(self);

    object_gc_untrack(self);
    if values {
        if not values_embedded(values) {
            for i in range(values_capacity(values)) {
                object_xdecref(value_at(values, i));
            }
            free_values(values);
        }
        dictkeys_decref(k);
    } elif k {
        dictkeys_decref(k);
    }
    if object_is_type(self, ptr[PyTypeObject](addressof(PyDict_Type)))
        and freelist_push(_Py_freelists_DICTS, self, Py_dicts_MAXFREELIST) {
        return;
    }
    free_object(self);
}

impl free_object(op: ptr[PyObject]) {
    calls = ptr[DictCall](__thread_local_block("jac_object_model_dict_call_slot", 32));
    calls.view(1)[0].free = int(object_type(op).view(1)[0].tp_free);
    calls.view(1)[0].free(ptr(op));
}

impl dict_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    res = Py_ReprEnter(self);
    if res != 0 {
        return PyUnicode_FromString(ptr[u8]("{...}")) if res > 0 else NULL;
    }
    if dict_used(self) == 0 {
        Py_ReprLeave(self);
        return PyUnicode_FromString(ptr[u8]("{}"));
    }

    writer = PyUnicodeWriter_Create(1 + 4 + 6 * (dict_used(self) - 1) + 1);
    ok = False;
    if writer {
        ok = PyUnicodeWriter_WriteChar(writer, 123) >= 0;
    }

    pos: i64 = 0;
    first = True;
    while ok {
        (found, pos, key, value, hash) = next_with_hash(self, pos);
        if not found {
            break;
        }
        object_incref(key);
        object_incref(value);
        if not first {
            ok = PyUnicodeWriter_WriteChar(writer, 44) >= 0
                and PyUnicodeWriter_WriteChar(writer, 32) >= 0;
        }
        first = False;
        ok = ok
            and PyUnicodeWriter_WriteRepr(writer, key) >= 0
            and PyUnicodeWriter_WriteChar(writer, 58) >= 0
            and PyUnicodeWriter_WriteChar(writer, 32) >= 0
            and PyUnicodeWriter_WriteRepr(writer, value) >= 0;
        object_decref(key);
        object_decref(value);
    }
    if ok and PyUnicodeWriter_WriteChar(writer, 125) >= 0 {
        Py_ReprLeave(self);
        return PyUnicodeWriter_Finish(writer);
    }
    Py_ReprLeave(self);
    PyUnicodeWriter_Discard(writer);
    return NULL;
}

impl dict_length(self: ptr[PyObject]) -> i64 {
    return dict_used(self);
}

impl dict_subscript(self: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    hash = hash_fast(key);
    if hash == -1 {
        dict_unhashable_type(key);
        return NULL;
    }
    (ix, value) = dict_lookup(self, key, hash);
    if ix == DKIX_ERROR {
        return NULL;
    }
    if ix != DKIX_EMPTY and value {
        return object_new_ref(value);
    }
    if not dict_check_exact(self) {
        missing = _PyObject_LookupSpecial(self, interned_name(0));
        if missing {
            res = PyObject_CallOneArg(missing, key);
            object_decref(missing);
            return res;
        }
        if PyErr_Occurred() {
            return NULL;
        }
    }
    _PyErr_SetKeyError(key);
    return NULL;
}

impl dict_ass_sub(mp: ptr[PyObject], v: ptr[PyObject], w: ptr[PyObject]) -> i32 {
    if not w {
        return PyDict_DelItem(mp, v);
    }
    return PyDict_SetItem(mp, v, w);
}

impl dict_to_list(dict: ptr[PyObject], what: i32) -> ptr[PyObject] {
    if not dict or not dict_check(dict) {
        PyErr_BadInternalCall();
        return NULL;
    }
    while True {
        n = dict_used(dict);
        v = PyList_New(n);
        if not v {
            return NULL;
        }

        failed = False;
        if what == 2 {
            for i in range(n) {
                item = PyTuple_New(2);
                if not item {
                    failed = True;
                    break;
                }
                PyList_SetItem(v, i, item);
            }
        }
        if failed {
            object_decref(v);
            return NULL;
        }
        if n != dict_used(dict) {
            object_decref(v);
            continue;
        }
        j: i64 = 0;
        pos: i64 = 0;
        while True {
            (found, pos, key, value, hash) = next_with_hash(dict, pos);
            if not found {
                break;
            }
            if what == 0 {
                PyList_SetItem(v, j, object_new_ref(key));
            } elif what == 1 {
                PyList_SetItem(v, j, object_new_ref(value));
            } else {
                item = PyList_GetItem(v, j);
                tuple_set_item(item, 0, object_new_ref(key));
                tuple_set_item(item, 1, object_new_ref(value));
            }
            j += 1;
        }
        return v;
    }
    return NULL;
}

impl dict_fromkeys(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("fromkeys"), nargs, 1, 2) == 0 {
        return NULL;
    }
    value = (args + 1).view(1)[0] if nargs > 1 else Py_None;
    return _PyDict_FromKeys(type, args.view(1)[0], value);
}

impl dict_update_arg(self: ptr[PyObject], arg: ptr[PyObject]) -> i32 {
    if dict_check_exact(arg) {
        return PyDict_Merge(self, arg, 1);
    }
    has_keys = PyObject_HasAttrWithError(arg, interned_name(1));
    if has_keys < 0 {
        return i32(-1);
    }
    if has_keys != 0 {
        return PyDict_Merge(self, arg, 1);
    }
    return PyDict_MergeFromSeq2(self, arg, 1);
}

impl dict_update_common(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], methname: ptr[u8]
) -> i32 {
    result = i32(0);
    nargs = object_size(args);
    if _PyArg_CheckPositional(methname, nargs, 0, 1) == 0 {
        return i32(-1);
    }
    if nargs == 1 {
        result = dict_update_arg(self, tuple_get_item(args, 0));
    }
    if result == 0 and kwds {
        if PyArg_ValidateKeywordArguments(kwds) == 0 {
            return i32(-1);
        }
        result = PyDict_Merge(self, kwds, 1);
    }
    return result;
}

impl dict_update(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if dict_update_common(self, args, kwds, ptr[u8]("update")) != -1 {
        return object_new_ref(Py_None);
    }
    return NULL;
}

impl merge_from_seq2(d: ptr[PyObject], seq2: ptr[PyObject], override_mode: i32) -> i32 {
    it = PyObject_GetIter(seq2);
    if not it {
        return i32(-1);
    }
    i: i64 = 0;
    while True {
        item = PyIter_Next(it);
        if not item {
            if PyErr_Occurred() {
                object_decref(it);
                return i32(-1);
            }
            break;
        }

        fast = PySequence_Fast(item, ptr[u8]("object is not iterable"));
        if not fast {
            if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
                _PyErr_FormatNote(
                    "Cannot convert dictionary update sequence element #%zd to a sequence",
                    i
                );
            }
            object_decref(item);
            object_decref(it);
            return i32(-1);
        }
        n = object_size(fast);
        if n != 2 {
            PyErr_Format(
                PyExc_ValueError,
                "dictionary update sequence element #%zd has length %zd; 2 is required",
                i,
                n
            );
            object_decref(fast);
            object_decref(item);
            object_decref(it);
            return i32(-1);
        }
        items = fast_items(fast);
        key = object_new_ref(items.view(1)[0]);
        value = object_new_ref((items + 1).view(1)[0]);
        status = i32(0);
        if override_mode != 0 {
            status = setitem_lock_held(d, key, value);
        } else {
            (status, existing) = setdefault_ref(d, key, value, False);
        }
        object_decref(key);
        object_decref(value);
        object_decref(fast);
        object_decref(item);
        if status < 0 {
            object_decref(it);
            return i32(-1);
        }
        i += 1;
    }
    object_decref(it);
    return i32(0);
}

impl dict_dict_merge(mp: ptr[PyObject], other: ptr[PyObject], override_in: i32) -> i32 {
    override_mode = override_in;
    if other == mp or dict_used(other) == 0 {
        return i32(0);
    }
    if dict_used(mp) == 0 {
        override_mode = i32(1);
        okeys = dict_keys_of(other);

        if not dict_values_of(mp)
            and not dict_values_of(other)
            and dict_used(other) == dk_nentries(okeys)
            and (
                dk_log2_size(okeys) == PyDict_LOG_MINSIZE
                or usable_fraction(dk_size(okeys) // 2) < dict_used(other)
            ) {
            notify_event(EVENT_CLONED, mp, other, NULL);
            k = clone_combined_dict_keys(other);
            if not k {
                return i32(-1);
            }
            dictkeys_decref(dict_keys_of(mp));
            set_dict_keys(mp, k);
            set_dict_used(mp, dict_used(other));
            if object_gc_is_tracked(other) and not object_gc_is_tracked(mp) {
                object_gc_track(mp);
            }
            return i32(0);
        }
    }

    if usable_fraction(dk_size(dict_keys_of(mp))) < dict_used(other) {
        if dictresize(
            mp,
            estimate_log2_keysize(dict_used(mp) + dict_used(other)),
            dk_is_unicode(dict_keys_of(other))
        )
            != 0 {
            return i32(-1);
        }
    }
    orig_size = dict_used(other);
    pos: i64 = 0;
    while True {
        (found, pos, key, value, hash) = next_with_hash(other, pos);
        if not found {
            break;
        }
        object_incref(key);
        object_incref(value);
        err = i32(0);
        if override_mode == 1 {
            err = insertdict(mp, object_new_ref(key), hash, object_new_ref(value));
        } else {
            err = _PyDict_Contains_KnownHash(mp, key, hash);
            if err == 0 {
                err = insertdict(mp, object_new_ref(key), hash, object_new_ref(value));
            } elif err > 0 {
                if override_mode != 0 {
                    _PyErr_SetKeyError(key);
                    object_decref(value);
                    object_decref(key);
                    return i32(-1);
                }
                err = i32(0);
            }
        }
        object_decref(value);
        object_decref(key);
        if err != 0 {
            return i32(-1);
        }
        if orig_size != dict_used(other) {
            PyErr_SetString(PyExc_RuntimeError, "dict mutated during update");
            return i32(-1);
        }
    }
    return i32(0);
}

impl dict_merge(a: ptr[PyObject], b: ptr[PyObject], override_mode: i32) -> i32 {
    if not a or not dict_check(a) or not b {
        PyErr_BadInternalCall();
        return i32(-1);
    }
    if dict_check(b)
        and int(object_type(b).view(1)[0].tp_iter)
            == int(addressof(PyDict_Type).view(1)[0].tp_iter) {
        return dict_dict_merge(a, b, override_mode);
    }

    keys = PyMapping_Keys(b);
    if not keys {
        return i32(-1);
    }
    iter = PyObject_GetIter(keys);
    object_decref(keys);
    if not iter {
        return i32(-1);
    }
    while True {
        key = PyIter_Next(iter);
        if not key {
            break;
        }
        if override_mode != 1 {
            status = PyDict_Contains(a, key);
            if status != 0 {
                if status > 0 {
                    if override_mode == 0 {
                        object_decref(key);
                        continue;
                    }
                    _PyErr_SetKeyError(key);
                }
                object_decref(key);
                object_decref(iter);
                return i32(-1);
            }
        }
        value = PyObject_GetItem(b, key);
        if not value {
            object_decref(iter);
            object_decref(key);
            return i32(-1);
        }
        status = setitem_lock_held(a, key, value);
        object_decref(key);
        object_decref(value);
        if status < 0 {
            object_decref(iter);
            return i32(-1);
        }
    }
    object_decref(iter);
    if PyErr_Occurred() {
        return i32(-1);
    }
    return i32(0);
}

impl copy_values(values: ptr[u8]) -> ptr[u8] {
    capacity = values_capacity(values);
    newvalues = new_values(capacity);
    if not newvalues {
        return ptr[u8]();
    }
    set_values_size(newvalues, values_size(values));
    memcpy(
        ptr(insertion_order(newvalues)), ptr(insertion_order(values)), u64(capacity)
    );
    for i in range(capacity) {
        set_value_at(newvalues, i, value_at(values, i));
    }
    return newvalues;
}

impl copy_lock_held(o: ptr[PyObject]) -> ptr[PyObject] {
    if dict_used(o) == 0 {
        return PyDict_New();
    }
    if has_split_table(o) {
        newvalues = copy_values(dict_values_of(o));
        if not newvalues {
            return PyErr_NoMemory();
        }
        split_copy = _PyObject_GC_New(ptr[PyObject](addressof(PyDict_Type)));
        if not split_copy {
            free_values(newvalues);
            return NULL;
        }
        for i in range(values_capacity(newvalues)) {
            object_xincref(value_at(newvalues, i));
        }
        set_dict_values(split_copy, newvalues);
        set_dict_keys(split_copy, dict_keys_of(o));
        set_dict_used(split_copy, dict_used(o));
        dict_of(split_copy).view(1)[0]._ma_watcher_tag = u64(0);
        dictkeys_incref(dict_keys_of(o));
        object_gc_track(split_copy);
        return split_copy;
    }

    if int(object_type(o).view(1)[0].tp_iter)
        == int(addressof(PyDict_Type).view(1)[0].tp_iter)
        and not dict_values_of(o)
        and dict_used(o) >= (dk_nentries(dict_keys_of(o)) * 2) // 3 {
        k = clone_combined_dict_keys(o);
        if not k {
            return NULL;
        }

        result = new_dict(k, ptr[u8](), 0, False);
        if not result {
            return NULL;
        }
        set_dict_used(result, dict_used(o));
        return result;
    }
    copy = PyDict_New();
    if not copy {
        return NULL;
    }
    if dict_merge(copy, o, 1) == 0 {
        return copy;
    }
    object_decref(copy);
    return NULL;
}

impl dict_equal(a: ptr[PyObject], b: ptr[PyObject]) -> i32 {
    if dict_used(a) != dict_used(b) {
        return i32(0);
    }
    i: i64 = 0;
    while i < dk_nentries(dict_keys_of(a)) {
        k = dict_keys_of(a);
        key = entry_key(k, i);
        aval: ptr[PyObject] = NULL;
        hash: i64 = 0;
        if dk_is_unicode(k) {
            if key {
                hash = unicode_get_hash(key);
                aval = value_at(dict_values_of(a), i)
                    if has_split_table(a)
                    else entry_value(k, i);
            }
        } else {
            aval = entry_value(k, i);
            hash = entry_hash(k, i);
        }
        i += 1;
        if not aval {
            continue;
        }

        object_incref(aval);
        object_incref(key);
        (ix, bval) = dict_lookup(b, key, hash);
        if not bval {
            object_decref(key);
            object_decref(aval);
            return i32(-1) if PyErr_Occurred() else i32(0);
        }
        object_incref(bval);
        cmp = PyObject_RichCompareBool(aval, bval, Py_EQ);
        object_decref(key);
        object_decref(aval);
        object_decref(bval);
        if cmp <= 0 {
            return cmp;
        }
    }
    return i32(1);
}

impl dict_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not dict_check(v) or not dict_check(w) or (op != Py_EQ and op != Py_NE) {
        return object_new_ref(Py_NotImplemented);
    }
    cmp = dict_equal(v, w);
    if cmp < 0 {
        return NULL;
    }
    return PyBool_FromLong(1 if (cmp == 1) == (op == Py_EQ) else 0);
}

impl dict___contains__(self: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    contains = PyDict_Contains(self, key);
    if contains < 0 {
        return NULL;
    }
    return PyBool_FromLong(i64(contains));
}

impl dict_get(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("get"), nargs, 1, 2) == 0 {
        return NULL;
    }
    key = args.view(1)[0];
    hash = hash_fast(key);
    if hash == -1 {
        dict_unhashable_type(key);
        return NULL;
    }
    (ix, val) = dict_lookup(self, key, hash);
    if ix == DKIX_ERROR {
        return NULL;
    }
    if ix == DKIX_EMPTY or not val {
        return object_new_ref((args + 1).view(1)[0])
            if nargs > 1
            else object_new_ref(Py_None);
    }
    return object_new_ref(val);
}

impl setdefault_ref(
    d: ptr[PyObject],
    key: ptr[PyObject],
    default_value: ptr[PyObject],
    incref_result: bool
) -> tuple[i32, ptr[PyObject]] {
    if not dict_check(d) {
        PyErr_BadInternalCall();
        return (i32(-1), NULL);
    }
    hash = hash_fast(key);
    if hash == -1 {
        dict_unhashable_type(key);
        return (i32(-1), NULL);
    }
    if dict_keys_of(d) == empty_keys() {
        if insert_to_emptydict(
            d, object_new_ref(key), hash, object_new_ref(default_value)
        )
            < 0 {
            return (i32(-1), NULL);
        }
        return (
            i32(0),
            object_new_ref(default_value) if incref_result else default_value
        );
    }
    ix: i64 = DKIX_EMPTY;
    value: ptr[PyObject] = NULL;
    if has_split_table(d) and unicode_check_exact(key) {
        ix = insert_split_key(dict_keys_of(d), key, hash);
        if ix != DKIX_EMPTY {
            value = value_at(dict_values_of(d), ix);
            present = bool(value);
            if not present {
                insert_split_value(d, key, default_value, ix);
                value = default_value;
            }
            return (
                i32(1) if present else i32(0),
                object_new_ref(value) if incref_result else value
            );
        }
    } else {
        (ix, value) = dict_lookup(d, key, hash);
        if ix == DKIX_ERROR {
            return (i32(-1), NULL);
        }
    }
    if ix == DKIX_EMPTY {
        value = default_value;
        if insert_combined_dict(d, hash, object_new_ref(key), object_new_ref(value))
            < 0 {
            object_decref(key);
            object_decref(value);
            return (i32(-1), NULL);
        }
        set_dict_used(d, dict_used(d) + 1);
        return (i32(0), object_new_ref(value) if incref_result else value);
    }
    return (i32(1), object_new_ref(value) if incref_result else value);
}

impl dict_setdefault(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("setdefault"), nargs, 1, 2) == 0 {
        return NULL;
    }
    default_value = (args + 1).view(1)[0] if nargs > 1 else Py_None;
    (status, value) = setdefault_ref(self, args.view(1)[0], default_value, True);
    return value;
}

impl dict_clear(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    clear_lock_held(self);
    return object_new_ref(Py_None);
}

impl dict_pop(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("pop"), nargs, 1, 2) == 0 {
        return NULL;
    }
    default_value = (args + 1).view(1)[0] if nargs > 1 else NULL;
    return dict_pop_default(self, args.view(1)[0], default_value);
}

impl dict_popitem(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    res = PyTuple_New(2);
    if not res {
        return NULL;
    }
    if dict_used(self) == 0 {
        object_decref(res);
        PyErr_SetString(PyExc_KeyError, "popitem(): dictionary is empty");
        return NULL;
    }

    if has_split_table(self) {
        if dictresize(self, dk_log2_size(dict_keys_of(self)), True) < 0 {
            object_decref(res);
            return NULL;
        }
    }
    k = dict_keys_of(self);
    set_dk_version(k, u32(0));

    i = dk_nentries(k) - 1;
    while i >= 0 and not entry_value(k, i) {
        i -= 1;
    }
    key = entry_key(k, i);
    notify_event(EVENT_DELETED, self, key, NULL);
    hash = unicode_get_hash(key) if dk_is_unicode(k) else entry_hash(k, i);
    value = entry_value(k, i);
    set_entry_key(k, i, NULL);
    if not dk_is_unicode(k) {
        set_entry_hash(k, i, -1);
    }
    set_entry_value(k, i, NULL);
    j = lookdict_index(k, hash, i);
    dictkeys_set_index(k, j, DKIX_DUMMY);
    tuple_set_item(res, 0, key);
    tuple_set_item(res, 1, value);

    set_dk_nentries(k, i);
    set_dict_used(self, dict_used(self) - 1);
    return res;
}

impl dict_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    k = dict_keys_of(op);
    n = dk_nentries(k);
    status = i32(0);
    if dk_is_unicode(k) {
        split = has_split_table(op);
        for i in range(n) {
            value = value_at(dict_values_of(op), i) if split else entry_value(k, i);
            status = visit_reference(value, visitor, arg);
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }
    for i in range(n) {
        if entry_value(k, i) {
            status = visit_reference(entry_value(k, i), visitor, arg);
            if status != 0 {
                return status;
            }
            status = visit_reference(entry_key(k, i), visitor, arg);
            if status != 0 {
                return status;
            }
        }
    }
    return i32(0);
}

impl dict_tp_clear(op: ptr[PyObject]) -> i32 {
    clear_lock_held(op);
    return i32(0);
}

impl dict___sizeof__(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromSsize_t(_PyDict_SizeOf(self));
}

impl dict_or(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    if not dict_check(self) or not dict_check(other) {
        return object_new_ref(Py_NotImplemented);
    }
    result = PyDict_Copy(self);
    if not result {
        return NULL;
    }
    if dict_update_arg(result, other) != 0 {
        object_decref(result);
        return NULL;
    }
    return result;
}

impl dict_ior(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    if dict_update_arg(self, other) != 0 {
        return NULL;
    }
    return object_new_ref(self);
}

impl dict_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    calls = ptr[DictCall](__thread_local_block("jac_object_model_dict_call_slot", 32));
    calls.view(1)[0].alloc = int(ptr[PyTypeObject](type).view(1)[0].tp_alloc);
    self = calls.view(1)[0].alloc(type, 0);
    if not self {
        return NULL;
    }
    set_dict_used(self, 0);
    dict_of(self).view(1)[0]._ma_watcher_tag = u64(0);

    set_dict_keys(self, empty_keys());
    set_dict_values(self, ptr[u8]());
    if not object_gc_is_tracked(self) {
        object_gc_track(self);
    }
    return self;
}

impl dict_init(self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    return dict_update_common(self, args, kwds, ptr[u8]("dict"));
}

impl dict_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if _PyArg_CheckPositional(ptr[u8]("dict"), nargs, 0, 1) == 0 {
        return NULL;
    }
    self = dict_new(type, NULL, NULL);
    if not self {
        return NULL;
    }
    rest = args;
    if nargs == 1 {
        if dict_update_arg(self, args.view(1)[0]) < 0 {
            object_decref(self);
            return NULL;
        }
        rest = args + 1;
    }
    if kwnames {
        for i in range(object_size(kwnames)) {
            if PyDict_SetItem(self, tuple_get_item(kwnames, i), (rest + i).view(1)[0])
                < 0 {
                object_decref(self);
                return NULL;
            }
        }
    }
    return self;
}

impl dict_iter(self: ptr[PyObject]) -> ptr[PyObject] {
    return dictiter_new(self, addressof(PyDictIterKey_Type));
}

impl iter_of(op: ptr[PyObject]) -> ptr[dictiterobject] {
    return ptr[dictiterobject](op);
}

impl iter_dict(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](iter_of(op).view(1)[0].di_dict);
}

impl is_iter_type(op: ptr[PyObject], type: ptr[PyTypeObject]) -> bool {
    return object_is_type(op, type);
}

impl dictiter_new(dict: ptr[PyObject], itertype: ptr[PyTypeObject]) -> ptr[PyObject] {
    di = _PyObject_GC_New(ptr[PyObject](itertype));
    if not di {
        return NULL;
    }
    it = iter_of(di);
    it.view(1)[0].di_dict = ptr[PyDictObject](object_new_ref(dict));
    used = dict_used(dict);
    it.view(1)[0].di_used = used;
    it.view(1)[0].len = used;
    reverse = itertype == addressof(PyDictRevIterKey_Type)
        or itertype == addressof(PyDictRevIterItem_Type)
        or itertype == addressof(PyDictRevIterValue_Type);
    if reverse {
        it.view(1)[0].di_pos = used - 1
            if has_split_table(dict)
            else dk_nentries(dict_keys_of(dict)) - 1;
    } else {
        it.view(1)[0].di_pos = 0;
    }
    it.view(1)[0].di_result = ptr[PyObject]();
    if itertype == addressof(PyDictIterItem_Type)
        or itertype == addressof(PyDictRevIterItem_Type) {
        result = PyTuple_New(2);
        if not result {
            object_decref(di);
            return NULL;
        }
        tuple_set_item(result, 0, object_new_ref(Py_None));
        tuple_set_item(result, 1, object_new_ref(Py_None));
        it.view(1)[0].di_result = ptr[PyObject](result);
    }
    object_gc_track(di);
    return di;
}

impl dictiter_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    object_xdecref(iter_dict(self));
    object_xdecref(ptr[PyObject](iter_of(self).view(1)[0].di_result));
    PyObject_GC_Del(ptr(self));
}

impl dictiter_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(iter_dict(self), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(
        ptr[PyObject](iter_of(self).view(1)[0].di_result), visitor, arg
    );
}

impl dictiter_len(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    it = iter_of(self);
    d = iter_dict(self);
    length: i64 = 0;
    if d and it.view(1)[0].di_used == dict_used(d) {
        length = it.view(1)[0].len;
    }
    return PyLong_FromSize_t(u64(length));
}

impl iter_exhaust(self: ptr[PyObject], d: ptr[PyObject]) {
    iter_of(self).view(1)[0].di_dict = ptr[PyDictObject]();
    object_decref(d);
}

impl iter_step(self: ptr[PyObject]) -> tuple[ptr[PyObject], ptr[PyObject]] {
    it = iter_of(self);
    d = iter_dict(self);
    if not d {
        return (NULL, NULL);
    }
    if it.view(1)[0].di_used != dict_used(d) {
        PyErr_SetString(PyExc_RuntimeError, "dictionary changed size during iteration");

        it.view(1)[0].di_used = -1;
        return (NULL, NULL);
    }
    i = it.view(1)[0].di_pos;
    k = dict_keys_of(d);
    key: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    if has_split_table(d) {
        if i >= dict_used(d) {
            iter_exhaust(self, d);
            return (NULL, NULL);
        }
        index = index_from_order(d, i);
        key = entry_key(k, index);
        value = value_at(dict_values_of(d), index);
    } else {
        n = dk_nentries(k);
        while i < n and not entry_value(k, i) {
            i += 1;
        }
        if i >= n {
            iter_exhaust(self, d);
            return (NULL, NULL);
        }
        key = entry_key(k, i);
        value = entry_value(k, i);
    }

    if it.view(1)[0].len == 0 {
        PyErr_SetString(PyExc_RuntimeError, "dictionary keys changed during iteration");
        iter_exhaust(self, d);
        return (NULL, NULL);
    }
    it.view(1)[0].di_pos = i + 1;
    it.view(1)[0].len = it.view(1)[0].len - 1;
    return (key, value);
}

impl dictiter_iternextkey(self: ptr[PyObject]) -> ptr[PyObject] {
    (key, value) = iter_step(self);
    return object_xnew_ref(key);
}

impl dictiter_iternextvalue(self: ptr[PyObject]) -> ptr[PyObject] {
    (key, value) = iter_step(self);
    return object_xnew_ref(value);
}

impl item_result(
    self: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    result = ptr[PyObject](iter_of(self).view(1)[0].di_result);
    if object_refcount(result) == 1 {
        object_incref(result);
        oldkey = tuple_get_item(result, 0);
        oldvalue = tuple_get_item(result, 1);
        tuple_set_item(result, 0, key);
        tuple_set_item(result, 1, value);
        object_decref(oldkey);
        object_decref(oldvalue);

        tuple_recycle(result);
        return result;
    }
    result = PyTuple_New(2);
    if not result {
        object_decref(key);
        object_decref(value);
        return NULL;
    }
    tuple_set_item(result, 0, key);
    tuple_set_item(result, 1, value);
    return result;
}

impl dictiter_iternextitem(self: ptr[PyObject]) -> ptr[PyObject] {
    (key, value) = iter_step(self);
    if not key {
        return NULL;
    }
    return item_result(self, object_new_ref(key), object_new_ref(value));
}

impl dictreviter_iternext(self: ptr[PyObject]) -> ptr[PyObject] {
    it = iter_of(self);
    d = iter_dict(self);
    if not d {
        return NULL;
    }
    if it.view(1)[0].di_used != dict_used(d) {
        PyErr_SetString(PyExc_RuntimeError, "dictionary changed size during iteration");
        it.view(1)[0].di_used = -1;
        return NULL;
    }
    i = it.view(1)[0].di_pos;
    k = dict_keys_of(d);
    if i < 0 {
        iter_exhaust(self, d);
        return NULL;
    }
    key: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    if has_split_table(d) {
        index = index_from_order(d, i);
        key = entry_key(k, index);
        value = value_at(dict_values_of(d), index);
    } else {
        while not entry_value(k, i) {
            i -= 1;
            if i < 0 {
                iter_exhaust(self, d);
                return NULL;
            }
        }
        key = entry_key(k, i);
        value = entry_value(k, i);
    }
    it.view(1)[0].di_pos = i - 1;
    it.view(1)[0].len = it.view(1)[0].len - 1;
    if is_iter_type(self, addressof(PyDictRevIterKey_Type)) {
        return object_new_ref(key);
    }
    if is_iter_type(self, addressof(PyDictRevIterValue_Type)) {
        return object_new_ref(value);
    }
    return item_result(self, object_new_ref(key), object_new_ref(value));
}

impl dict___reversed__(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return dictiter_new(self, addressof(PyDictRevIterKey_Type));
}

impl dictiter_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    it = iter_of(self);
    tmp = _PyObject_GC_New(ptr[PyObject](object_type(self)));
    if not tmp {
        return NULL;
    }
    copy = iter_of(tmp);
    copy.view(1)[0].di_dict = ptr[PyDictObject](object_xnew_ref(iter_dict(self)));
    copy.view(1)[0].di_used = it.view(1)[0].di_used;
    copy.view(1)[0].di_pos = it.view(1)[0].di_pos;
    copy.view(1)[0].len = it.view(1)[0].len;
    copy.view(1)[0].di_result = ptr[PyObject]();
    if it.view(1)[0].di_result {
        result = PyTuple_New(2);
        if not result {
            object_decref(tmp);
            return NULL;
        }
        tuple_set_item(result, 0, object_new_ref(Py_None));
        tuple_set_item(result, 1, object_new_ref(Py_None));
        copy.view(1)[0].di_result = ptr[PyObject](result);
    }
    object_gc_track(tmp);
    list = PySequence_List(tmp);
    object_decref(tmp);
    if not list {
        return NULL;
    }
    iter = eval_builtin("iter");
    if not iter {
        object_decref(list);
        return NULL;
    }
    args = PyTuple_New(1);
    if not args {
        object_decref(iter);
        object_decref(list);
        return NULL;
    }
    tuple_set_item(args, 0, list);
    result = PyTuple_New(2);
    if not result {
        object_decref(iter);
        object_decref(args);
        return NULL;
    }
    tuple_set_item(result, 0, iter);
    tuple_set_item(result, 1, args);
    return result;
}

impl view_dict(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](ptr[_PyDictViewObject](op).view(1)[0].dv_dict);
}

impl is_keys_view(op: ptr[PyObject]) -> bool {
    return object_type_check(op, addressof(PyDictKeys_Type));
}

impl is_items_view(op: ptr[PyObject]) -> bool {
    return object_type_check(op, addressof(PyDictItems_Type));
}

impl is_set_view(op: ptr[PyObject]) -> bool {
    return is_keys_view(op) or is_items_view(op);
}

impl anyset_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(PySet_Type)))
        or object_type_check(op, ptr[PyTypeObject](addressof(PyFrozenSet_Type)));
}

impl anyset_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PySet_Type)))
        or object_is_type(op, ptr[PyTypeObject](addressof(PyFrozenSet_Type)));
}

impl dictview_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    object_xdecref(view_dict(self));
    PyObject_GC_Del(ptr(self));
}

impl dictview_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(view_dict(self), visitor, arg);
}

impl dictview_len(self: ptr[PyObject]) -> i64 {
    d = view_dict(self);
    return dict_used(d) if d else 0;
}

impl dictview_mapping(view: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return PyDictProxy_New(view_dict(view));
}

impl all_contained_in(self: ptr[PyObject], other: ptr[PyObject]) -> i32 {
    iter = PyObject_GetIter(self);
    if not iter {
        return i32(-1);
    }
    ok = i32(1);
    while True {
        next = PyIter_Next(iter);
        if not next {
            if PyErr_Occurred() {
                ok = i32(-1);
            }
            break;
        }
        ok = PySequence_Contains(other, next);
        object_decref(next);
        if ok <= 0 {
            break;
        }
    }
    object_decref(iter);
    return ok;
}

impl dictview_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if not anyset_check(other) and not is_set_view(other) {
        return object_new_ref(Py_NotImplemented);
    }
    len_self = PyObject_Size(self);
    if len_self < 0 {
        return NULL;
    }
    len_other = PyObject_Size(other);
    if len_other < 0 {
        return NULL;
    }
    ok = i32(0);
    if op == Py_EQ or op == Py_NE {
        if len_self == len_other {
            ok = all_contained_in(self, other);
        }
        if op == Py_NE and ok >= 0 {
            ok = i32(1) if ok == 0 else i32(0);
        }
    } elif op == Py_LT {
        if len_self < len_other {
            ok = all_contained_in(self, other);
        }
    } elif op == Py_LE {
        if len_self <= len_other {
            ok = all_contained_in(self, other);
        }
    } elif op == Py_GT {
        if len_self > len_other {
            ok = all_contained_in(other, self);
        }
    } elif op == Py_GE {
        if len_self >= len_other {
            ok = all_contained_in(other, self);
        }
    }
    if ok < 0 {
        return NULL;
    }
    return PyBool_FromLong(i64(ok));
}

impl dictview_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    rc = Py_ReprEnter(self);
    if rc != 0 {
        return PyUnicode_FromString(ptr[u8]("...")) if rc > 0 else NULL;
    }
    result: ptr[PyObject] = NULL;
    seq = PySequence_List(self);
    if seq {
        result = PyUnicode_FromFormat(
            "%s(%R)", object_type(self).view(1)[0].tp_name, seq
        );
        object_decref(seq);
    }
    Py_ReprLeave(self);
    return result;
}

impl view_iter(self: ptr[PyObject], itertype: ptr[PyTypeObject]) -> ptr[PyObject] {
    d = view_dict(self);
    if not d {
        return object_new_ref(Py_None);
    }
    return dictiter_new(d, itertype);
}

impl dictkeys_iter(self: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(self, addressof(PyDictIterKey_Type));
}

impl dictitems_iter(self: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(self, addressof(PyDictIterItem_Type));
}

impl dictvalues_iter(self: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(self, addressof(PyDictIterValue_Type));
}

impl dictkeys_reversed(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(self, addressof(PyDictRevIterKey_Type));
}

impl dictitems_reversed(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(self, addressof(PyDictRevIterItem_Type));
}

impl dictvalues_reversed(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(self, addressof(PyDictRevIterValue_Type));
}

impl dictkeys_contains(self: ptr[PyObject], ob: ptr[PyObject]) -> i32 {
    d = view_dict(self);
    if not d {
        return i32(0);
    }
    return PyDict_Contains(d, ob);
}

impl dictitems_contains(self: ptr[PyObject], ob: ptr[PyObject]) -> i32 {
    d = view_dict(self);
    if not d {
        return i32(0);
    }
    if not type_has_feature(object_type(ob), Py_TPFLAGS_TUPLE_SUBCLASS)
        or object_size(ob) != 2 {
        return i32(0);
    }
    key = tuple_get_item(ob, 0);
    hash = hash_fast(key);
    if hash == -1 {
        dict_unhashable_type(key);
        return i32(-1);
    }
    (result, found) = get_item_ref_known_hash(d, key, hash);
    if result == 1 {
        result = PyObject_RichCompareBool(found, tuple_get_item(ob, 1), Py_EQ);
        object_decref(found);
    }
    return result;
}

impl dictviews_to_set(self: ptr[PyObject]) -> ptr[PyObject] {
    left = self;
    if is_keys_view(self) {
        d = view_dict(self);
        if dict_check_exact(d) {
            left = d;
        }
    }
    return PySet_New(left);
}

impl set_method_result(
    self: ptr[PyObject], name: str, other: ptr[PyObject]
) -> ptr[PyObject] {
    result = dictviews_to_set(self);
    if not result {
        return NULL;
    }
    method = jacpy_unicode_intern_text(name);
    if not method {
        object_decref(result);
        return NULL;
    }
    tmp = PyObject_CallMethodObjArgs(result, method, other, ptr());
    object_decref(method);
    if not tmp {
        object_decref(result);
        return NULL;
    }
    object_decref(tmp);
    return result;
}

impl dictviews_sub(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    return set_method_result(self, "difference_update", other);
}

impl dictviews_or(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    result = dictviews_to_set(self);
    if not result {
        return NULL;
    }
    if _PySet_Update(result, other) < 0 {
        object_decref(result);
        return NULL;
    }
    return result;
}

impl dictitems_xor(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    d1 = view_dict(self);
    d2 = view_dict(other);
    temp_dict = copy_lock_held(d1);
    if not temp_dict {
        return NULL;
    }
    result_set = PySet_New(NULL);
    if not result_set {
        object_decref(temp_dict);
        return NULL;
    }
    pos: i64 = 0;
    failed = False;
    while not failed {
        (found, pos, key, val2, hash) = next_with_hash(d2, pos);
        if not found {
            break;
        }
        object_incref(key);
        object_incref(val2);
        val1 = _PyDict_GetItem_KnownHash(temp_dict, key, hash);
        to_delete = i32(0);
        if not val1 {
            failed = bool(PyErr_Occurred());
        } else {
            object_incref(val1);
            to_delete = PyObject_RichCompareBool(val1, val2, Py_EQ);
            failed = to_delete < 0;
        }
        if not failed {
            if to_delete != 0 {
                failed = _PyDict_DelItem_KnownHash(temp_dict, key, hash) < 0;
            } else {
                pair = PyTuple_New(2);
                if not pair {
                    failed = True;
                } else {
                    tuple_set_item(pair, 0, object_new_ref(key));
                    tuple_set_item(pair, 1, object_new_ref(val2));
                    failed = PySet_Add(result_set, pair) < 0;
                    object_decref(pair);
                }
            }
        }
        object_decref(key);
        object_xdecref(val1);
        object_decref(val2);
    }
    if not failed {
        remaining_pairs = PyDict_Items(temp_dict);
        if remaining_pairs {
            status = _PySet_Update(result_set, remaining_pairs);
            object_decref(remaining_pairs);
            if status >= 0 {
                object_decref(temp_dict);
                return result_set;
            }
        }
    }
    object_decref(temp_dict);
    object_decref(result_set);
    return NULL;
}

impl dictviews_xor(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    if is_items_view(self) and is_items_view(other) {
        return dictitems_xor(self, other);
    }
    return set_method_result(self, "symmetric_difference_update", other);
}

impl dictviews_isdisjoint(
    self_in: ptr[PyObject], other_in: ptr[PyObject]
) -> ptr[PyObject] {
    self = self_in;
    other = other_in;
    if self == other {
        return PyBool_FromLong(1 if dictview_len(self) == 0 else 0);
    }

    if anyset_check(other) or is_set_view(other) {
        len_self = dictview_len(self);
        len_other = PyObject_Size(other);
        if len_other == -1 {
            return NULL;
        }
        if len_other > len_self {
            tmp = other;
            other = self;
            self = tmp;
        }
    }
    it = PyObject_GetIter(other);
    if not it {
        return NULL;
    }
    while True {
        item = PyIter_Next(it);
        if not item {
            break;
        }
        contains = PySequence_Contains(self, item);
        object_decref(item);
        if contains == -1 {
            object_decref(it);
            return NULL;
        }
        if contains != 0 {
            object_decref(it);
            return PyBool_FromLong(0);
        }
    }
    object_decref(it);
    if PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(1);
}

impl dict_keys(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return _PyDictView_New(self, addressof(PyDictKeys_Type));
}

impl dict_items(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return _PyDictView_New(self, addressof(PyDictItems_Type));
}

impl dict_values(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return _PyDictView_New(self, addressof(PyDictValues_Type));
}

impl dict_copy(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyDict_Copy(self);
}

impl inline_values(ob: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](ob) + object_type(ob).view(1)[0].tp_basicsize;
}

impl managed_dict_slot(ob: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](ob) + MANAGED_DICT_OFFSET);
}

impl managed_dict(ob: ptr[PyObject]) -> ptr[PyObject] {
    return managed_dict_slot(ob).view(1)[0];
}

impl set_managed_dict(ob: ptr[PyObject], dict: ptr[PyObject]) {
    managed_dict_slot(ob).view(1)[0] = dict;
}

impl cached_keys(tp: ptr[PyTypeObject]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tp) + PyHeapTypeObject_CACHED_KEYS).view(1)[0];
}

impl computed_dict_pointer(ob: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    tp = object_type(ob).view(1)[0];
    dictoffset = tp.tp_dictoffset;
    if dictoffset == 0 {
        return ptr[ptr[PyObject]]();
    }
    if dictoffset < 0 {
        tsize = object_size(ob);
        if tsize < 0 {
            tsize = -tsize;
        }

        size = (tp.tp_basicsize + tsize * tp.tp_itemsize + 7) & ~i64(7);
        dictoffset += size;
    }
    return ptr[ptr[PyObject]](ptr[u8](ob) + dictoffset);
}

impl make_dict_from_instance_attributes(k: ptr[u8], values: ptr[u8]) -> ptr[PyObject] {
    dictkeys_incref(k);
    used: i64 = 0;
    for i in range(shared_keys_usable_size(k)) {
        if value_at(values, i) {
            used += 1;
        }
    }
    return new_dict(k, values, used, False);
}

impl set_item_or_delete(
    dict: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    return _PyDict_SetItem_LockHeld(dict, name, value);
}

impl store_instance_attr(
    ob: ptr[PyObject], values: ptr[u8], name: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    k = cached_keys(object_type(ob));
    ix: i64 = DKIX_EMPTY;
    dict = managed_dict(ob);
    if unicode_check_exact(name) {
        hash = unicode_get_hash(name);
        if hash == -1 {
            hash = PyObject_Hash(name);
        }
        ix = insert_split_key(k, name, hash);
    }
    if ix == DKIX_EMPTY {
        if not dict {
            dict = make_dict_from_instance_attributes(k, values);
            if not dict or _PyDict_SetItem_LockHeld(dict, name, value) < 0 {
                object_xdecref(dict);
                return i32(-1);
            }
            set_managed_dict(ob, dict);
            return i32(0);
        }
        return _PyDict_SetItem_LockHeld(dict, name, value);
    }
    old_value = value_at(values, ix);
    if not old_value and not value {
        PyErr_Format(
            PyExc_AttributeError,
            "'%.100s' object has no attribute '%U'",
            object_type(ob).view(1)[0].tp_name,
            name
        );
        return i32(-1);
    }
    if dict {
        event = EVENT_ADDED
            if not old_value
            else (EVENT_DELETED if not value else EVENT_MODIFIED);
        notify_event(event, dict, name, value);
    }
    set_value_at(values, ix, object_xnew_ref(value));
    if not old_value {
        add_to_insertion_order(values, ix);
        if dict {
            set_dict_used(dict, dict_used(dict) + 1);
        }
    } else {
        if not value {
            delete_index_from_values(values, ix);
            if dict {
                set_dict_used(dict, dict_used(dict) - 1);
            }
        }
        object_decref(old_value);
    }
    return i32(0);
}

impl store_instance_attr_dict(
    ob: ptr[PyObject], dict: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    values = inline_values(ob);
    if dict_values_of(dict) == values {
        return store_instance_attr(ob, values, name, value);
    }
    return _PyDict_SetItem_LockHeld(dict, name, value);
}

impl clear_inline_values(values: ptr[u8]) {
    if values_valid(values) {
        set_values_valid(values, False);
        for i in range(values_capacity(values)) {
            old = value_at(values, i);
            set_value_at(values, i, NULL);
            object_xdecref(old);
        }
    }
}

impl set_dict_inline_values(ob: ptr[PyObject], new_dict: ptr[PyObject]) {
    values = inline_values(ob);
    set_managed_dict(ob, object_xnew_ref(new_dict));
    clear_inline_values(values);
}

impl detach_dict_from_object(mp: ptr[PyObject], ob: ptr[PyObject]) -> i32 {
    if dict_values_of(mp) != inline_values(ob) {
        return i32(0);
    }
    values = copy_values(dict_values_of(mp));
    if not values {
        PyErr_NoMemory();
        return i32(-1);
    }
    set_dict_values(mp, values);
    invalidate_and_clear_inline_values(inline_values(ob));
    return i32(0);
}

impl ensure_managed_dict(ob: ptr[PyObject]) -> ptr[PyObject] {
    dict = managed_dict(ob);
    if not dict {
        tp = object_type(ob);
        if type_has_feature(tp, Py_TPFLAGS_INLINE_VALUES)
            and values_valid(inline_values(ob)) {
            dict = _PyObject_MaterializeManagedDict(ob);
        } else {
            dict = new_dict_with_shared_keys(cached_keys(tp));
            set_managed_dict(ob, dict);
        }
    }
    return dict;
}

impl ensure_nonmanaged_dict(
    ob: ptr[PyObject], dictptr: ptr[ptr[PyObject]]
) -> ptr[PyObject] {
    dict = dictptr.view(1)[0];
    if not dict {
        tp = object_type(ob);
        cached = cached_keys(tp)
            if type_has_feature(tp, Py_TPFLAGS_HEAPTYPE)
            else ptr[u8]();
        dict = new_dict_with_shared_keys(cached) if cached else PyDict_New();
        dictptr.view(1)[0] = dict;
    }
    return dict;
}

impl watcher_slot(watcher_id: i64) -> ptr[int] {
    return ptr[int](current_interp() + PyInterpreterState_DICT_WATCHERS) + watcher_id;
}

impl validate_watcher_id(watcher_id: i32) -> i32 {
    if watcher_id < 0 or i64(watcher_id) >= DICT_MAX_WATCHERS {
        PyErr_Format(PyExc_ValueError, "Invalid dict watcher ID %d", watcher_id);
        return i32(-1);
    }
    if watcher_slot(i64(watcher_id)).view(1)[0] == 0 {
        PyErr_Format(PyExc_ValueError, "No dict watcher set for ID %d", watcher_id);
        return i32(-1);
    }
    return i32(0);
}

impl dict_event_name(event: i32) -> str {
    if event == EVENT_ADDED {
        return "PyDict_EVENT_ADDED";
    }
    if event == EVENT_MODIFIED {
        return "PyDict_EVENT_MODIFIED";
    }
    if event == EVENT_DELETED {
        return "PyDict_EVENT_DELETED";
    }
    if event == EVENT_CLONED {
        return "PyDict_EVENT_CLONED";
    }
    if event == EVENT_CLEARED {
        return "PyDict_EVENT_CLEARED";
    }
    return "PyDict_EVENT_DEALLOCATED";
}
