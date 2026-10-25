import from c {
    def memmove(target: ptr, source: ptr, size: u64) -> ptr;  def dlopen(
        filename: ptr[u8], flags: i32
    ) -> ptr;  def dlclose(handle: ptr) -> i32;  def dlerror -> ptr[u8];  def dlsym(
        handle: ptr, symbol: str
    ) -> ptr;  obj CallprocArgs {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut CallprocArgs) -> int;  obj callproc_argument {
        has ffi_type_: ptr[ffi_type],
            keep: ptr[PyObject],
            value: carg_value;
    }  def _ctypes_get_errobj(
        st: ptr[ctypes_state], pspace: ptr[ptr[i32]]
    ) -> ptr[PyObject] {
        (errobj, space) = ctypes_errobj(st);
        if errobj {
            pspace.view(1)[0] = space;
        }
        return errobj;
    }  def PyCArgObject_new(st: ptr[ctypes_state]) -> ptr[PyCArgObject] {
        p = ptr[PyCArgObject](
            _PyObject_GC_New(ptr[PyObject](st.view(1)[0].PyCArg_Type))
        );
        if not p {
            return ptr[PyCArgObject]();
        }
        p.view(1)[0].pffi_type = ptr[ffi_type]();
        p.view(1)[0].tag = 0;
        p.view(1)[0].obj_ = NULL;
        clear_result(carg_value_address(p));
        PyObject_GC_Track(ptr(p));
        return p;
    }  def _ctypes_get_ffi_type(
        st: ptr[ctypes_state], obj_: ptr[PyObject]
    ) -> ptr[ffi_type] {
        if not obj_ {
            return addressof(ffi_type_sint32);
        }
        (res, info) = PyStgInfo_FromType(st, obj_);
        if res < 0 {
            return ptr[ffi_type]();
        }
        if not info {
            return addressof(ffi_type_sint32);
        }
        return stginfo_ffi_type(info);
    }  def _ctypes_callproc(
        st: ptr[ctypes_state],
        pProc: ptr,
        arguments: ptr[PyObject],
        flags: i32,
        argtypes: ptr[PyObject],
        restype: ptr[PyObject],
        checker: ptr[PyObject]
    ) -> ptr[PyObject] {
        if PySys_Audit("ctypes.call_function", "KO", u64(int(pProc)), arguments) < 0 {
            return NULL;
        }

        argcount = object_size(arguments);
        if argcount > CTYPES_MAX_ARGCOUNT {
            PyErr_Format(
                st.view(1)[0].PyExc_ArgError,
                ptr[u8]("too many arguments (%zi), maximum is %i"),
                argcount,
                i32(CTYPES_MAX_ARGCOUNT)
            );
            return NULL;
        }

        args = ptr[callproc_argument](
            PyMem_Calloc(u64(argcount), u64(SIZEOF_CALLPROC_ARGUMENT))
        );
        if not args {
            return PyErr_NoMemory();
        }
        argtype_count: i64 = 0;
        if argtypes {
            argtype_count = object_size(argtypes);
        }
        retval = callproc_args(
            st,
            pProc,
            arguments,
            flags,
            argtypes,
            restype,
            checker,
            args,
            argcount,
            argtype_count
        );
        for i in range(argcount) {
            object_xdecref((args + i).view(1)[0].keep);
        }
        PyMem_Free(ptr(args));
        return retval;
    }  glob:priv PyCArgType_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("_obj"),
                 type_=_Py_T_OBJECT,
                 offset=PYCARG_OBJ,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the wrapped object")
             ),
             PyMemberDef()
         ],
         carg_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(PyCArg_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(PyCArg_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(PyCArg_clear)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(PyCArg_repr)),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(PyCArgType_members))),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob carg_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.CArgObject"),
             basicsize=i32(SIZEOF_PYCARGOBJECT),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
             ),
             slots=addressof(carg_slots)
         ),
         _ctypes_module_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("get_errno"),
                 ml_meth=ptr(get_errno),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set_errno"),
                 ml_meth=ptr(set_errno),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_unpickle"),
                 ml_meth=ptr(unpickle),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("buffer_info"),
                 ml_meth=ptr(buffer_info),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Return buffer interface information")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("resize"), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("dlopen"),
                 ml_meth=ptr(py_dl_open),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "dlopen(name, flag={RTLD_GLOBAL|RTLD_LOCAL}) open a shared library"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("dlclose"),
                 ml_meth=ptr(py_dl_close),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]("dlclose a library")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("dlsym"),
                 ml_meth=ptr(py_dl_sym),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]("find symbol in shared library")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("alignment"),
                 ml_meth=ptr(align_func),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "alignment(C type) -> integer\nalignment(C instance) -> integer\nReturn the alignment requirements of a C instance"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("sizeof"), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("byref"), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("addressof"),
                 ml_meth=ptr(),
                 ml_flags=0,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("call_function"),
                 ml_meth=ptr(call_function),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("call_cdeclfunction"),
                 ml_meth=ptr(call_cdeclfunction),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("PyObj_FromPtr"),
                 ml_meth=ptr(My_PyObj_FromPtr),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("Py_INCREF"),
                 ml_meth=ptr(My_Py_INCREF),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("Py_DECREF"),
                 ml_meth=ptr(My_Py_DECREF),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_dyld_shared_cache_contains_path"),
                 ml_meth=ptr(py_dyld_shared_cache_contains_path),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]("check if path is in the shared cache")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ];
}

