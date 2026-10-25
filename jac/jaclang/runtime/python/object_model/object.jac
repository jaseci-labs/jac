import from c {
    glob PyType_Type: PyTypeObject,
         PyBaseObject_Type: PyTypeObject,
         PyUnicode_Type: PyTypeObject,
         PyBool_Type: PyTypeObject,
         PyClassMethod_Type: PyTypeObject,
         PyStaticMethod_Type: PyTypeObject,
         PyAsyncGen_Type: PyTypeObject,
         PyByteArrayIter_Type: PyTypeObject,
         PyByteArray_Type: PyTypeObject,
         PyBytesIter_Type: PyTypeObject,
         PyBytes_Type: PyTypeObject,
         PyCFunction_Type: PyTypeObject,
         PyCallIter_Type: PyTypeObject,
         PyCapsule_Type: PyTypeObject,
         PyCell_Type: PyTypeObject,
         PyClassMethodDescr_Type: PyTypeObject,
         PyCode_Type: PyTypeObject,
         PyComplex_Type: PyTypeObject,
         PyContextToken_Type: PyTypeObject,
         PyContextVar_Type: PyTypeObject,
         PyContext_Type: PyTypeObject,
         PyCoro_Type: PyTypeObject,
         PyDictItems_Type: PyTypeObject,
         PyDictIterItem_Type: PyTypeObject,
         PyDictIterKey_Type: PyTypeObject,
         PyDictIterValue_Type: PyTypeObject,
         PyDictKeys_Type: PyTypeObject,
         PyDictProxy_Type: PyTypeObject,
         PyDictRevIterItem_Type: PyTypeObject,
         PyDictRevIterKey_Type: PyTypeObject,
         PyDictRevIterValue_Type: PyTypeObject,
         PyDictValues_Type: PyTypeObject,
         PyDict_Type: PyTypeObject,
         PyEllipsis_Type: PyTypeObject,
         PyEnum_Type: PyTypeObject,
         PyFilter_Type: PyTypeObject,
         PyFloat_Type: PyTypeObject,
         PyFrame_Type: PyTypeObject,
         PyFrameLocalsProxy_Type: PyTypeObject,
         PyFrozenSet_Type: PyTypeObject,
         PyFunction_Type: PyTypeObject,
         PyGen_Type: PyTypeObject,
         PyGetSetDescr_Type: PyTypeObject,
         PyInstanceMethod_Type: PyTypeObject,
         PyListIter_Type: PyTypeObject,
         PyListRevIter_Type: PyTypeObject,
         PyList_Type: PyTypeObject,
         PyLongRangeIter_Type: PyTypeObject,
         PyLong_Type: PyTypeObject,
         PyMap_Type: PyTypeObject,
         PyMemberDescr_Type: PyTypeObject,
         PyMemoryView_Type: PyTypeObject,
         PyMethodDescr_Type: PyTypeObject,
         PyMethod_Type: PyTypeObject,
         PyModuleDef_Type: PyTypeObject,
         PyModule_Type: PyTypeObject,
         PyODictIter_Type: PyTypeObject,
         PyPickleBuffer_Type: PyTypeObject,
         PyProperty_Type: PyTypeObject,
         PyRangeIter_Type: PyTypeObject,
         PyRange_Type: PyTypeObject,
         PyReversed_Type: PyTypeObject,
         PySeqIter_Type: PyTypeObject,
         PySetIter_Type: PyTypeObject,
         PySet_Type: PyTypeObject,
         PySlice_Type: PyTypeObject,
         PyStdPrinter_Type: PyTypeObject,
         PySuper_Type: PyTypeObject,
         PyTraceBack_Type: PyTypeObject,
         PyTupleIter_Type: PyTypeObject,
         PyTuple_Type: PyTypeObject,
         PyUnicodeIter_Type: PyTypeObject,
         PyWrapperDescr_Type: PyTypeObject,
         PyZip_Type: PyTypeObject,
         Py_GenericAliasType: PyTypeObject,
         _PyAnextAwaitable_Type: PyTypeObject,
         _PyAsyncGenASend_Type: PyTypeObject,
         _PyAsyncGenAThrow_Type: PyTypeObject,
         _PyAsyncGenWrappedValue_Type: PyTypeObject,
         _PyBufferWrapper_Type: PyTypeObject,
         _PyContextTokenMissing_Type: PyTypeObject,
         _PyCoroWrapper_Type: PyTypeObject,
         _Py_GenericAliasIterType: PyTypeObject,
         _PyHamtItems_Type: PyTypeObject,
         _PyHamtKeys_Type: PyTypeObject,
         _PyHamtValues_Type: PyTypeObject,
         _PyHamt_ArrayNode_Type: PyTypeObject,
         _PyHamt_BitmapNode_Type: PyTypeObject,
         _PyHamt_CollisionNode_Type: PyTypeObject,
         _PyHamt_Type: PyTypeObject,
         _PyInterpolation_Type: PyTypeObject,
         _PyLegacyEventHandler_Type: PyTypeObject,
         _PyLineIterator: PyTypeObject,
         _PyManagedBuffer_Type: PyTypeObject,
         _PyMemoryIter_Type: PyTypeObject,
         _PyMethodWrapper_Type: PyTypeObject,
         _PyNamespace_Type: PyTypeObject,
         _PyPositionsIterator: PyTypeObject,
         _PyTemplate_Type: PyTypeObject,
         _PyTemplateIter_Type: PyTypeObject,
         _PyUnicodeASCIIIter_Type: PyTypeObject,
         _PyUnion_Type: PyTypeObject,
         _PyWeakref_CallableProxyType: PyTypeObject,
         _PyWeakref_ProxyType: PyTypeObject,
         _PyWeakref_RefType: PyTypeObject,
         _PyTypeAlias_Type: PyTypeObject,
         _PyNoDefault_Type: PyTypeObject,
         PyCMethod_Type: PyTypeObject,
         PyODictItems_Type: PyTypeObject,
         PyODictKeys_Type: PyTypeObject,
         PyODictValues_Type: PyTypeObject,
         PyODict_Type: PyTypeObject,
         _Py_TrueStruct: PyObject,
         _Py_FalseStruct: PyObject,
         _Py_EllipsisObject: PyObject; def Py_EnterRecursiveCall(
        where: ptr[u8]
    ) -> i32;  def Py_FatalError(message: ptr[u8]);  def _PyType_LookupStackRefAndVersion(
        type: ptr[PyTypeObject], name: ptr[PyObject], out: &mut u64
    ) -> u32;  def _Py_type_getattro(
        type: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_type_getattro_impl(
        type: ptr[PyTypeObject], name: ptr[PyObject], suppress_missing: &mut i32
    ) -> ptr[PyObject];  def _Py_module_getattro(
        op: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_module_getattro_impl(
        m: ptr[PyObject], name: ptr[PyObject], suppress: i32
    ) -> ptr[PyObject];  def _PyUnicode_InternMortal(
        interp: ptr[u8], p: &mut ptr[PyObject]
    );  def _PyUnicode_FromId(id: ptr) -> ptr[PyObject];  def PyThreadState_GetDict -> ptr[
        PyObject
    ];  def _PyEval_GetFrame -> ptr[u8];  def _PyEval_GetFrameLocals -> ptr[PyObject];  def _PyEval_GetGlobalsFromRunningMain(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyObject_SetDict(
        ob: ptr[PyObject], value: ptr[PyObject]
    ) -> i32;  def _Py_BaseObject_RichCompare(
        left: ptr[PyObject], right: ptr[PyObject], op: i32
    ) -> ptr[PyObject];  def _PyStaticType_GetState(
        interp: ptr, type: ptr[PyTypeObject]
    ) -> ptr[u8];  def _PyStaticType_InitBuiltin(
        interp: ptr, type: ptr[PyTypeObject]
    ) -> i32;  def _PyStaticType_FiniBuiltin(interp: ptr, type: ptr[PyTypeObject]);  def _Py_initialize_generic(
        interp: ptr
    ) -> i32;  def _PyType_CheckConsistency(type: ptr[PyTypeObject]) -> i32;  def _PyUnicode_CheckConsistency(
        op: ptr[PyObject], check_content: i32
    ) -> i32;  def _PyDict_CheckConsistency(
        op: ptr[PyObject], check_content: i32
    ) -> i32;  def _PyMem_DumpTraceback(fd: i32, block: ptr);  def _PyObject_TryGetInstanceAttribute(
        ob: ptr[PyObject], name: ptr[PyObject], attr: &mut ptr[PyObject]
    ) -> bool;  def _PyObject_MaterializeManagedDict(
        ob: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_StoreInstanceAttribute(
        ob: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
    ) -> i32;  def _PyObjectDict_SetItem(
        tp: ptr[PyTypeObject],
        ob: ptr[PyObject],
        dictptr: ptr[ptr[PyObject]],
        key: ptr[PyObject],
        value: ptr[PyObject]
    ) -> i32;  def _PyDict_GetMethodStackRef(
        mp: ptr[PyObject], key: ptr[PyObject], method: ptr[u64]
    ) -> i32;  def _PyDict_DebugMallocStats(out: ptr);  def _PyFloat_DebugMallocStats(
        out: ptr
    );  def _PyList_DebugMallocStats(out: ptr);  def _PyTuple_DebugMallocStats(
        out: ptr
    );  def jacpy_stdio_stream(stream: i32) -> ptr;  def fprintf(
        stream: ptr, format: str, *args: any
    ) -> i32;  def fflush(stream: ptr) -> i32;  def fwrite(
        data: ptr, size: u64, count: u64, stream: ptr
    ) -> u64;  def ferror(stream: ptr) -> i32;  def clearerr(stream: ptr);  obj ObjectCall {
        has tracer: Callable[[ptr[PyObject], i32, ptr], i32] = 0;
    }  glob:priv interned_ids: list[ptr[PyObject]] = [
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject]()
         ],
         none_as_number: PyNumberMethods = PyNumberMethods(nb_bool=none_bool),
         notimplemented_as_number: PyNumberMethods = PyNumberMethods(
             nb_bool=notimplemented_bool
         ),
         notimplemented_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(NotImplemented_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob _Py_SwappedOp: list[i32] = [
             Py_GT,
             Py_GE,
             Py_EQ,
             Py_NE,
             Py_LT,
             Py_LE
         ],
         _PyNone_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("NoneType"),
             tp_dealloc=none_dealloc,
             tp_repr=none_repr,
             tp_as_number=addressof(none_as_number),
             tp_hash=none_hash,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_doc=ptr[u8]("NoneType()\n--\n\nThe type of the None singleton."),
             tp_richcompare=_Py_BaseObject_RichCompare,
             tp_new=none_new
         ),
         _Py_NoneStruct: _object = _object(
             ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
             ob_type=addressof(_PyNone_Type)
         ),
         _PyNotImplemented_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("NotImplementedType"),
             tp_dealloc=notimplemented_dealloc,
             tp_repr=NotImplemented_repr,
             tp_as_number=addressof(notimplemented_as_number),
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_doc=ptr[u8](
                 "NotImplementedType()\n--\n\n"
                 "The type of the NotImplemented singleton."
             ),
             tp_methods=addressof(notimplemented_methods),
             tp_new=notimplemented_new
         ),
         _Py_NotImplementedStruct: _object = _object(
             ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
             ob_type=addressof(_PyNotImplemented_Type)
         ); glob:priv constants: list[ptr[PyObject]] = [
             ptr[PyObject](addressof(_Py_NoneStruct)),
             ptr[PyObject](addressof(_Py_FalseStruct)),
             ptr[PyObject](addressof(_Py_TrueStruct)),
             ptr[PyObject](addressof(_Py_EllipsisObject)),
             ptr[PyObject](addressof(_Py_NotImplementedStruct)),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject]()
         ],
         static_types: list[ptr[PyTypeObject]] = [
             addressof(PyBaseObject_Type),
             addressof(PyType_Type),
             addressof(PyAsyncGen_Type),
             addressof(PyByteArrayIter_Type),
             addressof(PyByteArray_Type),
             addressof(PyBytesIter_Type),
             addressof(PyBytes_Type),
             addressof(PyCFunction_Type),
             addressof(PyCallIter_Type),
             addressof(PyCapsule_Type),
             addressof(PyCell_Type),
             addressof(PyClassMethodDescr_Type),
             addressof(PyClassMethod_Type),
             addressof(PyCode_Type),
             addressof(PyComplex_Type),
             addressof(PyContextToken_Type),
             addressof(PyContextVar_Type),
             addressof(PyContext_Type),
             addressof(PyCoro_Type),
             addressof(PyDictItems_Type),
             addressof(PyDictIterItem_Type),
             addressof(PyDictIterKey_Type),
             addressof(PyDictIterValue_Type),
             addressof(PyDictKeys_Type),
             addressof(PyDictProxy_Type),
             addressof(PyDictRevIterItem_Type),
             addressof(PyDictRevIterKey_Type),
             addressof(PyDictRevIterValue_Type),
             addressof(PyDictValues_Type),
             addressof(PyDict_Type),
             addressof(PyEllipsis_Type),
             addressof(PyEnum_Type),
             addressof(PyFilter_Type),
             addressof(PyFloat_Type),
             addressof(PyFrame_Type),
             addressof(PyFrameLocalsProxy_Type),
             addressof(PyFrozenSet_Type),
             addressof(PyFunction_Type),
             addressof(PyGen_Type),
             addressof(PyGetSetDescr_Type),
             addressof(PyInstanceMethod_Type),
             addressof(PyListIter_Type),
             addressof(PyListRevIter_Type),
             addressof(PyList_Type),
             addressof(PyLongRangeIter_Type),
             addressof(PyLong_Type),
             addressof(PyMap_Type),
             addressof(PyMemberDescr_Type),
             addressof(PyMemoryView_Type),
             addressof(PyMethodDescr_Type),
             addressof(PyMethod_Type),
             addressof(PyModuleDef_Type),
             addressof(PyModule_Type),
             addressof(PyODictIter_Type),
             addressof(PyPickleBuffer_Type),
             addressof(PyProperty_Type),
             addressof(PyRangeIter_Type),
             addressof(PyRange_Type),
             addressof(PyReversed_Type),
             addressof(PySeqIter_Type),
             addressof(PySetIter_Type),
             addressof(PySet_Type),
             addressof(PySlice_Type),
             addressof(PyStaticMethod_Type),
             addressof(PyStdPrinter_Type),
             addressof(PySuper_Type),
             addressof(PyTraceBack_Type),
             addressof(PyTupleIter_Type),
             addressof(PyTuple_Type),
             addressof(PyUnicodeIter_Type),
             addressof(PyUnicode_Type),
             addressof(PyWrapperDescr_Type),
             addressof(PyZip_Type),
             addressof(Py_GenericAliasType),
             addressof(_PyAnextAwaitable_Type),
             addressof(_PyAsyncGenASend_Type),
             addressof(_PyAsyncGenAThrow_Type),
             addressof(_PyAsyncGenWrappedValue_Type),
             addressof(_PyBufferWrapper_Type),
             addressof(_PyContextTokenMissing_Type),
             addressof(_PyCoroWrapper_Type),
             addressof(_Py_GenericAliasIterType),
             addressof(_PyHamtItems_Type),
             addressof(_PyHamtKeys_Type),
             addressof(_PyHamtValues_Type),
             addressof(_PyHamt_ArrayNode_Type),
             addressof(_PyHamt_BitmapNode_Type),
             addressof(_PyHamt_CollisionNode_Type),
             addressof(_PyHamt_Type),
             addressof(_PyInterpolation_Type),
             addressof(_PyLegacyEventHandler_Type),
             addressof(_PyLineIterator),
             addressof(_PyManagedBuffer_Type),
             addressof(_PyMemoryIter_Type),
             addressof(_PyMethodWrapper_Type),
             addressof(_PyNamespace_Type),
             addressof(_PyNone_Type),
             addressof(_PyNotImplemented_Type),
             addressof(_PyPositionsIterator),
             addressof(_PyTemplate_Type),
             addressof(_PyTemplateIter_Type),
             addressof(_PyUnicodeASCIIIter_Type),
             addressof(_PyUnion_Type),
             addressof(_PyWeakref_CallableProxyType),
             addressof(_PyWeakref_ProxyType),
             addressof(_PyWeakref_RefType),
             addressof(_PyTypeAlias_Type),
             addressof(_PyNoDefault_Type),
             addressof(PyBool_Type),
             addressof(PyCMethod_Type),
             addressof(PyODictItems_Type),
             addressof(PyODictKeys_Type),
             addressof(PyODictValues_Type),
             addressof(PyODict_Type)
         ];
}

glob:priv STACKREF_NULL: u64 = u64(1),
     STACKREF_TAG_BITS: u64 = u64(3),
     STACKREF_INT_TAG: u64 = u64(3),
     MANAGED_DICT_OFFSET: i64 = -24,
     PYREFTRACER_CREATE: i32 = 0,
     PYREFTRACER_DESTROY: i32 = 1,
     IMMORTAL_FLAGS_BITS: i64 = 0x1000000000000,
     TPFLAGS_PREHEADER: u64 = Py_TPFLAGS_MANAGED_WEAKREF | Py_TPFLAGS_MANAGED_DICT,
     N_STATIC_TYPES: i64 = 114,
     N_CONSTANTS: u32 = u32(10),
     CONSTANT_ZERO: i64 = 5,
     CONSTANT_ONE: i64 = 6,
     CONSTANT_EMPTY_STR: i64 = 7,
     CONSTANT_EMPTY_BYTES: i64 = 8,
     CONSTANT_EMPTY_TUPLE: i64 = 9,
     NSMALLNEGINTS: i64 = 5,
     FREE_OBJECT: i64 = 0,
     FREE_MEM: i64 = 1,
     FREE_RAW_MEM: i64 = 2,
     FREE_GC: i64 = 3,
     ID_BYTES: int = 0,
     ID_QUALNAME: int = 1,
     ID_MODULE: int = 2,
     ID_BUILTINS: int = 3,
     ID_ISABSTRACTMETHOD: int = 4,
     ID_NAME: int = 5,
     ID_OBJ: int = 6,
     ID_DIR: int = 7,
     ID_PY_REPR: int = 8,
     ID_REDUCE: int = 9,
     ID_TEXT: list[str] = [
         "__bytes__",
         "__qualname__",
         "__module__",
         "builtins",
         "__isabstractmethod__",
         "name",
         "obj",
         "__dir__",
         "Py_Repr",
         "__reduce__"
     ];

def py_none -> ptr[PyObject];

def py_not_implemented -> ptr[PyObject];

def py_true -> ptr[PyObject];

def py_false -> ptr[PyObject];

def unicode_check(op: ptr[PyObject]) -> bool;

def unicode_check_exact(op: ptr[PyObject]) -> bool;

def type_check(op: ptr[PyObject]) -> bool;

def list_check(op: ptr[PyObject]) -> bool;

def dict_check(op: ptr[PyObject]) -> bool;

def bytes_check(op: ptr[PyObject]) -> bool;

def dict_used(op: ptr[PyObject]) -> i64;

def type_is_ready(tp: ptr[PyTypeObject]) -> bool;

def object_is_immortal(op: ptr[PyObject]) -> bool;

def set_refcnt(op: ptr[PyObject], refcnt: i64);

def decref_mortal(op: ptr[PyObject]);

def stackref_borrow(bits: u64) -> ptr[PyObject];

def stackref_new(op: ptr[PyObject]) -> u64;

def stackref_steal(op: ptr[PyObject]) -> u64;

def stackref_as_object_steal(bits: u64) -> ptr[PyObject];

def stackref_close(bits: u64);

def stackref_clear(slot: ptr[u64]);

def stackref_xsetref(slot: ptr[u64], bits: u64);

def stackref_is_heap_safe(bits: u64) -> bool;

def reftracer_track(op: ptr[PyObject], operation: i32);

def interned_id(which: int) -> ptr[PyObject];

def managed_dict_slot(ob: ptr[PyObject]) -> ptr[ptr[PyObject]];

def managed_dict(ob: ptr[PyObject]) -> ptr[PyObject];

def attribute_error_pending -> bool;

def interp_of(tstate: ptr[u8]) -> ptr[u8];

def gc_finalized(op: ptr[PyObject]) -> bool;

def gc_set_finalized(op: ptr[PyObject]);

def object_is_gc(op: ptr[PyObject]) -> bool;

def var_size(tp: ptr[PyTypeObject], nitems: i64) -> i64;

def status_ok -> PyStatus;

def status_err(func: ptr[u8], msg: ptr[u8]) -> PyStatus;

def bad_attribute_name(name: ptr[PyObject]);

def no_attribute(ob: ptr[PyObject], tp: ptr[PyTypeObject], name: ptr[PyObject]);

def new_reference(op: ptr[PyObject]);

def object_init(op: ptr[PyObject], tp: ptr[PyTypeObject]);

def resurrect_end(op: ptr[PyObject]) -> bool;

def try_incref(op: ptr[PyObject]) -> bool;

def assert_failed(op: ptr[PyObject], msg: ptr[u8], line: i32, function: ptr[u8]);

import from c {
    def Py_IncRef(o: ptr[PyObject]) {
        if o {
            object_incref(o);
        }
    }  def Py_DecRef(o: ptr[PyObject]) {
        if o {
            object_decref(o);
        }
    }  def _Py_IncRef(o: ptr[PyObject]) {
        object_incref(o);
    }  def _Py_DecRef(o: ptr[PyObject]) {
        object_decref(o);
    }  def PyObject_Init(op: ptr[PyObject], tp: ptr[PyTypeObject]) -> ptr[PyObject] {
        if not op {
            return PyErr_NoMemory();
        }
        object_init(op, tp);
        return op;
    }  def PyObject_InitVar(
        op: ptr[PyObject], tp: ptr[PyTypeObject], size: i64
    ) -> ptr[PyObject] {
        if not op {
            return PyErr_NoMemory();
        }
        object_init(op, tp);
        ptr[PyVarObject](op).view(1)[0].ob_size = size;
        return op;
    }  def _PyObject_New(tp: ptr[PyTypeObject]) -> ptr[PyObject] {
        op = ptr[PyObject](PyObject_Malloc(u64(tp.view(1)[0].tp_basicsize)));
        if not op {
            return PyErr_NoMemory();
        }
        object_init(op, tp);
        return op;
    }  def _PyObject_NewVar(tp: ptr[PyTypeObject], nitems: i64) -> ptr[PyObject] {
        op = ptr[PyObject](PyObject_Malloc(u64(var_size(tp, nitems))));
        if not op {
            return PyErr_NoMemory();
        }
        object_init(op, tp);
        ptr[PyVarObject](op).view(1)[0].ob_size = nitems;
        return op;
    }  def PyObject_CallFinalizer(op_self: ptr[PyObject]) {
        tp = object_type(op_self);
        if int(tp.view(1)[0].tp_finalize) == 0 {
            return;
        }

        is_gc = type_has_feature(tp, Py_TPFLAGS_HAVE_GC);
        if is_gc and gc_finalized(op_self) {
            return;
        }
        tp.view(1)[0].tp_finalize(op_self);
        if is_gc {
            gc_set_finalized(op_self);
        }
    }  def PyObject_CallFinalizerFromDealloc(op_self: ptr[PyObject]) -> i32 {
        if object_refcount(op_self) != 0 {
            assert_failed(
                op_self,
                ptr[u8](
                    "PyObject_CallFinalizerFromDealloc called on object with a non-zero refcount"
                ),
                i32(596),
                ptr[u8]("PyObject_CallFinalizerFromDealloc")
            );
        }

        set_refcnt(op_self, 1);
        PyObject_CallFinalizer(op_self);

        if resurrect_end(op_self) {
            return i32(-1);
        }

        return i32(0);
    }  def _Py_NewReference(op: ptr[PyObject]) {
        new_reference(op);
    }  def _Py_NewReferenceNoTotal(op: ptr[PyObject]) {
        new_reference(op);
    }  def _Py_SetImmortalUntracked(op: ptr[PyObject]) {
        if object_is_immortal(op) {
            return;
        }
        header = ptr[_object](op);
        overflow = header.view(1)[0].ob_refcnt_full & 0xFFFF00000000;
        header.view(1)[0].ob_refcnt_full = IMMORTAL_FLAGS_BITS
            | overflow
            | _Py_IMMORTAL_INITIAL_REFCNT;
    }  def _Py_SetImmortal(op: ptr[PyObject]) {
        if object_is_gc(op) and object_gc_is_tracked(op) {
            object_gc_untrack(op);
        }
        _Py_SetImmortalUntracked(op);
    }  def _PyObject_SetDeferredRefcount(op: ptr[PyObject]) -> None {
        return;
    }  def PyUnstable_Object_EnableDeferredRefcount(op: ptr[PyObject]) -> i32 {
        return i32(0);
    }  def PyUnstable_Object_IsUniqueReferencedTemporary(op: ptr[PyObject]) -> i32 {
        if object_refcount(op) != 1 {
            return i32(0);
        }
        frame = _PyEval_GetFrame();
        if not frame {
            return i32(0);
        }

        code = stackref_borrow(
            ptr[u64](frame + _PyInterpreterFrame_F_EXECUTABLE).view(1)[0]
        );
        nlocalsplus = ptr[i32](ptr[u8](code) + PyCodeObject_NLOCALSPLUS).view(1)[0];
        base = ptr[u64](frame + _PyInterpreterFrame_LOCALSPLUS) + i64(nlocalsplus);
        stackpointer = ptr[ptr[u64]](frame + _PyInterpreterFrame_STACKPOINTER).view(1)[
            0
        ];
        while stackpointer > base {
            stackpointer = stackpointer - 1;
            bits = stackpointer.view(1)[0];
            if (bits & STACKREF_TAG_BITS) == STACKREF_INT_TAG {
                continue;
            }
            if op == stackref_borrow(bits) {
                return i32(1) if stackref_is_heap_safe(bits) else i32(0);
            }
        }
        return i32(0);
    }  def PyUnstable_TryIncRef(op: ptr[PyObject]) -> i32 {
        return i32(1) if try_incref(op) else i32(0);
    }  def PyUnstable_EnableTryIncRef(op: ptr[PyObject]) -> None {
        return;
    }  def _Py_ResurrectReference(op: ptr[PyObject]) -> None {
        return;
    }  def _Py_ForgetReference(op: ptr[PyObject]) -> None {
        return;
    }  def _Py_SetRefcnt(ob: ptr[PyObject], refcnt: i64) {
        set_refcnt(ob, refcnt);
    }  def PyUnstable_IsImmortal(op: ptr[PyObject]) -> i32 {
        return i32(1) if object_is_immortal(op) else i32(0);
    }  def PyUnstable_Object_IsUniquelyReferenced(op: ptr[PyObject]) -> i32 {
        return i32(1) if object_refcount(op) == 1 else i32(0);
    }  def PyRefTracer_SetTracer(tracer: ptr, data: ptr) -> i32 {
        runtime = int(addressof(_PyRuntime));
        ptr[ptr](runtime + _PyRuntimeState_REF_TRACER_FUNC).view(1)[0] = tracer;
        ptr[ptr](runtime + _PyRuntimeState_REF_TRACER_DATA).view(1)[0] = data;
        return i32(0);
    }  def PyRefTracer_GetTracer(data: ptr[ptr]) -> ptr {
        runtime = int(addressof(_PyRuntime));
        if data {
            data.view(1)[0] = ptr[ptr](runtime + _PyRuntimeState_REF_TRACER_DATA).view(
                1
            )[0];
        }
        return ptr[ptr](runtime + _PyRuntimeState_REF_TRACER_FUNC).view(1)[0];
    }  def Py_NewRef(ob: ptr[PyObject]) -> ptr[PyObject] {
        object_incref(ob);
        return ob;
    }  def Py_XNewRef(ob: ptr[PyObject]) -> ptr[PyObject] {
        if ob {
            object_incref(ob);
        }
        return ob;
    }  def Py_Is(x: ptr[PyObject], y: ptr[PyObject]) -> i32 {
        return i32(1) if x == y else i32(0);
    }  def Py_IsNone(x: ptr[PyObject]) -> i32 {
        return i32(1) if x == py_none() else i32(0);
    }  def Py_IsTrue(x: ptr[PyObject]) -> i32 {
        return i32(1) if x == py_true() else i32(0);
    }  def Py_IsFalse(x: ptr[PyObject]) -> i32 {
        return i32(1) if x == py_false() else i32(0);
    }  def Py_TYPE(ob: ptr[PyObject]) -> ptr[PyTypeObject] {
        return object_type(ob);
    }  def Py_REFCNT(ob: ptr[PyObject]) -> i64 {
        return object_refcount(ob);
    }  def PyObject_GET_WEAKREFS_LISTPTR(op: ptr[PyObject]) -> ptr[ptr[PyObject]] {
        if type_check(op)
            and type_has_feature(ptr[PyTypeObject](op), _Py_TPFLAGS_STATIC_BUILTIN) {
            state = _PyStaticType_GetState(current_interp(), ptr[PyTypeObject](op));
            return ptr[ptr[PyObject]](state + managed_static_type_state_TP_WEAKLIST);
        }
        return ptr[ptr[PyObject]](
            ptr[u8](op) + object_type(op).view(1)[0].tp_weaklistoffset
        );
    }
}

def delete_later_slot(tstate: ptr[u8]) -> ptr[i64];

import from c {
    def _PyTrash_thread_deposit_object(tstate: ptr[u8], op: ptr[PyObject]) {
        tp = object_type(op);
        tracked: i64 = 0;
        if int(tp.view(1)[0].tp_is_gc) == 0 or tp.view(1)[0].tp_is_gc(op) != 0 {
            if object_gc_is_tracked(op) {
                tracked = 1;
                gc_untrack_in(interp_of(tstate), op);
            }
        }
        slot = delete_later_slot(tstate);
        ptr[i64](gc_head(op)).view(1)[0] = slot.view(1)[0] | tracked;
        slot.view(1)[0] = int(op);
    }  def _PyTrash_thread_destroy_chain(tstate: ptr[u8]) {
        slot = delete_later_slot(tstate);
        while slot.view(1)[0] != 0 {
            op = ptr[PyObject](slot.view(1)[0]);
            next_word = ptr[i64](gc_head(op));
            tagged = next_word.view(1)[0];
            next_word.view(1)[0] = 0;
            slot.view(1)[0] = tagged & ~i64(1);
            if (tagged & 1) != 0 {
                gc_track_in(interp_of(tstate), op);
            }
            object_type(op).view(1)[0].tp_dealloc(op);
        }
    }
}

def free_object(item: ptr);

def clear_freelist(freelists: ptr[u8], offset: i64, is_finalization: bool, how: i64);

import from c {
    def _PyObject_ClearFreeLists(freelists: ptr[u8], is_finalization: i32) {
        finalizing = is_finalization != 0;
        clear_freelist(freelists, _Py_freelists_FLOATS, finalizing, FREE_OBJECT);
        for i in range(PyTuple_MAXSAVESIZE) {
            clear_freelist(
                freelists,
                _Py_freelists_TUPLES + i * _Py_freelist_SIZE,
                finalizing,
                FREE_OBJECT
            );
        }
        clear_freelist(freelists, _Py_freelists_LISTS, finalizing, FREE_OBJECT);
        clear_freelist(freelists, _Py_freelists_LIST_ITERS, finalizing, FREE_OBJECT);
        clear_freelist(freelists, _Py_freelists_TUPLE_ITERS, finalizing, FREE_OBJECT);
        clear_freelist(freelists, _Py_freelists_DICTS, finalizing, FREE_OBJECT);
        clear_freelist(freelists, _Py_freelists_DICTKEYS, finalizing, FREE_MEM);
        clear_freelist(freelists, _Py_freelists_SLICES, finalizing, FREE_OBJECT);
        clear_freelist(freelists, _Py_freelists_RANGES, finalizing, FREE_OBJECT);
        clear_freelist(freelists, _Py_freelists_RANGE_ITERS, finalizing, FREE_OBJECT);
        clear_freelist(freelists, _Py_freelists_CONTEXTS, finalizing, FREE_OBJECT);
        clear_freelist(freelists, _Py_freelists_ASYNC_GENS, finalizing, FREE_OBJECT);
        clear_freelist(
            freelists, _Py_freelists_ASYNC_GEN_ASENDS, finalizing, FREE_OBJECT
        );
        clear_freelist(freelists, _Py_freelists_FUTUREITERS, finalizing, FREE_OBJECT);
        if finalizing {
            clear_freelist(
                freelists, _Py_freelists_OBJECT_STACK_CHUNKS, True, FREE_RAW_MEM
            );
        }
        clear_freelist(freelists, _Py_freelists_UNICODE_WRITERS, finalizing, FREE_MEM);
        clear_freelist(freelists, _Py_freelists_INTS, finalizing, FREE_OBJECT);
        clear_freelist(freelists, _Py_freelists_PYCFUNCTIONOBJECT, finalizing, FREE_GC);
        clear_freelist(freelists, _Py_freelists_PYCMETHODOBJECT, finalizing, FREE_GC);
        clear_freelist(
            freelists, _Py_freelists_PYMETHODOBJECTS, finalizing, FREE_OBJECT
        );
    }  def _PyObject_DebugTypeStats(out: ptr) {
        _PyDict_DebugMallocStats(out);
        _PyFloat_DebugMallocStats(out);
        _PyList_DebugMallocStats(out);
        _PyTuple_DebugMallocStats(out);
    }
}

def is_ptr_freed(address: u64) -> bool;

def stderr_stream -> ptr;

import from c {
    def _PyObject_CheckConsistency(op: ptr[PyObject], check_content: i32) -> i32 {
        if _PyObject_IsFreed(op) != 0 {
            assert_failed(
                op,
                ptr[u8]("!_PyObject_IsFreed(op)"),
                i32(53),
                ptr[u8]("_PyObject_CheckConsistency")
            );
        }
        if object_refcount(op) < 1 {
            assert_failed(
                op,
                ptr[u8]("Py_REFCNT(op) >= 1"),
                i32(54),
                ptr[u8]("_PyObject_CheckConsistency")
            );
        }
        _PyType_CheckConsistency(object_type(op));
        if unicode_check(op) {
            _PyUnicode_CheckConsistency(op, check_content);
        } elif dict_check(op) {
            _PyDict_CheckConsistency(op, check_content);
        }
        return i32(1);
    }  def PyObject_Print(op: ptr[PyObject], fp: ptr, flags: i32) -> i32 {
        ret = i32(0);
        write_error = False;
        if PyErr_CheckSignals() != 0 {
            return i32(-1);
        }
        if Py_EnterRecursiveCall(ptr[u8](" printing an object")) != 0 {
            return i32(-1);
        }

        clearerr(fp);
        if not op {
            saved = PyEval_SaveThread();
            fprintf(fp, "<nil>");
            PyEval_RestoreThread(saved);
        } elif object_refcount(op) <= 0 {
            saved = PyEval_SaveThread();
            fprintf(fp, "<refcnt %zd at %p>", object_refcount(op), op);
            PyEval_RestoreThread(saved);
        } else {
            s = PyObject_Str(op) if (flags & Py_PRINT_RAW) != 0 else PyObject_Repr(op);
            if not s {
                ret = i32(-1);
            } else {
                length: i64 = 0;
                t = PyUnicode_AsUTF8AndSize(s, &mut length);
                if not t {
                    ret = i32(-1);
                } elif fwrite(ptr(t), u64(1), u64(length), fp) != u64(length) {
                    write_error = True;
                }
                object_decref(s);
            }
        }
        if ret == 0 and (write_error or ferror(fp) != 0) {
            PyErr_SetFromErrno(PyExc_OSError);
            clearerr(fp);
            ret = i32(-1);
        }
        return ret;
    }  def _Py_BreakPoint {}  def _PyObject_IsFreed(op: ptr[PyObject]) -> i32 {
        if is_ptr_freed(u64.wrap(int(op)))
            or is_ptr_freed(u64.wrap(int(object_type(op)))) {
            return i32(1);
        }
        return i32(0);
    }  def _PyObject_Dump(op: ptr[PyObject]) {
        err = stderr_stream();
        if _PyObject_IsFreed(op) != 0 {
            fprintf(err, "<object at %p is freed>\n", op);
            fflush(err);
            return;
        }

        fprintf(err, "object address  : %p\n", op);
        fprintf(err, "object refcount : %zd\n", object_refcount(op));
        fflush(err);
        tp = object_type(op);
        fprintf(err, "object type     : %p\n", tp);
        fprintf(
            err,
            "object type name: %s\n",
            ptr[u8]("NULL") if not tp else tp.view(1)[0].tp_name
        );

        fprintf(err, "object repr     : ");
        fflush(err);
        gil = PyGILState_Ensure();
        exc = PyErr_GetRaisedException();
        PyObject_Print(op, err, i32(0));
        fflush(err);
        PyErr_SetRaisedException(exc);
        PyGILState_Release(gil);
        fprintf(err, "\n");
        fflush(err);
    }  def _PyObject_AssertFailed(
        op: ptr[PyObject],
        expr: ptr[u8],
        msg: ptr[u8],
        file: ptr[u8],
        line: i32,
        function: ptr[u8]
    ) {
        err = stderr_stream();
        fprintf(err, "%s:%d: ", file, line);
        if function {
            fprintf(err, "%s: ", function);
        }
        fflush(err);
        if expr {
            fprintf(err, "Assertion \"%s\" failed", expr);
        } else {
            fprintf(err, "Assertion failed");
        }
        fflush(err);
        if msg {
            fprintf(err, ": %s", msg);
        }
        fprintf(err, "\n");
        fflush(err);
        if _PyObject_IsFreed(op) != 0 {
            fprintf(err, "<object at %p is freed>\n", op);
            fflush(err);
        } else {
            tp = object_type(op);
            presize = (
                PyGC_Head_SIZE if type_has_feature(tp, Py_TPFLAGS_HAVE_GC) else 0
            )
                + (16 if type_has_feature(tp, TPFLAGS_PREHEADER) else 0);
            _PyMem_DumpTraceback(i32(2), ptr(ptr[u8](op) - presize));
            _PyObject_Dump(op);
            fprintf(err, "\n");
            fflush(err);
        }
        Py_FatalError(ptr[u8]("_PyObject_AssertFailed"));
    }
}

import from c {
    def PyObject_Repr(v: ptr[PyObject]) -> ptr[PyObject] {
        if PyErr_CheckSignals() != 0 {
            return NULL;
        }
        if not v {
            return PyUnicode_FromString(ptr[u8]("<NULL>"));
        }
        tp = object_type(v);
        if int(tp.view(1)[0].tp_repr) == 0 {
            return PyUnicode_FromFormat("<%s object at %p>", tp.view(1)[0].tp_name, v);
        }

        if Py_EnterRecursiveCall(ptr[u8](" while getting the repr of an object"))
            != 0 {
            return NULL;
        }
        res = tp.view(1)[0].tp_repr(v);
        if not res {
            return NULL;
        }
        if not unicode_check(res) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("__repr__ returned non-string (type %.200s)"),
                object_type(res).view(1)[0].tp_name
            );
            object_decref(res);
            return NULL;
        }
        return res;
    }  def PyObject_Str(v: ptr[PyObject]) -> ptr[PyObject] {
        if PyErr_CheckSignals() != 0 {
            return NULL;
        }
        if not v {
            return PyUnicode_FromString(ptr[u8]("<NULL>"));
        }
        if unicode_check_exact(v) {
            return object_new_ref(v);
        }
        tp = object_type(v);
        if int(tp.view(1)[0].tp_str) == 0 {
            return PyObject_Repr(v);
        }

        if Py_EnterRecursiveCall(ptr[u8](" while getting the str of an object")) != 0 {
            return NULL;
        }
        res = tp.view(1)[0].tp_str(v);
        if not res {
            return NULL;
        }
        if not unicode_check(res) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("__str__ returned non-string (type %.200s)"),
                object_type(res).view(1)[0].tp_name
            );
            object_decref(res);
            return NULL;
        }
        return res;
    }  def PyObject_ASCII(v: ptr[PyObject]) -> ptr[PyObject] {
        repr_obj = PyObject_Repr(v);
        if not repr_obj {
            return NULL;
        }
        if jacpy_unicode_ascii(repr_obj) != 0 {
            return repr_obj;
        }

        ascii_bytes = _PyUnicode_AsASCIIString(repr_obj, ptr[u8]("backslashreplace"));
        object_decref(repr_obj);
        if not ascii_bytes {
            return NULL;
        }
        res = PyUnicode_DecodeASCII(
            ptr(ptr[u8](ascii_bytes) + PyBytesObject_OB_SVAL),
            object_size(ascii_bytes),
            ptr[u8]()
        );
        object_decref(ascii_bytes);
        return res;
    }  def PyObject_Bytes(v: ptr[PyObject]) -> ptr[PyObject] {
        if not v {
            return PyBytes_FromString(ptr[u8]("<NULL>"));
        }
        if object_is_type(v, addressof(PyBytes_Type)) {
            return object_new_ref(v);
        }
        key = interned_id(ID_BYTES);
        if not key {
            return NULL;
        }
        func = _PyObject_LookupSpecial(v, key);
        if func {
            result = PyObject_CallNoArgs(func);
            object_decref(func);
            if not result {
                return NULL;
            }
            if not bytes_check(result) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("__bytes__ returned non-bytes (type %.200s)"),
                    object_type(result).view(1)[0].tp_name
                );
                object_decref(result);
                return NULL;
            }
            return result;
        }
        if PyErr_Occurred() {
            return NULL;
        }
        return PyBytes_FromObject(v);
    }  def _PyObject_FunctionStr(x: ptr[PyObject]) -> ptr[PyObject] {
        qualname_key = interned_id(ID_QUALNAME);
        module_key = interned_id(ID_MODULE);
        builtins_key = interned_id(ID_BUILTINS);
        if not qualname_key or not module_key or not builtins_key {
            return NULL;
        }
        (ret, qualname) = optional_attr(x, qualname_key);
        if not qualname {
            if ret < 0 {
                return NULL;
            }
            return PyObject_Str(x);
        }
        result = NULL;
        (mret, module) = optional_attr(x, module_key);
        if module and module != py_none() {
            cmp = PyObject_RichCompareBool(module, builtins_key, Py_NE);
            if cmp > 0 {
                result = PyUnicode_FromFormat("%S.%S()", module, qualname);
            } elif cmp == 0 {
                result = PyUnicode_FromFormat("%S()", qualname);
            }
        } elif mret >= 0 {
            result = PyUnicode_FromFormat("%S()", qualname);
        }
        object_decref(qualname);
        object_xdecref(module);
        return result;
    }
}

