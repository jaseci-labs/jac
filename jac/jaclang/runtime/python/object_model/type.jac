import from c {
    glob PyUnicode_Type: PyTypeObject,
         PyTuple_Type: PyTypeObject,
         PyList_Type: PyTypeObject,
         PyDict_Type: PyTypeObject,
         PyLong_Type: PyTypeObject,
         PyBool_Type: PyTypeObject,
         PyModule_Type: PyTypeObject,
         PyCFunction_Type: PyTypeObject,
         PyFunction_Type: PyTypeObject,
         PyCell_Type: PyTypeObject,
         PyClassMethod_Type: PyTypeObject,
         PyStaticMethod_Type: PyTypeObject,
         PyWrapperDescr_Type: PyTypeObject,
         PyMethodDescr_Type: PyTypeObject,
         PyMemoryView_Type: PyTypeObject,
         _PyNone_Type: PyTypeObject,
         _PyWeakref_RefType: PyTypeObject; obj ManagedStaticTypeEntry {
        has type: ptr[PyTypeObject] = ptr[PyTypeObject](),
            interp_count: i64 = 0;
    }  obj SlotDef {
        has name: ptr[u8] = ptr[u8](),
            offset: i32 = 0,
            function: ptr = ptr(),
            wrapper: ptr = ptr(),
            doc: ptr[u8] = ptr[u8](),
            flags: i32 = 0,
            name_strobj: ptr[PyObject] = ptr[PyObject]();
    }  obj TypeCall {
        has lenfunc: Callable[[ptr[PyObject]], i64] = 0,
            inquiry: Callable[[ptr[PyObject]], i32] = 0,
            unaryfunc: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            binaryfunc: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            ternaryfunc:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            ssizeargfunc: Callable[[ptr[PyObject], i64], ptr[PyObject]] = 0,
            ssizeobjargproc: Callable[[ptr[PyObject], i64, ptr[PyObject]], i32] = 0,
            objobjproc: Callable[[ptr[PyObject], ptr[PyObject]], i32] = 0,
            objobjargproc:
                Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            hashfunc: Callable[[ptr[PyObject]], i64] = 0,
            destructor: Callable[[ptr[PyObject]], None] = 0,
            richcmpfunc:
                Callable[[ptr[PyObject], ptr[PyObject], i32], ptr[PyObject]] = 0,
            getbufferproc: Callable[[ptr[PyObject], ptr[Py_buffer], i32], i32] = 0,
            releasebufferproc: Callable[[ptr[PyObject], ptr[Py_buffer]], None] = 0,
            newfunc:
                Callable[
                    [ptr[PyTypeObject], ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            initproc: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            vectorcallfunc:
                Callable[
                    [ptr[PyObject], ptr[ptr[PyObject]], u64, ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            type_watcher: Callable[[ptr[PyTypeObject]], i32] = 0,
            validate_type: Callable[[ptr[PyTypeObject]], i32] = 0,
            getter_fn: Callable[[ptr[PyObject], ptr], ptr[PyObject]] = 0,
            setter_fn: Callable[[ptr[PyObject], ptr[PyObject], ptr], i32] = 0,
            pycfunction: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            wrapperfunc:
                Callable[[ptr[PyObject], ptr[PyObject], ptr], ptr[PyObject]] = 0,
            wrapperfunc_kwds:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr, ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            freefunc: Callable[[ptr], None] = 0,
            traverseproc: Callable[[ptr[PyObject], ptr, ptr], i32] = 0;
    }  obj StackArgs {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject](),
            s5: ptr[PyObject] = ptr[PyObject](),
            s6: ptr[PyObject] = ptr[PyObject](),
            s7: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut StackArgs) -> int;  obj PyBufferWrapper {
        has ob_base: _object,
            mv: ptr[PyObject],
            obj_: ptr[PyObject];
    }  obj SuperObject {
        has ob_base: _object,
            type: ptr[PyTypeObject] = ptr[PyTypeObject](),
            obj_: ptr[PyObject] = ptr[PyObject](),
            obj_type: ptr[PyTypeObject] = ptr[PyTypeObject]();
    }  obj TypeNewCtx {
        has metatype: ptr[PyTypeObject] = ptr[PyTypeObject](),
            args: ptr[PyObject] = ptr[PyObject](),
            kwds: ptr[PyObject] = ptr[PyObject](),
            orig_dict: ptr[PyObject] = ptr[PyObject](),
            name: ptr[PyObject] = ptr[PyObject](),
            bases: ptr[PyObject] = ptr[PyObject](),
            base: ptr[PyTypeObject] = ptr[PyTypeObject](),
            slots: ptr[PyObject] = ptr[PyObject](),
            nslot: i64 = 0,
            add_dict: i32 = 0,
            add_weak: i32 = 0,
            may_add_dict: i32 = 0,
            may_add_weak: i32 = 0;
    }  def PyCell_Set(op: ptr[PyObject], value: ptr[PyObject]) -> i32;  def PyClassMethod_New(
        callable: ptr[PyObject]
    ) -> ptr[PyObject];  def PyDescr_IsData(ob: ptr[PyObject]) -> i32;  def PyDescr_NewClassMethod(
        type: ptr[PyTypeObject], method: ptr[PyMethodDef]
    ) -> ptr[PyObject];  def PyDescr_NewGetSet(
        type: ptr[PyTypeObject], getset: ptr[PyGetSetDef]
    ) -> ptr[PyObject];  def PyDescr_NewMember(
        type: ptr[PyTypeObject], member: ptr[PyMemberDef]
    ) -> ptr[PyObject];  def PyDescr_NewMethod(
        type: ptr[PyTypeObject], method: ptr[PyMethodDef]
    ) -> ptr[PyObject];  def PyDescr_NewWrapper(
        type: ptr[PyTypeObject], base: ptr[wrapperbase], wrapped: ptr
    ) -> ptr[PyObject];  def PyDict_ContainsString(
        op: ptr[PyObject], key: ptr[u8]
    ) -> i32;  def PyEval_GetGlobals -> ptr[PyObject];  def PyMemoryView_FromBuffer(
        info: ptr[Py_buffer]
    ) -> ptr[PyObject];  def PyOS_snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def PyObject_InitVar(
        op: ptr[PyObject], tp: ptr[PyTypeObject], size: i64
    ) -> ptr[PyObject];  def PyObject_Size(o: ptr[PyObject]) -> i64;  def PyObject_VectorcallDict(
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargsf: u64,
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject];  def PySeqIter_New(seq: ptr[PyObject]) -> ptr[PyObject];  def PyStaticMethod_New(
        callable: ptr[PyObject]
    ) -> ptr[PyObject];  def PyUnicode_FromStringAndSize(
        u: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyUnicode_IsIdentifier(self_: ptr[PyObject]) -> i32;  def _PyDictKeys_DecRef(
        k: ptr[u8]
    );  def _PyDict_DetachFromObject(mp: ptr[PyObject], ob: ptr[PyObject]) -> i32;  def _PyDict_GetItemRef_Unicode_LockHeld(
        op: ptr[PyObject], key: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32;  def _PyDict_HasOnlyStringKeys(dct: ptr[PyObject]) -> i32;  def _PyDict_KeysSize(
        k: ptr[u8]
    ) -> u64;  def _PyDict_NewKeysForClass(cls: ptr[PyTypeObject]) -> ptr[u8];  def _PyDict_SetItem_LockHeld(
        dct: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
    ) -> i32;  def _PyErr_FormatNote(format: str, *args: any);  def _PyFunction_GetVersionForCurrentState(
        func: ptr[PyObject]
    ) -> u32;  def _PyMemoryView_FromBufferProc(
        v: ptr[PyObject], flags: i32, bufferproc: ptr
    ) -> ptr[PyObject];  def _PyObject_AssertFailed(
        op: ptr[PyObject],
        expr: ptr[u8],
        msg: ptr[u8],
        file: ptr[u8],
        line: i32,
        function: ptr[u8]
    );  def _PyObject_Call(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        args: ptr[PyObject],
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_Call_Prepend(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        obj_: ptr[PyObject],
        args: ptr[PyObject],
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_ComputedDictPointer(
        ob: ptr[PyObject]
    ) -> ptr[ptr[PyObject]];  def _PyObject_GC_Link(op: ptr[PyObject]);  def _PyObject_GenericGetAttrWithDict(
        ob: ptr[PyObject], name: ptr[PyObject], dict_arg: ptr[PyObject], suppress: i32
    ) -> ptr[PyObject];  def _PyObject_InitInlineValues(
        ob: ptr[PyObject], tp: ptr[PyTypeObject]
    );  def _PyObject_IsInstanceDictEmpty(ob: ptr[PyObject]) -> i32;  def _PyObject_MakeTpCall(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargs: i64,
        keywords: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_MaterializeManagedDict_LockHeld(
        ob: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_NextNotImplemented(
        op_self: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_RealIsInstance(
        inst: ptr[PyObject], cls: ptr[PyObject]
    ) -> i32;  def _PyObject_RealIsSubclass(
        derived: ptr[PyObject], cls: ptr[PyObject]
    ) -> i32;  def _PyObject_SetAttributeErrorContext(
        v: ptr[PyObject], name: ptr[PyObject]
    ) -> i32;  def _PyObject_SetDeferredRefcount(op: ptr[PyObject]) -> None;  def _PyObject_SetManagedDict(
        ob: ptr[PyObject], new_dict: ptr[PyObject]
    ) -> i32;  def _PyStaticType_ClearWeakRefs(interp: ptr, type: ptr[PyTypeObject]);  def _PyUnicode_Equal(
        str1: ptr[PyObject], str2: ptr[PyObject]
    ) -> i32;  def _PyUnicode_InternMortal(interp: ptr[u8], p: ptr[ptr[PyObject]]);  def _PyWeakref_ClearWeakRefsNoCallbacks(
        ob: ptr[PyObject]
    );  def _Py_CheckFunctionResult(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        result: ptr[PyObject],
        where: ptr[u8]
    ) -> ptr[PyObject];  def _Py_SetImmortalUntracked(op: ptr[PyObject]);  def _Py_dict_lookup_threadsafe_stackref(
        mp: ptr[PyObject], key: ptr[PyObject], hash: i64, value_addr: ptr[u64]
    ) -> i64;  def _Py_union_type_or(
        a: ptr[PyObject], b: ptr[PyObject]
    ) -> ptr[PyObject];  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def snprintf(
        target: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def strcmp(left: ptr[u8], right: ptr[u8]) -> i32;  def strlen(
        text: ptr[u8]
    ) -> u64;  def strncmp(left: ptr[u8], right: ptr[u8], size: u64) -> i32;  def strrchr(
        text: ptr[u8], character: i32
    ) -> ptr[u8];
}

glob:priv STACKREF_NULL: u64 = u64(1),
     MANAGED_STATIC_INTERP_COUNT: Final[i64] = 8,
     MANAGED_DICT_OFFSET: i64 = -24,
     MANAGED_WEAKREF_OFFSET: i64 = -32,
     TPFLAGS_PREHEADER: u64 = Py_TPFLAGS_MANAGED_WEAKREF | Py_TPFLAGS_MANAGED_DICT,
     MCACHE_MAX_ATTR_SIZE: i64 = 100,
     MAX_VERSIONS_PER_CLASS: i64 = 1000,
     NSMALLNEGINTS: i64 = 5,
     DKIX_ERROR: i64 = -3,
     CO_FAST_CELL: u8 = u8(64),
     superobject_TYPE: Final[i64] = 16,
     superobject_OBJ: Final[i64] = 24,
     superobject_OBJ_TYPE: Final[i64] = 32,
     superobject_SIZE: Final[i64] = 40;

def py_id(offset: i64) -> ptr[PyObject];

def runtime_at(offset: i64) -> ptr[u8];

def tuple_check(op: ptr[PyObject]) -> bool;

def tuple_check_exact(op: ptr[PyObject]) -> bool;

def dict_check_exact(op: ptr[PyObject]) -> bool;

def long_check(op: ptr[PyObject]) -> bool;

def type_check_exact(op: ptr[PyObject]) -> bool;

def object_xincref(op: ptr[PyObject]);

def object_xnewref(op: ptr[PyObject]) -> ptr[PyObject];

def py_clear(slot: ptr[ptr[PyObject]]);

def py_xsetref(slot: ptr[ptr[PyObject]], value: ptr[PyObject]);

def unicode_length(op: ptr[PyObject]) -> i64;

def unicode_is_interned(op: ptr[PyObject]) -> bool;

def object_hash_fast(op: ptr[PyObject]) -> i64;

def long_one -> ptr[PyObject];

def long_zero -> ptr[PyObject];

def weakref_get_ref(ref: ptr[PyObject]) -> ptr[PyObject];

def type_is_gc(tp: ptr[PyTypeObject]) -> bool;

def type_preheader_size(tp: ptr[PyTypeObject]) -> i64;

def is_static_builtin(tp: ptr[PyTypeObject]) -> bool;

def stackref_is_null(bits: u64) -> bool;

def clear_immortal(op: ptr[PyObject]);

def builtin_state_at(interp: ptr[u8], index: i64) -> ptr[managed_static_type_state];

def ext_state_at(interp: ptr[u8], index: i64) -> ptr[managed_static_type_state];

def managed_static_entry(full_index: i64) -> ptr[ManagedStaticTypeEntry];

def type_from_ref(ref: ptr[PyObject]) -> ptr[PyTypeObject];

def managed_static_type_index_get(self_: ptr[PyTypeObject]) -> i64;

def managed_static_type_index_set(self_: ptr[PyTypeObject], index: i64);

def managed_static_type_index_clear(self_: ptr[PyTypeObject]);

def static_ext_type_lookup(
    interp: ptr[u8], index: i64
) -> tuple[ptr[PyTypeObject], i64];

def managed_static_type_state_get(
    interp: ptr[u8], self_: ptr[PyTypeObject]
) -> ptr[managed_static_type_state];

import from c {
    def _PyStaticType_GetState(
        interp: ptr[u8], self_: ptr[PyTypeObject]
    ) -> ptr[managed_static_type_state] {
        return managed_static_type_state_get(interp, self_);
    }  def _PyStaticType_GetBuiltins -> ptr[PyObject] {
        interp = current_interp();
        count = ptr[i64](
            interp + PyInterpreterState_TYPES_BUILTINS_NUM_INITIALIZED
        ).view(
            1
        )[0];
        results = PyList_New(count);
        if not results {
            return NULL;
        }
        for i in range(count) {
            cls = builtin_state_at(interp, i).view(1)[0].type;

            (ptr[PyListObject](results).view(1)[0].ob_item + i).view(1)[0] = object_new_ref(
                ptr[PyObject](cls)
            );
        }
        return results;
    }
}

def managed_static_type_state_init(
    interp: ptr[u8], self_: ptr[PyTypeObject], isbuiltin: i32, initial: i32
);

def managed_static_type_state_clear(
    interp: ptr[u8], self_: ptr[PyTypeObject], isbuiltin: i32, final: i32
);

def type_set_flags(tp: ptr[PyTypeObject], flags: u64);

def type_set_flags_with_mask(tp: ptr[PyTypeObject], mask: u64, flags: u64);

def type_add_flags(tp: ptr[PyTypeObject], flag: u64);

def type_clear_flags(tp: ptr[PyTypeObject], flag: u64);

def start_readying(type: ptr[PyTypeObject]);

def stop_readying(type: ptr[PyTypeObject]);

def is_readying(type: ptr[PyTypeObject]) -> bool;

def lookup_tp_dict(self_: ptr[PyTypeObject]) -> ptr[PyObject];

import from c {
    def _PyType_GetDict(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
        return lookup_tp_dict(self_);
    }  def PyType_GetDict(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
        return object_xnewref(lookup_tp_dict(self_));
    }
}

def set_tp_dict(self_: ptr[PyTypeObject], dct: ptr[PyObject]);

def clear_tp_dict(self_: ptr[PyTypeObject]);

def lookup_tp_bases(self_: ptr[PyTypeObject]) -> ptr[PyObject];

import from c {
    def _PyType_GetBases(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
        return object_new_ref(lookup_tp_bases(self_));
    }
}

def set_tp_bases(self_: ptr[PyTypeObject], bases: ptr[PyObject], initial: i32);

def clear_tp_bases(self_: ptr[PyTypeObject], final: i32);

def lookup_tp_mro(self_: ptr[PyTypeObject]) -> ptr[PyObject];

import from c {
    def _PyType_GetMRO(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
        return object_xnewref(lookup_tp_mro(self_));
    }
}

def set_tp_mro(self_: ptr[PyTypeObject], mro: ptr[PyObject], initial: i32);

def clear_tp_mro(self_: ptr[PyTypeObject], final: i32);

def init_tp_subclasses(self_: ptr[PyTypeObject]) -> ptr[PyObject];

def clear_tp_subclasses(self_: ptr[PyTypeObject]);

def lookup_tp_subclasses(self_: ptr[PyTypeObject]) -> ptr[PyObject];

import from c {
    def _PyType_HasSubclasses(self_: ptr[PyTypeObject]) -> i32 {
        if not lookup_tp_subclasses(self_) {
            return 0;
        }
        return 1;
    }  def _PyType_GetSubclasses(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
        lst = PyList_New(0);
        if not lst {
            return NULL;
        }
        subclasses = lookup_tp_subclasses(self_);
        if not subclasses {
            return lst;
        }

        i: i64 = 0;
        key = NULL;
        ref = NULL;
        while PyDict_Next(subclasses, &mut i, &mut key, &mut ref) != 0 {
            subclass = type_from_ref(ref);
            if not subclass {
                continue;
            }
            if PyList_Append(lst, ptr[PyObject](subclass)) < 0 {
                object_decref(lst);
                object_decref(ptr[PyObject](subclass));
                return NULL;
            }
            object_decref(ptr[PyObject](subclass));
        }
        return lst;
    }
}

def find_signature(name: ptr[u8], doc: ptr[u8]) -> ptr[u8];

def skip_signature(doc: ptr[u8]) -> ptr[u8];

import from c {
    def _PyType_CheckConsistency(type: ptr[PyTypeObject]) -> i32 {
        return 1;
    }
}

def _PyType_DocWithoutSignature(name: ptr[u8], internal_doc: ptr[u8]) -> ptr[u8];

import from c {
    def _PyType_GetDocFromInternalDoc(
        name: ptr[u8], internal_doc: ptr[u8]
    ) -> ptr[PyObject] {
        doc = _PyType_DocWithoutSignature(name, internal_doc);
        if not doc or doc.view(1)[0] == u8(0) {
            return object_new_ref(Py_None);
        }
        return PyUnicode_FromString(doc);
    }
}

def signature_from_flags(flags: i32) -> ptr[u8];

import from c {
    def _PyType_GetTextSignatureFromInternalDoc(
        name: ptr[u8], internal_doc: ptr[u8], flags: i32
    ) -> ptr[PyObject] {
        start = find_signature(name, internal_doc);
        end = ptr[u8]();
        if start {
            end = skip_signature(start);
        }
        if not end {
            from_flags = signature_from_flags(flags);
            if from_flags {
                return PyUnicode_FromString(from_flags);
            }
            return object_new_ref(Py_None);
        }

        return PyUnicode_FromStringAndSize(start, i64(int(end) - int(start) - 5));
    }
}

def type_cache_clear(cache: ptr[type_cache_entry], value: ptr[PyObject]);

import from c {
    def _PyType_InitCache(interp: ptr[u8]) {
        cache = ptr[type_cache_entry](interp + PyInterpreterState_TYPES_TYPE_CACHE);
        for i in range(1 << MCACHE_SIZE_EXP) {
            cache_entry = cache + i;
            cache_entry.view(1)[0].version = u32(0);
            cache_entry.view(1)[0].name = Py_None;
            cache_entry.view(1)[0].value = NULL;
        }
        init_slotdefs();
    }
}

def _PyType_ClearCache(interp: ptr[u8]) -> u32;

import from c {
    def PyType_ClearCache -> u32 {
        return _PyType_ClearCache(current_interp());
    }  def _PyTypes_Fini(interp: ptr[u8]) {
        type_cache_clear(
            ptr[type_cache_entry](interp + PyInterpreterState_TYPES_TYPE_CACHE), NULL
        );
    }
}

import from c {
    def PyType_AddWatcher(callback: ptr) -> i32 {
        watchers = ptr[ptr](current_interp() + PyInterpreterState_TYPE_WATCHERS);
        i: i64 = 1;
        while i < TYPE_MAX_WATCHERS {
            if not (watchers + i).view(1)[0] {
                (watchers + i).view(1)[0] = callback;
                return i32(i);
            }
            i += 1;
        }
        PyErr_SetString(PyExc_RuntimeError, "no more type watcher IDs available");
        return -1;
    }
}

def validate_watcher_id(interp: ptr[u8], watcher_id: i32) -> i32;

import from c {
    def PyType_ClearWatcher(watcher_id: i32) -> i32 {
        interp = current_interp();
        if validate_watcher_id(interp, watcher_id) < 0 {
            return -1;
        }
        watchers = ptr[ptr](interp + PyInterpreterState_TYPE_WATCHERS);
        (watchers + i64(watcher_id)).view(1)[0] = ptr();
        return 0;
    }  def PyType_Watch(watcher_id: i32, obj_: ptr[PyObject]) -> i32 {
        if not type_check(obj_) {
            PyErr_SetString(PyExc_ValueError, "Cannot watch non-type");
            return -1;
        }
        type = ptr[PyTypeObject](obj_);
        interp = current_interp();
        if validate_watcher_id(interp, watcher_id) < 0 {
            return -1;
        }

        assign_version_tag(interp, type);
        type.view(1)[0].tp_watched = type.view(1)[0].tp_watched
            | u8.wrap(i32(1) << watcher_id);
        return 0;
    }  def PyType_Unwatch(watcher_id: i32, obj_: ptr[PyObject]) -> i32 {
        if not type_check(obj_) {
            PyErr_SetString(PyExc_ValueError, "Cannot watch non-type");
            return -1;
        }
        type = ptr[PyTypeObject](obj_);
        interp = current_interp();
        if validate_watcher_id(interp, watcher_id) != 0 {
            return -1;
        }
        type.view(1)[0].tp_watched = type.view(1)[0].tp_watched
            & ~u8.wrap(i32(1) << watcher_id);
        return 0;
    }
}

def set_version_unlocked(tp: ptr[PyTypeObject], version: u32);

def type_modified_unlocked(type: ptr[PyTypeObject]);

import from c {
    def PyType_Modified(type: ptr[PyTypeObject]) {
        if type.view(1)[0].tp_version_tag == u32(0) {
            return;
        }
        type_modified_unlocked(type);
    }
}

def has_custom_mro(tp: ptr[PyTypeObject]) -> bool;

def type_mro_modified(type: ptr[PyTypeObject], bases: ptr[PyObject]);

import from c {
    def _PyType_SetVersion(tp: ptr[PyTypeObject], version: u32) {
        set_version_unlocked(tp, version);
    }  def _PyType_LookupByVersion(version: u32) -> ptr[PyTypeObject] {
        version_cache = ptr[ptr[PyTypeObject]](
            current_interp() + PyInterpreterState_TYPES_TYPE_VERSION_CACHE
        );
        tp = (version_cache + (i64(version) % TYPE_VERSION_CACHE_SIZE)).view(1)[0];
        if tp and tp.view(1)[0].tp_version_tag == version {
            return tp;
        }
        return ptr[PyTypeObject]();
    }  def _PyType_GetVersionForCurrentState(tp: ptr[PyTypeObject]) -> u32 {
        return tp.view(1)[0].tp_version_tag;
    }
}

def next_global_version_tag -> u32;

def assign_version_tag(interp: ptr[u8], type: ptr[PyTypeObject]) -> i32;

import from c {
    def PyUnstable_Type_AssignVersionTag(type: ptr[PyTypeObject]) -> i32 {
        return assign_version_tag(current_interp(), type);
    }
}

def check_set_special_type_attr(
    type: ptr[PyTypeObject], value: ptr[PyObject], name: ptr[u8]
) -> i32;

import from c {
    def _PyType_Name(type: ptr[PyTypeObject]) -> ptr[u8] {
        tp_name = type.view(1)[0].tp_name;
        s = strrchr(tp_name, i32(46));
        if not s {
            return tp_name;
        }
        return s + 1;
    }
}

def find_name_in_mro(type: ptr[PyTypeObject], name: ptr[PyObject]) -> tuple[i32, u64];

def is_dunder_name(name: ptr[PyObject]) -> bool;

def update_cache(
    cache_entry: ptr[type_cache_entry],
    name: ptr[PyObject],
    version_tag: u32,
    value: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def _PyTypes_AfterFork {
        return;
    }  def _PyType_LookupRefAndVersion(
        type: ptr[PyTypeObject], name: ptr[PyObject], version: ptr[u32]
    ) -> ptr[PyObject] {
        (ver, out) = lookup_stackref_and_version(type, name);
        if version {
            version.view(1)[0] = ver;
        }
        if stackref_is_null(out) {
            return NULL;
        }
        return stackref_as_object_steal(out);
    }
}

def should_assign_version_tag(
    type: ptr[PyTypeObject], name: ptr[PyObject], version_tag: u32
) -> bool;

def type_cache_lookup_miss(
    interp: ptr[u8],
    type: ptr[PyTypeObject],
    name: ptr[PyObject],
    cache_entry: ptr[type_cache_entry]
) -> tuple[u32, u64];

def lookup_stackref_and_version(
    type: ptr[PyTypeObject], name: ptr[PyObject]
) -> tuple[u32, u64];

import from c {
    def _PyType_LookupStackRefAndVersion(
        type: ptr[PyTypeObject], name: ptr[PyObject], out: ptr[u64]
    ) -> u32 {
        type_version = type.view(1)[0].tp_version_tag;
        h = (type_version ^ u32.wrap(int(name) >> 3))
            & u32.wrap((1 << MCACHE_SIZE_EXP) - 1);
        interp = current_interp();
        cache_entry = ptr[type_cache_entry](
            interp + PyInterpreterState_TYPES_TYPE_CACHE
        )
            + i64(h);
        if cache_entry.view(1)[0].version == type_version
            and cache_entry.view(1)[0].name == name {
            value = cache_entry.view(1)[0].value;
            if value {
                out.view(1)[0] = stackref_new(value);
            } else {
                out.view(1)[0] = STACKREF_NULL;
            }
            return cache_entry.view(1)[0].version;
        }
        (version, found) = type_cache_lookup_miss(interp, type, name, cache_entry);
        out.view(1)[0] = found;
        return version;
    }  def _PyType_LookupRef(
        type: ptr[PyTypeObject], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        (ver, out) = lookup_stackref_and_version(type, name);
        if stackref_is_null(out) {
            return NULL;
        }
        return stackref_as_object_steal(out);
    }  def _PyType_Lookup(
        type: ptr[PyTypeObject], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        (ver, out) = lookup_stackref_and_version(type, name);
        if stackref_is_null(out) {
            return NULL;
        }
        res = stackref_as_object_steal(out);
        object_decref(res);
        return res;
    }  def _PyType_CacheInitForSpecialization(
        type: ptr[PyHeapTypeObject], init_fn: ptr[PyObject], tp_version: u32
    ) -> i32 {
        if not init_fn or tp_version == u32(0) {
            return 0;
        }
        can_cache = ptr[PyTypeObject](type).view(1)[0].tp_version_tag == tp_version;
        if can_cache {
            ptr[ptr[PyObject]](ptr[u8](type) + PyHeapTypeObject_SPEC_CACHE_INIT).view(1)[
                0
            ] = init_fn;
        }
        return i32(1) if can_cache else i32(0);
    }  def _PyType_CacheGetItemForSpecialization(
        ht: ptr[PyHeapTypeObject], descriptor: ptr[PyObject], tp_version: u32
    ) -> i32 {
        if not descriptor or tp_version == u32(0) {
            return 0;
        }
        can_cache = ptr[PyTypeObject](ht).view(1)[0].tp_version_tag == tp_version;
        version = _PyFunction_GetVersionForCurrentState(descriptor);

        can_cache = can_cache and version >= u32(2);
        if can_cache {
            ptr[ptr[PyObject]](ptr[u8](ht) + PyHeapTypeObject_SPEC_CACHE_GETITEM).view(
                1
            )[0] = descriptor;
            ptr[u32](ptr[u8](ht) + PyHeapTypeObject_SPEC_CACHE_GETITEM_VERSION).view(1)[
                0
            ] = version;
        }
        return i32(1) if can_cache else i32(0);
    }  def _PyType_SetFlags(self_: ptr[PyTypeObject], mask: u64, flags: u64) {
        type_set_flags_with_mask(self_, mask, flags);
    }  def _PyType_Validate(
        ty: ptr[PyTypeObject], validate: ptr, tp_version: ptr[u32]
    ) -> i32 {
        calls = ptr[TypeCall](
            __thread_local_block("jac_object_model_type_type_calls", 208)
        );
        calls.view(1)[0].validate_type = int(validate);
        err = calls.view(1)[0].validate_type(ty);
        if err == 0 {
            if assign_version_tag(current_interp(), ty) != 0 {
                tp_version.view(1)[0] = ty.view(1)[0].tp_version_tag;
            } else {
                err = -1;
            }
        }
        return err;
    }
}

def set_flags_recursive(self_: ptr[PyTypeObject], mask: u64, flags: u64);

import from c {
    def _PyType_SetFlagsRecursive(self_: ptr[PyTypeObject], mask: u64, flags: u64) {
        if not type_has_feature(self_, Py_TPFLAGS_IMMUTABLETYPE)
            and (self_.view(1)[0].tp_flags & mask) != flags {
            type_modified_unlocked(self_);
        }
        set_flags_recursive(self_, mask, flags);
    }  def _Py_type_getattro_impl(
        type: ptr[PyTypeObject],
        name: ptr[PyObject],
        suppress_missing_attribute: ptr[i32]
    ) -> ptr[PyObject] {
        metatype = object_type(ptr[PyObject](type));
        if not unicode_check(name) {
            PyErr_Format(
                PyExc_TypeError,
                "attribute name must be string, not '%.200s'",
                object_type(name).view(1)[0].tp_name
            );
            return NULL;
        }

        if not type_is_ready(type) {
            if PyType_Ready(type) < 0 {
                return NULL;
            }
        }
        calls = ptr[TypeCall](
            __thread_local_block("jac_object_model_type_type_calls", 208)
        );

        meta_get: int = 0;

        meta_attribute = _PyType_LookupRef(metatype, name);
        if meta_attribute {
            meta_get = int(object_type(meta_attribute).view(1)[0].tp_descr_get);
            if meta_get != 0 and PyDescr_IsData(meta_attribute) != 0 {
                calls.view(1)[0].ternaryfunc = meta_get;
                res = calls.view(1)[0].ternaryfunc(
                    meta_attribute, ptr[PyObject](type), ptr[PyObject](metatype)
                );
                object_decref(meta_attribute);
                return res;
            }
        }

        attribute = _PyType_LookupRef(type, name);
        if attribute {
            local_get = int(object_type(attribute).view(1)[0].tp_descr_get);
            object_xdecref(meta_attribute);
            if local_get != 0 {
                calls.view(1)[0].ternaryfunc = local_get;
                res = calls.view(1)[0].ternaryfunc(
                    attribute, NULL, ptr[PyObject](type)
                );
                object_decref(attribute);
                return res;
            }
            return attribute;
        }

        if meta_get != 0 {
            calls.view(1)[0].ternaryfunc = meta_get;
            res = calls.view(1)[0].ternaryfunc(
                meta_attribute, ptr[PyObject](type), ptr[PyObject](metatype)
            );
            object_decref(meta_attribute);
            return res;
        }

        if meta_attribute {
            return meta_attribute;
        }
        if not suppress_missing_attribute {
            PyErr_Format(
                PyExc_AttributeError,
                "type object '%.100s' has no attribute '%U'",
                type.view(1)[0].tp_name,
                name
            );
        } else {
            suppress_missing_attribute.view(1)[0] = 1;
        }
        return NULL;
    }  def _Py_type_getattro(tp: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
        return _Py_type_getattro_impl(ptr[PyTypeObject](tp), name, ptr[i32]());
    }
}

def type_update_dict(
    type: ptr[PyTypeObject],
    dct: ptr[PyObject],
    name: ptr[PyObject],
    value: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def type_setattro(
    self_: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def type_name(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_qualname(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_set_name(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32;

def type_set_qualname(tp: ptr[PyObject], value: ptr[PyObject], context: ptr) -> i32;

def type_module(type: ptr[PyTypeObject]) -> ptr[PyObject];

def type_get_module(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_set_module(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32;

import from c {
    def _PyType_GetFullyQualifiedName(
        type: ptr[PyTypeObject], sep: i8
    ) -> ptr[PyObject] {
        if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
            return PyUnicode_FromString(type.view(1)[0].tp_name);
        }
        qualname = type_qualname(ptr[PyObject](type), ptr());
        if not qualname {
            return NULL;
        }
        module = type_module(type);
        if not module {
            object_decref(qualname);
            return NULL;
        }
        result: ptr[PyObject] = NULL;
        if unicode_check(module)
            and _PyUnicode_Equal(module, py_id(_Py_ID_builtins)) == 0
            and _PyUnicode_Equal(module, py_id(_Py_ID___main__)) == 0 {
            sep_char = i32(sep);
            result = PyUnicode_FromFormat("%U%c%U", module, sep_char, qualname);
        } else {
            result = object_new_ref(qualname);
        }
        object_decref(module);
        object_decref(qualname);
        return result;
    }  def PyType_GetFullyQualifiedName(type: ptr[PyTypeObject]) -> ptr[PyObject] {
        return _PyType_GetFullyQualifiedName(type, i8(46));
    }
}

def type_abstractmethods(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_set_abstractmethods(
    tp: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32;

def type_get_bases(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_get_mro(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def mro_hierarchy_for_complete_type(
    type: ptr[PyTypeObject], temp: ptr[PyObject]
) -> i32;

def type_set_bases_undo(temp: ptr[PyObject]);

def type_set_bases_bail(
    type: ptr[PyTypeObject],
    new_bases: ptr[PyObject],
    new_base: ptr[PyTypeObject],
    old_bases: ptr[PyObject],
    old_base: ptr[PyTypeObject]
) -> i32;

def type_set_bases_unlocked(type: ptr[PyTypeObject], new_bases: ptr[PyObject]) -> i32;

def type_set_bases(tp: ptr[PyObject], new_bases: ptr[PyObject], closure: ptr) -> i32;

def type_dict(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_get_doc(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_get_text_signature(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_set_doc(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32;

def type_get_annotate(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_set_annotate(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32;

def type_get_annotations(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_set_annotations(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32;

def type_get_type_params(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def type_set_type_params(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32;

def type___instancecheck___impl(
    self_: ptr[PyTypeObject], instance: ptr[PyObject]
) -> i32;

def type___subclasscheck___impl(
    self_: ptr[PyTypeObject], subclass: ptr[PyObject]
) -> i32;

def type___instancecheck__(
    self_: ptr[PyObject], instance: ptr[PyObject]
) -> ptr[PyObject];

def type___subclasscheck__(
    self_: ptr[PyObject], subclass: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    glob:priv type_getsets: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__name__"), get=type_name, set=type_set_name),
             PyGetSetDef(
                 name=ptr[u8]("__qualname__"), get=type_qualname, set=type_set_qualname
             ),
             PyGetSetDef(
                 name=ptr[u8]("__bases__"), get=type_get_bases, set=type_set_bases
             ),
             PyGetSetDef(name=ptr[u8]("__mro__"), get=type_get_mro),
             PyGetSetDef(
                 name=ptr[u8]("__module__"), get=type_get_module, set=type_set_module
             ),
             PyGetSetDef(
                 name=ptr[u8]("__abstractmethods__"),
                 get=type_abstractmethods,
                 set=type_set_abstractmethods
             ),
             PyGetSetDef(name=ptr[u8]("__dict__"), get=type_dict),
             PyGetSetDef(name=ptr[u8]("__doc__"), get=type_get_doc, set=type_set_doc),
             PyGetSetDef(
                 name=ptr[u8]("__text_signature__"), get=type_get_text_signature
             ),
             PyGetSetDef(
                 name=ptr[u8]("__annotations__"),
                 get=type_get_annotations,
                 set=type_set_annotations
             ),
             PyGetSetDef(
                 name=ptr[u8]("__annotate__"),
                 get=type_get_annotate,
                 set=type_set_annotate
             ),
             PyGetSetDef(
                 name=ptr[u8]("__type_params__"),
                 get=type_get_type_params,
                 set=type_set_type_params
             ),
             PyGetSetDef()
         ];
}

def type_repr(self_: ptr[PyObject]) -> ptr[PyObject];

def type_call(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def inline_values_size(tp: ptr[PyTypeObject]) -> i64;

import from c {
    def _PyType_NewManagedObject(type: ptr[PyTypeObject]) -> ptr[PyObject] {
        obj_ = PyType_GenericAlloc(type, 0);
        if not obj_ {
            return PyErr_NoMemory();
        }
        return obj_;
    }  def _PyType_AllocNoTrack(type: ptr[PyTypeObject], nitems: i64) -> ptr[PyObject] {
        size = var_size(type, nitems + 1);
        presize = type_preheader_size(type);
        if type_has_feature(type, Py_TPFLAGS_INLINE_VALUES) {
            size += inline_values_size(type);
        }
        alloc = PyObject_Malloc(u64(size + presize));
        if not alloc {
            return PyErr_NoMemory();
        }
        obj_ = ptr[PyObject](ptr[u8](alloc) + presize);
        if presize != 0 {
            words = ptr[ptr[PyObject]](alloc).view(2);
            words[0] = NULL;
            words[1] = NULL;
        }
        if type_is_gc(type) {
            _PyObject_GC_Link(obj_);
        }

        memset(
            ptr(ptr[u8](obj_) + PyObject_HEAD_SIZE), 0, u64(size - PyObject_HEAD_SIZE)
        );
        if type.view(1)[0].tp_itemsize == 0 {
            PyObject_Init(obj_, ptr[PyObject](type));
        } else {
            PyObject_InitVar(obj_, type, nitems);
        }
        if type_has_feature(type, Py_TPFLAGS_INLINE_VALUES) {
            _PyObject_InitInlineValues(obj_, type);
        }
        return obj_;
    }  def PyType_GenericAlloc(type: ptr[PyTypeObject], nitems: i64) -> ptr[PyObject] {
        obj_ = _PyType_AllocNoTrack(type, nitems);
        if not obj_ {
            return NULL;
        }
        if type_is_gc(type) {
            object_gc_track(obj_);
        }
        return obj_;
    }  def PyType_GenericNew(
        type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
    ) -> ptr[PyObject] {
        return type.view(1)[0].tp_alloc(type, 0);
    }
}

def _PyHeapType_GET_MEMBERS(type: ptr[PyTypeObject]) -> ptr[PyMemberDef];

def traverse_slots(
    type: ptr[PyTypeObject], self_: ptr[PyObject], visitor: ptr, arg: ptr
) -> i32;

def subtype_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def clear_slots(type: ptr[PyTypeObject], self_: ptr[PyObject]);

def subtype_clear(self_: ptr[PyObject]) -> i32;

def subtype_dealloc(self_: ptr[PyObject]);

def type_is_subtype_base_chain(a: ptr[PyTypeObject], b: ptr[PyTypeObject]) -> i32;

def is_subtype_with_mro(
    a_mro: ptr[PyObject], a: ptr[PyTypeObject], b: ptr[PyTypeObject]
) -> i32;

import from c {
    def PyType_IsSubtype(a: ptr[PyTypeObject], b: ptr[PyTypeObject]) -> i32 {
        return is_subtype_with_mro(a.view(1)[0].tp_mro, a, b);
    }
}

import from c {
    def _PyObject_LookupSpecial(
        self_: ptr[PyObject], attr: ptr[PyObject]
    ) -> ptr[PyObject] {
        tp = object_type(self_);
        res = _PyType_LookupRef(tp, attr);
        if res {
            rtype = object_type(res);
            if int(rtype.view(1)[0].tp_descr_get) != 0 {
                bound = rtype.view(1)[0].tp_descr_get(res, self_, ptr[PyObject](tp));
                object_decref(res);
                res = bound;
            }
        }
        return res;
    }  def _PyObject_LookupSpecialMethod(
        attr: ptr[PyObject], method_and_self: ptr[u64]
    ) -> i32 {
        self_slot = method_and_self + 1;
        self_ = stackref_borrow(self_slot.view(1)[0]);
        tp = object_type(self_);
        (_version, method_ref) = lookup_stackref_and_version(tp, attr);
        method_and_self.view(1)[0] = method_ref;
        method_o = stackref_borrow(method_ref);
        if not method_o {
            return 0;
        }
        mtype = object_type(method_o);
        if type_has_feature(mtype, Py_TPFLAGS_METHOD_DESCRIPTOR) {
            return 1;
        }
        if int(mtype.view(1)[0].tp_descr_get) != 0 {
            func = mtype.view(1)[0].tp_descr_get(method_o, self_, ptr[PyObject](tp));
            if not func {
                return -1;
            }

            stackref_clear(method_and_self);
            method_and_self.view(1)[0] = stackref_steal(func);
        }

        stackref_clear(self_slot);
        return 1;
    }
}

def lookup_method_ex(
    self_: ptr[PyObject], attr: ptr[PyObject], raise_attribute_error: i32
) -> tuple[i32, u64];

def lookup_maybe_method(self_: ptr[PyObject], attr: ptr[PyObject]) -> tuple[i32, u64];

def lookup_method(self_: ptr[PyObject], attr: ptr[PyObject]) -> tuple[i32, u64];

def vectorcall_unbound(
    tstate: ptr[PyThreadState],
    unbound: i32,
    func: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64
) -> ptr[PyObject];

def call_unbound_noarg(
    unbound: i32, func: ptr[PyObject], self_: ptr[PyObject]
) -> ptr[PyObject];

def call_method_noarg(self_: ptr[PyObject], attr: ptr[PyObject]) -> ptr[PyObject];

def call_method(
    self_: ptr[PyObject], attr: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def vectorcall_method(
    name: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def vectorcall_maybe(
    tstate: ptr[PyThreadState],
    name: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64
) -> ptr[PyObject];

def maybe_call_special_no_args(
    self_: ptr[PyObject], attr: ptr[PyObject]
) -> tuple[ptr[PyObject], i32];

def maybe_call_special_one_arg(
    self_: ptr[PyObject], attr: ptr[PyObject], arg: ptr[PyObject]
) -> tuple[ptr[PyObject], i32];

import from c {
    def _PyObject_MaybeCallSpecialNoArgs(
        self_: ptr[PyObject], attr: ptr[PyObject]
    ) -> ptr[PyObject] {
        res = NULL;
        (unbound, ref) = lookup_maybe_method(self_, attr);
        func = stackref_borrow(ref);
        if func {
            res = call_unbound_noarg(unbound, func, self_);
        }
        stackref_close(ref);
        return res;
    }  def _PyObject_MaybeCallSpecialOneArg(
        self_: ptr[PyObject], attr: ptr[PyObject], arg: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = thread_state();
        res = NULL;
        (unbound, ref) = lookup_maybe_method(self_, attr);
        func = stackref_borrow(ref);
        if func {
            slots: own StackArgs = StackArgs();
            stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
            stack.view(1)[0] = self_;
            (stack + 1).view(1)[0] = arg;
            res = vectorcall_unbound(tstate, unbound, func, stack, 2);
        }
        stackref_close(ref);
        return res;
    }
}

def tail_contains(tup: ptr[PyObject], whence: i64, o: ptr[PyObject]) -> i32;

def class_name(cls: ptr[PyObject]) -> ptr[PyObject];

def check_duplicates(tup: ptr[PyObject]) -> i32;

def set_mro_error(to_merge: ptr[ptr[PyObject]], to_merge_size: i64, remain: ptr[i64]);

def pmerge(
    acc: ptr[PyObject], to_merge: ptr[ptr[PyObject]], to_merge_size: i64
) -> i32;

def mro_implementation_unlocked(type: ptr[PyTypeObject]) -> ptr[PyObject];

def mro_implementation(type: ptr[PyTypeObject]) -> ptr[PyObject];

def type_mro_impl(self_: ptr[PyTypeObject]) -> ptr[PyObject];

def type_mro(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def mro_check(type: ptr[PyTypeObject], mro: ptr[PyObject]) -> i32;

def mro_invoke(type: ptr[PyTypeObject]) -> ptr[PyObject];

def mro_internal_unlocked(
    type: ptr[PyTypeObject], initial: i32
) -> tuple[i32, ptr[PyObject]];

def mro_internal(type: ptr[PyTypeObject]) -> tuple[i32, ptr[PyObject]];

def best_base(bases: ptr[PyObject]) -> ptr[PyTypeObject];

def shape_differs(t1: ptr[PyTypeObject], t2: ptr[PyTypeObject]) -> i32;

def solid_base(type: ptr[PyTypeObject]) -> ptr[PyTypeObject];

def get_builtin_base_with_dict(type: ptr[PyTypeObject]) -> ptr[PyTypeObject];

def get_dict_descriptor(type: ptr[PyTypeObject]) -> ptr[PyObject];

def raise_dict_descr_error(obj_: ptr[PyObject]);

def subtype_dict(obj_: ptr[PyObject], context: ptr) -> ptr[PyObject];

import from c {
    def _PyObject_SetDict(obj_: ptr[PyObject], value: ptr[PyObject]) -> i32 {
        if value and not dict_check(value) {
            PyErr_Format(
                PyExc_TypeError,
                "__dict__ must be set to a dictionary, not a '%.200s'",
                object_type(value).view(1)[0].tp_name
            );
            return i32(-1);
        }
        if type_has_feature(object_type(obj_), Py_TPFLAGS_MANAGED_DICT) {
            return _PyObject_SetManagedDict(obj_, value);
        }
        dictptr = _PyObject_ComputedDictPointer(obj_);
        if not dictptr {
            PyErr_SetString(PyExc_AttributeError, "This object has no __dict__");
            return i32(-1);
        }
        olddict = dictptr.view(1)[0];

        dictptr.view(1)[0] = object_new_ref(value);
        object_xdecref(olddict);
        return i32(0);
    }
}

def subtype_setdict(obj_: ptr[PyObject], value: ptr[PyObject], context: ptr) -> i32;

def subtype_getweakref(obj_: ptr[PyObject], context: ptr) -> ptr[PyObject];

import from c {
    glob:priv subtype_getsets_full: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__dict__"),
                 get=subtype_dict,
                 set=subtype_setdict,
                 doc=ptr[u8]("dictionary for instance variables")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__weakref__"),
                 get=subtype_getweakref,
                 doc=ptr[u8]("list of weak references to the object")
             ),
             PyGetSetDef()
         ],
         subtype_getsets_dict_only: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__dict__"),
                 get=subtype_dict,
                 set=subtype_setdict,
                 doc=ptr[u8]("dictionary for instance variables")
             ),
             PyGetSetDef()
         ],
         subtype_getsets_weakref_only: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__weakref__"),
                 get=subtype_getweakref,
                 doc=ptr[u8]("list of weak references to the object")
             ),
             PyGetSetDef()
         ];
}

def valid_identifier(s: ptr[PyObject]) -> i32;

def type_init(cls: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

import from c {
    def PyType_GetFlags(type: ptr[PyTypeObject]) -> u64 {
        return type.view(1)[0].tp_flags;
    }  def PyType_SUPPORTS_WEAKREFS(type: ptr[PyTypeObject]) -> i32 {
        if type.view(1)[0].tp_weaklistoffset != 0 {
            return i32(1);
        }
        return i32(0);
    }  def _PyType_CalculateMetaclass(
        metatype: ptr[PyTypeObject], bases: ptr[PyObject]
    ) -> ptr[PyTypeObject] {
        nbases = object_size(bases);
        winner = metatype;
        for i in range(nbases) {
            tmptype = object_type(tuple_get_item(bases, i));
            if PyType_IsSubtype(winner, tmptype) != 0 {
                continue;
            }
            if PyType_IsSubtype(tmptype, winner) != 0 {
                winner = tmptype;
                continue;
            }
            PyErr_SetString(
                PyExc_TypeError,
                "metaclass conflict: the metaclass of a derived class must be a (non-strict) subclass of the metaclasses of all its bases"
            );
            return ptr[PyTypeObject]();
        }
        return winner;
    }
}

glob:priv TYPE_NEW_CTX_SIZE: u64 = u64(88);

def type_new_visit_slots(ctx: ptr[TypeNewCtx]) -> i32;

def type_new_copy_slots(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]) -> ptr[PyObject];

def type_new_slots_bases(ctx: ptr[TypeNewCtx]);

def type_new_slots_impl(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]) -> i32;

def type_new_slots(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]) -> i64;

def type_new_alloc(ctx: ptr[TypeNewCtx]) -> ptr[PyTypeObject];

def type_new_set_name(ctx: ptr[TypeNewCtx], type: ptr[PyTypeObject]) -> i32;

def type_new_set_module(dct: ptr[PyObject]) -> i32;

def type_new_set_ht_name(type: ptr[PyTypeObject], dct: ptr[PyObject]) -> i32;

def type_new_set_doc(type: ptr[PyTypeObject], dct: ptr[PyObject]) -> i32;

def type_new_staticmethod(dct: ptr[PyObject], attr: ptr[PyObject]) -> i32;

def type_new_classmethod(dct: ptr[PyObject], attr: ptr[PyObject]) -> i32;

def type_new_descriptors(ctx: ptr[TypeNewCtx], type: ptr[PyTypeObject]) -> i32;

def type_new_set_slots(ctx: ptr[TypeNewCtx], type: ptr[PyTypeObject]);

def type_new_set_classcell(type: ptr[PyTypeObject], dct: ptr[PyObject]) -> i32;

def type_new_set_classdictcell(dct: ptr[PyObject]) -> i32;

def type_new_set_attrs(ctx: ptr[TypeNewCtx], type: ptr[PyTypeObject]) -> i32;

def type_new_get_slots(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]) -> i32;

def type_new_init(ctx: ptr[TypeNewCtx]) -> ptr[PyTypeObject];

def type_new_init_error(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]);

def type_new_impl(ctx: ptr[TypeNewCtx]) -> ptr[PyObject];

def type_new_get_bases(ctx: ptr[TypeNewCtx]) -> tuple[i32, ptr[PyObject]];

def type_new_bad_argument(iarg: i64, expected: ptr[u8], arg: ptr[PyObject]);

def type_new(
    metatype: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def type_vectorcall(
    metatype: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def _align_up(size: i64) -> i64;

import from c {
    obj SlotOffset {
        has subslot_offset: i64 = 0,
            slot_offset: i64 = 0;
    }  glob:priv pyslot_offsets: list[SlotOffset] = [
             SlotOffset(subslot_offset=0, slot_offset=0),
             SlotOffset(
                 subslot_offset=PyBufferProcs_BF_GETBUFFER,
                 slot_offset=PyTypeObject_TP_AS_BUFFER
             ),
             SlotOffset(
                 subslot_offset=PyBufferProcs_BF_RELEASEBUFFER,
                 slot_offset=PyTypeObject_TP_AS_BUFFER
             ),
             SlotOffset(
                 subslot_offset=PyMappingMethods_MP_ASS_SUBSCRIPT,
                 slot_offset=PyTypeObject_TP_AS_MAPPING
             ),
             SlotOffset(
                 subslot_offset=PyMappingMethods_MP_LENGTH,
                 slot_offset=PyTypeObject_TP_AS_MAPPING
             ),
             SlotOffset(
                 subslot_offset=PyMappingMethods_MP_SUBSCRIPT,
                 slot_offset=PyTypeObject_TP_AS_MAPPING
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_ABSOLUTE,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_ADD,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_AND,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_BOOL,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_DIVMOD,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_FLOAT,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_FLOOR_DIVIDE,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INDEX,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_ADD,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_AND,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_FLOOR_DIVIDE,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_LSHIFT,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_MULTIPLY,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_OR,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_POWER,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_REMAINDER,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_RSHIFT,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_SUBTRACT,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_TRUE_DIVIDE,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_XOR,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INT,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INVERT,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_LSHIFT,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_MULTIPLY,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_NEGATIVE,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_OR,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_POSITIVE,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_POWER,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_REMAINDER,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_RSHIFT,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_SUBTRACT,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_TRUE_DIVIDE,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_XOR,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PySequenceMethods_SQ_ASS_ITEM,
                 slot_offset=PyTypeObject_TP_AS_SEQUENCE
             ),
             SlotOffset(
                 subslot_offset=PySequenceMethods_SQ_CONCAT,
                 slot_offset=PyTypeObject_TP_AS_SEQUENCE
             ),
             SlotOffset(
                 subslot_offset=PySequenceMethods_SQ_CONTAINS,
                 slot_offset=PyTypeObject_TP_AS_SEQUENCE
             ),
             SlotOffset(
                 subslot_offset=PySequenceMethods_SQ_INPLACE_CONCAT,
                 slot_offset=PyTypeObject_TP_AS_SEQUENCE
             ),
             SlotOffset(
                 subslot_offset=PySequenceMethods_SQ_INPLACE_REPEAT,
                 slot_offset=PyTypeObject_TP_AS_SEQUENCE
             ),
             SlotOffset(
                 subslot_offset=PySequenceMethods_SQ_ITEM,
                 slot_offset=PyTypeObject_TP_AS_SEQUENCE
             ),
             SlotOffset(
                 subslot_offset=PySequenceMethods_SQ_LENGTH,
                 slot_offset=PyTypeObject_TP_AS_SEQUENCE
             ),
             SlotOffset(
                 subslot_offset=PySequenceMethods_SQ_REPEAT,
                 slot_offset=PyTypeObject_TP_AS_SEQUENCE
             ),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_ALLOC),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_BASE),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_BASES),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_CALL),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_CLEAR),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_DEALLOC),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_DEL),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_DESCR_GET),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_DESCR_SET),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_DOC),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_GETATTR),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_GETATTRO),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_HASH),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_INIT),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_IS_GC),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_ITER),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_ITERNEXT),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_METHODS),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_NEW),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_REPR),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_RICHCOMPARE),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_SETATTR),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_SETATTRO),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_STR),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_TRAVERSE),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_MEMBERS),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_GETSET),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_FREE),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_MATRIX_MULTIPLY,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyNumberMethods_NB_INPLACE_MATRIX_MULTIPLY,
                 slot_offset=PyTypeObject_TP_AS_NUMBER
             ),
             SlotOffset(
                 subslot_offset=PyAsyncMethods_AM_AWAIT,
                 slot_offset=PyTypeObject_TP_AS_ASYNC
             ),
             SlotOffset(
                 subslot_offset=PyAsyncMethods_AM_AITER,
                 slot_offset=PyTypeObject_TP_AS_ASYNC
             ),
             SlotOffset(
                 subslot_offset=PyAsyncMethods_AM_ANEXT,
                 slot_offset=PyTypeObject_TP_AS_ASYNC
             ),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_FINALIZE),
             SlotOffset(
                 subslot_offset=PyAsyncMethods_AM_SEND,
                 slot_offset=PyTypeObject_TP_AS_ASYNC
             ),
             SlotOffset(subslot_offset=-1, slot_offset=PyTypeObject_TP_VECTORCALL),
             SlotOffset(subslot_offset=-1, slot_offset=PyHeapTypeObject_HT_TOKEN)
         ];
}

glob:priv PYSLOT_OFFSETS_LEN: i64 = 84;

def get_bases_tuple(bases_in: ptr[PyObject], spec: ptr[PyType_Spec]) -> ptr[PyObject];

def check_basicsize_includes_size_and_offsets(type: ptr[PyTypeObject]) -> i32;

def check_immutable_bases(
    type_name: ptr[u8], bases: ptr[PyObject], skip_first: i32
) -> i32;

def special_offset_from_member(
    memb: ptr[PyMemberDef], type_data_offset: i64
) -> tuple[i32, i64];

def type_from_spec_finally(
    res: ptr[PyObject],
    bases: ptr[PyObject],
    tp_doc: ptr[u8],
    ht_name: ptr[PyObject],
    ht_tpname: ptr[u8]
) -> ptr[PyObject];

import from c {
    def PyType_FromMetaclass(
        metaclass: ptr[PyTypeObject],
        module: ptr[PyObject],
        spec: ptr[PyType_Spec],
        bases_in: ptr[PyObject]
    ) -> ptr[PyObject] {
        res: ptr[PyObject] = NULL;
        bases: ptr[PyObject] = NULL;
        tp_doc: ptr[u8] = ptr[u8]();
        ht_name: ptr[PyObject] = NULL;
        ht_tpname: ptr[u8] = ptr[u8]();
        r: i32 = 0;
        nmembers: i64 = 0;
        weaklistoffset_member: ptr[PyMemberDef] = ptr[PyMemberDef]();
        dictoffset_member: ptr[PyMemberDef] = ptr[PyMemberDef]();
        vectorcalloffset_member: ptr[PyMemberDef] = ptr[PyMemberDef]();
        spec_flags: u64 = u64(spec.view(1)[0].flags);

        slot = spec.view(1)[0].slots;
        while slot.view(1)[0].slot != 0 {
            slot_id = slot.view(1)[0].slot;
            if slot_id < 0 or i64(slot_id) >= PYSLOT_OFFSETS_LEN {
                PyErr_SetString(PyExc_RuntimeError, "invalid slot offset");
                return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
            }
            if slot_id == Py_tp_members {
                if nmembers != 0 {
                    PyErr_SetString(
                        PyExc_SystemError,
                        "Multiple Py_tp_members slots are not supported."
                    );
                    return type_from_spec_finally(
                        res, bases, tp_doc, ht_name, ht_tpname
                    );
                }
                memb = ptr[PyMemberDef](slot.view(1)[0].pfunc);
                while int(memb.view(1)[0].name) != 0 {
                    nmembers += 1;
                    if (memb.view(1)[0].flags & Py_RELATIVE_OFFSET) != 0 {
                        if spec.view(1)[0].basicsize > 0 {
                            PyErr_SetString(
                                PyExc_SystemError,
                                "With Py_RELATIVE_OFFSET, basicsize must be negative."
                            );
                            return type_from_spec_finally(
                                res, bases, tp_doc, ht_name, ht_tpname
                            );
                        }
                        if memb.view(1)[0].offset < 0
                            or memb.view(1)[0].offset
                                >= -i64(spec.view(1)[0].basicsize) {
                            PyErr_SetString(
                                PyExc_SystemError,
                                "Member offset out of range (0..-basicsize)"
                            );
                            return type_from_spec_finally(
                                res, bases, tp_doc, ht_name, ht_tpname
                            );
                        }
                    }
                    if strcmp(memb.view(1)[0].name, ptr[u8]("__weaklistoffset__"))
                        == 0 {
                        weaklistoffset_member = memb;
                    } elif strcmp(memb.view(1)[0].name, ptr[u8]("__dictoffset__"))
                        == 0 {
                        dictoffset_member = memb;
                    } elif strcmp(memb.view(1)[0].name, ptr[u8]("__vectorcalloffset__"))
                        == 0 {
                        vectorcalloffset_member = memb;
                    }
                    memb = memb + 1;
                }
            } elif slot_id == Py_tp_doc {
                if tp_doc {
                    PyErr_SetString(
                        PyExc_SystemError, "Multiple Py_tp_doc slots are not supported."
                    );
                    return type_from_spec_finally(
                        res, bases, tp_doc, ht_name, ht_tpname
                    );
                }
                if not slot.view(1)[0].pfunc {
                    PyMem_Free(ptr(tp_doc));
                    tp_doc = ptr[u8]();
                } else {
                    doc_len = strlen(ptr[u8](slot.view(1)[0].pfunc)) + u64(1);
                    tp_doc = ptr[u8](PyMem_Malloc(doc_len));
                    if not tp_doc {
                        PyErr_NoMemory();
                        return type_from_spec_finally(
                            res, bases, tp_doc, ht_name, ht_tpname
                        );
                    }
                    memcpy(ptr(tp_doc), slot.view(1)[0].pfunc, doc_len);
                }
            }
            slot = slot + 1;
        }

        spec_name = spec.view(1)[0].name;
        if not spec_name {
            PyErr_SetString(
                PyExc_SystemError, "Type spec does not define the name field."
            );
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        s = strrchr(spec_name, 46);
        if not s {
            s = spec_name;
        } else {
            s = s + 1;
        }
        ht_name = PyUnicode_FromString(s);
        if not ht_name {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }

        name_buf_len = strlen(spec_name) + u64(1);
        ht_tpname = ptr[u8](PyMem_Malloc(name_buf_len));
        if not ht_tpname {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        memcpy(ptr(ht_tpname), ptr(spec_name), name_buf_len);

        bases = get_bases_tuple(bases_in, spec);
        if not bases {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }

        if (spec_flags & Py_TPFLAGS_IMMUTABLETYPE) != u64(0) {
            if check_immutable_bases(spec_name, bases, 0) < 0 {
                return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
            }
        }

        meta: ptr[PyTypeObject] = metaclass;
        if not meta {
            meta = addressof(PyType_Type);
        }
        meta = _PyType_CalculateMetaclass(meta, bases);
        if not meta {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        if not type_check(ptr[PyObject](meta)) {
            PyErr_Format(
                PyExc_TypeError,
                "Metaclass '%R' is not a subclass of 'type'.",
                ptr[PyObject](meta)
            );
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        meta_new = int(meta.view(1)[0].tp_new);
        if meta_new != 0
            and meta_new != int(addressof(PyType_Type).view(1)[0].tp_new) {
            PyErr_SetString(
                PyExc_TypeError, "Metaclasses with custom tp_new are not supported."
            );
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }

        base = best_base(bases);
        if not base {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }

        basicsize: i64 = i64(spec.view(1)[0].basicsize);
        type_data_offset: i64 = i64(spec.view(1)[0].basicsize);
        if basicsize == 0 {
            basicsize = base.view(1)[0].tp_basicsize;
        } elif basicsize < 0 {
            type_data_offset = _align_up(base.view(1)[0].tp_basicsize);
            basicsize = type_data_offset + _align_up(-i64(spec.view(1)[0].basicsize));
            if base.view(1)[0].tp_itemsize != 0
                and ((base.view(1)[0].tp_flags | spec_flags) & Py_TPFLAGS_ITEMS_AT_END)
                    == u64(0) {
                PyErr_SetString(
                    PyExc_SystemError,
                    "Cannot extend variable-size class without Py_TPFLAGS_ITEMS_AT_END."
                );
                return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
            }
        }
        itemsize: i64 = i64(spec.view(1)[0].itemsize);

        (wl_status, weaklistoffset) = special_offset_from_member(
            weaklistoffset_member, type_data_offset
        );
        if wl_status < 0 {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        (dict_status, dictoffset) = special_offset_from_member(
            dictoffset_member, type_data_offset
        );
        if dict_status < 0 {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        (vc_status, vectorcalloffset) = special_offset_from_member(
            vectorcalloffset_member, type_data_offset
        );
        if vc_status < 0 {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }

        res = meta.view(1)[0].tp_alloc(meta, nmembers);
        if not res {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        res_start = ptr[u8](res);
        ht = ptr[PyHeapTypeObject](res);
        type = ptr[PyTypeObject](res);

        type_set_flags(type, spec_flags | Py_TPFLAGS_HEAPTYPE);
        ht.view(1)[0].ht_module = object_xnewref(module);

        type.view(1)[0].tp_as_async = ptr[PyAsyncMethods](
            res_start + PyHeapTypeObject_AS_ASYNC
        );
        type.view(1)[0].tp_as_number = ptr[PyNumberMethods](
            res_start + PyHeapTypeObject_AS_NUMBER
        );
        type.view(1)[0].tp_as_sequence = ptr[PySequenceMethods](
            res_start + PyHeapTypeObject_AS_SEQUENCE
        );
        type.view(1)[0].tp_as_mapping = ptr[PyMappingMethods](
            res_start + PyHeapTypeObject_AS_MAPPING
        );
        type.view(1)[0].tp_as_buffer = ptr[PyBufferProcs](
            res_start + PyHeapTypeObject_AS_BUFFER
        );

        type.view(1)[0].tp_base = ptr[PyTypeObject](
            object_new_ref(ptr[PyObject](base))
        );
        set_tp_bases(type, bases, 1);
        bases = NULL;
        type.view(1)[0].tp_doc = tp_doc;
        tp_doc = ptr[u8]();
        ht.view(1)[0].ht_qualname = object_new_ref(ht_name);
        ht.view(1)[0].ht_name = ht_name;
        ht_name = NULL;
        type.view(1)[0].tp_name = ht_tpname;
        ht.view(1)[0]._ht_tpname = ht_tpname;
        ht_tpname = ptr[u8]();

        type.view(1)[0].tp_basicsize = basicsize;
        type.view(1)[0].tp_itemsize = itemsize;

        slot = spec.view(1)[0].slots;
        while slot.view(1)[0].slot != 0 {
            slot_id = slot.view(1)[0].slot;
            pfunc = slot.view(1)[0].pfunc;
            if slot_id == Py_tp_base
                or slot_id == Py_tp_bases
                or slot_id == Py_tp_doc {
                slot = slot + 1;
                continue;
            }
            if slot_id == Py_tp_members {
                members_len = object_type(ptr[PyObject](type)).view(1)[0].tp_itemsize
                    * nmembers;
                members = _PyHeapType_GET_MEMBERS(type);
                memcpy(ptr(members), pfunc, u64(members_len));
                type.view(1)[0].tp_members = members;
                memb = members;
                i: i64 = nmembers;
                while i > 0 {
                    if (memb.view(1)[0].flags & Py_RELATIVE_OFFSET) != 0 {
                        memb.view(1)[0].flags = memb.view(1)[0].flags
                            & ~Py_RELATIVE_OFFSET;
                        memb.view(1)[0].offset = memb.view(1)[0].offset
                            + type_data_offset;
                    }
                    memb = memb + 1;
                    i -= 1;
                }
            } elif slot_id == Py_tp_token {
                if not pfunc {
                    ht.view(1)[0].ht_token = ptr(spec);
                } else {
                    ht.view(1)[0].ht_token = pfunc;
                }
            } else {
                offsets = addressof(pyslot_offsets) + i64(slot_id);
                slot_offset = offsets.view(1)[0].slot_offset;
                subslot_offset = offsets.view(1)[0].subslot_offset;
                if subslot_offset == -1 {
                    ptr[ptr](res_start + slot_offset).view(1)[0] = pfunc;
                } else {
                    procs = ptr[ptr](res_start + slot_offset).view(1)[0];
                    ptr[ptr](ptr[u8](procs) + subslot_offset).view(1)[0] = pfunc;
                }
            }
            slot = slot + 1;
        }
        if int(type.view(1)[0].tp_dealloc) == 0 {
            type.view(1)[0].tp_dealloc = subtype_dealloc;
        }

        type.view(1)[0].tp_vectorcall_offset = vectorcalloffset;
        type.view(1)[0].tp_weaklistoffset = weaklistoffset;
        type.view(1)[0].tp_dictoffset = dictoffset;

        if PyType_Ready(type) < 0 {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        if check_basicsize_includes_size_and_offsets(type) == 0 {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        dct = lookup_tp_dict(type);
        if type.view(1)[0].tp_doc {
            doc_obj = PyUnicode_FromString(
                _PyType_DocWithoutSignature(
                    type.view(1)[0].tp_name, type.view(1)[0].tp_doc
                )
            );
            if not doc_obj {
                return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
            }
            r = PyDict_SetItem(dct, py_id(_Py_ID___doc__), doc_obj);
            object_decref(doc_obj);
            if r < 0 {
                return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
            }
        }
        if weaklistoffset != 0 {
            if PyDict_DelItem(dct, py_id(_Py_ID___weaklistoffset__)) < 0 {
                return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
            }
        }
        if dictoffset != 0 {
            if PyDict_DelItem(dct, py_id(_Py_ID___dictoffset__)) < 0 {
                return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
            }
        }

        r = PyDict_Contains(dct, py_id(_Py_ID___module__));
        if r < 0 {
            return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
        }
        if r == 0 {
            s = strrchr(spec_name, 46);
            if s {
                modname_len = i64(int(s) - int(spec_name));
                modname = PyUnicode_FromStringAndSize(spec_name, modname_len);
                if not modname {
                    return type_from_spec_finally(
                        res, bases, tp_doc, ht_name, ht_tpname
                    );
                }
                r = PyDict_SetItem(dct, py_id(_Py_ID___module__), modname);
                object_decref(modname);
                if r != 0 {
                    return type_from_spec_finally(
                        res, bases, tp_doc, ht_name, ht_tpname
                    );
                }
            } elif PyErr_WarnFormat(
                PyExc_DeprecationWarning,
                1,
                "builtin type %.200s has no __module__ attribute",
                spec_name
            )
                != 0 {
                return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
            }
        }
        return type_from_spec_finally(res, bases, tp_doc, ht_name, ht_tpname);
    }  def PyType_FromModuleAndSpec(
        module: ptr[PyObject], spec: ptr[PyType_Spec], bases: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyType_FromMetaclass(ptr[PyTypeObject](), module, spec, bases);
    }  def PyType_FromSpecWithBases(
        spec: ptr[PyType_Spec], bases: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyType_FromMetaclass(ptr[PyTypeObject](), NULL, spec, bases);
    }  def PyType_FromSpec(spec: ptr[PyType_Spec]) -> ptr[PyObject] {
        return PyType_FromMetaclass(ptr[PyTypeObject](), NULL, spec, NULL);
    }  def PyType_GetName(type: ptr[PyTypeObject]) -> ptr[PyObject] {
        return type_name(ptr[PyObject](type), ptr());
    }  def PyType_GetQualName(type: ptr[PyTypeObject]) -> ptr[PyObject] {
        return type_qualname(ptr[PyObject](type), ptr());
    }  def PyType_GetModuleName(type: ptr[PyTypeObject]) -> ptr[PyObject] {
        return type_module(type);
    }  def PyType_GetSlot(type: ptr[PyTypeObject], slot: i32) -> ptr {
        if slot <= 0 or i64(slot) >= PYSLOT_OFFSETS_LEN {
            PyErr_BadInternalCall();
            return ptr();
        }
        offsets = addressof(pyslot_offsets) + i64(slot);
        slot_offset = offsets.view(1)[0].slot_offset;
        if slot_offset >= PyTypeObject_SIZE {
            if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
                return ptr();
            }
        }
        parent_slot = ptr[ptr](ptr[u8](type) + slot_offset).view(1)[0];
        if not parent_slot {
            return ptr();
        }

        if offsets.view(1)[0].subslot_offset == -1 {
            return parent_slot;
        }
        return ptr[ptr](ptr[u8](parent_slot) + offsets.view(1)[0].subslot_offset).view(
            1
        )[0];
    }  def PyType_GetModule(type: ptr[PyTypeObject]) -> ptr[PyObject] {
        if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
            PyErr_Format(
                PyExc_TypeError,
                "PyType_GetModule: Type '%s' is not a heap type",
                type.view(1)[0].tp_name
            );
            return NULL;
        }
        module = ptr[PyHeapTypeObject](type).view(1)[0].ht_module;
        if not module {
            PyErr_Format(
                PyExc_TypeError,
                "PyType_GetModule: Type '%s' has no associated module",
                type.view(1)[0].tp_name
            );
            return NULL;
        }
        return module;
    }  def PyType_GetModuleState(type: ptr[PyTypeObject]) -> ptr {
        m = PyType_GetModule(type);
        if not m {
            return ptr();
        }

        return ptr[PyModuleObject](m).view(1)[0].md_state;
    }  def PyType_GetModuleByDef(
        type: ptr[PyTypeObject], mod_def: ptr[PyModuleDef]
    ) -> ptr[PyObject] {
        if type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
            module = ptr[PyHeapTypeObject](type).view(1)[0].ht_module;

            if module
                and int(ptr[PyModuleObject](module).view(1)[0].md_def)
                    == int(mod_def) {
                return module;
            }

            mro = lookup_tp_mro(type);
            n = object_size(mro);
            i: i64 = 1;
            while i < n {
                su = ptr[PyTypeObject](tuple_get_item(mro, i));

                if type_has_feature(su, Py_TPFLAGS_HEAPTYPE) {
                    module = ptr[PyHeapTypeObject](su).view(1)[0].ht_module;
                    if module
                        and int(ptr[PyModuleObject](module).view(1)[0].md_def)
                            == int(mod_def) {
                        return module;
                    }
                }
                i += 1;
            }
        }
        PyErr_Format(
            PyExc_TypeError,
            "PyType_GetModuleByDef: No superclass of '%s' has the given module",
            type.view(1)[0].tp_name
        );
        return NULL;
    }
}

def get_base_by_token_recursive(bases: ptr[PyObject], token: ptr) -> ptr[PyTypeObject];

import from c {
    def _PyType_GetBaseByToken_Borrow(
        type: ptr[PyTypeObject], token: ptr, result: ptr[ptr[PyTypeObject]]
    ) -> i32 {
        if result {
            result.view(1)[0] = ptr[PyTypeObject]();
        }
        if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
            return 0;
        }
        if int(ptr[PyHeapTypeObject](type).view(1)[0].ht_token) == int(token) {
            if result {
                result.view(1)[0] = type;
            }
            return 1;
        }

        mro = type.view(1)[0].tp_mro;
        if not mro {
            base = get_base_by_token_recursive(lookup_tp_bases(type), token);
            if base {
                if result {
                    result.view(1)[0] = base;
                }
                return 1;
            }
            return 0;
        }

        n = object_size(mro);
        i: i64 = 1;
        while i < n {
            candidate = ptr[PyTypeObject](tuple_get_item(mro, i));
            if type_has_feature(candidate, Py_TPFLAGS_HEAPTYPE)
                and int(ptr[PyHeapTypeObject](candidate).view(1)[0].ht_token)
                    == int(token) {
                if result {
                    result.view(1)[0] = candidate;
                }
                return 1;
            }
            i += 1;
        }
        return 0;
    }  def PyType_GetBaseByToken(
        type: ptr[PyTypeObject], token: ptr, result: ptr[ptr[PyTypeObject]]
    ) -> i32 {
        if result {
            result.view(1)[0] = ptr[PyTypeObject]();
        }
        if not token {
            PyErr_Format(
                PyExc_SystemError, "PyType_GetBaseByToken called with token=NULL"
            );
            return -1;
        }
        if not type_check(ptr[PyObject](type)) {
            PyErr_Format(
                PyExc_TypeError,
                "expected a type, got a '%T' object",
                ptr[PyObject](type)
            );
            return -1;
        }
        res = _PyType_GetBaseByToken_Borrow(type, token, result);
        if res > 0 and result {
            object_incref(ptr[PyObject](result.view(1)[0]));
        }
        return res;
    }  def PyObject_GetTypeData(obj_: ptr[PyObject], cls: ptr[PyTypeObject]) -> ptr {
        return ptr(
            ptr[u8](obj_) + _align_up(cls.view(1)[0].tp_base.view(1)[0].tp_basicsize)
        );
    }  def PyType_GetTypeDataSize(cls: ptr[PyTypeObject]) -> i64 {
        result: i64 = cls.view(1)[0].tp_basicsize
            - _align_up(cls.view(1)[0].tp_base.view(1)[0].tp_basicsize);
        if result < 0 {
            return 0;
        }
        return result;
    }  def PyObject_GetItemData(obj_: ptr[PyObject]) -> ptr {
        tp = object_type(obj_);
        if not type_has_feature(tp, Py_TPFLAGS_ITEMS_AT_END) {
            PyErr_Format(
                PyExc_TypeError,
                "type '%s' does not have Py_TPFLAGS_ITEMS_AT_END",
                tp.view(1)[0].tp_name
            );
            return ptr();
        }
        return ptr(ptr[u8](obj_) + tp.view(1)[0].tp_basicsize);
    }
}

import from c {
    glob:priv type_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__basicsize__"),
                 type_=Py_T_PYSSIZET,
                 offset=PyTypeObject_TP_BASICSIZE,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__itemsize__"),
                 type_=Py_T_PYSSIZET,
                 offset=PyTypeObject_TP_ITEMSIZE,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__flags__"),
                 type_=Py_T_ULONG,
                 offset=PyTypeObject_TP_FLAGS,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__weakrefoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=PyTypeObject_TP_WEAKLISTOFFSET,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__base__"),
                 type_=_Py_T_OBJECT,
                 offset=PyTypeObject_TP_BASE,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=PyTypeObject_TP_DICTOFFSET,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ];
}

def type_dealloc_common(type: ptr[PyTypeObject]);

def clear_static_tp_subclasses(type: ptr[PyTypeObject], isbuiltin: i32);

def clear_static_type_objects(
    interp: ptr[u8], type: ptr[PyTypeObject], isbuiltin: i32, final: i32
);

def fini_static_type(
    interp: ptr[u8], type: ptr[PyTypeObject], isbuiltin: i32, final: i32
);

import from c {
    def _PyTypes_FiniExtTypes(interp: ptr[u8]) {
        i: i64 = _Py_MAX_MANAGED_STATIC_EXT_TYPES;
        while i > 0 {
            num_initialized = ptr[i64](
                interp + PyInterpreterState_TYPES_EXT_NUM_INITIALIZED
            ).view(
                1
            )[0];
            if num_initialized == 0 {
                break;
            }
            (type, count) = static_ext_type_lookup(interp, i - 1);
            i -= 1;
            if not type {
                continue;
            }
            final: i32 = 0;
            if count == 1 {
                final = 1;
            }
            fini_static_type(interp, type, 0, final);
        }
    }  def _PyStaticType_FiniBuiltin(interp: ptr[u8], type: ptr[PyTypeObject]) {
        is_main: i32 = 0;
        if interp == ptr[u8](_PyInterpreterState_Main()) {
            is_main = 1;
        }
        fini_static_type(interp, type, 1, is_main);
    }
}

def type_dealloc(self_: ptr[PyObject]);

def type___subclasses___impl(self_: ptr[PyTypeObject]) -> ptr[PyObject];

def type___subclasses__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def type_prepare(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def merge_class_dict(dct: ptr[PyObject], aclass: ptr[PyObject]) -> i32;

def type___dir___impl(self_: ptr[PyTypeObject]) -> ptr[PyObject];

def type___dir__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def type___sizeof___impl(self_: ptr[PyTypeObject]) -> ptr[PyObject];

def type___sizeof__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv type_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("mro"),
                 ml_meth=ptr(type_mro),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "mro($self, /)\n--\n\nReturn a type's method resolution order."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__subclasses__"),
                 ml_meth=ptr(type___subclasses__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__subclasses__($self, /)\n--\n\nReturn a list of immediate subclasses."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__prepare__"),
                 ml_meth=ptr(type_prepare),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS | METH_CLASS,
                 ml_doc=ptr[u8](
                     "__prepare__($cls, name, bases, /, **kwds)\n--\n\n"
                     "Create the namespace for the class statement"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__instancecheck__"),
                 ml_meth=ptr(type___instancecheck__),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "__instancecheck__($self, instance, /)\n--\n\n"
                     "Check if an object is an instance."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__subclasscheck__"),
                 ml_meth=ptr(type___subclasscheck__),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "__subclasscheck__($self, subclass, /)\n--\n\n"
                     "Check if a class is a subclass."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__dir__"),
                 ml_meth=ptr(type___dir__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__dir__($self, /)\n--\n\n"
                     "Specialized __dir__ implementation for types."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(type___sizeof__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__sizeof__($self, /)\n--\n\n"
                     "Return memory consumption of the type object."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ];
}

def type_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def type_clear(self_: ptr[PyObject]) -> i32;

def type_tp_is_gc(tp: ptr[PyObject]) -> i32;

import from c {
    glob:priv type_as_number: PyNumberMethods = PyNumberMethods(
             nb_or=_Py_union_type_or
         ); glob PyType_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("type"),
             tp_basicsize=PyHeapTypeObject_SIZE,
             tp_itemsize=PY_MEMBER_DEF_SIZE,
             tp_dealloc=type_dealloc,
             tp_vectorcall_offset=PyTypeObject_TP_VECTORCALL,
             tp_repr=type_repr,
             tp_as_number=addressof(type_as_number),
             tp_call=type_call,
             tp_getattro=_Py_type_getattro,
             tp_setattro=type_setattro,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_TYPE_SUBCLASS
                 | Py_TPFLAGS_HAVE_VECTORCALL
                 | Py_TPFLAGS_ITEMS_AT_END,
             tp_doc=ptr[u8](
                 "type(object) -> the object's type\n"
                 "type(name, bases, dict, **kwds) -> a new type"
             ),
             tp_traverse=type_traverse,
             tp_clear=type_clear,
             tp_weaklistoffset=PyTypeObject_TP_WEAKLIST,
             tp_methods=addressof(type_methods),
             tp_members=addressof(type_members),
             tp_getset=addressof(type_getsets),
             tp_dictoffset=PyTypeObject_TP_DICT,
             tp_init=type_init,
             tp_new=type_new,
             tp_free=PyObject_GC_Del,
             tp_is_gc=type_tp_is_gc,
             tp_vectorcall=type_vectorcall
         );
}

def excess_args(args: ptr[PyObject], kwds: ptr[PyObject]) -> bool;

def object_init(self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

def object_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def object_new_abstract_error(type: ptr[PyTypeObject]) -> ptr[PyObject];

def object_dealloc(self_: ptr[PyObject]);

def object_repr(self_: ptr[PyObject]) -> ptr[PyObject];

def object_str(self_: ptr[PyObject]) -> ptr[PyObject];

def object_richcompare(
    self_: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject];

import from c {
    def _Py_BaseObject_RichCompare(
        self_: ptr[PyObject], other: ptr[PyObject], op: i32
    ) -> ptr[PyObject] {
        return object_richcompare(self_, other, op);
    }
}

def object_get_class(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def compatible_with_tp_base(child: ptr[PyTypeObject]) -> i32;

def same_slots_added(a: ptr[PyTypeObject], b: ptr[PyTypeObject]) -> i32;

def compatible_for_assignment(
    oldto: ptr[PyTypeObject], newto: ptr[PyTypeObject], attr: ptr[u8]
) -> i32;

def object_set_class_world_stopped(
    self_: ptr[PyObject], newto: ptr[PyTypeObject]
) -> i32;

def object_set_class(self_: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32;

import from c {
    glob:priv object_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__class__"),
                 get=object_get_class,
                 set=object_set_class,
                 doc=ptr[u8]("the object's class")
             ),
             PyGetSetDef()
         ];
}

def import_copyreg -> ptr[PyObject];

def _PyType_GetSlotNames(cls: ptr[PyTypeObject]) -> ptr[PyObject];

def object_getstate_default(obj_: ptr[PyObject], required: i32) -> ptr[PyObject];

def object_getstate(obj_: ptr[PyObject], required: i32) -> ptr[PyObject];

import from c {
    def _PyObject_GetState(obj_: ptr[PyObject]) -> ptr[PyObject] {
        return object_getstate(obj_, 0);
    }
}

def object___getstate___impl(self_: ptr[PyObject]) -> ptr[PyObject];

def object___getstate__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def _PyObject_GetNewArguments(
    obj_: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]];

def _PyObject_GetItemsIter(
    obj_: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]];

def reduce_newobj(obj_: ptr[PyObject]) -> ptr[PyObject];

def _common_reduce(self_: ptr[PyObject], proto: i32) -> ptr[PyObject];

def object___reduce___impl(self_: ptr[PyObject]) -> ptr[PyObject];

def object___reduce__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def object___reduce_ex___impl(self_: ptr[PyObject], protocol: i32) -> ptr[PyObject];

def object___reduce_ex__(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def object_subclasshook(cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def object_init_subclass(cls: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def object___format___impl(
    self_: ptr[PyObject], format_spec: ptr[PyObject]
) -> ptr[PyObject];

def object___format__(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def object___sizeof___impl(self_: ptr[PyObject]) -> ptr[PyObject];

def object___sizeof__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def object___dir___impl(self_: ptr[PyObject]) -> ptr[PyObject];

def object___dir__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv object_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce_ex__"),
                 ml_meth=ptr(object___reduce_ex__),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "__reduce_ex__($self, protocol, /)\n--\n\nHelper for pickle."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(object___reduce__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__reduce__($self, /)\n--\n\nHelper for pickle.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__getstate__"),
                 ml_meth=ptr(object___getstate__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__getstate__($self, /)\n--\n\nHelper for pickle.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__subclasshook__"),
                 ml_meth=ptr(object_subclasshook),
                 ml_flags=METH_CLASS | METH_O,
                 ml_doc=ptr[u8](
                     "Abstract classes can override this to customize issubclass().\n\nThis is invoked early on by abc.ABCMeta.__subclasscheck__().\nIt should return True, False or NotImplemented.  If it returns\nNotImplemented, the normal algorithm is used.  Otherwise, it\noverrides the normal algorithm (and the outcome is cached).\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__init_subclass__"),
                 ml_meth=ptr(object_init_subclass),
                 ml_flags=METH_CLASS | METH_NOARGS,
                 ml_doc=ptr[u8](
                     "This method is called when a class is subclassed.\n\nThe default implementation does nothing. It may be\noverridden to extend subclasses.\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__format__"),
                 ml_meth=ptr(object___format__),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "__format__($self, format_spec, /)\n--\n\nDefault object formatter.\n\nReturn str(self) if format_spec is empty. Raise TypeError otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(object___sizeof__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__sizeof__($self, /)\n--\n\nSize of object in memory, in bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__dir__"),
                 ml_meth=ptr(object___dir__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__dir__($self, /)\n--\n\nDefault dir() implementation."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyBaseObject_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("object"),
             tp_basicsize=PyObject_HEAD_SIZE,
             tp_dealloc=object_dealloc,
             tp_repr=object_repr,
             tp_hash=PyObject_GenericHash,
             tp_str=object_str,
             tp_getattro=PyObject_GenericGetAttr,
             tp_setattro=PyObject_GenericSetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "object()\n--\n\nThe base class of the class hierarchy.\n\nWhen called, it accepts no arguments and returns a new featureless\ninstance that has no instance attributes and cannot be given any.\n"
             ),
             tp_richcompare=object_richcompare,
             tp_methods=addressof(object_methods),
             tp_getset=addressof(object_getsets),
             tp_init=object_init,
             tp_alloc=PyType_GenericAlloc,
             tp_new=object_new,
             tp_free=PyObject_Free
         );
}

glob:priv COLLECTION_FLAGS: u64 = Py_TPFLAGS_SEQUENCE | Py_TPFLAGS_MAPPING;

def type_add_method(type: ptr[PyTypeObject], meth: ptr[PyMethodDef]) -> i32;

import from c {
    def _PyType_AddMethod(type: ptr[PyTypeObject], meth: ptr[PyMethodDef]) -> i32 {
        return type_add_method(type, meth);
    }
}

def type_add_methods(type: ptr[PyTypeObject]) -> i32;

def type_add_members(type: ptr[PyTypeObject]) -> i32;

def type_add_getset(type: ptr[PyTypeObject]) -> i32;

def inherit_special(type: ptr[PyTypeObject], base: ptr[PyTypeObject]);

def overrides_hash(type: ptr[PyTypeObject]) -> i32;

def inherit_slots(type: ptr[PyTypeObject], base: ptr[PyTypeObject]) -> i32;

def type_ready_pre_checks(type: ptr[PyTypeObject]) -> i32;

def type_ready_set_base(type: ptr[PyTypeObject]) -> i32;

def type_ready_set_type(type: ptr[PyTypeObject]) -> i32;

def type_ready_set_bases(type: ptr[PyTypeObject], initial: i32) -> i32;

def type_ready_set_dict(type: ptr[PyTypeObject]) -> i32;

def type_dict_set_doc(type: ptr[PyTypeObject]) -> i32;

def type_ready_fill_dict(type: ptr[PyTypeObject]) -> i32;

def type_ready_preheader(type: ptr[PyTypeObject]) -> i32;

def type_ready_mro(type: ptr[PyTypeObject], initial: i32) -> i32;

def type_ready_inherit_as_structs(type: ptr[PyTypeObject], base: ptr[PyTypeObject]);

def inherit_patma_flags(type: ptr[PyTypeObject], base: ptr[PyTypeObject]);

def type_ready_inherit(type: ptr[PyTypeObject]) -> i32;

def type_ready_set_hash(type: ptr[PyTypeObject]) -> i32;

def type_ready_add_subclasses(type: ptr[PyTypeObject]) -> i32;

def type_ready_set_new(type: ptr[PyTypeObject], initial: i32) -> i32;

def type_ready_managed_dict(type: ptr[PyTypeObject]) -> i32;

def type_ready_post_checks(type: ptr[PyTypeObject]) -> i32;

def type_ready(type: ptr[PyTypeObject], initial: i32) -> i32;

import from c {
    def PyType_Ready(type: ptr[PyTypeObject]) -> i32 {
        if type_has_feature(type, Py_TPFLAGS_READY) {
            return 0;
        }

        if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
            type_add_flags(type, Py_TPFLAGS_IMMUTABLETYPE);
            _Py_SetImmortalUntracked(ptr[PyObject](type));
        }
        res: i32 = 0;
        if not type_has_feature(type, Py_TPFLAGS_READY) {
            res = type_ready(type, 1);
        }
        return res;
    }
}

def init_static_type(
    interp: ptr[u8], self_: ptr[PyTypeObject], isbuiltin: i32, initial: i32
) -> i32;

import from c {
    def _PyStaticType_InitForExtension(
        interp: ptr[u8], self_: ptr[PyTypeObject]
    ) -> i32 {
        initial: i32 = 0;
        if (self_.view(1)[0].tp_flags & Py_TPFLAGS_READY) == 0 {
            initial = 1;
        }
        return init_static_type(interp, self_, 0, initial);
    }  def _PyStaticType_InitBuiltin(interp: ptr[u8], self_: ptr[PyTypeObject]) -> i32 {
        initial: i32 = 0;
        if interp == ptr[u8](_PyInterpreterState_Main()) {
            initial = 1;
        }
        return init_static_type(interp, self_, 1, initial);
    }
}

def add_subclass(base: ptr[PyTypeObject], type: ptr[PyTypeObject]) -> i32;

def add_all_subclasses(type: ptr[PyTypeObject], bases: ptr[PyObject]) -> i32;

def get_subclasses_key(
    type: ptr[PyTypeObject], base: ptr[PyTypeObject]
) -> ptr[PyObject];

def remove_subclass(base: ptr[PyTypeObject], type: ptr[PyTypeObject]);

def remove_all_subclasses(type: ptr[PyTypeObject], bases: ptr[PyObject]);

def check_num_args(ob: ptr[PyObject], n: i32) -> i32;

def check_pow_args(ob: ptr[PyObject]) -> i64;

def wrap_lenfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_inquirypred(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_binaryfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_binaryfunc_l(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_binaryfunc_r(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_ternaryfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_ternaryfunc_r(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_unaryfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_indexargfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def getindex(self_: ptr[PyObject], arg: ptr[PyObject]) -> i64;

def wrap_sq_item(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_sq_setitem(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_sq_delitem(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_objobjproc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_objobjargproc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_delitem(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def hackcheck_unlocked(self_: ptr[PyObject], func: ptr, what: ptr[u8]) -> i32;

def hackcheck(self_: ptr[PyObject], func: ptr, what: ptr[u8]) -> i32;

def wrap_setattr(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_delattr(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_hashfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_call(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr, kwds: ptr[PyObject]
) -> ptr[PyObject];

def wrap_del(self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr) -> ptr[PyObject];

def wrap_richcmpfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr, op: i32
) -> ptr[PyObject];

def richcmp_lt(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def richcmp_le(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def richcmp_eq(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def richcmp_ne(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def richcmp_gt(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def richcmp_ge(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_next(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_descr_get(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_descr_set(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_descr_delete(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_buffer(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_releasebuffer(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject];

def wrap_init(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr, kwds: ptr[PyObject]
) -> ptr[PyObject];

def tp_new_wrapper(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    glob:priv tp_new_methoddef: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__new__"),
                 ml_meth=ptr(tp_new_wrapper),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "__new__($type, *args, **kwargs)\n--\n\nCreate and return a new object.  See help(type) for accurate signature."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ];
}

def add_tp_new_wrapper(type: ptr[PyTypeObject]) -> i32;

def method_is_overloaded(
    left: ptr[PyObject], right: ptr[PyObject], name: ptr[PyObject]
) -> i32;

def slot_sq_length(self_: ptr[PyObject]) -> i64;

def slot_sq_item(self_: ptr[PyObject], i: i64) -> ptr[PyObject];

def slot_sq_ass_item(self_: ptr[PyObject], index: i64, value: ptr[PyObject]) -> i32;

def slot_sq_contains(self_: ptr[PyObject], value: ptr[PyObject]) -> i32;

def slot_mp_subscript(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject];

def slot_mp_ass_subscript(
    self_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def slot_nb_add(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_subtract(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_multiply(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_matrix_multiply(
    self_: ptr[PyObject], other: ptr[PyObject]
) -> ptr[PyObject];

def slot_nb_remainder(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_divmod(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_power_binary(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_power(
    self_: ptr[PyObject], other: ptr[PyObject], modulus: ptr[PyObject]
) -> ptr[PyObject];

def slot_nb_negative(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_positive(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_absolute(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_bool(self_: ptr[PyObject]) -> i32;

def slot_nb_index(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_invert(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_lshift(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_rshift(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_and(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_xor(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_or(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_int(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_float(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_inplace_add(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_inplace_subtract(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject];

def slot_nb_inplace_multiply(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject];

def slot_nb_inplace_matrix_multiply(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject];

def slot_nb_inplace_remainder(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject];

def slot_nb_inplace_power(
    self_: ptr[PyObject], arg1: ptr[PyObject], arg2: ptr[PyObject]
) -> ptr[PyObject];

def slot_nb_inplace_lshift(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_inplace_rshift(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_inplace_and(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_inplace_xor(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_inplace_or(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_floor_divide(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_true_divide(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def slot_nb_inplace_floor_divide(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject];

def slot_nb_inplace_true_divide(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject];

def slot_tp_repr(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_tp_str(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_tp_hash(self_: ptr[PyObject]) -> i64;

def slot_tp_call(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def _Py_slot_tp_getattro(
        self_: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        slots: own StackArgs = StackArgs();
        stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = name;
        return vectorcall_method(py_id(_Py_ID___getattribute__), stack, 2);
    }
}

def call_attribute(
    self_: ptr[PyObject], attr: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def _Py_slot_tp_getattr_hook(
        self_: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        tp = object_type(self_);

        getattr_fn = _PyType_LookupRef(tp, py_id(_Py_ID___getattr__));
        if not getattr_fn {
            tp.view(1)[0].tp_getattro = _Py_slot_tp_getattro;
            return _Py_slot_tp_getattro(self_, name);
        }

        getattribute = _PyType_LookupRef(tp, py_id(_Py_ID___getattribute__));
        res = NULL;

        use_generic = False;
        if not getattribute {
            use_generic = True;
        } elif object_is_type(getattribute, addressof(PyWrapperDescr_Type)) {
            wrapped = ptr[ptr](
                ptr[u8](getattribute) + PyWrapperDescrObject_WRAPPED
            ).view(
                1
            )[0];
            if int(wrapped) == int(ptr(PyObject_GenericGetAttr)) {
                use_generic = True;
            }
        }
        if use_generic {
            object_xdecref(getattribute);
            res = _PyObject_GenericGetAttrWithDict(self_, name, NULL, i32(1));

            if not res and not PyErr_Occurred() {
                res = call_attribute(self_, getattr_fn, name);
            }
        } else {
            res = call_attribute(self_, getattribute, name);
            object_decref(getattribute);
            if not res and PyErr_ExceptionMatches(PyExc_AttributeError) != 0 {
                PyErr_Clear();
                res = call_attribute(self_, getattr_fn, name);
            }
        }
        object_decref(getattr_fn);
        return res;
    }
}

def slot_tp_setattro(
    self_: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32;

import from c {
    glob:priv name_op: list[i64] = [
             _Py_ID___lt__,
             _Py_ID___le__,
             _Py_ID___eq__,
             _Py_ID___ne__,
             _Py_ID___gt__,
             _Py_ID___ge__
         ];
}

def slot_tp_richcompare(
    self_: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject];

def has_dunder_getitem(self_: ptr[PyObject]) -> i32;

def slot_tp_iter(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_tp_iternext(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_tp_descr_get(
    self_: ptr[PyObject], obj_: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def slot_tp_descr_set(
    self_: ptr[PyObject], target: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def slot_tp_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def slot_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def slot_tp_finalize(self_: ptr[PyObject]);

def bufferwrapper_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def bufferwrapper_dealloc(self_: ptr[PyObject]);

def bufferwrapper_releasebuf(self_: ptr[PyObject], view: ptr[Py_buffer]);

import from c {
    glob:priv bufferwrapper_as_buffer: PyBufferProcs = PyBufferProcs(
             bf_releasebuffer=bufferwrapper_releasebuf
         ); glob _PyBufferWrapper_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("_buffer_wrapper"),
             tp_basicsize=32,
             tp_dealloc=bufferwrapper_dealloc,
             tp_as_buffer=addressof(bufferwrapper_as_buffer),
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=bufferwrapper_traverse,
             tp_alloc=PyType_GenericAlloc,
             tp_free=PyObject_GC_Del
         );
}

def slot_bf_getbuffer(self_: ptr[PyObject], buffer: ptr[Py_buffer], flags: i32) -> i32;

def releasebuffer_maybe_call_super_unlocked(
    self_: ptr[PyObject], buffer: ptr[Py_buffer]
) -> int;

def releasebuffer_maybe_call_super(self_: ptr[PyObject], buffer: ptr[Py_buffer]);

def releasebuffer_call_python(self_: ptr[PyObject], buffer: ptr[Py_buffer]);

def slot_bf_releasebuffer(self_: ptr[PyObject], buffer: ptr[Py_buffer]);

def slot_am_generic(self_: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def slot_am_await(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_am_aiter(self_: ptr[PyObject]) -> ptr[PyObject];

def slot_am_anext(self_: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv slotdefs: list[SlotDef] = [
             SlotDef(
                 name=ptr[u8]("__getattribute__"),
                 offset=SLOTDEF_TP_GETATTR,
                 function=ptr(),
                 wrapper=ptr(),
                 doc=ptr[u8]("")
             ),
             SlotDef(
                 name=ptr[u8]("__getattr__"),
                 offset=SLOTDEF_TP_GETATTR,
                 function=ptr(),
                 wrapper=ptr(),
                 doc=ptr[u8]("")
             ),
             SlotDef(
                 name=ptr[u8]("__setattr__"),
                 offset=SLOTDEF_TP_SETATTR,
                 function=ptr(),
                 wrapper=ptr(),
                 doc=ptr[u8]("")
             ),
             SlotDef(
                 name=ptr[u8]("__delattr__"),
                 offset=SLOTDEF_TP_SETATTR,
                 function=ptr(),
                 wrapper=ptr(),
                 doc=ptr[u8]("")
             ),
             SlotDef(
                 name=ptr[u8]("__repr__"),
                 offset=SLOTDEF_TP_REPR,
                 function=ptr(slot_tp_repr),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8]("__repr__($self, /)\n--\n\nReturn repr(self).")
             ),
             SlotDef(
                 name=ptr[u8]("__hash__"),
                 offset=SLOTDEF_TP_HASH,
                 function=ptr(slot_tp_hash),
                 wrapper=ptr(wrap_hashfunc),
                 doc=ptr[u8]("__hash__($self, /)\n--\n\nReturn hash(self).")
             ),
             SlotDef(
                 name=ptr[u8]("__call__"),
                 offset=SLOTDEF_TP_CALL,
                 function=ptr(slot_tp_call),
                 wrapper=ptr(wrap_call),
                 doc=ptr[u8](
                     "__call__($self, /, *args, **kwargs)\n--\n\nCall self as a function."
                 ),
                 flags=PyWrapperFlag_KEYWORDS
             ),
             SlotDef(
                 name=ptr[u8]("__str__"),
                 offset=SLOTDEF_TP_STR,
                 function=ptr(slot_tp_str),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8]("__str__($self, /)\n--\n\nReturn str(self).")
             ),
             SlotDef(
                 name=ptr[u8]("__getattribute__"),
                 offset=SLOTDEF_TP_GETATTRO,
                 function=ptr(_Py_slot_tp_getattr_hook),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8](
                     "__getattribute__($self, name, /)\n--\n\nReturn getattr(self, name)."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__getattr__"),
                 offset=SLOTDEF_TP_GETATTRO,
                 function=ptr(_Py_slot_tp_getattr_hook),
                 wrapper=ptr(),
                 doc=ptr[u8](
                     "__getattr__($self, name, /)\n--\n\nImplement getattr(self, name)."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__setattr__"),
                 offset=SLOTDEF_TP_SETATTRO,
                 function=ptr(slot_tp_setattro),
                 wrapper=ptr(wrap_setattr),
                 doc=ptr[u8](
                     "__setattr__($self, name, value, /)\n--\n\nImplement setattr(self, name, value)."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__delattr__"),
                 offset=SLOTDEF_TP_SETATTRO,
                 function=ptr(slot_tp_setattro),
                 wrapper=ptr(wrap_delattr),
                 doc=ptr[u8](
                     "__delattr__($self, name, /)\n--\n\nImplement delattr(self, name)."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__lt__"),
                 offset=SLOTDEF_TP_RICHCOMPARE,
                 function=ptr(slot_tp_richcompare),
                 wrapper=ptr(richcmp_lt),
                 doc=ptr[u8]("__lt__($self, value, /)\n--\n\nReturn self<value.")
             ),
             SlotDef(
                 name=ptr[u8]("__le__"),
                 offset=SLOTDEF_TP_RICHCOMPARE,
                 function=ptr(slot_tp_richcompare),
                 wrapper=ptr(richcmp_le),
                 doc=ptr[u8]("__le__($self, value, /)\n--\n\nReturn self<=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__eq__"),
                 offset=SLOTDEF_TP_RICHCOMPARE,
                 function=ptr(slot_tp_richcompare),
                 wrapper=ptr(richcmp_eq),
                 doc=ptr[u8]("__eq__($self, value, /)\n--\n\nReturn self==value.")
             ),
             SlotDef(
                 name=ptr[u8]("__ne__"),
                 offset=SLOTDEF_TP_RICHCOMPARE,
                 function=ptr(slot_tp_richcompare),
                 wrapper=ptr(richcmp_ne),
                 doc=ptr[u8]("__ne__($self, value, /)\n--\n\nReturn self!=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__gt__"),
                 offset=SLOTDEF_TP_RICHCOMPARE,
                 function=ptr(slot_tp_richcompare),
                 wrapper=ptr(richcmp_gt),
                 doc=ptr[u8]("__gt__($self, value, /)\n--\n\nReturn self>value.")
             ),
             SlotDef(
                 name=ptr[u8]("__ge__"),
                 offset=SLOTDEF_TP_RICHCOMPARE,
                 function=ptr(slot_tp_richcompare),
                 wrapper=ptr(richcmp_ge),
                 doc=ptr[u8]("__ge__($self, value, /)\n--\n\nReturn self>=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__iter__"),
                 offset=SLOTDEF_TP_ITER,
                 function=ptr(slot_tp_iter),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8]("__iter__($self, /)\n--\n\nImplement iter(self).")
             ),
             SlotDef(
                 name=ptr[u8]("__next__"),
                 offset=SLOTDEF_TP_ITERNEXT,
                 function=ptr(slot_tp_iternext),
                 wrapper=ptr(wrap_next),
                 doc=ptr[u8]("__next__($self, /)\n--\n\nImplement next(self).")
             ),
             SlotDef(
                 name=ptr[u8]("__get__"),
                 offset=SLOTDEF_TP_DESCR_GET,
                 function=ptr(slot_tp_descr_get),
                 wrapper=ptr(wrap_descr_get),
                 doc=ptr[u8](
                     "__get__($self, instance, owner=None, /)\n--\n\nReturn an attribute of instance, which is of type owner."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__set__"),
                 offset=SLOTDEF_TP_DESCR_SET,
                 function=ptr(slot_tp_descr_set),
                 wrapper=ptr(wrap_descr_set),
                 doc=ptr[u8](
                     "__set__($self, instance, value, /)\n--\n\nSet an attribute of instance to value."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__delete__"),
                 offset=SLOTDEF_TP_DESCR_SET,
                 function=ptr(slot_tp_descr_set),
                 wrapper=ptr(wrap_descr_delete),
                 doc=ptr[u8](
                     "__delete__($self, instance, /)\n--\n\nDelete an attribute of instance."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__init__"),
                 offset=SLOTDEF_TP_INIT,
                 function=ptr(slot_tp_init),
                 wrapper=ptr(wrap_init),
                 doc=ptr[u8](
                     "__init__($self, /, *args, **kwargs)\n--\n\nInitialize self.  See help(type(self)) for accurate signature."
                 ),
                 flags=PyWrapperFlag_KEYWORDS
             ),
             SlotDef(
                 name=ptr[u8]("__new__"),
                 offset=SLOTDEF_TP_NEW,
                 function=ptr(slot_tp_new),
                 wrapper=ptr(),
                 doc=ptr[u8](
                     "__new__(type, /, *args, **kwargs)\n--\n\nCreate and return new object.  See help(type) for accurate signature."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__del__"),
                 offset=SLOTDEF_TP_FINALIZE,
                 function=ptr(slot_tp_finalize),
                 wrapper=ptr(wrap_del),
                 doc=ptr[u8](
                     "__del__($self, /)\n--\n\nCalled when the instance is about to be destroyed."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__buffer__"),
                 offset=SLOTDEF_BF_GETBUFFER,
                 function=ptr(slot_bf_getbuffer),
                 wrapper=ptr(wrap_buffer),
                 doc=ptr[u8](
                     "__buffer__($self, flags, /)\n--\n\nReturn a buffer object that exposes the underlying memory of the object."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__release_buffer__"),
                 offset=SLOTDEF_BF_RELEASEBUFFER,
                 function=ptr(slot_bf_releasebuffer),
                 wrapper=ptr(wrap_releasebuffer),
                 doc=ptr[u8](
                     "__release_buffer__($self, buffer, /)\n--\n\nRelease the buffer object that exposes the underlying memory of the object."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__await__"),
                 offset=SLOTDEF_AM_AWAIT,
                 function=ptr(slot_am_await),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8](
                     "__await__($self, /)\n--\n\nReturn an iterator to be used in await expression."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__aiter__"),
                 offset=SLOTDEF_AM_AITER,
                 function=ptr(slot_am_aiter),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8](
                     "__aiter__($self, /)\n--\n\nReturn an awaitable, that resolves in asynchronous iterator."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__anext__"),
                 offset=SLOTDEF_AM_ANEXT,
                 function=ptr(slot_am_anext),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8](
                     "__anext__($self, /)\n--\n\nReturn a value or raise StopAsyncIteration."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__add__"),
                 offset=SLOTDEF_NB_ADD,
                 function=ptr(slot_nb_add),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__add__($self, value, /)\n--\n\nReturn self+value.")
             ),
             SlotDef(
                 name=ptr[u8]("__radd__"),
                 offset=SLOTDEF_NB_ADD,
                 function=ptr(slot_nb_add),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__radd__($self, value, /)\n--\n\nReturn value+self.")
             ),
             SlotDef(
                 name=ptr[u8]("__sub__"),
                 offset=SLOTDEF_NB_SUBTRACT,
                 function=ptr(slot_nb_subtract),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__sub__($self, value, /)\n--\n\nReturn self-value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rsub__"),
                 offset=SLOTDEF_NB_SUBTRACT,
                 function=ptr(slot_nb_subtract),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__rsub__($self, value, /)\n--\n\nReturn value-self.")
             ),
             SlotDef(
                 name=ptr[u8]("__mul__"),
                 offset=SLOTDEF_NB_MULTIPLY,
                 function=ptr(slot_nb_multiply),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__mul__($self, value, /)\n--\n\nReturn self*value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rmul__"),
                 offset=SLOTDEF_NB_MULTIPLY,
                 function=ptr(slot_nb_multiply),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__rmul__($self, value, /)\n--\n\nReturn value*self.")
             ),
             SlotDef(
                 name=ptr[u8]("__mod__"),
                 offset=SLOTDEF_NB_REMAINDER,
                 function=ptr(slot_nb_remainder),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__mod__($self, value, /)\n--\n\nReturn self%value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rmod__"),
                 offset=SLOTDEF_NB_REMAINDER,
                 function=ptr(slot_nb_remainder),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__rmod__($self, value, /)\n--\n\nReturn value%self.")
             ),
             SlotDef(
                 name=ptr[u8]("__divmod__"),
                 offset=SLOTDEF_NB_DIVMOD,
                 function=ptr(slot_nb_divmod),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8](
                     "__divmod__($self, value, /)\n--\n\nReturn divmod(self, value)."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__rdivmod__"),
                 offset=SLOTDEF_NB_DIVMOD,
                 function=ptr(slot_nb_divmod),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8](
                     "__rdivmod__($self, value, /)\n--\n\nReturn divmod(value, self)."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__pow__"),
                 offset=SLOTDEF_NB_POWER,
                 function=ptr(slot_nb_power),
                 wrapper=ptr(wrap_ternaryfunc),
                 doc=ptr[u8](
                     "__pow__($self, value, mod=None, /)\n--\n\nReturn pow(self, value, mod)."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__rpow__"),
                 offset=SLOTDEF_NB_POWER,
                 function=ptr(slot_nb_power),
                 wrapper=ptr(wrap_ternaryfunc_r),
                 doc=ptr[u8](
                     "__rpow__($self, value, mod=None, /)\n--\n\nReturn pow(value, self, mod)."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__neg__"),
                 offset=SLOTDEF_NB_NEGATIVE,
                 function=ptr(slot_nb_negative),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8]("__neg__($self, /)\n--\n\n-self")
             ),
             SlotDef(
                 name=ptr[u8]("__pos__"),
                 offset=SLOTDEF_NB_POSITIVE,
                 function=ptr(slot_nb_positive),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8]("__pos__($self, /)\n--\n\n+self")
             ),
             SlotDef(
                 name=ptr[u8]("__abs__"),
                 offset=SLOTDEF_NB_ABSOLUTE,
                 function=ptr(slot_nb_absolute),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8]("__abs__($self, /)\n--\n\nabs(self)")
             ),
             SlotDef(
                 name=ptr[u8]("__bool__"),
                 offset=SLOTDEF_NB_BOOL,
                 function=ptr(slot_nb_bool),
                 wrapper=ptr(wrap_inquirypred),
                 doc=ptr[u8]("__bool__($self, /)\n--\n\nTrue if self else False")
             ),
             SlotDef(
                 name=ptr[u8]("__invert__"),
                 offset=SLOTDEF_NB_INVERT,
                 function=ptr(slot_nb_invert),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8]("__invert__($self, /)\n--\n\n~self")
             ),
             SlotDef(
                 name=ptr[u8]("__lshift__"),
                 offset=SLOTDEF_NB_LSHIFT,
                 function=ptr(slot_nb_lshift),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__lshift__($self, value, /)\n--\n\nReturn self<<value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rlshift__"),
                 offset=SLOTDEF_NB_LSHIFT,
                 function=ptr(slot_nb_lshift),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__rlshift__($self, value, /)\n--\n\nReturn value<<self.")
             ),
             SlotDef(
                 name=ptr[u8]("__rshift__"),
                 offset=SLOTDEF_NB_RSHIFT,
                 function=ptr(slot_nb_rshift),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__rshift__($self, value, /)\n--\n\nReturn self>>value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rrshift__"),
                 offset=SLOTDEF_NB_RSHIFT,
                 function=ptr(slot_nb_rshift),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__rrshift__($self, value, /)\n--\n\nReturn value>>self.")
             ),
             SlotDef(
                 name=ptr[u8]("__and__"),
                 offset=SLOTDEF_NB_AND,
                 function=ptr(slot_nb_and),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__and__($self, value, /)\n--\n\nReturn self&value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rand__"),
                 offset=SLOTDEF_NB_AND,
                 function=ptr(slot_nb_and),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__rand__($self, value, /)\n--\n\nReturn value&self.")
             ),
             SlotDef(
                 name=ptr[u8]("__xor__"),
                 offset=SLOTDEF_NB_XOR,
                 function=ptr(slot_nb_xor),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__xor__($self, value, /)\n--\n\nReturn self^value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rxor__"),
                 offset=SLOTDEF_NB_XOR,
                 function=ptr(slot_nb_xor),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__rxor__($self, value, /)\n--\n\nReturn value^self.")
             ),
             SlotDef(
                 name=ptr[u8]("__or__"),
                 offset=SLOTDEF_NB_OR,
                 function=ptr(slot_nb_or),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__or__($self, value, /)\n--\n\nReturn self|value.")
             ),
             SlotDef(
                 name=ptr[u8]("__ror__"),
                 offset=SLOTDEF_NB_OR,
                 function=ptr(slot_nb_or),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__ror__($self, value, /)\n--\n\nReturn value|self.")
             ),
             SlotDef(
                 name=ptr[u8]("__int__"),
                 offset=SLOTDEF_NB_INT,
                 function=ptr(slot_nb_int),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8]("__int__($self, /)\n--\n\nint(self)")
             ),
             SlotDef(
                 name=ptr[u8]("__float__"),
                 offset=SLOTDEF_NB_FLOAT,
                 function=ptr(slot_nb_float),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8]("__float__($self, /)\n--\n\nfloat(self)")
             ),
             SlotDef(
                 name=ptr[u8]("__iadd__"),
                 offset=SLOTDEF_NB_INPLACE_ADD,
                 function=ptr(slot_nb_inplace_add),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__iadd__($self, value, /)\n--\n\nReturn self+=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__isub__"),
                 offset=SLOTDEF_NB_INPLACE_SUBTRACT,
                 function=ptr(slot_nb_inplace_subtract),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__isub__($self, value, /)\n--\n\nReturn self-=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__imul__"),
                 offset=SLOTDEF_NB_INPLACE_MULTIPLY,
                 function=ptr(slot_nb_inplace_multiply),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__imul__($self, value, /)\n--\n\nReturn self*=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__imod__"),
                 offset=SLOTDEF_NB_INPLACE_REMAINDER,
                 function=ptr(slot_nb_inplace_remainder),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__imod__($self, value, /)\n--\n\nReturn self%=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__ipow__"),
                 offset=SLOTDEF_NB_INPLACE_POWER,
                 function=ptr(slot_nb_inplace_power),
                 wrapper=ptr(wrap_ternaryfunc),
                 doc=ptr[u8]("__ipow__($self, value, /)\n--\n\nReturn self**=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__ilshift__"),
                 offset=SLOTDEF_NB_INPLACE_LSHIFT,
                 function=ptr(slot_nb_inplace_lshift),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__ilshift__($self, value, /)\n--\n\nReturn self<<=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__irshift__"),
                 offset=SLOTDEF_NB_INPLACE_RSHIFT,
                 function=ptr(slot_nb_inplace_rshift),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__irshift__($self, value, /)\n--\n\nReturn self>>=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__iand__"),
                 offset=SLOTDEF_NB_INPLACE_AND,
                 function=ptr(slot_nb_inplace_and),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__iand__($self, value, /)\n--\n\nReturn self&=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__ixor__"),
                 offset=SLOTDEF_NB_INPLACE_XOR,
                 function=ptr(slot_nb_inplace_xor),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__ixor__($self, value, /)\n--\n\nReturn self^=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__ior__"),
                 offset=SLOTDEF_NB_INPLACE_OR,
                 function=ptr(slot_nb_inplace_or),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__ior__($self, value, /)\n--\n\nReturn self|=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__floordiv__"),
                 offset=SLOTDEF_NB_FLOOR_DIVIDE,
                 function=ptr(slot_nb_floor_divide),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__floordiv__($self, value, /)\n--\n\nReturn self//value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rfloordiv__"),
                 offset=SLOTDEF_NB_FLOOR_DIVIDE,
                 function=ptr(slot_nb_floor_divide),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8](
                     "__rfloordiv__($self, value, /)\n--\n\nReturn value//self."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__truediv__"),
                 offset=SLOTDEF_NB_TRUE_DIVIDE,
                 function=ptr(slot_nb_true_divide),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__truediv__($self, value, /)\n--\n\nReturn self/value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rtruediv__"),
                 offset=SLOTDEF_NB_TRUE_DIVIDE,
                 function=ptr(slot_nb_true_divide),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__rtruediv__($self, value, /)\n--\n\nReturn value/self.")
             ),
             SlotDef(
                 name=ptr[u8]("__ifloordiv__"),
                 offset=SLOTDEF_NB_INPLACE_FLOOR_DIVIDE,
                 function=ptr(slot_nb_inplace_floor_divide),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8](
                     "__ifloordiv__($self, value, /)\n--\n\nReturn self//=value."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__itruediv__"),
                 offset=SLOTDEF_NB_INPLACE_TRUE_DIVIDE,
                 function=ptr(slot_nb_inplace_true_divide),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__itruediv__($self, value, /)\n--\n\nReturn self/=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__index__"),
                 offset=SLOTDEF_NB_INDEX,
                 function=ptr(slot_nb_index),
                 wrapper=ptr(wrap_unaryfunc),
                 doc=ptr[u8](
                     "__index__($self, /)\n--\n\nReturn self converted to an integer, if self is suitable for use as an index into a list."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__matmul__"),
                 offset=SLOTDEF_NB_MATRIX_MULTIPLY,
                 function=ptr(slot_nb_matrix_multiply),
                 wrapper=ptr(wrap_binaryfunc_l),
                 doc=ptr[u8]("__matmul__($self, value, /)\n--\n\nReturn self@value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rmatmul__"),
                 offset=SLOTDEF_NB_MATRIX_MULTIPLY,
                 function=ptr(slot_nb_matrix_multiply),
                 wrapper=ptr(wrap_binaryfunc_r),
                 doc=ptr[u8]("__rmatmul__($self, value, /)\n--\n\nReturn value@self.")
             ),
             SlotDef(
                 name=ptr[u8]("__imatmul__"),
                 offset=SLOTDEF_NB_INPLACE_MATRIX_MULTIPLY,
                 function=ptr(slot_nb_inplace_matrix_multiply),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__imatmul__($self, value, /)\n--\n\nReturn self@=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__len__"),
                 offset=SLOTDEF_MP_LENGTH,
                 function=ptr(slot_sq_length),
                 wrapper=ptr(wrap_lenfunc),
                 doc=ptr[u8]("__len__($self, /)\n--\n\nReturn len(self).")
             ),
             SlotDef(
                 name=ptr[u8]("__getitem__"),
                 offset=SLOTDEF_MP_SUBSCRIPT,
                 function=ptr(slot_mp_subscript),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__getitem__($self, key, /)\n--\n\nReturn self[key].")
             ),
             SlotDef(
                 name=ptr[u8]("__setitem__"),
                 offset=SLOTDEF_MP_ASS_SUBSCRIPT,
                 function=ptr(slot_mp_ass_subscript),
                 wrapper=ptr(wrap_objobjargproc),
                 doc=ptr[u8](
                     "__setitem__($self, key, value, /)\n--\n\nSet self[key] to value."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__delitem__"),
                 offset=SLOTDEF_MP_ASS_SUBSCRIPT,
                 function=ptr(slot_mp_ass_subscript),
                 wrapper=ptr(wrap_delitem),
                 doc=ptr[u8]("__delitem__($self, key, /)\n--\n\nDelete self[key].")
             ),
             SlotDef(
                 name=ptr[u8]("__len__"),
                 offset=SLOTDEF_SQ_LENGTH,
                 function=ptr(slot_sq_length),
                 wrapper=ptr(wrap_lenfunc),
                 doc=ptr[u8]("__len__($self, /)\n--\n\nReturn len(self).")
             ),
             SlotDef(
                 name=ptr[u8]("__add__"),
                 offset=SLOTDEF_SQ_CONCAT,
                 function=ptr(),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__add__($self, value, /)\n--\n\nReturn self+value.")
             ),
             SlotDef(
                 name=ptr[u8]("__mul__"),
                 offset=SLOTDEF_SQ_REPEAT,
                 function=ptr(),
                 wrapper=ptr(wrap_indexargfunc),
                 doc=ptr[u8]("__mul__($self, value, /)\n--\n\nReturn self*value.")
             ),
             SlotDef(
                 name=ptr[u8]("__rmul__"),
                 offset=SLOTDEF_SQ_REPEAT,
                 function=ptr(),
                 wrapper=ptr(wrap_indexargfunc),
                 doc=ptr[u8]("__rmul__($self, value, /)\n--\n\nReturn value*self.")
             ),
             SlotDef(
                 name=ptr[u8]("__getitem__"),
                 offset=SLOTDEF_SQ_ITEM,
                 function=ptr(slot_sq_item),
                 wrapper=ptr(wrap_sq_item),
                 doc=ptr[u8]("__getitem__($self, key, /)\n--\n\nReturn self[key].")
             ),
             SlotDef(
                 name=ptr[u8]("__setitem__"),
                 offset=SLOTDEF_SQ_ASS_ITEM,
                 function=ptr(slot_sq_ass_item),
                 wrapper=ptr(wrap_sq_setitem),
                 doc=ptr[u8](
                     "__setitem__($self, key, value, /)\n--\n\nSet self[key] to value."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__delitem__"),
                 offset=SLOTDEF_SQ_ASS_ITEM,
                 function=ptr(slot_sq_ass_item),
                 wrapper=ptr(wrap_sq_delitem),
                 doc=ptr[u8]("__delitem__($self, key, /)\n--\n\nDelete self[key].")
             ),
             SlotDef(
                 name=ptr[u8]("__contains__"),
                 offset=SLOTDEF_SQ_CONTAINS,
                 function=ptr(slot_sq_contains),
                 wrapper=ptr(wrap_objobjproc),
                 doc=ptr[u8](
                     "__contains__($self, key, /)\n--\n\nReturn bool(key in self)."
                 )
             ),
             SlotDef(
                 name=ptr[u8]("__iadd__"),
                 offset=SLOTDEF_SQ_INPLACE_CONCAT,
                 function=ptr(),
                 wrapper=ptr(wrap_binaryfunc),
                 doc=ptr[u8]("__iadd__($self, value, /)\n--\n\nImplement self+=value.")
             ),
             SlotDef(
                 name=ptr[u8]("__imul__"),
                 offset=SLOTDEF_SQ_INPLACE_REPEAT,
                 function=ptr(),
                 wrapper=ptr(wrap_indexargfunc),
                 doc=ptr[u8]("__imul__($self, value, /)\n--\n\nImplement self*=value.")
             ),
             SlotDef()
         ],
         slotdef_name_ids: list[i64] = [
             _Py_ID___getattribute__,
             _Py_ID___getattr__,
             _Py_ID___setattr__,
             _Py_ID___delattr__,
             _Py_ID___repr__,
             _Py_ID___hash__,
             _Py_ID___call__,
             _Py_ID___str__,
             _Py_ID___getattribute__,
             _Py_ID___getattr__,
             _Py_ID___setattr__,
             _Py_ID___delattr__,
             _Py_ID___lt__,
             _Py_ID___le__,
             _Py_ID___eq__,
             _Py_ID___ne__,
             _Py_ID___gt__,
             _Py_ID___ge__,
             _Py_ID___iter__,
             _Py_ID___next__,
             _Py_ID___get__,
             _Py_ID___set__,
             _Py_ID___delete__,
             _Py_ID___init__,
             _Py_ID___new__,
             _Py_ID___del__,
             _Py_ID___buffer__,
             _Py_ID___release_buffer__,
             _Py_ID___await__,
             _Py_ID___aiter__,
             _Py_ID___anext__,
             _Py_ID___add__,
             _Py_ID___radd__,
             _Py_ID___sub__,
             _Py_ID___rsub__,
             _Py_ID___mul__,
             _Py_ID___rmul__,
             _Py_ID___mod__,
             _Py_ID___rmod__,
             _Py_ID___divmod__,
             _Py_ID___rdivmod__,
             _Py_ID___pow__,
             _Py_ID___rpow__,
             _Py_ID___neg__,
             _Py_ID___pos__,
             _Py_ID___abs__,
             _Py_ID___bool__,
             _Py_ID___invert__,
             _Py_ID___lshift__,
             _Py_ID___rlshift__,
             _Py_ID___rshift__,
             _Py_ID___rrshift__,
             _Py_ID___and__,
             _Py_ID___rand__,
             _Py_ID___xor__,
             _Py_ID___rxor__,
             _Py_ID___or__,
             _Py_ID___ror__,
             _Py_ID___int__,
             _Py_ID___float__,
             _Py_ID___iadd__,
             _Py_ID___isub__,
             _Py_ID___imul__,
             _Py_ID___imod__,
             _Py_ID___ipow__,
             _Py_ID___ilshift__,
             _Py_ID___irshift__,
             _Py_ID___iand__,
             _Py_ID___ixor__,
             _Py_ID___ior__,
             _Py_ID___floordiv__,
             _Py_ID___rfloordiv__,
             _Py_ID___truediv__,
             _Py_ID___rtruediv__,
             _Py_ID___ifloordiv__,
             _Py_ID___itruediv__,
             _Py_ID___index__,
             _Py_ID___matmul__,
             _Py_ID___rmatmul__,
             _Py_ID___imatmul__,
             _Py_ID___len__,
             _Py_ID___getitem__,
             _Py_ID___setitem__,
             _Py_ID___delitem__,
             _Py_ID___len__,
             _Py_ID___add__,
             _Py_ID___mul__,
             _Py_ID___rmul__,
             _Py_ID___getitem__,
             _Py_ID___setitem__,
             _Py_ID___delitem__,
             _Py_ID___contains__,
             _Py_ID___iadd__,
             _Py_ID___imul__,
             0
         ];
}

def init_slotdefs;

def slotptr(type: ptr[PyTypeObject], ioffset: i32) -> ptr[ptr];

import from c {
    glob:priv type_slots_pname: ptr[PyObject] = ptr[PyObject](),
         type_slots_ptrs: list[ptr] = [
             ptr(),
             ptr(),
             ptr(),
             ptr(),
             ptr(),
             ptr(),
             ptr(),
             ptr(),
             ptr(),
             ptr()
         ];
}

def resolve_slotdups(type: ptr[PyTypeObject], name: ptr[PyObject]) -> ptr[ptr];

def wrapper_descr_base(descr: ptr[PyObject]) -> ptr[SlotDef];

def wrapper_descr_wrapped(descr: ptr[PyObject]) -> ptr;

def method_descr_meth(descr: ptr[PyObject]) -> ptr;

def update_one_slot(type: ptr[PyTypeObject], p: ptr[SlotDef]) -> ptr[SlotDef];

def update_slots_callback(type: ptr[PyTypeObject], pp: ptr[ptr[SlotDef]]) -> i32;

def update_slot(type: ptr[PyTypeObject], name: ptr[PyObject]) -> i32;

def fixup_slot_dispatchers(type: ptr[PyTypeObject]);

def update_all_slots(type: ptr[PyTypeObject]);

import from c {
    def _PyType_GetSlotWrapperNames -> ptr[PyObject] {
        first = ptr[SlotDef](addressof(slotdefs));

        count: i64 = 0;
        while (first + count).view(1)[0].name {
            count += 1;
        }
        names = PyList_New(count);
        if not names {
            return NULL;
        }
        items = ptr[PyListObject](names).view(1)[0].ob_item;
        for i in range(count) {
            (items + i).view(1)[0] = object_new_ref((first + i).view(1)[0].name_strobj);
        }
        return names;
    }
}

def type_new_set_names(type: ptr[PyTypeObject]) -> i32;

def type_new_init_subclass(type: ptr[PyTypeObject], kwds: ptr[PyObject]) -> i32;

def update_subclasses(
    type: ptr[PyTypeObject], attr_name: ptr[PyObject], pp: ptr[ptr[SlotDef]]
) -> i32;

def recurse_down_subclasses(
    type: ptr[PyTypeObject], attr_name: ptr[PyObject], pp: ptr[ptr[SlotDef]]
) -> i32;

def slot_inherited(
    type: ptr[PyTypeObject], slotdef: ptr[SlotDef], slot: ptr[ptr]
) -> i32;

def add_operators(type: ptr[PyTypeObject]) -> i32;

import from c {
    def PyType_Freeze(type: ptr[PyTypeObject]) -> i32 {
        mro = type_get_mro(ptr[PyObject](type), ptr());
        if not tuple_check(mro) {
            object_decref(mro);
            PyErr_SetString(PyExc_TypeError, "unable to get the type MRO");
            return -1;
        }
        chk = check_immutable_bases(type.view(1)[0].tp_name, mro, 1);
        object_decref(mro);
        if chk < 0 {
            return -1;
        }
        type_add_flags(type, Py_TPFLAGS_IMMUTABLETYPE);
        type_modified_unlocked(type);
        return 0;
    }
}

import from c {
    glob:priv super_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__thisclass__"),
                 type_=_Py_T_OBJECT,
                 offset=superobject_TYPE,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the class invoking super()")
             ),
             PyMemberDef(
                 name=ptr[u8]("__self__"),
                 type_=_Py_T_OBJECT,
                 offset=superobject_OBJ,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the instance invoking super(); may be None")
             ),
             PyMemberDef(
                 name=ptr[u8]("__self_class__"),
                 type_=_Py_T_OBJECT,
                 offset=superobject_OBJ_TYPE,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the type of the instance invoking super(); may be None")
             ),
             PyMemberDef()
         ];
}

def super_dealloc(self_: ptr[PyObject]);

def super_repr(self_: ptr[PyObject]) -> ptr[PyObject];

def _super_lookup_descr(
    su_type: ptr[PyTypeObject], su_obj_type: ptr[PyTypeObject], name: ptr[PyObject]
) -> ptr[PyObject];

def do_super_lookup(
    su: ptr[SuperObject],
    su_type: ptr[PyTypeObject],
    su_obj: ptr[PyObject],
    su_obj_type: ptr[PyTypeObject],
    name: ptr[PyObject],
    want_method: bool
) -> tuple[ptr[PyObject], i32];

def super_getattro(self_: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def supercheck(type: ptr[PyTypeObject], obj_: ptr[PyObject]) -> ptr[PyTypeObject];

import from c {
    def _PySuper_Lookup(
        su_type: ptr[PyTypeObject],
        su_obj: ptr[PyObject],
        name: ptr[PyObject],
        method: ptr[i32]
    ) -> ptr[PyObject] {
        su_obj_type = supercheck(su_type, su_obj);
        if not su_obj_type {
            return NULL;
        }
        (res, found_method) = do_super_lookup(
            ptr[SuperObject](), su_type, su_obj, su_obj_type, name, int(method) != 0
        );
        if found_method != 0 {
            method.view(1)[0] = i32(1);
        }
        object_decref(ptr[PyObject](su_obj_type));
        return res;
    }
}

def super_descr_get(
    self_: ptr[PyObject], obj_: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def frame_get_code(frame: ptr[u8]) -> ptr[u8];

def frame_is_incomplete(frame: ptr[u8]) -> bool;

def thread_state_get_frame(tstate: ptr[PyThreadState]) -> ptr[u8];

def super_init_without_args(
    cframe: ptr[u8]
) -> tuple[i32, ptr[PyTypeObject], ptr[PyObject]];

def super_init(self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

def super_init_impl(
    self_: ptr[PyObject], type: ptr[PyTypeObject], obj_: ptr[PyObject]
) -> i32;

def super_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def super_vectorcall(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    glob PySuper_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("super"),
             tp_basicsize=superobject_SIZE,
             tp_dealloc=super_dealloc,
             tp_repr=super_repr,
             tp_getattro=super_getattro,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "super() -> same as super(__class__, <first argument>)\nsuper(type) -> unbound super object\nsuper(type, obj) -> bound super object; requires isinstance(obj, type)\nsuper(type, type2) -> bound super object; requires\n    issubclass(type2, type)\nTypical use to call a cooperative superclass method:\nclass C(B):\n    def meth(self, arg):\n        super().meth(arg)\nThis works for class methods too:\nclass C(B):\n    @classmethod\n    def cmeth(cls, arg):\n        super().cmeth(arg)\n"
             ),
             tp_traverse=super_traverse,
             tp_members=addressof(super_members),
             tp_descr_get=super_descr_get,
             tp_init=super_init,
             tp_alloc=PyType_GenericAlloc,
             tp_new=PyType_GenericNew,
             tp_free=PyObject_GC_Del,
             tp_vectorcall=super_vectorcall
         );
}

impl py_id(offset: i64) -> ptr[PyObject] {
    return ptr[PyObject](
        ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_GLOBAL_STRINGS + offset
    );
}

impl runtime_at(offset: i64) -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime)) + offset;
}

impl tuple_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl tuple_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyTuple_Type));
}

impl dict_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyDict_Type));
}

impl long_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl type_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyType_Type));
}

impl object_xincref(op: ptr[PyObject]) {
    if op {
        object_incref(op);
    }
}

impl object_xnewref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl py_clear(slot: ptr[ptr[PyObject]]) {
    old = slot.view(1)[0];
    if old {
        slot.view(1)[0] = NULL;
        object_decref(old);
    }
}

impl py_xsetref(slot: ptr[ptr[PyObject]], value: ptr[PyObject]) {
    old = slot.view(1)[0];
    slot.view(1)[0] = value;
    object_xdecref(old);
}

impl unicode_length(op: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](op) + PyASCIIObject_LENGTH).view(1)[0];
}

impl unicode_is_interned(op: ptr[PyObject]) -> bool {
    return (ptr[u32](ptr[u8](op) + PyASCIIObject_STATE).view(1)[0] & u32(3)) != u32(0);
}

impl object_hash_fast(op: ptr[PyObject]) -> i64 {
    if object_is_type(op, addressof(PyUnicode_Type)) {
        hash = ptr[i64](ptr[u8](op) + PyASCIIObject_HASH).view(1)[0];
        if hash != -1 {
            return hash;
        }
    }
    return PyObject_Hash(op);
}

impl long_one -> ptr[PyObject] {
    return ptr[PyObject](
        runtime_at(_PyRuntimeState_SMALL_INTS) + (NSMALLNEGINTS + 1) * PyLongObject_SIZE
    );
}

impl long_zero -> ptr[PyObject] {
    return ptr[PyObject](
        runtime_at(_PyRuntimeState_SMALL_INTS) + NSMALLNEGINTS * PyLongObject_SIZE
    );
}

impl weakref_get_ref(ref: ptr[PyObject]) -> ptr[PyObject] {
    target = ptr[PyWeakReference](ref).view(1)[0].wr_object;
    if target == Py_None or object_refcount(target) == 0 {
        return NULL;
    }
    object_incref(target);
    return target;
}

impl type_is_gc(tp: ptr[PyTypeObject]) -> bool {
    return type_has_feature(tp, Py_TPFLAGS_HAVE_GC);
}

impl type_preheader_size(tp: ptr[PyTypeObject]) -> i64 {
    size: i64 = 0;
    if type_is_gc(tp) {
        size = PyGC_Head_SIZE;
    }
    if type_has_feature(tp, TPFLAGS_PREHEADER) {
        size += 16;
    }
    return size;
}

impl is_static_builtin(tp: ptr[PyTypeObject]) -> bool {
    return type_has_feature(tp, _Py_TPFLAGS_STATIC_BUILTIN);
}

impl stackref_is_null(bits: u64) -> bool {
    return bits == STACKREF_NULL;
}

impl clear_immortal(op: ptr[PyObject]) {
    if op {
        header = ptr[_object](op);
        full = header.view(1)[0].ob_refcnt_full;
        header.view(1)[0].ob_refcnt_full = (full & ~i64(0xFFFFFFFF)) | 1;
        object_decref(op);
    }
}

impl builtin_state_at(interp: ptr[u8], index: i64) -> ptr[managed_static_type_state] {
    return ptr[managed_static_type_state](
        interp + PyInterpreterState_TYPES_BUILTINS_INITIALIZED
    )
        + index;
}

impl ext_state_at(interp: ptr[u8], index: i64) -> ptr[managed_static_type_state] {
    return ptr[managed_static_type_state](
        interp + PyInterpreterState_TYPES_EXT_INITIALIZED
    )
        + index;
}

impl managed_static_entry(full_index: i64) -> ptr[ManagedStaticTypeEntry] {
    return ptr[ManagedStaticTypeEntry](runtime_at(_PyRuntimeState_TYPES_MANAGED_STATIC))
        + full_index;
}

impl type_from_ref(ref: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[PyTypeObject](weakref_get_ref(ref));
}

impl managed_static_type_index_get(self_: ptr[PyTypeObject]) -> i64 {
    return int(self_.view(1)[0].tp_subclasses) - 1;
}

impl managed_static_type_index_set(self_: ptr[PyTypeObject], index: i64) {
    self_.view(1)[0].tp_subclasses = ptr(index + 1);
}

impl managed_static_type_index_clear(self_: ptr[PyTypeObject]) {
    self_.view(1)[0].tp_subclasses = ptr();
}

impl static_ext_type_lookup(
    interp: ptr[u8], index: i64
) -> tuple[ptr[PyTypeObject], i64] {
    full_index = index + _Py_MAX_MANAGED_STATIC_BUILTIN_TYPES;
    interp_count = __atomic_load_i64(
        int(managed_static_entry(full_index)) + MANAGED_STATIC_INTERP_COUNT, 5
    );
    type = ext_state_at(interp, index).view(1)[0].type;
    return (type, interp_count);
}

impl managed_static_type_state_get(
    interp: ptr[u8], self_: ptr[PyTypeObject]
) -> ptr[managed_static_type_state] {
    index = managed_static_type_index_get(self_);
    state = builtin_state_at(interp, index);
    if state.view(1)[0].type == self_ {
        return state;
    }
    if index > _Py_MAX_MANAGED_STATIC_EXT_TYPES {
        return state;
    }
    return ext_state_at(interp, index);
}

impl managed_static_type_state_init(
    interp: ptr[u8], self_: ptr[PyTypeObject], isbuiltin: i32, initial: i32
) {
    index: i64 = 0;
    if initial != 0 {
        if isbuiltin != 0 {
            index = ptr[i64](
                interp + PyInterpreterState_TYPES_BUILTINS_NUM_INITIALIZED
            ).view(
                1
            )[0];
        } else {
            mutex = ptr[PyMutex](interp + PyInterpreterState_TYPES_MUTEX);
            PyMutex_Lock(mutex);
            next_index = ptr[i64](interp + PyInterpreterState_TYPES_EXT_NEXT_INDEX);
            index = next_index.view(1)[0];
            next_index.view(1)[0] = index + 1;
            PyMutex_Unlock(mutex);
        }
        managed_static_type_index_set(self_, index);
    } else {
        index = managed_static_type_index_get(self_);
    }
    full_index = index;
    if isbuiltin == 0 {
        full_index = index + _Py_MAX_MANAGED_STATIC_BUILTIN_TYPES;
    }
    rt_entry = managed_static_entry(full_index);
    __atomic_add_i64(int(rt_entry) + MANAGED_STATIC_INTERP_COUNT, 1, 5);
    if initial != 0 {
        rt_entry.view(1)[0].type = self_;
    }
    state = builtin_state_at(interp, index)
        if isbuiltin != 0
        else ext_state_at(interp, index);

    state.view(1)[0].type = self_;
    state.view(1)[0].isbuiltin = isbuiltin;

    if isbuiltin != 0 {
        count = ptr[i64](interp + PyInterpreterState_TYPES_BUILTINS_NUM_INITIALIZED);
        count.view(1)[0] = count.view(1)[0] + 1;
    } else {
        count = ptr[i64](interp + PyInterpreterState_TYPES_EXT_NUM_INITIALIZED);
        count.view(1)[0] = count.view(1)[0] + 1;
    }
}

impl managed_static_type_state_clear(
    interp: ptr[u8], self_: ptr[PyTypeObject], isbuiltin: i32, final: i32
) {
    index = managed_static_type_index_get(self_);
    full_index = index;
    if isbuiltin == 0 {
        full_index = index + _Py_MAX_MANAGED_STATIC_BUILTIN_TYPES;
    }
    state = builtin_state_at(interp, index)
        if isbuiltin != 0
        else ext_state_at(interp, index);
    state.view(1)[0].type = ptr[PyTypeObject]();

    rt_entry = managed_static_entry(full_index);
    __atomic_sub_i64(int(rt_entry) + MANAGED_STATIC_INTERP_COUNT, 1, 5);
    if final != 0 {
        rt_entry.view(1)[0].type = ptr[PyTypeObject]();
        managed_static_type_index_clear(self_);
    }
    if isbuiltin != 0 {
        count = ptr[i64](interp + PyInterpreterState_TYPES_BUILTINS_NUM_INITIALIZED);
        count.view(1)[0] = count.view(1)[0] - 1;
    } else {
        mutex = ptr[PyMutex](interp + PyInterpreterState_TYPES_MUTEX);
        PyMutex_Lock(mutex);
        count = ptr[i64](interp + PyInterpreterState_TYPES_EXT_NUM_INITIALIZED);
        count.view(1)[0] = count.view(1)[0] - 1;
        if count.view(1)[0] == 0 {
            ptr[i64](interp + PyInterpreterState_TYPES_EXT_NEXT_INDEX).view(1)[0] = 0;
        }
        PyMutex_Unlock(mutex);
    }
}

impl type_set_flags(tp: ptr[PyTypeObject], flags: u64) {
    tp.view(1)[0].tp_flags = flags;
}

impl type_set_flags_with_mask(tp: ptr[PyTypeObject], mask: u64, flags: u64) {
    type_set_flags(tp, (tp.view(1)[0].tp_flags & ~mask) | flags);
}

impl type_add_flags(tp: ptr[PyTypeObject], flag: u64) {
    type_set_flags(tp, tp.view(1)[0].tp_flags | flag);
}

impl type_clear_flags(tp: ptr[PyTypeObject], flag: u64) {
    type_set_flags(tp, tp.view(1)[0].tp_flags & ~flag);
}

impl start_readying(type: ptr[PyTypeObject]) {
    if is_static_builtin(type) {
        state = managed_static_type_state_get(current_interp(), type);
        state.view(1)[0].readying = 1;
        return;
    }
    type_add_flags(type, Py_TPFLAGS_READYING);
}

impl stop_readying(type: ptr[PyTypeObject]) {
    if is_static_builtin(type) {
        state = managed_static_type_state_get(current_interp(), type);
        state.view(1)[0].readying = 0;
        return;
    }
    type_clear_flags(type, Py_TPFLAGS_READYING);
}

impl is_readying(type: ptr[PyTypeObject]) -> bool {
    if is_static_builtin(type) {
        state = managed_static_type_state_get(current_interp(), type);
        return state.view(1)[0].readying != 0;
    }
    return type_has_feature(type, Py_TPFLAGS_READYING);
}

impl lookup_tp_dict(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
    if is_static_builtin(self_) {
        state = managed_static_type_state_get(current_interp(), self_);
        return state.view(1)[0].tp_dict;
    }
    return self_.view(1)[0].tp_dict;
}

impl set_tp_dict(self_: ptr[PyTypeObject], dct: ptr[PyObject]) {
    if is_static_builtin(self_) {
        state = managed_static_type_state_get(current_interp(), self_);
        state.view(1)[0].tp_dict = dct;
        return;
    }
    self_.view(1)[0].tp_dict = dct;
}

impl clear_tp_dict(self_: ptr[PyTypeObject]) {
    if is_static_builtin(self_) {
        state = managed_static_type_state_get(current_interp(), self_);
        old = state.view(1)[0].tp_dict;
        if old {
            state.view(1)[0].tp_dict = NULL;
            object_decref(old);
        }
        return;
    }
    old = self_.view(1)[0].tp_dict;
    if old {
        self_.view(1)[0].tp_dict = NULL;
        object_decref(old);
    }
}

impl lookup_tp_bases(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
    return self_.view(1)[0].tp_bases;
}

impl set_tp_bases(self_: ptr[PyTypeObject], bases: ptr[PyObject], initial: i32) {
    if is_static_builtin(self_) {
        _Py_SetImmortal(bases);
    }
    self_.view(1)[0].tp_bases = bases;
}

impl clear_tp_bases(self_: ptr[PyTypeObject], final: i32) {
    if is_static_builtin(self_) {
        if final != 0 {
            bases = self_.view(1)[0].tp_bases;
            if bases {
                if object_size(bases) == 0 {
                    self_.view(1)[0].tp_bases = NULL;
                    object_decref(bases);
                } else {
                    clear_immortal(bases);
                    self_.view(1)[0].tp_bases = NULL;
                }
            }
        }
        return;
    }
    bases = self_.view(1)[0].tp_bases;
    if bases {
        self_.view(1)[0].tp_bases = NULL;
        object_decref(bases);
    }
}

impl lookup_tp_mro(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
    return self_.view(1)[0].tp_mro;
}

impl set_tp_mro(self_: ptr[PyTypeObject], mro: ptr[PyObject], initial: i32) {
    if mro and is_static_builtin(self_) {
        _Py_SetImmortal(mro);
    }
    self_.view(1)[0].tp_mro = mro;
}

impl clear_tp_mro(self_: ptr[PyTypeObject], final: i32) {
    if is_static_builtin(self_) {
        if final != 0 {
            mro = self_.view(1)[0].tp_mro;
            if mro {
                if object_size(mro) == 0 {
                    self_.view(1)[0].tp_mro = NULL;
                    object_decref(mro);
                } else {
                    clear_immortal(mro);
                    self_.view(1)[0].tp_mro = NULL;
                }
            }
        }
        return;
    }
    mro = self_.view(1)[0].tp_mro;
    if mro {
        self_.view(1)[0].tp_mro = NULL;
        object_decref(mro);
    }
}

impl init_tp_subclasses(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
    subclasses = PyDict_New();
    if not subclasses {
        return NULL;
    }
    if is_static_builtin(self_) {
        state = managed_static_type_state_get(current_interp(), self_);
        state.view(1)[0].tp_subclasses = subclasses;
        return subclasses;
    }
    self_.view(1)[0].tp_subclasses = ptr(subclasses);
    return subclasses;
}

impl clear_tp_subclasses(self_: ptr[PyTypeObject]) {
    if is_static_builtin(self_) {
        state = managed_static_type_state_get(current_interp(), self_);
        old = state.view(1)[0].tp_subclasses;
        if old {
            state.view(1)[0].tp_subclasses = NULL;
            object_decref(old);
        }
        return;
    }
    old = ptr[PyObject](self_.view(1)[0].tp_subclasses);
    if old {
        self_.view(1)[0].tp_subclasses = ptr();
        object_decref(old);
    }
}

impl lookup_tp_subclasses(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
    if is_static_builtin(self_) {
        state = managed_static_type_state_get(current_interp(), self_);
        return state.view(1)[0].tp_subclasses;
    }
    return ptr[PyObject](self_.view(1)[0].tp_subclasses);
}

impl find_signature(name: ptr[u8], doc: ptr[u8]) -> ptr[u8] {
    if not doc {
        return ptr[u8]();
    }

    short_name = name;
    dot = strrchr(name, i32(46));
    if dot {
        short_name = dot + 1;
    }
    length = strlen(short_name);
    if strncmp(doc, short_name, length) != 0 {
        return ptr[u8]();
    }
    sig = doc + i64(length);
    if sig.view(1)[0] != u8(40) {
        return ptr[u8]();
    }
    return sig;
}

impl skip_signature(doc: ptr[u8]) -> ptr[u8] {
    cursor = doc;
    while cursor.view(1)[0] != u8(0) {
        if cursor.view(1)[0] == u8(41)
            and strncmp(cursor, ptr[u8](")\n--\n\n"), u64(6)) == 0 {
            return cursor + 6;
        }
        if cursor.view(1)[0] == u8(10) and (cursor + 1).view(1)[0] == u8(10) {
            return ptr[u8]();
        }
        cursor = cursor + 1;
    }
    return ptr[u8]();
}

impl _PyType_DocWithoutSignature(name: ptr[u8], internal_doc: ptr[u8]) -> ptr[u8] {
    doc = find_signature(name, internal_doc);
    if doc {
        doc = skip_signature(doc);
        if doc {
            return doc;
        }
    }
    return internal_doc;
}

impl signature_from_flags(flags: i32) -> ptr[u8] {
    kind = flags & ~METH_COEXIST;
    if kind == METH_NOARGS {
        return ptr[u8]("($self, /)");
    }
    if kind == (METH_NOARGS | METH_CLASS) {
        return ptr[u8]("($type, /)");
    }
    if kind == (METH_NOARGS | METH_STATIC) {
        return ptr[u8]("()");
    }
    if kind == METH_O {
        return ptr[u8]("($self, object, /)");
    }
    if kind == (METH_O | METH_CLASS) {
        return ptr[u8]("($type, object, /)");
    }
    if kind == (METH_O | METH_STATIC) {
        return ptr[u8]("(object, /)");
    }
    return ptr[u8]();
}

impl type_cache_clear(cache: ptr[type_cache_entry], value: ptr[PyObject]) {
    for i in range(1 << MCACHE_SIZE_EXP) {
        cache_entry = cache + i;
        cache_entry.view(1)[0].version = u32(0);
        old = cache_entry.view(1)[0].name;
        cache_entry.view(1)[0].name = object_xnewref(value);
        object_xdecref(old);
        cache_entry.view(1)[0].value = NULL;
    }
}

impl _PyType_ClearCache(interp: ptr[u8]) -> u32 {
    type_cache_clear(
        ptr[type_cache_entry](interp + PyInterpreterState_TYPES_TYPE_CACHE), Py_None
    );
    return wrapping_sub(
        ptr[u32](interp + PyInterpreterState_TYPES_NEXT_VERSION_TAG).view(1)[0], u32(1)
    );
}

impl validate_watcher_id(interp: ptr[u8], watcher_id: i32) -> i32 {
    if watcher_id < 0 or i64(watcher_id) >= TYPE_MAX_WATCHERS {
        PyErr_Format(PyExc_ValueError, "Invalid type watcher ID %d", watcher_id);
        return -1;
    }
    watchers = ptr[ptr](interp + PyInterpreterState_TYPE_WATCHERS);
    if not (watchers + i64(watcher_id)).view(1)[0] {
        PyErr_Format(PyExc_ValueError, "No type watcher set for ID %d", watcher_id);
        return -1;
    }
    return 0;
}

impl set_version_unlocked(tp: ptr[PyTypeObject], version: u32) {
    interp = current_interp();
    version_cache = ptr[ptr[PyTypeObject]](
        interp + PyInterpreterState_TYPES_TYPE_VERSION_CACHE
    );
    old_version = tp.view(1)[0].tp_version_tag;
    if old_version != u32(0) {
        (version_cache + (i64(old_version) % TYPE_VERSION_CACHE_SIZE)).view(1)[0] = ptr[
            PyTypeObject
        ]();
    }
    if version != u32(0) {
        tp.view(1)[0].tp_versions_used = wrapping_add(
            tp.view(1)[0].tp_versions_used, u16(1)
        );
    }
    tp.view(1)[0].tp_version_tag = version;
    if version != u32(0) {
        (version_cache + (i64(version) % TYPE_VERSION_CACHE_SIZE)).view(1)[0] = tp;
    }
}

impl type_modified_unlocked(type: ptr[PyTypeObject]) {
    if type.view(1)[0].tp_version_tag == u32(0) {
        return;
    }

    subclasses = lookup_tp_subclasses(type);
    if subclasses {
        i: i64 = 0;
        key = NULL;
        ref = NULL;
        while PyDict_Next(subclasses, &mut i, &mut key, &mut ref) != 0 {
            subclass = type_from_ref(ref);
            if not subclass {
                continue;
            }
            type_modified_unlocked(subclass);
            object_decref(ptr[PyObject](subclass));
        }
    }

    if type.view(1)[0].tp_watched != u8(0) {
        watchers = ptr[ptr](current_interp() + PyInterpreterState_TYPE_WATCHERS);
        calls = ptr[TypeCall](
            __thread_local_block("jac_object_model_type_type_calls", 208)
        );
        bits = i32(type.view(1)[0].tp_watched);
        watcher: i32 = 0;
        while bits != 0 {
            if (bits & 1) != 0 {
                cb = (watchers + i64(watcher)).view(1)[0];
                if cb {
                    calls.view(1)[0].type_watcher = int(cb);
                    if calls.view(1)[0].type_watcher(type) < 0 {
                        PyErr_FormatUnraisable(
                            "Exception ignored in type watcher callback #%d for %R",
                            watcher,
                            ptr[PyObject](type)
                        );
                    }
                }
            }
            watcher += 1;
            bits = bits >> 1;
        }
    }
    set_version_unlocked(type, u32(0));
    if type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        ptr[ptr[PyObject]](ptr[u8](type) + PyHeapTypeObject_SPEC_CACHE_GETITEM).view(1)[
            0
        ] = NULL;
    }
}

impl has_custom_mro(tp: ptr[PyTypeObject]) -> bool {
    (version1, ref1) = lookup_stackref_and_version(
        object_type(ptr[PyObject](tp)), py_id(_Py_ID_mro)
    );
    (version2, ref2) = lookup_stackref_and_version(
        addressof(PyType_Type), py_id(_Py_ID_mro)
    );

    custom = (ref1 & ~u64(1)) != (ref2 & ~u64(1));
    stackref_close(ref2);
    stackref_close(ref1);
    return custom;
}

impl type_mro_modified(type: ptr[PyTypeObject], bases: ptr[PyObject]) {
    clear = False;
    if not object_is_type(ptr[PyObject](type), addressof(PyType_Type))
        and has_custom_mro(type) {
        clear = True;
    }
    if not clear {
        n = object_size(bases);
        for i in range(n) {
            cls = ptr[PyTypeObject](tuple_get_item(bases, i));
            if cls.view(1)[0].tp_versions_used >= _Py_ATTR_CACHE_UNUSED {
                clear = True;
                break;
            }
            if is_subtype_with_mro(lookup_tp_mro(type), type, cls) == 0 {
                clear = True;
                break;
            }
        }
    }
    if not clear {
        return;
    }

    set_version_unlocked(type, u32(0));
    type.view(1)[0].tp_versions_used = _Py_ATTR_CACHE_UNUSED;
    if type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        ptr[ptr[PyObject]](ptr[u8](type) + PyHeapTypeObject_SPEC_CACHE_GETITEM).view(1)[
            0
        ] = NULL;
    }
}

impl next_global_version_tag -> u32 {
    slot = int(runtime_at(_PyRuntimeState_TYPES_NEXT_VERSION_TAG));
    while True {
        old = __atomic_load_i32(slot, 0);
        if u32.wrap(old) >= _Py_MAX_GLOBAL_TYPE_VERSION_TAG {
            return u32(0);
        }
        if __atomic_cas_i32(slot, old, old + i32(1), 5) == old {
            return u32.wrap(old) + u32(1);
        }
    }
    return u32(0);
}

impl assign_version_tag(interp: ptr[u8], type: ptr[PyTypeObject]) -> i32 {
    if type.view(1)[0].tp_version_tag != u32(0) {
        return 1;
    }
    if not type_has_feature(type, Py_TPFLAGS_READY) {
        return 0;
    }

    if i64(type.view(1)[0].tp_versions_used) >= MAX_VERSIONS_PER_CLASS {
        return 0;
    }
    bases = lookup_tp_bases(type);
    n = object_size(bases);
    for i in range(n) {
        if assign_version_tag(interp, ptr[PyTypeObject](tuple_get_item(bases, i)))
            == 0 {
            return 0;
        }
    }
    if (type.view(1)[0].tp_flags & Py_TPFLAGS_IMMUTABLETYPE) != u64(0) {
        next_version_tag = next_global_version_tag();
        if next_version_tag == u32(0) {
            return 0;
        }
        set_version_unlocked(type, next_version_tag);
    } else {
        next_slot = ptr[u32](interp + PyInterpreterState_TYPES_NEXT_VERSION_TAG);
        tag = next_slot.view(1)[0];
        if tag == u32(0) {
            return 0;
        }
        next_slot.view(1)[0] = wrapping_add(tag, u32(1));
        set_version_unlocked(type, tag);
    }
    return 1;
}

impl check_set_special_type_attr(
    type: ptr[PyTypeObject], value: ptr[PyObject], name: ptr[u8]
) -> i32 {
    if type_has_feature(type, Py_TPFLAGS_IMMUTABLETYPE) {
        PyErr_Format(
            PyExc_TypeError,
            "cannot set '%s' attribute of immutable type '%s'",
            name,
            type.view(1)[0].tp_name
        );
        return 0;
    }
    if not value {
        PyErr_Format(
            PyExc_TypeError,
            "cannot delete '%s' attribute of immutable type '%s'",
            name,
            type.view(1)[0].tp_name
        );
        return 0;
    }
    if PySys_Audit("object.__setattr__", "OsO", ptr[PyObject](type), name, value) < 0 {
        return 0;
    }
    return 1;
}

impl find_name_in_mro(type: ptr[PyTypeObject], name: ptr[PyObject]) -> tuple[i32, u64] {
    hash = object_hash_fast(name);
    if hash == -1 {
        PyErr_Clear();
        return (i32(-1), STACKREF_NULL);
    }

    mro = lookup_tp_mro(type);
    if not mro {
        if not is_readying(type) {
            if PyType_Ready(type) < 0 {
                PyErr_Clear();
                return (i32(-1), STACKREF_NULL);
            }
            mro = lookup_tp_mro(type);
        }
        if not mro {
            return (i32(-1), STACKREF_NULL);
        }
    }
    res: i32 = 0;
    slots: own StackArgs = StackArgs();
    out = ptr[u64](jacpy_stack_address(&mut slots));
    out.view(1)[0] = STACKREF_NULL;

    mro_ref = stackref_new(mro);
    n = object_size(mro);
    for i in range(n) {
        base = tuple_get_item(mro, i);
        dct = lookup_tp_dict(ptr[PyTypeObject](base));
        ix = _Py_dict_lookup_threadsafe_stackref(dct, name, hash, out);
        if ix == DKIX_ERROR {
            PyErr_Clear();
            res = -1;
            break;
        }
        if not stackref_is_null(out.view(1)[0]) {
            res = 1;
            break;
        }
    }
    stackref_close(mro_ref);
    return (res, out.view(1)[0]);
}

impl is_dunder_name(name: ptr[PyObject]) -> bool {
    length = unicode_length(name);

    state = ptr[u32](ptr[u8](name) + PyASCIIObject_STATE).view(1)[0];
    kind = (state >> u32(2)) & u32(7);
    if length > 4 and kind == u32(1) {
        characters = ptr[u8]();
        if (state & u32(0x20)) != u32(0) {
            if (state & u32(0x40)) != u32(0) {
                characters = ptr[u8](name) + PyASCIIObject_SIZE;
            } else {
                characters = ptr[u8](name) + PyCompactUnicodeObject_SIZE;
            }
        } else {
            characters = ptr[ptr[u8]](ptr[u8](name) + PyUnicodeObject_DATA).view(1)[0];
        }
        return (characters + (length - 2)).view(1)[0] == u8(95)
            and (characters + (length - 1)).view(1)[0] == u8(95)
            and characters.view(1)[0] == u8(95)
            and (characters + 1).view(1)[0] == u8(95);
    }
    return False;
}

impl update_cache(
    cache_entry: ptr[type_cache_entry],
    name: ptr[PyObject],
    version_tag: u32,
    value: ptr[PyObject]
) -> ptr[PyObject] {
    cache_entry.view(1)[0].value = value;
    old_name = cache_entry.view(1)[0].name;
    cache_entry.view(1)[0].name = object_new_ref(name);
    cache_entry.view(1)[0].version = version_tag;
    return old_name;
}

impl should_assign_version_tag(
    type: ptr[PyTypeObject], name: ptr[PyObject], version_tag: u32
) -> bool {
    return version_tag == u32(0)
        and i64(type.view(1)[0].tp_versions_used) < MAX_VERSIONS_PER_CLASS
        and unicode_check_exact(name)
        and unicode_length(name) <= MCACHE_MAX_ATTR_SIZE;
}

impl type_cache_lookup_miss(
    interp: ptr[u8],
    type: ptr[PyTypeObject],
    name: ptr[PyObject],
    cache_entry: ptr[type_cache_entry]
) -> tuple[u32, u64] {
    version_tag = type.view(1)[0].tp_version_tag;
    if should_assign_version_tag(type, name, version_tag) {
        assign_version_tag(interp, type);
        version_tag = type.view(1)[0].tp_version_tag;
    }
    (res, out) = find_name_in_mro(type, name);

    if res < 0 {
        return (u32(0), STACKREF_NULL);
    }
    if version_tag == u32(0)
        or not (
            unicode_check_exact(name) and unicode_length(name) <= MCACHE_MAX_ATTR_SIZE
        ) {
        return (u32(0), out);
    }
    old_value = update_cache(cache_entry, name, version_tag, stackref_borrow(out));
    object_decref(old_value);
    return (version_tag, out);
}

impl lookup_stackref_and_version(
    type: ptr[PyTypeObject], name: ptr[PyObject]
) -> tuple[u32, u64] {
    type_version = type.view(1)[0].tp_version_tag;
    h = (type_version ^ u32.wrap(int(name) >> 3))
        & u32.wrap((1 << MCACHE_SIZE_EXP) - 1);
    interp = current_interp();
    cache_entry = ptr[type_cache_entry](interp + PyInterpreterState_TYPES_TYPE_CACHE)
        + i64(h);
    if cache_entry.view(1)[0].version == type_version
        and cache_entry.view(1)[0].name == name {
        value = cache_entry.view(1)[0].value;
        if value {
            return (cache_entry.view(1)[0].version, stackref_new(value));
        }
        return (cache_entry.view(1)[0].version, STACKREF_NULL);
    }
    return type_cache_lookup_miss(interp, type, name, cache_entry);
}

impl set_flags_recursive(self_: ptr[PyTypeObject], mask: u64, flags: u64) {
    if type_has_feature(self_, Py_TPFLAGS_IMMUTABLETYPE)
        or (self_.view(1)[0].tp_flags & mask) == flags {
        return;
    }
    type_set_flags_with_mask(self_, mask, flags);
    children = _PyType_GetSubclasses(self_);
    if not children {
        return;
    }
    i: i64 = 0;
    while i < object_size(children) {
        child = (ptr[PyListObject](children).view(1)[0].ob_item + i).view(1)[0];
        set_flags_recursive(ptr[PyTypeObject](child), mask, flags);
        i += 1;
    }
    object_decref(children);
}

impl type_update_dict(
    type: ptr[PyTypeObject],
    dct: ptr[PyObject],
    name: ptr[PyObject],
    value: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    slots: own StackArgs = StackArgs();
    old_slot = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    if _PyDict_GetItemRef_Unicode_LockHeld(dct, name, old_slot) < 0 {
        return (i32(-1), old_slot.view(1)[0]);
    }
    old_value = old_slot.view(1)[0];

    type_modified_unlocked(type);
    if _PyDict_SetItem_LockHeld(dct, name, value) < 0 {
        PyErr_Format(
            PyExc_AttributeError,
            "type object '%.50s' has no attribute '%U'",
            type.view(1)[0].tp_name,
            name
        );
        _PyObject_SetAttributeErrorContext(ptr[PyObject](type), name);
        return (i32(-1), old_value);
    }
    if is_dunder_name(name) {
        return (update_slot(type, name), old_value);
    }
    return (i32(0), old_value);
}

impl type_setattro(
    self_: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    type = ptr[PyTypeObject](self_);
    if type_has_feature(type, Py_TPFLAGS_IMMUTABLETYPE) {
        PyErr_Format(
            PyExc_TypeError,
            "cannot set %R attribute of immutable type '%s'",
            name,
            type.view(1)[0].tp_name
        );
        return -1;
    }
    if not unicode_check(name) {
        PyErr_Format(
            PyExc_TypeError,
            "attribute name must be string, not '%.200s'",
            object_type(name).view(1)[0].tp_name
        );
        return -1;
    }
    key = NULL;
    if unicode_check_exact(name) {
        key = object_new_ref(name);
    } else {
        key = _PyUnicode_Copy(name);
        if not key {
            return -1;
        }
    }
    slots: own StackArgs = StackArgs();
    key_slot = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    if not unicode_is_interned(key) {
        key_slot.view(1)[0] = key;
        _PyUnicode_InternMortal(current_interp(), key_slot);
        key = key_slot.view(1)[0];
        if not unicode_is_interned(key) {
            PyErr_SetString(
                PyExc_MemoryError, "Out of memory interning an attribute name"
            );
            object_decref(key);
            return -1;
        }
    }

    metatype = object_type(self_);
    res: i32 = 0;
    old_value = NULL;
    done = False;
    descr = _PyType_LookupRef(metatype, key);
    if descr {
        if int(object_type(descr).view(1)[0].tp_descr_set) != 0 {
            res = object_type(descr).view(1)[0].tp_descr_set(descr, self_, value);
            done = True;
        }
    }
    if not done {
        dct = type.view(1)[0].tp_dict;
        if not dct {
            dct = PyDict_New();
            type.view(1)[0].tp_dict = dct;
            if not dct {
                res = -1;
                done = True;
            }
        }
        if not done {
            (status, old) = type_update_dict(type, dct, key, value);
            res = status;
            old_value = old;
        }
    }
    object_decref(key);
    object_xdecref(descr);
    object_xdecref(old_value);
    return res;
}

impl type_name(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    if type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        et = ptr[PyHeapTypeObject](type);
        return object_new_ref(et.view(1)[0].ht_name);
    }
    return PyUnicode_FromString(_PyType_Name(type));
}

impl type_qualname(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    if type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        et = ptr[PyHeapTypeObject](type);
        return object_new_ref(et.view(1)[0].ht_qualname);
    }
    return PyUnicode_FromString(_PyType_Name(type));
}

impl type_set_name(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    type = ptr[PyTypeObject](tp);
    if check_set_special_type_attr(type, value, ptr[u8]("__name__")) == 0 {
        return i32(-1);
    }
    if not unicode_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            "can only assign string to %s.__name__, not '%s'",
            type.view(1)[0].tp_name,
            object_type(value).view(1)[0].tp_name
        );
        return i32(-1);
    }
    name_size: i64 = 0;
    tp_name = PyUnicode_AsUTF8AndSize(value, &mut name_size);
    if not tp_name {
        return i32(-1);
    }
    if strlen(tp_name) != u64(name_size) {
        PyErr_SetString(PyExc_ValueError, "type name must not contain null characters");
        return i32(-1);
    }

    type.view(1)[0].tp_name = tp_name;
    et = ptr[PyHeapTypeObject](type);
    old_name = et.view(1)[0].ht_name;
    et.view(1)[0].ht_name = object_new_ref(value);
    object_decref(old_name);
    return i32(0);
}

impl type_set_qualname(tp: ptr[PyObject], value: ptr[PyObject], context: ptr) -> i32 {
    type = ptr[PyTypeObject](tp);
    if check_set_special_type_attr(type, value, ptr[u8]("__qualname__")) == 0 {
        return i32(-1);
    }
    if not unicode_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            "can only assign string to %s.__qualname__, not '%s'",
            type.view(1)[0].tp_name,
            object_type(value).view(1)[0].tp_name
        );
        return i32(-1);
    }
    et = ptr[PyHeapTypeObject](type);
    old = et.view(1)[0].ht_qualname;
    et.view(1)[0].ht_qualname = object_new_ref(value);
    object_decref(old);
    return i32(0);
}

impl type_module(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    mod: ptr[PyObject] = NULL;
    if type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        dct = lookup_tp_dict(type);
        if PyDict_GetItemRef(dct, py_id(_Py_ID___module__), &mut mod) == 0 {
            PyErr_Format(PyExc_AttributeError, "__module__");
        }
    } else {
        tp_name = type.view(1)[0].tp_name;
        s = strrchr(tp_name, i32(46));
        if s {
            mod = PyUnicode_FromStringAndSize(tp_name, i64(int(s) - int(tp_name)));
            if mod {
                interp = current_interp();
                slots: own StackArgs = StackArgs();
                stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
                stack.view(1)[0] = mod;
                _PyUnicode_InternMortal(interp, stack);
                mod = stack.view(1)[0];
            }
        } else {
            mod = py_id(_Py_ID_builtins);
        }
    }
    return mod;
}

impl type_get_module(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return type_module(ptr[PyTypeObject](tp));
}

impl type_set_module(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    type = ptr[PyTypeObject](tp);
    if check_set_special_type_attr(type, value, ptr[u8]("__module__")) == 0 {
        return i32(-1);
    }
    PyType_Modified(type);
    dct = lookup_tp_dict(type);
    if PyDict_Pop(dct, py_id(_Py_ID___firstlineno__), None) < 0 {
        return i32(-1);
    }
    return PyDict_SetItem(dct, py_id(_Py_ID___module__), value);
}

impl type_abstractmethods(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    res: ptr[PyObject] = NULL;

    if type == addressof(PyType_Type) {
        PyErr_SetObject(PyExc_AttributeError, py_id(_Py_ID___abstractmethods__));
    } else {
        dct = lookup_tp_dict(type);
        if PyDict_GetItemRef(dct, py_id(_Py_ID___abstractmethods__), &mut res) == 0 {
            PyErr_SetObject(PyExc_AttributeError, py_id(_Py_ID___abstractmethods__));
        }
    }
    return res;
}

impl type_set_abstractmethods(
    tp: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32 {
    type = ptr[PyTypeObject](tp);
    is_abstract: i32 = 0;
    res: i32 = 0;
    dct = lookup_tp_dict(type);
    if value {
        is_abstract = PyObject_IsTrue(value);
        if is_abstract < 0 {
            return i32(-1);
        }
        res = PyDict_SetItem(dct, py_id(_Py_ID___abstractmethods__), value);
    } else {
        is_abstract = 0;
        res = PyDict_Pop(dct, py_id(_Py_ID___abstractmethods__), None);
        if res == 0 {
            PyErr_SetObject(PyExc_AttributeError, py_id(_Py_ID___abstractmethods__));
            return i32(-1);
        }
    }
    if res < 0 {
        return i32(-1);
    }
    type_modified_unlocked(type);
    if is_abstract != 0 {
        type_add_flags(type, Py_TPFLAGS_IS_ABSTRACT);
    } else {
        type_clear_flags(type, Py_TPFLAGS_IS_ABSTRACT);
    }
    return i32(0);
}

impl type_get_bases(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    bases = _PyType_GetBases(type);
    if not bases {
        return object_new_ref(Py_None);
    }
    return bases;
}

impl type_get_mro(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    mro = lookup_tp_mro(type);
    if not mro {
        return object_new_ref(Py_None);
    }
    return object_new_ref(mro);
}

impl mro_hierarchy_for_complete_type(
    type: ptr[PyTypeObject], temp: ptr[PyObject]
) -> i32 {
    (res, old_mro) = mro_internal(type);
    if res <= 0 {
        return res;
    }
    new_mro = lookup_tp_mro(type);

    tup: ptr[PyObject] = NULL;
    if old_mro {
        tup = PyTuple_Pack(i64(3), ptr[PyObject](type), new_mro, old_mro);
    } else {
        tup = PyTuple_Pack(i64(2), ptr[PyObject](type), new_mro);
    }
    if tup {
        res = PyList_Append(temp, tup);
    } else {
        res = i32(-1);
    }
    object_xdecref(tup);
    if res < 0 {
        set_tp_mro(type, old_mro, 0);
        object_decref(new_mro);
        return i32(-1);
    }
    object_xdecref(old_mro);

    if _PyType_HasSubclasses(type) != 0 {
        subclasses = _PyType_GetSubclasses(type);
        if not subclasses {
            return i32(-1);
        }
        n = object_size(subclasses);
        for i in range(n) {
            subclass = ptr[PyTypeObject](
                (ptr[PyListObject](subclasses).view(1)[0].ob_item + i).view(1)[0]
            );
            res = mro_hierarchy_for_complete_type(subclass, temp);
            if res < 0 {
                break;
            }
        }
        object_decref(subclasses);
    }
    return res;
}

impl type_set_bases_undo(temp: ptr[PyObject]) {
    n = object_size(temp);
    i = n - 1;
    while i >= 0 {
        item = (ptr[PyListObject](temp).view(1)[0].ob_item + i).view(1)[0];
        cls = ptr[PyTypeObject](tuple_get_item(item, 0));
        new_mro = tuple_get_item(item, 1);
        old_mro: ptr[PyObject] = NULL;
        if object_size(item) > 2 {
            old_mro = tuple_get_item(item, 2);
        }

        if lookup_tp_mro(cls) == new_mro {
            set_tp_mro(cls, object_xnewref(old_mro), 0);
            object_decref(new_mro);
        }
        i -= 1;
    }
    object_decref(temp);
}

impl type_set_bases_bail(
    type: ptr[PyTypeObject],
    new_bases: ptr[PyObject],
    new_base: ptr[PyTypeObject],
    old_bases: ptr[PyObject],
    old_base: ptr[PyTypeObject]
) -> i32 {
    if lookup_tp_bases(type) == new_bases {
        set_tp_bases(type, old_bases, 0);
        type.view(1)[0].tp_base = old_base;
        object_decref(new_bases);
        object_decref(ptr[PyObject](new_base));
    } else {
        object_decref(old_bases);
        object_decref(ptr[PyObject](old_base));
    }
    return i32(-1);
}

impl type_set_bases_unlocked(type: ptr[PyTypeObject], new_bases: ptr[PyObject]) -> i32 {
    if check_set_special_type_attr(type, new_bases, ptr[u8]("__bases__")) == 0 {
        return i32(-1);
    }

    if not tuple_check(new_bases) {
        PyErr_Format(
            PyExc_TypeError,
            "can only assign tuple to %s.__bases__, not %s",
            type.view(1)[0].tp_name,
            object_type(new_bases).view(1)[0].tp_name
        );
        return i32(-1);
    }
    if object_size(new_bases) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "can only assign non-empty tuple to %s.__bases__, not ()",
            type.view(1)[0].tp_name
        );
        return i32(-1);
    }
    n = object_size(new_bases);
    for i in range(n) {
        ob = tuple_get_item(new_bases, i);
        if not type_check(ob) {
            PyErr_Format(
                PyExc_TypeError,
                "%s.__bases__ must be tuple of classes, not '%s'",
                type.view(1)[0].tp_name,
                object_type(ob).view(1)[0].tp_name
            );
            return i32(-1);
        }
        base = ptr[PyTypeObject](ob);

        if is_subtype_with_mro(lookup_tp_mro(base), base, type) != 0
            or (lookup_tp_mro(base) and type_is_subtype_base_chain(base, type) != 0) {
            PyErr_SetString(
                PyExc_TypeError, "a __bases__ item causes an inheritance cycle"
            );
            return i32(-1);
        }
    }

    new_base = best_base(new_bases);
    if not new_base {
        return i32(-1);
    }
    if compatible_for_assignment(
        type.view(1)[0].tp_base, new_base, ptr[u8]("__bases__")
    )
        == 0 {
        return i32(-1);
    }
    old_bases = lookup_tp_bases(type);

    old_base = type.view(1)[0].tp_base;
    set_tp_bases(type, object_new_ref(new_bases), 0);
    type.view(1)[0].tp_base = ptr[PyTypeObject](
        object_new_ref(ptr[PyObject](new_base))
    );
    temp = PyList_New(0);
    if not temp {
        return type_set_bases_bail(type, new_bases, new_base, old_bases, old_base);
    }
    if mro_hierarchy_for_complete_type(type, temp) < 0 {
        type_set_bases_undo(temp);
        return type_set_bases_bail(type, new_bases, new_base, old_bases, old_base);
    }
    object_decref(temp);

    res: i32 = 0;
    if lookup_tp_bases(type) == new_bases {
        remove_all_subclasses(type, old_bases);
        res = add_all_subclasses(type, new_bases);
        update_all_slots(type);
    } else {
        res = 0;
    }

    counter = current_interp() + PyInterpreterState_RARE_SET_BASES;
    if counter.view(1)[0] < u8(255) {
        counter.view(1)[0] = counter.view(1)[0] + u8(1);
    }
    object_decref(old_bases);
    object_decref(ptr[PyObject](old_base));
    return res;
}

impl type_set_bases(tp: ptr[PyObject], new_bases: ptr[PyObject], closure: ptr) -> i32 {
    return type_set_bases_unlocked(ptr[PyTypeObject](tp), new_bases);
}

impl type_dict(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    dct = lookup_tp_dict(type);
    if not dct {
        return object_new_ref(Py_None);
    }
    return PyDictProxy_New(dct);
}

impl type_get_doc(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    result: ptr[PyObject] = NULL;
    if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) and type.view(1)[0].tp_doc {
        return _PyType_GetDocFromInternalDoc(
            type.view(1)[0].tp_name, type.view(1)[0].tp_doc
        );
    }
    dct = lookup_tp_dict(type);
    if PyDict_GetItemRef(dct, py_id(_Py_ID___doc__), &mut result) == 0 {
        result = object_new_ref(Py_None);
    } elif result {
        if int(object_type(result).view(1)[0].tp_descr_get) != 0 {
            old = result;
            result = object_type(old).view(1)[0].tp_descr_get(old, NULL, tp);
            object_decref(old);
        }
    }
    return result;
}

impl type_get_text_signature(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    return _PyType_GetTextSignatureFromInternalDoc(
        type.view(1)[0].tp_name, type.view(1)[0].tp_doc, 0
    );
}

impl type_set_doc(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    type = ptr[PyTypeObject](tp);
    if check_set_special_type_attr(type, value, ptr[u8]("__doc__")) == 0 {
        return i32(-1);
    }
    PyType_Modified(type);
    dct = lookup_tp_dict(type);
    return PyDict_SetItem(dct, py_id(_Py_ID___doc__), value);
}

impl type_get_annotate(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        PyErr_Format(
            PyExc_AttributeError,
            "type object '%s' has no attribute '__annotate__'",
            type.view(1)[0].tp_name
        );
        return NULL;
    }
    annotate: ptr[PyObject] = NULL;
    dct = PyType_GetDict(type);

    if PyDict_GetItemRef(dct, py_id(_Py_ID___annotate__), &mut annotate) < 0 {
        object_decref(dct);
        return NULL;
    }
    if not annotate {
        if PyDict_GetItemRef(dct, py_id(_Py_ID___annotate_func__), &mut annotate) < 0 {
            object_decref(dct);
            return NULL;
        }
    }
    if annotate {
        if int(object_type(annotate).view(1)[0].tp_descr_get) != 0 {
            old = annotate;
            annotate = object_type(old).view(1)[0].tp_descr_get(old, NULL, tp);
            object_decref(old);
        }
    } else {
        annotate = Py_None;
        result = PyDict_SetItem(dct, py_id(_Py_ID___annotate_func__), annotate);
        if result < 0 {
            object_decref(dct);
            return NULL;
        }
    }
    object_decref(dct);
    return annotate;
}

impl type_set_annotate(tp: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    type = ptr[PyTypeObject](tp);
    if not value {
        PyErr_SetString(PyExc_TypeError, "cannot delete __annotate__ attribute");
        return i32(-1);
    }
    if type_has_feature(type, Py_TPFLAGS_IMMUTABLETYPE) {
        PyErr_Format(
            PyExc_TypeError,
            "cannot set '__annotate__' attribute of immutable type '%s'",
            type.view(1)[0].tp_name
        );
        return i32(-1);
    }
    if value != Py_None and PyCallable_Check(value) == 0 {
        PyErr_SetString(PyExc_TypeError, "__annotate__ must be callable or None");
        return i32(-1);
    }
    dct = PyType_GetDict(type);

    result = PyDict_SetItem(dct, py_id(_Py_ID___annotate_func__), value);
    if result < 0 {
        object_decref(dct);
        return i32(-1);
    }
    if value != Py_None {
        if PyDict_Pop(dct, py_id(_Py_ID___annotations_cache__), None) == -1 {
            object_decref(dct);
            PyType_Modified(type);
            return i32(-1);
        }
    }
    object_decref(dct);
    PyType_Modified(type);
    return i32(0);
}

impl type_get_annotations(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        PyErr_Format(
            PyExc_AttributeError,
            "type object '%s' has no attribute '__annotations__'",
            type.view(1)[0].tp_name
        );
        return NULL;
    }
    annotations: ptr[PyObject] = NULL;
    dct = PyType_GetDict(type);

    if PyDict_GetItemRef(dct, py_id(_Py_ID___annotations__), &mut annotations) < 0 {
        object_decref(dct);
        return NULL;
    }
    if not annotations {
        if PyDict_GetItemRef(dct, py_id(_Py_ID___annotations_cache__), &mut annotations)
            < 0 {
            object_decref(dct);
            return NULL;
        }
    }
    if annotations {
        if int(object_type(annotations).view(1)[0].tp_descr_get) != 0 {
            old = annotations;
            annotations = object_type(old).view(1)[0].tp_descr_get(old, NULL, tp);
            object_decref(old);
        }
    } else {
        annotate = PyObject_GetAttrString(tp, ptr[u8]("__annotate__"));
        if not annotate {
            object_decref(dct);
            return NULL;
        }
        if PyCallable_Check(annotate) != 0 {
            annotations = PyObject_CallOneArg(annotate, long_one());
            if not annotations {
                object_decref(dct);
                object_decref(annotate);
                return NULL;
            }
            if not dict_check(annotations) {
                PyErr_Format(
                    PyExc_TypeError,
                    "__annotate__ returned non-dict of type '%.100s'",
                    object_type(annotations).view(1)[0].tp_name
                );
                object_decref(annotations);
                object_decref(annotate);
                object_decref(dct);
                return NULL;
            }
        } else {
            annotations = PyDict_New();
        }
        object_decref(annotate);
        if annotations {
            result = PyDict_SetItem(
                dct, py_id(_Py_ID___annotations_cache__), annotations
            );
            if result != 0 {
                old_annotations = annotations;
                annotations = NULL;
                object_decref(old_annotations);
            } else {
                PyType_Modified(type);
            }
        }
    }
    object_decref(dct);
    return annotations;
}

impl type_set_annotations(
    tp: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32 {
    type = ptr[PyTypeObject](tp);
    if type_has_feature(type, Py_TPFLAGS_IMMUTABLETYPE) {
        PyErr_Format(
            PyExc_TypeError,
            "cannot set '__annotations__' attribute of immutable type '%s'",
            type.view(1)[0].tp_name
        );
        return i32(-1);
    }
    dct = PyType_GetDict(type);
    result = PyDict_ContainsString(dct, ptr[u8]("__annotations__"));
    if result < 0 {
        object_decref(dct);
        return i32(-1);
    }
    if result != 0 {
        if value {
            result = PyDict_SetItem(dct, py_id(_Py_ID___annotations__), value);
        } else {
            result = PyDict_Pop(dct, py_id(_Py_ID___annotations__), None);
            if result == 0 {
                PyErr_SetString(PyExc_AttributeError, "__annotations__");
                object_decref(dct);
                return i32(-1);
            }
        }
        if result < 0 {
            object_decref(dct);
            return i32(-1);
        }

        result = PyDict_Pop(dct, py_id(_Py_ID___annotations_cache__), None);
    } elif value {
        result = PyDict_SetItem(dct, py_id(_Py_ID___annotations_cache__), value);
    } else {
        result = PyDict_Pop(dct, py_id(_Py_ID___annotations_cache__), None);
        if result == 0 {
            PyErr_SetString(PyExc_AttributeError, "__annotations__");
            object_decref(dct);
            return i32(-1);
        }
    }
    if result < 0 {
        object_decref(dct);
        return i32(-1);
    }

    if PyDict_Pop(dct, py_id(_Py_ID___annotate_func__), None) < 0 {
        PyType_Modified(type);
        object_decref(dct);
        return i32(-1);
    }
    if PyDict_Pop(dct, py_id(_Py_ID___annotate__), None) < 0 {
        PyType_Modified(type);
        object_decref(dct);
        return i32(-1);
    }
    PyType_Modified(type);
    object_decref(dct);
    return i32(0);
}

impl type_get_type_params(tp: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    type = ptr[PyTypeObject](tp);
    if type == addressof(PyType_Type) {
        return PyTuple_New(0);
    }
    params: ptr[PyObject] = NULL;
    if PyDict_GetItemRef(
        lookup_tp_dict(type), py_id(_Py_ID___type_params__), &mut params
    )
        == 0 {
        return PyTuple_New(0);
    }
    return params;
}

impl type_set_type_params(
    tp: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32 {
    type = ptr[PyTypeObject](tp);
    if check_set_special_type_attr(type, value, ptr[u8]("__type_params__")) == 0 {
        return i32(-1);
    }
    dct = lookup_tp_dict(type);
    result = PyDict_SetItem(dct, py_id(_Py_ID___type_params__), value);
    if result == 0 {
        PyType_Modified(type);
    }
    return result;
}

impl type___instancecheck___impl(
    self_: ptr[PyTypeObject], instance: ptr[PyObject]
) -> i32 {
    return _PyObject_RealIsInstance(instance, ptr[PyObject](self_));
}

impl type___subclasscheck___impl(
    self_: ptr[PyTypeObject], subclass: ptr[PyObject]
) -> i32 {
    return _PyObject_RealIsSubclass(subclass, ptr[PyObject](self_));
}

impl type___instancecheck__(
    self_: ptr[PyObject], instance: ptr[PyObject]
) -> ptr[PyObject] {
    rv = type___instancecheck___impl(ptr[PyTypeObject](self_), instance);
    if rv == -1 and PyErr_Occurred() != NULL {
        return NULL;
    }
    return PyBool_FromLong(i64(rv));
}

impl type___subclasscheck__(
    self_: ptr[PyObject], subclass: ptr[PyObject]
) -> ptr[PyObject] {
    rv = type___subclasscheck___impl(ptr[PyTypeObject](self_), subclass);
    if rv == -1 and PyErr_Occurred() != NULL {
        return NULL;
    }
    return PyBool_FromLong(i64(rv));
}

impl type_repr(self_: ptr[PyObject]) -> ptr[PyObject] {
    type = ptr[PyTypeObject](self_);
    if not type.view(1)[0].tp_name {
        return PyUnicode_FromFormat("<class at %p>", self_);
    }
    mod = type_module(type);
    if not mod {
        PyErr_Clear();
    } elif not unicode_check(mod) {
        old = mod;
        mod = NULL;
        object_decref(old);
    }
    name = type_qualname(self_, ptr());
    if not name {
        object_xdecref(mod);
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    if mod and _PyUnicode_Equal(mod, py_id(_Py_ID_builtins)) == 0 {
        result = PyUnicode_FromFormat("<class '%U.%U'>", mod, name);
    } else {
        result = PyUnicode_FromFormat("<class '%s'>", type.view(1)[0].tp_name);
    }
    object_xdecref(mod);
    object_decref(name);
    return result;
}

impl type_call(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    type = ptr[PyTypeObject](self_);
    tstate = thread_state();

    if type == addressof(PyType_Type) {
        nargs = object_size(args);
        if nargs == 1 and (not kwds or dict_used(kwds) == 0) {
            return object_new_ref(ptr[PyObject](object_type(tuple_get_item(args, 0))));
        }

        if nargs != 3 {
            PyErr_SetString(PyExc_TypeError, "type() takes 1 or 3 arguments");
            return NULL;
        }
    }
    if int(type.view(1)[0].tp_new) == 0 {
        PyErr_Format(
            PyExc_TypeError, "cannot create '%s' instances", type.view(1)[0].tp_name
        );
        return NULL;
    }
    obj_ = type.view(1)[0].tp_new(type, args, kwds);
    obj_ = _Py_CheckFunctionResult(tstate, self_, obj_, ptr[u8]());
    if not obj_ {
        return NULL;
    }

    if not object_type_check(obj_, type) {
        return obj_;
    }
    type = object_type(obj_);
    if int(type.view(1)[0].tp_init) != 0 {
        res = type.view(1)[0].tp_init(obj_, args, kwds);
        if res < 0 {
            object_decref(obj_);
            obj_ = NULL;
        }
    }
    return obj_;
}

impl inline_values_size(tp: ptr[PyTypeObject]) -> i64 {
    keys = ptr[u8](ptr[PyHeapTypeObject](tp).view(1)[0].ht_cached_keys);

    dk_usable = ptr[i64](keys + PyDictKeysObject_USABLE).view(1)[0];
    dk_nentries = ptr[i64](keys + PyDictKeysObject_NENTRIES).view(1)[0];
    size = dk_nentries + dk_usable;
    prefix_size = (size + 7) & ~i64(7);
    return prefix_size + (size + 1) * 8;
}

impl _PyHeapType_GET_MEMBERS(type: ptr[PyTypeObject]) -> ptr[PyMemberDef] {
    return ptr[PyMemberDef](PyObject_GetItemData(ptr[PyObject](type)));
}

impl traverse_slots(
    type: ptr[PyTypeObject], self_: ptr[PyObject], visitor: ptr, arg: ptr
) -> i32 {
    n = object_size(ptr[PyObject](type));
    mp = _PyHeapType_GET_MEMBERS(type);
    for i in range(n) {
        member = mp + i;
        if member.view(1)[0].type_ == Py_T_OBJECT_EX {
            addr = ptr[u8](self_) + member.view(1)[0].offset;
            obj_ = ptr[ptr[PyObject]](addr).view(1)[0];
            if obj_ {
                err = visit_reference(obj_, visitor, arg);
                if err != 0 {
                    return err;
                }
            }
        }
    }
    return 0;
}

impl subtype_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    type = object_type(self_);
    base = type;
    while int(base.view(1)[0].tp_traverse) == int(ptr(subtype_traverse)) {
        if object_size(ptr[PyObject](base)) != 0 {
            err = traverse_slots(base, self_, visitor, arg);
            if err != 0 {
                return err;
            }
        }
        base = base.view(1)[0].tp_base;
    }
    basetraverse = int(base.view(1)[0].tp_traverse);
    if type.view(1)[0].tp_dictoffset != base.view(1)[0].tp_dictoffset {
        if type_has_feature(type, Py_TPFLAGS_MANAGED_DICT) {
            err = PyObject_VisitManagedDict(self_, visitor, arg);
            if err != 0 {
                return err;
            }
        } else {
            dictptr = _PyObject_ComputedDictPointer(self_);
            if dictptr and dictptr.view(1)[0] {
                err = visit_reference(dictptr.view(1)[0], visitor, arg);
                if err != 0 {
                    return err;
                }
            }
        }
    }
    if type_has_feature(type, Py_TPFLAGS_HEAPTYPE)
        and (basetraverse == 0 or not type_has_feature(base, Py_TPFLAGS_HEAPTYPE)) {
        err = visit_reference(ptr[PyObject](type), visitor, arg);
        if err != 0 {
            return err;
        }
    }
    if basetraverse != 0 {
        calls = ptr[TypeCall](
            __thread_local_block("jac_object_model_type_type_calls", 208)
        );
        calls.view(1)[0].traverseproc = basetraverse;
        return calls.view(1)[0].traverseproc(self_, visitor, arg);
    }
    return 0;
}

impl clear_slots(type: ptr[PyTypeObject], self_: ptr[PyObject]) {
    n = object_size(ptr[PyObject](type));
    mp = _PyHeapType_GET_MEMBERS(type);
    for i in range(n) {
        member = mp + i;
        if member.view(1)[0].type_ == Py_T_OBJECT_EX
            and (member.view(1)[0].flags & Py_READONLY) == 0 {
            addr = ptr[ptr[PyObject]](ptr[u8](self_) + member.view(1)[0].offset);
            obj_ = addr.view(1)[0];
            if obj_ {
                addr.view(1)[0] = NULL;
                object_decref(obj_);
            }
        }
    }
}

impl subtype_clear(self_: ptr[PyObject]) -> i32 {
    type = object_type(self_);
    base = type;
    while int(base.view(1)[0].tp_clear) == int(ptr(subtype_clear)) {
        if object_size(ptr[PyObject](base)) != 0 {
            clear_slots(base, self_);
        }
        base = base.view(1)[0].tp_base;
    }
    baseclear = int(base.view(1)[0].tp_clear);

    if type_has_feature(type, Py_TPFLAGS_MANAGED_DICT) {
        if not type_has_feature(base, Py_TPFLAGS_MANAGED_DICT) {
            PyObject_ClearManagedDict(self_);
        }
    } elif type.view(1)[0].tp_dictoffset != base.view(1)[0].tp_dictoffset {
        dictptr = _PyObject_ComputedDictPointer(self_);
        if dictptr and dictptr.view(1)[0] {
            py_clear(dictptr);
        }
    }
    if baseclear != 0 {
        return base.view(1)[0].tp_clear(self_);
    }
    return 0;
}

impl subtype_dealloc(self_: ptr[PyObject]) {
    type = object_type(self_);

    if not type_is_gc(type) {
        if int(type.view(1)[0].tp_finalize) != 0 {
            if PyObject_CallFinalizerFromDealloc(self_) < 0 {
                return;
            }
        }
        if int(type.view(1)[0].tp_del) != 0 {
            type.view(1)[0].tp_del(self_);
            if object_refcount(self_) > 0 {
                return;
            }
        }

        base = type;
        while int(base.view(1)[0].tp_dealloc) == int(ptr(subtype_dealloc)) {
            base = base.view(1)[0].tp_base;
        }

        type = object_type(self_);

        type_needs_decref = type_has_feature(type, Py_TPFLAGS_HEAPTYPE)
            and not type_has_feature(base, Py_TPFLAGS_HEAPTYPE);

        base.view(1)[0].tp_dealloc(self_);

        if type_needs_decref {
            object_decref(ptr[PyObject](type));
        }

        return;
    }

    object_gc_untrack(self_);

    base = type;
    while int(base.view(1)[0].tp_dealloc) == int(ptr(subtype_dealloc)) {
        base = base.view(1)[0].tp_base;
    }
    has_finalizer = int(type.view(1)[0].tp_finalize) != 0
        or int(type.view(1)[0].tp_del) != 0;
    if int(type.view(1)[0].tp_finalize) != 0 {
        object_gc_track(self_);
        if PyObject_CallFinalizerFromDealloc(self_) < 0 {
            return;
        }
        object_gc_untrack(self_);
    }

    if type.view(1)[0].tp_weaklistoffset != 0
        and base.view(1)[0].tp_weaklistoffset == 0 {
        PyObject_ClearWeakRefs(self_);
    }
    if int(type.view(1)[0].tp_del) != 0 {
        object_gc_track(self_);
        type.view(1)[0].tp_del(self_);
        if object_refcount(self_) > 0 {
            return;
        }
        object_gc_untrack(self_);
    }
    if has_finalizer {
        if type.view(1)[0].tp_weaklistoffset != 0
            and base.view(1)[0].tp_weaklistoffset == 0 {
            _PyWeakref_ClearWeakRefsNoCallbacks(self_);
        }
    }

    base = type;
    while int(base.view(1)[0].tp_dealloc) == int(ptr(subtype_dealloc)) {
        if object_size(ptr[PyObject](base)) != 0 {
            clear_slots(base, self_);
        }
        base = base.view(1)[0].tp_base;
    }

    if type_has_feature(type, Py_TPFLAGS_MANAGED_DICT) {
        PyObject_ClearManagedDict(self_);
    } elif type.view(1)[0].tp_dictoffset != 0 and base.view(1)[0].tp_dictoffset == 0 {
        dictptr = _PyObject_ComputedDictPointer(self_);
        if dictptr {
            dct = dictptr.view(1)[0];
            if dct {
                object_decref(dct);
                dictptr.view(1)[0] = NULL;
            }
        }
    }

    type = object_type(self_);

    if type_is_gc(base) {
        object_gc_track(self_);
    }

    type_needs_decref = type_has_feature(type, Py_TPFLAGS_HEAPTYPE)
        and not type_has_feature(base, Py_TPFLAGS_HEAPTYPE);
    base.view(1)[0].tp_dealloc(self_);

    if type_needs_decref {
        object_decref(ptr[PyObject](type));
    }
}

impl type_is_subtype_base_chain(a: ptr[PyTypeObject], b: ptr[PyTypeObject]) -> i32 {
    cur = a;
    while True {
        if cur == b {
            return 1;
        }
        cur = cur.view(1)[0].tp_base;
        if not cur {
            break;
        }
    }
    if b == addressof(PyBaseObject_Type) {
        return 1;
    }
    return 0;
}

impl is_subtype_with_mro(
    a_mro: ptr[PyObject], a: ptr[PyTypeObject], b: ptr[PyTypeObject]
) -> i32 {
    res: i32 = 0;
    if a_mro {
        n = object_size(a_mro);
        items = tuple_items(a_mro);
        target = ptr[PyObject](b);
        for i in range(n) {
            if (items + i).view(1)[0] == target {
                res = 1;
                break;
            }
        }
    } else {
        res = type_is_subtype_base_chain(a, b);
    }
    return res;
}

impl lookup_method_ex(
    self_: ptr[PyObject], attr: ptr[PyObject], raise_attribute_error: i32
) -> tuple[i32, u64] {
    tp = object_type(self_);
    (_version, out) = lookup_stackref_and_version(tp, attr);
    if stackref_is_null(out) {
        if raise_attribute_error != 0 {
            PyErr_SetObject(PyExc_AttributeError, attr);
        }
        return (i32(-1), out);
    }
    value = stackref_borrow(out);
    vtype = object_type(value);
    if type_has_feature(vtype, Py_TPFLAGS_METHOD_DESCRIPTOR) {
        return (i32(1), out);
    }
    if int(vtype.view(1)[0].tp_descr_get) != 0 {
        bound = vtype.view(1)[0].tp_descr_get(value, self_, ptr[PyObject](tp));
        stackref_close(out);
        if not bound {
            if raise_attribute_error == 0
                and PyErr_ExceptionMatches(PyExc_AttributeError) != 0 {
                PyErr_Clear();
            }
            return (i32(-1), STACKREF_NULL);
        }
        return (i32(0), stackref_steal(bound));
    }
    return (i32(0), out);
}

impl lookup_maybe_method(self_: ptr[PyObject], attr: ptr[PyObject]) -> tuple[i32, u64] {
    (unbound, out) = lookup_method_ex(self_, attr, i32(0));
    return (unbound, out);
}

impl lookup_method(self_: ptr[PyObject], attr: ptr[PyObject]) -> tuple[i32, u64] {
    (unbound, out) = lookup_method_ex(self_, attr, i32(1));
    return (unbound, out);
}

impl vectorcall_unbound(
    tstate: ptr[PyThreadState],
    unbound: i32,
    func: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64
) -> ptr[PyObject] {
    argv = args;
    nargsf = u64(nargs);
    if unbound == 0 {
        argv = args + 1;
        nargsf = nargsf - u64(1) + PY_VECTORCALL_ARGUMENTS_OFFSET;
    }
    return vectorcall_tstate(tstate, func, argv, nargsf, NULL);
}

impl call_unbound_noarg(
    unbound: i32, func: ptr[PyObject], self_: ptr[PyObject]
) -> ptr[PyObject] {
    if unbound != 0 {
        return PyObject_CallOneArg(func, self_);
    }
    return PyObject_CallNoArgs(func);
}

impl call_method_noarg(self_: ptr[PyObject], attr: ptr[PyObject]) -> ptr[PyObject] {
    res = NULL;
    (unbound, ref) = lookup_method(self_, attr);
    if unbound >= 0 {
        func = stackref_borrow(ref);
        res = call_unbound_noarg(unbound, func, self_);
    }
    stackref_close(ref);
    return res;
}

impl call_method(
    self_: ptr[PyObject], attr: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    res = NULL;
    (unbound, ref) = lookup_method(self_, attr);
    if unbound >= 0 {
        meth = stackref_borrow(ref);
        if unbound != 0 {
            res = _PyObject_Call_Prepend(tstate, meth, self_, args, kwds);
        } else {
            res = _PyObject_Call(tstate, meth, args, kwds);
        }
    }
    stackref_close(ref);
    return res;
}

impl vectorcall_method(
    name: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    tstate = thread_state();
    retval = NULL;
    self_ = args.view(1)[0];
    (unbound, ref) = lookup_method(self_, name);
    if unbound >= 0 {
        func = stackref_borrow(ref);
        retval = vectorcall_unbound(tstate, unbound, func, args, nargs);
    }
    stackref_close(ref);
    return retval;
}

impl vectorcall_maybe(
    tstate: ptr[PyThreadState],
    name: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64
) -> ptr[PyObject] {
    self_ = args.view(1)[0];
    (unbound, ref) = lookup_maybe_method(self_, name);
    func = stackref_borrow(ref);
    if not func {
        stackref_close(ref);
        if not exception_raised(tstate) {
            return object_new_ref(Py_NotImplemented);
        }
        return NULL;
    }
    retval = vectorcall_unbound(tstate, unbound, func, args, nargs);
    stackref_close(ref);
    return retval;
}

impl maybe_call_special_no_args(
    self_: ptr[PyObject], attr: ptr[PyObject]
) -> tuple[ptr[PyObject], i32] {
    res = NULL;
    (unbound, ref) = lookup_maybe_method(self_, attr);
    func = stackref_borrow(ref);
    attr_is_none: i32 = 0;
    if func == Py_None {
        attr_is_none = 1;
    }
    if func and func != Py_None {
        res = call_unbound_noarg(unbound, func, self_);
    }
    stackref_close(ref);
    return (res, attr_is_none);
}

impl maybe_call_special_one_arg(
    self_: ptr[PyObject], attr: ptr[PyObject], arg: ptr[PyObject]
) -> tuple[ptr[PyObject], i32] {
    tstate = thread_state();
    res = NULL;
    (unbound, ref) = lookup_maybe_method(self_, attr);
    func = stackref_borrow(ref);
    attr_is_none: i32 = 0;
    if func == Py_None {
        attr_is_none = 1;
    }
    if func and func != Py_None {
        slots: own StackArgs = StackArgs();
        stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = arg;
        res = vectorcall_unbound(tstate, unbound, func, stack, 2);
    }
    stackref_close(ref);
    return (res, attr_is_none);
}

impl tail_contains(tup: ptr[PyObject], whence: i64, o: ptr[PyObject]) -> i32 {
    size = object_size(tup);
    j = whence + 1;
    while j < size {
        if tuple_get_item(tup, j) == o {
            return i32(1);
        }
        j += 1;
    }
    return i32(0);
}

impl class_name(cls: ptr[PyObject]) -> ptr[PyObject] {
    name = NULL;
    if PyObject_GetOptionalAttr(cls, py_id(_Py_ID___name__), &mut name) == 0 {
        name = PyObject_Repr(cls);
    }
    return name;
}

impl check_duplicates(tup: ptr[PyObject]) -> i32 {
    n = object_size(tup);
    for i in range(n) {
        o = tuple_get_item(tup, i);
        j = i + 1;
        while j < n {
            if tuple_get_item(tup, j) == o {
                name = class_name(o);
                if name {
                    if unicode_check(name) {
                        PyErr_Format(PyExc_TypeError, "duplicate base class %U", name);
                    } else {
                        PyErr_SetString(PyExc_TypeError, "duplicate base class");
                    }
                    object_decref(name);
                }
                return i32(-1);
            }
            j += 1;
        }
    }
    return i32(0);
}

impl set_mro_error(to_merge: ptr[ptr[PyObject]], to_merge_size: i64, remain: ptr[i64]) {
    st = PyDict_New();
    if not st {
        return;
    }
    for i in range(to_merge_size) {
        lst = (to_merge + i).view(1)[0];
        index = (remain + i).view(1)[0];
        if index < object_size(lst) {
            c = tuple_get_item(lst, index);
            if PyDict_SetItem(st, c, Py_None) < 0 {
                object_decref(st);
                return;
            }
        }
    }
    n = dict_used(st);

    buf = ptr[u8](PyMem_Malloc(u64(1000)));
    if not buf {
        object_decref(st);
        PyErr_NoMemory();
        return;
    }
    off = i64(
        PyOS_snprintf(
            buf,
            u64(1000),
            ptr[u8](
                "Cannot create a consistent method resolution order (MRO) for bases"
            )
        )
    );
    pos: i64 = 0;
    k = NULL;
    v = NULL;
    while PyDict_Next(st, &mut pos, &mut k, &mut v) != 0 and off >= 0 and off < 1000 {
        name = class_name(k);
        name_str = ptr[u8]();
        if name {
            if unicode_check(name) {
                name_str = PyUnicode_AsUTF8(name);
            } else {
                name_str = ptr[u8]("?");
            }
        }
        if not name_str {
            object_xdecref(name);
            object_decref(st);
            PyMem_Free(buf);
            return;
        }
        off += i64(PyOS_snprintf(buf + off, u64(1000 - off), ptr[u8](" %s"), name_str));
        object_xdecref(name);
        n -= 1;
        if n != 0 and off >= 0 and off + 1 < 1000 {
            (buf + off).view(1)[0] = u8(44);
            off += 1;
            (buf + off).view(1)[0] = u8(0);
        }
    }

    msg = PyUnicode_FromString(buf);
    if msg {
        PyErr_SetObject(PyExc_TypeError, msg);
        object_decref(msg);
    }
    PyMem_Free(buf);
    object_decref(st);
}

impl pmerge(
    acc: ptr[PyObject], to_merge: ptr[ptr[PyObject]], to_merge_size: i64
) -> i32 {
    res = i32(0);

    remain = ptr[i64]();
    if to_merge_size <= 1152921504606846975 {
        remain = ptr[i64](PyMem_Malloc(u64(to_merge_size * 8)));
    }
    if not remain {
        PyErr_NoMemory();
        return i32(-1);
    }
    for i in range(to_merge_size) {
        (remain + i).view(1)[0] = 0;
    }
    empty_cnt: i64 = 0;
    again = True;
    while again {
        again = False;
        empty_cnt = 0;
        for i in range(to_merge_size) {
            cur_tuple = (to_merge + i).view(1)[0];
            if (remain + i).view(1)[0] >= object_size(cur_tuple) {
                empty_cnt += 1;
                continue;
            }

            candidate = tuple_get_item(cur_tuple, (remain + i).view(1)[0]);
            in_tail = False;
            for j in range(to_merge_size) {
                j_lst = (to_merge + j).view(1)[0];
                if tail_contains(j_lst, (remain + j).view(1)[0], candidate) != 0 {
                    in_tail = True;
                    break;
                }
            }
            if in_tail {
                continue;
            }
            res = PyList_Append(acc, candidate);
            if res < 0 {
                PyMem_Free(ptr(remain));
                return res;
            }
            for j in range(to_merge_size) {
                j_lst = (to_merge + j).view(1)[0];
                index = (remain + j).view(1)[0];
                if index < object_size(j_lst)
                    and tuple_get_item(j_lst, index) == candidate {
                    (remain + j).view(1)[0] = index + 1;
                }
            }
            again = True;
            break;
        }
    }
    if empty_cnt != to_merge_size {
        set_mro_error(to_merge, to_merge_size, remain);
        res = i32(-1);
    }
    PyMem_Free(ptr(remain));
    return res;
}

impl mro_implementation_unlocked(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    if not type_is_ready(type) {
        if PyType_Ready(type) < 0 {
            return NULL;
        }
    }
    bases = lookup_tp_bases(type);
    n = object_size(bases);
    for i in range(n) {
        base = ptr[PyTypeObject](tuple_get_item(bases, i));
        if not lookup_tp_mro(base) {
            PyErr_Format(
                PyExc_TypeError,
                "Cannot extend an incomplete type '%.100s'",
                base.view(1)[0].tp_name
            );
            return NULL;
        }
    }
    if n == 1 {
        base = ptr[PyTypeObject](tuple_get_item(bases, 0));
        base_mro = lookup_tp_mro(base);
        k = object_size(base_mro);
        result = PyTuple_New(k + 1);
        if not result {
            return NULL;
        }
        tuple_set_item(result, 0, object_new_ref(ptr[PyObject](type)));
        for i in range(k) {
            cls = tuple_get_item(base_mro, i);
            tuple_set_item(result, i + 1, object_new_ref(cls));
        }
        return result;
    }

    if check_duplicates(bases) < 0 {
        return NULL;
    }

    to_merge = ptr[ptr[PyObject]]();
    if n + 1 <= 1152921504606846975 {
        to_merge = ptr[ptr[PyObject]](PyMem_Malloc(u64((n + 1) * 8)));
    }
    if not to_merge {
        PyErr_NoMemory();
        return NULL;
    }
    for i in range(n) {
        base = ptr[PyTypeObject](tuple_get_item(bases, i));
        (to_merge + i).view(1)[0] = lookup_tp_mro(base);
    }
    (to_merge + n).view(1)[0] = bases;
    result = PyList_New(1);
    if not result {
        PyMem_Free(ptr(to_merge));
        return NULL;
    }

    ptr[PyListObject](result).view(1)[0].ob_item.view(1)[0] = object_new_ref(
        ptr[PyObject](type)
    );
    if pmerge(result, to_merge, n + 1) < 0 {
        object_decref(result);
        result = NULL;
    }
    PyMem_Free(ptr(to_merge));
    return result;
}

impl mro_implementation(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    return mro_implementation_unlocked(type);
}

impl type_mro_impl(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
    seq = mro_implementation(self_);
    if seq and not list_check(seq) {
        lst = PySequence_List(seq);
        object_decref(seq);
        seq = lst;
    }
    return seq;
}

impl type_mro(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return type_mro_impl(ptr[PyTypeObject](self_));
}

impl mro_check(type: ptr[PyTypeObject], mro: ptr[PyObject]) -> i32 {
    solid = solid_base(type);
    n = object_size(mro);
    for i in range(n) {
        obj_ = tuple_get_item(mro, i);
        if not type_check(obj_) {
            PyErr_Format(
                PyExc_TypeError,
                "mro() returned a non-class ('%.500s')",
                object_type(obj_).view(1)[0].tp_name
            );
            return i32(-1);
        }
        base = ptr[PyTypeObject](obj_);
        if is_subtype_with_mro(lookup_tp_mro(solid), solid, solid_base(base)) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                "mro() returned base with unsuitable layout ('%.500s')",
                base.view(1)[0].tp_name
            );
            return i32(-1);
        }
    }
    return i32(0);
}

impl mro_invoke(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    custom = not object_is_type(ptr[PyObject](type), addressof(PyType_Type));
    mro_result = NULL;
    if custom {
        mro_result = call_method_noarg(ptr[PyObject](type), py_id(_Py_ID_mro));
    } else {
        mro_result = mro_implementation_unlocked(type);
    }
    if not mro_result {
        return NULL;
    }
    new_mro = PySequence_Tuple(mro_result);
    object_decref(mro_result);
    if not new_mro {
        return NULL;
    }
    if object_size(new_mro) == 0 {
        object_decref(new_mro);
        PyErr_Format(PyExc_TypeError, "type MRO must not be empty");
        return NULL;
    }
    if custom and mro_check(type, new_mro) < 0 {
        object_decref(new_mro);
        return NULL;
    }
    return new_mro;
}

impl mro_internal_unlocked(
    type: ptr[PyTypeObject], initial: i32
) -> tuple[i32, ptr[PyObject]] {
    old_mro = object_xnewref(lookup_tp_mro(type));

    new_mro = mro_invoke(type);
    reent = lookup_tp_mro(type) != old_mro;
    object_xdecref(old_mro);
    if not new_mro {
        return (i32(-1), NULL);
    }
    if reent {
        object_decref(new_mro);
        return (i32(0), NULL);
    }
    set_tp_mro(type, new_mro, initial);
    type_mro_modified(type, new_mro);

    type_mro_modified(type, lookup_tp_bases(type));
    if not is_static_builtin(type) {
        type_modified_unlocked(type);
    }

    return (i32(1), old_mro);
}

impl mro_internal(type: ptr[PyTypeObject]) -> tuple[i32, ptr[PyObject]] {
    (res, old_mro) = mro_internal_unlocked(type, i32(0));
    return (res, old_mro);
}

impl best_base(bases: ptr[PyObject]) -> ptr[PyTypeObject] {
    n = object_size(bases);
    base = ptr[PyTypeObject]();
    winner = ptr[PyTypeObject]();
    for i in range(n) {
        base_proto = tuple_get_item(bases, i);
        if not type_check(base_proto) {
            PyErr_SetString(PyExc_TypeError, "bases must be types");
            return ptr[PyTypeObject]();
        }
        base_i = ptr[PyTypeObject](base_proto);
        if not type_is_ready(base_i) {
            if PyType_Ready(base_i) < 0 {
                return ptr[PyTypeObject]();
            }
        }
        if not type_has_feature(base_i, Py_TPFLAGS_BASETYPE) {
            PyErr_Format(
                PyExc_TypeError,
                "type '%.100s' is not an acceptable base type",
                base_i.view(1)[0].tp_name
            );
            return ptr[PyTypeObject]();
        }
        candidate = solid_base(base_i);
        if not winner {
            winner = candidate;
            base = base_i;
        } elif PyType_IsSubtype(winner, candidate) == 0 {
            if PyType_IsSubtype(candidate, winner) != 0 {
                winner = candidate;
                base = base_i;
            } else {
                PyErr_SetString(
                    PyExc_TypeError, "multiple bases have instance lay-out conflict"
                );
                return ptr[PyTypeObject]();
            }
        }
    }
    return base;
}

impl shape_differs(t1: ptr[PyTypeObject], t2: ptr[PyTypeObject]) -> i32 {
    if t1.view(1)[0].tp_basicsize != t2.view(1)[0].tp_basicsize
        or t1.view(1)[0].tp_itemsize != t2.view(1)[0].tp_itemsize {
        return i32(1);
    }
    return i32(0);
}

impl solid_base(type: ptr[PyTypeObject]) -> ptr[PyTypeObject] {
    base = ptr[PyTypeObject]();
    if type.view(1)[0].tp_base {
        base = solid_base(type.view(1)[0].tp_base);
    } else {
        base = addressof(PyBaseObject_Type);
    }
    if shape_differs(type, base) != 0 {
        return type;
    }
    return base;
}

impl get_builtin_base_with_dict(type: ptr[PyTypeObject]) -> ptr[PyTypeObject] {
    tp = type;
    while tp.view(1)[0].tp_base {
        if tp.view(1)[0].tp_dictoffset != 0
            and (tp.view(1)[0].tp_flags & Py_TPFLAGS_HEAPTYPE) == 0 {
            return tp;
        }
        tp = tp.view(1)[0].tp_base;
    }
    return ptr[PyTypeObject]();
}

impl get_dict_descriptor(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    descr = _PyType_Lookup(type, py_id(_Py_ID___dict__));
    if not descr or PyDescr_IsData(descr) == 0 {
        return NULL;
    }
    return descr;
}

impl raise_dict_descr_error(obj_: ptr[PyObject]) {
    PyErr_Format(
        PyExc_TypeError,
        "this __dict__ descriptor does not support '%.200s' objects",
        object_type(obj_).view(1)[0].tp_name
    );
}

impl subtype_dict(obj_: ptr[PyObject], context: ptr) -> ptr[PyObject] {
    base = get_builtin_base_with_dict(object_type(obj_));
    if base {
        descr = get_dict_descriptor(base);
        if not descr {
            raise_dict_descr_error(obj_);
            return NULL;
        }
        if int(object_type(descr).view(1)[0].tp_descr_get) == 0 {
            raise_dict_descr_error(obj_);
            return NULL;
        }
        return object_type(descr).view(1)[0].tp_descr_get(
            descr, obj_, ptr[PyObject](object_type(obj_))
        );
    }
    return PyObject_GenericGetDict(obj_, context);
}

impl subtype_setdict(obj_: ptr[PyObject], value: ptr[PyObject], context: ptr) -> i32 {
    base = get_builtin_base_with_dict(object_type(obj_));
    if base {
        descr = get_dict_descriptor(base);
        if not descr {
            raise_dict_descr_error(obj_);
            return i32(-1);
        }
        if int(object_type(descr).view(1)[0].tp_descr_set) == 0 {
            raise_dict_descr_error(obj_);
            return i32(-1);
        }
        return object_type(descr).view(1)[0].tp_descr_set(descr, obj_, value);
    }
    return _PyObject_SetDict(obj_, value);
}

impl subtype_getweakref(obj_: ptr[PyObject], context: ptr) -> ptr[PyObject] {
    type = object_type(obj_);
    offset = type.view(1)[0].tp_weaklistoffset;
    if offset == 0 {
        PyErr_SetString(PyExc_AttributeError, "This object has no __weakref__");
        return NULL;
    }

    result = ptr[ptr[PyObject]](ptr[u8](obj_) + offset).view(1)[0];
    if not result {
        result = Py_None;
    }
    return object_new_ref(result);
}

impl valid_identifier(s: ptr[PyObject]) -> i32 {
    if not unicode_check(s) {
        PyErr_Format(
            PyExc_TypeError,
            "__slots__ items must be strings, not '%.200s'",
            object_type(s).view(1)[0].tp_name
        );
        return i32(0);
    }
    if PyUnicode_IsIdentifier(s) == 0 {
        PyErr_SetString(PyExc_TypeError, "__slots__ must be identifiers");
        return i32(0);
    }
    return i32(1);
}

impl type_init(cls: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    if kwds and object_size(args) == 1 and dict_used(kwds) != 0 {
        PyErr_SetString(PyExc_TypeError, "type.__init__() takes no keyword arguments");
        return i32(-1);
    }
    if object_size(args) != 1 and object_size(args) != 3 {
        PyErr_SetString(PyExc_TypeError, "type.__init__() takes 1 or 3 arguments");
        return i32(-1);
    }
    return i32(0);
}

impl type_new_visit_slots(ctx: ptr[TypeNewCtx]) -> i32 {
    slots = ctx.view(1)[0].slots;
    nslot = ctx.view(1)[0].nslot;
    for i in range(nslot) {
        name = tuple_get_item(slots, i);
        if valid_identifier(name) == 0 {
            return -1;
        }

        if _PyUnicode_Equal(name, py_id(_Py_ID___dict__)) != 0 {
            if ctx.view(1)[0].may_add_dict == 0 or ctx.view(1)[0].add_dict != 0 {
                PyErr_SetString(
                    PyExc_TypeError, "__dict__ slot disallowed: we already got one"
                );
                return -1;
            }
            ctx.view(1)[0].add_dict = ctx.view(1)[0].add_dict + 1;
        }
        if _PyUnicode_Equal(name, py_id(_Py_ID___weakref__)) != 0 {
            if ctx.view(1)[0].may_add_weak == 0 or ctx.view(1)[0].add_weak != 0 {
                PyErr_SetString(
                    PyExc_TypeError, "__weakref__ slot disallowed: we already got one"
                );
                return -1;
            }
            ctx.view(1)[0].add_weak = ctx.view(1)[0].add_weak + 1;
        }
    }
    return 0;
}

impl type_new_copy_slots(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]) -> ptr[PyObject] {
    slots = ctx.view(1)[0].slots;
    nslot = ctx.view(1)[0].nslot;
    add_dict = ctx.view(1)[0].add_dict;
    add_weak = ctx.view(1)[0].add_weak;
    new_nslot = nslot - i64(add_dict) - i64(add_weak);
    new_slots = PyList_New(new_nslot);
    if not new_slots {
        return NULL;
    }
    items = ptr[PyListObject](new_slots).view(1)[0].ob_item;
    j: i64 = 0;
    for i in range(nslot) {
        slot = tuple_get_item(slots, i);
        if (add_dict != 0 and _PyUnicode_Equal(slot, py_id(_Py_ID___dict__)) != 0)
            or (
                add_weak != 0 and _PyUnicode_Equal(slot, py_id(_Py_ID___weakref__)) != 0
            ) {
            continue;
        }
        slot = _Py_Mangle(ctx.view(1)[0].name, slot);
        if not slot {
            object_decref(new_slots);
            return NULL;
        }

        (items + j).view(1)[0] = slot;
        r = PyDict_Contains(dct, slot);
        if r < 0 {
            object_decref(new_slots);
            return NULL;
        }
        if r > 0 {
            if _PyUnicode_Equal(slot, py_id(_Py_ID___qualname__)) == 0
                and _PyUnicode_Equal(slot, py_id(_Py_ID___classcell__)) == 0
                and _PyUnicode_Equal(slot, py_id(_Py_ID___classdictcell__)) == 0 {
                PyErr_Format(
                    PyExc_ValueError,
                    "%R in __slots__ conflicts with class variable",
                    slot
                );
                object_decref(new_slots);
                return NULL;
            }
        }
        j += 1;
    }

    if PyList_Sort(new_slots) == -1 {
        object_decref(new_slots);
        return NULL;
    }
    tup = PyList_AsTuple(new_slots);
    object_decref(new_slots);
    if not tup {
        return NULL;
    }
    return tup;
}

impl type_new_slots_bases(ctx: ptr[TypeNewCtx]) {
    bases = ctx.view(1)[0].bases;
    nbases = object_size(bases);
    if nbases > 1
        and (
            (ctx.view(1)[0].may_add_dict != 0 and ctx.view(1)[0].add_dict == 0)
            or (ctx.view(1)[0].may_add_weak != 0 and ctx.view(1)[0].add_weak == 0)
        ) {
        for i in range(nbases) {
            ob = tuple_get_item(bases, i);
            if ob == ptr[PyObject](ctx.view(1)[0].base) {
                continue;
            }
            base = ptr[PyTypeObject](ob);
            if ctx.view(1)[0].may_add_dict != 0
                and ctx.view(1)[0].add_dict == 0
                and base.view(1)[0].tp_dictoffset != 0 {
                ctx.view(1)[0].add_dict = ctx.view(1)[0].add_dict + 1;
            }
            if ctx.view(1)[0].may_add_weak != 0
                and ctx.view(1)[0].add_weak == 0
                and base.view(1)[0].tp_weaklistoffset != 0 {
                ctx.view(1)[0].add_weak = ctx.view(1)[0].add_weak + 1;
            }
            if ctx.view(1)[0].may_add_dict != 0 and ctx.view(1)[0].add_dict == 0 {
                continue;
            }
            if ctx.view(1)[0].may_add_weak != 0 and ctx.view(1)[0].add_weak == 0 {
                continue;
            }

            break;
        }
    }
}

impl type_new_slots_impl(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]) -> i32 {
    base = ctx.view(1)[0].base;

    if ctx.view(1)[0].nslot > 0 and base.view(1)[0].tp_itemsize != 0 {
        PyErr_Format(
            PyExc_TypeError,
            "nonempty __slots__ not supported for subtype of '%s'",
            base.view(1)[0].tp_name
        );
        return -1;
    }
    if type_new_visit_slots(ctx) < 0 {
        return -1;
    }
    new_slots = type_new_copy_slots(ctx, dct);
    if not new_slots {
        return -1;
    }

    old = ctx.view(1)[0].slots;
    ctx.view(1)[0].slots = new_slots;
    object_xdecref(old);
    ctx.view(1)[0].nslot = object_size(new_slots);

    type_new_slots_bases(ctx);
    return 0;
}

impl type_new_slots(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]) -> i64 {
    base = ctx.view(1)[0].base;
    ctx.view(1)[0].add_dict = 0;
    ctx.view(1)[0].add_weak = 0;
    ctx.view(1)[0].may_add_dict = i32(1)
        if base.view(1)[0].tp_dictoffset == 0
        else i32(0);
    ctx.view(1)[0].may_add_weak = i32(1)
        if base.view(1)[0].tp_weaklistoffset == 0 and base.view(1)[0].tp_itemsize == 0
        else i32(0);
    if not ctx.view(1)[0].slots {
        if ctx.view(1)[0].may_add_dict != 0 {
            ctx.view(1)[0].add_dict = ctx.view(1)[0].add_dict + 1;
        }
        if ctx.view(1)[0].may_add_weak != 0 {
            ctx.view(1)[0].add_weak = ctx.view(1)[0].add_weak + 1;
        }
    } elif type_new_slots_impl(ctx, dct) < 0 {
        return -1;
    }
    return 0;
}

impl type_new_alloc(ctx: ptr[TypeNewCtx]) -> ptr[PyTypeObject] {
    metatype = ctx.view(1)[0].metatype;

    type = ptr[PyTypeObject](
        metatype.view(1)[0].tp_alloc(metatype, ctx.view(1)[0].nslot)
    );
    if not type {
        return ptr[PyTypeObject]();
    }
    et = ptr[PyHeapTypeObject](type);

    type_set_flags(
        type,
        Py_TPFLAGS_DEFAULT
            | Py_TPFLAGS_HEAPTYPE
            | Py_TPFLAGS_BASETYPE
            | Py_TPFLAGS_HAVE_GC
    );

    fields = ptr[u8](type);
    type.view(1)[0].tp_as_async = ptr[PyAsyncMethods](
        fields + PyHeapTypeObject_AS_ASYNC
    );
    type.view(1)[0].tp_as_number = ptr[PyNumberMethods](
        fields + PyHeapTypeObject_AS_NUMBER
    );
    type.view(1)[0].tp_as_sequence = ptr[PySequenceMethods](
        fields + PyHeapTypeObject_AS_SEQUENCE
    );
    type.view(1)[0].tp_as_mapping = ptr[PyMappingMethods](
        fields + PyHeapTypeObject_AS_MAPPING
    );
    type.view(1)[0].tp_as_buffer = ptr[PyBufferProcs](
        fields + PyHeapTypeObject_AS_BUFFER
    );
    set_tp_bases(type, object_new_ref(ctx.view(1)[0].bases), 1);
    type.view(1)[0].tp_base = ptr[PyTypeObject](
        object_new_ref(ptr[PyObject](ctx.view(1)[0].base))
    );
    type.view(1)[0].tp_dealloc = subtype_dealloc;

    type.view(1)[0].tp_alloc = PyType_GenericAlloc;
    type.view(1)[0].tp_free = PyObject_GC_Del;
    ptr[ptr](ptr[u8](type) + PyTypeObject_TP_TRAVERSE).view(1)[0] = ptr(
        subtype_traverse
    );
    type.view(1)[0].tp_clear = subtype_clear;
    et.view(1)[0].ht_name = object_new_ref(ctx.view(1)[0].name);
    et.view(1)[0].ht_module = NULL;
    et.view(1)[0]._ht_tpname = ptr[u8]();
    et.view(1)[0].ht_token = ptr();
    return type;
}

impl type_new_set_name(ctx: ptr[TypeNewCtx], type: ptr[PyTypeObject]) -> i32 {
    name_size: i64 = 0;
    type.view(1)[0].tp_name = PyUnicode_AsUTF8AndSize(
        ctx.view(1)[0].name, &mut name_size
    );
    if not type.view(1)[0].tp_name {
        return -1;
    }
    if strlen(type.view(1)[0].tp_name) != u64(name_size) {
        PyErr_SetString(PyExc_ValueError, "type name must not contain null characters");
        return -1;
    }
    return 0;
}

impl type_new_set_module(dct: ptr[PyObject]) -> i32 {
    r = PyDict_Contains(dct, py_id(_Py_ID___module__));
    if r < 0 {
        return -1;
    }
    if r > 0 {
        return 0;
    }
    globals = PyEval_GetGlobals();
    if not globals {
        return 0;
    }
    module = NULL;
    r = PyDict_GetItemRef(globals, py_id(_Py_ID___name__), &mut module);
    if module {
        r = PyDict_SetItem(dct, py_id(_Py_ID___module__), module);
        object_decref(module);
    }
    return r;
}

impl type_new_set_ht_name(type: ptr[PyTypeObject], dct: ptr[PyObject]) -> i32 {
    et = ptr[PyHeapTypeObject](type);
    qualname = NULL;
    if PyDict_GetItemRef(dct, py_id(_Py_ID___qualname__), &mut qualname) < 0 {
        return -1;
    }
    if qualname {
        if not unicode_check(qualname) {
            PyErr_Format(
                PyExc_TypeError,
                "type __qualname__ must be a str, not %s",
                object_type(qualname).view(1)[0].tp_name
            );
            object_decref(qualname);
            return -1;
        }
        et.view(1)[0].ht_qualname = qualname;
        if PyDict_DelItem(dct, py_id(_Py_ID___qualname__)) < 0 {
            return -1;
        }
    } else {
        et.view(1)[0].ht_qualname = object_new_ref(et.view(1)[0].ht_name);
    }
    return 0;
}

impl type_new_set_doc(type: ptr[PyTypeObject], dct: ptr[PyObject]) -> i32 {
    doc = PyDict_GetItemWithError(dct, py_id(_Py_ID___doc__));
    if not doc {
        if PyErr_Occurred() {
            return -1;
        }

        return 0;
    }
    if not unicode_check(doc) {
        return 0;
    }
    doc_str = PyUnicode_AsUTF8(doc);
    if not doc_str {
        return -1;
    }

    size = strlen(doc_str) + u64(1);
    tp_doc = ptr[u8](PyMem_Malloc(size));
    if not tp_doc {
        PyErr_NoMemory();
        return -1;
    }
    memcpy(ptr(tp_doc), ptr(doc_str), size);
    type.view(1)[0].tp_doc = tp_doc;
    return 0;
}

impl type_new_staticmethod(dct: ptr[PyObject], attr: ptr[PyObject]) -> i32 {
    func = PyDict_GetItemWithError(dct, attr);
    if not func {
        if PyErr_Occurred() {
            return -1;
        }
        return 0;
    }
    if not object_is_type(func, addressof(PyFunction_Type)) {
        return 0;
    }
    static_func = PyStaticMethod_New(func);
    if not static_func {
        return -1;
    }
    if PyDict_SetItem(dct, attr, static_func) < 0 {
        object_decref(static_func);
        return -1;
    }
    object_decref(static_func);
    return 0;
}

impl type_new_classmethod(dct: ptr[PyObject], attr: ptr[PyObject]) -> i32 {
    func = PyDict_GetItemWithError(dct, attr);
    if not func {
        if PyErr_Occurred() {
            return -1;
        }
        return 0;
    }
    if not object_is_type(func, addressof(PyFunction_Type)) {
        return 0;
    }
    method = PyClassMethod_New(func);
    if not method {
        return -1;
    }
    if PyDict_SetItem(dct, attr, method) < 0 {
        object_decref(method);
        return -1;
    }
    object_decref(method);
    return 0;
}

impl type_new_descriptors(ctx: ptr[TypeNewCtx], type: ptr[PyTypeObject]) -> i32 {
    et = ptr[PyHeapTypeObject](type);
    base = ctx.view(1)[0].base;
    slotoffset = base.view(1)[0].tp_basicsize;
    ht_slots = et.view(1)[0].ht_slots;
    if ht_slots {
        mp = _PyHeapType_GET_MEMBERS(type);
        nslot = object_size(ht_slots);
        for i in range(nslot) {
            mp.view(1)[0].name = PyUnicode_AsUTF8(tuple_get_item(ht_slots, i));
            if not mp.view(1)[0].name {
                return -1;
            }
            mp.view(1)[0].type_ = Py_T_OBJECT_EX;
            mp.view(1)[0].offset = slotoffset;

            slotoffset += 8;
            mp = mp + 1;
        }
    }
    if ctx.view(1)[0].add_weak != 0 {
        type_add_flags(type, Py_TPFLAGS_MANAGED_WEAKREF);
        type.view(1)[0].tp_weaklistoffset = MANAGED_WEAKREF_OFFSET;
    }
    if ctx.view(1)[0].add_dict != 0 {
        type_add_flags(type, Py_TPFLAGS_MANAGED_DICT);
        type.view(1)[0].tp_dictoffset = -1;
    }
    type.view(1)[0].tp_basicsize = slotoffset;
    type.view(1)[0].tp_itemsize = base.view(1)[0].tp_itemsize;
    type.view(1)[0].tp_members = _PyHeapType_GET_MEMBERS(type);
    return 0;
}

impl type_new_set_slots(ctx: ptr[TypeNewCtx], type: ptr[PyTypeObject]) {
    weaklistoffset = type.view(1)[0].tp_weaklistoffset;
    dictoffset = type.view(1)[0].tp_dictoffset;
    if weaklistoffset != 0 and dictoffset != 0 {
        type.view(1)[0].tp_getset = ptr[PyGetSetDef](addressof(subtype_getsets_full));
    } elif weaklistoffset != 0 and dictoffset == 0 {
        type.view(1)[0].tp_getset = ptr[PyGetSetDef](
            addressof(subtype_getsets_weakref_only)
        );
    } elif weaklistoffset == 0 and dictoffset != 0 {
        type.view(1)[0].tp_getset = ptr[PyGetSetDef](
            addressof(subtype_getsets_dict_only)
        );
    } else {
        type.view(1)[0].tp_getset = ptr[PyGetSetDef]();
    }

    if type.view(1)[0].tp_dictoffset != 0 or ctx.view(1)[0].nslot > 0 {
        base = ctx.view(1)[0].base;
        if int(base.view(1)[0].tp_getattr) == 0
            and int(base.view(1)[0].tp_getattro) == 0 {
            type.view(1)[0].tp_getattro = PyObject_GenericGetAttr;
        }
        if int(base.view(1)[0].tp_setattr) == 0
            and int(base.view(1)[0].tp_setattro) == 0 {
            type.view(1)[0].tp_setattro = PyObject_GenericSetAttr;
        }
    }
}

impl type_new_set_classcell(type: ptr[PyTypeObject], dct: ptr[PyObject]) -> i32 {
    cell = PyDict_GetItemWithError(dct, py_id(_Py_ID___classcell__));
    if not cell {
        if PyErr_Occurred() {
            return -1;
        }
        return 0;
    }
    if not object_is_type(cell, addressof(PyCell_Type)) {
        PyErr_Format(
            PyExc_TypeError,
            "__classcell__ must be a nonlocal cell, not %.200R",
            ptr[PyObject](object_type(cell))
        );
        return -1;
    }
    PyCell_Set(cell, ptr[PyObject](type));
    if PyDict_DelItem(dct, py_id(_Py_ID___classcell__)) < 0 {
        return -1;
    }
    return 0;
}

impl type_new_set_classdictcell(dct: ptr[PyObject]) -> i32 {
    cell = PyDict_GetItemWithError(dct, py_id(_Py_ID___classdictcell__));
    if not cell {
        if PyErr_Occurred() {
            return -1;
        }
        return 0;
    }
    if not object_is_type(cell, addressof(PyCell_Type)) {
        PyErr_Format(
            PyExc_TypeError,
            "__classdictcell__ must be a nonlocal cell, not %.200R",
            ptr[PyObject](object_type(cell))
        );
        return -1;
    }
    PyCell_Set(cell, dct);
    if PyDict_DelItem(dct, py_id(_Py_ID___classdictcell__)) < 0 {
        return -1;
    }
    return 0;
}

impl type_new_set_attrs(ctx: ptr[TypeNewCtx], type: ptr[PyTypeObject]) -> i32 {
    if type_new_set_name(ctx, type) < 0 {
        return -1;
    }
    dct = lookup_tp_dict(type);
    if type_new_set_module(dct) < 0 {
        return -1;
    }
    if type_new_set_ht_name(type, dct) < 0 {
        return -1;
    }
    if type_new_set_doc(type, dct) < 0 {
        return -1;
    }

    if type_new_staticmethod(dct, py_id(_Py_ID___new__)) < 0 {
        return -1;
    }

    if type_new_classmethod(dct, py_id(_Py_ID___init_subclass__)) < 0 {
        return -1;
    }
    if type_new_classmethod(dct, py_id(_Py_ID___class_getitem__)) < 0 {
        return -1;
    }
    if type_new_descriptors(ctx, type) < 0 {
        return -1;
    }
    type_new_set_slots(ctx, type);
    if type_new_set_classcell(type, dct) < 0 {
        return -1;
    }
    if type_new_set_classdictcell(dct) < 0 {
        return -1;
    }
    return 0;
}

impl type_new_get_slots(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]) -> i32 {
    slots = PyDict_GetItemWithError(dct, py_id(_Py_ID___slots__));
    if not slots {
        if PyErr_Occurred() {
            return -1;
        }
        ctx.view(1)[0].slots = NULL;
        ctx.view(1)[0].nslot = 0;
        return 0;
    }

    new_slots = NULL;
    if unicode_check(slots) {
        new_slots = PyTuple_Pack(1, slots);
    } else {
        new_slots = PySequence_Tuple(slots);
    }
    if not new_slots {
        return -1;
    }

    ctx.view(1)[0].slots = new_slots;
    ctx.view(1)[0].nslot = object_size(new_slots);
    return 0;
}

impl type_new_init(ctx: ptr[TypeNewCtx]) -> ptr[PyTypeObject] {
    dct = PyDict_Copy(ctx.view(1)[0].orig_dict);
    if not dct {
        type_new_init_error(ctx, dct);
        return ptr[PyTypeObject]();
    }
    if type_new_get_slots(ctx, dct) < 0 {
        type_new_init_error(ctx, dct);
        return ptr[PyTypeObject]();
    }

    if type_new_slots(ctx, dct) < 0 {
        type_new_init_error(ctx, dct);
        return ptr[PyTypeObject]();
    }
    type = type_new_alloc(ctx);
    if not type {
        type_new_init_error(ctx, dct);
        return ptr[PyTypeObject]();
    }
    set_tp_dict(type, dct);
    et = ptr[PyHeapTypeObject](type);
    et.view(1)[0].ht_slots = ctx.view(1)[0].slots;
    ctx.view(1)[0].slots = NULL;
    return type;
}

impl type_new_init_error(ctx: ptr[TypeNewCtx], dct: ptr[PyObject]) {
    old = ctx.view(1)[0].slots;
    if old {
        ctx.view(1)[0].slots = NULL;
        object_decref(old);
    }
    object_xdecref(dct);
}

impl type_new_impl(ctx: ptr[TypeNewCtx]) -> ptr[PyObject] {
    type = type_new_init(ctx);
    if not type {
        return NULL;
    }
    if type_new_set_attrs(ctx, type) < 0 {
        object_decref(ptr[PyObject](type));
        return NULL;
    }

    if PyType_Ready(type) < 0 {
        object_decref(ptr[PyObject](type));
        return NULL;
    }

    fixup_slot_dispatchers(type);
    if _PyDict_HasOnlyStringKeys(type.view(1)[0].tp_dict) == 0 {
        if PyErr_WarnFormat(
            PyExc_RuntimeWarning,
            1,
            "non-string key in the __dict__ of class %.200s",
            type.view(1)[0].tp_name
        )
            == -1 {
            object_decref(ptr[PyObject](type));
            return NULL;
        }
    }
    if type_new_set_names(type) < 0 {
        object_decref(ptr[PyObject](type));
        return NULL;
    }
    if type_new_init_subclass(type, ctx.view(1)[0].kwds) < 0 {
        object_decref(ptr[PyObject](type));
        return NULL;
    }
    return ptr[PyObject](type);
}

impl type_new_get_bases(ctx: ptr[TypeNewCtx]) -> tuple[i32, ptr[PyObject]] {
    bases = ctx.view(1)[0].bases;
    nbases = object_size(bases);
    if nbases == 0 {
        ctx.view(1)[0].base = addressof(PyBaseObject_Type);
        new_bases = PyTuple_Pack(1, ptr[PyObject](ctx.view(1)[0].base));
        if not new_bases {
            return (i32(-1), NULL);
        }
        ctx.view(1)[0].bases = new_bases;
        return (i32(0), NULL);
    }
    for i in range(nbases) {
        ob = tuple_get_item(bases, i);
        if type_check(ob) {
            continue;
        }
        rc = PyObject_HasAttrWithError(ob, py_id(_Py_ID___mro_entries__));
        if rc < 0 {
            return (i32(-1), NULL);
        }
        if rc != 0 {
            PyErr_SetString(
                PyExc_TypeError,
                "type() doesn't support MRO entry resolution; use types.new_class()"
            );
            return (i32(-1), NULL);
        }
    }

    winner = _PyType_CalculateMetaclass(ctx.view(1)[0].metatype, bases);
    if not winner {
        return (i32(-1), NULL);
    }
    if winner != ctx.view(1)[0].metatype {
        if int(winner.view(1)[0].tp_new) != int(ptr(type_new)) {
            made = winner.view(1)[0].tp_new(
                winner, ctx.view(1)[0].args, ctx.view(1)[0].kwds
            );
            if not made {
                return (i32(-1), NULL);
            }
            return (i32(1), made);
        }
        ctx.view(1)[0].metatype = winner;
    }

    base = best_base(bases);
    if not base {
        return (i32(-1), NULL);
    }
    ctx.view(1)[0].base = base;
    ctx.view(1)[0].bases = object_new_ref(bases);
    return (i32(0), NULL);
}

impl type_new_bad_argument(iarg: i64, expected: ptr[u8], arg: ptr[PyObject]) {
    got = ptr[u8]("None") if arg == Py_None else object_type(arg).view(1)[0].tp_name;
    PyErr_Format(
        PyExc_TypeError,
        "type.__new__() argument %zd must be %.50s, not %.50s",
        iarg,
        expected,
        got
    );
}

impl type_new(
    metatype: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = object_size(args);
    if nargs != 3 {
        PyErr_Format(
            PyExc_TypeError,
            "type.__new__() takes exactly 3 arguments (%zd given)",
            nargs
        );
        return NULL;
    }
    name = tuple_get_item(args, 0);
    if not unicode_check(name) {
        type_new_bad_argument(1, ptr[u8]("str"), name);
        return NULL;
    }
    bases = tuple_get_item(args, 1);
    if not object_type_check(bases, addressof(PyTuple_Type)) {
        type_new_bad_argument(2, addressof(PyTuple_Type).view(1)[0].tp_name, bases);
        return NULL;
    }
    orig_dict = tuple_get_item(args, 2);
    if not object_type_check(orig_dict, addressof(PyDict_Type)) {
        type_new_bad_argument(3, addressof(PyDict_Type).view(1)[0].tp_name, orig_dict);
        return NULL;
    }
    ctx = ptr[TypeNewCtx](PyMem_Calloc(u64(1), TYPE_NEW_CTX_SIZE));
    if not ctx {
        PyErr_NoMemory();
        return NULL;
    }
    ctx.view(1)[0].metatype = metatype;
    ctx.view(1)[0].args = args;
    ctx.view(1)[0].kwds = kwds;
    ctx.view(1)[0].orig_dict = orig_dict;
    ctx.view(1)[0].name = name;
    ctx.view(1)[0].bases = bases;

    (res, type) = type_new_get_bases(ctx);
    if res < 0 {
        PyMem_Free(ptr(ctx));
        return NULL;
    }
    if res == 1 {
        PyMem_Free(ptr(ctx));
        return type;
    }

    type = type_new_impl(ctx);
    object_decref(ctx.view(1)[0].bases);
    PyMem_Free(ptr(ctx));
    return type;
}

impl type_vectorcall(
    metatype: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = vectorcall_nargs(nargsf);
    if nargs == 1 and metatype == ptr[PyObject](addressof(PyType_Type)) {
        if kwnames and _PyArg_NoKwnames("type", kwnames) == 0 {
            return NULL;
        }
        return object_new_ref(ptr[PyObject](object_type(args.view(1)[0])));
    }

    tstate = thread_state();
    return _PyObject_MakeTpCall(tstate, metatype, args, nargs, kwnames);
}

impl _align_up(size: i64) -> i64 {
    return (size + ALIGNOF_MAX_ALIGN_T - 1) & ~(ALIGNOF_MAX_ALIGN_T - 1);
}

impl get_bases_tuple(bases_in: ptr[PyObject], spec: ptr[PyType_Spec]) -> ptr[PyObject] {
    if not bases_in {
        base: ptr[PyTypeObject] = addressof(PyBaseObject_Type);
        bases: ptr[PyObject] = NULL;
        slot = spec.view(1)[0].slots;
        while slot.view(1)[0].slot != 0 {
            slot_id = slot.view(1)[0].slot;
            if slot_id == Py_tp_base {
                base = ptr[PyTypeObject](slot.view(1)[0].pfunc);
            } elif slot_id == Py_tp_bases {
                bases = ptr[PyObject](slot.view(1)[0].pfunc);
            }
            slot = slot + 1;
        }
        if not bases {
            return PyTuple_Pack(1, ptr[PyObject](base));
        }
        if tuple_check(bases) {
            return object_new_ref(bases);
        }
        PyErr_SetString(PyExc_SystemError, "Py_tp_bases is not a tuple");
        return NULL;
    }
    if tuple_check(bases_in) {
        return object_new_ref(bases_in);
    }

    return PyTuple_Pack(1, bases_in);
}

impl check_basicsize_includes_size_and_offsets(type: ptr[PyTypeObject]) -> i32 {
    if int(type.view(1)[0].tp_alloc) != int(ptr(PyType_GenericAlloc)) {
        return 1;
    }
    max_size: i64 = type.view(1)[0].tp_basicsize;
    base = type.view(1)[0].tp_base;
    if base and base.view(1)[0].tp_basicsize > type.view(1)[0].tp_basicsize {
        PyErr_Format(
            PyExc_TypeError,
            "tp_basicsize for type '%s' (%zd) is too small for base '%s' (%zd)",
            type.view(1)[0].tp_name,
            type.view(1)[0].tp_basicsize,
            base.view(1)[0].tp_name,
            base.view(1)[0].tp_basicsize
        );
        return 0;
    }
    if type.view(1)[0].tp_weaklistoffset + 8 > max_size {
        PyErr_Format(
            PyExc_TypeError,
            "weaklist offset %zd is out of bounds for type '%s' (tp_basicsize = %zd)",
            type.view(1)[0].tp_weaklistoffset,
            type.view(1)[0].tp_name,
            type.view(1)[0].tp_basicsize
        );
        return 0;
    }
    if type.view(1)[0].tp_dictoffset + 8 > max_size {
        PyErr_Format(
            PyExc_TypeError,
            "dict offset %zd is out of bounds for type '%s' (tp_basicsize = %zd)",
            type.view(1)[0].tp_dictoffset,
            type.view(1)[0].tp_name,
            type.view(1)[0].tp_basicsize
        );
        return 0;
    }
    if type.view(1)[0].tp_vectorcall_offset + 8 > max_size {
        PyErr_Format(
            PyExc_TypeError,
            "vectorcall offset %zd is out of bounds for type '%s' (tp_basicsize = %zd)",
            type.view(1)[0].tp_vectorcall_offset,
            type.view(1)[0].tp_name,
            type.view(1)[0].tp_basicsize
        );
        return 0;
    }
    return 1;
}

impl check_immutable_bases(
    type_name: ptr[u8], bases: ptr[PyObject], skip_first: i32
) -> i32 {
    i: i64 = 0;
    if skip_first != 0 {
        i = 1;
    }
    while i < object_size(bases) {
        b = ptr[PyTypeObject](tuple_get_item(bases, i));
        if not b {
            return -1;
        }
        if not type_has_feature(b, Py_TPFLAGS_IMMUTABLETYPE) {
            PyErr_Format(
                PyExc_TypeError,
                "Creating immutable type %s from mutable base %N",
                type_name,
                ptr[PyObject](b)
            );
            return -1;
        }
        i += 1;
    }
    return 0;
}

impl special_offset_from_member(
    memb: ptr[PyMemberDef], type_data_offset: i64
) -> tuple[i32, i64] {
    if not memb {
        return (i32(0), i64(0));
    }
    if memb.view(1)[0].type_ != Py_T_PYSSIZET {
        PyErr_Format(
            PyExc_SystemError, "type of %s must be Py_T_PYSSIZET", memb.view(1)[0].name
        );
        return (i32(-1), i64(0));
    }
    flags = memb.view(1)[0].flags;
    if flags == Py_READONLY {
        return (i32(0), memb.view(1)[0].offset);
    } elif flags == (Py_READONLY | Py_RELATIVE_OFFSET) {
        return (i32(0), memb.view(1)[0].offset + type_data_offset);
    }
    PyErr_Format(
        PyExc_SystemError,
        "flags for %s must be Py_READONLY or (Py_READONLY | Py_RELATIVE_OFFSET)",
        memb.view(1)[0].name
    );
    return (i32(-1), i64(0));
}

impl type_from_spec_finally(
    res: ptr[PyObject],
    bases: ptr[PyObject],
    tp_doc: ptr[u8],
    ht_name: ptr[PyObject],
    ht_tpname: ptr[u8]
) -> ptr[PyObject] {
    result = res;
    if PyErr_Occurred() {
        if result {
            old = result;
            result = NULL;
            object_decref(old);
        }
    }
    object_xdecref(bases);
    PyMem_Free(ptr(tp_doc));
    object_xdecref(ht_name);
    PyMem_Free(ptr(ht_tpname));
    return result;
}

impl get_base_by_token_recursive(
    bases: ptr[PyObject], token: ptr
) -> ptr[PyTypeObject] {
    n = object_size(bases);
    for i in range(n) {
        base = ptr[PyTypeObject](tuple_get_item(bases, i));
        if not type_has_feature(base, Py_TPFLAGS_HEAPTYPE) {
            continue;
        }
        if int(ptr[PyHeapTypeObject](base).view(1)[0].ht_token) == int(token) {
            return base;
        }
        base = get_base_by_token_recursive(lookup_tp_bases(base), token);
        if base {
            return base;
        }
    }
    return ptr[PyTypeObject]();
}

impl type_dealloc_common(type: ptr[PyTypeObject]) {
    bases = lookup_tp_bases(type);
    if bases {
        exc = PyErr_GetRaisedException();
        remove_all_subclasses(type, bases);
        PyErr_SetRaisedException(exc);
    }
}

impl clear_static_tp_subclasses(type: ptr[PyTypeObject], isbuiltin: i32) {
    subclasses = lookup_tp_subclasses(type);
    if not subclasses {
        return;
    }
    clear_tp_subclasses(type);
}

impl clear_static_type_objects(
    interp: ptr[u8], type: ptr[PyTypeObject], isbuiltin: i32, final: i32
) {
    if final != 0 {
        cache = type.view(1)[0].tp_cache;
        if cache {
            type.view(1)[0].tp_cache = NULL;
            object_decref(cache);
        }
    }
    clear_tp_dict(type);
    clear_tp_bases(type, final);
    clear_tp_mro(type, final);
    clear_static_tp_subclasses(type, isbuiltin);
}

impl fini_static_type(
    interp: ptr[u8], type: ptr[PyTypeObject], isbuiltin: i32, final: i32
) {
    type_dealloc_common(type);
    clear_static_type_objects(interp, type, isbuiltin, final);
    if final != 0 {
        type_clear_flags(type, Py_TPFLAGS_READY);
        set_version_unlocked(type, u32(0));
    }
    _PyStaticType_ClearWeakRefs(ptr(interp), type);
    managed_static_type_state_clear(interp, type, isbuiltin, final);
}

impl type_dealloc(self_: ptr[PyObject]) {
    type = ptr[PyTypeObject](self_);

    object_gc_untrack(self_);
    type_dealloc_common(type);

    PyObject_ClearWeakRefs(self_);
    object_xdecref(ptr[PyObject](type.view(1)[0].tp_base));
    object_xdecref(type.view(1)[0].tp_dict);
    object_xdecref(type.view(1)[0].tp_bases);
    object_xdecref(type.view(1)[0].tp_mro);
    object_xdecref(type.view(1)[0].tp_cache);
    clear_tp_subclasses(type);

    PyMem_Free(ptr(type.view(1)[0].tp_doc));
    et = ptr[PyHeapTypeObject](self_);
    object_xdecref(et.view(1)[0].ht_name);
    object_xdecref(et.view(1)[0].ht_qualname);
    object_xdecref(et.view(1)[0].ht_slots);
    if et.view(1)[0].ht_cached_keys {
        _PyDictKeys_DecRef(ptr[u8](et.view(1)[0].ht_cached_keys));
    }
    object_xdecref(et.view(1)[0].ht_module);
    PyMem_Free(ptr(et.view(1)[0]._ht_tpname));
    et.view(1)[0].ht_token = ptr();
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl type___subclasses___impl(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
    return _PyType_GetSubclasses(self_);
}

impl type___subclasses__(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return type___subclasses___impl(ptr[PyTypeObject](self_));
}

impl type_prepare(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return PyDict_New();
}

impl merge_class_dict(dct: ptr[PyObject], aclass: ptr[PyObject]) -> i32 {
    classdict = NULL;
    if PyObject_GetOptionalAttr(aclass, py_id(_Py_ID___dict__), &mut classdict) < 0 {
        return -1;
    }
    if classdict {
        status = PyDict_Update(dct, classdict);
        object_decref(classdict);
        if status < 0 {
            return -1;
        }
    }

    bases = NULL;
    if PyObject_GetOptionalAttr(aclass, py_id(_Py_ID___bases__), &mut bases) < 0 {
        return -1;
    }
    if bases {
        n = PySequence_Size(bases);
        if n < 0 {
            object_decref(bases);
            return -1;
        }
        for i in range(n) {
            base = PySequence_GetItem(bases, i);
            if not base {
                object_decref(bases);
                return -1;
            }
            base_status = merge_class_dict(dct, base);
            object_decref(base);
            if base_status < 0 {
                object_decref(bases);
                return -1;
            }
        }
        object_decref(bases);
    }
    return 0;
}

impl type___dir___impl(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
    result = NULL;
    dct = PyDict_New();
    if dct and merge_class_dict(dct, ptr[PyObject](self_)) == 0 {
        result = PyDict_Keys(dct);
    }
    object_xdecref(dct);
    return result;
}

impl type___dir__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return type___dir___impl(ptr[PyTypeObject](self_));
}

impl type___sizeof___impl(self_: ptr[PyTypeObject]) -> ptr[PyObject] {
    size: u64 = 0;
    if (self_.view(1)[0].tp_flags & Py_TPFLAGS_HEAPTYPE) != 0 {
        et = ptr[PyHeapTypeObject](self_);
        size = u64(PyHeapTypeObject_SIZE);
        if et.view(1)[0].ht_cached_keys {
            size += _PyDict_KeysSize(ptr[u8](et.view(1)[0].ht_cached_keys));
        }
    } else {
        size = u64(PyTypeObject_SIZE);
    }
    return PyLong_FromSize_t(size);
}

impl type___sizeof__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return type___sizeof___impl(ptr[PyTypeObject](self_));
}

impl type_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    type = ptr[PyTypeObject](self_);
    if (type.view(1)[0].tp_flags & Py_TPFLAGS_HEAPTYPE) == 0 {
        msg = ptr[u8](PyMem_Malloc(u64(200)));
        if msg {
            snprintf(
                msg,
                u64(200),
                ptr[u8]("type_traverse() called on non-heap type '%.100s'"),
                type.view(1)[0].tp_name
            );
        }
        _PyObject_AssertFailed(
            self_,
            ptr[u8](),
            msg,
            ptr[u8]("Objects/typeobject.c"),
            i32(6646),
            ptr[u8]("type_traverse")
        );
    }
    status = visit_reference(type.view(1)[0].tp_dict, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(type.view(1)[0].tp_cache, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(type.view(1)[0].tp_mro, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(type.view(1)[0].tp_bases, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(ptr[PyObject](type.view(1)[0].tp_base), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(
        ptr[PyHeapTypeObject](self_).view(1)[0].ht_module, visitor, arg
    );
    if status != 0 {
        return status;
    }
    return 0;
}

impl type_clear(self_: ptr[PyObject]) -> i32 {
    type = ptr[PyTypeObject](self_);

    PyType_Modified(type);
    dct = lookup_tp_dict(type);
    if dct {
        PyDict_Clear(dct);
    }
    et = ptr[PyHeapTypeObject](self_);
    module = et.view(1)[0].ht_module;
    if module {
        et.view(1)[0].ht_module = NULL;
        object_decref(module);
    }
    mro = type.view(1)[0].tp_mro;
    if mro {
        type.view(1)[0].tp_mro = NULL;
        object_decref(mro);
    }
    return 0;
}

impl type_tp_is_gc(tp: ptr[PyObject]) -> i32 {
    return i32(ptr[PyTypeObject](tp).view(1)[0].tp_flags & Py_TPFLAGS_HEAPTYPE);
}

impl excess_args(args: ptr[PyObject], kwds: ptr[PyObject]) -> bool {
    return object_size(args) != 0
        or (kwds != NULL and dict_check(kwds) and dict_used(kwds) != 0);
}

impl object_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    type = object_type(self_);
    if excess_args(args, kwds) {
        if int(type.view(1)[0].tp_init) != int(ptr(object_init)) {
            PyErr_SetString(
                PyExc_TypeError,
                "object.__init__() takes exactly one argument (the instance to initialize)"
            );
            return -1;
        }
        if int(type.view(1)[0].tp_new) == int(ptr(object_new)) {
            PyErr_Format(
                PyExc_TypeError,
                "%.200s.__init__() takes exactly one argument (the instance to initialize)",
                type.view(1)[0].tp_name
            );
            return -1;
        }
    }
    return 0;
}

impl object_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if excess_args(args, kwds) {
        if int(type.view(1)[0].tp_new) != int(ptr(object_new)) {
            PyErr_SetString(
                PyExc_TypeError,
                "object.__new__() takes exactly one argument (the type to instantiate)"
            );
            return NULL;
        }
        if int(type.view(1)[0].tp_init) == int(ptr(object_init)) {
            PyErr_Format(
                PyExc_TypeError, "%.200s() takes no arguments", type.view(1)[0].tp_name
            );
            return NULL;
        }
    }
    if type_has_feature(type, Py_TPFLAGS_IS_ABSTRACT) {
        return object_new_abstract_error(type);
    }
    return type.view(1)[0].tp_alloc(type, 0);
}

impl object_new_abstract_error(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    abstract_methods = type_abstractmethods(ptr[PyObject](type), ptr());
    if not abstract_methods {
        return NULL;
    }
    sorted_methods = PySequence_List(abstract_methods);
    object_decref(abstract_methods);
    if not sorted_methods {
        return NULL;
    }
    if PyList_Sort(sorted_methods) != 0 {
        object_decref(sorted_methods);
        return NULL;
    }
    comma_w_quotes_sep = PyUnicode_FromString(ptr[u8]("', '"));
    if not comma_w_quotes_sep {
        object_decref(sorted_methods);
        return NULL;
    }
    joined = PyUnicode_Join(comma_w_quotes_sep, sorted_methods);
    object_decref(comma_w_quotes_sep);
    if not joined {
        object_decref(sorted_methods);
        return NULL;
    }
    method_count = PyObject_Size(sorted_methods);
    object_decref(sorted_methods);
    if method_count == -1 {
        object_decref(joined);
        return NULL;
    }
    plural: ptr[u8] = ptr[u8]("");
    if method_count > 1 {
        plural = ptr[u8]("s");
    }
    PyErr_Format(
        PyExc_TypeError,
        "Can't instantiate abstract class %s without an implementation for abstract method%s '%U'",
        type.view(1)[0].tp_name,
        plural,
        joined
    );
    object_decref(joined);
    return NULL;
}

impl object_dealloc(self_: ptr[PyObject]) {
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl object_repr(self_: ptr[PyObject]) -> ptr[PyObject] {
    type = object_type(self_);
    mod = type_module(type);
    if not mod {
        PyErr_Clear();
    } elif not unicode_check(mod) {
        old = mod;
        mod = NULL;
        object_decref(old);
    }
    name = type_qualname(ptr[PyObject](type), ptr());
    if not name {
        object_xdecref(mod);
        return NULL;
    }
    rtn = NULL;
    if mod and _PyUnicode_Equal(mod, py_id(_Py_ID_builtins)) == 0 {
        rtn = PyUnicode_FromFormat("<%U.%U object at %p>", mod, name, self_);
    } else {
        rtn = PyUnicode_FromFormat("<%s object at %p>", type.view(1)[0].tp_name, self_);
    }
    object_xdecref(mod);
    object_decref(name);
    return rtn;
}

impl object_str(self_: ptr[PyObject]) -> ptr[PyObject] {
    type = object_type(self_);
    if int(type.view(1)[0].tp_repr) == 0 {
        return object_repr(self_);
    }
    return type.view(1)[0].tp_repr(self_);
}

impl object_richcompare(
    self_: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if op == Py_EQ {
        if self_ == other {
            return object_new_ref(py_true());
        }
        return object_new_ref(Py_NotImplemented);
    }
    if op == Py_NE {
        type = object_type(self_);
        if int(type.view(1)[0].tp_richcompare) == 0 {
            return object_new_ref(Py_NotImplemented);
        }
        res = type.view(1)[0].tp_richcompare(self_, other, Py_EQ);
        if res and res != Py_NotImplemented {
            ok = PyObject_IsTrue(res);
            object_decref(res);
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                return object_new_ref(py_false());
            }
            return object_new_ref(py_true());
        }
        return res;
    }
    return object_new_ref(Py_NotImplemented);
}

impl object_get_class(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return object_new_ref(ptr[PyObject](object_type(self_)));
}

impl compatible_with_tp_base(child: ptr[PyTypeObject]) -> i32 {
    parent = child.view(1)[0].tp_base;
    if not parent {
        return 0;
    }
    c = child.view(1);
    p = parent.view(1);
    return i32(
        c[0].tp_basicsize == p[0].tp_basicsize
            and c[0].tp_itemsize == p[0].tp_itemsize
            and c[0].tp_dictoffset == p[0].tp_dictoffset
            and c[0].tp_weaklistoffset == p[0].tp_weaklistoffset
            and (c[0].tp_flags & Py_TPFLAGS_HAVE_GC)
                == (p[0].tp_flags & Py_TPFLAGS_HAVE_GC)
            and (
                int(c[0].tp_dealloc) == int(ptr(subtype_dealloc))
                or int(c[0].tp_dealloc) == int(p[0].tp_dealloc)
            )
    );
}

impl same_slots_added(a: ptr[PyTypeObject], b: ptr[PyTypeObject]) -> i32 {
    base = a.view(1)[0].tp_base;
    size = base.view(1)[0].tp_basicsize;
    if a.view(1)[0].tp_dictoffset == size and b.view(1)[0].tp_dictoffset == size {
        size += 8;
    }
    if a.view(1)[0].tp_weaklistoffset == size
        and b.view(1)[0].tp_weaklistoffset == size {
        size += 8;
    }

    if not type_has_feature(a, Py_TPFLAGS_HEAPTYPE)
        or not type_has_feature(b, Py_TPFLAGS_HEAPTYPE) {
        return 0;
    }
    slots_a = ptr[PyHeapTypeObject](a).view(1)[0].ht_slots;
    slots_b = ptr[PyHeapTypeObject](b).view(1)[0].ht_slots;
    if slots_a and slots_b {
        if PyObject_RichCompareBool(slots_a, slots_b, Py_EQ) != 1 {
            return 0;
        }
        size += 8 * object_size(slots_a);
    }
    return i32(size == a.view(1)[0].tp_basicsize and size == b.view(1)[0].tp_basicsize);
}

impl compatible_for_assignment(
    oldto: ptr[PyTypeObject], newto: ptr[PyTypeObject], attr: ptr[u8]
) -> i32 {
    if int(newto.view(1)[0].tp_free) != int(oldto.view(1)[0].tp_free) {
        PyErr_Format(
            PyExc_TypeError,
            "%s assignment: '%s' deallocator differs from '%s'",
            attr,
            newto.view(1)[0].tp_name,
            oldto.view(1)[0].tp_name
        );
        return 0;
    }
    newbase = newto;
    oldbase = oldto;
    while compatible_with_tp_base(newbase) != 0 {
        newbase = newbase.view(1)[0].tp_base;
    }
    while compatible_with_tp_base(oldbase) != 0 {
        oldbase = oldbase.view(1)[0].tp_base;
    }

    if not (
        newbase != oldbase
        and (
            newbase.view(1)[0].tp_base != oldbase.view(1)[0].tp_base
            or same_slots_added(newbase, oldbase) == 0
        )
    )
        and (oldto.view(1)[0].tp_flags & Py_TPFLAGS_INLINE_VALUES)
            == (newto.view(1)[0].tp_flags & Py_TPFLAGS_INLINE_VALUES)
        and (oldto.view(1)[0].tp_flags & TPFLAGS_PREHEADER)
            == (newto.view(1)[0].tp_flags & TPFLAGS_PREHEADER) {
        return 1;
    }
    PyErr_Format(
        PyExc_TypeError,
        "%s assignment: '%s' object layout differs from '%s'",
        attr,
        newto.view(1)[0].tp_name,
        oldto.view(1)[0].tp_name
    );
    return 0;
}

impl object_set_class_world_stopped(
    self_: ptr[PyObject], newto: ptr[PyTypeObject]
) -> i32 {
    oldto = object_type(self_);
    if not (
        PyType_IsSubtype(newto, addressof(PyModule_Type)) != 0
        and PyType_IsSubtype(oldto, addressof(PyModule_Type)) != 0
    )
        and (
            type_has_feature(newto, Py_TPFLAGS_IMMUTABLETYPE)
            or type_has_feature(oldto, Py_TPFLAGS_IMMUTABLETYPE)
        ) {
        PyErr_Format(
            PyExc_TypeError,
            "__class__ assignment only supported for mutable types or ModuleType subclasses"
        );
        return -1;
    }
    if compatible_for_assignment(oldto, newto, ptr[u8]("__class__")) == 0 {
        return -1;
    }

    if type_has_feature(oldto, Py_TPFLAGS_INLINE_VALUES) {
        dct = managed_dict(self_);
        if not dct {
            dct = _PyObject_MaterializeManagedDict_LockHeld(self_);
            if not dct {
                return -1;
            }
        }
        if _PyDict_DetachFromObject(dct, self_) < 0 {
            return -1;
        }
    }
    if type_has_feature(newto, Py_TPFLAGS_HEAPTYPE) {
        object_incref(ptr[PyObject](newto));
    }

    ptr[_object](self_).view(1)[0].ob_type = newto;
    return 0;
}

impl object_set_class(self_: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    if not value {
        PyErr_SetString(PyExc_TypeError, "can't delete __class__ attribute");
        return -1;
    }
    if not type_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            "__class__ must be set to a class, not '%s' object",
            object_type(value).view(1)[0].tp_name
        );
        return -1;
    }
    newto = ptr[PyTypeObject](value);
    if PySys_Audit("object.__setattr__", "OsO", self_, ptr[u8]("__class__"), value)
        < 0 {
        return -1;
    }
    oldto = object_type(self_);
    res = object_set_class_world_stopped(self_, newto);
    if res == 0 {
        if type_has_feature(oldto, Py_TPFLAGS_HEAPTYPE) {
            object_decref(ptr[PyObject](oldto));
        }

        counter = current_interp() + PyInterpreterState_RARE_SET_CLASS;
        if counter.view(1)[0] < u8(255) {
            counter.view(1)[0] = counter.view(1)[0] + u8(1);
        }
        return 0;
    }
    return res;
}

impl import_copyreg -> ptr[PyObject] {
    copyreg_module = PyImport_GetModule(py_id(_Py_ID_copyreg));
    if copyreg_module {
        return copyreg_module;
    }
    if PyErr_Occurred() {
        return NULL;
    }
    return PyImport_Import(py_id(_Py_ID_copyreg));
}

impl _PyType_GetSlotNames(cls: ptr[PyTypeObject]) -> ptr[PyObject] {
    slotnames = NULL;
    dct = lookup_tp_dict(cls);
    if PyDict_GetItemRef(dct, py_id(_Py_ID___slotnames__), &mut slotnames) < 0 {
        return NULL;
    }
    if slotnames {
        if slotnames != Py_None and not list_check(slotnames) {
            PyErr_Format(
                PyExc_TypeError,
                "%.200s.__slotnames__ should be a list or None, not %.200s",
                cls.view(1)[0].tp_name,
                object_type(slotnames).view(1)[0].tp_name
            );
            object_decref(slotnames);
            return NULL;
        }
        return slotnames;
    }

    copyreg = import_copyreg();
    if not copyreg {
        return NULL;
    }

    small: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut small));
    stack.view(2)[0] = copyreg;
    stack.view(2)[1] = ptr[PyObject](cls);
    result = PyObject_VectorcallMethod(
        py_id(_Py_ID__slotnames), stack, u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
    object_decref(copyreg);
    if not result {
        return NULL;
    }
    if result != Py_None and not list_check(result) {
        PyErr_SetString(
            PyExc_TypeError, "copyreg._slotnames didn't return a list or None"
        );
        object_decref(result);
        return NULL;
    }
    return result;
}

impl object_getstate_default(obj_: ptr[PyObject], required: i32) -> ptr[PyObject] {
    if required != 0 and object_type(obj_).view(1)[0].tp_itemsize != 0 {
        PyErr_Format(
            PyExc_TypeError,
            "cannot pickle %.200s objects",
            object_type(obj_).view(1)[0].tp_name
        );
        return NULL;
    }
    state = NULL;
    if _PyObject_IsInstanceDictEmpty(obj_) != 0 {
        state = object_new_ref(Py_None);
    } else {
        state = PyObject_GenericGetDict(obj_, ptr());
        if not state {
            return NULL;
        }
    }
    slotnames = _PyType_GetSlotNames(object_type(obj_));
    if not slotnames {
        object_decref(state);
        return NULL;
    }

    if required != 0 {
        type = object_type(obj_);
        basicsize = addressof(PyBaseObject_Type).view(1)[0].tp_basicsize;
        if type.view(1)[0].tp_dictoffset != 0
            and (type.view(1)[0].tp_flags & Py_TPFLAGS_MANAGED_DICT) == u64(0) {
            basicsize += 8;
        }
        if type.view(1)[0].tp_weaklistoffset > 0 {
            basicsize += 8;
        }
        if slotnames != Py_None {
            basicsize += 8 * object_size(slotnames);
        }
        if type.view(1)[0].tp_basicsize > basicsize {
            object_decref(slotnames);
            object_decref(state);
            PyErr_Format(
                PyExc_TypeError,
                "cannot pickle '%.200s' object",
                object_type(obj_).view(1)[0].tp_name
            );
            return NULL;
        }
    }
    if slotnames != Py_None and object_size(slotnames) > 0 {
        slots = PyDict_New();
        if not slots {
            object_decref(slotnames);
            object_decref(state);
            return NULL;
        }
        slotnames_size = object_size(slotnames);
        for i in range(slotnames_size) {
            name = object_new_ref(
                (ptr[PyListObject](slotnames).view(1)[0].ob_item + i).view(1)[0]
            );
            value = NULL;
            if PyObject_GetOptionalAttr(obj_, name, &mut value) < 0 {
                object_decref(name);
                object_decref(slotnames);
                object_decref(slots);
                object_decref(state);
                return NULL;
            }
            if not value {
                object_decref(name);
            } else {
                err = PyDict_SetItem(slots, name, value);
                object_decref(name);
                object_decref(value);
                if err != 0 {
                    object_decref(slotnames);
                    object_decref(slots);
                    object_decref(state);
                    return NULL;
                }
            }

            if slotnames_size != object_size(slotnames) {
                PyErr_Format(
                    PyExc_RuntimeError, "__slotnames__ changed size during iteration"
                );
                object_decref(slotnames);
                object_decref(slots);
                object_decref(state);
                return NULL;
            }
        }

        if dict_used(slots) > 0 {
            state2 = PyTuple_Pack(2, state, slots);
            object_decref(state);
            if not state2 {
                object_decref(slotnames);
                object_decref(slots);
                return NULL;
            }
            state = state2;
        }
        object_decref(slots);
    }
    object_decref(slotnames);
    return state;
}

impl object_getstate(obj_: ptr[PyObject], required: i32) -> ptr[PyObject] {
    getstate = PyObject_GetAttr(obj_, py_id(_Py_ID___getstate__));
    if not getstate {
        return NULL;
    }

    is_default = False;
    if object_type_check(getstate, addressof(PyCFunction_Type)) {
        func = ptr[PyCFunctionObject](getstate);
        ml = func.view(1)[0].m_ml;
        bound_self = NULL;
        if (ml.view(1)[0].ml_flags & METH_STATIC) == 0 {
            bound_self = func.view(1)[0].m_self;
        }
        is_default = bound_self == obj_
            and int(ml.view(1)[0].ml_meth) == int(ptr(object___getstate__));
    }
    state = NULL;
    if is_default {
        state = object_getstate_default(obj_, required);
    } else {
        state = PyObject_CallNoArgs(getstate);
    }
    object_decref(getstate);
    return state;
}

impl object___getstate___impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return object_getstate_default(self_, 0);
}

impl object___getstate__(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return object___getstate___impl(self_);
}

impl _PyObject_GetNewArguments(
    obj_: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]] {
    getnewargs_ex = _PyObject_LookupSpecial(obj_, py_id(_Py_ID___getnewargs_ex__));
    if getnewargs_ex {
        newargs = PyObject_CallNoArgs(getnewargs_ex);
        object_decref(getnewargs_ex);
        if not newargs {
            return (i32(-1), NULL, NULL);
        }
        if not tuple_check(newargs) {
            PyErr_Format(
                PyExc_TypeError,
                "__getnewargs_ex__ should return a tuple, not '%.200s'",
                object_type(newargs).view(1)[0].tp_name
            );
            object_decref(newargs);
            return (i32(-1), NULL, NULL);
        }
        if object_size(newargs) != 2 {
            size: i64 = object_size(newargs);
            PyErr_Format(
                PyExc_ValueError,
                "__getnewargs_ex__ should return a tuple of length 2, not %zd",
                size
            );
            object_decref(newargs);
            return (i32(-1), NULL, NULL);
        }
        args = object_new_ref(tuple_get_item(newargs, 0));
        kwargs = object_new_ref(tuple_get_item(newargs, 1));
        object_decref(newargs);

        if not tuple_check(args) {
            PyErr_Format(
                PyExc_TypeError,
                "first item of the tuple returned by __getnewargs_ex__ must be a tuple, not '%.200s'",
                object_type(args).view(1)[0].tp_name
            );
            object_decref(args);
            object_decref(kwargs);
            return (i32(-1), NULL, NULL);
        }
        if not dict_check(kwargs) {
            PyErr_Format(
                PyExc_TypeError,
                "second item of the tuple returned by __getnewargs_ex__ must be a dict, not '%.200s'",
                object_type(kwargs).view(1)[0].tp_name
            );
            object_decref(args);
            object_decref(kwargs);
            return (i32(-1), NULL, NULL);
        }
        return (i32(0), args, kwargs);
    } elif PyErr_Occurred() {
        return (i32(-1), NULL, NULL);
    }

    getnewargs = _PyObject_LookupSpecial(obj_, py_id(_Py_ID___getnewargs__));
    if getnewargs {
        newargs_only = PyObject_CallNoArgs(getnewargs);
        object_decref(getnewargs);
        if not newargs_only {
            return (i32(-1), NULL, NULL);
        }
        if not tuple_check(newargs_only) {
            PyErr_Format(
                PyExc_TypeError,
                "__getnewargs__ should return a tuple, not '%.200s'",
                object_type(newargs_only).view(1)[0].tp_name
            );
            object_decref(newargs_only);
            return (i32(-1), NULL, NULL);
        }
        return (i32(0), newargs_only, NULL);
    } elif PyErr_Occurred() {
        return (i32(-1), NULL, NULL);
    }
    return (i32(0), NULL, NULL);
}

impl _PyObject_GetItemsIter(
    obj_: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]] {
    listitems = NULL;
    if not list_check(obj_) {
        listitems = object_new_ref(Py_None);
    } else {
        listitems = PyObject_GetIter(obj_);
        if not listitems {
            return (i32(-1), NULL, NULL);
        }
    }
    dictitems = NULL;
    if not dict_check(obj_) {
        dictitems = object_new_ref(Py_None);
    } else {
        small: own StackArgs = StackArgs();
        stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut small));
        stack.view(1)[0] = obj_;
        items = PyObject_VectorcallMethod(
            py_id(_Py_ID_items), stack, u64(1) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
        );
        if not items {
            object_decref(listitems);
            return (i32(-1), NULL, NULL);
        }
        dictitems = PyObject_GetIter(items);
        object_decref(items);
        if not dictitems {
            object_decref(listitems);
            return (i32(-1), NULL, NULL);
        }
    }
    return (i32(0), listitems, dictitems);
}

impl reduce_newobj(obj_: ptr[PyObject]) -> ptr[PyObject] {
    if int(object_type(obj_).view(1)[0].tp_new) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "cannot pickle '%.200s' object",
            object_type(obj_).view(1)[0].tp_name
        );
        return NULL;
    }
    (status, args, kwargs) = _PyObject_GetNewArguments(obj_);
    if status < 0 {
        return NULL;
    }
    copyreg = import_copyreg();
    if not copyreg {
        object_xdecref(args);
        object_xdecref(kwargs);
        return NULL;
    }
    hasargs = args != NULL;
    newobj = NULL;
    newargs = NULL;
    if not kwargs or dict_used(kwargs) == 0 {
        object_xdecref(kwargs);
        newobj = PyObject_GetAttr(copyreg, py_id(_Py_ID___newobj__));
        object_decref(copyreg);
        if not newobj {
            object_xdecref(args);
            return NULL;
        }
        n: i64 = 0;
        if args {
            n = object_size(args);
        }
        newargs = PyTuple_New(n + 1);
        if not newargs {
            object_xdecref(args);
            object_decref(newobj);
            return NULL;
        }
        cls = ptr[PyObject](object_type(obj_));
        tuple_set_item(newargs, 0, object_new_ref(cls));
        for i in range(n) {
            v = tuple_get_item(args, i);
            tuple_set_item(newargs, i + 1, object_new_ref(v));
        }
        object_xdecref(args);
    } elif args {
        newobj = PyObject_GetAttr(copyreg, py_id(_Py_ID___newobj_ex__));
        object_decref(copyreg);
        if not newobj {
            object_decref(args);
            object_decref(kwargs);
            return NULL;
        }
        newargs = PyTuple_Pack(3, ptr[PyObject](object_type(obj_)), args, kwargs);
        object_decref(args);
        object_decref(kwargs);
        if not newargs {
            object_decref(newobj);
            return NULL;
        }
    } else {
        object_decref(copyreg);
        object_decref(kwargs);
        PyErr_BadInternalCall();
        return NULL;
    }
    required: i32 = 0;
    if not (hasargs or list_check(obj_) or dict_check(obj_)) {
        required = 1;
    }
    state = object_getstate(obj_, required);
    if not state {
        object_decref(newobj);
        object_decref(newargs);
        return NULL;
    }
    (items_status, listitems, dictitems) = _PyObject_GetItemsIter(obj_);
    if items_status < 0 {
        object_decref(newobj);
        object_decref(newargs);
        object_decref(state);
        return NULL;
    }
    result = PyTuple_Pack(5, newobj, newargs, state, listitems, dictitems);
    object_decref(newobj);
    object_decref(newargs);
    object_decref(state);
    object_decref(listitems);
    object_decref(dictitems);
    return result;
}

impl _common_reduce(self_: ptr[PyObject], proto: i32) -> ptr[PyObject] {
    if proto >= 2 {
        return reduce_newobj(self_);
    }
    copyreg = import_copyreg();
    if not copyreg {
        return NULL;
    }
    res = PyObject_CallMethod(copyreg, "_reduce_ex", "Oi", self_, proto);
    object_decref(copyreg);
    return res;
}

impl object___reduce___impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return _common_reduce(self_, 0);
}

impl object___reduce__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return object___reduce___impl(self_);
}

impl object___reduce_ex___impl(self_: ptr[PyObject], protocol: i32) -> ptr[PyObject] {
    reduce = NULL;
    if PyObject_GetOptionalAttr(self_, py_id(_Py_ID___reduce__), &mut reduce) < 0 {
        return NULL;
    }
    if reduce {
        cls = ptr[PyObject](object_type(self_));
        clsreduce = PyObject_GetAttr(cls, py_id(_Py_ID___reduce__));
        if not clsreduce {
            object_decref(reduce);
            return NULL;
        }

        interp = current_interp();
        objreduce = ptr[ptr[PyObject]](
            interp + PyInterpreterState_CACHED_OBJREDUCE
        ).view(
            1
        )[0];
        overrides = clsreduce != objreduce;
        object_decref(clsreduce);
        if overrides {
            res = PyObject_CallNoArgs(reduce);
            object_decref(reduce);
            return res;
        }
        object_decref(reduce);
    }
    return _common_reduce(self_, protocol);
}

impl object___reduce_ex__(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    protocol = PyLong_AsInt(arg);
    if protocol == -1 and PyErr_Occurred() {
        return NULL;
    }
    return object___reduce_ex___impl(self_, protocol);
}

impl object_subclasshook(cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(Py_NotImplemented);
}

impl object_init_subclass(cls: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(Py_None);
}

impl object___format___impl(
    self_: ptr[PyObject], format_spec: ptr[PyObject]
) -> ptr[PyObject] {
    if unicode_length(format_spec) > 0 {
        PyErr_Format(
            PyExc_TypeError,
            "unsupported format string passed to %.200s.__format__",
            object_type(self_).view(1)[0].tp_name
        );
        return NULL;
    }
    return PyObject_Str(self_);
}

impl object___format__(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(arg) {
        _PyArg_BadArgument("__format__", "argument", "str", arg);
        return NULL;
    }
    return object___format___impl(self_, arg);
}

impl object___sizeof___impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    res: i64 = 0;
    isize = object_type(self_).view(1)[0].tp_itemsize;
    if isize > 0 {
        res = object_size(self_) * isize;
    }
    res += object_type(self_).view(1)[0].tp_basicsize;
    return PyLong_FromSsize_t(res);
}

impl object___sizeof__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return object___sizeof___impl(self_);
}

impl object___dir___impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    dct = NULL;
    itsclass = NULL;

    if PyObject_GetOptionalAttr(self_, py_id(_Py_ID___dict__), &mut dct) < 0 {
        return NULL;
    }
    if not dct {
        dct = PyDict_New();
    } elif not dict_check(dct) {
        object_decref(dct);
        dct = PyDict_New();
    } else {
        temp = PyDict_Copy(dct);
        old = dct;
        dct = temp;
        object_decref(old);
    }
    if not dct {
        return NULL;
    }

    if PyObject_GetOptionalAttr(self_, py_id(_Py_ID___class__), &mut itsclass) < 0 {
        object_decref(dct);
        return NULL;
    }

    if itsclass and merge_class_dict(dct, itsclass) < 0 {
        object_decref(itsclass);
        object_decref(dct);
        return NULL;
    }
    result = PyDict_Keys(dct);
    object_xdecref(itsclass);
    object_decref(dct);
    return result;
}

impl object___dir__(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return object___dir___impl(self_);
}

impl type_add_method(type: ptr[PyTypeObject], meth: ptr[PyMethodDef]) -> i32 {
    descr = NULL;
    isdescr = True;
    if (meth.view(1)[0].ml_flags & METH_CLASS) != 0 {
        if (meth.view(1)[0].ml_flags & METH_STATIC) != 0 {
            PyErr_SetString(PyExc_ValueError, "method cannot be both class and static");
            return -1;
        }
        descr = PyDescr_NewClassMethod(type, meth);
    } elif (meth.view(1)[0].ml_flags & METH_STATIC) != 0 {
        cfunc = PyCFunction_NewEx(meth, ptr[PyObject](type), NULL);
        if not cfunc {
            return -1;
        }
        descr = PyStaticMethod_New(cfunc);
        isdescr = False;
        object_decref(cfunc);
    } else {
        descr = PyDescr_NewMethod(type, meth);
    }
    if not descr {
        return -1;
    }
    name = NULL;
    if isdescr {
        name = ptr[PyDescrObject](descr).view(1)[0].d_name;
    } else {
        name = PyUnicode_FromString(meth.view(1)[0].ml_name);
        if not name {
            object_decref(descr);
            return -1;
        }
    }
    err = False;
    dct = lookup_tp_dict(type);
    if (meth.view(1)[0].ml_flags & METH_COEXIST) == 0 {
        err = PyDict_SetDefaultRef(dct, name, descr, None) < 0;
    } else {
        err = PyDict_SetItem(dct, name, descr) < 0;
    }
    if not isdescr {
        object_decref(name);
    }
    object_decref(descr);
    if err {
        return -1;
    }
    return 0;
}

impl type_add_methods(type: ptr[PyTypeObject]) -> i32 {
    meth = type.view(1)[0].tp_methods;
    if not meth {
        return 0;
    }
    while meth.view(1)[0].ml_name {
        if type_add_method(type, meth) < 0 {
            return -1;
        }
        meth = meth + 1;
    }
    return 0;
}

impl type_add_members(type: ptr[PyTypeObject]) -> i32 {
    memb = type.view(1)[0].tp_members;
    if not memb {
        return 0;
    }
    dct = lookup_tp_dict(type);
    while memb.view(1)[0].name {
        descr = PyDescr_NewMember(type, memb);
        if not descr {
            return -1;
        }
        if PyDict_SetDefaultRef(
            dct, ptr[PyDescrObject](descr).view(1)[0].d_name, descr, None
        )
            < 0 {
            object_decref(descr);
            return -1;
        }
        object_decref(descr);
        memb = memb + 1;
    }
    return 0;
}

impl type_add_getset(type: ptr[PyTypeObject]) -> i32 {
    gsp = type.view(1)[0].tp_getset;
    if not gsp {
        return 0;
    }
    dct = lookup_tp_dict(type);
    while gsp.view(1)[0].name {
        descr = PyDescr_NewGetSet(type, gsp);
        if not descr {
            return -1;
        }
        if PyDict_SetDefaultRef(
            dct, ptr[PyDescrObject](descr).view(1)[0].d_name, descr, None
        )
            < 0 {
            object_decref(descr);
            return -1;
        }
        object_decref(descr);
        gsp = gsp + 1;
    }
    return 0;
}

impl inherit_special(type: ptr[PyTypeObject], base: ptr[PyTypeObject]) {
    if (type.view(1)[0].tp_flags & Py_TPFLAGS_HAVE_GC) == 0
        and (base.view(1)[0].tp_flags & Py_TPFLAGS_HAVE_GC) != 0
        and (
            int(type.view(1)[0].tp_traverse) == 0 and int(type.view(1)[0].tp_clear) == 0
        ) {
        type_add_flags(type, Py_TPFLAGS_HAVE_GC);
        if int(type.view(1)[0].tp_traverse) == 0 {
            type.view(1)[0].tp_traverse = base.view(1)[0].tp_traverse;
        }
        if int(type.view(1)[0].tp_clear) == 0 {
            type.view(1)[0].tp_clear = base.view(1)[0].tp_clear;
        }
    }
    type_add_flags(type, base.view(1)[0].tp_flags & TPFLAGS_PREHEADER);
    if type.view(1)[0].tp_basicsize == 0 {
        type.view(1)[0].tp_basicsize = base.view(1)[0].tp_basicsize;
    }

    if type.view(1)[0].tp_itemsize == 0 {
        type.view(1)[0].tp_itemsize = base.view(1)[0].tp_itemsize;
    }
    if type.view(1)[0].tp_weaklistoffset == 0 {
        type.view(1)[0].tp_weaklistoffset = base.view(1)[0].tp_weaklistoffset;
    }
    if type.view(1)[0].tp_dictoffset == 0 {
        type.view(1)[0].tp_dictoffset = base.view(1)[0].tp_dictoffset;
    }

    mro = lookup_tp_mro(base);
    flags: u64 = 0;
    if is_subtype_with_mro(mro, base, ptr[PyTypeObject](PyExc_BaseException)) != 0 {
        flags |= Py_TPFLAGS_BASE_EXC_SUBCLASS;
    } elif is_subtype_with_mro(mro, base, addressof(PyType_Type)) != 0 {
        flags |= Py_TPFLAGS_TYPE_SUBCLASS;
    } elif is_subtype_with_mro(mro, base, addressof(PyLong_Type)) != 0 {
        flags |= Py_TPFLAGS_LONG_SUBCLASS;
    } elif is_subtype_with_mro(mro, base, ptr[PyTypeObject](addressof(PyBytes_Type)))
        != 0 {
        flags |= Py_TPFLAGS_BYTES_SUBCLASS;
    } elif is_subtype_with_mro(mro, base, addressof(PyUnicode_Type)) != 0 {
        flags |= Py_TPFLAGS_UNICODE_SUBCLASS;
    } elif is_subtype_with_mro(mro, base, addressof(PyTuple_Type)) != 0 {
        flags |= Py_TPFLAGS_TUPLE_SUBCLASS;
    } elif is_subtype_with_mro(mro, base, addressof(PyList_Type)) != 0 {
        flags |= Py_TPFLAGS_LIST_SUBCLASS;
    } elif is_subtype_with_mro(mro, base, addressof(PyDict_Type)) != 0 {
        flags |= Py_TPFLAGS_DICT_SUBCLASS;
    }

    if type_has_feature(base, _Py_TPFLAGS_MATCH_SELF) {
        flags |= _Py_TPFLAGS_MATCH_SELF;
    }
    if type_has_feature(base, Py_TPFLAGS_ITEMS_AT_END) {
        flags |= Py_TPFLAGS_ITEMS_AT_END;
    }
    type_add_flags(type, flags);
}

impl overrides_hash(type: ptr[PyTypeObject]) -> i32 {
    dct = lookup_tp_dict(type);

    r = PyDict_Contains(dct, py_id(_Py_ID___eq__));
    if r == 0 {
        r = PyDict_Contains(dct, py_id(_Py_ID___hash__));
    }
    return r;
}

impl inherit_slots(type: ptr[PyTypeObject], base: ptr[PyTypeObject]) -> i32 {
    basebase = base.view(1)[0].tp_base;

    num_t = type.view(1)[0].tp_as_number;
    num_b = base.view(1)[0].tp_as_number;
    if num_t and num_b {
        num_bb = basebase.view(1)[0].tp_as_number;
        if int(num_t.view(1)[0].nb_add) == 0
            and int(num_b.view(1)[0].nb_add) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_add) != int(num_bb.view(1)[0].nb_add)
            ) {
            num_t.view(1)[0].nb_add = num_b.view(1)[0].nb_add;
        }
        if int(num_t.view(1)[0].nb_subtract) == 0
            and int(num_b.view(1)[0].nb_subtract) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_subtract)
                    != int(num_bb.view(1)[0].nb_subtract)
            ) {
            num_t.view(1)[0].nb_subtract = num_b.view(1)[0].nb_subtract;
        }
        if int(num_t.view(1)[0].nb_multiply) == 0
            and int(num_b.view(1)[0].nb_multiply) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_multiply)
                    != int(num_bb.view(1)[0].nb_multiply)
            ) {
            num_t.view(1)[0].nb_multiply = num_b.view(1)[0].nb_multiply;
        }
        if int(num_t.view(1)[0].nb_remainder) == 0
            and int(num_b.view(1)[0].nb_remainder) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_remainder)
                    != int(num_bb.view(1)[0].nb_remainder)
            ) {
            num_t.view(1)[0].nb_remainder = num_b.view(1)[0].nb_remainder;
        }
        if int(num_t.view(1)[0].nb_divmod) == 0
            and int(num_b.view(1)[0].nb_divmod) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_divmod) != int(num_bb.view(1)[0].nb_divmod)
            ) {
            num_t.view(1)[0].nb_divmod = num_b.view(1)[0].nb_divmod;
        }
        if int(num_t.view(1)[0].nb_power) == 0
            and int(num_b.view(1)[0].nb_power) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_power) != int(num_bb.view(1)[0].nb_power)
            ) {
            num_t.view(1)[0].nb_power = num_b.view(1)[0].nb_power;
        }
        if int(num_t.view(1)[0].nb_negative) == 0
            and int(num_b.view(1)[0].nb_negative) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_negative)
                    != int(num_bb.view(1)[0].nb_negative)
            ) {
            num_t.view(1)[0].nb_negative = num_b.view(1)[0].nb_negative;
        }
        if int(num_t.view(1)[0].nb_positive) == 0
            and int(num_b.view(1)[0].nb_positive) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_positive)
                    != int(num_bb.view(1)[0].nb_positive)
            ) {
            num_t.view(1)[0].nb_positive = num_b.view(1)[0].nb_positive;
        }
        if int(num_t.view(1)[0].nb_absolute) == 0
            and int(num_b.view(1)[0].nb_absolute) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_absolute)
                    != int(num_bb.view(1)[0].nb_absolute)
            ) {
            num_t.view(1)[0].nb_absolute = num_b.view(1)[0].nb_absolute;
        }
        if int(num_t.view(1)[0].nb_bool) == 0
            and int(num_b.view(1)[0].nb_bool) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_bool) != int(num_bb.view(1)[0].nb_bool)
            ) {
            num_t.view(1)[0].nb_bool = num_b.view(1)[0].nb_bool;
        }
        if int(num_t.view(1)[0].nb_invert) == 0
            and int(num_b.view(1)[0].nb_invert) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_invert) != int(num_bb.view(1)[0].nb_invert)
            ) {
            num_t.view(1)[0].nb_invert = num_b.view(1)[0].nb_invert;
        }
        if int(num_t.view(1)[0].nb_lshift) == 0
            and int(num_b.view(1)[0].nb_lshift) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_lshift) != int(num_bb.view(1)[0].nb_lshift)
            ) {
            num_t.view(1)[0].nb_lshift = num_b.view(1)[0].nb_lshift;
        }
        if int(num_t.view(1)[0].nb_rshift) == 0
            and int(num_b.view(1)[0].nb_rshift) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_rshift) != int(num_bb.view(1)[0].nb_rshift)
            ) {
            num_t.view(1)[0].nb_rshift = num_b.view(1)[0].nb_rshift;
        }
        if int(num_t.view(1)[0].nb_and) == 0
            and int(num_b.view(1)[0].nb_and) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_and) != int(num_bb.view(1)[0].nb_and)
            ) {
            num_t.view(1)[0].nb_and = num_b.view(1)[0].nb_and;
        }
        if int(num_t.view(1)[0].nb_xor) == 0
            and int(num_b.view(1)[0].nb_xor) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_xor) != int(num_bb.view(1)[0].nb_xor)
            ) {
            num_t.view(1)[0].nb_xor = num_b.view(1)[0].nb_xor;
        }
        if int(num_t.view(1)[0].nb_or) == 0
            and int(num_b.view(1)[0].nb_or) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_or) != int(num_bb.view(1)[0].nb_or)
            ) {
            num_t.view(1)[0].nb_or = num_b.view(1)[0].nb_or;
        }
        if int(num_t.view(1)[0].nb_int) == 0
            and int(num_b.view(1)[0].nb_int) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_int) != int(num_bb.view(1)[0].nb_int)
            ) {
            num_t.view(1)[0].nb_int = num_b.view(1)[0].nb_int;
        }
        if int(num_t.view(1)[0].nb_float) == 0
            and int(num_b.view(1)[0].nb_float) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_float) != int(num_bb.view(1)[0].nb_float)
            ) {
            num_t.view(1)[0].nb_float = num_b.view(1)[0].nb_float;
        }
        if int(num_t.view(1)[0].nb_inplace_add) == 0
            and int(num_b.view(1)[0].nb_inplace_add) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_add)
                    != int(num_bb.view(1)[0].nb_inplace_add)
            ) {
            num_t.view(1)[0].nb_inplace_add = num_b.view(1)[0].nb_inplace_add;
        }
        if int(num_t.view(1)[0].nb_inplace_subtract) == 0
            and int(num_b.view(1)[0].nb_inplace_subtract) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_subtract)
                    != int(num_bb.view(1)[0].nb_inplace_subtract)
            ) {
            num_t.view(1)[0].nb_inplace_subtract = num_b.view(1)[0].nb_inplace_subtract;
        }
        if int(num_t.view(1)[0].nb_inplace_multiply) == 0
            and int(num_b.view(1)[0].nb_inplace_multiply) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_multiply)
                    != int(num_bb.view(1)[0].nb_inplace_multiply)
            ) {
            num_t.view(1)[0].nb_inplace_multiply = num_b.view(1)[0].nb_inplace_multiply;
        }
        if int(num_t.view(1)[0].nb_inplace_remainder) == 0
            and int(num_b.view(1)[0].nb_inplace_remainder) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_remainder)
                    != int(num_bb.view(1)[0].nb_inplace_remainder)
            ) {
            num_t.view(1)[0].nb_inplace_remainder = num_b.view(1)[
                0
            ].nb_inplace_remainder;
        }
        if int(num_t.view(1)[0].nb_inplace_power) == 0
            and int(num_b.view(1)[0].nb_inplace_power) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_power)
                    != int(num_bb.view(1)[0].nb_inplace_power)
            ) {
            num_t.view(1)[0].nb_inplace_power = num_b.view(1)[0].nb_inplace_power;
        }
        if int(num_t.view(1)[0].nb_inplace_lshift) == 0
            and int(num_b.view(1)[0].nb_inplace_lshift) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_lshift)
                    != int(num_bb.view(1)[0].nb_inplace_lshift)
            ) {
            num_t.view(1)[0].nb_inplace_lshift = num_b.view(1)[0].nb_inplace_lshift;
        }
        if int(num_t.view(1)[0].nb_inplace_rshift) == 0
            and int(num_b.view(1)[0].nb_inplace_rshift) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_rshift)
                    != int(num_bb.view(1)[0].nb_inplace_rshift)
            ) {
            num_t.view(1)[0].nb_inplace_rshift = num_b.view(1)[0].nb_inplace_rshift;
        }
        if int(num_t.view(1)[0].nb_inplace_and) == 0
            and int(num_b.view(1)[0].nb_inplace_and) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_and)
                    != int(num_bb.view(1)[0].nb_inplace_and)
            ) {
            num_t.view(1)[0].nb_inplace_and = num_b.view(1)[0].nb_inplace_and;
        }
        if int(num_t.view(1)[0].nb_inplace_xor) == 0
            and int(num_b.view(1)[0].nb_inplace_xor) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_xor)
                    != int(num_bb.view(1)[0].nb_inplace_xor)
            ) {
            num_t.view(1)[0].nb_inplace_xor = num_b.view(1)[0].nb_inplace_xor;
        }
        if int(num_t.view(1)[0].nb_inplace_or) == 0
            and int(num_b.view(1)[0].nb_inplace_or) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_or)
                    != int(num_bb.view(1)[0].nb_inplace_or)
            ) {
            num_t.view(1)[0].nb_inplace_or = num_b.view(1)[0].nb_inplace_or;
        }
        if int(num_t.view(1)[0].nb_true_divide) == 0
            and int(num_b.view(1)[0].nb_true_divide) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_true_divide)
                    != int(num_bb.view(1)[0].nb_true_divide)
            ) {
            num_t.view(1)[0].nb_true_divide = num_b.view(1)[0].nb_true_divide;
        }
        if int(num_t.view(1)[0].nb_floor_divide) == 0
            and int(num_b.view(1)[0].nb_floor_divide) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_floor_divide)
                    != int(num_bb.view(1)[0].nb_floor_divide)
            ) {
            num_t.view(1)[0].nb_floor_divide = num_b.view(1)[0].nb_floor_divide;
        }
        if int(num_t.view(1)[0].nb_inplace_true_divide) == 0
            and int(num_b.view(1)[0].nb_inplace_true_divide) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_true_divide)
                    != int(num_bb.view(1)[0].nb_inplace_true_divide)
            ) {
            num_t.view(1)[0].nb_inplace_true_divide = num_b.view(1)[
                0
            ].nb_inplace_true_divide;
        }
        if int(num_t.view(1)[0].nb_inplace_floor_divide) == 0
            and int(num_b.view(1)[0].nb_inplace_floor_divide) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_floor_divide)
                    != int(num_bb.view(1)[0].nb_inplace_floor_divide)
            ) {
            num_t.view(1)[0].nb_inplace_floor_divide = num_b.view(1)[
                0
            ].nb_inplace_floor_divide;
        }
        if int(num_t.view(1)[0].nb_index) == 0
            and int(num_b.view(1)[0].nb_index) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_index) != int(num_bb.view(1)[0].nb_index)
            ) {
            num_t.view(1)[0].nb_index = num_b.view(1)[0].nb_index;
        }
        if int(num_t.view(1)[0].nb_matrix_multiply) == 0
            and int(num_b.view(1)[0].nb_matrix_multiply) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_matrix_multiply)
                    != int(num_bb.view(1)[0].nb_matrix_multiply)
            ) {
            num_t.view(1)[0].nb_matrix_multiply = num_b.view(1)[0].nb_matrix_multiply;
        }
        if int(num_t.view(1)[0].nb_inplace_matrix_multiply) == 0
            and int(num_b.view(1)[0].nb_inplace_matrix_multiply) != 0
            and (
                not num_bb
                or int(num_b.view(1)[0].nb_inplace_matrix_multiply)
                    != int(num_bb.view(1)[0].nb_inplace_matrix_multiply)
            ) {
            num_t.view(1)[0].nb_inplace_matrix_multiply = num_b.view(1)[
                0
            ].nb_inplace_matrix_multiply;
        }
    }

    async_t = type.view(1)[0].tp_as_async;
    async_b = base.view(1)[0].tp_as_async;
    if async_t and async_b {
        async_bb = basebase.view(1)[0].tp_as_async;
        if int(async_t.view(1)[0].am_await) == 0
            and int(async_b.view(1)[0].am_await) != 0
            and (
                not async_bb
                or int(async_b.view(1)[0].am_await) != int(async_bb.view(1)[0].am_await)
            ) {
            async_t.view(1)[0].am_await = async_b.view(1)[0].am_await;
        }
        if int(async_t.view(1)[0].am_aiter) == 0
            and int(async_b.view(1)[0].am_aiter) != 0
            and (
                not async_bb
                or int(async_b.view(1)[0].am_aiter) != int(async_bb.view(1)[0].am_aiter)
            ) {
            async_t.view(1)[0].am_aiter = async_b.view(1)[0].am_aiter;
        }
        if int(async_t.view(1)[0].am_anext) == 0
            and int(async_b.view(1)[0].am_anext) != 0
            and (
                not async_bb
                or int(async_b.view(1)[0].am_anext) != int(async_bb.view(1)[0].am_anext)
            ) {
            async_t.view(1)[0].am_anext = async_b.view(1)[0].am_anext;
        }
    }

    seq_t = type.view(1)[0].tp_as_sequence;
    seq_b = base.view(1)[0].tp_as_sequence;
    if seq_t and seq_b {
        seq_bb = basebase.view(1)[0].tp_as_sequence;
        if int(seq_t.view(1)[0].sq_length) == 0
            and int(seq_b.view(1)[0].sq_length) != 0
            and (
                not seq_bb
                or int(seq_b.view(1)[0].sq_length) != int(seq_bb.view(1)[0].sq_length)
            ) {
            seq_t.view(1)[0].sq_length = seq_b.view(1)[0].sq_length;
        }
        if int(seq_t.view(1)[0].sq_concat) == 0
            and int(seq_b.view(1)[0].sq_concat) != 0
            and (
                not seq_bb
                or int(seq_b.view(1)[0].sq_concat) != int(seq_bb.view(1)[0].sq_concat)
            ) {
            seq_t.view(1)[0].sq_concat = seq_b.view(1)[0].sq_concat;
        }
        if int(seq_t.view(1)[0].sq_repeat) == 0
            and int(seq_b.view(1)[0].sq_repeat) != 0
            and (
                not seq_bb
                or int(seq_b.view(1)[0].sq_repeat) != int(seq_bb.view(1)[0].sq_repeat)
            ) {
            seq_t.view(1)[0].sq_repeat = seq_b.view(1)[0].sq_repeat;
        }
        if int(seq_t.view(1)[0].sq_item) == 0
            and int(seq_b.view(1)[0].sq_item) != 0
            and (
                not seq_bb
                or int(seq_b.view(1)[0].sq_item) != int(seq_bb.view(1)[0].sq_item)
            ) {
            seq_t.view(1)[0].sq_item = seq_b.view(1)[0].sq_item;
        }
        if int(seq_t.view(1)[0].sq_ass_item) == 0
            and int(seq_b.view(1)[0].sq_ass_item) != 0
            and (
                not seq_bb
                or int(seq_b.view(1)[0].sq_ass_item)
                    != int(seq_bb.view(1)[0].sq_ass_item)
            ) {
            seq_t.view(1)[0].sq_ass_item = seq_b.view(1)[0].sq_ass_item;
        }
        if int(seq_t.view(1)[0].sq_contains) == 0
            and int(seq_b.view(1)[0].sq_contains) != 0
            and (
                not seq_bb
                or int(seq_b.view(1)[0].sq_contains)
                    != int(seq_bb.view(1)[0].sq_contains)
            ) {
            seq_t.view(1)[0].sq_contains = seq_b.view(1)[0].sq_contains;
        }
        if int(seq_t.view(1)[0].sq_inplace_concat) == 0
            and int(seq_b.view(1)[0].sq_inplace_concat) != 0
            and (
                not seq_bb
                or int(seq_b.view(1)[0].sq_inplace_concat)
                    != int(seq_bb.view(1)[0].sq_inplace_concat)
            ) {
            seq_t.view(1)[0].sq_inplace_concat = seq_b.view(1)[0].sq_inplace_concat;
        }
        if int(seq_t.view(1)[0].sq_inplace_repeat) == 0
            and int(seq_b.view(1)[0].sq_inplace_repeat) != 0
            and (
                not seq_bb
                or int(seq_b.view(1)[0].sq_inplace_repeat)
                    != int(seq_bb.view(1)[0].sq_inplace_repeat)
            ) {
            seq_t.view(1)[0].sq_inplace_repeat = seq_b.view(1)[0].sq_inplace_repeat;
        }
    }

    map_t = type.view(1)[0].tp_as_mapping;
    map_b = base.view(1)[0].tp_as_mapping;
    if map_t and map_b {
        map_bb = basebase.view(1)[0].tp_as_mapping;
        if int(map_t.view(1)[0].mp_length) == 0
            and int(map_b.view(1)[0].mp_length) != 0
            and (
                not map_bb
                or int(map_b.view(1)[0].mp_length) != int(map_bb.view(1)[0].mp_length)
            ) {
            map_t.view(1)[0].mp_length = map_b.view(1)[0].mp_length;
        }
        if int(map_t.view(1)[0].mp_subscript) == 0
            and int(map_b.view(1)[0].mp_subscript) != 0
            and (
                not map_bb
                or int(map_b.view(1)[0].mp_subscript)
                    != int(map_bb.view(1)[0].mp_subscript)
            ) {
            map_t.view(1)[0].mp_subscript = map_b.view(1)[0].mp_subscript;
        }
        if int(map_t.view(1)[0].mp_ass_subscript) == 0
            and int(map_b.view(1)[0].mp_ass_subscript) != 0
            and (
                not map_bb
                or int(map_b.view(1)[0].mp_ass_subscript)
                    != int(map_bb.view(1)[0].mp_ass_subscript)
            ) {
            map_t.view(1)[0].mp_ass_subscript = map_b.view(1)[0].mp_ass_subscript;
        }
    }

    buf_t = type.view(1)[0].tp_as_buffer;
    buf_b = base.view(1)[0].tp_as_buffer;
    if buf_t and buf_b {
        buf_bb = basebase.view(1)[0].tp_as_buffer;
        if int(buf_t.view(1)[0].bf_getbuffer) == 0
            and int(buf_b.view(1)[0].bf_getbuffer) != 0
            and (
                not buf_bb
                or int(buf_b.view(1)[0].bf_getbuffer)
                    != int(buf_bb.view(1)[0].bf_getbuffer)
            ) {
            buf_t.view(1)[0].bf_getbuffer = buf_b.view(1)[0].bf_getbuffer;
        }
        if int(buf_t.view(1)[0].bf_releasebuffer) == 0
            and int(buf_b.view(1)[0].bf_releasebuffer) != 0
            and (
                not buf_bb
                or int(buf_b.view(1)[0].bf_releasebuffer)
                    != int(buf_bb.view(1)[0].bf_releasebuffer)
            ) {
            buf_t.view(1)[0].bf_releasebuffer = buf_b.view(1)[0].bf_releasebuffer;
        }
    }

    if int(type.view(1)[0].tp_dealloc) == 0
        and int(base.view(1)[0].tp_dealloc) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_dealloc) != int(basebase.view(1)[0].tp_dealloc)
        ) {
        type.view(1)[0].tp_dealloc = base.view(1)[0].tp_dealloc;
    }
    if int(type.view(1)[0].tp_getattr) == 0 and int(type.view(1)[0].tp_getattro) == 0 {
        type.view(1)[0].tp_getattr = base.view(1)[0].tp_getattr;
        type.view(1)[0].tp_getattro = base.view(1)[0].tp_getattro;
    }
    if int(type.view(1)[0].tp_setattr) == 0 and int(type.view(1)[0].tp_setattro) == 0 {
        type.view(1)[0].tp_setattr = base.view(1)[0].tp_setattr;
        type.view(1)[0].tp_setattro = base.view(1)[0].tp_setattro;
    }
    if int(type.view(1)[0].tp_repr) == 0
        and int(base.view(1)[0].tp_repr) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_repr) != int(basebase.view(1)[0].tp_repr)
        ) {
        type.view(1)[0].tp_repr = base.view(1)[0].tp_repr;
    }

    if type.view(1)[0].tp_vectorcall_offset == 0
        and base.view(1)[0].tp_vectorcall_offset != 0
        and (
            not basebase
            or base.view(1)[0].tp_vectorcall_offset
                != basebase.view(1)[0].tp_vectorcall_offset
        ) {
        type.view(1)[0].tp_vectorcall_offset = base.view(1)[0].tp_vectorcall_offset;
    }

    if int(type.view(1)[0].tp_call) == 0
        and type_has_feature(base, Py_TPFLAGS_HAVE_VECTORCALL) {
        type_add_flags(type, Py_TPFLAGS_HAVE_VECTORCALL);
    }
    if int(type.view(1)[0].tp_call) == 0
        and int(base.view(1)[0].tp_call) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_call) != int(basebase.view(1)[0].tp_call)
        ) {
        type.view(1)[0].tp_call = base.view(1)[0].tp_call;
    }
    if int(type.view(1)[0].tp_str) == 0
        and int(base.view(1)[0].tp_str) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_str) != int(basebase.view(1)[0].tp_str)
        ) {
        type.view(1)[0].tp_str = base.view(1)[0].tp_str;
    }

    if int(type.view(1)[0].tp_richcompare) == 0 and int(type.view(1)[0].tp_hash) == 0 {
        r = overrides_hash(type);
        if r < 0 {
            return -1;
        }
        if r == 0 {
            type.view(1)[0].tp_richcompare = base.view(1)[0].tp_richcompare;
            type.view(1)[0].tp_hash = base.view(1)[0].tp_hash;
        }
    }
    if int(type.view(1)[0].tp_iter) == 0
        and int(base.view(1)[0].tp_iter) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_iter) != int(basebase.view(1)[0].tp_iter)
        ) {
        type.view(1)[0].tp_iter = base.view(1)[0].tp_iter;
    }
    if int(type.view(1)[0].tp_iternext) == 0
        and int(base.view(1)[0].tp_iternext) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_iternext) != int(basebase.view(1)[0].tp_iternext)
        ) {
        type.view(1)[0].tp_iternext = base.view(1)[0].tp_iternext;
    }
    if int(type.view(1)[0].tp_descr_get) == 0
        and int(base.view(1)[0].tp_descr_get) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_descr_get)
                != int(basebase.view(1)[0].tp_descr_get)
        ) {
        type.view(1)[0].tp_descr_get = base.view(1)[0].tp_descr_get;
    }

    if int(base.view(1)[0].tp_descr_get) != 0
        and int(type.view(1)[0].tp_descr_get) == int(base.view(1)[0].tp_descr_get)
        and type_has_feature(type, Py_TPFLAGS_IMMUTABLETYPE)
        and type_has_feature(base, Py_TPFLAGS_METHOD_DESCRIPTOR) {
        type_add_flags(type, Py_TPFLAGS_METHOD_DESCRIPTOR);
    }
    if int(type.view(1)[0].tp_descr_set) == 0
        and int(base.view(1)[0].tp_descr_set) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_descr_set)
                != int(basebase.view(1)[0].tp_descr_set)
        ) {
        type.view(1)[0].tp_descr_set = base.view(1)[0].tp_descr_set;
    }
    if type.view(1)[0].tp_dictoffset == 0
        and base.view(1)[0].tp_dictoffset != 0
        and (
            not basebase
            or base.view(1)[0].tp_dictoffset != basebase.view(1)[0].tp_dictoffset
        ) {
        type.view(1)[0].tp_dictoffset = base.view(1)[0].tp_dictoffset;
    }
    if int(type.view(1)[0].tp_init) == 0
        and int(base.view(1)[0].tp_init) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_init) != int(basebase.view(1)[0].tp_init)
        ) {
        type.view(1)[0].tp_init = base.view(1)[0].tp_init;
    }
    if int(type.view(1)[0].tp_alloc) == 0
        and int(base.view(1)[0].tp_alloc) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_alloc) != int(basebase.view(1)[0].tp_alloc)
        ) {
        type.view(1)[0].tp_alloc = base.view(1)[0].tp_alloc;
    }
    if int(type.view(1)[0].tp_is_gc) == 0
        and int(base.view(1)[0].tp_is_gc) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_is_gc) != int(basebase.view(1)[0].tp_is_gc)
        ) {
        type.view(1)[0].tp_is_gc = base.view(1)[0].tp_is_gc;
    }
    if int(type.view(1)[0].tp_finalize) == 0
        and int(base.view(1)[0].tp_finalize) != 0
        and (
            not basebase
            or int(base.view(1)[0].tp_finalize) != int(basebase.view(1)[0].tp_finalize)
        ) {
        type.view(1)[0].tp_finalize = base.view(1)[0].tp_finalize;
    }
    if (type.view(1)[0].tp_flags & Py_TPFLAGS_HAVE_GC)
        == (base.view(1)[0].tp_flags & Py_TPFLAGS_HAVE_GC) {
        if int(type.view(1)[0].tp_free) == 0
            and int(base.view(1)[0].tp_free) != 0
            and (
                not basebase
                or int(base.view(1)[0].tp_free) != int(basebase.view(1)[0].tp_free)
            ) {
            type.view(1)[0].tp_free = base.view(1)[0].tp_free;
        }
    } elif (type.view(1)[0].tp_flags & Py_TPFLAGS_HAVE_GC) != 0
        and int(type.view(1)[0].tp_free) == 0
        and int(base.view(1)[0].tp_free) == int(ptr(PyObject_Free)) {
        type.view(1)[0].tp_free = PyObject_GC_Del;
    }

    return 0;
}

impl type_ready_pre_checks(type: ptr[PyTypeObject]) -> i32 {
    if not type.view(1)[0].tp_name {
        PyErr_Format(PyExc_SystemError, "Type does not define the tp_name field.");
        return -1;
    }
    return 0;
}

impl type_ready_set_base(type: ptr[PyTypeObject]) -> i32 {
    base = type.view(1)[0].tp_base;
    if not base and type != addressof(PyBaseObject_Type) {
        base = addressof(PyBaseObject_Type);
        if type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
            type.view(1)[0].tp_base = ptr[PyTypeObject](
                object_new_ref(ptr[PyObject](base))
            );
        } else {
            type.view(1)[0].tp_base = base;
        }
    }

    if base and not type_is_ready(base) {
        if PyType_Ready(base) < 0 {
            return -1;
        }
    }
    return 0;
}

impl type_ready_set_type(type: ptr[PyTypeObject]) -> i32 {
    base = type.view(1)[0].tp_base;
    if not object_type(ptr[PyObject](type)) and base {
        ptr[_object](type).view(1)[0].ob_type = object_type(ptr[PyObject](base));
    }
    return 0;
}

impl type_ready_set_bases(type: ptr[PyTypeObject], initial: i32) -> i32 {
    if type_has_feature(type, _Py_TPFLAGS_STATIC_BUILTIN) {
        if initial == 0 {
            return 0;
        }
    }
    bases = lookup_tp_bases(type);
    if not bases {
        base = type.view(1)[0].tp_base;
        if not base {
            bases = PyTuple_New(0);
        } else {
            bases = PyTuple_Pack(1, ptr[PyObject](base));
        }
        if not bases {
            return -1;
        }
        set_tp_bases(type, bases, 1);
    }
    return 0;
}

impl type_ready_set_dict(type: ptr[PyTypeObject]) -> i32 {
    if lookup_tp_dict(type) {
        return 0;
    }
    dct = PyDict_New();
    if not dct {
        return -1;
    }
    set_tp_dict(type, dct);
    return 0;
}

impl type_dict_set_doc(type: ptr[PyTypeObject]) -> i32 {
    dct = lookup_tp_dict(type);
    r = PyDict_Contains(dct, py_id(_Py_ID___doc__));
    if r < 0 {
        return -1;
    }
    if r > 0 {
        return 0;
    }
    if type.view(1)[0].tp_doc {
        doc_str = _PyType_DocWithoutSignature(
            type.view(1)[0].tp_name, type.view(1)[0].tp_doc
        );
        doc = PyUnicode_FromString(doc_str);
        if not doc {
            return -1;
        }
        if PyDict_SetItem(dct, py_id(_Py_ID___doc__), doc) < 0 {
            object_decref(doc);
            return -1;
        }
        object_decref(doc);
    } elif PyDict_SetItem(dct, py_id(_Py_ID___doc__), Py_None) < 0 {
        return -1;
    }
    return 0;
}

impl type_ready_fill_dict(type: ptr[PyTypeObject]) -> i32 {
    if add_operators(type) < 0 {
        return -1;
    }
    if type_add_methods(type) < 0 {
        return -1;
    }
    if type_add_members(type) < 0 {
        return -1;
    }
    if type_add_getset(type) < 0 {
        return -1;
    }
    if type_dict_set_doc(type) < 0 {
        return -1;
    }
    return 0;
}

impl type_ready_preheader(type: ptr[PyTypeObject]) -> i32 {
    if type_has_feature(type, Py_TPFLAGS_MANAGED_DICT) {
        if type.view(1)[0].tp_dictoffset > 0 or type.view(1)[0].tp_dictoffset < -1 {
            PyErr_Format(
                PyExc_TypeError,
                "type %s has the Py_TPFLAGS_MANAGED_DICT flag but tp_dictoffset is set",
                type.view(1)[0].tp_name
            );
            return -1;
        }
        type.view(1)[0].tp_dictoffset = -1;
    }
    if type_has_feature(type, Py_TPFLAGS_MANAGED_WEAKREF) {
        if type.view(1)[0].tp_weaklistoffset != 0
            and type.view(1)[0].tp_weaklistoffset != MANAGED_WEAKREF_OFFSET {
            PyErr_Format(
                PyExc_TypeError,
                "type %s has the Py_TPFLAGS_MANAGED_WEAKREF flag but tp_weaklistoffset is set",
                type.view(1)[0].tp_name
            );
            return -1;
        }
        type.view(1)[0].tp_weaklistoffset = MANAGED_WEAKREF_OFFSET;
    }
    return 0;
}

impl type_ready_mro(type: ptr[PyTypeObject], initial: i32) -> i32 {
    if type_has_feature(type, _Py_TPFLAGS_STATIC_BUILTIN) {
        if initial == 0 {
            return 0;
        }
    }
    (status, old_mro) = mro_internal_unlocked(type, initial);
    object_xdecref(old_mro);
    if status < 0 {
        return -1;
    }
    mro = lookup_tp_mro(type);

    if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        n = object_size(mro);
        for i in range(n) {
            base = ptr[PyTypeObject](tuple_get_item(mro, i));
            if type_has_feature(base, Py_TPFLAGS_HEAPTYPE) {
                PyErr_Format(
                    PyExc_TypeError,
                    "type '%.100s' is not dynamically allocated but its base type '%.100s' is dynamically allocated",
                    type.view(1)[0].tp_name,
                    base.view(1)[0].tp_name
                );
                return -1;
            }
        }
    }
    return 0;
}

impl type_ready_inherit_as_structs(type: ptr[PyTypeObject], base: ptr[PyTypeObject]) {
    if not type.view(1)[0].tp_as_async {
        type.view(1)[0].tp_as_async = base.view(1)[0].tp_as_async;
    }
    if not type.view(1)[0].tp_as_number {
        type.view(1)[0].tp_as_number = base.view(1)[0].tp_as_number;
    }
    if not type.view(1)[0].tp_as_sequence {
        type.view(1)[0].tp_as_sequence = base.view(1)[0].tp_as_sequence;
    }
    if not type.view(1)[0].tp_as_mapping {
        type.view(1)[0].tp_as_mapping = base.view(1)[0].tp_as_mapping;
    }
    if not type.view(1)[0].tp_as_buffer {
        type.view(1)[0].tp_as_buffer = base.view(1)[0].tp_as_buffer;
    }
}

impl inherit_patma_flags(type: ptr[PyTypeObject], base: ptr[PyTypeObject]) {
    if (type.view(1)[0].tp_flags & COLLECTION_FLAGS) == 0 {
        type_add_flags(type, base.view(1)[0].tp_flags & COLLECTION_FLAGS);
    }
}

impl type_ready_inherit(type: ptr[PyTypeObject]) -> i32 {
    base = type.view(1)[0].tp_base;
    if base {
        inherit_special(type, base);
    }

    mro = lookup_tp_mro(type);
    n = object_size(mro);
    i: i64 = 1;
    while i < n {
        b = tuple_get_item(mro, i);
        if type_check(b) {
            if inherit_slots(type, ptr[PyTypeObject](b)) < 0 {
                return -1;
            }
            inherit_patma_flags(type, ptr[PyTypeObject](b));
        }
        i += 1;
    }
    if base {
        type_ready_inherit_as_structs(type, base);
    }

    if type_is_gc(type)
        and type_has_feature(type, Py_TPFLAGS_BASETYPE)
        and (
            int(type.view(1)[0].tp_free) == 0
            or int(type.view(1)[0].tp_free) == int(ptr(PyObject_Free))
        ) {
        PyErr_Format(
            PyExc_TypeError,
            "type '%.100s' participates in gc and is a base type but has inappropriate tp_free slot",
            type.view(1)[0].tp_name
        );
        return -1;
    }
    return 0;
}

impl type_ready_set_hash(type: ptr[PyTypeObject]) -> i32 {
    if int(type.view(1)[0].tp_hash) != 0 {
        return 0;
    }
    dct = lookup_tp_dict(type);
    r = PyDict_Contains(dct, py_id(_Py_ID___hash__));
    if r < 0 {
        return -1;
    }
    if r > 0 {
        return 0;
    }
    if PyDict_SetItem(dct, py_id(_Py_ID___hash__), Py_None) < 0 {
        return -1;
    }
    type.view(1)[0].tp_hash = PyObject_HashNotImplemented;
    return 0;
}

impl type_ready_add_subclasses(type: ptr[PyTypeObject]) -> i32 {
    bases = lookup_tp_bases(type);
    nbase = object_size(bases);
    for i in range(nbase) {
        b = tuple_get_item(bases, i);
        if type_check(b) and add_subclass(ptr[PyTypeObject](b), type) < 0 {
            return -1;
        }
    }
    return 0;
}

impl type_ready_set_new(type: ptr[PyTypeObject], initial: i32) -> i32 {
    base = type.view(1)[0].tp_base;
    if int(type.view(1)[0].tp_new) == 0
        and base == addressof(PyBaseObject_Type)
        and not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        if initial != 0 {
            type_add_flags(type, Py_TPFLAGS_DISALLOW_INSTANTIATION);
        }
    }
    if not type_has_feature(type, Py_TPFLAGS_DISALLOW_INSTANTIATION) {
        if int(type.view(1)[0].tp_new) != 0 {
            if initial != 0
                or not base
                or int(type.view(1)[0].tp_new) != int(base.view(1)[0].tp_new) {
                if add_tp_new_wrapper(type) < 0 {
                    return -1;
                }
            }
        } elif initial != 0 {
            type.view(1)[0].tp_new = base.view(1)[0].tp_new;
        }
    } elif initial != 0 {
        type.view(1)[0].tp_new = 0;
    }
    return 0;
}

impl type_ready_managed_dict(type: ptr[PyTypeObject]) -> i32 {
    if not type_has_feature(type, Py_TPFLAGS_MANAGED_DICT) {
        return 0;
    }
    if not type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        PyErr_Format(
            PyExc_SystemError,
            "type %s has the Py_TPFLAGS_MANAGED_DICT flag but not Py_TPFLAGS_HEAPTYPE flag",
            type.view(1)[0].tp_name
        );
        return -1;
    }
    et = ptr[PyHeapTypeObject](type);
    if not et.view(1)[0].ht_cached_keys {
        et.view(1)[0].ht_cached_keys = ptr[_dictkeysobject](
            _PyDict_NewKeysForClass(type)
        );
        if not et.view(1)[0].ht_cached_keys {
            PyErr_NoMemory();
            return -1;
        }
    }
    if type.view(1)[0].tp_itemsize == 0 {
        type_add_flags(type, Py_TPFLAGS_INLINE_VALUES);
    }
    return 0;
}

impl type_ready_post_checks(type: ptr[PyTypeObject]) -> i32 {
    if type_has_feature(type, Py_TPFLAGS_HAVE_GC)
        and int(type.view(1)[0].tp_traverse) == 0 {
        PyErr_Format(
            PyExc_SystemError,
            "type %s has the Py_TPFLAGS_HAVE_GC flag but has no traverse function",
            type.view(1)[0].tp_name
        );
        return -1;
    }
    if type_has_feature(type, Py_TPFLAGS_MANAGED_DICT) {
        if type.view(1)[0].tp_dictoffset != -1 {
            PyErr_Format(
                PyExc_SystemError,
                "type %s has the Py_TPFLAGS_MANAGED_DICT flag but tp_dictoffset is set to incompatible value",
                type.view(1)[0].tp_name
            );
            return -1;
        }
    } elif type.view(1)[0].tp_dictoffset < PyObject_HEAD_SIZE {
        if type.view(1)[0].tp_dictoffset + type.view(1)[0].tp_basicsize <= 0 {
            PyErr_Format(
                PyExc_SystemError,
                "type %s has a tp_dictoffset that is too small",
                type.view(1)[0].tp_name
            );
            return -1;
        }
    }
    return 0;
}

impl type_ready(type: ptr[PyTypeObject], initial: i32) -> i32 {
    start_readying(type);
    if type_ready_pre_checks(type) < 0 {
        stop_readying(type);
        return -1;
    }

    if type_ready_set_dict(type) < 0 {
        stop_readying(type);
        return -1;
    }
    if type_ready_set_base(type) < 0 {
        stop_readying(type);
        return -1;
    }
    if type_ready_set_type(type) < 0 {
        stop_readying(type);
        return -1;
    }
    if type_ready_set_bases(type, initial) < 0 {
        stop_readying(type);
        return -1;
    }
    if type_ready_mro(type, initial) < 0 {
        stop_readying(type);
        return -1;
    }
    if type_ready_set_new(type, initial) < 0 {
        stop_readying(type);
        return -1;
    }
    if type_ready_fill_dict(type) < 0 {
        stop_readying(type);
        return -1;
    }
    if initial != 0 {
        if type_ready_inherit(type) < 0 {
            stop_readying(type);
            return -1;
        }
        if type_ready_preheader(type) < 0 {
            stop_readying(type);
            return -1;
        }
    }
    if type_ready_set_hash(type) < 0 {
        stop_readying(type);
        return -1;
    }
    if type_ready_add_subclasses(type) < 0 {
        stop_readying(type);
        return -1;
    }
    if initial != 0 {
        if type_ready_managed_dict(type) < 0 {
            stop_readying(type);
            return -1;
        }
        if type_ready_post_checks(type) < 0 {
            stop_readying(type);
            return -1;
        }
    }

    if initial != 0 {
        type_add_flags(type, Py_TPFLAGS_READY);
    }
    stop_readying(type);
    return 0;
}

impl init_static_type(
    interp: ptr[u8], self_: ptr[PyTypeObject], isbuiltin: i32, initial: i32
) -> i32 {
    if initial != 0 {
        type_add_flags(self_, _Py_TPFLAGS_STATIC_BUILTIN);
        type_add_flags(self_, Py_TPFLAGS_IMMUTABLETYPE);
        if self_.view(1)[0].tp_version_tag == 0 {
            next_version_tag = next_global_version_tag();

            _PyType_SetVersion(self_, next_version_tag);
        }
    }

    managed_static_type_state_init(interp, self_, isbuiltin, initial);
    res = type_ready(self_, initial);
    if res < 0 {
        _PyStaticType_ClearWeakRefs(ptr(interp), self_);
        managed_static_type_state_clear(interp, self_, isbuiltin, initial);
    }
    return res;
}

impl add_subclass(base: ptr[PyTypeObject], type: ptr[PyTypeObject]) -> i32 {
    key = PyLong_FromVoidPtr(ptr(type));
    if not key {
        return -1;
    }
    ref = PyWeakref_NewRef(ptr[PyObject](type), NULL);
    if not ref {
        object_decref(key);
        return -1;
    }

    subclasses = lookup_tp_subclasses(base);
    if not subclasses {
        subclasses = init_tp_subclasses(base);
        if not subclasses {
            object_decref(key);
            object_decref(ref);
            return -1;
        }
    }

    result = PyDict_SetItem(subclasses, key, ref);
    object_decref(ref);
    object_decref(key);
    return result;
}

impl add_all_subclasses(type: ptr[PyTypeObject], bases: ptr[PyObject]) -> i32 {
    n = object_size(bases);
    res: i32 = 0;
    for i in range(n) {
        obj_ = tuple_get_item(bases, i);
        base = ptr[PyTypeObject](obj_);
        if add_subclass(base, type) < 0 {
            res = -1;
        }
    }
    return res;
}

impl get_subclasses_key(
    type: ptr[PyTypeObject], base: ptr[PyTypeObject]
) -> ptr[PyObject] {
    key = PyLong_FromVoidPtr(ptr(type));
    if key {
        return key;
    }
    PyErr_Clear();
    i: i64 = 0;

    ref = NULL;
    subclasses = lookup_tp_subclasses(base);
    if subclasses {
        while PyDict_Next(subclasses, &mut i, &mut key, &mut ref) != 0 {
            subclass = type_from_ref(ref);
            if not subclass {
                continue;
            }
            if subclass == type {
                object_decref(ptr[PyObject](subclass));
                return object_new_ref(key);
            }
            object_decref(ptr[PyObject](subclass));
        }
    }

    return NULL;
}

impl remove_subclass(base: ptr[PyTypeObject], type: ptr[PyTypeObject]) {
    subclasses = lookup_tp_subclasses(base);
    if not subclasses {
        return;
    }

    key = get_subclasses_key(type, base);
    if key and PyDict_DelItem(subclasses, key) != 0 {
        PyErr_Clear();
    }
    object_xdecref(key);
    if PyDict_Size(subclasses) == 0 {
        clear_tp_subclasses(base);
    }
}

impl remove_all_subclasses(type: ptr[PyTypeObject], bases: ptr[PyObject]) {
    i: i64 = 0;
    while i < object_size(bases) {
        base = tuple_get_item(bases, i);
        if type_check(base) {
            remove_subclass(ptr[PyTypeObject](base), type);
        }
        i += 1;
    }
}

impl check_num_args(ob: ptr[PyObject], n: i32) -> i32 {
    if not tuple_check_exact(ob) {
        PyErr_SetString(
            PyExc_SystemError, "PyArg_UnpackTuple() argument list is not a tuple"
        );
        return 0;
    }
    size = object_size(ob);
    if i64(n) == size {
        return 1;
    }
    suffix = ptr[u8]("s");
    if n == 1 {
        suffix = ptr[u8]("");
    }
    PyErr_Format(PyExc_TypeError, "expected %d argument%s, got %zd", n, suffix, size);
    return 0;
}

impl check_pow_args(ob: ptr[PyObject]) -> i64 {
    min_args: i32 = 1;
    max_args: i32 = 2;
    if not tuple_check_exact(ob) {
        PyErr_SetString(
            PyExc_SystemError, "PyArg_UnpackTuple() argument list is not a tuple"
        );
        return -1;
    }
    size = object_size(ob);
    if size >= i64(min_args) and size <= i64(max_args) {
        return size;
    }
    PyErr_Format(
        PyExc_TypeError,
        "expected %d or %d arguments, got %zd",
        min_args,
        max_args,
        size
    );
    return -1;
}

impl wrap_lenfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 0) == 0 {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].lenfunc = int(wrapped);
    res = calls.view(1)[0].lenfunc(self_);
    if res == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(res);
}

impl wrap_inquirypred(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 0) == 0 {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].inquiry = int(wrapped);
    res = calls.view(1)[0].inquiry(self_);
    if res == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(res));
}

impl wrap_binaryfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    other = tuple_get_item(args, 0);
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].binaryfunc = int(wrapped);
    return calls.view(1)[0].binaryfunc(self_, other);
}

impl wrap_binaryfunc_l(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    other = tuple_get_item(args, 0);
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].binaryfunc = int(wrapped);
    return calls.view(1)[0].binaryfunc(self_, other);
}

impl wrap_binaryfunc_r(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    other = tuple_get_item(args, 0);
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].binaryfunc = int(wrapped);
    return calls.view(1)[0].binaryfunc(other, self_);
}

impl wrap_ternaryfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    third = Py_None;
    size = check_pow_args(args);
    if size == -1 {
        return NULL;
    }
    other = tuple_get_item(args, 0);
    if size == 2 {
        third = tuple_get_item(args, 1);
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].ternaryfunc = int(wrapped);
    return calls.view(1)[0].ternaryfunc(self_, other, third);
}

impl wrap_ternaryfunc_r(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    third = Py_None;
    size = check_pow_args(args);
    if size == -1 {
        return NULL;
    }
    other = tuple_get_item(args, 0);
    if size == 2 {
        third = tuple_get_item(args, 1);
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].ternaryfunc = int(wrapped);
    return calls.view(1)[0].ternaryfunc(other, self_, third);
}

impl wrap_unaryfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 0) == 0 {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].unaryfunc = int(wrapped);
    return calls.view(1)[0].unaryfunc(self_);
}

impl wrap_indexargfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    o = tuple_get_item(args, 0);
    i = PyNumber_AsSsize_t(o, PyExc_OverflowError);
    if i == -1 and PyErr_Occurred() {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].ssizeargfunc = int(wrapped);
    return calls.view(1)[0].ssizeargfunc(self_, i);
}

impl getindex(self_: ptr[PyObject], arg: ptr[PyObject]) -> i64 {
    i = PyNumber_AsSsize_t(arg, PyExc_OverflowError);
    if i == -1 and PyErr_Occurred() {
        return -1;
    }
    if i < 0 {
        sq = object_type(self_).view(1)[0].tp_as_sequence;
        if sq and int(sq.view(1)[0].sq_length) != 0 {
            n = sq.view(1)[0].sq_length(self_);
            if n < 0 {
                return -1;
            }
            i += n;
        }
    }
    return i;
}

impl wrap_sq_item(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if object_size(args) == 1 {
        arg = tuple_get_item(args, 0);
        i = getindex(self_, arg);
        if i == -1 and PyErr_Occurred() {
            return NULL;
        }
        calls = ptr[TypeCall](
            __thread_local_block("jac_object_model_type_type_calls", 208)
        );
        calls.view(1)[0].ssizeargfunc = int(wrapped);
        return calls.view(1)[0].ssizeargfunc(self_, i);
    }
    check_num_args(args, 1);

    return NULL;
}

impl wrap_sq_setitem(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    arg = NULL;
    value = NULL;
    if PyArg_UnpackTuple(args, "__setitem__", 2, 2, &mut arg, &mut value) == 0 {
        return NULL;
    }
    i = getindex(self_, arg);
    if i == -1 and PyErr_Occurred() {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].ssizeobjargproc = int(wrapped);
    res = calls.view(1)[0].ssizeobjargproc(self_, i, value);
    if res == -1 and PyErr_Occurred() {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl wrap_sq_delitem(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    arg = tuple_get_item(args, 0);
    i = getindex(self_, arg);
    if i == -1 and PyErr_Occurred() {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].ssizeobjargproc = int(wrapped);
    res = calls.view(1)[0].ssizeobjargproc(self_, i, NULL);
    if res == -1 and PyErr_Occurred() {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl wrap_objobjproc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    value = tuple_get_item(args, 0);
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].objobjproc = int(wrapped);
    res = calls.view(1)[0].objobjproc(self_, value);
    if res == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(res));
}

impl wrap_objobjargproc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    key = NULL;
    value = NULL;
    if PyArg_UnpackTuple(args, "__setitem__", 2, 2, &mut key, &mut value) == 0 {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].objobjargproc = int(wrapped);
    res = calls.view(1)[0].objobjargproc(self_, key, value);
    if res == -1 and PyErr_Occurred() {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl wrap_delitem(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    key = tuple_get_item(args, 0);
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].objobjargproc = int(wrapped);
    res = calls.view(1)[0].objobjargproc(self_, key, NULL);
    if res == -1 and PyErr_Occurred() {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl hackcheck_unlocked(self_: ptr[PyObject], func: ptr, what: ptr[u8]) -> i32 {
    type = object_type(self_);
    mro = lookup_tp_mro(type);
    if not mro {
        return 1;
    }

    slot_setattro = int(ptr(slot_tp_setattro));

    defining_type = type;
    i = object_size(mro) - 1;
    while i >= 0 {
        base = ptr[PyTypeObject](tuple_get_item(mro, i));
        if int(base.view(1)[0].tp_setattro) == slot_setattro {
            i -= 1;
            continue;
        }
        if int(base.view(1)[0].tp_setattro) == int(type.view(1)[0].tp_setattro) {
            defining_type = base;
            break;
        }
        i -= 1;
    }

    base = defining_type;
    while base {
        if int(base.view(1)[0].tp_setattro) == int(func) {
            break;
        }
        if int(base.view(1)[0].tp_setattro) != slot_setattro {
            PyErr_Format(
                PyExc_TypeError,
                "can't apply this %s to %s object",
                what,
                type.view(1)[0].tp_name
            );
            return 0;
        }
        base = base.view(1)[0].tp_base;
    }
    return 1;
}

impl hackcheck(self_: ptr[PyObject], func: ptr, what: ptr[u8]) -> i32 {
    if not type_check(self_) {
        return 1;
    }
    return hackcheck_unlocked(self_, func, what);
}

impl wrap_setattr(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    name = NULL;
    value = NULL;
    if PyArg_UnpackTuple(args, "__setattr__", 2, 2, &mut name, &mut value) == 0 {
        return NULL;
    }
    if hackcheck(self_, wrapped, ptr[u8]("__setattr__")) == 0 {
        return NULL;
    }

    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].objobjargproc = int(wrapped);
    res = calls.view(1)[0].objobjargproc(self_, name, value);
    if res < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl wrap_delattr(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    name = tuple_get_item(args, 0);
    if hackcheck(self_, wrapped, ptr[u8]("__delattr__")) == 0 {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].objobjargproc = int(wrapped);
    res = calls.view(1)[0].objobjargproc(self_, name, NULL);
    if res < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl wrap_hashfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 0) == 0 {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].hashfunc = int(wrapped);
    res = calls.view(1)[0].hashfunc(self_);
    if res == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(res);
}

impl wrap_call(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr, kwds: ptr[PyObject]
) -> ptr[PyObject] {
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].ternaryfunc = int(wrapped);
    return calls.view(1)[0].ternaryfunc(self_, args, kwds);
}

impl wrap_del(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 0) == 0 {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].destructor = int(wrapped);
    calls.view(1)[0].destructor(self_);
    return object_new_ref(Py_None);
}

impl wrap_richcmpfunc(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr, op: i32
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    other = tuple_get_item(args, 0);
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].richcmpfunc = int(wrapped);
    return calls.view(1)[0].richcmpfunc(self_, other, op);
}

impl richcmp_lt(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    return wrap_richcmpfunc(self_, args, wrapped, Py_LT);
}

impl richcmp_le(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    return wrap_richcmpfunc(self_, args, wrapped, Py_LE);
}

impl richcmp_eq(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    return wrap_richcmpfunc(self_, args, wrapped, Py_EQ);
}

impl richcmp_ne(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    return wrap_richcmpfunc(self_, args, wrapped, Py_NE);
}

impl richcmp_gt(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    return wrap_richcmpfunc(self_, args, wrapped, Py_GT);
}

impl richcmp_ge(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    return wrap_richcmpfunc(self_, args, wrapped, Py_GE);
}

impl wrap_next(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 0) == 0 {
        return NULL;
    }
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].unaryfunc = int(wrapped);
    res = calls.view(1)[0].unaryfunc(self_);
    if not res and not PyErr_Occurred() {
        PyErr_SetNone(PyExc_StopIteration);
    }
    return res;
}

impl wrap_descr_get(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    obj_ = NULL;
    type = NULL;
    if PyArg_UnpackTuple(args, "__get__", 1, 2, &mut obj_, &mut type) == 0 {
        return NULL;
    }
    if obj_ == Py_None {
        obj_ = NULL;
    }
    if type == Py_None {
        type = NULL;
    }
    if not type and not obj_ {
        PyErr_SetString(PyExc_TypeError, "__get__(None, None) is invalid");
        return NULL;
    }

    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].ternaryfunc = int(wrapped);
    return calls.view(1)[0].ternaryfunc(self_, obj_, type);
}

impl wrap_descr_set(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    obj_ = NULL;
    value = NULL;
    if PyArg_UnpackTuple(args, "__set__", 2, 2, &mut obj_, &mut value) == 0 {
        return NULL;
    }

    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].objobjargproc = int(wrapped);
    ret = calls.view(1)[0].objobjargproc(self_, obj_, value);
    if ret < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl wrap_descr_delete(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    if check_num_args(args, 1) == 0 {
        return NULL;
    }
    obj_ = tuple_get_item(args, 0);
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].objobjargproc = int(wrapped);
    ret = calls.view(1)[0].objobjargproc(self_, obj_, NULL);
    if ret < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl wrap_buffer(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    arg = NULL;
    if PyArg_UnpackTuple(args, "__buffer__", 1, 1, &mut arg) == 0 {
        return NULL;
    }
    flags = PyNumber_AsSsize_t(arg, PyExc_OverflowError);
    if flags == -1 and PyErr_Occurred() {
        return NULL;
    }

    if flags > 2147483647 or flags < -2147483648 {
        PyErr_SetString(PyExc_OverflowError, "buffer flags out of range");
        return NULL;
    }
    return _PyMemoryView_FromBufferProc(self_, i32(flags), wrapped);
}

impl wrap_releasebuffer(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr
) -> ptr[PyObject] {
    arg = NULL;
    if PyArg_UnpackTuple(args, "__release_buffer__", 1, 1, &mut arg) == 0 {
        return NULL;
    }

    if not object_is_type(arg, addressof(PyMemoryView_Type)) {
        PyErr_SetString(PyExc_TypeError, "expected a memoryview object");
        return NULL;
    }
    view_obj = ptr[Py_buffer](ptr[u8](arg) + PyMemoryViewObject_VIEW).view(1)[0].owner;
    if not view_obj {
        return object_new_ref(Py_None);
    }
    if view_obj != self_ {
        PyErr_SetString(PyExc_ValueError, "memoryview's buffer is not this object");
        return NULL;
    }
    if (ptr[PyMemoryViewObject](arg).view(1)[0].flags & _Py_MEMORYVIEW_RELEASED) != 0 {
        PyErr_SetString(
            PyExc_ValueError, "memoryview's buffer has already been released"
        );
        return NULL;
    }

    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = arg;
    res = PyObject_VectorcallMethod(
        py_id(_Py_ID_release), stack, u64(1) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
    if not res {
        return NULL;
    }
    object_decref(res);
    return object_new_ref(Py_None);
}

impl wrap_init(
    self_: ptr[PyObject], args: ptr[PyObject], wrapped: ptr, kwds: ptr[PyObject]
) -> ptr[PyObject] {
    calls = ptr[TypeCall](
        __thread_local_block("jac_object_model_type_type_calls", 208)
    );
    calls.view(1)[0].initproc = int(wrapped);
    if calls.view(1)[0].initproc(self_, args, kwds) < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl tp_new_wrapper(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if not self_ or not type_check(self_) {
        PyErr_Format(PyExc_SystemError, "__new__() called with non-type 'self'");
        return NULL;
    }
    type = ptr[PyTypeObject](self_);
    if not tuple_check(args) or object_size(args) < 1 {
        PyErr_Format(
            PyExc_TypeError,
            "%s.__new__(): not enough arguments",
            type.view(1)[0].tp_name
        );
        return NULL;
    }
    arg0 = tuple_get_item(args, 0);
    if not type_check(arg0) {
        PyErr_Format(
            PyExc_TypeError,
            "%s.__new__(X): X is not a type object (%s)",
            type.view(1)[0].tp_name,
            object_type(arg0).view(1)[0].tp_name
        );
        return NULL;
    }
    subtype = ptr[PyTypeObject](arg0);
    if PyType_IsSubtype(subtype, type) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "%s.__new__(%s): %s is not a subtype of %s",
            type.view(1)[0].tp_name,
            subtype.view(1)[0].tp_name,
            subtype.view(1)[0].tp_name,
            type.view(1)[0].tp_name
        );
        return NULL;
    }

    slot_new = int(ptr(slot_tp_new));
    staticbase = subtype;
    while staticbase and int(staticbase.view(1)[0].tp_new) == slot_new {
        staticbase = staticbase.view(1)[0].tp_base;
    }

    if staticbase
        and int(staticbase.view(1)[0].tp_new) != int(type.view(1)[0].tp_new) {
        if int(staticbase.view(1)[0].tp_new) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                "cannot create '%s' instances",
                subtype.view(1)[0].tp_name
            );
            return NULL;
        }
        PyErr_Format(
            PyExc_TypeError,
            "%s.__new__(%s) is not safe, use %s.__new__()",
            type.view(1)[0].tp_name,
            subtype.view(1)[0].tp_name,
            staticbase.view(1)[0].tp_name
        );
        return NULL;
    }
    new_args = PyTuple_GetSlice(args, 1, object_size(args));
    if not new_args {
        return NULL;
    }
    res = type.view(1)[0].tp_new(subtype, new_args, kwds);
    object_decref(new_args);
    return res;
}

impl add_tp_new_wrapper(type: ptr[PyTypeObject]) -> i32 {
    dct = lookup_tp_dict(type);
    r = PyDict_Contains(dct, py_id(_Py_ID___new__));
    if r > 0 {
        return 0;
    }
    if r < 0 {
        return -1;
    }
    func = PyCFunction_NewEx(
        ptr[PyMethodDef](addressof(tp_new_methoddef)), ptr[PyObject](type), NULL
    );
    if not func {
        return -1;
    }
    _PyObject_SetDeferredRefcount(func);
    r = PyDict_SetItem(dct, py_id(_Py_ID___new__), func);
    object_decref(func);
    return r;
}

impl method_is_overloaded(
    left: ptr[PyObject], right: ptr[PyObject], name: ptr[PyObject]
) -> i32 {
    b = NULL;
    if PyObject_GetOptionalAttr(ptr[PyObject](object_type(right)), name, &mut b) < 0 {
        return -1;
    }
    if not b {
        return 0;
    }
    a = NULL;
    if PyObject_GetOptionalAttr(ptr[PyObject](object_type(left)), name, &mut a) < 0 {
        object_decref(b);
        return -1;
    }
    if not a {
        object_decref(b);

        return 1;
    }
    ok = PyObject_RichCompareBool(a, b, Py_NE);
    object_decref(a);
    object_decref(b);
    return ok;
}

impl slot_sq_length(self_: ptr[PyObject]) -> i64 {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    res = vectorcall_method(py_id(_Py_ID___len__), stack, 1);
    if not res {
        return -1;
    }
    index_obj = _PyNumber_Index(res);
    object_decref(res);
    res = index_obj;
    if not res {
        return -1;
    }

    if (ptr[u64](ptr[u8](res) + PyLongObject_TAG).view(1)[0] & _PyLong_SIGN_MASK)
        == u64(2) {
        object_decref(res);
        PyErr_SetString(PyExc_ValueError, "__len__() should return >= 0");
        return -1;
    }
    length = PyNumber_AsSsize_t(res, PyExc_OverflowError);
    object_decref(res);
    return length;
}

impl slot_sq_item(self_: ptr[PyObject], i: i64) -> ptr[PyObject] {
    ival = PyLong_FromSsize_t(i);
    if not ival {
        return NULL;
    }
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = ival;
    retval = vectorcall_method(py_id(_Py_ID___getitem__), stack, 2);
    object_decref(ival);
    return retval;
}

impl slot_sq_ass_item(self_: ptr[PyObject], index: i64, value: ptr[PyObject]) -> i32 {
    index_obj = PyLong_FromSsize_t(index);
    if not index_obj {
        return -1;
    }
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = index_obj;
    res = NULL;
    if not value {
        res = vectorcall_method(py_id(_Py_ID___delitem__), stack, 2);
    } else {
        (stack + 2).view(1)[0] = value;
        res = vectorcall_method(py_id(_Py_ID___setitem__), stack, 3);
    }
    object_decref(index_obj);
    if not res {
        return -1;
    }
    object_decref(res);
    return 0;
}

impl slot_sq_contains(self_: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    (res, attr_is_none) = maybe_call_special_one_arg(
        self_, py_id(_Py_ID___contains__), value
    );
    if attr_is_none != 0 {
        PyErr_Format(
            PyExc_TypeError,
            "'%.200s' object is not a container",
            object_type(self_).view(1)[0].tp_name
        );
        return -1;
    } elif not res {
        if PyErr_Occurred() {
            return -1;
        }
        return i32(_PySequence_IterSearch(self_, value, PY_ITERSEARCH_CONTAINS));
    }
    result = PyObject_IsTrue(res);
    object_decref(res);
    return result;
}

impl slot_mp_subscript(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___getitem__), stack, 2);
}

impl slot_mp_ass_subscript(
    self_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = key;
    res = NULL;
    if not value {
        res = vectorcall_method(py_id(_Py_ID___delitem__), stack, 2);
    } else {
        (stack + 2).view(1)[0] = value;
        res = vectorcall_method(py_id(_Py_ID___setitem__), stack, 3);
    }
    if not res {
        return -1;
    }
    object_decref(res);
    return 0;
}

impl slot_nb_add(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_add) == int(ptr(slot_nb_add)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number and int(self_number.view(1)[0].nb_add) == int(ptr(slot_nb_add)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___radd__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___radd__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___add__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___radd__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_subtract(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_subtract)
                == int(ptr(slot_nb_subtract)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_subtract) == int(ptr(slot_nb_subtract)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rsub__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rsub__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___sub__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rsub__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_multiply(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_multiply)
                == int(ptr(slot_nb_multiply)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_multiply) == int(ptr(slot_nb_multiply)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rmul__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rmul__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___mul__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rmul__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_matrix_multiply(
    self_: ptr[PyObject], other: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_matrix_multiply)
                == int(ptr(slot_nb_matrix_multiply)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_matrix_multiply)
            == int(ptr(slot_nb_matrix_multiply)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rmatmul__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rmatmul__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___matmul__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rmatmul__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_remainder(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_remainder)
                == int(ptr(slot_nb_remainder)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_remainder) == int(ptr(slot_nb_remainder)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rmod__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rmod__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___mod__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rmod__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_divmod(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_divmod) == int(ptr(slot_nb_divmod)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_divmod) == int(ptr(slot_nb_divmod)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rdivmod__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rdivmod__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___divmod__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rdivmod__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_power_binary(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_power) == int(ptr(slot_nb_power)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_power) == int(ptr(slot_nb_power)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rpow__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rpow__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___pow__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rpow__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_power(
    self_: ptr[PyObject], other: ptr[PyObject], modulus: ptr[PyObject]
) -> ptr[PyObject] {
    if modulus == Py_None {
        return slot_nb_power_binary(self_, other);
    }
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_power) == int(ptr(slot_nb_power)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_power) == int(ptr(slot_nb_power)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rpow__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                (stack + 2).view(1)[0] = modulus;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rpow__), stack, 3);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        (stack + 2).view(1)[0] = modulus;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___pow__), stack, 3);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        (stack + 2).view(1)[0] = modulus;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rpow__), stack, 3);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_negative(self_: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    return vectorcall_method(py_id(_Py_ID___neg__), stack, 1);
}

impl slot_nb_positive(self_: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    return vectorcall_method(py_id(_Py_ID___pos__), stack, 1);
}

impl slot_nb_absolute(self_: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    return vectorcall_method(py_id(_Py_ID___abs__), stack, 1);
}

impl slot_nb_bool(self_: ptr[PyObject]) -> i32 {
    using_len = False;
    (value, attr_is_none) = maybe_call_special_no_args(self_, py_id(_Py_ID___bool__));
    if attr_is_none != 0 {
        PyErr_Format(
            PyExc_TypeError,
            "'%.200s' cannot be interpreted as a boolean",
            object_type(self_).view(1)[0].tp_name
        );
        return -1;
    } elif not value and not PyErr_Occurred() {
        value = _PyObject_MaybeCallSpecialNoArgs(self_, py_id(_Py_ID___len__));
        if not value and not PyErr_Occurred() {
            return 1;
        }
        using_len = True;
    }
    if not value {
        return -1;
    }
    result: i32 = 0;
    if using_len {
        result = PyObject_IsTrue(value);
    } elif object_is_type(value, addressof(PyBool_Type)) {
        result = PyObject_IsTrue(value);
    } else {
        PyErr_Format(
            PyExc_TypeError,
            "__bool__ should return bool, returned %s",
            object_type(value).view(1)[0].tp_name
        );
        result = -1;
    }
    object_decref(value);
    return result;
}

impl slot_nb_index(self_: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    return vectorcall_method(py_id(_Py_ID___index__), stack, 1);
}

impl slot_nb_invert(self_: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    return vectorcall_method(py_id(_Py_ID___invert__), stack, 1);
}

impl slot_nb_lshift(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_lshift) == int(ptr(slot_nb_lshift)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_lshift) == int(ptr(slot_nb_lshift)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rlshift__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rlshift__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___lshift__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rlshift__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_rshift(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_rshift) == int(ptr(slot_nb_rshift)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_rshift) == int(ptr(slot_nb_rshift)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rrshift__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rrshift__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___rshift__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rrshift__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_and(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_and) == int(ptr(slot_nb_and)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number and int(self_number.view(1)[0].nb_and) == int(ptr(slot_nb_and)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rand__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rand__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___and__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rand__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_xor(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_xor) == int(ptr(slot_nb_xor)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number and int(self_number.view(1)[0].nb_xor) == int(ptr(slot_nb_xor)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rxor__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rxor__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___xor__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rxor__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_or(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_or) == int(ptr(slot_nb_or)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number and int(self_number.view(1)[0].nb_or) == int(ptr(slot_nb_or)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___ror__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___ror__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___or__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___ror__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_int(self_: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    return vectorcall_method(py_id(_Py_ID___int__), stack, 1);
}

impl slot_nb_float(self_: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    return vectorcall_method(py_id(_Py_ID___float__), stack, 1);
}

impl slot_nb_inplace_add(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___iadd__), stack, 2);
}

impl slot_nb_inplace_subtract(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___isub__), stack, 2);
}

impl slot_nb_inplace_multiply(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___imul__), stack, 2);
}

impl slot_nb_inplace_matrix_multiply(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___imatmul__), stack, 2);
}

impl slot_nb_inplace_remainder(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___imod__), stack, 2);
}

impl slot_nb_inplace_power(
    self_: ptr[PyObject], arg1: ptr[PyObject], arg2: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___ipow__), stack, 2);
}

impl slot_nb_inplace_lshift(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___ilshift__), stack, 2);
}

impl slot_nb_inplace_rshift(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___irshift__), stack, 2);
}

impl slot_nb_inplace_and(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___iand__), stack, 2);
}

impl slot_nb_inplace_xor(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___ixor__), stack, 2);
}

impl slot_nb_inplace_or(self_: ptr[PyObject], arg1: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___ior__), stack, 2);
}

impl slot_nb_floor_divide(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_floor_divide)
                == int(ptr(slot_nb_floor_divide)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_floor_divide)
            == int(ptr(slot_nb_floor_divide)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rfloordiv__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rfloordiv__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___floordiv__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rfloordiv__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_true_divide(self_: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    tstate = thread_state();
    r = NULL;
    do_other = False;
    if not object_is_type(self_, object_type(other)) {
        other_number = object_type(other).view(1)[0].tp_as_number;
        if other_number
            and int(other_number.view(1)[0].nb_true_divide)
                == int(ptr(slot_nb_true_divide)) {
            do_other = True;
        }
    }
    self_number = object_type(self_).view(1)[0].tp_as_number;
    if self_number
        and int(self_number.view(1)[0].nb_true_divide)
            == int(ptr(slot_nb_true_divide)) {
        if do_other and PyType_IsSubtype(object_type(other), object_type(self_)) != 0 {
            ok = method_is_overloaded(self_, other, py_id(_Py_ID___rtruediv__));
            if ok < 0 {
                return NULL;
            }
            if ok != 0 {
                stack.view(1)[0] = other;
                (stack + 1).view(1)[0] = self_;
                r = vectorcall_maybe(tstate, py_id(_Py_ID___rtruediv__), stack, 2);
                if r != Py_NotImplemented {
                    return r;
                }
                object_decref(r);
                do_other = False;
            }
        }
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = other;
        r = vectorcall_maybe(tstate, py_id(_Py_ID___truediv__), stack, 2);
        if r != Py_NotImplemented or object_is_type(other, object_type(self_)) {
            return r;
        }
        object_decref(r);
    }
    if do_other {
        stack.view(1)[0] = other;
        (stack + 1).view(1)[0] = self_;
        return vectorcall_maybe(tstate, py_id(_Py_ID___rtruediv__), stack, 2);
    }
    return object_new_ref(Py_NotImplemented);
}

impl slot_nb_inplace_floor_divide(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___ifloordiv__), stack, 2);
}

impl slot_nb_inplace_true_divide(
    self_: ptr[PyObject], arg1: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = arg1;
    return vectorcall_method(py_id(_Py_ID___itruediv__), stack, 2);
}

impl slot_tp_repr(self_: ptr[PyObject]) -> ptr[PyObject] {
    res = _PyObject_MaybeCallSpecialNoArgs(self_, py_id(_Py_ID___repr__));
    if res {
        return res;
    } elif PyErr_Occurred() {
        return NULL;
    }
    return PyUnicode_FromFormat(
        "<%s object at %p>", object_type(self_).view(1)[0].tp_name, self_
    );
}

impl slot_tp_str(self_: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    return vectorcall_method(py_id(_Py_ID___str__), stack, 1);
}

impl slot_tp_hash(self_: ptr[PyObject]) -> i64 {
    (res, attr_is_none) = maybe_call_special_no_args(self_, py_id(_Py_ID___hash__));
    if attr_is_none != 0 or not res {
        if PyErr_Occurred() {
            return -1;
        }
        return PyObject_HashNotImplemented(self_);
    }
    if not long_check(res) {
        object_decref(res);
        PyErr_SetString(PyExc_TypeError, "__hash__ method should return an integer");
        return -1;
    }

    h = PyLong_AsSsize_t(res);
    if h == -1 {
        if PyErr_Occurred() {
            PyErr_Clear();
            h = addressof(PyLong_Type).view(1)[0].tp_hash(res);
        }
    }

    if h == -1 {
        h = -2;
    }
    object_decref(res);
    return h;
}

impl slot_tp_call(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return call_method(self_, py_id(_Py_ID___call__), args, kwds);
}

impl call_attribute(
    self_: ptr[PyObject], attr: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    attr_type = object_type(attr);
    if type_has_feature(attr_type, Py_TPFLAGS_METHOD_DESCRIPTOR) {
        slots: own StackArgs = StackArgs();
        stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        stack.view(1)[0] = self_;
        (stack + 1).view(1)[0] = name;
        return PyObject_Vectorcall(attr, stack, u64(2), NULL);
    }
    descr = NULL;
    callee = attr;
    if int(attr_type.view(1)[0].tp_descr_get) != 0 {
        descr = attr_type.view(1)[0].tp_descr_get(
            attr, self_, ptr[PyObject](object_type(self_))
        );
        if not descr {
            return NULL;
        }
        callee = descr;
    }
    res = PyObject_CallOneArg(callee, name);
    object_xdecref(descr);
    return res;
}

impl slot_tp_setattro(
    self_: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = name;
    res = NULL;
    if not value {
        res = vectorcall_method(py_id(_Py_ID___delattr__), stack, 2);
    } else {
        (stack + 2).view(1)[0] = value;
        res = vectorcall_method(py_id(_Py_ID___setattr__), stack, 3);
    }
    if not res {
        return -1;
    }
    object_decref(res);
    return 0;
}

impl slot_tp_richcompare(
    self_: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    res = _PyObject_MaybeCallSpecialOneArg(
        self_, py_id((addressof(name_op) + i64(op)).view(1)[0]), other
    );
    if not res {
        if PyErr_Occurred() {
            return NULL;
        }
        return object_new_ref(Py_NotImplemented);
    }
    return res;
}

impl has_dunder_getitem(self_: ptr[PyObject]) -> i32 {
    (unbound, ref) = lookup_maybe_method(self_, py_id(_Py_ID___getitem__));
    found: i32 = 1;
    if stackref_is_null(ref) {
        found = 0;
    }
    stackref_close(ref);
    return found;
}

impl slot_tp_iter(self_: ptr[PyObject]) -> ptr[PyObject] {
    (res, attr_is_none) = maybe_call_special_no_args(self_, py_id(_Py_ID___iter__));
    if res {
        return res;
    } elif PyErr_Occurred() {
        return NULL;
    } elif attr_is_none != 0 or has_dunder_getitem(self_) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "'%.200s' object is not iterable",
            object_type(self_).view(1)[0].tp_name
        );
        return NULL;
    }
    return PySeqIter_New(self_);
}

impl slot_tp_iternext(self_: ptr[PyObject]) -> ptr[PyObject] {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    return vectorcall_method(py_id(_Py_ID___next__), stack, 1);
}

impl slot_tp_descr_get(
    self_: ptr[PyObject], obj_: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    tp = object_type(self_);
    get_fn = _PyType_LookupRef(tp, py_id(_Py_ID___get__));
    if not get_fn {
        if int(tp.view(1)[0].tp_descr_get) == int(ptr(slot_tp_descr_get)) {
            tp.view(1)[0].tp_descr_get = 0;
        }
        return object_new_ref(self_);
    }
    instance = obj_;
    if not instance {
        instance = Py_None;
    }
    owner = type;
    if not owner {
        owner = Py_None;
    }
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = instance;
    (stack + 2).view(1)[0] = owner;
    res = PyObject_Vectorcall(get_fn, stack, u64(3), NULL);
    object_decref(get_fn);
    return res;
}

impl slot_tp_descr_set(
    self_: ptr[PyObject], target: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = target;
    res = NULL;
    if not value {
        res = vectorcall_method(py_id(_Py_ID___delete__), stack, 2);
    } else {
        (stack + 2).view(1)[0] = value;
        res = vectorcall_method(py_id(_Py_ID___set__), stack, 3);
    }
    if not res {
        return -1;
    }
    object_decref(res);
    return 0;
}

impl slot_tp_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    res = call_method(self_, py_id(_Py_ID___init__), args, kwds);
    if not res {
        return -1;
    }
    if res != Py_None {
        PyErr_Format(
            PyExc_TypeError,
            "__init__() should return None, not '%.200s'",
            object_type(res).view(1)[0].tp_name
        );
        object_decref(res);
        return -1;
    }
    object_decref(res);
    return 0;
}

impl slot_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    func = PyObject_GetAttr(ptr[PyObject](type), py_id(_Py_ID___new__));
    if not func {
        return NULL;
    }
    result = _PyObject_Call_Prepend(tstate, func, ptr[PyObject](type), args, kwds);
    object_decref(func);
    return result;
}

impl slot_tp_finalize(self_: ptr[PyObject]) {
    exc = PyErr_GetRaisedException();

    (unbound, ref) = lookup_maybe_method(self_, py_id(_Py_ID___del__));
    if unbound >= 0 {
        del_fn = stackref_borrow(ref);
        res = call_unbound_noarg(unbound, del_fn, self_);
        if not res {
            PyErr_FormatUnraisable(
                "Exception ignored while calling deallocator %R", del_fn
            );
        } else {
            object_decref(res);
        }
    }
    stackref_close(ref);

    PyErr_SetRaisedException(exc);
}

impl bufferwrapper_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    bw = ptr[PyBufferWrapper](op);
    vret = visit_reference(bw.view(1)[0].mv, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(bw.view(1)[0].obj_, visitor, arg);
    if vret != 0 {
        return vret;
    }
    return 0;
}

impl bufferwrapper_dealloc(self_: ptr[PyObject]) {
    bw = ptr[PyBufferWrapper](self_);
    object_gc_untrack(self_);
    object_xdecref(bw.view(1)[0].mv);
    object_xdecref(bw.view(1)[0].obj_);
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl bufferwrapper_releasebuf(self_: ptr[PyObject], view: ptr[Py_buffer]) {
    bw = ptr[PyBufferWrapper](self_);
    if not bw.view(1)[0].mv or not bw.view(1)[0].obj_ {
        return;
    }
    mv = bw.view(1)[0].mv;
    obj_ = bw.view(1)[0].obj_;

    mv_buffer = object_type(mv).view(1)[0].tp_as_buffer;
    mv_buffer.view(1)[0].bf_releasebuffer(mv, view);

    if ptr[Py_buffer](ptr[u8](mv) + PyMemoryViewObject_VIEW).view(1)[0].owner != obj_ {
        obj_buffer = object_type(obj_).view(1)[0].tp_as_buffer;
        if obj_buffer
            and int(obj_buffer.view(1)[0].bf_releasebuffer)
                == int(ptr(slot_bf_releasebuffer)) {
            releasebuffer_call_python(obj_, view);
        }
    }

    old_mv = bw.view(1)[0].mv;
    if old_mv {
        bw.view(1)[0].mv = NULL;
        object_decref(old_mv);
    }
    old_obj = bw.view(1)[0].obj_;
    if old_obj {
        bw.view(1)[0].obj_ = NULL;
        object_decref(old_obj);
    }
}

impl slot_bf_getbuffer(
    self_: ptr[PyObject], buffer: ptr[Py_buffer], flags: i32
) -> i32 {
    flags_obj = PyLong_FromLong(i64(flags));
    if not flags_obj {
        return -1;
    }

    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = flags_obj;
    ret = vectorcall_method(py_id(_Py_ID___buffer__), stack, 2);
    if not ret {
        object_decref(flags_obj);
        return -1;
    }
    if not object_is_type(ret, addressof(PyMemoryView_Type)) {
        PyErr_Format(PyExc_TypeError, "__buffer__ returned non-memoryview object");
        object_decref(ret);
        object_decref(flags_obj);
        return -1;
    }
    if PyObject_GetBuffer(ret, buffer, flags) < 0 {
        object_decref(ret);
        object_decref(flags_obj);
        return -1;
    }

    wrapper = _PyObject_GC_New(ptr[PyObject](addressof(_PyBufferWrapper_Type)));
    if not wrapper {
        object_decref(ret);
        object_decref(flags_obj);
        return -1;
    }
    bw = ptr[PyBufferWrapper](wrapper);
    bw.view(1)[0].mv = ret;
    bw.view(1)[0].obj_ = object_new_ref(self_);
    object_gc_track(wrapper);
    buffer.view(1)[0].owner = wrapper;
    object_decref(ret);
    object_decref(flags_obj);
    return 0;
}

impl releasebuffer_maybe_call_super_unlocked(
    self_: ptr[PyObject], buffer: ptr[Py_buffer]
) -> int {
    self_type = object_type(self_);
    mro = lookup_tp_mro(self_type);
    if not mro {
        return 0;
    }

    n = object_size(mro);
    i: i64 = 0;

    while i < n - 1 {
        if ptr[PyObject](self_type) == tuple_get_item(mro, i) {
            break;
        }
        i += 1;
    }

    i += 1;
    if i >= n {
        return 0;
    }
    while i < n {
        item = tuple_get_item(mro, i);
        i += 1;
        if not type_check(item) {
            continue;
        }
        base_buffer = ptr[PyTypeObject](item).view(1)[0].tp_as_buffer;
        if base_buffer {
            base_releasebuffer = int(base_buffer.view(1)[0].bf_releasebuffer);
            if base_releasebuffer != 0
                and base_releasebuffer != int(ptr(slot_bf_releasebuffer)) {
                return base_releasebuffer;
            }
        }
    }
    return 0;
}

impl releasebuffer_maybe_call_super(self_: ptr[PyObject], buffer: ptr[Py_buffer]) {
    base_releasebuffer = releasebuffer_maybe_call_super_unlocked(self_, buffer);
    if base_releasebuffer != 0 {
        calls = ptr[TypeCall](
            __thread_local_block("jac_object_model_type_type_calls", 208)
        );
        calls.view(1)[0].releasebufferproc = base_releasebuffer;
        calls.view(1)[0].releasebufferproc(self_, buffer);
    }
}

impl releasebuffer_call_python(self_: ptr[PyObject], buffer: ptr[Py_buffer]) {
    exc = PyErr_GetRaisedException();
    owner = buffer.view(1)[0].owner;
    is_buffer_wrapper = object_is_type(owner, addressof(_PyBufferWrapper_Type));
    mv = NULL;
    if is_buffer_wrapper {
        bw = ptr[PyBufferWrapper](owner);
        if not bw.view(1)[0].mv {
            PyErr_SetRaisedException(exc);
            return;
        }
        mv = object_new_ref(bw.view(1)[0].mv);
    } else {
        mv = PyMemoryView_FromBuffer(buffer);
        if not mv {
            PyErr_FormatUnraisable(
                "Exception ignored in bf_releasebuffer of %s",
                object_type(self_).view(1)[0].tp_name
            );
            PyErr_SetRaisedException(exc);
            return;
        }
        mv_obj = ptr[PyMemoryViewObject](mv);
        mv_obj.view(1)[0].flags = mv_obj.view(1)[0].flags | _Py_MEMORYVIEW_RESTRICTED;
    }
    slots: own StackArgs = StackArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = self_;
    (stack + 1).view(1)[0] = mv;
    ret = vectorcall_method(py_id(_Py_ID___release_buffer__), stack, 2);
    if not ret {
        PyErr_FormatUnraisable(
            "Exception ignored in __release_buffer__ of %s",
            object_type(self_).view(1)[0].tp_name
        );
    } else {
        object_decref(ret);
    }
    if not is_buffer_wrapper {
        stack.view(1)[0] = mv;
        res = PyObject_VectorcallMethod(
            py_id(_Py_ID_release), stack, u64(1) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
        );
        if not res {
            PyErr_FormatUnraisable(
                "Exception ignored in bf_releasebuffer of %s",
                object_type(self_).view(1)[0].tp_name
            );
        } else {
            object_decref(res);
        }
    }
    object_decref(mv);

    PyErr_SetRaisedException(exc);
}

impl slot_bf_releasebuffer(self_: ptr[PyObject], buffer: ptr[Py_buffer]) {
    releasebuffer_call_python(self_, buffer);
    releasebuffer_maybe_call_super(self_, buffer);
}

impl slot_am_generic(self_: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    res = _PyObject_MaybeCallSpecialNoArgs(self_, name);
    if not res and not PyErr_Occurred() {
        PyErr_Format(
            PyExc_AttributeError,
            "object %.50s does not have %U method",
            object_type(self_).view(1)[0].tp_name,
            name
        );
    }
    return res;
}

impl slot_am_await(self_: ptr[PyObject]) -> ptr[PyObject] {
    return slot_am_generic(self_, py_id(_Py_ID___await__));
}

impl slot_am_aiter(self_: ptr[PyObject]) -> ptr[PyObject] {
    return slot_am_generic(self_, py_id(_Py_ID___aiter__));
}

impl slot_am_anext(self_: ptr[PyObject]) -> ptr[PyObject] {
    return slot_am_generic(self_, py_id(_Py_ID___anext__));
}

impl init_slotdefs {
    first = ptr[SlotDef](addressof(slotdefs));
    ids = ptr[i64](addressof(slotdef_name_ids));
    i: i64 = 0;
    while (first + i).view(1)[0].name {
        (first + i).view(1)[0].name_strobj = py_id((ids + i).view(1)[0]);
        i += 1;
    }
}

impl slotptr(type: ptr[PyTypeObject], ioffset: i32) -> ptr[ptr] {
    offset = i64(ioffset);

    base: ptr[u8] = ptr[u8]();
    if offset >= PyHeapTypeObject_AS_BUFFER {
        base = ptr[u8](type.view(1)[0].tp_as_buffer);
        offset -= PyHeapTypeObject_AS_BUFFER;
    } elif offset >= PyHeapTypeObject_AS_SEQUENCE {
        base = ptr[u8](type.view(1)[0].tp_as_sequence);
        offset -= PyHeapTypeObject_AS_SEQUENCE;
    } elif offset >= PyHeapTypeObject_AS_MAPPING {
        base = ptr[u8](type.view(1)[0].tp_as_mapping);
        offset -= PyHeapTypeObject_AS_MAPPING;
    } elif offset >= PyHeapTypeObject_AS_NUMBER {
        base = ptr[u8](type.view(1)[0].tp_as_number);
        offset -= PyHeapTypeObject_AS_NUMBER;
    } elif offset >= PyHeapTypeObject_AS_ASYNC {
        base = ptr[u8](type.view(1)[0].tp_as_async);
        offset -= PyHeapTypeObject_AS_ASYNC;
    } else {
        base = ptr[u8](type);
    }
    if base {
        base = base + offset;
    }
    return ptr[ptr](base);
}

impl resolve_slotdups(type: ptr[PyTypeObject], name: ptr[PyObject]) -> ptr[ptr] {
    ptrs = ptr[ptr[SlotDef]](addressof(type_slots_ptrs));
    if type_slots_pname != name {
        type_slots_pname = name;
        pp = ptrs;
        p = ptr[SlotDef](addressof(slotdefs));
        while p.view(1)[0].name_strobj {
            if p.view(1)[0].name_strobj == name {
                pp.view(1)[0] = p;
                pp = pp + 1;
            }
            p = p + 1;
        }
        pp.view(1)[0] = ptr[SlotDef]();
    }

    res: ptr[ptr] = ptr[ptr]();
    pp = ptrs;
    while pp.view(1)[0] {
        slot = slotptr(type, pp.view(1)[0].view(1)[0].offset);
        pp = pp + 1;
        if not slot or not slot.view(1)[0] {
            continue;
        }
        if res {
            return ptr[ptr]();
        }
        res = slot;
    }
    return res;
}

impl wrapper_descr_base(descr: ptr[PyObject]) -> ptr[SlotDef] {
    return ptr[SlotDef](
        ptr[ptr](ptr[u8](descr) + PyWrapperDescrObject_BASE).view(1)[0]
    );
}

impl wrapper_descr_wrapped(descr: ptr[PyObject]) -> ptr {
    return ptr[ptr](ptr[u8](descr) + PyWrapperDescrObject_WRAPPED).view(1)[0];
}

impl method_descr_meth(descr: ptr[PyObject]) -> ptr {
    d_method = ptr[PyMethodDef](
        ptr[ptr](ptr[u8](descr) + PyMethodDescrObject_METHOD).view(1)[0]
    );
    return d_method.view(1)[0].ml_meth;
}

impl update_one_slot(type: ptr[PyTypeObject], p: ptr[SlotDef]) -> ptr[SlotDef] {
    specific: ptr = ptr();

    generic: ptr = ptr();

    use_generic: i32 = 0;
    cur = p;
    offset = cur.view(1)[0].offset;
    slot = slotptr(type, offset);
    if not slot {
        cur = cur + 1;
        while cur.view(1)[0].offset == offset {
            cur = cur + 1;
        }
        return cur;
    }
    type_addr = ptr[u8](type);

    while True {
        (res, descr_ref) = find_name_in_mro(type, cur.view(1)[0].name_strobj);
        if res <= 0 {
            if int(slot) == int(type_addr + PyTypeObject_TP_ITERNEXT) {
                specific = ptr(_PyObject_NextNotImplemented);
            }
        } else {
            descr = stackref_borrow(descr_ref);
            if object_is_type(descr, addressof(PyWrapperDescr_Type))
                and wrapper_descr_base(descr).view(1)[0].name_strobj
                    == cur.view(1)[0].name_strobj {
                tptr = resolve_slotdups(type, cur.view(1)[0].name_strobj);
                if not tptr or int(tptr) == int(slot) {
                    generic = cur.view(1)[0].function;
                }
                d_base = wrapper_descr_base(descr);
                d_wrapped = wrapper_descr_wrapped(descr);
                if (not specific or int(specific) == int(d_wrapped))
                    and int(d_base.view(1)[0].wrapper) == int(cur.view(1)[0].wrapper)
                    and is_subtype_with_mro(
                        lookup_tp_mro(type),
                        type,
                        ptr[PyDescrObject](descr).view(1)[0].d_type
                    )
                        != 0 {
                    specific = d_wrapped;
                } else {
                    use_generic = 1;
                }
            } elif object_is_type(descr, addressof(PyCFunction_Type))
                and int(
                    ptr[PyCFunctionObject](descr).view(1)[0].m_ml.view(1)[0].ml_meth
                )
                    == int(ptr(tp_new_wrapper))
                and int(slot) == int(type_addr + PyTypeObject_TP_NEW) {
                specific = slot.view(1)[0];
            } elif descr == Py_None
                and int(slot) == int(type_addr + PyTypeObject_TP_HASH) {
                specific = ptr(PyObject_HashNotImplemented);
            } else {
                use_generic = 1;
                if not generic
                    and object_is_type(descr, addressof(PyMethodDescr_Type))
                    and int(slot.view(1)[0]) == int(method_descr_meth(descr)) {
                    generic = slot.view(1)[0];
                } else {
                    generic = cur.view(1)[0].function;
                }
                if int(cur.view(1)[0].function) == int(ptr(slot_tp_call)) {
                    type_clear_flags(type, Py_TPFLAGS_HAVE_VECTORCALL);
                }
            }
            stackref_close(descr_ref);
        }
        cur = cur + 1;
        if cur.view(1)[0].offset != offset {
            break;
        }
    }
    if specific and use_generic == 0 {
        slot.view(1)[0] = specific;
    } else {
        slot.view(1)[0] = generic;
    }
    return cur;
}

impl update_slots_callback(type: ptr[PyTypeObject], pp: ptr[ptr[SlotDef]]) -> i32 {
    while pp.view(1)[0] {
        update_one_slot(type, pp.view(1)[0]);
        pp = pp + 1;
    }
    return 0;
}

impl update_slot(type: ptr[PyTypeObject], name: ptr[PyObject]) -> i32 {
    slots: own StackArgs = StackArgs();
    ptrs = ptr[ptr[SlotDef]](jacpy_stack_address(&mut slots));
    first = ptr[SlotDef](addressof(slotdefs));
    pp = ptrs;
    p = first;
    while p.view(1)[0].name {
        if p.view(1)[0].name_strobj == name {
            pp.view(1)[0] = p;
            pp = pp + 1;
        }
        p = p + 1;
    }
    pp.view(1)[0] = ptr[SlotDef]();
    pp = ptrs;
    while pp.view(1)[0] {
        p = pp.view(1)[0];
        offset = p.view(1)[0].offset;
        while int(p) > int(first) and (p - 1).view(1)[0].offset == offset {
            p = p - 1;
        }
        pp.view(1)[0] = p;
        pp = pp + 1;
    }
    if not ptrs.view(1)[0] {
        return 0;
    }
    return update_subclasses(type, name, ptrs);
}

impl fixup_slot_dispatchers(type: ptr[PyTypeObject]) {
    p = ptr[SlotDef](addressof(slotdefs));
    while p.view(1)[0].name {
        p = update_one_slot(type, p);
    }
}

impl update_all_slots(type: ptr[PyTypeObject]) {
    type_modified_unlocked(type);
    p = ptr[SlotDef](addressof(slotdefs));
    while p.view(1)[0].name {
        update_slot(type, p.view(1)[0].name_strobj);
        p = p + 1;
    }
}

impl type_new_set_names(type: ptr[PyTypeObject]) -> i32 {
    dct = lookup_tp_dict(type);
    names_to_set = PyDict_Copy(dct);
    if not names_to_set {
        return -1;
    }
    i: i64 = 0;
    key = NULL;
    value = NULL;
    while PyDict_Next(names_to_set, &mut i, &mut key, &mut value) != 0 {
        set_name = _PyObject_LookupSpecial(value, py_id(_Py_ID___set_name__));
        if not set_name {
            if PyErr_Occurred() {
                object_decref(names_to_set);
                return -1;
            }
            continue;
        }
        res = PyObject_CallFunctionObjArgs(set_name, ptr[PyObject](type), key, NULL);
        object_decref(set_name);
        if not res {
            _PyErr_FormatNote(
                "Error calling __set_name__ on '%.100s' instance %R in '%.100s'",
                object_type(value).view(1)[0].tp_name,
                key,
                type.view(1)[0].tp_name
            );
            object_decref(names_to_set);
            return -1;
        }
        object_decref(res);
    }
    object_decref(names_to_set);
    return 0;
}

impl type_new_init_subclass(type: ptr[PyTypeObject], kwds: ptr[PyObject]) -> i32 {
    slots: own StackArgs = StackArgs();
    args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    args.view(1)[0] = ptr[PyObject](type);
    (args + 1).view(1)[0] = ptr[PyObject](type);
    su = PyObject_Vectorcall(ptr[PyObject](addressof(PySuper_Type)), args, 2, NULL);
    if not su {
        return -1;
    }
    func = PyObject_GetAttr(su, py_id(_Py_ID___init_subclass__));
    object_decref(su);
    if not func {
        return -1;
    }
    result = PyObject_VectorcallDict(func, ptr[ptr[PyObject]](), 0, kwds);
    object_decref(func);
    if not result {
        return -1;
    }
    object_decref(result);
    return 0;
}

impl update_subclasses(
    type: ptr[PyTypeObject], attr_name: ptr[PyObject], pp: ptr[ptr[SlotDef]]
) -> i32 {
    if update_slots_callback(type, pp) < 0 {
        return -1;
    }
    return recurse_down_subclasses(type, attr_name, pp);
}

impl recurse_down_subclasses(
    type: ptr[PyTypeObject], attr_name: ptr[PyObject], pp: ptr[ptr[SlotDef]]
) -> i32 {
    subclasses = lookup_tp_subclasses(type);
    if not subclasses {
        return 0;
    }

    i: i64 = 0;
    key = NULL;
    ref = NULL;
    while PyDict_Next(subclasses, &mut i, &mut key, &mut ref) != 0 {
        subclass = type_from_ref(ref);
        if not subclass {
            continue;
        }

        dct = lookup_tp_dict(subclass);
        if dct and dict_check(dct) {
            r = PyDict_Contains(dct, attr_name);
            if r < 0 {
                object_decref(ptr[PyObject](subclass));
                return -1;
            }
            if r > 0 {
                object_decref(ptr[PyObject](subclass));
                continue;
            }
        }
        if update_subclasses(subclass, attr_name, pp) < 0 {
            object_decref(ptr[PyObject](subclass));
            return -1;
        }
        object_decref(ptr[PyObject](subclass));
    }
    return 0;
}

impl slot_inherited(
    type: ptr[PyTypeObject], slotdef: ptr[SlotDef], slot: ptr[ptr]
) -> i32 {
    base = type.view(1)[0].tp_base;
    slot_base = slotptr(base, slotdef.view(1)[0].offset);
    if not slot_base or int(slot.view(1)[0]) != int(slot_base.view(1)[0]) {
        return 0;
    }

    type_addr = ptr[u8](type);
    if int(slot) == int(type_addr + PyTypeObject_TP_HASH) {
        return i32(1)
            if int(type.view(1)[0].tp_richcompare)
                == int(base.view(1)[0].tp_richcompare)
            else i32(0);
    } elif int(slot) == int(type_addr + PyTypeObject_TP_RICHCOMPARE) {
        return i32(1)
            if int(type.view(1)[0].tp_hash) == int(base.view(1)[0].tp_hash)
            else i32(0);
    }

    return 1;
}

impl add_operators(type: ptr[PyTypeObject]) -> i32 {
    dct = lookup_tp_dict(type);
    first = ptr[SlotDef](addressof(slotdefs));
    i: i64 = 0;
    while (first + i).view(1)[0].name {
        p = first + i;
        i += 1;
        if not p.view(1)[0].wrapper {
            continue;
        }
        slot = slotptr(type, p.view(1)[0].offset);
        if not slot or not slot.view(1)[0] {
            continue;
        }

        if (type.view(1)[0].tp_flags & _Py_TPFLAGS_STATIC_BUILTIN) != 0
            and type.view(1)[0].tp_base
            and slot_inherited(type, p, slot) != 0 {
            continue;
        }
        r = PyDict_Contains(dct, p.view(1)[0].name_strobj);
        if r > 0 {
            continue;
        }
        if r < 0 {
            return -1;
        }
        if int(slot.view(1)[0]) == int(ptr(PyObject_HashNotImplemented)) {
            if PyDict_SetItem(dct, p.view(1)[0].name_strobj, Py_None) < 0 {
                return -1;
            }
        } else {
            descr = PyDescr_NewWrapper(type, ptr[wrapperbase](p), slot.view(1)[0]);
            if not descr {
                return -1;
            }
            if PyDict_SetItem(dct, p.view(1)[0].name_strobj, descr) < 0 {
                object_decref(descr);
                return -1;
            }
            object_decref(descr);
        }
    }
    return 0;
}

impl super_dealloc(self_: ptr[PyObject]) {
    su = ptr[SuperObject](self_);
    object_gc_untrack(self_);
    object_xdecref(su.view(1)[0].obj_);
    object_xdecref(ptr[PyObject](su.view(1)[0].type));
    object_xdecref(ptr[PyObject](su.view(1)[0].obj_type));
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl super_repr(self_: ptr[PyObject]) -> ptr[PyObject] {
    su = ptr[SuperObject](self_);
    cls_name = ptr[u8]("NULL");
    if su.view(1)[0].type {
        cls_name = su.view(1)[0].type.view(1)[0].tp_name;
    }
    if su.view(1)[0].obj_type {
        obj_name = su.view(1)[0].obj_type.view(1)[0].tp_name;
        return PyUnicode_FromFormat(
            "<super: <class '%s'>, <%s object>>", cls_name, obj_name
        );
    }
    return PyUnicode_FromFormat("<super: <class '%s'>, NULL>", cls_name);
}

impl _super_lookup_descr(
    su_type: ptr[PyTypeObject], su_obj_type: ptr[PyTypeObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    mro = lookup_tp_mro(su_obj_type);
    if not mro {
        return NULL;
    }

    mro_ref = stackref_new(mro);

    n = object_size(mro);

    i: i64 = 0;
    while i + 1 < n {
        if ptr[PyObject](su_type) == tuple_get_item(mro, i) {
            break;
        }
        i += 1;
    }

    i += 1;
    if i >= n {
        stackref_close(mro_ref);
        return NULL;
    }
    res = NULL;
    while i < n {
        cls = tuple_get_item(mro, i);

        dct = lookup_tp_dict(ptr[PyTypeObject](cls));
        if PyDict_GetItemRef(dct, name, &mut res) != 0 {
            stackref_close(mro_ref);
            return res;
        }
        i += 1;
    }
    stackref_close(mro_ref);
    return NULL;
}

impl do_super_lookup(
    su: ptr[SuperObject],
    su_type: ptr[PyTypeObject],
    su_obj: ptr[PyObject],
    su_obj_type: ptr[PyTypeObject],
    name: ptr[PyObject],
    want_method: bool
) -> tuple[ptr[PyObject], i32] {
    if su_obj_type {
        res = _super_lookup_descr(su_type, su_obj_type, name);
        if res {
            tp = object_type(res);
            if want_method and type_has_feature(tp, Py_TPFLAGS_METHOD_DESCRIPTOR) {
                return (res, i32(1));
            }
            if int(tp.view(1)[0].tp_descr_get) != 0 {
                inst = su_obj;
                if su_obj == ptr[PyObject](su_obj_type) {
                    inst = NULL;
                }
                res2 = tp.view(1)[0].tp_descr_get(
                    res, inst, ptr[PyObject](su_obj_type)
                );
                old = res;
                res = res2;
                object_decref(old);
            }
            return (res, i32(0));
        }
        if PyErr_Occurred() {
            return (NULL, i32(0));
        }
    }

    target = ptr[PyObject](su);
    temp_su = False;
    if not su {
        slots: own StackArgs = StackArgs();
        stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        stack.view(2)[0] = ptr[PyObject](su_type);
        stack.view(2)[1] = su_obj;
        target = PyObject_Vectorcall(
            ptr[PyObject](addressof(PySuper_Type)), stack, u64(2), NULL
        );
        if not target {
            return (NULL, i32(0));
        }
        temp_su = True;
    }
    found = PyObject_GenericGetAttr(target, name);
    if temp_su {
        object_decref(target);
    }
    return (found, i32(0));
}

impl super_getattro(self_: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    su = ptr[SuperObject](self_);

    if unicode_check(name)
        and unicode_length(name) == 9
        and _PyUnicode_Equal(name, py_id(_Py_ID___class__)) != 0 {
        return PyObject_GenericGetAttr(self_, name);
    }
    (res, is_method) = do_super_lookup(
        su, su.view(1)[0].type, su.view(1)[0].obj_, su.view(1)[0].obj_type, name, False
    );
    return res;
}

impl supercheck(type: ptr[PyTypeObject], obj_: ptr[PyObject]) -> ptr[PyTypeObject] {
    if type_check(obj_) and PyType_IsSubtype(ptr[PyTypeObject](obj_), type) != 0 {
        return ptr[PyTypeObject](object_new_ref(obj_));
    }

    obj_tp = object_type(obj_);
    if PyType_IsSubtype(obj_tp, type) != 0 {
        return ptr[PyTypeObject](object_new_ref(ptr[PyObject](obj_tp)));
    }

    class_attr = NULL;
    if PyObject_GetOptionalAttr(obj_, py_id(_Py_ID___class__), &mut class_attr) < 0 {
        return ptr[PyTypeObject]();
    }
    if class_attr
        and type_check(class_attr)
        and ptr[PyTypeObject](class_attr) != obj_tp {
        ok = PyType_IsSubtype(ptr[PyTypeObject](class_attr), type);
        if ok != 0 {
            return ptr[PyTypeObject](class_attr);
        }
    }
    object_xdecref(class_attr);
    type_or_instance = ptr[u8]("instance of");
    obj_str = object_type(obj_).view(1)[0].tp_name;
    if type_check(obj_) {
        type_or_instance = ptr[u8]("type");
        obj_str = ptr[PyTypeObject](obj_).view(1)[0].tp_name;
    }
    type_str = type.view(1)[0].tp_name;
    PyErr_Format(
        PyExc_TypeError,
        "super(type, obj): obj (%s %.200s) is not an instance or subtype of type (%.200s).",
        type_or_instance,
        obj_str,
        type_str
    );
    return ptr[PyTypeObject]();
}

impl super_descr_get(
    self_: ptr[PyObject], obj_: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    su = ptr[SuperObject](self_);
    if not obj_ or obj_ == Py_None or su.view(1)[0].obj_ {
        return object_new_ref(self_);
    }
    if not object_is_type(self_, addressof(PySuper_Type)) {
        return PyObject_CallFunctionObjArgs(
            ptr[PyObject](object_type(self_)),
            ptr[PyObject](su.view(1)[0].type),
            obj_,
            NULL
        );
    }

    obj_type = supercheck(su.view(1)[0].type, obj_);
    if not obj_type {
        return NULL;
    }
    newobj = addressof(PySuper_Type).view(1)[0].tp_new(
        addressof(PySuper_Type), NULL, NULL
    );
    if not newobj {
        object_decref(ptr[PyObject](obj_type));
        return NULL;
    }
    bound = ptr[SuperObject](newobj);
    bound.view(1)[0].type = ptr[PyTypeObject](
        object_new_ref(ptr[PyObject](su.view(1)[0].type))
    );
    bound.view(1)[0].obj_ = object_new_ref(obj_);
    bound.view(1)[0].obj_type = obj_type;
    return newobj;
}

impl frame_get_code(frame: ptr[u8]) -> ptr[u8] {
    return ptr[u8](
        stackref_borrow(ptr[u64](frame + _PyInterpreterFrame_F_EXECUTABLE).view(1)[0])
    );
}

impl frame_is_incomplete(frame: ptr[u8]) -> bool {
    owner = i32((frame + _PyInterpreterFrame_OWNER).view(1)[0]);
    if owner >= FRAME_OWNED_BY_INTERPRETER {
        return True;
    }
    if owner == FRAME_OWNED_BY_GENERATOR {
        return False;
    }
    co = frame_get_code(frame);
    instr_ptr = ptr[ptr[u16]](frame + _PyInterpreterFrame_INSTR_PTR).view(1)[0];
    firsttraceable = ptr[i32](co + PyCodeObject_FIRSTTRACEABLE).view(1)[0];

    first = ptr[u16](co + PyCodeObject_CODE_ADAPTIVE) + i64(firsttraceable);
    return instr_ptr < first;
}

impl thread_state_get_frame(tstate: ptr[PyThreadState]) -> ptr[u8] {
    frame = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0];
    while frame and frame_is_incomplete(frame) {
        frame = ptr[ptr[u8]](frame + _PyInterpreterFrame_PREVIOUS).view(1)[0];
    }
    return frame;
}

impl super_init_without_args(
    cframe: ptr[u8]
) -> tuple[i32, ptr[PyTypeObject], ptr[PyObject]] {
    co = frame_get_code(cframe);
    if ptr[i32](co + PyCodeObject_ARGCOUNT).view(1)[0] == 0 {
        PyErr_SetString(PyExc_RuntimeError, "super(): no arguments");
        return (i32(-1), ptr[PyTypeObject](), NULL);
    }

    localsplus = ptr[u64](cframe + _PyInterpreterFrame_LOCALSPLUS);
    firstarg = stackref_borrow(localsplus.view(1)[0]);
    if not firstarg {
        PyErr_SetString(PyExc_RuntimeError, "super(): arg[0] deleted");
        return (i32(-1), ptr[PyTypeObject](), NULL);
    }

    kinds = ptr[ptr[u8]](co + PyCodeObject_LOCALSPLUSKINDS).view(1)[0];
    kind0 = (kinds + PyBytesObject_OB_SVAL).view(1)[0];
    instr_ptr = ptr[ptr[u8]](cframe + _PyInterpreterFrame_INSTR_PTR).view(1)[0];
    bytecode = co + PyCodeObject_CODE_ADAPTIVE;

    if (kind0 & CO_FAST_CELL) != 0 and instr_ptr >= bytecode {
        firstarg = object_xnewref(ptr[PyCellObject](firstarg).view(1)[0].ob_ref);
        if not firstarg {
            PyErr_SetString(PyExc_RuntimeError, "super(): arg[0] deleted");
            return (i32(-1), ptr[PyTypeObject](), NULL);
        }
    } else {
        object_incref(firstarg);
    }

    cls = ptr[PyTypeObject]();
    nlocalsplus = ptr[i32](co + PyCodeObject_NLOCALSPLUS).view(1)[0];
    names = ptr[ptr[PyObject]](co + PyCodeObject_LOCALSPLUSNAMES).view(1)[0];

    i = nlocalsplus - ptr[i32](co + PyCodeObject_NFREEVARS).view(1)[0];
    while i < nlocalsplus {
        name = tuple_get_item(names, i64(i));
        if _PyUnicode_Equal(name, py_id(_Py_ID___class__)) != 0 {
            cell = stackref_borrow((localsplus + i64(i)).view(1)[0]);
            if not cell or not object_is_type(cell, addressof(PyCell_Type)) {
                PyErr_SetString(PyExc_RuntimeError, "super(): bad __class__ cell");
                object_decref(firstarg);
                return (i32(-1), ptr[PyTypeObject](), NULL);
            }

            cls = ptr[PyTypeObject](
                object_xnewref(ptr[PyCellObject](cell).view(1)[0].ob_ref)
            );
            if not cls {
                PyErr_SetString(PyExc_RuntimeError, "super(): empty __class__ cell");
                object_decref(firstarg);
                return (i32(-1), ptr[PyTypeObject](), NULL);
            }
            if not type_check(ptr[PyObject](cls)) {
                cls_tp_name = object_type(ptr[PyObject](cls)).view(1)[0].tp_name;
                PyErr_Format(
                    PyExc_RuntimeError,
                    "super(): __class__ is not a type (%s)",
                    cls_tp_name
                );
                object_decref(ptr[PyObject](cls));
                object_decref(firstarg);
                return (i32(-1), ptr[PyTypeObject](), NULL);
            }
            break;
        }
        i += 1;
    }
    if not cls {
        PyErr_SetString(PyExc_RuntimeError, "super(): __class__ cell not found");
        object_decref(firstarg);
        return (i32(-1), ptr[PyTypeObject](), NULL);
    }
    return (i32(0), cls, firstarg);
}

impl super_init(self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    if kwds and _PyArg_NoKeywords("super", kwds) == 0 {
        return -1;
    }
    if not tuple_check(args) {
        PyErr_SetString(
            PyExc_SystemError, "new style getargs format but argument is not a tuple"
        );
        return -1;
    }
    nargs: i64 = object_size(args);
    if nargs > 2 {
        PyErr_Format(
            PyExc_TypeError, "super() takes at most 2 arguments (%zd given)", nargs
        );
        return -1;
    }
    cls = ptr[PyTypeObject]();
    inst = NULL;
    if nargs >= 1 {
        arg0 = tuple_get_item(args, 0);

        if PyType_IsSubtype(object_type(arg0), addressof(PyType_Type)) == 0 {
            arg0_name = ptr[u8]("None");
            if arg0 != Py_None {
                arg0_name = object_type(arg0).view(1)[0].tp_name;
            }
            PyErr_Format(
                PyExc_TypeError, "super() argument 1 must be type, not %.50s", arg0_name
            );
            return -1;
        }
        cls = ptr[PyTypeObject](arg0);
    }
    if nargs == 2 {
        inst = tuple_get_item(args, 1);
    }
    if super_init_impl(self_, cls, inst) < 0 {
        return -1;
    }
    return 0;
}

impl super_init_impl(
    self_: ptr[PyObject], type: ptr[PyTypeObject], obj_: ptr[PyObject]
) -> i32 {
    su = ptr[SuperObject](self_);
    obj_type = ptr[PyTypeObject]();
    cls = type;
    inst = obj_;
    if not cls {
        tstate = thread_state();
        frame = thread_state_get_frame(tstate);
        if not frame {
            PyErr_SetString(PyExc_RuntimeError, "super(): no current frame");
            return -1;
        }
        (res, frame_cls, frame_obj) = super_init_without_args(frame);
        if res < 0 {
            return -1;
        }
        cls = frame_cls;
        inst = frame_obj;
    } else {
        object_incref(ptr[PyObject](cls));
        object_xincref(inst);
    }
    if inst == Py_None {
        object_decref(inst);
        inst = NULL;
    }
    if inst {
        obj_type = supercheck(cls, inst);
        if not obj_type {
            object_decref(ptr[PyObject](cls));
            object_decref(inst);
            return -1;
        }
    }
    old_type = su.view(1)[0].type;
    su.view(1)[0].type = cls;
    object_xdecref(ptr[PyObject](old_type));
    old_obj = su.view(1)[0].obj_;
    su.view(1)[0].obj_ = inst;
    object_xdecref(old_obj);
    old_obj_type = su.view(1)[0].obj_type;
    su.view(1)[0].obj_type = obj_type;
    object_xdecref(ptr[PyObject](old_obj_type));
    return 0;
}

impl super_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    su = ptr[SuperObject](self_);
    vret = visit_reference(su.view(1)[0].obj_, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(ptr[PyObject](su.view(1)[0].type), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(ptr[PyObject](su.view(1)[0].obj_type), visitor, arg);
    if vret != 0 {
        return vret;
    }
    return 0;
}

impl super_vectorcall(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames and _PyArg_NoKwnames("super", kwnames) == 0 {
        return NULL;
    }
    nargs = vectorcall_nargs(nargsf);
    if (nargs < 0 or nargs > 2)
        and _PyArg_CheckPositional("super()", nargs, 0, 2) == 0 {
        return NULL;
    }
    cls = ptr[PyTypeObject]();
    inst = NULL;
    self_type = ptr[PyTypeObject](self_);
    su = self_type.view(1)[0].tp_alloc(self_type, 0);
    if not su {
        return NULL;
    }

    if nargs != 0 {
        arg0 = args.view(1)[0];
        if not type_check(arg0) {
            arg0_name = object_type(arg0).view(1)[0].tp_name;
            PyErr_Format(
                PyExc_TypeError,
                "super() argument 1 must be a type, not %.200s",
                arg0_name
            );
            object_decref(su);
            return NULL;
        }
        cls = ptr[PyTypeObject](arg0);
    }
    if nargs == 2 {
        inst = (args + 1).view(1)[0];
    }
    if super_init_impl(su, cls, inst) < 0 {
        object_decref(su);
        return NULL;
    }
    return su;
}