glob:priv SIZEOF_CALLPROC_ARGUMENT: Final[i64] = 48,
     CALLPROC_ARGUMENT_VALUE: Final[i64] = 16,
     SIZEOF_FFI_ARG: Final[u64] = 8,
     INT_MAX: Final[i64] = 2147483647,
     INT_MIN: Final[i64] = -2147483648,
     GETRESULT_TRACEBACK_LINE: Final[i32] = 1036;

def clear_result(value: ptr[u8]);

def copy_result(dst: ptr[u8], src: ptr[u8]);

def argument_value(pa: ptr[callproc_argument]) -> ptr[u8];

def getargs_count(args: ptr[PyObject], fname: ptr[u8], lo: i64, hi: i64) -> bool;

def getargs_converter_failed(fname: ptr[u8], iarg: i64);

def getargs_must_be(fname: ptr[u8], iarg: i64, expected: ptr[u8], arg: ptr[PyObject]);

def getargs_int(arg: ptr[PyObject]) -> tuple[i32, i32];

def pymem_destructor(op: ptr[PyObject]);

def ctypes_errobj(st: ptr[ctypes_state]) -> tuple[ptr[PyObject], ptr[i32]];

def get_error_internal(
    self_: ptr[PyObject], args: ptr[PyObject], index: i64
) -> ptr[PyObject];

def set_error_internal(
    self_: ptr[PyObject], args: ptr[PyObject], index: i64
) -> ptr[PyObject];