def swapped_op(op: i32) -> i32;

def op_string(op: i32) -> ptr[u8];

def do_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject];

import from c {
    def PyObject_RichCompare(
        v: ptr[PyObject], w: ptr[PyObject], op: i32
    ) -> ptr[PyObject] {
        if not v or not w {
            if not PyErr_Occurred() {
                PyErr_BadInternalCall();
            }
            return NULL;
        }
        if Py_EnterRecursiveCall(ptr[u8](" in comparison")) != 0 {
            return NULL;
        }
        return do_richcompare(v, w, op);
    }  def PyObject_RichCompareBool(
        v: ptr[PyObject], w: ptr[PyObject], op: i32
    ) -> i32 {
        if v == w {
            if op == Py_EQ {
                return i32(1);
            }
            if op == Py_NE {
                return i32(0);
            }
        }
        res = PyObject_RichCompare(v, w, op);
        if not res {
            return i32(-1);
        }
        ok = i32(0);
        if object_is_type(res, addressof(PyBool_Type)) {
            ok = i32(1) if res == py_true() else i32(0);
        } else {
            ok = PyObject_IsTrue(res);
        }
        object_decref(res);
        return ok;
    }  def PyObject_HashNotImplemented(v: ptr[PyObject]) -> i64 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("unhashable type: '%.200s'"),
            object_type(v).view(1)[0].tp_name
        );
        return -1;
    }  def PyObject_Hash(v: ptr[PyObject]) -> i64 {
        tp = object_type(v);
        if int(tp.view(1)[0].tp_hash) != 0 {
            return tp.view(1)[0].tp_hash(v);
        }

        if not type_is_ready(tp) {
            if PyType_Ready(ptr[PyObject](tp)) < 0 {
                return -1;
            }
            if int(tp.view(1)[0].tp_hash) != 0 {
                return tp.view(1)[0].tp_hash(v);
            }
        }

        return PyObject_HashNotImplemented(v);
    }  def PyObject_IsTrue(v: ptr[PyObject]) -> i32 {
        if v == py_true() {
            return i32(1);
        }
        if v == py_false() or v == py_none() {
            return i32(0);
        }
        tp = object_type(v);
        res: i64 = 0;
        nb = tp.view(1)[0].tp_as_number;
        if nb and int(nb.view(1)[0].nb_bool) != 0 {
            res = i64(nb.view(1)[0].nb_bool(v));
        } else {
            mp = tp.view(1)[0].tp_as_mapping;
            if mp and int(mp.view(1)[0].mp_length) != 0 {
                res = mp.view(1)[0].mp_length(v);
            } else {
                sq = tp.view(1)[0].tp_as_sequence;
                if not sq or int(sq.view(1)[0].sq_length) == 0 {
                    return i32(1);
                }
                res = sq.view(1)[0].sq_length(v);
            }
        }

        return i32(1) if res > 0 else i32.wrap(res);
    }  def PyObject_Not(v: ptr[PyObject]) -> i32 {
        res = PyObject_IsTrue(v);
        if res < 0 {
            return res;
        }
        return i32(1) if res == 0 else i32(0);
    }  def PyCallable_Check(x: ptr[PyObject]) -> i32 {
        if not x {
            return i32(0);
        }
        return i32(1) if int(object_type(x).view(1)[0].tp_call) != 0 else i32(0);
    }
}

