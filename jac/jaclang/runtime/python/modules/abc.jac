glob abc_data_token = ClassToken();

glob DATA_TYPE: int = 0,
     IMPL: int = 1,
     ABSTRACTMETHODS: int = 2,
     SUBCLASSCHECK: int = 3,
     SUBCLASSHOOK: int = 4,
     CLASS: int = 5,
     DICT: int = 6,
     BASES: int = 7,
     SUBCLASSES: int = 8,
     TPFLAGS: int = 9,
     STATE_NAMES: list[str] = [
         "_abc_impl",
         "__abstractmethods__",
         "__subclasscheck__",
         "__subclasshook__",
         "__class__",
         "__dict__",
         "__bases__",
         "__subclasses__",
         "__abc_tpflags__"
     ];

glob:priv REGISTRY: int = 0,
     CACHE: int = 1,
     NEGATIVE_CACHE: int = 2,
     COLLECTION_FLAGS: u64 = 96;

obj AbcModuleState(NativeState) {
    has invalidation_counter: u64 = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
}

obj AbcData(ReferenceState) {
    has negative_cache_version: u64 = 0;
}

def:priv name(module: ptr[PyObject], index: int) -> ptr[PyObject];

def:priv module_state(module: ptr[PyObject]) -> AbcModuleState | None;

def:priv data_of(abc_impl: ptr[PyObject]) -> AbcData | None;

def abc_data_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def:priv get_impl(module: ptr[PyObject], self_: ptr[PyObject]) -> ptr[PyObject];

def:priv in_weak_set(weak_set: ptr[PyObject], object_: ptr[PyObject]) -> i32;

def:priv abc_destroy(
    setweakref: ptr[PyObject], objweakref: ptr[PyObject]
) -> ptr[PyObject];

glob:priv destroy_functions = FunctionTable(
         [MethodDefinition("_destroy", MethodCallbacks(positional=abc_destroy), "", 8)]
     );

def:priv add_to_weak_set(data: AbcData, which: int, object_: ptr[PyObject]) -> i32;

def:priv clear_set(weak_set: ptr[PyObject]) -> bool;

def _abc__reset_registry_impl(
    module: ptr[PyObject], self_: ptr[PyObject]
) -> ptr[PyObject];

def _abc__reset_caches_impl(
    module: ptr[PyObject], self_: ptr[PyObject]
) -> ptr[PyObject];

def _abc__get_dump_impl(module: ptr[PyObject], self_: ptr[PyObject]) -> ptr[PyObject];