def get_errno(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def set_errno(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def PyCArg_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def PyCArg_clear(op: ptr[PyObject]) -> i32;

def PyCArg_dealloc(self_: ptr[PyObject]);

def is_literal_char(c: u8) -> bool;

def PyCArg_repr(op: ptr[PyObject]) -> ptr[PyObject];

def ConvParam(
    st: ptr[ctypes_state], obj_: ptr[PyObject], index: i64, pa: ptr[callproc_argument]
) -> i32;

def call_function_pointer_cif(
    st: ptr[ctypes_state],
    cif: ptr[ffi_cif],
    flags: i32,
    pProc: ptr,
    avalues: ptr[ptr],
    atypes: ptr[ptr[ffi_type]],
    restype: ptr[ffi_type],
    resmem: ptr,
    argcount: i32,
    argtypecount: i32
) -> i32;

def _call_function_pointer(
    st: ptr[ctypes_state],
    flags: i32,
    pProc: ptr,
    avalues: ptr[ptr],
    atypes: ptr[ptr[ffi_type]],
    restype: ptr[ffi_type],
    resmem: ptr,
    argcount: i32,
    argtypecount: i32
) -> i32;

def GetResult(
    st: ptr[ctypes_state], restype: ptr[PyObject], result: ptr, checker: ptr[PyObject]
) -> ptr[PyObject];

def _ctypes_extend_error(exc_class: ptr[PyObject], prefix: ptr[PyObject]);

def callproc_args(
    st: ptr[ctypes_state],
    pProc: ptr,
    arguments: ptr[PyObject],
    flags: i32,
    argtypes: ptr[PyObject],
    restype: ptr[PyObject],
    checker: ptr[PyObject],
    args: ptr[callproc_argument],
    argcount: i64,
    argtype_count: i64
) -> ptr[PyObject];

def _parse_voidp(obj_: ptr[PyObject]) -> tuple[i32, ptr];

def py_dyld_shared_cache_contains_path(
    self_: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject];

def py_dl_open(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def py_dl_close(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def py_dl_sym(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def parse_call_args(args: ptr[PyObject]) -> tuple[i32, ptr, ptr[PyObject]];

def call_function(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def call_cdeclfunction(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def _ctypes_sizeof_impl(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def align_func(self_: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def _ctypes_byref_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], offset: i64
) -> ptr[PyObject];

def _ctypes_addressof_impl(
    module: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject];

def converter(obj_: ptr[PyObject]) -> tuple[i32, ptr];

def My_PyObj_FromPtr(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def My_Py_INCREF(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def My_Py_DECREF(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def _ctypes_resize_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], size: i64
) -> ptr[PyObject];

def unpickle(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def buffer_info(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

impl clear_result(value: ptr[u8]) {
    words = ptr[u64](value);
    words.view(4)[0] = 0;
    words.view(4)[1] = 0;
    words.view(4)[2] = 0;
    words.view(4)[3] = 0;
}

impl copy_result(dst: ptr[u8], src: ptr[u8]) {
    target = ptr[u64](dst);
    source = ptr[u64](src);
    target.view(4)[0] = source.view(4)[0];
    target.view(4)[1] = source.view(4)[1];
    target.view(4)[2] = source.view(4)[2];
    target.view(4)[3] = source.view(4)[3];
}

impl argument_value(pa: ptr[callproc_argument]) -> ptr[u8] {
    return ptr[u8](pa) + CALLPROC_ARGUMENT_VALUE;
}

impl getargs_count(args: ptr[PyObject], fname: ptr[u8], lo: i64, hi: i64) -> bool {
    nargs = object_size(args);
    if nargs >= lo and nargs <= hi {
        return True;
    }
    bound = hi;
    how = ptr[u8]("at most");
    if lo == hi {
        how = ptr[u8]("exactly");
    } elif nargs < lo {
        how = ptr[u8]("at least");
    }
    if nargs < lo {
        bound = lo;
    }
    name = fname;
    paren = ptr[u8]("()");
    if not fname {
        name = ptr[u8]("function");
        paren = ptr[u8]("");
    }
    plural = ptr[u8]("s");
    if bound == 1 {
        plural = ptr[u8]("");
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("%.150s%s takes %s %d argument%s (%zd given)"),
        name,
        paren,
        how,
        i32(bound),
        plural,
        nargs
    );
    return False;
}

impl getargs_converter_failed(fname: ptr[u8], iarg: i64) {
    if PyErr_Occurred() {
        return;
    }
    if fname {
        PyErr_Format(
            PyExc_SystemError,
            ptr[u8]("%.200s() argument %zd (unspecified)"),
            fname,
            iarg
        );
    } else {
        PyErr_Format(PyExc_SystemError, ptr[u8]("argument %zd (unspecified)"), iarg);
    }
}

impl getargs_must_be(fname: ptr[u8], iarg: i64, expected: ptr[u8], arg: ptr[PyObject]) {
    shown = ptr[u8]("None");
    if arg != Py_None {
        shown = object_type(arg).view(1)[0].tp_name;
    }
    if fname {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%.200s() argument %zd must be %.50s, not %.50s"),
            fname,
            iarg,
            expected,
            shown
        );
    } else {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("argument %zd must be %.50s, not %.50s"),
            iarg,
            expected,
            shown
        );
    }
}

impl getargs_int(arg: ptr[PyObject]) -> tuple[i32, i32] {
    ival = PyLong_AsLong(arg);
    if ival == -1 and PyErr_Occurred() {
        return (i32(0), i32(0));
    }
    if ival > INT_MAX {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed integer is greater than maximum")
        );
        return (i32(0), i32(0));
    }
    if ival < INT_MIN {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed integer is less than minimum")
        );
        return (i32(0), i32(0));
    }
    return (i32(1), i32(ival));
}

impl pymem_destructor(op: ptr[PyObject]) {
    p = PyCapsule_GetPointer(op, ptr[u8]("_ctypes pymem"));
    if p {
        PyMem_Free(p);
    }
}

impl ctypes_errobj(st: ptr[ctypes_state]) -> tuple[ptr[PyObject], ptr[i32]] {
    dct = PyThreadState_GetDict();
    if not dct {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("cannot get thread state"));
        return (NULL, ptr[i32]());
    }
    errobj: ptr[PyObject] = NULL;
    if PyDict_GetItemRef(dct, st.view(1)[0].error_object_name, &mut errobj) < 0 {
        return (NULL, ptr[i32]());
    }
    if errobj {
        if PyCapsule_IsValid(errobj, ptr[u8]("_ctypes pymem")) == 0 {
            PyErr_SetString(
                PyExc_RuntimeError, ptr[u8]("ctypes.error_object is an invalid capsule")
            );
            object_decref(errobj);
            return (NULL, ptr[i32]());
        }
    } else {
        space = PyMem_Calloc(2, 4);
        if not space {
            return (NULL, ptr[i32]());
        }
        errobj = PyCapsule_New(space, ptr[u8]("_ctypes pymem"), ptr(pymem_destructor));
        if not errobj {
            PyMem_Free(space);
            return (NULL, ptr[i32]());
        }
        if PyDict_SetItem(dct, st.view(1)[0].error_object_name, errobj) < 0 {
            object_decref(errobj);
            return (NULL, ptr[i32]());
        }
    }
    pspace = ptr[i32](PyCapsule_GetPointer(errobj, ptr[u8]("_ctypes pymem")));
    return (errobj, pspace);
}

impl get_error_internal(
    self_: ptr[PyObject], args: ptr[PyObject], index: i64
) -> ptr[PyObject] {
    st = get_module_state(self_);
    (errobj, space) = ctypes_errobj(st);
    if not errobj {
        return NULL;
    }
    result = PyLong_FromLong(i64((space + index).view(1)[0]));
    object_decref(errobj);
    return result;
}

impl set_error_internal(
    self_: ptr[PyObject], args: ptr[PyObject], index: i64
) -> ptr[PyObject] {
    if not getargs_count(args, ptr[u8](), 1, 1) {
        return NULL;
    }
    (ok, new_errno) = getargs_int(tuple_get_item(args, 0));
    if ok == 0 {
        return NULL;
    }
    st = get_module_state(self_);
    (errobj, space) = ctypes_errobj(st);
    if not errobj {
        return NULL;
    }
    old_errno = (space + index).view(1)[0];
    (space + index).view(1)[0] = new_errno;
    object_decref(errobj);
    return PyLong_FromLong(i64(old_errno));
}

impl get_errno(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if PySys_AuditTuple("ctypes.get_errno", NULL) < 0 {
        return NULL;
    }
    return get_error_internal(self_, args, 0);
}

impl set_errno(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if PySys_Audit("ctypes.set_errno", "O", args) < 0 {
        return NULL;
    }
    return set_error_internal(self_, args, 0);
}

impl PyCArg_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(ptr[PyCArgObject](op).view(1)[0].obj_, visitor, arg);
    if status != 0 {
        return status;
    }
    return i32(0);
}

impl PyCArg_clear(op: ptr[PyObject]) -> i32 {
    self_ = ptr[PyCArgObject](op);
    old = self_.view(1)[0].obj_;
    if old {
        self_.view(1)[0].obj_ = NULL;
        object_decref(old);
    }
    return i32(0);
}

impl PyCArg_dealloc(self_: ptr[PyObject]) {
    tp = object_type(self_);
    PyObject_GC_UnTrack(ptr(self_));
    PyCArg_clear(self_);
    tp.view(1)[0].tp_free(ptr(self_));
    object_decref(ptr[PyObject](tp));
}

impl is_literal_char(c: u8) -> bool {
    return c < 128 and _PyUnicode_IsPrintable(u32(c)) != 0 and c != 92 and c != 39;
}

impl PyCArg_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = ptr[PyCArgObject](op);
    tag = self_.view(1)[0].tag;
    value = carg_value_address(self_);
    if tag == 98 or tag == 66 {
        return PyUnicode_FromFormat(
            "<cparam '%c' (%d)>", i32(tag), i32(ptr[i8](value).view(1)[0])
        );
    }
    if tag == 104 or tag == 72 {
        return PyUnicode_FromFormat(
            "<cparam '%c' (%d)>", i32(tag), i32(ptr[i16](value).view(1)[0])
        );
    }
    if tag == 105 or tag == 73 {
        return PyUnicode_FromFormat(
            "<cparam '%c' (%d)>", i32(tag), ptr[i32](value).view(1)[0]
        );
    }
    if tag == 108 or tag == 76 {
        return PyUnicode_FromFormat(
            "<cparam '%c' (%ld)>", i32(tag), ptr[i64](value).view(1)[0]
        );
    }
    if tag == 113 or tag == 81 {
        return PyUnicode_FromFormat(
            "<cparam '%c' (%lld)>", i32(tag), ptr[i64](value).view(1)[0]
        );
    }
    if tag == 100 or tag == 102 {
        number: f64 = ptr[f64](value).view(1)[0];
        if tag == 102 {
            number = f64(ptr[f32](value).view(1)[0]);
        }
        f = PyFloat_FromDouble(number);
        if not f {
            return NULL;
        }
        result = PyUnicode_FromFormat("<cparam '%c' (%R)>", i32(tag), f);
        object_decref(f);
        return result;
    }
    if tag == 99 {
        c = ptr[u8](value).view(1)[0];
        if is_literal_char(c) {
            return PyUnicode_FromFormat("<cparam '%c' ('%c')>", i32(tag), i32(c));
        }
        return PyUnicode_FromFormat("<cparam '%c' ('\\x%02x')>", i32(tag), i32(c));
    }

    if tag == 122 or tag == 90 or tag == 80 {
        return PyUnicode_FromFormat(
            "<cparam '%c' (%p)>", i32(tag), ptr[ptr](value).view(1)[0]
        );
    }
    if is_literal_char(tag) {
        return PyUnicode_FromFormat("<cparam '%c' at %p>", i32(tag), ptr(op));
    }
    return PyUnicode_FromFormat("<cparam 0x%02x at %p>", i32(tag), ptr(op));
}

impl ConvParam(
    st: ptr[ctypes_state], obj_: ptr[PyObject], index: i64, pa: ptr[callproc_argument]
) -> i32 {
    pa.view(1)[0].keep = NULL;
    value = argument_value(pa);

    (result, info) = PyStgInfo_FromObject(st, obj_);
    if result < 0 {
        return i32(-1);
    }
    if info {
        carg = call_paramfunc(info.view(1)[0].paramfunc, st, ptr[CDataObject](obj_));
        if not carg {
            return i32(-1);
        }
        pa.view(1)[0].ffi_type_ = carg.view(1)[0].pffi_type;
        copy_result(value, carg_value_address(carg));
        pa.view(1)[0].keep = ptr[PyObject](carg);
        return i32(0);
    }

    if PyCArg_CheckExact(st, obj_) {
        carg_obj = ptr[PyCArgObject](obj_);
        pa.view(1)[0].ffi_type_ = carg_obj.view(1)[0].pffi_type;
        pa.view(1)[0].keep = object_new_ref(obj_);
        copy_result(value, carg_value_address(carg_obj));
        return i32(0);
    }

    if obj_ == Py_None {
        pa.view(1)[0].ffi_type_ = addressof(ffi_type_pointer);
        ptr[ptr](value).view(1)[0] = ptr();
        return i32(0);
    }

    if long_check(obj_) {
        pa.view(1)[0].ffi_type_ = addressof(ffi_type_sint32);
        ival = i32.wrap(PyLong_AsUnsignedLong(obj_));
        ptr[i32](value).view(1)[0] = ival;
        if ival == -1 and PyErr_Occurred() {
            PyErr_Clear();
            ival = i32.wrap(PyLong_AsLong(obj_));
            ptr[i32](value).view(1)[0] = ival;
            if ival == -1 and PyErr_Occurred() {
                PyErr_SetString(
                    PyExc_OverflowError, ptr[u8]("int too long to convert")
                );
                return i32(-1);
            }
        }
        return i32(0);
    }

    if bytes_check(obj_) {
        pa.view(1)[0].ffi_type_ = addressof(ffi_type_pointer);
        ptr[ptr[u8]](value).view(1)[0] = PyBytes_AsString(obj_);
        pa.view(1)[0].keep = object_new_ref(obj_);
        return i32(0);
    }

    if unicode_check(obj_) {
        pa.view(1)[0].ffi_type_ = addressof(ffi_type_pointer);
        wide = PyUnicode_AsWideCharString(obj_, None);
        ptr[ptr[i32]](value).view(1)[0] = wide;
        if not wide {
            return i32(-1);
        }
        capsule = PyCapsule_New(
            ptr(wide), ptr[u8]("_ctypes pymem"), ptr(pymem_destructor)
        );
        pa.view(1)[0].keep = capsule;
        if not capsule {
            PyMem_Free(ptr(wide));
            return i32(-1);
        }
        return i32(0);
    }

    arg: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttrString(obj_, ptr[u8]("_as_parameter_"), &mut arg) < 0 {
        return i32(-1);
    }

    if arg {
        status = ConvParam(st, arg, index, pa);
        object_decref(arg);
        return status;
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("Don't know how to convert parameter %d"), i32(index)
    );
    return i32(-1);
}

impl call_function_pointer_cif(
    st: ptr[ctypes_state],
    cif: ptr[ffi_cif],
    flags: i32,
    pProc: ptr,
    avalues: ptr[ptr],
    atypes: ptr[ptr[ffi_type]],
    restype: ptr[ffi_type],
    resmem: ptr,
    argcount: i32,
    argtypecount: i32
) -> i32 {
    cc: i32 = FFI_DEFAULT_ABI;

    is_variadic = argtypecount != 0 and argcount > argtypecount;

    if is_variadic {
        if ffi_prep_cif_var(cif, cc, u32(argtypecount), u32(argcount), restype, atypes)
            != FFI_OK {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("ffi_prep_cif_var failed"));
            return i32(-1);
        }
    } elif ffi_prep_cif(cif, cc, u32(argcount), restype, atypes) != FFI_OK {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("ffi_prep_cif failed"));
        return i32(-1);
    }

    error_object: ptr[PyObject] = NULL;
    space = ptr[i32]();
    if (flags & (FUNCFLAG_USE_ERRNO | FUNCFLAG_USE_LASTERROR)) != 0 {
        (errobj, errspace) = ctypes_errobj(st);
        if not errobj {
            return i32(-1);
        }
        error_object = errobj;
        space = errspace;
    }
    save = ptr[PyThreadState]();
    if (flags & FUNCFLAG_PYTHONAPI) == 0 {
        save = PyEval_SaveThread();
    }
    if (flags & FUNCFLAG_USE_ERRNO) != 0 {
        temp = space.view(2)[0];
        space.view(2)[0] = i32.wrap(jacpy_errno());
        jacpy_set_errno(i64(temp));
    }
    ffi_call(cif, pProc, resmem, avalues);
    if (flags & FUNCFLAG_USE_ERRNO) != 0 {
        temp = space.view(2)[0];
        space.view(2)[0] = i32.wrap(jacpy_errno());
        jacpy_set_errno(i64(temp));
    }
    if (flags & FUNCFLAG_PYTHONAPI) == 0 {
        PyEval_RestoreThread(save);
    }
    object_xdecref(error_object);
    if (flags & FUNCFLAG_PYTHONAPI) != 0 and PyErr_Occurred() {
        return i32(-1);
    }
    return i32(0);
}

impl _call_function_pointer(
    st: ptr[ctypes_state],
    flags: i32,
    pProc: ptr,
    avalues: ptr[ptr],
    atypes: ptr[ptr[ffi_type]],
    restype: ptr[ffi_type],
    resmem: ptr,
    argcount: i32,
    argtypecount: i32
) -> i32 {
    if not restype {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("No ffi_type for result"));
        return i32(-1);
    }
    cif = ptr[ffi_cif](PyMem_Malloc(u64(SIZEOF_FFI_CIF)));
    if not cif {
        PyErr_NoMemory();
        return i32(-1);
    }
    status = call_function_pointer_cif(
        st, cif, flags, pProc, avalues, atypes, restype, resmem, argcount, argtypecount
    );
    PyMem_Free(ptr(cif));
    return status;
}