import from c {
    def Py_ReprEnter(ob: ptr[PyObject]) -> i32 {
        dict = PyThreadState_GetDict();
        if not dict {
            return i32(0);
        }
        key = interned_id(ID_PY_REPR);
        if not key {
            return i32(-1);
        }
        repr_list = PyDict_GetItemWithError(dict, key);
        if not repr_list {
            if PyErr_Occurred() {
                return i32(-1);
            }
            repr_list = PyList_New(0);
            if not repr_list {
                return i32(-1);
            }
            if PyDict_SetItem(dict, key, repr_list) < 0 {
                return i32(-1);
            }
            object_decref(repr_list);
        }
        items = ptr[PyListObject](repr_list).view(1)[0].ob_item;
        i = object_size(repr_list);
        while i > 0 {
            i -= 1;
            if (items + i).view(1)[0] == ob {
                return i32(1);
            }
        }
        if PyList_Append(repr_list, ob) < 0 {
            return i32(-1);
        }
        return i32(0);
    }  def Py_ReprLeave(ob: ptr[PyObject]) {
        exc = PyErr_GetRaisedException();
        dict = PyThreadState_GetDict();
        key = interned_id(ID_PY_REPR);
        if dict and key {
            repr_list = PyDict_GetItemWithError(dict, key);
            if repr_list and list_check(repr_list) {
                items = ptr[PyListObject](repr_list).view(1)[0].ob_item;
                i = object_size(repr_list);

                while i > 0 {
                    i -= 1;
                    if (items + i).view(1)[0] == ob {
                        PyList_SetSlice(repr_list, i, i + 1, NULL);
                        break;
                    }
                }
            }
        }
        PyErr_SetRaisedException(exc);
    }
}