def:priv add_if_abstract(
    abstracts: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def:priv direct_abstracts(
    module: ptr[PyObject], self_: ptr[PyObject], abstracts: ptr[PyObject]
) -> i32;

def:priv inherited_abstracts(
    module: ptr[PyObject], self_: ptr[PyObject], abstracts: ptr[PyObject]
) -> i32;

def:priv compute_abstract_methods(module: ptr[PyObject], self_: ptr[PyObject]) -> i32;

def _abc__abc_init_impl(module: ptr[PyObject], self_: ptr[PyObject]) -> ptr[PyObject];

def _abc__abc_register_impl(
    module: ptr[PyObject], self_: ptr[PyObject], subclass: ptr[PyObject]
) -> ptr[PyObject];

def:priv call_subclasscheck(
    module: ptr[PyObject], self_: ptr[PyObject], subclass: ptr[PyObject]
) -> ptr[PyObject];

def:priv instancecheck(
    module: ptr[PyObject],
    self_: ptr[PyObject],
    instance: ptr[PyObject],
    data: AbcData,
    subclass: ptr[PyObject]
) -> ptr[PyObject];

def _abc__abc_instancecheck_impl(
    module: ptr[PyObject], self_: ptr[PyObject], instance: ptr[PyObject]
) -> ptr[PyObject];

def:priv subclasscheck_check_registry(data: AbcData, subclass: ptr[PyObject]) -> i32;

def:priv remember(
    data: AbcData, which: int, subclass: ptr[PyObject], answer: ptr[PyObject]
) -> ptr[PyObject];

def:priv subclasscheck(
    module: ptr[PyObject], self_: ptr[PyObject], data: AbcData, subclass: ptr[PyObject]
) -> ptr[PyObject];

def _abc__abc_subclasscheck_impl(
    module: ptr[PyObject], self_: ptr[PyObject], subclass: ptr[PyObject]
) -> ptr[PyObject];

def _abc_get_cache_token_impl(module: ptr[PyObject]) -> ptr[PyObject];

impl AbcModuleState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl AbcModuleState.clear {}

impl name(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

impl module_state(module: ptr[PyObject]) -> AbcModuleState | None {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, AbcModuleState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "_abc module state is unavailable");
    return None;
}

impl data_of(abc_impl: ptr[PyObject]) -> AbcData | None {
    if jacpy_binding_native_present(abc_impl, abc_data_token.handle) != 0 {
        state = jacpy_binding_native_get(abc_impl, abc_data_token.handle);
        if isinstance(state, AbcData) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "_abc_data state is unavailable");
    return None;
}

impl abc_data_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    module = PyType_GetModule(type);
    state = module_state(module) if module else None;
    if state is None {
        jacpy_release(instance);
        return NULL;
    }
    data = AbcData(
        references=[NULL, NULL, NULL], negative_cache_version=state.invalidation_counter
    );
    if jacpy_binding_native_set(instance, abc_data_token.handle, data) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

impl get_impl(module: ptr[PyObject], self_: ptr[PyObject]) -> ptr[PyObject] {
    abc_impl = PyObject_GetAttr(self_, name(module, IMPL));
    if not abc_impl {
        return NULL;
    }
    if Py_TYPE(abc_impl) != name(module, DATA_TYPE) {
        object_error(PyExc_TypeError, "_abc_impl is set to a wrong type");
        jacpy_release(abc_impl);
        return NULL;
    }
    return abc_impl;
}

impl in_weak_set(weak_set: ptr[PyObject], object_: ptr[PyObject]) -> i32 {
    if not weak_set or PySet_Size(weak_set) == 0 {
        return i32(0);
    }
    ref = PyWeakref_NewRef(object_, NULL);
    if not ref {
        if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
            PyErr_Clear();
            return i32(0);
        }
        return i32(-1);
    }
    res = PySet_Contains(weak_set, ref);
    jacpy_release(ref);
    return res;
}