impl GetResult(
    st: ptr[ctypes_state], restype: ptr[PyObject], result: ptr, checker: ptr[PyObject]
) -> ptr[PyObject] {
    if not restype {
        return PyLong_FromLong(i64(ptr[i32](result).view(1)[0]));
    }

    if restype == Py_None {
        return object_new_ref(Py_None);
    }

    (res, info) = PyStgInfo_FromType(st, restype);
    if res < 0 {
        return NULL;
    }
    if not info {
        return PyObject_CallFunction(restype, "i", ptr[i32](result).view(1)[0]);
    }

    retval: ptr[PyObject] = NULL;
    if info.view(1)[0].getfunc and _ctypes_simple_instance(st, restype) == 0 {
        retval = call_getfunc(info.view(1)[0].getfunc, result, info.view(1)[0].size);

        o_desc = ptr[fielddesc](_ctypes_get_fielddesc(ptr[u8]("O")));
        o_get = o_desc.view(1)[0].getfunc;
        if int(info.view(1)[0].getfunc) == int(o_get) {
            object_xdecref(retval);
        }
    } else {
        retval = ptr[PyObject](
            PyCData_FromBaseObj(st, restype, NULL, 0, ptr[u8](result))
        );
    }
    if not checker or not retval {
        return retval;
    }

    v = PyObject_CallOneArg(checker, retval);
    if not v {
        _PyTraceback_Add(
            ptr[u8]("GetResult"),
            ptr[u8]("_ctypes/callproc.c"),
            GETRESULT_TRACEBACK_LINE
        );
    }
    object_decref(retval);
    return v;
}