def optional_attr(v: ptr[PyObject], name: ptr[PyObject]) -> tuple[i32, ptr[PyObject]];

def optional_attr_string(
    ob: ptr[PyObject], name: ptr[u8]
) -> tuple[i32, ptr[PyObject]];

import from c {
    def PyObject_GetAttrString(v: ptr[PyObject], name: ptr[u8]) -> ptr[PyObject] {
        tp = object_type(v);
        if int(tp.view(1)[0].tp_getattr) != 0 {
            return tp.view(1)[0].tp_getattr(v, name);
        }
        w = PyUnicode_FromString(name);
        if not w {
            return NULL;
        }
        res = PyObject_GetAttr(v, w);
        object_decref(w);
        return res;
    }  def PyObject_HasAttrStringWithError(ob: ptr[PyObject], name: ptr[u8]) -> i32 {
        (rc, res) = optional_attr_string(ob, name);
        object_xdecref(res);
        return rc;
    }  def PyObject_HasAttrString(ob: ptr[PyObject], name: ptr[u8]) -> i32 {
        rc = PyObject_HasAttrStringWithError(ob, name);
        if rc < 0 {
            PyErr_FormatUnraisable(
                ptr[u8](
                    "Exception ignored in PyObject_HasAttrString(); consider using PyObject_HasAttrStringWithError(), PyObject_GetOptionalAttrString() or PyObject_GetAttrString()"
                )
            );
            return i32(0);
        }
        return rc;
    }  def PyObject_SetAttrString(
        v: ptr[PyObject], name: ptr[u8], w: ptr[PyObject]
    ) -> i32 {
        tp = object_type(v);
        if int(tp.view(1)[0].tp_setattr) != 0 {
            return tp.view(1)[0].tp_setattr(v, name, w);
        }
        s = PyUnicode_InternFromString(name);
        if not s {
            return i32(-1);
        }
        res = PyObject_SetAttr(v, s, w);
        object_xdecref(s);
        return res;
    }  def PyObject_DelAttrString(v: ptr[PyObject], name: ptr[u8]) -> i32 {
        return PyObject_SetAttrString(v, name, NULL);
    }  def _PyObject_IsAbstract(ob: ptr[PyObject]) -> i32 {
        if not ob {
            return i32(0);
        }
        key = interned_id(ID_ISABSTRACTMETHOD);
        if not key {
            return i32(-1);
        }
        (res, isabstract) = optional_attr(ob, key);
        if res > 0 {
            res = PyObject_IsTrue(isabstract);
            object_decref(isabstract);
        }
        return res;
    }  def _PyObject_GetAttrId(v: ptr[PyObject], name: ptr) -> ptr[PyObject] {
        oname = _PyUnicode_FromId(name);
        if not oname {
            return NULL;
        }
        return PyObject_GetAttr(v, oname);
    }  def _PyObject_SetAttributeErrorContext(
        v: ptr[PyObject], name: ptr[PyObject]
    ) -> i32 {
        if not attribute_error_pending() {
            return i32(0);
        }
        exc = PyErr_GetRaisedException();
        if PyErr_GivenExceptionMatches(exc, PyExc_AttributeError) != 0 {
            fields = ptr[u8](exc);
            exc_name = ptr[ptr[PyObject]](fields + PyAttributeErrorObject_NAME).view(1)[
                0
            ];
            exc_obj = ptr[ptr[PyObject]](fields + PyAttributeErrorObject_OBJ).view(1)[
                0
            ];

            if not exc_name and not exc_obj {
                name_key = interned_id(ID_NAME);
                obj_key = interned_id(ID_OBJ);
                if not name_key
                    or not obj_key
                    or PyObject_SetAttr(exc, name_key, name) != 0
                    or PyObject_SetAttr(exc, obj_key, v) != 0 {
                    return i32(1);
                }
            }
        }
        PyErr_SetRaisedException(exc);
        return i32(0);
    }  def PyObject_GetAttr(v: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
        tp = object_type(v);
        if not unicode_check(name) {
            bad_attribute_name(name);
            return NULL;
        }
        result = NULL;
        if int(tp.view(1)[0].tp_getattro) != 0 {
            result = tp.view(1)[0].tp_getattro(v, name);
        } elif int(tp.view(1)[0].tp_getattr) != 0 {
            name_str = PyUnicode_AsUTF8(name);
            if not name_str {
                return NULL;
            }
            result = tp.view(1)[0].tp_getattr(v, name_str);
        } else {
            PyErr_Format(
                PyExc_AttributeError,
                ptr[u8]("'%.100s' object has no attribute '%U'"),
                tp.view(1)[0].tp_name,
                name
            );
        }
        if not result {
            _PyObject_SetAttributeErrorContext(v, name);
        }
        return result;
    }  def PyObject_GetOptionalAttr(
        v: ptr[PyObject], name: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32 {
        (rc, value) = optional_attr(v, name);
        result.view(1)[0] = value;
        return rc;
    }  def PyObject_GetOptionalAttrString(
        ob: ptr[PyObject], name: ptr[u8], result: ptr[ptr[PyObject]]
    ) -> i32 {
        (rc, value) = optional_attr_string(ob, name);
        result.view(1)[0] = value;
        return rc;
    }  def PyObject_HasAttrWithError(ob: ptr[PyObject], name: ptr[PyObject]) -> i32 {
        (rc, res) = optional_attr(ob, name);
        object_xdecref(res);
        return rc;
    }  def PyObject_HasAttr(ob: ptr[PyObject], name: ptr[PyObject]) -> i32 {
        rc = PyObject_HasAttrWithError(ob, name);
        if rc < 0 {
            PyErr_FormatUnraisable(
                ptr[u8](
                    "Exception ignored in PyObject_HasAttr(); consider using PyObject_HasAttrWithError(), PyObject_GetOptionalAttr() or PyObject_GetAttr()"
                )
            );
            return i32(0);
        }
        return rc;
    }  def PyObject_SetAttr(
        v: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
    ) -> i32 {
        tp = object_type(v);
        if not unicode_check(name) {
            bad_attribute_name(name);
            return i32(-1);
        }
        key = object_new_ref(name);
        _PyUnicode_InternMortal(current_interp(), &mut key);
        if int(tp.view(1)[0].tp_setattro) != 0 {
            err = tp.view(1)[0].tp_setattro(v, key, value);
            object_decref(key);
            return err;
        }
        if int(tp.view(1)[0].tp_setattr) != 0 {
            name_str = PyUnicode_AsUTF8(key);
            if not name_str {
                object_decref(key);
                return i32(-1);
            }
            err = tp.view(1)[0].tp_setattr(v, name_str, value);
            object_decref(key);
            return err;
        }
        object_decref(key);
        action = ptr[u8]("del") if not value else ptr[u8]("assign to");
        if int(tp.view(1)[0].tp_getattr) == 0 and int(tp.view(1)[0].tp_getattro) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("'%.100s' object has no attributes (%s .%U)"),
                tp.view(1)[0].tp_name,
                action,
                key
            );
        } else {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("'%.100s' object has only read-only attributes (%s .%U)"),
                tp.view(1)[0].tp_name,
                action,
                key
            );
        }
        return i32(-1);
    }  def PyObject_DelAttr(v: ptr[PyObject], name: ptr[PyObject]) -> i32 {
        return PyObject_SetAttr(v, name, NULL);
    }  def _PyObject_ComputedDictPointer(ob: ptr[PyObject]) -> ptr[ptr[PyObject]] {
        tp = object_type(ob);
        dictoffset = tp.view(1)[0].tp_dictoffset;
        if dictoffset == 0 {
            return ptr[ptr[PyObject]]();
        }
        if dictoffset < 0 {
            tsize = object_size(ob);
            if tsize < 0 {
                tsize = -tsize;
            }
            dictoffset += var_size(tp, tsize);
        }
        return ptr[ptr[PyObject]](ptr[u8](ob) + dictoffset);
    }  def _PyObject_GetDictPtr(ob: ptr[PyObject]) -> ptr[ptr[PyObject]] {
        tp = object_type(ob);
        if not type_has_feature(tp, Py_TPFLAGS_MANAGED_DICT) {
            return _PyObject_ComputedDictPointer(ob);
        }
        if not managed_dict(ob) and type_has_feature(tp, Py_TPFLAGS_INLINE_VALUES) {
            if not _PyObject_MaterializeManagedDict(ob) {
                PyErr_Clear();
                return ptr[ptr[PyObject]]();
            }
        }
        return managed_dict_slot(ob);
    }  def PyObject_SelfIter(ob: ptr[PyObject]) -> ptr[PyObject] {
        return object_new_ref(ob);
    }  def _PyObject_NextNotImplemented(op_self: ptr[PyObject]) -> ptr[PyObject] {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("'%.200s' object is not iterable"),
            object_type(op_self).view(1)[0].tp_name
        );
        return NULL;
    }
}

