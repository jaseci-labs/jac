import from c {
    glob:priv picklebuf_keywords: list[ptr[u8]] = [ptr[u8](""), ptr[u8]()],
         picklebuf_as_buffer: PyBufferProcs = PyBufferProcs(
             bf_getbuffer=picklebuf_getbuf, bf_releasebuffer=picklebuf_releasebuf
         ),
         picklebuf_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("raw"),
                 ml_meth=ptr(picklebuf_raw),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "raw($self, /)\n--\n\n"
                     "Return a memoryview of the raw memory underlying this buffer.\n"
                     "Will raise BufferError is the buffer isn't contiguous."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("release"),
                 ml_meth=ptr(picklebuf_release),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "release($self, /)\n--\n\n"
                     "Release the underlying buffer exposed by the PickleBuffer object."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyPickleBuffer_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("pickle.PickleBuffer"),
             tp_doc=ptr[u8]("Wrapper for potentially out-of-band buffers"),
             tp_basicsize=PyPickleBufferObject_SIZE,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_new=picklebuf_new,
             tp_dealloc=picklebuf_dealloc,
             tp_traverse=picklebuf_traverse,
             tp_clear=picklebuf_clear,
             tp_weaklistoffset=PyPickleBufferObject_WEAKREFLIST,
             tp_as_buffer=addressof(picklebuf_as_buffer),
             tp_methods=addressof(picklebuf_methods)
         );
}

def picklebuf_of(op: ptr[PyObject]) -> ptr[PyPickleBufferObject];

def view_of(op: ptr[PyObject]) -> ptr[Py_buffer];

def picklebuf_check(op: ptr[PyObject]) -> bool;

def picklebuf_create(_type: ptr[PyTypeObject], base: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def PyPickleBuffer_FromObject(base: ptr[PyObject]) -> ptr[PyObject] {
        return picklebuf_create(addressof(PyPickleBuffer_Type), base);
    }  def PyPickleBuffer_GetBuffer(op: ptr[PyObject]) -> ptr[Py_buffer] {
        if not picklebuf_check(op) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("expected PickleBuffer, %.200s found"),
                object_type(op).view(1)[0].tp_name
            );
            return ptr[Py_buffer]();
        }
        if not view_of(op).view(1)[0].owner {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("operation forbidden on released PickleBuffer object")
            );
            return ptr[Py_buffer]();
        }
        return view_of(op);
    }  def PyPickleBuffer_Release(op: ptr[PyObject]) -> i32 {
        if not picklebuf_check(op) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("expected PickleBuffer, %.200s found"),
                object_type(op).view(1)[0].tp_name
            );
            return i32(-1);
        }
        PyBuffer_Release(view_of(op));
        return i32(0);
    }
}

def picklebuf_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def picklebuf_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def picklebuf_clear(op: ptr[PyObject]) -> i32;

def picklebuf_dealloc(op: ptr[PyObject]);

def picklebuf_getbuf(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32;

def picklebuf_releasebuf(_op: ptr[PyObject], _view: ptr[Py_buffer]);

def picklebuf_raw(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def picklebuf_release(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

impl picklebuf_of(op: ptr[PyObject]) -> ptr[PyPickleBufferObject] {
    return ptr[PyPickleBufferObject](op);
}

impl view_of(op: ptr[PyObject]) -> ptr[Py_buffer] {
    return ptr[Py_buffer](ptr[u8](op) + PyPickleBufferObject_VIEW);
}

impl picklebuf_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyPickleBuffer_Type));
}

impl picklebuf_create(_type: ptr[PyTypeObject], base: ptr[PyObject]) -> ptr[PyObject] {
    op = _type.view(1)[0].tp_alloc(_type, 0);
    if not op {
        return NULL;
    }
    view_of(op).view(1)[0].owner = NULL;
    picklebuf_of(op).view(1)[0].weakreflist = NULL;
    if PyObject_GetBuffer(base, view_of(op), PyBUF_FULL_RO) < 0 {
        jacpy_release(op);
        return NULL;
    }
    return op;
}

impl picklebuf_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    base = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O:PickleBuffer"),
        ptr(addressof(picklebuf_keywords)),
        &mut base
    )
        == 0 {
        return NULL;
    }
    return picklebuf_create(_type, base);
}

impl picklebuf_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(view_of(op).view(1)[0].owner, visitor, arg);
}

impl picklebuf_clear(op: ptr[PyObject]) -> i32 {
    PyBuffer_Release(view_of(op));
    return i32(0);
}

impl picklebuf_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    if picklebuf_of(op).view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    PyBuffer_Release(view_of(op));
    object_type(op).view(1)[0].tp_free(ptr(op));
}

impl picklebuf_getbuf(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32 {
    exporter = view_of(op).view(1)[0].owner;
    if not exporter {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("operation forbidden on released PickleBuffer object")
        );
        return i32(-1);
    }
    return PyObject_GetBuffer(exporter, view, flags);
}

impl picklebuf_releasebuf(_op: ptr[PyObject], _view: ptr[Py_buffer]) {}

impl picklebuf_raw(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    view = view_of(op);
    if not view.view(1)[0].owner {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("operation forbidden on released PickleBuffer object")
        );
        return NULL;
    }
    if view.view(1)[0].suboffsets or PyBuffer_IsContiguous(view, i8(65)) == 0 {
        PyErr_SetString(
            PyExc_BufferError,
            ptr[u8]("cannot extract raw buffer from non-contiguous buffer")
        );
        return NULL;
    }
    m = PyMemoryView_FromObject(op);
    if not m {
        return NULL;
    }

    mv = ptr[Py_buffer](ptr[u8](m) + PyMemoryViewObject_VIEW);
    mv.view(1)[0].format_ = ptr[u8]("B");
    mv.view(1)[0].ndim = 1;
    mv.view(1)[0].itemsize = 1;

    mv.view(1)[0].shape = ptr[i64](ptr[u8](mv) + Py_buffer_LEN);

    mv.view(1)[0].strides = ptr[i64](ptr[u8](mv) + Py_buffer_ITEMSIZE);

    ptr[i32](ptr[u8](m) + PyMemoryViewObject_FLAGS).view(1)[0] = _Py_MEMORYVIEW_C
        | _Py_MEMORYVIEW_FORTRAN;
    return m;
}

impl picklebuf_release(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    PyBuffer_Release(view_of(op));
    return Py_NewRef(Py_None);
}