impl _ctypes_extend_error(exc_class: ptr[PyObject], prefix: ptr[PyObject]) {
    s: ptr[PyObject] = prefix;
    if not s {
        return;
    }

    exc = PyErr_GetRaisedException();
    cls_str = PyType_GetName(object_type(exc));
    if cls_str {
        PyUnicode_AppendAndDel(&mut s, cls_str);
        PyUnicode_AppendAndDel(&mut s, PyUnicode_FromString(ptr[u8](": ")));
        if not s {
            object_xdecref(exc);
            return;
        }
    } else {
        PyErr_Clear();
    }

    msg_str = PyObject_Str(exc);
    if msg_str {
        PyUnicode_AppendAndDel(&mut s, msg_str);
    } else {
        PyErr_Clear();
        PyUnicode_AppendAndDel(&mut s, PyUnicode_FromString(ptr[u8]("???")));
    }
    if s {
        PyErr_SetObject(exc_class, s);
    }
    object_xdecref(exc);
    object_xdecref(s);
}

impl callproc_args(
    st: ptr[ctypes_state],
    pProc: ptr,
    arguments: ptr[PyObject],
    flags: i32,
    argtypes: ptr[PyObject],
    restype: ptr[PyObject],
    checker: ptr[PyObject],
    args: ptr[callproc_argument],
    argcount: i64,
    argtype_count: i64
) -> ptr[PyObject] {
    for i in range(argcount) {
        pa = args + i;
        arg = tuple_get_item(arguments, i);

        if argtypes and argtype_count > i {
            converter_fn = tuple_get_item(argtypes, i);
            v = PyObject_CallOneArg(converter_fn, arg);
            if not v {
                _ctypes_extend_error(
                    st.view(1)[0].PyExc_ArgError,
                    PyUnicode_FromFormat("argument %zd: ", i64(i + 1))
                );
                return NULL;
            }
            err = ConvParam(st, v, i64(i + 1), pa);
            object_decref(v);
            if err == -1 {
                _ctypes_extend_error(
                    st.view(1)[0].PyExc_ArgError,
                    PyUnicode_FromFormat("argument %zd: ", i64(i + 1))
                );
                return NULL;
            }
        } else {
            err = ConvParam(st, arg, i64(i + 1), pa);
            if err == -1 {
                _ctypes_extend_error(
                    st.view(1)[0].PyExc_ArgError,
                    PyUnicode_FromFormat("argument %zd: ", i64(i + 1))
                );
                return NULL;
            }
        }
    }

    rtype = ptr[ffi_type]();
    if restype == Py_None {
        rtype = addressof(ffi_type_void);
    } else {
        rtype = _ctypes_get_ffi_type(st, restype);
    }
    if not rtype {
        return NULL;
    }

    ressize = rtype.view(1)[0].size;
    if ressize < SIZEOF_FFI_ARG {
        ressize = SIZEOF_FFI_ARG;
    }
    resbuf = PyMem_Malloc(ressize);
    avalues = ptr[ptr](PyMem_Malloc(u64(8 * argcount)));
    atypes = ptr[ptr[ffi_type]](PyMem_Malloc(u64(8 * argcount)));

    temps = ptr[ptr](PyMem_Calloc(u64(argcount + 1), 8));
    retval: ptr[PyObject] = NULL;
    if not resbuf or not avalues or not atypes or not temps {
        PyErr_NoMemory();
    } else {
        copied = True;
        for i in range(argcount) {
            atype = (args + i).view(1)[0].ffi_type_;
            (atypes + i).view(1)[0] = atype;
            size = atype.view(1)[0].size;
            if PASS_BY_REF_HACK
                and (
                    size > 8 or size == 0 or (size & wrapping_sub(u64(0), size)) != size
                ) {
                tmp = PyMem_Malloc(size);
                if not tmp {
                    PyErr_NoMemory();
                    copied = False;
                    break;
                }
                (temps + i).view(1)[0] = tmp;
                if atype.view(1)[0].type == FFI_TYPE_STRUCT {
                    memmove(tmp, ptr[ptr](argument_value(args + i)).view(1)[0], size);
                } else {
                    memmove(tmp, ptr(argument_value(args + i)), size);
                }
                (avalues + i).view(1)[0] = tmp;
            } elif atype.view(1)[0].type == FFI_TYPE_STRUCT {
                (avalues + i).view(1)[0] = ptr[ptr](argument_value(args + i)).view(1)[
                    0
                ];
            } else {
                (avalues + i).view(1)[0] = ptr(argument_value(args + i));
            }
        }
        if copied {
            status = _call_function_pointer(
                st,
                flags,
                pProc,
                avalues,
                atypes,
                rtype,
                resbuf,
                i32(argcount),
                i32(argtype_count)
            );
            if status != -1 {
                retval = GetResult(st, restype, resbuf, checker);
            }
        }
    }
    if temps {
        for i in range(argcount) {
            if (temps + i).view(1)[0] {
                PyMem_Free((temps + i).view(1)[0]);
            }
        }
        PyMem_Free(ptr(temps));
    }
    PyMem_Free(resbuf);
    PyMem_Free(ptr(avalues));
    PyMem_Free(ptr(atypes));
    return retval;
}