import from c {
    def _PyObject_GetMethod(
        ob: ptr[PyObject], name: ptr[PyObject], method: ptr[ptr[PyObject]]
    ) -> i32 {
        tp = object_type(ob);
        if not type_is_ready(tp) and PyType_Ready(ptr[PyObject](tp)) < 0 {
            return i32(0);
        }
        if int(tp.view(1)[0].tp_getattro) != int(ptr(PyObject_GenericGetAttr))
            or not unicode_check_exact(name) {
            method.view(1)[0] = PyObject_GetAttr(ob, name);
            return i32(0);
        }
        descr = _PyType_LookupRef(ptr[PyObject](tp), name);
        meth_found = False;
        has_get = False;
        if descr {
            dtype = object_type(descr);
            if type_has_feature(dtype, Py_TPFLAGS_METHOD_DESCRIPTOR) {
                meth_found = True;
            } else {
                has_get = int(dtype.view(1)[0].tp_descr_get) != 0;
                if has_get and int(dtype.view(1)[0].tp_descr_set) != 0 {
                    method.view(1)[0] = dtype.view(1)[0].tp_descr_get(
                        descr, ob, ptr[PyObject](tp)
                    );
                    object_decref(descr);
                    return i32(0);
                }
            }
        }
        flags = tp.view(1)[0].tp_flags;
        dict = NULL;
        attr = NULL;
        if (flags & Py_TPFLAGS_INLINE_VALUES) != u64(0)
            and _PyObject_TryGetInstanceAttribute(ob, name, &mut attr) {
            if attr {
                method.view(1)[0] = attr;
                object_xdecref(descr);
                return i32(0);
            }
        } elif (flags & Py_TPFLAGS_MANAGED_DICT) != u64(0) {
            dict = managed_dict(ob);
        } else {
            dictptr = _PyObject_ComputedDictPointer(ob);
            if dictptr {
                dict = dictptr.view(1)[0];
            }
        }
        if dict {
            object_incref(dict);
            if PyDict_GetItemRef(dict, name, &mut attr) != 0 {
                method.view(1)[0] = attr;
                object_decref(dict);
                object_xdecref(descr);
                return i32(0);
            }
            object_decref(dict);
        }
        if meth_found {
            method.view(1)[0] = descr;
            return i32(1);
        }
        if has_get {
            method.view(1)[0] = object_type(descr).view(1)[0].tp_descr_get(
                descr, ob, ptr[PyObject](tp)
            );
            object_decref(descr);
            return i32(0);
        }
        if descr {
            method.view(1)[0] = descr;
            return i32(0);
        }
        no_attribute(ob, tp, name);
        return i32(0);
    }  def _PyObject_GetMethodStackRef(
        ts: ptr, self_ref: ptr[u64], name: ptr[PyObject], method: ptr[u64]
    ) -> i32 {
        ob = stackref_borrow(self_ref.view(1)[0]);
        tp = object_type(ob);
        if not type_is_ready(tp) and PyType_Ready(ptr[PyObject](tp)) < 0 {
            stackref_clear(self_ref);
            return i32(-1);
        }
        if int(tp.view(1)[0].tp_getattro) != int(ptr(PyObject_GenericGetAttr))
            or not unicode_check_exact(name) {
            res = PyObject_GetAttr(ob, name);
            stackref_clear(self_ref);
            if res {
                method.view(1)[0] = stackref_steal(res);
                return i32(0);
            }
            return i32(-1);
        }
        found: u64 = STACKREF_NULL;
        _PyType_LookupStackRefAndVersion(tp, name, &mut found);
        method.view(1)[0] = found;
        descr = stackref_borrow(found);
        meth_found = False;
        has_get = False;
        if descr {
            dtype = object_type(descr);
            if type_has_feature(dtype, Py_TPFLAGS_METHOD_DESCRIPTOR) {
                meth_found = True;
            } else {
                has_get = int(dtype.view(1)[0].tp_descr_get) != 0;
                if has_get and int(dtype.view(1)[0].tp_descr_set) != 0 {
                    value = dtype.view(1)[0].tp_descr_get(descr, ob, ptr[PyObject](tp));
                    stackref_clear(method);
                    stackref_clear(self_ref);
                    if value {
                        method.view(1)[0] = stackref_steal(value);
                        return i32(0);
                    }
                    return i32(-1);
                }
            }
        }
        flags = tp.view(1)[0].tp_flags;
        dict = NULL;
        attr = NULL;
        if (flags & Py_TPFLAGS_INLINE_VALUES) != u64(0)
            and _PyObject_TryGetInstanceAttribute(ob, name, &mut attr) {
            if attr {
                stackref_xsetref(method, stackref_steal(attr));
                stackref_clear(self_ref);
                return i32(0);
            }
        } elif (flags & Py_TPFLAGS_MANAGED_DICT) != u64(0) {
            dict = managed_dict(ob);
        } else {
            dictptr = _PyObject_ComputedDictPointer(ob);
            if dictptr {
                dict = dictptr.view(1)[0];
            }
        }
        if dict {
            in_dict = _PyDict_GetMethodStackRef(dict, name, method);
            if in_dict < 0 {
                stackref_clear(self_ref);
                return i32(-1);
            }
            if in_dict > 0 {
                stackref_clear(self_ref);
                return i32(0);
            }
        }
        if meth_found {
            return i32(1);
        }
        if has_get {
            if object_is_type(descr, addressof(PyClassMethod_Type)) {
                wrapped = ptr[classmethod](descr).view(1)[0].cm_callable;
                stackref_xsetref(method, stackref_new(wrapped));
                stackref_xsetref(self_ref, stackref_new(ptr[PyObject](tp)));
                return i32(1);
            }
            if object_is_type(descr, addressof(PyStaticMethod_Type)) {
                wrapped = ptr[staticmethod](descr).view(1)[0].sm_callable;
                stackref_xsetref(method, stackref_new(wrapped));
                stackref_clear(self_ref);
                return i32(0);
            }
            value = object_type(descr).view(1)[0].tp_descr_get(
                descr, ob, ptr[PyObject](tp)
            );
            stackref_clear(method);
            stackref_clear(self_ref);
            if value {
                method.view(1)[0] = stackref_steal(value);
                return i32(0);
            }
            return i32(-1);
        }
        if descr {
            stackref_clear(self_ref);
            return i32(0);
        }
        no_attribute(ob, tp, name);
        stackref_clear(self_ref);
        return i32(-1);
    }
}