impl abc_destroy(
    setweakref: ptr[PyObject], objweakref: ptr[PyObject]
) -> ptr[PyObject] {
    weak_set: ptr[PyObject] = NULL;
    if PyWeakref_GetRef(setweakref, &mut weak_set) < 0 {
        return NULL;
    }
    if not weak_set {
        return Py_NewRef(borrowed_none());
    }
    status = PySet_Discard(weak_set, objweakref);
    jacpy_release(weak_set);
    if status < 0 {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

impl add_to_weak_set(data: AbcData, which: int, object_: ptr[PyObject]) -> i32 {
    weak_set = data.references[which];
    if not weak_set {
        weak_set = PySet_New(NULL);
        if not weak_set {
            return i32(-1);
        }
        data.references[which] = weak_set;
    }
    wr = PyWeakref_NewRef(weak_set, NULL);
    if not wr {
        return i32(-1);
    }
    destroy_cb = destroy_functions.bind(0, wr);
    if not destroy_cb {
        jacpy_release(wr);
        return i32(-1);
    }
    ref = PyWeakref_NewRef(object_, destroy_cb);
    jacpy_release(destroy_cb);
    if not ref {
        jacpy_release(wr);
        return i32(-1);
    }
    ret = PySet_Add(weak_set, ref);
    jacpy_release(wr);
    jacpy_release(ref);
    return ret;
}

impl clear_set(weak_set: ptr[PyObject]) -> bool {
    return not weak_set or PySet_Clear(weak_set) >= 0;
}

impl _abc__reset_registry_impl(
    module: ptr[PyObject], self_: ptr[PyObject]
) -> ptr[PyObject] {
    abc_impl = get_impl(module, self_);
    if not abc_impl {
        return NULL;
    }
    data = data_of(abc_impl);
    ok = data is not None and clear_set(data.references[REGISTRY]);
    jacpy_release(abc_impl);
    return Py_NewRef(borrowed_none()) if ok else NULL;
}

impl _abc__reset_caches_impl(
    module: ptr[PyObject], self_: ptr[PyObject]
) -> ptr[PyObject] {
    abc_impl = get_impl(module, self_);
    if not abc_impl {
        return NULL;
    }
    data = data_of(abc_impl);
    ok = data is not None
        and clear_set(data.references[CACHE])
        and clear_set(data.references[NEGATIVE_CACHE]);
    jacpy_release(abc_impl);
    return Py_NewRef(borrowed_none()) if ok else NULL;
}

impl _abc__get_dump_impl(module: ptr[PyObject], self_: ptr[PyObject]) -> ptr[PyObject] {
    abc_impl = get_impl(module, self_);
    if not abc_impl {
        return NULL;
    }
    data = data_of(abc_impl);
    result: ptr[PyObject] = NULL;
    if data is not None {
        result = owned_tuple(
            [
                PySet_New(data.references[REGISTRY]),
                PySet_New(data.references[CACHE]),
                PySet_New(data.references[NEGATIVE_CACHE]),
                PyLong_FromUnsignedLongLong(data.negative_cache_version)
            ]
        );
    }
    jacpy_release(abc_impl);
    return result;
}

impl add_if_abstract(
    abstracts: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    is_abstract = _PyObject_IsAbstract(value);
    if is_abstract < 0 or (is_abstract != 0 and PySet_Add(abstracts, key) < 0) {
        return i32(-1);
    }
    return i32(0);
}

impl direct_abstracts(
    module: ptr[PyObject], self_: ptr[PyObject], abstracts: ptr[PyObject]
) -> i32 {
    ns = PyObject_GetAttr(self_, name(module, DICT));
    if not ns {
        return i32(-1);
    }
    items = PyMapping_Items(ns);
    jacpy_release(ns);
    if not items {
        return i32(-1);
    }
    status = i32(0);
    pos: i64 = 0;
    while pos < jacpy_list_size(items) {
        item = PyList_GetItemRef(items, pos);
        if not item {
            status = i32(-1);
            break;
        }
        it = PySequence_Fast(item, ptr[u8]("items() returned non-iterable"));
        jacpy_release(item);
        if not it {
            status = i32(-1);
            break;
        }
        if jacpy_fast_size(it) != 2 {
            object_error(PyExc_TypeError, "items() returned item which size is not 2");
            jacpy_release(it);
            status = i32(-1);
            break;
        }
        key = jacpy_fast_item(it, 0);
        value = jacpy_fast_item(it, 1);
        status = add_if_abstract(abstracts, key, value);
        jacpy_release(value);
        jacpy_release(key);
        jacpy_release(it);
        if status < 0 {
            break;
        }
        pos += 1;
    }
    jacpy_release(items);
    return status;
}

impl inherited_abstracts(
    module: ptr[PyObject], self_: ptr[PyObject], abstracts: ptr[PyObject]
) -> i32 {
    bases = PyObject_GetAttr(self_, name(module, BASES));
    if not bases {
        return i32(-1);
    }
    if jacpy_is_tuple(bases) == 0 {
        object_error(PyExc_TypeError, "__bases__ is not tuple");
        jacpy_release(bases);
        return i32(-1);
    }
    status = i32(0);
    for pos in range(int(PyTuple_Size(bases))) {
        item = jacpy_tuple_item(bases, i64(pos));
        base_abstracts: ptr[PyObject] = NULL;
        found = PyObject_GetOptionalAttr(
            item, name(module, ABSTRACTMETHODS), &mut base_abstracts
        );
        jacpy_release(item);
        if found < 0 {
            status = i32(-1);
            break;
        }
        if not base_abstracts {
            continue;
        }
        iterator = PyObject_GetIter(base_abstracts);
        jacpy_release(base_abstracts);
        if not iterator {
            status = i32(-1);
            break;
        }
        key = PyIter_Next(iterator);
        while key {
            value: ptr[PyObject] = NULL;
            if PyObject_GetOptionalAttr(self_, key, &mut value) < 0 {
                status = i32(-1);
            } elif value {
                status = add_if_abstract(abstracts, key, value);
                jacpy_release(value);
            }
            jacpy_release(key);
            if status < 0 {
                break;
            }
            key = PyIter_Next(iterator);
        }
        jacpy_release(iterator);
        if status < 0 or jacpy_error_pending() != 0 {
            status = i32(-1);
            break;
        }
    }
    jacpy_release(bases);
    return status;
}

impl compute_abstract_methods(module: ptr[PyObject], self_: ptr[PyObject]) -> i32 {
    abstracts = jacpy_set_new(NULL, 1);
    if not abstracts {
        return i32(-1);
    }
    status = direct_abstracts(module, self_, abstracts);
    if status == 0 {
        status = inherited_abstracts(module, self_, abstracts);
    }
    if status == 0
        and PyObject_SetAttr(self_, name(module, ABSTRACTMETHODS), abstracts) < 0 {
        status = i32(-1);
    }
    jacpy_release(abstracts);
    return status;
}

impl _abc__abc_init_impl(module: ptr[PyObject], self_: ptr[PyObject]) -> ptr[PyObject] {
    if compute_abstract_methods(module, self_) < 0 {
        return NULL;
    }

    data = abc_data_new(name(module, DATA_TYPE), NULL, NULL);
    if not data {
        return NULL;
    }
    status = PyObject_SetAttr(self_, name(module, IMPL), data);
    jacpy_release(data);
    if status < 0 {
        return NULL;
    }

    if jacpy_is_type(self_) != 0 {
        flags: ptr[PyObject] = NULL;
        if PyDict_Pop(_PyType_GetDict(self_), name(module, TPFLAGS), &mut flags) < 0 {
            return NULL;
        }
        if not flags or jacpy_is_exact_long(flags) == 0 {
            jacpy_release(flags);
            return Py_NewRef(borrowed_none());
        }
        val = PyLong_AsLong(flags);
        jacpy_release(flags);
        if val == -1 and jacpy_error_pending() != 0 {
            return NULL;
        }
        if (u64(val) & COLLECTION_FLAGS) == COLLECTION_FLAGS {
            object_error(
                PyExc_TypeError,
                "__abc_tpflags__ cannot be both Py_TPFLAGS_SEQUENCE and Py_TPFLAGS_MAPPING"
            );
            return NULL;
        }
        _PyType_SetFlags(self_, u64(0), u64(val) & COLLECTION_FLAGS);
    }
    return Py_NewRef(borrowed_none());
}

impl _abc__abc_register_impl(
    module: ptr[PyObject], self_: ptr[PyObject], subclass: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_type(subclass) == 0 {
        object_error(PyExc_TypeError, "Can only register classes");
        return NULL;
    }
    result = PyObject_IsSubclass(subclass, self_);
    if result > 0 {
        return Py_NewRef(subclass);
    }
    if result < 0 {
        return NULL;
    }

    result = PyObject_IsSubclass(self_, subclass);
    if result > 0 {
        object_error(PyExc_RuntimeError, "Refusing to create an inheritance cycle");
        return NULL;
    }
    if result < 0 {
        return NULL;
    }
    abc_impl = get_impl(module, self_);
    if not abc_impl {
        return NULL;
    }
    data = data_of(abc_impl);
    failed = data is None or add_to_weak_set(data, REGISTRY, subclass) < 0;
    jacpy_release(abc_impl);
    if failed {
        return NULL;
    }

    state = module_state(module);
    if state is None {
        return NULL;
    }
    state.invalidation_counter += u64(1);

    if jacpy_is_type(self_) != 0 {
        collection_flag = PyType_GetFlags(self_) & COLLECTION_FLAGS;
        if collection_flag != 0 {
            _PyType_SetFlagsRecursive(subclass, COLLECTION_FLAGS, collection_flag);
        }
    }
    return Py_NewRef(subclass);
}

impl call_subclasscheck(
    module: ptr[PyObject], self_: ptr[PyObject], subclass: ptr[PyObject]
) -> ptr[PyObject] {
    method = PyObject_GetAttr(self_, name(module, SUBCLASSCHECK));
    if not method {
        return NULL;
    }
    result = PyObject_CallOneArg(method, subclass);
    jacpy_release(method);
    return result;
}

impl instancecheck(
    module: ptr[PyObject],
    self_: ptr[PyObject],
    instance: ptr[PyObject],
    data: AbcData,
    subclass: ptr[PyObject]
) -> ptr[PyObject] {
    incache = in_weak_set(data.references[CACHE], subclass);
    if incache < 0 {
        return NULL;
    }
    if incache > 0 {
        return Py_NewRef(borrowed_true());
    }
    subtype = Py_TYPE(instance);
    if subtype == subclass {
        state = module_state(module);
        if state is None {
            return NULL;
        }
        if data.negative_cache_version == state.invalidation_counter {
            incache = in_weak_set(data.references[NEGATIVE_CACHE], subclass);
            if incache < 0 {
                return NULL;
            }
            if incache > 0 {
                return Py_NewRef(borrowed_false());
            }
        }

        return call_subclasscheck(module, self_, subclass);
    }
    result = call_subclasscheck(module, self_, subclass);
    if not result {
        return NULL;
    }
    truth = PyObject_IsTrue(result);
    if truth < 0 {
        jacpy_release(result);
        return NULL;
    }
    if truth == 0 {
        jacpy_release(result);
        return call_subclasscheck(module, self_, subtype);
    }
    return result;
}

impl _abc__abc_instancecheck_impl(
    module: ptr[PyObject], self_: ptr[PyObject], instance: ptr[PyObject]
) -> ptr[PyObject] {
    abc_impl = get_impl(module, self_);
    if not abc_impl {
        return NULL;
    }
    data = data_of(abc_impl);
    if data is None {
        jacpy_release(abc_impl);
        return NULL;
    }
    subclass = PyObject_GetAttr(instance, name(module, CLASS));
    if not subclass {
        jacpy_release(abc_impl);
        return NULL;
    }
    result = instancecheck(module, self_, instance, data, subclass);
    jacpy_release(abc_impl);
    jacpy_release(subclass);
    return result;
}

impl subclasscheck_check_registry(data: AbcData, subclass: ptr[PyObject]) -> i32 {
    ret = in_weak_set(data.references[REGISTRY], subclass);
    if ret != 0 {
        return ret;
    }
    registry_shared = data.references[REGISTRY];
    if not registry_shared {
        return i32(0);
    }

    registry = jacpy_set_new(registry_shared, 1);
    if not registry {
        return i32(-1);
    }
    iterator = PyObject_GetIter(registry);
    jacpy_release(registry);
    if not iterator {
        return i32(-1);
    }
    key = PyIter_Next(iterator);
    while key {
        rkey: ptr[PyObject] = NULL;
        status = PyWeakref_GetRef(key, &mut rkey);
        jacpy_release(key);
        if status < 0 {
            ret = i32(-1);
            break;
        }
        if rkey {
            r = PyObject_IsSubclass(subclass, rkey);
            jacpy_release(rkey);
            if r < 0 {
                ret = i32(-1);
                break;
            }
            if r > 0 {
                ret = i32(-1) if add_to_weak_set(data, CACHE, subclass) < 0 else i32(1);
                break;
            }
        }
        key = PyIter_Next(iterator);
    }
    jacpy_release(iterator);
    if ret == 0 and jacpy_error_pending() != 0 {
        ret = i32(-1);
    }
    return ret;
}

impl remember(
    data: AbcData, which: int, subclass: ptr[PyObject], answer: ptr[PyObject]
) -> ptr[PyObject] {
    if add_to_weak_set(data, which, subclass) < 0 {
        return NULL;
    }
    return Py_NewRef(answer);
}

impl subclasscheck(
    module: ptr[PyObject], self_: ptr[PyObject], data: AbcData, subclass: ptr[PyObject]
) -> ptr[PyObject] {
    incache = in_weak_set(data.references[CACHE], subclass);
    if incache < 0 {
        return NULL;
    }
    if incache > 0 {
        return Py_NewRef(borrowed_true());
    }
    state = module_state(module);
    if state is None {
        return NULL;
    }

    invalidation_counter = state.invalidation_counter;
    if data.negative_cache_version < invalidation_counter {
        if not clear_set(data.references[NEGATIVE_CACHE]) {
            return NULL;
        }
        data.negative_cache_version = invalidation_counter;
    } else {
        incache = in_weak_set(data.references[NEGATIVE_CACHE], subclass);
        if incache < 0 {
            return NULL;
        }
        if incache > 0 {
            return Py_NewRef(borrowed_false());
        }
    }

    hook = PyObject_GetAttr(self_, name(module, SUBCLASSHOOK));
    if not hook {
        return NULL;
    }
    ok = PyObject_CallOneArg(hook, subclass);
    jacpy_release(hook);
    if not ok {
        return NULL;
    }
    if ok == borrowed_true() {
        jacpy_release(ok);
        return remember(data, CACHE, subclass, borrowed_true());
    }
    if ok == borrowed_false() {
        jacpy_release(ok);
        return remember(data, NEGATIVE_CACHE, subclass, borrowed_false());
    }
    if ok != Py_NotImplemented {
        jacpy_release(ok);
        object_error(
            PyExc_AssertionError,
            "__subclasshook__ must return either False, True, or NotImplemented"
        );
        return NULL;
    }
    jacpy_release(ok);

    if PyType_IsSubtype(subclass, self_) != 0 {
        return remember(data, CACHE, subclass, borrowed_true());
    }

    registered = subclasscheck_check_registry(data, subclass);
    if registered < 0 {
        return NULL;
    }
    if registered > 0 {
        return Py_NewRef(borrowed_true());
    }

    method = PyObject_GetAttr(self_, name(module, SUBCLASSES));
    if not method {
        return NULL;
    }
    subclasses = PyObject_CallNoArgs(method);
    jacpy_release(method);
    if not subclasses {
        return NULL;
    }
    if jacpy_is_list(subclasses) == 0 {
        object_error(PyExc_TypeError, "__subclasses__() must return a list");
        jacpy_release(subclasses);
        return NULL;
    }
    pos: i64 = 0;
    while pos < jacpy_list_size(subclasses) {
        scls = PyList_GetItemRef(subclasses, pos);
        if not scls {
            jacpy_release(subclasses);
            return NULL;
        }
        r = PyObject_IsSubclass(subclass, scls);
        jacpy_release(scls);
        if r > 0 {
            jacpy_release(subclasses);
            return remember(data, CACHE, subclass, borrowed_true());
        }
        if r < 0 {
            jacpy_release(subclasses);
            return NULL;
        }
        pos += 1;
    }
    jacpy_release(subclasses);

    return remember(data, NEGATIVE_CACHE, subclass, borrowed_false());
}

impl _abc__abc_subclasscheck_impl(
    module: ptr[PyObject], self_: ptr[PyObject], subclass: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_type(subclass) == 0 {
        object_error(PyExc_TypeError, "issubclass() arg 1 must be a class");
        return NULL;
    }
    abc_impl = get_impl(module, self_);
    if not abc_impl {
        return NULL;
    }
    data = data_of(abc_impl);
    result: ptr[PyObject] = NULL;
    if data is not None {
        result = subclasscheck(module, self_, data, subclass);
    }
    jacpy_release(abc_impl);
    return result;
}

impl _abc_get_cache_token_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    state = module_state(module);
    if state is None {
        return NULL;
    }
    return PyLong_FromUnsignedLongLong(state.invalidation_counter);
}
