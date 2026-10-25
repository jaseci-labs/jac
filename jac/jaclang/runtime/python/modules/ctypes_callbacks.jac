import from c {
    def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  glob:priv cthunk_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr[u8]("CThunkObject")),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(CThunkObject_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(CThunkObject_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(CThunkObject_clear)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob cthunk_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.CThunkObject"),
             basicsize=i32(SIZEOF_CTHUNKOBJECT),
             itemsize=i32(SIZEOF_FFI_TYPE),
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
             ),
             slots=addressof(cthunk_slots)
         ); def _ctypes_alloc_callback(
        st: ptr[ctypes_state],
        callable: ptr[PyObject],
        converters: ptr[PyObject],
        restype: ptr[PyObject],
        flags: i32
    ) -> ptr[CThunkObject] {
        nargs = object_size(converters);
        p = CThunkObject_new(st, nargs);
        if not p {
            return ptr[CThunkObject]();
        }

        p.view(1)[0].pcl_write = Py_ffi_closure_alloc(
            u64(SIZEOF_FFI_CLOSURE), ptr[ptr](ptr[u8](p) + CTHUNK_PCL_EXEC)
        );
        if not p.view(1)[0].pcl_write {
            PyErr_NoMemory();
            object_xdecref(ptr[PyObject](p));
            return ptr[CThunkObject]();
        }

        p.view(1)[0].flags = flags;
        atypes = thunk_atypes(p);
        for i in range(nargs) {
            cnv = tuple_get_item(converters, i);
            (atypes + i).view(1)[0] = ptr[ffi_type](_ctypes_get_ffi_type(st, cnv));
        }
        (atypes + nargs).view(1)[0] = ptr[ffi_type]();

        p.view(1)[0].restype = object_new_ref(restype);
        if restype == Py_None {
            p.view(1)[0].setfunc = ptr();
            p.view(1)[0].ffi_restype = addressof(ffi_type_void);
        } else {
            (status, info) = PyStgInfo_FromType(st, restype);
            if status < 0 {
                object_xdecref(ptr[PyObject](p));
                return ptr[CThunkObject]();
            }
            if not info or not info.view(1)[0].setfunc {
                PyErr_SetString(
                    PyExc_TypeError,
                    ptr[u8]("invalid result type for callback function")
                );
                object_xdecref(ptr[PyObject](p));
                return ptr[CThunkObject]();
            }
            p.view(1)[0].setfunc = info.view(1)[0].setfunc;
            p.view(1)[0].ffi_restype = stginfo_ffi_type(info);
        }

        cc = FFI_DEFAULT_ABI;
        result = ffi_prep_cif(
            thunk_cif(p), cc, u32.wrap(nargs), p.view(1)[0].ffi_restype, thunk_atypes(p)
        );
        if result != FFI_OK {
            PyErr_Format(
                PyExc_RuntimeError, ptr[u8]("ffi_prep_cif failed with %d"), result
            );
            object_xdecref(ptr[PyObject](p));
            return ptr[CThunkObject]();
        }

        result = ffi_prep_closure_loc(
            p.view(1)[0].pcl_write,
            thunk_cif(p),
            ptr(closure_fcn),
            ptr(p),
            p.view(1)[0].pcl_exec
        );
        if result != FFI_OK {
            PyErr_Format(
                PyExc_RuntimeError, ptr[u8]("ffi_prep_closure failed with %d"), result
            );
            object_xdecref(ptr[PyObject](p));
            return ptr[CThunkObject]();
        }

        p.view(1)[0].converters = object_new_ref(converters);
        p.view(1)[0].callable = object_new_ref(callable);
        return p;
    }
}