import from c {
    def _PyObject_GenericGetAttrWithDict(
        ob: ptr[PyObject], name: ptr[PyObject], dict_arg: ptr[PyObject], suppress: i32
    ) -> ptr[PyObject] {
        tp = object_type(ob);
        if not unicode_check(name) {
            bad_attribute_name(name);
            return NULL;
        }
        if not type_is_ready(tp) and PyType_Ready(ptr[PyObject](tp)) < 0 {
            return NULL;
        }
        object_incref(name);

        descr_ref: u64 = STACKREF_NULL;
        _PyType_LookupStackRefAndVersion(tp, name, &mut descr_ref);
        descr = stackref_borrow(descr_ref);
        res = NULL;
        done = False;
        has_get = False;
        if descr {
            dtype = object_type(descr);
            has_get = int(dtype.view(1)[0].tp_descr_get) != 0;
            if has_get and int(dtype.view(1)[0].tp_descr_set) != 0 {
                res = dtype.view(1)[0].tp_descr_get(descr, ob, ptr[PyObject](tp));
                if not res and suppress != 0 and attribute_error_pending() {
                    PyErr_Clear();
                }
                done = True;
            }
        }
        dict = dict_arg;
        if not done and not dict {
            flags = tp.view(1)[0].tp_flags;
            if (flags & Py_TPFLAGS_INLINE_VALUES) != u64(0) {
                if unicode_check_exact(name)
                    and _PyObject_TryGetInstanceAttribute(ob, name, &mut res) {
                    if res {
                        done = True;
                    }
                } else {
                    dict = _PyObject_MaterializeManagedDict(ob);
                    if not dict {
                        done = True;
                    }
                }
            } elif (flags & Py_TPFLAGS_MANAGED_DICT) != u64(0) {
                dict = managed_dict(ob);
            } else {
                dictptr = _PyObject_ComputedDictPointer(ob);
                if dictptr {
                    dict = dictptr.view(1)[0];
                }
            }
        }
        if not done and dict {
            object_incref(dict);
            rc = PyDict_GetItemRef(dict, name, &mut res);
            object_decref(dict);
            if res {
                done = True;
            } elif rc < 0 {
                if suppress != 0 and attribute_error_pending() {
                    PyErr_Clear();
                } else {
                    done = True;
                }
            }
        }
        if not done {
            if has_get {
                res = object_type(descr).view(1)[0].tp_descr_get(
                    descr, ob, ptr[PyObject](tp)
                );
                if not res and suppress != 0 and attribute_error_pending() {
                    PyErr_Clear();
                }
            } elif descr {
                res = stackref_as_object_steal(descr_ref);
                descr_ref = STACKREF_NULL;
            } elif suppress == 0 {
                no_attribute(ob, tp, name);
            }
        }
        stackref_close(descr_ref);
        object_decref(name);
        return res;
    }  def PyObject_GenericGetAttr(
        ob: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        return _PyObject_GenericGetAttrWithDict(ob, name, NULL, i32(0));
    }  def _PyObject_GenericSetAttrWithDict(
        ob: ptr[PyObject],
        name: ptr[PyObject],
        value: ptr[PyObject],
        dict_arg: ptr[PyObject]
    ) -> i32 {
        tp = object_type(ob);
        if not unicode_check(name) {
            bad_attribute_name(name);
            return i32(-1);
        }
        if not type_is_ready(tp) and PyType_Ready(ptr[PyObject](tp)) < 0 {
            return i32(-1);
        }
        object_incref(name);
        object_incref(ptr[PyObject](tp));
        descr_ref: u64 = STACKREF_NULL;
        _PyType_LookupStackRefAndVersion(tp, name, &mut descr_ref);
        descr = stackref_borrow(descr_ref);
        res = i32(-1);

        done = False;
        if descr and int(object_type(descr).view(1)[0].tp_descr_set) != 0 {
            res = object_type(descr).view(1)[0].tp_descr_set(descr, ob, value);
            done = True;
        } elif dict_arg {
            object_incref(dict_arg);
            if not value {
                res = PyDict_DelItem(dict_arg, name);
            } else {
                res = PyDict_SetItem(dict_arg, name, value);
            }
            object_decref(dict_arg);
        } else {
            flags = tp.view(1)[0].tp_flags;
            if (flags & Py_TPFLAGS_INLINE_VALUES) != u64(0) {
                res = _PyObject_StoreInstanceAttribute(ob, name, value);
            } else {
                dictptr = ptr[ptr[PyObject]]();
                if (flags & Py_TPFLAGS_MANAGED_DICT) != u64(0) {
                    dictptr = managed_dict_slot(ob);
                } else {
                    dictptr = _PyObject_ComputedDictPointer(ob);
                }
                if not dictptr {
                    if not descr {
                        if int(tp.view(1)[0].tp_setattro)
                            == int(ptr(PyObject_GenericSetAttr)) {
                            PyErr_Format(
                                PyExc_AttributeError,
                                ptr[u8](
                                    "'%.100s' object has no attribute '%U' and no __dict__ for setting new attributes"
                                ),
                                tp.view(1)[0].tp_name,
                                name
                            );
                        } else {
                            PyErr_Format(
                                PyExc_AttributeError,
                                ptr[u8]("'%.100s' object has no attribute '%U'"),
                                tp.view(1)[0].tp_name,
                                name
                            );
                        }
                        _PyObject_SetAttributeErrorContext(ob, name);
                    } else {
                        PyErr_Format(
                            PyExc_AttributeError,
                            ptr[u8]("'%.100s' object attribute '%U' is read-only"),
                            tp.view(1)[0].tp_name,
                            name
                        );
                    }
                    done = True;
                } else {
                    res = _PyObjectDict_SetItem(tp, ob, dictptr, name, value);
                }
            }
        }
        if not done and res < 0 and PyErr_ExceptionMatches(PyExc_KeyError) != 0 {
            no_attribute(ob, tp, name);
        }
        stackref_close(descr_ref);
        object_decref(ptr[PyObject](tp));
        object_decref(name);
        return res;
    }  def PyObject_GenericSetAttr(
        ob: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
    ) -> i32 {
        return _PyObject_GenericSetAttrWithDict(ob, name, value, NULL);
    }  def PyObject_GenericSetDict(
        ob: ptr[PyObject], value: ptr[PyObject], context: ptr
    ) -> i32 {
        if not value {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("cannot delete __dict__"));
            return i32(-1);
        }
        return _PyObject_SetDict(ob, value);
    }
}