impl _parse_voidp(obj_: ptr[PyObject]) -> tuple[i32, ptr] {
    address = PyLong_AsVoidPtr(obj_);
    if not address {
        return (i32(0), address);
    }
    return (i32(1), address);
}

impl py_dyld_shared_cache_contains_path(
    self_: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    if not getargs_count(args, ptr[u8](), 1, 1) {
        return NULL;
    }
    name = tuple_get_item(args, 0);

    if name == Py_None {
        return PyBool_FromLong(0);
    }

    name2: ptr[PyObject] = NULL;
    if PyUnicode_FSConverter(name, &mut name2) == 0 {
        return NULL;
    }
    name_str = PyBytes_AsString(name2);

    r = dyld_shared_cache_contains_path(name_str);
    object_decref(name2);

    if r {
        return PyBool_FromLong(1);
    }
    return PyBool_FromLong(0);
}

impl py_dl_open(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    mode: i32 = RTLD_NOW | RTLD_LOCAL;
    if not getargs_count(args, ptr[u8]("dlopen"), 1, 2) {
        return NULL;
    }
    name = tuple_get_item(args, 0);
    if object_size(args) > 1 {
        (ok, flag) = getargs_int(tuple_get_item(args, 1));
        if ok == 0 {
            return NULL;
        }
        mode = flag;
    }
    mode = mode | RTLD_NOW;
    name2: ptr[PyObject] = NULL;
    name_str = ptr[u8]();
    if name != Py_None {
        if PyUnicode_FSConverter(name, &mut name2) == 0 {
            return NULL;
        }
        name_str = PyBytes_AsString(name2);
    }
    if PySys_Audit("ctypes.dlopen", "O", name) < 0 {
        return NULL;
    }
    handle = dlopen(name_str, mode);
    object_xdecref(name2);
    if not handle {
        errmsg = dlerror();
        if errmsg {
            _PyErr_SetLocaleString(PyExc_OSError, errmsg);
            return NULL;
        }
        PyErr_SetString(PyExc_OSError, ptr[u8]("dlopen() error"));
        return NULL;
    }
    return PyLong_FromVoidPtr(handle);
}