def CThunkObject_traverse(myself: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def CThunkObject_clear(myself: ptr[PyObject]) -> i32;

def CThunkObject_dealloc(myself: ptr[PyObject]);

def _CallPythonObject(
    st: ptr[ctypes_state],
    mem: ptr,
    restype: ptr[ffi_type],
    setfunc: ptr,
    callable: ptr[PyObject],
    converters: ptr[PyObject],
    flags: i32,
    pArgs: ptr[ptr]
);

def callback_args_release(args: ptr[ptr[PyObject]], count: i64);

def closure_fcn(cif: ptr[ffi_cif], resp: ptr, args: ptr[ptr], userdata: ptr);

def CThunkObject_new(st: ptr[ctypes_state], nargs: i64) -> ptr[CThunkObject];

impl CThunkObject_traverse(myself: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = ptr[CThunkObject](myself);
    vret = visit_reference(ptr[PyObject](object_type(myself)), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(self_.view(1)[0].converters, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(self_.view(1)[0].callable, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(self_.view(1)[0].restype, visitor, arg);
    if vret != 0 {
        return vret;
    }
    return 0;
}

impl CThunkObject_clear(myself: ptr[PyObject]) -> i32 {
    self_ = ptr[CThunkObject](myself);
    old = self_.view(1)[0].converters;
    if old {
        self_.view(1)[0].converters = NULL;
        object_decref(old);
    }
    old = self_.view(1)[0].callable;
    if old {
        self_.view(1)[0].callable = NULL;
        object_decref(old);
    }
    old = self_.view(1)[0].restype;
    if old {
        self_.view(1)[0].restype = NULL;
        object_decref(old);
    }
    return 0;
}

impl CThunkObject_dealloc(myself: ptr[PyObject]) {
    self_ = ptr[CThunkObject](myself);
    tp = object_type(myself);
    PyObject_GC_UnTrack(ptr(self_));
    CThunkObject_clear(myself);
    if self_.view(1)[0].pcl_write {
        Py_ffi_closure_free(self_.view(1)[0].pcl_write);
    }
    PyObject_GC_Del(ptr(self_));
    object_decref(ptr[PyObject](tp));
}

impl _CallPythonObject(
    st: ptr[ctypes_state],
    mem: ptr,
    restype: ptr[ffi_type],
    setfunc: ptr,
    callable: ptr[PyObject],
    converters: ptr[PyObject],
    flags: i32,
    pArgs: ptr[ptr]
) {
    result = NULL;
    error_object = NULL;
    space = ptr[i32]();
    i: i64 = 0;

    nargs = object_size(converters);
    args = ptr[ptr[PyObject]](PyMem_Malloc(u64(nargs) * u64(8)));
    failed = False;
    if not args {
        PyErr_NoMemory();
        failed = True;
    }
    while not failed and i < nargs {
        cnv = tuple_get_item(converters, i);

        (status, info) = PyStgInfo_FromType(st, cnv);
        if status < 0 {
            failed = True;
            break;
        }

        if info and info.view(1)[0].getfunc and _ctypes_simple_instance(st, cnv) == 0 {
            v = call_getfunc(
                info.view(1)[0].getfunc, pArgs.view(1)[0], info.view(1)[0].size
            );
            if not v {
                failed = True;
                break;
            }
            (args + i).view(1)[0] = v;
        } elif info {
            obj_ = PyObject_CallNoArgs(cnv);
            if not obj_ {
                failed = True;
                break;
            }
            if not CDataObject_Check(st, obj_) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("%R returned unexpected result of type %T"),
                    cnv,
                    obj_
                );
                object_decref(obj_);
                failed = True;
                break;
            }
            memcpy(
                ptr(ptr[CDataObject](obj_).view(1)[0].b_ptr),
                pArgs.view(1)[0],
                u64(info.view(1)[0].size)
            );
            (args + i).view(1)[0] = obj_;
        } else {
            PyErr_Format(
                PyExc_TypeError, ptr[u8]("cannot build parameter of type %R"), cnv
            );
            failed = True;
            break;
        }
        pArgs = pArgs + 1;
        i += 1;
    }

    if failed {
        PyErr_FormatUnraisable(
            ptr[u8](
                "Exception ignored while creating argument %zd for ctypes callback function %R"
            ),
            i,
            callable
        );
        callback_args_release(args, i);
        return;
    }

    if (flags & (FUNCFLAG_USE_ERRNO | FUNCFLAG_USE_LASTERROR)) != 0 {
        (errobj, errspace) = ctypes_errobj(st);
        error_object = ptr[PyObject](errobj);
        space = ptr[i32](errspace);
        if not error_object {
            PyErr_FormatUnraisable(
                ptr[u8](
                    "Exception ignored while setting error for ctypes callback function %R"
                ),
                callable
            );
            callback_args_release(args, i);
            return;
        }
        if (flags & FUNCFLAG_USE_ERRNO) != 0 {
            temp = space.view(1)[0];
            space.view(1)[0] = i32.wrap(jacpy_errno());
            jacpy_set_errno(i64(temp));
        }
    }

    result = PyObject_Vectorcall(callable, args, u64(nargs), NULL);
    if not result {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while calling ctypes callback function %R"),
            callable
        );
    }

    if (flags & FUNCFLAG_USE_ERRNO) != 0 {
        temp = space.view(1)[0];
        space.view(1)[0] = i32.wrap(jacpy_errno());
        jacpy_set_errno(i64(temp));
    }
    object_xdecref(error_object);

    if restype != addressof(ffi_type_void) and result {
        keep = call_setfunc(setfunc, mem, result, i64(restype.view(1)[0].size));

        if not keep {
            PyErr_FormatUnraisable(
                ptr[u8](
                    "Exception ignored while converting result of ctypes callback function %R"
                ),
                callable
            );
        } elif int(setfunc)
            != int(
                ptr[fielddesc](_ctypes_get_fielddesc(ptr[u8]("O"))).view(1)[0].setfunc
            ) {
            if keep == Py_None {
                object_decref(keep);
            } elif PyErr_WarnEx(
                PyExc_RuntimeWarning, ptr[u8]("memory leak in callback function."), 1
            )
                == -1 {
                PyErr_FormatUnraisable(
                    ptr[u8](
                        "Exception ignored while converting result of ctypes callback function %R"
                    ),
                    callable
                );
            }
        }
    }

    object_xdecref(result);
    callback_args_release(args, i);
}

impl callback_args_release(args: ptr[ptr[PyObject]], count: i64) {
    if not args {
        return;
    }
    for j in range(count) {
        object_decref((args + j).view(1)[0]);
    }
    PyMem_Free(ptr(args));
}

impl closure_fcn(cif: ptr[ffi_cif], resp: ptr, args: ptr[ptr], userdata: ptr) {
    state = PyGILState_Ensure();

    p = ptr[CThunkObject](userdata);
    st = get_module_state_by_class(object_type(ptr[PyObject](p)));

    _CallPythonObject(
        st,
        resp,
        p.view(1)[0].ffi_restype,
        p.view(1)[0].setfunc,
        p.view(1)[0].callable,
        p.view(1)[0].converters,
        p.view(1)[0].flags,
        args
    );

    PyGILState_Release(state);
}

impl CThunkObject_new(st: ptr[ctypes_state], nargs: i64) -> ptr[CThunkObject] {
    p = ptr[CThunkObject](
        _PyObject_GC_NewVar(ptr[PyObject](st.view(1)[0].PyCThunk_Type), nargs)
    );
    if not p {
        return ptr[CThunkObject]();
    }

    p.view(1)[0].pcl_write = ptr();
    p.view(1)[0].pcl_exec = ptr();
    memset(ptr(thunk_cif(p)), 0, u64(SIZEOF_FFI_CIF));
    p.view(1)[0].flags = 0;
    p.view(1)[0].converters = NULL;
    p.view(1)[0].callable = NULL;
    p.view(1)[0].restype = NULL;
    p.view(1)[0].setfunc = ptr();
    p.view(1)[0].ffi_restype = ptr[ffi_type]();

    atypes = thunk_atypes(p);
    for i in range(nargs + 1) {
        (atypes + i).view(1)[0] = ptr[ffi_type]();
    }
    PyObject_GC_Track(ptr(p));
    return p;
}