def dir_locals -> ptr[PyObject];

def dir_object(ob: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def PyObject_Dir(ob: ptr[PyObject]) -> ptr[PyObject] {
        return dir_locals() if not ob else dir_object(ob);
    }
}

def none_repr(op: ptr[PyObject]) -> ptr[PyObject];

def none_dealloc(none_obj: ptr[PyObject]);

def has_arguments(args: ptr[PyObject], kwargs: ptr[PyObject]) -> bool;

def none_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def none_bool(v: ptr[PyObject]) -> i32;

def none_hash(v: ptr[PyObject]) -> i64;

def NotImplemented_repr(op: ptr[PyObject]) -> ptr[PyObject];

def NotImplemented_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def notimplemented_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def notimplemented_dealloc(notimplemented: ptr[PyObject]);

def notimplemented_bool(v: ptr[PyObject]) -> i32;

def static_type(index: i64) -> ptr[PyTypeObject];

def constant_slot(index: i64) -> ptr[ptr[PyObject]];

import from c {
    def _PyObject_InitState(interp: ptr) -> PyStatus {
        return status_ok();
    }  def _PyObject_FiniState(interp: ptr) -> None {
        return;
    }  def _PyTypes_InitTypes(interp: ptr) -> PyStatus {
        for i in range(N_STATIC_TYPES) {
            if _PyStaticType_InitBuiltin(interp, static_type(i)) < 0 {
                return status_err(
                    ptr[u8]("_PyTypes_InitTypes"),
                    ptr[u8]("Can't initialize builtin type")
                );
            }
        }

        key = interned_id(ID_REDUCE);
        baseobj_dict = _PyType_GetDict(ptr[PyObject](addressof(PyBaseObject_Type)));
        baseobj_reduce = PyDict_GetItemWithError(baseobj_dict, key) if key else NULL;
        if not baseobj_reduce and PyErr_Occurred() {
            return status_err(
                ptr[u8]("_PyTypes_InitTypes"),
                ptr[u8]("Can't get __reduce__ from base object")
            );
        }
        ptr[ptr[PyObject]](ptr[u8](interp) + PyInterpreterState_CACHED_OBJREDUCE).view(
            1
        )[0] = baseobj_reduce;

        if _Py_initialize_generic(interp) < 0 {
            return status_err(
                ptr[u8]("_PyTypes_InitTypes"), ptr[u8]("Can't initialize generic types")
            );
        }
        return status_ok();
    }  def _PyTypes_FiniTypes(interp: ptr) {
        i = N_STATIC_TYPES;
        while i > 0 {
            i -= 1;
            _PyStaticType_FiniBuiltin(interp, static_type(i));
        }
    }  def _Py_GetConstant_Init {
        small_ints = int(addressof(_PyRuntime)) + _PyRuntimeState_SMALL_INTS;
        constant_slot(CONSTANT_ZERO).view(1)[0] = ptr[PyObject](
            small_ints + NSMALLNEGINTS * PyLongObject_SIZE
        );
        constant_slot(CONSTANT_ONE).view(1)[0] = ptr[PyObject](
            small_ints + (NSMALLNEGINTS + 1) * PyLongObject_SIZE
        );
        constant_slot(CONSTANT_EMPTY_STR).view(1)[0] = PyUnicode_New(0, u32(0));
        constant_slot(CONSTANT_EMPTY_BYTES).view(1)[0] = PyBytes_FromStringAndSize(
            ptr[u8](), 0
        );
        constant_slot(CONSTANT_EMPTY_TUPLE).view(1)[0] = PyTuple_New(0);
    }  def Py_GetConstant(constant_id: u32) -> ptr[PyObject] {
        if constant_id < N_CONSTANTS {
            return constant_slot(i64(constant_id)).view(1)[0];
        }
        PyErr_BadInternalCall();
        return NULL;
    }  def Py_GetConstantBorrowed(constant_id: u32) -> ptr[PyObject] {
        return Py_GetConstant(constant_id);
    }
}

impl py_none -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_NoneStruct));
}

impl py_not_implemented -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_NotImplementedStruct));
}

impl py_true -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct));
}

impl py_false -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_FalseStruct));
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl unicode_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyUnicode_Type));
}

impl type_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TYPE_SUBCLASS);
}

impl list_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LIST_SUBCLASS);
}

impl dict_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}

impl bytes_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BYTES_SUBCLASS);
}

impl dict_used(op: ptr[PyObject]) -> i64 {
    return ptr[PyDictObject](op).view(1)[0].ma_used;
}

impl type_is_ready(tp: ptr[PyTypeObject]) -> bool {
    return type_has_feature(tp, Py_TPFLAGS_READY)
        or _PyType_GetDict(ptr[PyObject](tp)) != NULL;
}

impl object_is_immortal(op: ptr[PyObject]) -> bool {
    return (ptr[_object](op).view(1)[0].ob_refcnt_full & 0x80000000) != 0;
}

impl set_refcnt(op: ptr[PyObject], refcnt: i64) {
    if object_is_immortal(op) {
        return;
    }
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    header.view(1)[0].ob_refcnt_full = (full & ~i64(0xFFFFFFFF))
        | (refcnt & 0xFFFFFFFF);
}

impl decref_mortal(op: ptr[PyObject]) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full - 1;
    header.view(1)[0].ob_refcnt_full = full;
    if (full & 0xFFFFFFFF) == 0 {
        _Py_Dealloc(op);
    }
}

impl stackref_borrow(bits: u64) -> ptr[PyObject] {
    return ptr[PyObject](i64.wrap(bits & u64(0xFFFFFFFFFFFFFFFE)));
}

impl stackref_new(op: ptr[PyObject]) -> u64 {
    if object_is_immortal(op) {
        return u64.wrap(int(op)) | u64(1);
    }
    object_incref(op);
    return u64.wrap(int(op));
}

impl stackref_steal(op: ptr[PyObject]) -> u64 {
    flags = u64.wrap(ptr[_object](op).view(1)[0].ob_refcnt_full) >> u64(48);
    return u64.wrap(int(op)) | (flags & u64(1));
}

impl stackref_as_object_steal(bits: u64) -> ptr[PyObject] {
    if (bits & u64(1)) == u64(0) {
        return ptr[PyObject](i64.wrap(bits));
    }
    return object_new_ref(stackref_borrow(bits));
}

impl stackref_close(bits: u64) {
    if (bits & u64(1)) == u64(0) {
        decref_mortal(ptr[PyObject](i64.wrap(bits)));
    }
}

impl stackref_clear(slot: ptr[u64]) {
    old = slot.view(1)[0];
    slot.view(1)[0] = STACKREF_NULL;
    stackref_close(old);
}

impl stackref_xsetref(slot: ptr[u64], bits: u64) {
    old = slot.view(1)[0];
    slot.view(1)[0] = bits;
    stackref_close(old);
}

impl stackref_is_heap_safe(bits: u64) -> bool {
    return (bits & STACKREF_TAG_BITS) != u64(1)
        or bits == STACKREF_NULL
        or object_is_immortal(stackref_borrow(bits));
}

impl reftracer_track(op: ptr[PyObject], operation: i32) {
    runtime = ptr[u8](addressof(_PyRuntime));
    tracer = ptr[ptr](runtime + _PyRuntimeState_REF_TRACER_FUNC).view(1)[0];
    if not tracer {
        return;
    }
    data = ptr[ptr](runtime + _PyRuntimeState_REF_TRACER_DATA).view(1)[0];
    slot = ptr[ObjectCall](
        __thread_local_block("jac_object_model_object_call_slot", 8)
    );
    slot.view(1)[0].tracer = int(tracer);
    slot.view(1)[0].tracer(op, operation, data);
}

impl interned_id(which: int) -> ptr[PyObject] {
    slot = ptr[ptr[PyObject]](addressof(interned_ids)) + which;
    name = slot.view(1)[0];
    if not name {
        name = jacpy_unicode_intern_text(ID_TEXT[which]);
        slot.view(1)[0] = name;
    }
    return name;
}

impl managed_dict_slot(ob: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](ob) + MANAGED_DICT_OFFSET);
}

impl managed_dict(ob: ptr[PyObject]) -> ptr[PyObject] {
    return managed_dict_slot(ob).view(1)[0];
}

impl attribute_error_pending -> bool {
    return PyErr_ExceptionMatches(PyExc_AttributeError) != 0;
}

impl interp_of(tstate: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](tstate + PyThreadState_INTERP).view(1)[0];
}

impl gc_finalized(op: ptr[PyObject]) -> bool {
    return (ptr[i64](gc_head(op)).view(2)[1] & _PyGC_PREV_MASK_FINALIZED) != 0;
}

impl gc_set_finalized(op: ptr[PyObject]) {
    words = ptr[i64](gc_head(op)).view(2);
    words[1] = words[1] | _PyGC_PREV_MASK_FINALIZED;
}