impl py_dl_close(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if not getargs_count(args, ptr[u8]("dlclose"), 1, 1) {
        return NULL;
    }
    (ok, handle) = _parse_voidp(tuple_get_item(args, 0));
    if ok == 0 {
        getargs_converter_failed(ptr[u8]("dlclose"), 1);
        return NULL;
    }
    if dlclose(handle) != 0 {
        errmsg = dlerror();
        if errmsg {
            _PyErr_SetLocaleString(PyExc_OSError, errmsg);
            return NULL;
        }
        PyErr_SetString(PyExc_OSError, ptr[u8]("dlclose() error"));
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl py_dl_sym(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if not getargs_count(args, ptr[u8]("dlsym"), 2, 2) {
        return NULL;
    }
    (ok, handle) = _parse_voidp(tuple_get_item(args, 0));
    if ok == 0 {
        getargs_converter_failed(ptr[u8]("dlsym"), 1);
        return NULL;
    }
    name_obj = tuple_get_item(args, 1);
    name = "";
    try {
        name = convert_str(name_obj, "dlsym", "argument 2");
    } except boundary_failure {
        return NULL;
    }
    if PySys_Audit("ctypes.dlsym/handle", "O", args) < 0 {
        return NULL;
    }

    dlerror();
    p = dlsym(handle, name);
    if p {
        return PyLong_FromVoidPtr(p);
    }
    errmsg = dlerror();
    if errmsg {
        _PyErr_SetLocaleString(PyExc_OSError, errmsg);
        return NULL;
    }
    PyErr_Format(
        PyExc_OSError, ptr[u8]("symbol '%s' not found"), PyUnicode_AsUTF8(name_obj)
    );
    return NULL;
}

impl parse_call_args(args: ptr[PyObject]) -> tuple[i32, ptr, ptr[PyObject]] {
    if not getargs_count(args, ptr[u8](), 2, 2) {
        return (i32(0), ptr(), NULL);
    }
    (ok, func) = _parse_voidp(tuple_get_item(args, 0));
    if ok == 0 {
        getargs_converter_failed(ptr[u8](), 1);
        return (i32(0), ptr(), NULL);
    }
    arguments = tuple_get_item(args, 1);
    if not tuple_check(arguments) {
        getargs_must_be(ptr[u8](), 2, ptr[u8]("tuple"), arguments);
        return (i32(0), ptr(), NULL);
    }
    return (i32(1), func, arguments);
}

impl call_function(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, func, arguments) = parse_call_args(args);
    if ok == 0 {
        return NULL;
    }
    st = get_module_state(self_);
    return _ctypes_callproc(st, func, arguments, 0, NULL, NULL, NULL);
}

impl call_cdeclfunction(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, func, arguments) = parse_call_args(args);
    if ok == 0 {
        return NULL;
    }
    st = get_module_state(self_);
    return _ctypes_callproc(st, func, arguments, FUNCFLAG_CDECL, NULL, NULL, NULL);
}

impl _ctypes_sizeof_impl(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    st = get_module_state(module);

    (res, info) = PyStgInfo_FromType(st, obj_);
    if res < 0 {
        return NULL;
    }
    if info {
        return PyLong_FromSsize_t(info.view(1)[0].size);
    }

    if CDataObject_Check(st, obj_) {
        return PyLong_FromSsize_t(ptr[CDataObject](obj_).view(1)[0].b_size);
    }
    PyErr_SetString(PyExc_TypeError, ptr[u8]("this type has no size"));
    return NULL;
}