impl object_is_gc(op: ptr[PyObject]) -> bool {
    tp = object_type(op);
    return type_has_feature(tp, Py_TPFLAGS_HAVE_GC)
        and (int(tp.view(1)[0].tp_is_gc) == 0 or tp.view(1)[0].tp_is_gc(op) != 0);
}

impl var_size(tp: ptr[PyTypeObject], nitems: i64) -> i64 {
    size = tp.view(1)[0].tp_basicsize + nitems * tp.view(1)[0].tp_itemsize;
    return (size + 7) & ~i64(7);
}

impl status_ok -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
    );
}

impl status_err(func: ptr[u8], msg: ptr[u8]) -> PyStatus {
    return PyStatus(_type=_PyStatus_TYPE_ERROR, func=func, err_msg=msg, exitcode=0);
}

impl bad_attribute_name(name: ptr[PyObject]) {
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("attribute name must be string, not '%.200s'"),
        object_type(name).view(1)[0].tp_name
    );
}

impl no_attribute(ob: ptr[PyObject], tp: ptr[PyTypeObject], name: ptr[PyObject]) {
    PyErr_Format(
        PyExc_AttributeError,
        ptr[u8]("'%.100s' object has no attribute '%U'"),
        tp.view(1)[0].tp_name,
        name
    );
    _PyObject_SetAttributeErrorContext(ob, name);
}

impl new_reference(op: ptr[PyObject]) {
    ptr[_object](op).view(1)[0].ob_refcnt_full = 1;
    reftracer_track(op, PYREFTRACER_CREATE);
}

impl object_init(op: ptr[PyObject], tp: ptr[PyTypeObject]) {
    ptr[_object](op).view(1)[0].ob_type = tp;
    object_incref(ptr[PyObject](tp));
    new_reference(op);
}

impl resurrect_end(op: ptr[PyObject]) -> bool {
    set_refcnt(op, object_refcount(op) - 1);
    return object_refcount(op) != 0;
}

impl try_incref(op: ptr[PyObject]) -> bool {
    if object_refcount(op) > 0 {
        object_incref(op);
        return True;
    }
    return False;
}

impl assert_failed(op: ptr[PyObject], msg: ptr[u8], line: i32, function: ptr[u8]) {
    _PyObject_AssertFailed(
        op, ptr[u8](), msg, ptr[u8]("Objects/object.c"), line, function
    );
}

impl delete_later_slot(tstate: ptr[u8]) -> ptr[i64] {
    return ptr[i64](tstate + PyThreadState_DELETE_LATER);
}

impl free_object(item: ptr) {
    op = ptr[PyObject](item);
    tp = object_type(op);
    tp.view(1)[0].tp_free(item);
    object_decref(ptr[PyObject](tp));
}

impl clear_freelist(freelists: ptr[u8], offset: i64, is_finalization: bool, how: i64) {
    fl = ptr[_Py_freelist](freelists + offset);
    while True {
        item = fl.view(1)[0].freelist;
        if not item {
            break;
        }
        fl.view(1)[0].freelist = ptr[ptr](item).view(1)[0];
        fl.view(1)[0].size -= 1;
        if how == FREE_OBJECT {
            free_object(item);
        } elif how == FREE_MEM {
            PyMem_Free(item);
        } elif how == FREE_RAW_MEM {
            PyMem_RawFree(item);
        } else {
            PyObject_GC_Del(item);
        }
    }
    if is_finalization {
        fl.view(1)[0].size = -1;
    }
}

impl is_ptr_freed(address: u64) -> bool {
    return address <= u64(0xFF)
        or address == u64(0xCDCDCDCDCDCDCDCD)
        or address == u64(0xDDDDDDDDDDDDDDDD)
        or address == u64(0xFDFDFDFDFDFDFDFD)
        or address >= u64(0xFFFFFFFFFFFFFF00);
}

impl stderr_stream -> ptr {
    return jacpy_stdio_stream(i32(2));
}

impl swapped_op(op: i32) -> i32 {
    return (ptr[i32](addressof(_Py_SwappedOp)) + i64(op)).view(1)[0];
}

impl op_string(op: i32) -> ptr[u8] {
    if op == Py_LT {
        return ptr[u8]("<");
    }
    if op == Py_LE {
        return ptr[u8]("<=");
    }
    if op == Py_EQ {
        return ptr[u8]("==");
    }
    if op == Py_NE {
        return ptr[u8]("!=");
    }
    if op == Py_GT {
        return ptr[u8](">");
    }
    return ptr[u8](">=");
}

impl do_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    vt = object_type(v);
    wt = object_type(w);
    checked_reverse_op = False;
    if vt != wt
        and PyType_IsSubtype(ptr[PyObject](wt), ptr[PyObject](vt)) != 0
        and int(wt.view(1)[0].tp_richcompare) != 0 {
        checked_reverse_op = True;
        res = wt.view(1)[0].tp_richcompare(w, v, swapped_op(op));
        if res != py_not_implemented() {
            return res;
        }
        object_decref(res);
    }
    if int(vt.view(1)[0].tp_richcompare) != 0 {
        res = vt.view(1)[0].tp_richcompare(v, w, op);
        if res != py_not_implemented() {
            return res;
        }
        object_decref(res);
    }
    if not checked_reverse_op and int(wt.view(1)[0].tp_richcompare) != 0 {
        res = wt.view(1)[0].tp_richcompare(w, v, swapped_op(op));
        if res != py_not_implemented() {
            return res;
        }
        object_decref(res);
    }

    if op == Py_EQ {
        return py_true() if v == w else py_false();
    }
    if op == Py_NE {
        return py_true() if v != w else py_false();
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("'%s' not supported between instances of '%.100s' and '%.100s'"),
        op_string(op),
        vt.view(1)[0].tp_name,
        wt.view(1)[0].tp_name
    );
    return NULL;
}

impl optional_attr(v: ptr[PyObject], name: ptr[PyObject]) -> tuple[i32, ptr[PyObject]] {
    tp = object_type(v);
    if not unicode_check(name) {
        bad_attribute_name(name);
        return (i32(-1), NULL);
    }
    getattro = int(tp.view(1)[0].tp_getattro);
    result = NULL;
    if getattro == int(ptr(PyObject_GenericGetAttr)) {
        result = _PyObject_GenericGetAttrWithDict(v, name, NULL, i32(1));
        if result {
            return (i32(1), result);
        }
        if PyErr_Occurred() {
            return (i32(-1), NULL);
        }
        return (i32(0), NULL);
    }
    if getattro == int(ptr(_Py_type_getattro)) {
        suppress_missing = i32(0);
        result = _Py_type_getattro_impl(
            ptr[PyTypeObject](v), name, &mut suppress_missing
        );
        if suppress_missing != 0 {
            return (i32(0), result);
        }
    } elif getattro == int(ptr(_Py_module_getattro)) {
        result = _Py_module_getattro_impl(v, name, i32(1));
        if result {
            return (i32(1), result);
        }
        if PyErr_Occurred() {
            return (i32(-1), NULL);
        }
        return (i32(0), NULL);
    } elif getattro != 0 {
        result = tp.view(1)[0].tp_getattro(v, name);
    } elif int(tp.view(1)[0].tp_getattr) != 0 {
        name_str = PyUnicode_AsUTF8(name);
        if not name_str {
            return (i32(-1), NULL);
        }
        result = tp.view(1)[0].tp_getattr(v, name_str);
    } else {
        return (i32(0), NULL);
    }
    if result {
        return (i32(1), result);
    }
    if not attribute_error_pending() {
        return (i32(-1), NULL);
    }
    PyErr_Clear();
    return (i32(0), NULL);
}

impl optional_attr_string(
    ob: ptr[PyObject], name: ptr[u8]
) -> tuple[i32, ptr[PyObject]] {
    tp = object_type(ob);
    if int(tp.view(1)[0].tp_getattr) == 0 {
        oname = PyUnicode_FromString(name);
        if not oname {
            return (i32(-1), NULL);
        }
        (rc, result) = optional_attr(ob, oname);
        object_decref(oname);
        return (rc, result);
    }
    value = tp.view(1)[0].tp_getattr(ob, name);
    if value {
        return (i32(1), value);
    }
    if not attribute_error_pending() {
        return (i32(-1), NULL);
    }
    PyErr_Clear();
    return (i32(0), NULL);
}

impl dir_locals -> ptr[PyObject] {
    scope = NULL;
    if _PyEval_GetFrame() {
        scope = _PyEval_GetFrameLocals();
    } else {
        scope = _PyEval_GetGlobalsFromRunningMain(current_tstate());
        if not scope {
            if not PyErr_Occurred() {
                scope = _PyEval_GetFrameLocals();
            }
        } else {
            object_incref(scope);
        }
    }
    if not scope {
        return NULL;
    }
    names = PyMapping_Keys(scope);
    object_decref(scope);
    if not names {
        return NULL;
    }
    if not list_check(names) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("dir(): expected keys() of scope to be a list, not '%.200s'"),
            object_type(names).view(1)[0].tp_name
        );
        object_decref(names);
        return NULL;
    }
    if PyList_Sort(names) != 0 {
        object_decref(names);
        return NULL;
    }
    return names;
}

impl dir_object(ob: ptr[PyObject]) -> ptr[PyObject] {
    key = interned_id(ID_DIR);
    if not key {
        return NULL;
    }
    dirfunc = _PyObject_LookupSpecial(ob, key);
    if not dirfunc {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("object does not provide __dir__")
            );
        }
        return NULL;
    }
    result = PyObject_CallNoArgs(dirfunc);
    object_decref(dirfunc);
    if not result {
        return NULL;
    }
    names = PySequence_List(result);
    object_decref(result);
    if not names {
        return NULL;
    }
    if PyList_Sort(names) != 0 {
        object_decref(names);
        return NULL;
    }
    return names;
}

impl none_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString(ptr[u8]("None"));
}

impl none_dealloc(none_obj: ptr[PyObject]) {
    _Py_SetImmortal(none_obj);
}

impl has_arguments(args: ptr[PyObject], kwargs: ptr[PyObject]) -> bool {
    return object_size(args) != 0 or (bool(kwargs) and dict_used(kwargs) != 0);
}

impl none_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if has_arguments(args, kwargs) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("NoneType takes no arguments"));
        return NULL;
    }
    return py_none();
}

impl none_bool(v: ptr[PyObject]) -> i32 {
    return i32(0);
}

impl none_hash(v: ptr[PyObject]) -> i64 {
    return 0xFCA86420;
}

impl NotImplemented_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString(ptr[u8]("NotImplemented"));
}

impl NotImplemented_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString(ptr[u8]("NotImplemented"));
}

impl notimplemented_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if has_arguments(args, kwargs) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("NotImplementedType takes no arguments")
        );
        return NULL;
    }
    return py_not_implemented();
}

impl notimplemented_dealloc(notimplemented: ptr[PyObject]) {
    _Py_SetImmortal(notimplemented);
}

impl notimplemented_bool(v: ptr[PyObject]) -> i32 {
    PyErr_SetString(
        PyExc_TypeError,
        ptr[u8]("NotImplemented should not be used in a boolean context")
    );
    return i32(-1);
}

impl static_type(index: i64) -> ptr[PyTypeObject] {
    return (ptr[ptr[PyTypeObject]](addressof(static_types)) + index).view(1)[0];
}

impl constant_slot(index: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](addressof(constants)) + index;
}