impl align_func(self_: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    st = get_module_state(self_);
    (res, info) = PyStgInfo_FromAny(st, obj_);
    if res < 0 {
        return NULL;
    }
    if info {
        return PyLong_FromSsize_t(info.view(1)[0].align);
    }
    PyErr_SetString(PyExc_TypeError, ptr[u8]("no alignment info"));
    return NULL;
}

impl _ctypes_byref_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], offset: i64
) -> ptr[PyObject] {
    st = get_module_state(module);

    parg = PyCArgObject_new(st);
    if not parg {
        return NULL;
    }

    parg.view(1)[0].tag = 80;
    parg.view(1)[0].pffi_type = addressof(ffi_type_pointer);
    parg.view(1)[0].obj_ = object_new_ref(obj_);
    base = ptr[CDataObject](obj_).view(1)[0].b_ptr;
    ptr[ptr[u8]](carg_value_address(parg)).view(1)[0] = base + offset;
    return ptr[PyObject](parg);
}

impl _ctypes_addressof_impl(
    module: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    if PySys_Audit("ctypes.addressof", "(O)", obj_) < 0 {
        return NULL;
    }
    return PyLong_FromVoidPtr(ptr(ptr[CDataObject](obj_).view(1)[0].b_ptr));
}

impl converter(obj_: ptr[PyObject]) -> tuple[i32, ptr] {
    address = PyLong_AsVoidPtr(obj_);
    if not address {
        return (i32(0), address);
    }
    return (i32(1), address);
}

impl My_PyObj_FromPtr(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if not getargs_count(args, ptr[u8]("PyObj_FromPtr"), 1, 1) {
        return NULL;
    }
    (ok, address) = converter(tuple_get_item(args, 0));
    if ok == 0 {
        getargs_converter_failed(ptr[u8]("PyObj_FromPtr"), 1);
        return NULL;
    }
    ob = ptr[PyObject](address);
    if PySys_Audit("ctypes.PyObj_FromPtr", "(O)", ob) < 0 {
        return NULL;
    }
    return object_new_ref(ob);
}

impl My_Py_INCREF(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    object_incref(arg);
    object_incref(arg);
    return arg;
}

impl My_Py_DECREF(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    object_decref(arg);
    object_incref(arg);
    return arg;
}

impl _ctypes_resize_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], size: i64
) -> ptr[PyObject] {
    st = get_module_state(module);
    cdata = ptr[CDataObject](obj_);
    (result, info) = PyStgInfo_FromObject(st, obj_);
    if result < 0 {
        return NULL;
    }
    if not info {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("expected ctypes instance"));
        return NULL;
    }
    if size < info.view(1)[0].size {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("minimum size is %zd"), info.view(1)[0].size
        );
        return NULL;
    }
    if cdata.view(1)[0].b_needsfree == 0 {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("Memory cannot be resized because this object doesn't own it")
        );
        return NULL;
    }
    if size <= SIZEOF_VALUE_UNION {
        cdata.view(1)[0].b_size = size;
        return object_new_ref(Py_None);
    }
    if not _CDataObject_HasExternalBuffer(cdata) {
        block = PyMem_Calloc(1, u64(size));
        if not block {
            return PyErr_NoMemory();
        }
        memmove(block, ptr(cdata.view(1)[0].b_ptr), u64(cdata.view(1)[0].b_size));
        cdata.view(1)[0].b_ptr = ptr[u8](block);
        cdata.view(1)[0].b_size = size;
    } else {
        block = PyMem_Realloc(ptr(cdata.view(1)[0].b_ptr), u64(size));
        if not block {
            return PyErr_NoMemory();
        }
        cdata.view(1)[0].b_ptr = ptr[u8](block);
        cdata.view(1)[0].b_size = size;
    }
    return object_new_ref(Py_None);
}

impl unpickle(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if not getargs_count(args, ptr[u8](), 2, 2) {
        return NULL;
    }
    typ = tuple_get_item(args, 0);
    state = tuple_get_item(args, 1);
    if not tuple_check(state) {
        getargs_must_be(ptr[u8](), 2, ptr[u8]("tuple"), state);
        return NULL;
    }
    slots: own CallprocArgs = CallprocArgs();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(2)[0] = typ;
    stack.view(2)[1] = typ;
    obj_ = PyObject_VectorcallMethod(
        py_id(_Py_ID___new__), stack, u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
    if not obj_ {
        return NULL;
    }

    meth = PyObject_GetAttrString(obj_, ptr[u8]("__setstate__"));
    if not meth {
        object_decref(obj_);
        return NULL;
    }

    result = PyObject_Call(meth, state, NULL);
    object_decref(meth);
    if not result {
        object_decref(obj_);
        return NULL;
    }
    object_decref(result);

    return obj_;
}

impl buffer_info(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    st = get_module_state(self_);
    (res, info) = PyStgInfo_FromAny(st, arg);
    if res < 0 {
        return NULL;
    }
    if not info {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("not a ctypes type or object"));
        return NULL;
    }
    ndim = info.view(1)[0].ndim;
    shape = PyTuple_New(i64(ndim));
    if not shape {
        return NULL;
    }
    i: i64 = 0;
    while i < i64(ndim) {
        dim = (info.view(1)[0].shape + i).view(1)[0];
        tuple_set_item(shape, i, PyLong_FromSsize_t(dim));
        i += 1;
    }

    if PyErr_Occurred() {
        object_decref(shape);
        return NULL;
    }
    return Py_BuildValue(ptr[u8]("siN"), info.view(1)[0].format_, ndim, shape);
}
