import from c {
    glob PyType_Type: PyTypeObject; def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        o: ptr[PyObject],
        buf: ptr,
        len_: i64,
        readonly: i32,
        flags: i32
    ) -> i32;  def PyLong_AsVoidPtr(arg0: ptr[PyObject]) -> ptr;  def PyIter_NextItem(
        iter: ptr[PyObject], item: &mut ptr[PyObject]
    ) -> i32;  def _Py_strhex_with_sep(
        argbuf: ptr, arglen: i64, sep: ptr[PyObject], bytes_per_group: i32
    ) -> ptr[PyObject];  def _PyEval_SliceIndexNotNone(
        arg0: ptr[PyObject], arg1: &mut i64
    ) -> i32;  def PyFloat_Pack2(x: f64, data: ptr[u8], le: i32) -> i32;  def PyFloat_Unpack2(
        data: ptr[u8], le: i32
    ) -> f64;  def strcmp(s1: ptr[u8], s2: ptr[u8]) -> i32;  def strlen(
        s: ptr[u8]
    ) -> u64;  obj BufferProcCall {
        has call: Callable[[ptr[PyObject], ptr[Py_buffer], i32], i32] = 0;
    }  glob:priv memory_as_buffer: PyBufferProcs = PyBufferProcs(
             bf_getbuffer=memory_getbuf, bf_releasebuffer=memory_releasebuf
         ),
         memory_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=memory_length,
             mp_subscript=memory_subscript,
             mp_ass_subscript=memory_ass_sub
         ),
         memory_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_length=memory_length, sq_item=memory_item
         ),
         memory_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("obj"),
                 get=memory_obj_get,
                 doc=ptr[u8]("The underlying object of the memoryview.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("nbytes"),
                 get=memory_nbytes_get,
                 doc=ptr[u8](
                     "The amount of space in bytes that the array would use in\n"
                     " a contiguous representation."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("readonly"),
                 get=memory_readonly_get,
                 doc=ptr[u8]("A bool indicating whether the memory is read only.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("itemsize"),
                 get=memory_itemsize_get,
                 doc=ptr[u8]("The size in bytes of each element of the memoryview.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("format"),
                 get=memory_format_get,
                 doc=ptr[u8](
                     "A string containing the format (in struct module style)\n"
                     " for each element in the view."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("ndim"),
                 get=memory_ndim_get,
                 doc=ptr[u8](
                     "An integer indicating how many dimensions of a multi-dimensional\n"
                     " array the memory represents."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("shape"),
                 get=memory_shape_get,
                 doc=ptr[u8](
                     "A tuple of ndim integers giving the shape of the memory\n"
                     " as an N-dimensional array."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("strides"),
                 get=memory_strides_get,
                 doc=ptr[u8](
                     "A tuple of ndim integers giving the size in bytes to access\n"
                     " each element for each dimension of the array."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("suboffsets"),
                 get=memory_suboffsets_get,
                 doc=ptr[u8](
                     "A tuple of integers used internally for PIL-style arrays."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("c_contiguous"),
                 get=memory_c_contiguous,
                 doc=ptr[u8]("A bool indicating whether the memory is C contiguous.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("f_contiguous"),
                 get=memory_f_contiguous,
                 doc=ptr[u8](
                     "A bool indicating whether the memory is Fortran contiguous."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("contiguous"),
                 get=memory_contiguous,
                 doc=ptr[u8]("A bool indicating whether the memory is contiguous.")
             ),
             PyGetSetDef()
         ],
         memory_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("release"),
                 ml_meth=ptr(memoryview_release),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "release($self, /)\n--\n\n"
                     "Release the underlying buffer exposed by the memoryview object."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("tobytes"),
                 ml_meth=ptr(memoryview_tobytes),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "tobytes($self, /, order='C')\n--\n\n"
                     "Return the data in the buffer as a byte string.\n\n"
                     "Order can be {'C', 'F', 'A'}.  When order is 'C' or 'F', the data of\n"
                     "the original array is converted to C or Fortran order.  For\n"
                     "contiguous views, 'A' returns an exact copy of the physical memory.\n"
                     "In particular, in-memory Fortran order is preserved.  For\n"
                     "non-contiguous views, the data is converted to C first.  order=None\n"
                     "is the same as order='C'."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("hex"),
                 ml_meth=ptr(memoryview_hex),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "hex($self, /, sep=<unrepresentable>, bytes_per_sep=1)\n--\n\n"
                     "Return the data in the buffer as a str of hexadecimal numbers.\n\n"
                     "  sep\n"
                     "    An optional single character or byte to separate hex bytes.\n"
                     "  bytes_per_sep\n"
                     "    How many bytes between separators.  Positive values count from\n"
                     "    the right, negative values count from the left.\n\n"
                     "Example:\n"
                     ">>> value = memoryview(b'\\xb9\\x01\\xef')\n"
                     ">>> value.hex()\n"
                     "'b901ef'\n"
                     ">>> value.hex(':')\n"
                     "'b9:01:ef'\n"
                     ">>> value.hex(':', 2)\n"
                     "'b9:01ef'\n"
                     ">>> value.hex(':', -2)\n"
                     "'b901:ef'"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("tolist"),
                 ml_meth=ptr(memoryview_tolist),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "tolist($self, /)\n--\n\n"
                     "Return the data in the buffer as a list of elements."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("cast"),
                 ml_meth=ptr(memoryview_cast),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "cast($self, /, format, shape=<unrepresentable>)\n--\n\n"
                     "Cast a memoryview to a new format or shape."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("toreadonly"),
                 ml_meth=ptr(memoryview_toreadonly),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "toreadonly($self, /)\n--\n\n"
                     "Return a readonly version of the memoryview."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_from_flags"),
                 ml_meth=ptr(memoryview__from_flags),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS | METH_CLASS,
                 ml_doc=ptr[u8](
                     "_from_flags($type, /, object, flags)\n--\n\n"
                     "Create a new memoryview object which references the given object."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("count"),
                 ml_meth=ptr(memoryview_count),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "count($self, value, /)\n--\n\n"
                     "Count the number of occurrences of a value."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("index"),
                 ml_meth=ptr(memoryview_index),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "index($self, value, start=0, stop=sys.maxsize, /)\n--\n\n"
                     "Return the index of the first occurrence of a value.\n\n"
                     "Raises ValueError if the value is not present."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__enter__"),
                 ml_meth=ptr(memory_enter),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__exit__"),
                 ml_meth=ptr(memory_exit),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "__exit__($self, /, *exc_info)\n--\n\n"
                     "Release the underlying buffer exposed by the memoryview object."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "memoryviews are generic over the type of their underlying data"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob _PyManagedBuffer_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("managedbuffer"),
             tp_basicsize=_PyManagedBufferObject_SIZE,
             tp_dealloc=mbuf_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=mbuf_traverse,
             tp_clear=mbuf_clear
         ),
         _PyMemoryIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("memory_iterator"),
             tp_basicsize=memoryiterobject_SIZE,
             tp_dealloc=memoryiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=memoryiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=memoryiter_next
         ),
         PyMemoryView_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("memoryview"),
             tp_basicsize=PyMemoryViewObject_OB_ARRAY,
             tp_itemsize=8,
             tp_dealloc=memory_dealloc,
             tp_repr=memory_repr,
             tp_as_sequence=addressof(memory_as_sequence),
             tp_as_mapping=addressof(memory_as_mapping),
             tp_hash=memory_hash,
             tp_getattro=PyObject_GenericGetAttr,
             tp_as_buffer=addressof(memory_as_buffer),
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_SEQUENCE,
             tp_doc=ptr[u8](
                 "memoryview(object)\n--\n\n"
                 "Create a new memoryview object which references the given object."
             ),
             tp_traverse=memory_traverse,
             tp_clear=memory_clear,
             tp_richcompare=memory_richcompare,
             tp_weaklistoffset=PyMemoryViewObject_WEAKREFLIST,
             tp_iter=memory_iter,
             tp_methods=addressof(memory_methods),
             tp_getset=addressof(memory_getsetlist),
             tp_new=memoryview_new
         );
}

glob:priv PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     MV_COMPARE_EX: i32 = i32(-1),
     MV_COMPARE_NOT_IMPL: i32 = i32(-2),
     FMT_AT: i64 = 64,
     FMT_CHAR: i64 = 99,
     FMT_BYTE: i64 = 98,
     FMT_UBYTE: i64 = 66,
     FMT_SHORT: i64 = 104,
     FMT_USHORT: i64 = 72,
     FMT_INT: i64 = 105,
     FMT_UINT: i64 = 73,
     FMT_LONG: i64 = 108,
     FMT_ULONG: i64 = 76,
     FMT_LONGLONG: i64 = 113,
     FMT_ULONGLONG: i64 = 81,
     FMT_SSIZE: i64 = 110,
     FMT_SIZE: i64 = 78,
     FMT_FLOAT: i64 = 102,
     FMT_DOUBLE: i64 = 100,
     FMT_HALF: i64 = 101,
     FMT_BOOL: i64 = 63,
     FMT_POINTER: i64 = 80,
     FMT_STRUCT: i64 = 95,
     ORDER_C: i8 = i8(67),
     ORDER_F: i8 = i8(70),
     ORDER_A: i8 = i8(65);

glob:priv memoryview_new_signature = CallSignature(
         "memoryview", ["object"], 1, 1, 0, parser=PARSE_KEYWORDS
     );

glob:priv from_flags_signature = CallSignature(
         "_from_flags", ["object", "flags"], 2, 2, 0, parser=PARSE_KEYWORDS
     );

glob:priv cast_signature = CallSignature(
         "cast", ["format", "shape"], 1, 2, 0, parser=PARSE_KEYWORDS
     );

glob:priv tobytes_signature = CallSignature(
         "tobytes", ["order"], 0, 1, 0, parser=PARSE_KEYWORDS
     );

glob:priv hex_signature = CallSignature(
         "hex", ["sep", "bytes_per_sep"], 0, 2, 0, parser=PARSE_KEYWORDS
     );

obj StructUnpacker {
    has unpack_from: ptr[PyObject] = NULL,
        mview: ptr[PyObject] = NULL,
        item: ptr[u8] = ptr[u8](),
        itemsize: i64 = 0;
}

def mbuf_of(op: ptr[PyObject]) -> ptr[_PyManagedBufferObject];

def master_of(mbuf: ptr[PyObject]) -> ptr[Py_buffer];

def mv_of(op: ptr[PyObject]) -> ptr[PyMemoryViewObject];

def view_of(op: ptr[PyObject]) -> ptr[Py_buffer];

def array_of(op: ptr[PyObject]) -> ptr[i64];

def view_mbuf(op: ptr[PyObject]) -> ptr[PyObject];

def mv_flags(op: ptr[PyObject]) -> i32;

def add_exports(op: ptr[PyObject], delta: i64);

def memoryiter_of(op: ptr[PyObject]) -> ptr[memoryiterobject];

def buffer_size -> i64;

def memoryview_check(op: ptr[PyObject]) -> bool;

def is_tuple(op: ptr[PyObject]) -> bool;

def is_list(op: ptr[PyObject]) -> bool;

def is_long(op: ptr[PyObject]) -> bool;

def is_bytes(op: ptr[PyObject]) -> bool;

def is_unicode(op: ptr[PyObject]) -> bool;

def is_slice(op: ptr[PyObject]) -> bool;

def base_inaccessible(op: ptr[PyObject]) -> bool;

def check_released(op: ptr[PyObject]) -> bool;

def check_restricted(op: ptr[PyObject]) -> bool;

def mv_c_contiguous(flags: i32) -> bool;

def mv_f_contiguous(flags: i32) -> bool;

def mv_any_contiguous(flags: i32) -> bool;

def requested(flags: i32, request: i32) -> bool;

def have_ptr(suboffsets: ptr[i64], dim: i64) -> bool;

def adjust_ptr(p: ptr[u8], suboffsets: ptr[i64], dim: i64) -> ptr[u8];

def next_suboffsets(suboffsets: ptr[i64]) -> ptr[i64];

def fmt_code(fmt: ptr[u8]) -> i64;

def skip_at(fmt: ptr[u8]) -> ptr[u8];

def is_byte_format(c: i64) -> bool;

def native_endian -> i32;

def as_i32(flag: bool) -> i32;

def mbuf_alloc -> ptr[PyObject];

def mbuf_from_object(base: ptr[PyObject], flags: i32) -> ptr[PyObject];

def mbuf_release(mbuf: ptr[PyObject]);

def mbuf_dealloc(op: ptr[PyObject]);

def mbuf_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def mbuf_clear(op: ptr[PyObject]) -> i32;

def have_suboffsets_in_last_dim(view: ptr[Py_buffer]) -> bool;

def last_dim_is_contiguous(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> bool;

def equiv_format(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> bool;

def equiv_shape(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> bool;

def equiv_structure(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> bool;

def copy_base(
    shape: ptr[i64],
    itemsize: i64,
    dptr_in: ptr[u8],
    dstrides: ptr[i64],
    dsuboffsets: ptr[i64],
    sptr_in: ptr[u8],
    sstrides: ptr[i64],
    ssuboffsets: ptr[i64],
    mem: ptr[u8]
);

def copy_rec(
    shape: ptr[i64],
    ndim: i64,
    itemsize: i64,
    dptr_in: ptr[u8],
    dstrides: ptr[i64],
    dsuboffsets: ptr[i64],
    sptr_in: ptr[u8],
    sstrides: ptr[i64],
    ssuboffsets: ptr[i64],
    mem: ptr[u8]
);

def copy_single(op: ptr[PyObject], dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> i32;

def copy_buffer(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> i32;

def init_strides_from_shape(view: ptr[Py_buffer]);

def init_fortran_strides_from_shape(view: ptr[Py_buffer]);

def buffer_to_contiguous(mem: ptr[u8], src: ptr[Py_buffer], order: i8) -> i32;

def init_shared_values(dest: ptr[Py_buffer], src: ptr[Py_buffer]);

def init_shape_strides(dest: ptr[Py_buffer], src: ptr[Py_buffer]);

def init_suboffsets(dest: ptr[Py_buffer], src: ptr[Py_buffer]);

def init_len(view: ptr[Py_buffer]);

def init_flags(op: ptr[PyObject]);

def memory_alloc(ndim: i64) -> ptr[PyObject];

def register_view(op: ptr[PyObject], mbuf: ptr[PyObject]);

def mbuf_add_view(mbuf: ptr[PyObject], src_in: ptr[Py_buffer]) -> ptr[PyObject];

def mbuf_add_incomplete_view(
    mbuf: ptr[PyObject], src_in: ptr[Py_buffer], ndim: i64
) -> ptr[PyObject];

def memory_from_object_and_flags(v: ptr[PyObject], flags: i32) -> ptr[PyObject];

def mbuf_copy_format(mbuf: ptr[PyObject], fmt: ptr[u8]) -> i32;

def memory_from_contiguous_copy(src: ptr[Py_buffer], order: i8) -> ptr[PyObject];

import from c {
    def PyMemoryView_FromMemory(mem: ptr[u8], size: i64, flags: i32) -> ptr[PyObject] {
        mbuf = mbuf_alloc();
        if not mbuf {
            return NULL;
        }
        readonly = i32(0) if flags == PyBUF_WRITE else i32(1);
        PyBuffer_FillInfo(
            master_of(mbuf), NULL, ptr(mem), size, readonly, PyBUF_FULL_RO
        );
        mv = mbuf_add_view(mbuf, ptr[Py_buffer]());
        object_decref(mbuf);
        return mv;
    }  def PyMemoryView_FromBuffer(info: ptr[Py_buffer]) -> ptr[PyObject] {
        if not info.view(1)[0].buf {
            PyErr_SetString(
                PyExc_ValueError,
                "PyMemoryView_FromBuffer(): info->buf must not be NULL"
            );
            return NULL;
        }
        mbuf = mbuf_alloc();
        if not mbuf {
            return NULL;
        }

        master = master_of(mbuf);
        jacpy_memory_copy(ptr(master), ptr(info), buffer_size());
        master.view(1)[0].owner = NULL;
        mv = mbuf_add_view(mbuf, ptr[Py_buffer]());
        object_decref(mbuf);
        return mv;
    }  def _PyMemoryView_FromBufferProc(
        v: ptr[PyObject], flags: i32, bufferproc: ptr
    ) -> ptr[PyObject] {
        mbuf = mbuf_alloc();
        if not mbuf {
            return NULL;
        }
        slot = ptr[BufferProcCall](
            __thread_local_block("jac_object_model_memory_bufferproc_slot", 8)
        );
        slot.view(1)[0].call = int(bufferproc);
        res = slot.view(1)[0].call(v, master_of(mbuf), flags);
        if res < i32(0) {
            master_of(mbuf).view(1)[0].owner = NULL;
            object_decref(mbuf);
            return NULL;
        }
        ret = mbuf_add_view(mbuf, ptr[Py_buffer]());
        object_decref(mbuf);
        return ret;
    }  def PyMemoryView_FromObject(v: ptr[PyObject]) -> ptr[PyObject] {
        return memory_from_object_and_flags(v, PyBUF_FULL_RO);
    }  def PyMemoryView_GetContiguous(
        obj_: ptr[PyObject], buffertype: i32, order: i8
    ) -> ptr[PyObject] {
        mv = PyMemoryView_FromObject(obj_);
        if not mv {
            return NULL;
        }
        view = view_of(mv);
        if buffertype == PyBUF_WRITE and view.view(1)[0].readonly != i32(0) {
            PyErr_SetString(PyExc_BufferError, "underlying buffer is not writable");
            object_decref(mv);
            return NULL;
        }
        if PyBuffer_IsContiguous(view, order) != i32(0) {
            return mv;
        }
        if buffertype == PyBUF_WRITE {
            PyErr_SetString(
                PyExc_BufferError,
                "writable contiguous buffer requested for a non-contiguous object."
            );
            object_decref(mv);
            return NULL;
        }
        ret = memory_from_contiguous_copy(view, order);
        object_decref(mv);
        return ret;
    }  def PyBuffer_ToContiguous(
        buf: ptr, src: ptr[Py_buffer], length: i64, order: i8
    ) -> i32 {
        if length != src.view(1)[0].length {
            PyErr_SetString(
                PyExc_ValueError, "PyBuffer_ToContiguous: len != view->len"
            );
            return i32(-1);
        }
        if PyBuffer_IsContiguous(src, order) != i32(0) {
            jacpy_memory_copy(buf, src.view(1)[0].buf, length);
            return i32(0);
        }

        ndim = i64(src.view(1)[0].ndim);
        fb = ptr[Py_buffer](PyMem_Malloc(u64(buffer_size() + 8 + 3 * ndim * 8)));
        if not fb {
            PyErr_NoMemory();
            return i32(-1);
        }
        array = ptr[i64](ptr[u8](fb) + buffer_size());
        fb.view(1)[0].ndim = src.view(1)[0].ndim;
        fb.view(1)[0].shape = array;
        fb.view(1)[0].strides = array + ndim;
        fb.view(1)[0].suboffsets = array + 2 * ndim;
        init_shared_values(fb, src);
        init_shape_strides(fb, src);
        init_suboffsets(fb, src);
        ret = buffer_to_contiguous(ptr[u8](buf), fb, order);
        PyMem_Free(ptr(fb));
        return ret;
    }
}

def memoryview_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def memoryview_new_bound(args: BoundArguments) -> ptr[PyObject];

def from_flags_impl(object_: ptr[PyObject], flags_obj: ptr[PyObject]) -> ptr[PyObject];

def from_flags_bound(args: BoundArguments) -> ptr[PyObject];

def memoryview__from_flags(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def memory_release_buffer(op: ptr[PyObject]);

def memoryview_release(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def memory_dealloc(op: ptr[PyObject]);

def memory_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def memory_clear(op: ptr[PyObject]) -> i32;

def memory_enter(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def memory_exit(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def get_native_fmtchar(fmt_in: ptr[u8]) -> tuple[i64, i64];

def pick_format(at: bool, with_at: ptr[u8], plain: ptr[u8]) -> ptr[u8];

def get_native_fmtstr(fmt_in: ptr[u8]) -> ptr[u8];

def cast_format(op: ptr[PyObject], dest_fmt: ptr[u8]) -> i32;

def cast_to_1D(op: ptr[PyObject], fmt_obj: ptr[PyObject]) -> i32;

def copy_shape(shape: ptr[i64], seq: ptr[PyObject], ndim: i64, itemsize: i64) -> i64;

def cast_to_ND(op: ptr[PyObject], shape: ptr[PyObject], ndim: i64) -> i32;

def zero_in_shape(op: ptr[PyObject]) -> bool;

def memoryview_cast_impl(
    op: ptr[PyObject], fmt_obj: ptr[PyObject], shape: ptr[PyObject]
) -> ptr[PyObject];

def memoryview_cast_checked(
    op: ptr[PyObject], fmt_obj: ptr[PyObject], shape: ptr[PyObject]
) -> ptr[PyObject];

def memoryview_cast_bound(args: BoundArguments) -> ptr[PyObject];

def memoryview_cast(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def memoryview_toreadonly(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def memory_getbuf(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32;

def memory_releasebuf(op: ptr[PyObject], view: ptr[Py_buffer]);

def type_error_int(fmt: ptr[u8]) -> i32;

def value_error_int(fmt: ptr[u8]) -> i32;

def fix_error_int(fmt: ptr[u8]) -> i32;

def pylong_as_ld(item: ptr[PyObject]) -> i64;

def pylong_as_lu(item: ptr[PyObject]) -> u64;

def pylong_as_lld(item: ptr[PyObject]) -> i64;

def pylong_as_llu(item: ptr[PyObject]) -> u64;

def pylong_as_zd(item: ptr[PyObject]) -> i64;

def pylong_as_zu(item: ptr[PyObject]) -> u64;

def unpack_single(op: ptr[PyObject], p: ptr[u8], fmt: ptr[u8]) -> ptr[PyObject];

def pack_single(
    op: ptr[PyObject], p: ptr[u8], item: ptr[PyObject], fmt: ptr[u8]
) -> i32;

def unpacker_free(x: StructUnpacker);

def struct_get_unpacker(fmt: ptr[u8], itemsize: i64) -> StructUnpacker;

def struct_unpack_single(p: ptr[u8], x: StructUnpacker) -> ptr[PyObject];

def adjust_fmt(view: ptr[Py_buffer]) -> ptr[u8];

def list_set_item(lst: ptr[PyObject], index: i64, item: ptr[PyObject]);

def tolist_base(
    op: ptr[PyObject],
    p_in: ptr[u8],
    shape: ptr[i64],
    strides: ptr[i64],
    suboffsets: ptr[i64],
    fmt: ptr[u8]
) -> ptr[PyObject];

def tolist_rec(
    op: ptr[PyObject],
    p_in: ptr[u8],
    ndim: i64,
    shape: ptr[i64],
    strides: ptr[i64],
    suboffsets: ptr[i64],
    fmt: ptr[u8]
) -> ptr[PyObject];

def memoryview_tolist(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def memoryview_tobytes_impl(op: ptr[PyObject], order: ptr[u8]) -> ptr[PyObject];

def tobytes_order(value: ptr[PyObject]) -> tuple[ptr[u8], bool];

def tobytes_with(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def memoryview_tobytes_bound(args: BoundArguments) -> ptr[PyObject];

def memoryview_tobytes(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def memoryview_hex_impl(
    op: ptr[PyObject], sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject];

def memoryview_hex_bound(args: BoundArguments) -> ptr[PyObject];

def memoryview_hex(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def memory_repr(op: ptr[PyObject]) -> ptr[PyObject];

def lookup_dimension(
    view: ptr[Py_buffer], p: ptr[u8], dim: i64, index_in: i64
) -> ptr[u8];

def ptr_from_index(view: ptr[Py_buffer], index: i64) -> ptr[u8];

def ptr_from_tuple(view: ptr[Py_buffer], tup: ptr[PyObject]) -> ptr[u8];

def memory_item(op: ptr[PyObject], index: i64) -> ptr[PyObject];

def memory_item_multi(op: ptr[PyObject], tup: ptr[PyObject]) -> ptr[PyObject];

def init_slice(base: ptr[Py_buffer], key: ptr[PyObject], dim: i64) -> i32;

def is_multislice(key: ptr[PyObject]) -> bool;

def is_multiindex(key: ptr[PyObject]) -> bool;

def memory_subscript(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];

def assign_slice(
    op: ptr[PyObject], view: ptr[Py_buffer], key: ptr[PyObject], src: ptr[Py_buffer]
) -> i32;

def memory_ass_sub(op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]) -> i32;

def memory_length(op: ptr[PyObject]) -> i64;

def memoryview_count(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def memoryview_index_impl(
    op: ptr[PyObject], value: ptr[PyObject], start_in: i64, stop_in: i64
) -> ptr[PyObject];

def memoryview_index(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def fix_struct_error_int -> i32;

def struct_unpack_cmp(
    p: ptr[u8], q: ptr[u8], unpack_p: StructUnpacker, unpack_q: StructUnpacker
) -> i32;

def unpack_cmp(
    p: ptr[u8], q: ptr[u8], fmt: i64, unpack_p: StructUnpacker, unpack_q: StructUnpacker
) -> i32;

def cmp_base(
    p_in: ptr[u8],
    q_in: ptr[u8],
    shape: ptr[i64],
    pstrides: ptr[i64],
    psuboffsets: ptr[i64],
    qstrides: ptr[i64],
    qsuboffsets: ptr[i64],
    fmt: i64,
    unpack_p: StructUnpacker,
    unpack_q: StructUnpacker
) -> i32;

def cmp_rec(
    p_in: ptr[u8],
    q_in: ptr[u8],
    ndim: i64,
    shape: ptr[i64],
    pstrides: ptr[i64],
    psuboffsets: ptr[i64],
    qstrides: ptr[i64],
    qsuboffsets: ptr[i64],
    fmt: i64,
    unpack_p: StructUnpacker,
    unpack_q: StructUnpacker
) -> i32;

def compare_buffers(vv: ptr[Py_buffer], ww: ptr[Py_buffer]) -> i32;

def memory_equal(v: ptr[PyObject], w: ptr[PyObject]) -> i32;

def memory_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject];

def memory_hash(op: ptr[PyObject]) -> i64;

def int_tuple_from_ssizet(length: i64, vals: ptr[i64]) -> ptr[PyObject];

def memory_obj_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_nbytes_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_format_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_itemsize_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_shape_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_strides_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_suboffsets_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_readonly_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_ndim_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_c_contiguous(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_f_contiguous(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memory_contiguous(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def memoryiter_dealloc(op: ptr[PyObject]);

def memoryiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def memoryiter_next(op: ptr[PyObject]) -> ptr[PyObject];

def memory_iter(seq: ptr[PyObject]) -> ptr[PyObject];

impl mbuf_of(op: ptr[PyObject]) -> ptr[_PyManagedBufferObject] {
    return ptr[_PyManagedBufferObject](op);
}

impl master_of(mbuf: ptr[PyObject]) -> ptr[Py_buffer] {
    return ptr[Py_buffer](ptr[u8](mbuf) + _PyManagedBufferObject_MASTER);
}

impl mv_of(op: ptr[PyObject]) -> ptr[PyMemoryViewObject] {
    return ptr[PyMemoryViewObject](op);
}

impl view_of(op: ptr[PyObject]) -> ptr[Py_buffer] {
    return ptr[Py_buffer](ptr[u8](op) + PyMemoryViewObject_VIEW);
}

impl array_of(op: ptr[PyObject]) -> ptr[i64] {
    return ptr[i64](ptr[u8](op) + PyMemoryViewObject_OB_ARRAY);
}

impl view_mbuf(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](mv_of(op).view(1)[0].mbuf);
}

impl mv_flags(op: ptr[PyObject]) -> i32 {
    return mv_of(op).view(1)[0].flags;
}

impl add_exports(op: ptr[PyObject], delta: i64) {
    mv = mv_of(op);
    mv.view(1)[0].exports = mv.view(1)[0].exports + delta;
}

impl memoryiter_of(op: ptr[PyObject]) -> ptr[memoryiterobject] {
    return ptr[memoryiterobject](op);
}

impl buffer_size -> i64 {
    return i64(PY_BUFFER_SIZE);
}

impl memoryview_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyMemoryView_Type));
}

impl is_tuple(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl is_list(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LIST_SUBCLASS);
}

impl is_long(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl is_bytes(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BYTES_SUBCLASS);
}

impl is_unicode(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl is_slice(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PySlice_Type)));
}

impl base_inaccessible(op: ptr[PyObject]) -> bool {
    if (mv_flags(op) & _Py_MEMORYVIEW_RELEASED) != i32(0) {
        return True;
    }
    return (mbuf_of(view_mbuf(op)).view(1)[0].flags & _Py_MANAGED_BUFFER_RELEASED)
        != i32(0);
}

impl check_released(op: ptr[PyObject]) -> bool {
    if base_inaccessible(op) {
        PyErr_SetString(
            PyExc_ValueError, "operation forbidden on released memoryview object"
        );
        return True;
    }
    return False;
}

impl check_restricted(op: ptr[PyObject]) -> bool {
    if (mv_flags(op) & _Py_MEMORYVIEW_RESTRICTED) != i32(0) {
        PyErr_SetString(
            PyExc_ValueError, "cannot create new view on restricted memoryview"
        );
        return True;
    }
    return False;
}

impl mv_c_contiguous(flags: i32) -> bool {
    return (flags & (_Py_MEMORYVIEW_SCALAR | _Py_MEMORYVIEW_C)) != i32(0);
}

impl mv_f_contiguous(flags: i32) -> bool {
    return (flags & (_Py_MEMORYVIEW_SCALAR | _Py_MEMORYVIEW_FORTRAN)) != i32(0);
}

impl mv_any_contiguous(flags: i32) -> bool {
    layouts = _Py_MEMORYVIEW_SCALAR | _Py_MEMORYVIEW_C | _Py_MEMORYVIEW_FORTRAN;
    return (flags & layouts) != i32(0);
}

impl requested(flags: i32, request: i32) -> bool {
    return (flags & request) == request;
}

impl have_ptr(suboffsets: ptr[i64], dim: i64) -> bool {
    if not suboffsets {
        return False;
    }
    return (suboffsets + dim).view(1)[0] >= 0;
}

impl adjust_ptr(p: ptr[u8], suboffsets: ptr[i64], dim: i64) -> ptr[u8] {
    if have_ptr(suboffsets, dim) {
        return ptr[ptr[u8]](p).view(1)[0] + (suboffsets + dim).view(1)[0];
    }
    return p;
}

impl next_suboffsets(suboffsets: ptr[i64]) -> ptr[i64] {
    if suboffsets {
        return suboffsets + 1;
    }
    return ptr[i64]();
}

impl fmt_code(fmt: ptr[u8]) -> i64 {
    return i64(fmt.view(1)[0]);
}

impl skip_at(fmt: ptr[u8]) -> ptr[u8] {
    if fmt_code(fmt) == FMT_AT {
        return fmt + 1;
    }
    return fmt;
}

impl is_byte_format(c: i64) -> bool {
    return c == FMT_BYTE or c == FMT_UBYTE or c == FMT_CHAR;
}

impl native_endian -> i32 {
    return i32(1) if jacpy_native_little_endian() != 0 else i32(0);
}

impl as_i32(flag: bool) -> i32 {
    return i32(1) if flag else i32(0);
}

impl mbuf_alloc -> ptr[PyObject] {
    mbuf = _PyObject_GC_New(ptr[PyObject](addressof(_PyManagedBuffer_Type)));
    if not mbuf {
        return NULL;
    }
    mbuf_of(mbuf).view(1)[0].flags = i32(0);
    mbuf_of(mbuf).view(1)[0].exports = 0;
    master_of(mbuf).view(1)[0].owner = NULL;
    object_gc_track(mbuf);
    return mbuf;
}

impl mbuf_from_object(base: ptr[PyObject], flags: i32) -> ptr[PyObject] {
    mbuf = mbuf_alloc();
    if not mbuf {
        return NULL;
    }
    if PyObject_GetBuffer(base, master_of(mbuf), flags) < 0 {
        master_of(mbuf).view(1)[0].owner = NULL;
        object_decref(mbuf);
        return NULL;
    }
    return mbuf;
}

impl mbuf_release(mbuf: ptr[PyObject]) {
    flags = mbuf_of(mbuf).view(1)[0].flags;
    if (flags & _Py_MANAGED_BUFFER_RELEASED) != i32(0) {
        return;
    }
    mbuf_of(mbuf).view(1)[0].flags = flags | _Py_MANAGED_BUFFER_RELEASED;

    object_gc_untrack(mbuf);
    PyBuffer_Release(master_of(mbuf));
}

impl mbuf_dealloc(op: ptr[PyObject]) {
    mbuf_release(op);
    if (mbuf_of(op).view(1)[0].flags & _Py_MANAGED_BUFFER_FREE_FORMAT) != i32(0) {
        PyMem_Free(ptr(master_of(op).view(1)[0].format_));
    }
    PyObject_GC_Del(ptr(op));
}

impl mbuf_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(master_of(op).view(1)[0].owner, visitor, arg);
}

impl mbuf_clear(op: ptr[PyObject]) -> i32 {
    mbuf_release(op);
    return i32(0);
}

impl have_suboffsets_in_last_dim(view: ptr[Py_buffer]) -> bool {
    return have_ptr(view.view(1)[0].suboffsets, i64(view.view(1)[0].ndim) - 1);
}

impl last_dim_is_contiguous(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> bool {
    dlast = i64(dest.view(1)[0].ndim) - 1;
    slast = i64(src.view(1)[0].ndim) - 1;
    return not have_suboffsets_in_last_dim(dest)
        and not have_suboffsets_in_last_dim(src)
        and (dest.view(1)[0].strides + dlast).view(1)[0] == dest.view(1)[0].itemsize
        and (src.view(1)[0].strides + slast).view(1)[0] == src.view(1)[0].itemsize;
}

impl equiv_format(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> bool {
    if strcmp(skip_at(dest.view(1)[0].format_), skip_at(src.view(1)[0].format_))
        != i32(0)
        or dest.view(1)[0].itemsize != src.view(1)[0].itemsize {
        return False;
    }
    return True;
}

impl equiv_shape(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> bool {
    ndim = dest.view(1)[0].ndim;
    if ndim != src.view(1)[0].ndim {
        return False;
    }
    dshape = dest.view(1)[0].shape;
    sshape = src.view(1)[0].shape;
    for i in range(i64(ndim)) {
        if (dshape + i).view(1)[0] != (sshape + i).view(1)[0] {
            return False;
        }
        if (dshape + i).view(1)[0] == 0 {
            break;
        }
    }
    return True;
}

impl equiv_structure(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> bool {
    if not equiv_format(dest, src) or not equiv_shape(dest, src) {
        PyErr_SetString(
            PyExc_ValueError,
            "memoryview assignment: lvalue and rvalue have different structures"
        );
        return False;
    }
    return True;
}

impl copy_base(
    shape: ptr[i64],
    itemsize: i64,
    dptr_in: ptr[u8],
    dstrides: ptr[i64],
    dsuboffsets: ptr[i64],
    sptr_in: ptr[u8],
    sstrides: ptr[i64],
    ssuboffsets: ptr[i64],
    mem: ptr[u8]
) {
    if not mem {
        size = shape.view(1)[0] * itemsize;
        if dptr_in + size < sptr_in or sptr_in + size < dptr_in {
            jacpy_memory_copy(ptr(dptr_in), ptr(sptr_in), size);
        } else {
            jacpy_memory_move(ptr(dptr_in), ptr(sptr_in), size);
        }
        return;
    }
    n = shape.view(1)[0];
    p = mem;
    sptr = sptr_in;
    for i in range(n) {
        jacpy_memory_copy(ptr(p), ptr(adjust_ptr(sptr, ssuboffsets, 0)), itemsize);
        p = p + itemsize;
        sptr = sptr + sstrides.view(1)[0];
    }
    p = mem;
    dptr = dptr_in;
    for i in range(n) {
        jacpy_memory_copy(ptr(adjust_ptr(dptr, dsuboffsets, 0)), ptr(p), itemsize);
        p = p + itemsize;
        dptr = dptr + dstrides.view(1)[0];
    }
}

impl copy_rec(
    shape: ptr[i64],
    ndim: i64,
    itemsize: i64,
    dptr_in: ptr[u8],
    dstrides: ptr[i64],
    dsuboffsets: ptr[i64],
    sptr_in: ptr[u8],
    sstrides: ptr[i64],
    ssuboffsets: ptr[i64],
    mem: ptr[u8]
) {
    if ndim == 1 {
        copy_base(
            shape,
            itemsize,
            dptr_in,
            dstrides,
            dsuboffsets,
            sptr_in,
            sstrides,
            ssuboffsets,
            mem
        );
        return;
    }
    dptr = dptr_in;
    sptr = sptr_in;
    for i in range(shape.view(1)[0]) {
        copy_rec(
            shape + 1,
            ndim - 1,
            itemsize,
            adjust_ptr(dptr, dsuboffsets, 0),
            dstrides + 1,
            next_suboffsets(dsuboffsets),
            adjust_ptr(sptr, ssuboffsets, 0),
            sstrides + 1,
            next_suboffsets(ssuboffsets),
            mem
        );
        dptr = dptr + dstrides.view(1)[0];
        sptr = sptr + sstrides.view(1)[0];
    }
}

impl copy_single(op: ptr[PyObject], dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> i32 {
    if check_released(op) {
        return i32(-1);
    }
    if not equiv_structure(dest, src) {
        return i32(-1);
    }
    mem = ptr[u8]();
    if not last_dim_is_contiguous(dest, src) {
        mem = ptr[u8](
            PyMem_Malloc(
                u64(dest.view(1)[0].shape.view(1)[0] * dest.view(1)[0].itemsize)
            )
        );
        if not mem {
            PyErr_NoMemory();
            return i32(-1);
        }
    }
    copy_base(
        dest.view(1)[0].shape,
        dest.view(1)[0].itemsize,
        ptr[u8](dest.view(1)[0].buf),
        dest.view(1)[0].strides,
        dest.view(1)[0].suboffsets,
        ptr[u8](src.view(1)[0].buf),
        src.view(1)[0].strides,
        src.view(1)[0].suboffsets,
        mem
    );
    if mem {
        PyMem_Free(ptr(mem));
    }
    return i32(0);
}

impl copy_buffer(dest: ptr[Py_buffer], src: ptr[Py_buffer]) -> i32 {
    if not equiv_structure(dest, src) {
        return i32(-1);
    }
    mem = ptr[u8]();
    if not last_dim_is_contiguous(dest, src) {
        last = i64(dest.view(1)[0].ndim) - 1;
        mem = ptr[u8](
            PyMem_Malloc(
                u64(
                    (dest.view(1)[0].shape + last).view(1)[0] * dest.view(1)[0].itemsize
                )
            )
        );
        if not mem {
            PyErr_NoMemory();
            return i32(-1);
        }
    }
    copy_rec(
        dest.view(1)[0].shape,
        i64(dest.view(1)[0].ndim),
        dest.view(1)[0].itemsize,
        ptr[u8](dest.view(1)[0].buf),
        dest.view(1)[0].strides,
        dest.view(1)[0].suboffsets,
        ptr[u8](src.view(1)[0].buf),
        src.view(1)[0].strides,
        src.view(1)[0].suboffsets,
        mem
    );
    if mem {
        PyMem_Free(ptr(mem));
    }
    return i32(0);
}

impl init_strides_from_shape(view: ptr[Py_buffer]) {
    shape = view.view(1)[0].shape;
    strides = view.view(1)[0].strides;
    last = i64(view.view(1)[0].ndim) - 1;
    (strides + last).view(1)[0] = view.view(1)[0].itemsize;
    i = last - 1;
    while i >= 0 {
        (strides + i).view(1)[0] = (strides + i + 1).view(1)[0]
            * (shape + i + 1).view(1)[0];
        i -= 1;
    }
}

impl init_fortran_strides_from_shape(view: ptr[Py_buffer]) {
    shape = view.view(1)[0].shape;
    strides = view.view(1)[0].strides;
    strides.view(1)[0] = view.view(1)[0].itemsize;
    for i in range(1, i64(view.view(1)[0].ndim)) {
        (strides + i).view(1)[0] = (strides + i - 1).view(1)[0]
            * (shape + i - 1).view(1)[0];
    }
}

impl buffer_to_contiguous(mem: ptr[u8], src: ptr[Py_buffer], order: i8) -> i32 {
    ndim = i64(src.view(1)[0].ndim);

    dest = ptr[Py_buffer](PyMem_Malloc(u64(buffer_size() + ndim * 8)));
    if not dest {
        PyErr_NoMemory();
        return i32(-1);
    }
    jacpy_memory_copy(ptr(dest), ptr(src), buffer_size());
    dest.view(1)[0].buf = ptr(mem);
    dest.view(1)[0].strides = ptr[i64](ptr[u8](dest) + buffer_size());
    if order == ORDER_C or order == ORDER_A {
        init_strides_from_shape(dest);
    } else {
        init_fortran_strides_from_shape(dest);
    }
    dest.view(1)[0].suboffsets = ptr[i64]();
    ret = copy_buffer(dest, src);
    PyMem_Free(ptr(dest));
    return ret;
}

impl init_shared_values(dest: ptr[Py_buffer], src: ptr[Py_buffer]) {
    dest.view(1)[0].owner = src.view(1)[0].owner;
    dest.view(1)[0].buf = src.view(1)[0].buf;
    dest.view(1)[0].length = src.view(1)[0].length;
    dest.view(1)[0].itemsize = src.view(1)[0].itemsize;
    dest.view(1)[0].readonly = src.view(1)[0].readonly;
    if src.view(1)[0].format_ {
        dest.view(1)[0].format_ = src.view(1)[0].format_;
    } else {
        dest.view(1)[0].format_ = ptr[u8]("B");
    }
    dest.view(1)[0].internal = src.view(1)[0].internal;
}

impl init_shape_strides(dest: ptr[Py_buffer], src: ptr[Py_buffer]) {
    ndim = i64(src.view(1)[0].ndim);
    if ndim == 0 {
        dest.view(1)[0].shape = ptr[i64]();
        dest.view(1)[0].strides = ptr[i64]();
        return;
    }
    sshape = src.view(1)[0].shape;
    sstrides = src.view(1)[0].strides;
    dshape = dest.view(1)[0].shape;
    dstrides = dest.view(1)[0].strides;
    if ndim == 1 {
        if sshape {
            dshape.view(1)[0] = sshape.view(1)[0];
        } else {
            dshape.view(1)[0] = src.view(1)[0].length // src.view(1)[0].itemsize;
        }
        if sstrides {
            dstrides.view(1)[0] = sstrides.view(1)[0];
        } else {
            dstrides.view(1)[0] = src.view(1)[0].itemsize;
        }
        return;
    }
    for i in range(ndim) {
        (dshape + i).view(1)[0] = (sshape + i).view(1)[0];
    }
    if sstrides {
        for i in range(ndim) {
            (dstrides + i).view(1)[0] = (sstrides + i).view(1)[0];
        }
    } else {
        init_strides_from_shape(dest);
    }
}

impl init_suboffsets(dest: ptr[Py_buffer], src: ptr[Py_buffer]) {
    ssub = src.view(1)[0].suboffsets;
    if not ssub {
        dest.view(1)[0].suboffsets = ptr[i64]();
        return;
    }
    dsub = dest.view(1)[0].suboffsets;
    for i in range(i64(src.view(1)[0].ndim)) {
        (dsub + i).view(1)[0] = (ssub + i).view(1)[0];
    }
}

impl init_len(view: ptr[Py_buffer]) {
    length: i64 = 1;
    shape = view.view(1)[0].shape;
    for i in range(i64(view.view(1)[0].ndim)) {
        length *= (shape + i).view(1)[0];
    }
    view.view(1)[0].length = length * view.view(1)[0].itemsize;
}

impl init_flags(op: ptr[PyObject]) {
    view = view_of(op);
    ndim = i64(view.view(1)[0].ndim);
    flags = i32(0);
    if ndim == 0 {
        flags = _Py_MEMORYVIEW_SCALAR | _Py_MEMORYVIEW_C | _Py_MEMORYVIEW_FORTRAN;
    } elif ndim == 1 {
        if view.view(1)[0].shape.view(1)[0] == 1
            or view.view(1)[0].strides.view(1)[0] == view.view(1)[0].itemsize {
            flags = _Py_MEMORYVIEW_C | _Py_MEMORYVIEW_FORTRAN;
        }
    } else {
        if PyBuffer_IsContiguous(view, ORDER_C) != i32(0) {
            flags = flags | _Py_MEMORYVIEW_C;
        }
        if PyBuffer_IsContiguous(view, ORDER_F) != i32(0) {
            flags = flags | _Py_MEMORYVIEW_FORTRAN;
        }
    }
    if view.view(1)[0].suboffsets {
        flags = (flags | _Py_MEMORYVIEW_PIL)
            & ~(_Py_MEMORYVIEW_C | _Py_MEMORYVIEW_FORTRAN);
    }
    mv_of(op).view(1)[0].flags = flags;
}

impl memory_alloc(ndim: i64) -> ptr[PyObject] {
    op = _PyObject_GC_NewVar(ptr[PyObject](addressof(PyMemoryView_Type)), 3 * ndim);
    if not op {
        return NULL;
    }
    mv = mv_of(op);
    mv.view(1)[0].mbuf = ptr[_PyManagedBufferObject]();
    mv.view(1)[0].hash = -1;
    mv.view(1)[0].flags = i32(0);
    mv.view(1)[0].exports = 0;
    view = view_of(op);
    array = array_of(op);
    view.view(1)[0].ndim = i32(ndim);
    view.view(1)[0].shape = array;
    view.view(1)[0].strides = array + ndim;
    view.view(1)[0].suboffsets = array + 2 * ndim;
    mv.view(1)[0].weakreflist = NULL;
    object_gc_track(op);
    return op;
}

impl register_view(op: ptr[PyObject], mbuf: ptr[PyObject]) {
    mv_of(op).view(1)[0].mbuf = ptr[_PyManagedBufferObject](object_new_ref(mbuf));
    m = mbuf_of(mbuf);
    m.view(1)[0].exports = m.view(1)[0].exports + 1;
}

impl mbuf_add_view(mbuf: ptr[PyObject], src_in: ptr[Py_buffer]) -> ptr[PyObject] {
    src = src_in;
    if not src {
        src = master_of(mbuf);
    }
    if i64(src.view(1)[0].ndim) > i64(PyBUF_MAX_NDIM) {
        PyErr_SetString(
            PyExc_ValueError, "memoryview: number of dimensions must not exceed 64"
        );
        return NULL;
    }
    op = memory_alloc(i64(src.view(1)[0].ndim));
    if not op {
        return NULL;
    }
    dest = view_of(op);
    init_shared_values(dest, src);
    init_shape_strides(dest, src);
    init_suboffsets(dest, src);
    init_flags(op);
    register_view(op, mbuf);
    return op;
}

impl mbuf_add_incomplete_view(
    mbuf: ptr[PyObject], src_in: ptr[Py_buffer], ndim: i64
) -> ptr[PyObject] {
    src = src_in;
    if not src {
        src = master_of(mbuf);
    }
    op = memory_alloc(ndim);
    if not op {
        return NULL;
    }
    init_shared_values(view_of(op), src);
    register_view(op, mbuf);
    return op;
}

impl memory_from_object_and_flags(v: ptr[PyObject], flags: i32) -> ptr[PyObject] {
    if memoryview_check(v) {
        if check_released(v) or check_restricted(v) {
            return NULL;
        }
        return mbuf_add_view(view_mbuf(v), view_of(v));
    }
    if PyObject_CheckBuffer(v) != 0 {
        mbuf = mbuf_from_object(v, flags);
        if not mbuf {
            return NULL;
        }
        ret = mbuf_add_view(mbuf, ptr[Py_buffer]());
        object_decref(mbuf);
        return ret;
    }
    PyErr_Format(
        PyExc_TypeError,
        "memoryview: a bytes-like object is required, not '%.200s'",
        object_type(v).view(1)[0].tp_name
    );
    return NULL;
}

impl mbuf_copy_format(mbuf: ptr[PyObject], fmt: ptr[u8]) -> i32 {
    if fmt {
        size = i64(strlen(fmt)) + 1;
        cp = ptr[u8](PyMem_Malloc(u64(size)));
        if not cp {
            PyErr_NoMemory();
            return i32(-1);
        }
        jacpy_memory_copy(ptr(cp), ptr(fmt), size);
        master_of(mbuf).view(1)[0].format_ = cp;
        m = mbuf_of(mbuf);
        m.view(1)[0].flags = m.view(1)[0].flags | _Py_MANAGED_BUFFER_FREE_FORMAT;
    }
    return i32(0);
}

impl memory_from_contiguous_copy(src: ptr[Py_buffer], order: i8) -> ptr[PyObject] {
    ndim = i64(src.view(1)[0].ndim);
    copy = PyBytes_FromStringAndSize(ptr[u8](), src.view(1)[0].length);
    if not copy {
        return NULL;
    }
    mbuf = mbuf_from_object(copy, PyBUF_FULL_RO);
    object_decref(copy);
    if not mbuf {
        return NULL;
    }
    if mbuf_copy_format(mbuf, src.view(1)[0].format_) < 0 {
        object_decref(mbuf);
        return NULL;
    }
    op = mbuf_add_incomplete_view(mbuf, ptr[Py_buffer](), ndim);
    object_decref(mbuf);
    if not op {
        return NULL;
    }
    dest = view_of(op);

    dest.view(1)[0].itemsize = src.view(1)[0].itemsize;
    dshape = dest.view(1)[0].shape;
    sshape = src.view(1)[0].shape;
    for i in range(ndim) {
        (dshape + i).view(1)[0] = (sshape + i).view(1)[0];
    }
    if order == ORDER_C or order == ORDER_A {
        init_strides_from_shape(dest);
    } else {
        init_fortran_strides_from_shape(dest);
    }
    dest.view(1)[0].suboffsets = ptr[i64]();
    init_flags(op);
    if copy_buffer(dest, src) < 0 {
        object_decref(op);
        return NULL;
    }
    return op;
}

impl memoryview_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwargs and object_size(args) == 1 {
        return PyMemoryView_FromObject(tuple_get_item(args, 0));
    }
    return invoke(
        memoryview_new_signature,
        args,
        kwargs,
        memoryview_new_bound,
        ptr[PyObject](type)
    );
}

impl memoryview_new_bound(args: BoundArguments) -> ptr[PyObject] {
    return PyMemoryView_FromObject(args.values[0]);
}

impl from_flags_impl(
    object_: ptr[PyObject], flags_obj: ptr[PyObject]
) -> ptr[PyObject] {
    flags = PyLong_AsInt(flags_obj);
    if flags == i32(-1) and PyErr_Occurred() {
        return NULL;
    }
    return memory_from_object_and_flags(object_, flags);
}

impl from_flags_bound(args: BoundArguments) -> ptr[PyObject] {
    return from_flags_impl(args.values[0], args.values[1]);
}

impl memoryview__from_flags(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 2 and not kwnames {
        return from_flags_impl(args.view(1)[0], (args + 1).view(1)[0]);
    }
    return invoke_vector(
        from_flags_signature, args, nargs, kwnames, from_flags_bound, type
    );
}

impl memory_release_buffer(op: ptr[PyObject]) {
    flags = mv_flags(op);
    if (flags & _Py_MEMORYVIEW_RELEASED) != i32(0) {
        return;
    }
    mv_of(op).view(1)[0].flags = flags | _Py_MEMORYVIEW_RELEASED;
    mbuf = view_mbuf(op);
    m = mbuf_of(mbuf);
    exports = m.view(1)[0].exports - 1;
    m.view(1)[0].exports = exports;
    if exports == 0 {
        mbuf_release(mbuf);
    }
}

impl memoryview_release(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    exports = mv_of(op).view(1)[0].exports;
    if exports == 0 {
        memory_release_buffer(op);
        return object_new_ref(Py_None);
    }
    if exports > 0 {
        suffix = ptr[u8]("s");
        if exports == 1 {
            suffix = ptr[u8]("");
        }
        PyErr_Format(
            PyExc_BufferError, "memoryview has %zd exported buffer%s", exports, suffix
        );
        return NULL;
    }
    PyErr_SetString(PyExc_SystemError, "memoryview: negative export count");
    return NULL;
}

impl memory_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    memory_release_buffer(op);
    mbuf = view_mbuf(op);
    mv_of(op).view(1)[0].mbuf = ptr[_PyManagedBufferObject]();
    object_xdecref(mbuf);
    if mv_of(op).view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    PyObject_GC_Del(ptr(op));
}

impl memory_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(view_mbuf(op), visitor, arg);
}

impl memory_clear(op: ptr[PyObject]) -> i32 {
    if mv_of(op).view(1)[0].exports == 0 {
        memory_release_buffer(op);
        mbuf = view_mbuf(op);
        mv_of(op).view(1)[0].mbuf = ptr[_PyManagedBufferObject]();
        object_xdecref(mbuf);
    }
    return i32(0);
}

impl memory_enter(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    return object_new_ref(op);
}

impl memory_exit(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return memoryview_release(op, NULL);
}

impl get_native_fmtchar(fmt_in: ptr[u8]) -> tuple[i64, i64] {
    fmt = skip_at(fmt_in);
    c = fmt_code(fmt);
    size: i64 = -1;
    if c == FMT_CHAR or c == FMT_BYTE or c == FMT_UBYTE or c == FMT_BOOL {
        size = 1;
    } elif c == FMT_SHORT or c == FMT_USHORT or c == FMT_HALF {
        size = 2;
    } elif c == FMT_INT or c == FMT_UINT or c == FMT_FLOAT {
        size = 4;
    } elif c == FMT_LONG
        or c == FMT_ULONG
        or c == FMT_LONGLONG
        or c == FMT_ULONGLONG
        or c == FMT_SSIZE
        or c == FMT_SIZE
        or c == FMT_DOUBLE
        or c == FMT_POINTER {
        size = 8;
    }
    if size > 0 and (fmt + 1).view(1)[0] == u8(0) {
        return (size, c);
    }
    return (-1, 0);
}

impl pick_format(at: bool, with_at: ptr[u8], plain: ptr[u8]) -> ptr[u8] {
    if at {
        return with_at;
    }
    return plain;
}

impl get_native_fmtstr(fmt_in: ptr[u8]) -> ptr[u8] {
    fmt = fmt_in;
    at = False;
    if fmt_code(fmt) == FMT_AT {
        at = True;
        fmt = fmt + 1;
    }
    if fmt.view(1)[0] == u8(0) or (fmt + 1).view(1)[0] != u8(0) {
        return ptr[u8]();
    }
    c = fmt_code(fmt);
    if c == FMT_CHAR {
        return pick_format(at, ptr[u8]("@c"), ptr[u8]("c"));
    }
    if c == FMT_BYTE {
        return pick_format(at, ptr[u8]("@b"), ptr[u8]("b"));
    }
    if c == FMT_UBYTE {
        return pick_format(at, ptr[u8]("@B"), ptr[u8]("B"));
    }
    if c == FMT_SHORT {
        return pick_format(at, ptr[u8]("@h"), ptr[u8]("h"));
    }
    if c == FMT_USHORT {
        return pick_format(at, ptr[u8]("@H"), ptr[u8]("H"));
    }
    if c == FMT_INT {
        return pick_format(at, ptr[u8]("@i"), ptr[u8]("i"));
    }
    if c == FMT_UINT {
        return pick_format(at, ptr[u8]("@I"), ptr[u8]("I"));
    }
    if c == FMT_LONG {
        return pick_format(at, ptr[u8]("@l"), ptr[u8]("l"));
    }
    if c == FMT_ULONG {
        return pick_format(at, ptr[u8]("@L"), ptr[u8]("L"));
    }
    if c == FMT_LONGLONG {
        return pick_format(at, ptr[u8]("@q"), ptr[u8]("q"));
    }
    if c == FMT_ULONGLONG {
        return pick_format(at, ptr[u8]("@Q"), ptr[u8]("Q"));
    }
    if c == FMT_SSIZE {
        return pick_format(at, ptr[u8]("@n"), ptr[u8]("n"));
    }
    if c == FMT_SIZE {
        return pick_format(at, ptr[u8]("@N"), ptr[u8]("N"));
    }
    if c == FMT_FLOAT {
        return pick_format(at, ptr[u8]("@f"), ptr[u8]("f"));
    }
    if c == FMT_DOUBLE {
        return pick_format(at, ptr[u8]("@d"), ptr[u8]("d"));
    }
    if c == FMT_HALF {
        return pick_format(at, ptr[u8]("@e"), ptr[u8]("e"));
    }
    if c == FMT_BOOL {
        return pick_format(at, ptr[u8]("@?"), ptr[u8]("?"));
    }
    if c == FMT_POINTER {
        return pick_format(at, ptr[u8]("@P"), ptr[u8]("P"));
    }
    return ptr[u8]();
}

impl cast_format(op: ptr[PyObject], dest_fmt: ptr[u8]) -> i32 {
    view = view_of(op);
    (itemsize, destchar) = get_native_fmtchar(dest_fmt);
    if itemsize < 0 {
        PyErr_SetString(
            PyExc_ValueError,
            "memoryview: destination format must be a native single character format prefixed with an optional '@'"
        );
        return i32(-1);
    }
    (srcsize, srcchar) = get_native_fmtchar(view.view(1)[0].format_);
    if (srcsize < 0 or not is_byte_format(srcchar)) and not is_byte_format(destchar) {
        PyErr_SetString(
            PyExc_TypeError, "memoryview: cannot cast between two non-byte formats"
        );
        return i32(-1);
    }
    if view.view(1)[0].length % itemsize != 0 {
        PyErr_SetString(
            PyExc_TypeError, "memoryview: length is not a multiple of itemsize"
        );
        return i32(-1);
    }
    native = get_native_fmtstr(dest_fmt);
    view.view(1)[0].format_ = native;
    if not native {
        PyErr_SetString(PyExc_RuntimeError, "memoryview: internal error");
        return i32(-1);
    }
    view.view(1)[0].itemsize = itemsize;
    view.view(1)[0].ndim = i32(1);
    view.view(1)[0].shape.view(1)[0] = view.view(1)[0].length // itemsize;
    view.view(1)[0].strides.view(1)[0] = itemsize;
    view.view(1)[0].suboffsets = ptr[i64]();
    init_flags(op);
    return i32(0);
}

impl cast_to_1D(op: ptr[PyObject], fmt_obj: ptr[PyObject]) -> i32 {
    asciifmt = PyUnicode_AsASCIIString(fmt_obj);
    if not asciifmt {
        return i32(-1);
    }
    ret = cast_format(op, ptr[u8](PyBytes_AsString(asciifmt)));
    object_decref(asciifmt);
    return ret;
}

impl copy_shape(shape: ptr[i64], seq: ptr[PyObject], ndim: i64, itemsize: i64) -> i64 {
    length = itemsize;
    items = fast_items(seq);
    for i in range(ndim) {
        tmp = (items + i).view(1)[0];
        if not is_long(tmp) {
            PyErr_SetString(
                PyExc_TypeError, "memoryview.cast(): elements of shape must be integers"
            );
            return -1;
        }
        x = PyLong_AsSsize_t(tmp);
        if x == -1 and PyErr_Occurred() {
            return -1;
        }
        if x <= 0 {
            PyErr_Format(
                PyExc_ValueError,
                "memoryview.cast(): elements of shape must be integers > 0"
            );
            return -1;
        }
        if x > PY_SSIZE_T_MAX // length {
            PyErr_Format(
                PyExc_ValueError, "memoryview.cast(): product(shape) > SSIZE_MAX"
            );
            return -1;
        }
        length *= x;
        (shape + i).view(1)[0] = x;
    }
    return length;
}

impl cast_to_ND(op: ptr[PyObject], shape: ptr[PyObject], ndim: i64) -> i32 {
    view = view_of(op);
    length: i64 = 0;
    view.view(1)[0].ndim = i32(ndim);
    if ndim == 0 {
        view.view(1)[0].shape = ptr[i64]();
        view.view(1)[0].strides = ptr[i64]();
        length = view.view(1)[0].itemsize;
    } else {
        length = copy_shape(
            view.view(1)[0].shape, shape, ndim, view.view(1)[0].itemsize
        );
        if length < 0 {
            return i32(-1);
        }
        init_strides_from_shape(view);
    }
    if view.view(1)[0].length != length {
        PyErr_SetString(
            PyExc_TypeError, "memoryview: product(shape) * itemsize != buffer size"
        );
        return i32(-1);
    }
    init_flags(op);
    return i32(0);
}

impl zero_in_shape(op: ptr[PyObject]) -> bool {
    view = view_of(op);
    shape = view.view(1)[0].shape;
    for i in range(i64(view.view(1)[0].ndim)) {
        if (shape + i).view(1)[0] == 0 {
            return True;
        }
    }
    return False;
}

impl memoryview_cast_impl(
    op: ptr[PyObject], fmt_obj: ptr[PyObject], shape: ptr[PyObject]
) -> ptr[PyObject] {
    if check_released(op) or check_restricted(op) {
        return NULL;
    }
    if not mv_c_contiguous(mv_flags(op)) {
        PyErr_SetString(
            PyExc_TypeError, "memoryview: casts are restricted to C-contiguous views"
        );
        return NULL;
    }
    view_ndim = i64(view_of(op).view(1)[0].ndim);
    if (shape != NULL or view_ndim != 1) and zero_in_shape(op) {
        PyErr_SetString(
            PyExc_TypeError,
            "memoryview: cannot cast view with zeros in shape or strides"
        );
        return NULL;
    }
    ndim: i64 = 1;
    if shape {
        if not is_list(shape) and not is_tuple(shape) {
            PyErr_SetString(PyExc_TypeError, "shape must be a list or a tuple");
            return NULL;
        }
        ndim = object_size(shape);
        if ndim > i64(PyBUF_MAX_NDIM) {
            PyErr_SetString(
                PyExc_ValueError, "memoryview: number of dimensions must not exceed 64"
            );
            return NULL;
        }
        if view_ndim != 1 and ndim != 1 {
            PyErr_SetString(
                PyExc_TypeError, "memoryview: cast must be 1D -> ND or ND -> 1D"
            );
            return NULL;
        }
    }
    array_ndim = ndim;
    if ndim == 0 {
        array_ndim = 1;
    }
    mv = mbuf_add_incomplete_view(view_mbuf(op), view_of(op), array_ndim);
    if not mv {
        return NULL;
    }
    if cast_to_1D(mv, fmt_obj) < 0 {
        object_decref(mv);
        return NULL;
    }
    if shape and cast_to_ND(mv, shape, ndim) < 0 {
        object_decref(mv);
        return NULL;
    }
    return mv;
}

impl memoryview_cast_checked(
    op: ptr[PyObject], fmt_obj: ptr[PyObject], shape: ptr[PyObject]
) -> ptr[PyObject] {
    if not is_unicode(fmt_obj) {
        _PyArg_BadArgument(
            ptr[u8]("cast"), ptr[u8]("argument 'format'"), ptr[u8]("str"), fmt_obj
        );
        return NULL;
    }
    return memoryview_cast_impl(op, fmt_obj, shape);
}

impl memoryview_cast_bound(args: BoundArguments) -> ptr[PyObject] {
    return memoryview_cast_checked(args.context, args.values[0], args.values[1]);
}

impl memoryview_cast(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs == 1 {
        return memoryview_cast_checked(op, args.view(1)[0], NULL);
    }
    if not kwnames and nargs == 2 {
        return memoryview_cast_checked(op, args.view(1)[0], (args + 1).view(1)[0]);
    }
    return invoke_vector(
        cast_signature, args, nargs, kwnames, memoryview_cast_bound, op
    );
}

impl memoryview_toreadonly(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    if check_released(op) or check_restricted(op) {
        return NULL;
    }

    mv = mbuf_add_view(view_mbuf(op), view_of(op));
    if mv {
        view_of(mv).view(1)[0].readonly = i32(1);
    }
    return mv;
}

impl memory_getbuf(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32 {
    base = view_of(op);
    baseflags = mv_flags(op);
    if check_released(op) or check_restricted(op) {
        return i32(-1);
    }

    jacpy_memory_copy(ptr(view), ptr(base), buffer_size());
    view.view(1)[0].owner = NULL;
    if (flags & PyBUF_WRITABLE) != i32(0) and base.view(1)[0].readonly != i32(0) {
        PyErr_SetString(
            PyExc_BufferError, "memoryview: underlying buffer is not writable"
        );
        return i32(-1);
    }
    if (flags & PyBUF_FORMAT) == i32(0) {
        view.view(1)[0].format_ = ptr[u8]();
    }
    if requested(flags, PyBUF_C_CONTIGUOUS) and not mv_c_contiguous(baseflags) {
        PyErr_SetString(
            PyExc_BufferError, "memoryview: underlying buffer is not C-contiguous"
        );
        return i32(-1);
    }
    if requested(flags, PyBUF_F_CONTIGUOUS) and not mv_f_contiguous(baseflags) {
        PyErr_SetString(
            PyExc_BufferError, "memoryview: underlying buffer is not Fortran contiguous"
        );
        return i32(-1);
    }
    if requested(flags, PyBUF_ANY_CONTIGUOUS) and not mv_any_contiguous(baseflags) {
        PyErr_SetString(
            PyExc_BufferError, "memoryview: underlying buffer is not contiguous"
        );
        return i32(-1);
    }
    if not requested(flags, PyBUF_INDIRECT)
        and (baseflags & _Py_MEMORYVIEW_PIL) != i32(0) {
        PyErr_SetString(
            PyExc_BufferError, "memoryview: underlying buffer requires suboffsets"
        );
        return i32(-1);
    }
    if not requested(flags, PyBUF_STRIDES) {
        if not mv_c_contiguous(baseflags) {
            PyErr_SetString(
                PyExc_BufferError, "memoryview: underlying buffer is not C-contiguous"
            );
            return i32(-1);
        }
        view.view(1)[0].strides = ptr[i64]();
    }
    if not requested(flags, PyBUF_ND) {
        if view.view(1)[0].format_ {
            PyErr_Format(
                PyExc_BufferError,
                "memoryview: cannot cast to unsigned bytes if the format flag is present"
            );
            return i32(-1);
        }
        view.view(1)[0].ndim = i32(1);
        view.view(1)[0].shape = ptr[i64]();
    }
    view.view(1)[0].owner = object_new_ref(op);
    add_exports(op, 1);
    return i32(0);
}

impl memory_releasebuf(op: ptr[PyObject], view: ptr[Py_buffer]) {
    add_exports(op, -1);
}

impl type_error_int(fmt: ptr[u8]) -> i32 {
    PyErr_Format(PyExc_TypeError, "memoryview: invalid type for format '%s'", fmt);
    return i32(-1);
}

impl value_error_int(fmt: ptr[u8]) -> i32 {
    PyErr_Format(PyExc_ValueError, "memoryview: invalid value for format '%s'", fmt);
    return i32(-1);
}

impl fix_error_int(fmt: ptr[u8]) -> i32 {
    if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
        PyErr_Clear();
        return type_error_int(fmt);
    }
    if PyErr_ExceptionMatches(PyExc_OverflowError) != 0
        or PyErr_ExceptionMatches(PyExc_ValueError) != 0 {
        PyErr_Clear();
        return value_error_int(fmt);
    }
    return i32(-1);
}

impl pylong_as_ld(item: ptr[PyObject]) -> i64 {
    tmp = _PyNumber_Index(item);
    if not tmp {
        return -1;
    }
    ld = PyLong_AsLong(tmp);
    object_decref(tmp);
    return ld;
}

impl pylong_as_lu(item: ptr[PyObject]) -> u64 {
    tmp = _PyNumber_Index(item);
    if not tmp {
        return u64(0xFFFFFFFFFFFFFFFF);
    }
    lu = PyLong_AsUnsignedLong(tmp);
    object_decref(tmp);
    return lu;
}

impl pylong_as_lld(item: ptr[PyObject]) -> i64 {
    tmp = _PyNumber_Index(item);
    if not tmp {
        return -1;
    }
    lld = PyLong_AsLongLong(tmp);
    object_decref(tmp);
    return lld;
}

impl pylong_as_llu(item: ptr[PyObject]) -> u64 {
    tmp = _PyNumber_Index(item);
    if not tmp {
        return u64(0xFFFFFFFFFFFFFFFF);
    }
    llu = PyLong_AsUnsignedLongLong(tmp);
    object_decref(tmp);
    return llu;
}

impl pylong_as_zd(item: ptr[PyObject]) -> i64 {
    tmp = _PyNumber_Index(item);
    if not tmp {
        return -1;
    }
    zd = PyLong_AsSsize_t(tmp);
    object_decref(tmp);
    return zd;
}

impl pylong_as_zu(item: ptr[PyObject]) -> u64 {
    tmp = _PyNumber_Index(item);
    if not tmp {
        return u64(0xFFFFFFFFFFFFFFFF);
    }
    zu = PyLong_AsSize_t(tmp);
    object_decref(tmp);
    return zu;
}

impl unpack_single(op: ptr[PyObject], p: ptr[u8], fmt: ptr[u8]) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    c = fmt_code(fmt);
    if c == FMT_UBYTE {
        return PyLong_FromLong(i64(p.view(1)[0]));
    }
    if c == FMT_BYTE {
        return PyLong_FromLong(i64(ptr[i8](p).view(1)[0]));
    }
    if c == FMT_SHORT {
        return PyLong_FromLong(i64(ptr[i16](p).view(1)[0]));
    }
    if c == FMT_INT {
        return PyLong_FromLong(i64(ptr[i32](p).view(1)[0]));
    }
    if c == FMT_LONG {
        return PyLong_FromLong(ptr[i64](p).view(1)[0]);
    }
    if c == FMT_BOOL {
        return PyBool_FromLong(1 if p.view(1)[0] != u8(0) else 0);
    }
    if c == FMT_USHORT {
        return PyLong_FromUnsignedLong(u64(ptr[u16](p).view(1)[0]));
    }
    if c == FMT_UINT {
        return PyLong_FromUnsignedLong(u64(ptr[u32](p).view(1)[0]));
    }
    if c == FMT_ULONG {
        return PyLong_FromUnsignedLong(ptr[u64](p).view(1)[0]);
    }
    if c == FMT_LONGLONG {
        return PyLong_FromLongLong(ptr[i64](p).view(1)[0]);
    }
    if c == FMT_ULONGLONG {
        return PyLong_FromUnsignedLongLong(ptr[u64](p).view(1)[0]);
    }
    if c == FMT_SSIZE {
        return PyLong_FromSsize_t(ptr[i64](p).view(1)[0]);
    }
    if c == FMT_SIZE {
        return PyLong_FromSize_t(ptr[u64](p).view(1)[0]);
    }
    if c == FMT_FLOAT {
        return PyFloat_FromDouble(f64(ptr[f32](p).view(1)[0]));
    }
    if c == FMT_DOUBLE {
        return PyFloat_FromDouble(ptr[f64](p).view(1)[0]);
    }
    if c == FMT_HALF {
        return PyFloat_FromDouble(PyFloat_Unpack2(p, native_endian()));
    }
    if c == FMT_CHAR {
        return PyBytes_FromStringAndSize(p, 1);
    }
    if c == FMT_POINTER {
        return PyLong_FromVoidPtr(ptr[ptr](p).view(1)[0]);
    }
    PyErr_Format(PyExc_NotImplementedError, "memoryview: format %s not supported", fmt);
    return NULL;
}

impl pack_single(
    op: ptr[PyObject], p: ptr[u8], item: ptr[PyObject], fmt: ptr[u8]
) -> i32 {
    c = fmt_code(fmt);
    if c == FMT_BYTE or c == FMT_SHORT or c == FMT_INT or c == FMT_LONG {
        ld = pylong_as_ld(item);
        if ld == -1 and PyErr_Occurred() {
            return fix_error_int(fmt);
        }
        if check_released(op) {
            return i32(-1);
        }
        if c == FMT_BYTE {
            if ld < -128 or ld > 127 {
                return value_error_int(fmt);
            }
            ptr[i8](p).view(1)[0] = i8(ld);
        } elif c == FMT_SHORT {
            if ld < -32768 or ld > 32767 {
                return value_error_int(fmt);
            }
            ptr[i16](p).view(1)[0] = i16(ld);
        } elif c == FMT_INT {
            if ld < -2147483648 or ld > 2147483647 {
                return value_error_int(fmt);
            }
            ptr[i32](p).view(1)[0] = i32(ld);
        } else {
            ptr[i64](p).view(1)[0] = ld;
        }
        return i32(0);
    }
    if c == FMT_UBYTE or c == FMT_USHORT or c == FMT_UINT or c == FMT_ULONG {
        lu = pylong_as_lu(item);
        if lu == u64(0xFFFFFFFFFFFFFFFF) and PyErr_Occurred() {
            return fix_error_int(fmt);
        }
        if check_released(op) {
            return i32(-1);
        }
        if c == FMT_UBYTE {
            if lu > u64(255) {
                return value_error_int(fmt);
            }
            p.view(1)[0] = u8(lu);
        } elif c == FMT_USHORT {
            if lu > u64(65535) {
                return value_error_int(fmt);
            }
            ptr[u16](p).view(1)[0] = u16(lu);
        } elif c == FMT_UINT {
            if lu > u64(4294967295) {
                return value_error_int(fmt);
            }
            ptr[u32](p).view(1)[0] = u32(lu);
        } else {
            ptr[u64](p).view(1)[0] = lu;
        }
        return i32(0);
    }
    if c == FMT_LONGLONG {
        lld = pylong_as_lld(item);
        if lld == -1 and PyErr_Occurred() {
            return fix_error_int(fmt);
        }
        if check_released(op) {
            return i32(-1);
        }
        ptr[i64](p).view(1)[0] = lld;
        return i32(0);
    }
    if c == FMT_ULONGLONG {
        llu = pylong_as_llu(item);
        if llu == u64(0xFFFFFFFFFFFFFFFF) and PyErr_Occurred() {
            return fix_error_int(fmt);
        }
        if check_released(op) {
            return i32(-1);
        }
        ptr[u64](p).view(1)[0] = llu;
        return i32(0);
    }
    if c == FMT_SSIZE {
        zd = pylong_as_zd(item);
        if zd == -1 and PyErr_Occurred() {
            return fix_error_int(fmt);
        }
        if check_released(op) {
            return i32(-1);
        }
        ptr[i64](p).view(1)[0] = zd;
        return i32(0);
    }
    if c == FMT_SIZE {
        zu = pylong_as_zu(item);
        if zu == u64(0xFFFFFFFFFFFFFFFF) and PyErr_Occurred() {
            return fix_error_int(fmt);
        }
        if check_released(op) {
            return i32(-1);
        }
        ptr[u64](p).view(1)[0] = zu;
        return i32(0);
    }
    if c == FMT_FLOAT or c == FMT_DOUBLE or c == FMT_HALF {
        d = PyFloat_AsDouble(item);
        if d == -1.0 and PyErr_Occurred() {
            return fix_error_int(fmt);
        }
        if check_released(op) {
            return i32(-1);
        }
        if c == FMT_FLOAT {
            ptr[f32](p).view(1)[0] = f32(d);
        } elif c == FMT_DOUBLE {
            ptr[f64](p).view(1)[0] = d;
        } elif PyFloat_Pack2(d, p, native_endian()) < i32(0) {
            return fix_error_int(fmt);
        }
        return i32(0);
    }
    if c == FMT_BOOL {
        truth = PyObject_IsTrue(item);
        if truth < i32(0) {
            return i32(-1);
        }
        if check_released(op) {
            return i32(-1);
        }
        p.view(1)[0] = u8(1) if truth != i32(0) else u8(0);
        return i32(0);
    }
    if c == FMT_CHAR {
        if not is_bytes(item) {
            return type_error_int(fmt);
        }
        if object_size(item) != 1 {
            return value_error_int(fmt);
        }
        p.view(1)[0] = PyBytes_AsString(item).view(1)[0];
        return i32(0);
    }
    if c == FMT_POINTER {
        pv = PyLong_AsVoidPtr(item);
        if not pv and PyErr_Occurred() {
            return fix_error_int(fmt);
        }
        if check_released(op) {
            return i32(-1);
        }
        ptr[ptr](p).view(1)[0] = pv;
        return i32(0);
    }
    PyErr_Format(PyExc_NotImplementedError, "memoryview: format %s not supported", fmt);
    return i32(-1);
}

impl unpacker_free(x: StructUnpacker) {
    object_xdecref(x.unpack_from);
    object_xdecref(x.mview);
    PyMem_Free(ptr(x.item));
    x.unpack_from = NULL;
    x.mview = NULL;
    x.item = ptr[u8]();
    x.itemsize = 0;
}

impl struct_get_unpacker(fmt: ptr[u8], itemsize: i64) -> StructUnpacker {
    struct_type = PyImport_ImportModuleAttrString("struct", "Struct");
    if not struct_type {
        return StructUnpacker();
    }
    x = StructUnpacker();
    complete = False;
    structobj = NULL;
    fmt_bytes = PyBytes_FromString(ptr(fmt));
    if fmt_bytes {
        structobj = PyObject_CallOneArg(struct_type, fmt_bytes);
    }
    if structobj {
        x.unpack_from = PyObject_GetAttrString(structobj, ptr[u8]("unpack_from"));
    }
    if x.unpack_from {
        x.item = ptr[u8](PyMem_Malloc(u64(itemsize)));
        if not x.item {
            PyErr_NoMemory();
        }
    }
    if x.item {
        x.itemsize = itemsize;
        x.mview = PyMemoryView_FromMemory(x.item, itemsize, PyBUF_WRITE);
        if x.mview {
            complete = True;
        }
    }
    if not complete {
        unpacker_free(x);
        x = StructUnpacker();
    }
    object_decref(struct_type);
    object_xdecref(fmt_bytes);
    object_xdecref(structobj);
    return x;
}

impl struct_unpack_single(p: ptr[u8], x: StructUnpacker) -> ptr[PyObject] {
    jacpy_memory_copy(ptr(x.item), ptr(p), x.itemsize);
    v = PyObject_CallOneArg(x.unpack_from, x.mview);
    if not v {
        return NULL;
    }
    if object_size(v) == 1 {
        res = object_new_ref(tuple_get_item(v, 0));
        object_decref(v);
        return res;
    }
    return v;
}

impl adjust_fmt(view: ptr[Py_buffer]) -> ptr[u8] {
    fmt = skip_at(view.view(1)[0].format_);
    if fmt.view(1)[0] != u8(0) and (fmt + 1).view(1)[0] == u8(0) {
        return fmt;
    }
    PyErr_Format(
        PyExc_NotImplementedError,
        "memoryview: unsupported format %s",
        view.view(1)[0].format_
    );
    return ptr[u8]();
}

impl list_set_item(lst: ptr[PyObject], index: i64, item: ptr[PyObject]) {
    (ptr[PyListObject](lst).view(1)[0].ob_item + index).view(1)[0] = item;
}

impl tolist_base(
    op: ptr[PyObject],
    p_in: ptr[u8],
    shape: ptr[i64],
    strides: ptr[i64],
    suboffsets: ptr[i64],
    fmt: ptr[u8]
) -> ptr[PyObject] {
    n = shape.view(1)[0];
    lst = PyList_New(n);
    if not lst {
        return NULL;
    }
    p = p_in;
    for i in range(n) {
        item = unpack_single(op, adjust_ptr(p, suboffsets, 0), fmt);
        if not item {
            object_decref(lst);
            return NULL;
        }
        list_set_item(lst, i, item);
        p = p + strides.view(1)[0];
    }
    return lst;
}

impl tolist_rec(
    op: ptr[PyObject],
    p_in: ptr[u8],
    ndim: i64,
    shape: ptr[i64],
    strides: ptr[i64],
    suboffsets: ptr[i64],
    fmt: ptr[u8]
) -> ptr[PyObject] {
    if ndim == 1 {
        return tolist_base(op, p_in, shape, strides, suboffsets, fmt);
    }
    n = shape.view(1)[0];
    lst = PyList_New(n);
    if not lst {
        return NULL;
    }
    p = p_in;
    for i in range(n) {
        item = tolist_rec(
            op,
            adjust_ptr(p, suboffsets, 0),
            ndim - 1,
            shape + 1,
            strides + 1,
            next_suboffsets(suboffsets),
            fmt
        );
        if not item {
            object_decref(lst);
            return NULL;
        }
        list_set_item(lst, i, item);
        p = p + strides.view(1)[0];
    }
    return lst;
}

impl memoryview_tolist(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    view = view_of(op);
    if check_released(op) {
        return NULL;
    }
    fmt = adjust_fmt(view);
    if not fmt {
        return NULL;
    }
    ndim = i64(view.view(1)[0].ndim);
    buf = ptr[u8](view.view(1)[0].buf);
    if ndim == 0 {
        return unpack_single(op, buf, fmt);
    }
    if ndim == 1 {
        return tolist_base(
            op,
            buf,
            view.view(1)[0].shape,
            view.view(1)[0].strides,
            view.view(1)[0].suboffsets,
            fmt
        );
    }
    return tolist_rec(
        op,
        buf,
        ndim,
        view.view(1)[0].shape,
        view.view(1)[0].strides,
        view.view(1)[0].suboffsets,
        fmt
    );
}

impl memoryview_tobytes_impl(op: ptr[PyObject], order: ptr[u8]) -> ptr[PyObject] {
    src = view_of(op);
    if check_released(op) {
        return NULL;
    }
    order_char = ORDER_C;
    if order {
        if strcmp(order, ptr[u8]("F")) == i32(0) {
            order_char = ORDER_F;
        } elif strcmp(order, ptr[u8]("A")) == i32(0) {
            order_char = ORDER_A;
        } elif strcmp(order, ptr[u8]("C")) != i32(0) {
            PyErr_SetString(PyExc_ValueError, "order must be 'C', 'F' or 'A'");
            return NULL;
        }
    }
    copy = PyBytes_FromStringAndSize(ptr[u8](), src.view(1)[0].length);
    if not copy {
        return NULL;
    }
    if PyBuffer_ToContiguous(
        ptr(PyBytes_AsString(copy)), src, src.view(1)[0].length, order_char
    )
        < i32(0) {
        object_decref(copy);
        return NULL;
    }
    return copy;
}

impl tobytes_order(value: ptr[PyObject]) -> tuple[ptr[u8], bool] {
    if not value or value == Py_None {
        return (ptr[u8](), True);
    }
    if is_unicode(value) {
        length: i64 = 0;
        order = PyUnicode_AsUTF8AndSize(value, &mut length);
        if not order {
            return (ptr[u8](), False);
        }
        if i64(strlen(order)) != length {
            PyErr_SetString(PyExc_ValueError, "embedded null character");
            return (ptr[u8](), False);
        }
        return (order, True);
    }
    _PyArg_BadArgument(
        ptr[u8]("tobytes"), ptr[u8]("argument 'order'"), ptr[u8]("str or None"), value
    );
    return (ptr[u8](), False);
}

impl tobytes_with(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    (order, ok) = tobytes_order(value);
    if not ok {
        return NULL;
    }
    return memoryview_tobytes_impl(op, order);
}

impl memoryview_tobytes_bound(args: BoundArguments) -> ptr[PyObject] {
    return tobytes_with(args.context, args.values[0]);
}

impl memoryview_tobytes(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs == 0 {
        return memoryview_tobytes_impl(op, ptr[u8]());
    }
    if not kwnames and nargs == 1 {
        return tobytes_with(op, args.view(1)[0]);
    }
    return invoke_vector(
        tobytes_signature, args, nargs, kwnames, memoryview_tobytes_bound, op
    );
}

impl memoryview_hex_impl(
    op: ptr[PyObject], sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject] {
    src = view_of(op);
    if check_released(op) {
        return NULL;
    }
    if mv_c_contiguous(mv_flags(op)) {
        add_exports(op, 1);
        ret = _Py_strhex_with_sep(
            src.view(1)[0].buf, src.view(1)[0].length, sep, bytes_per_sep
        );
        add_exports(op, -1);
        return ret;
    }
    copy = PyBytes_FromStringAndSize(ptr[u8](), src.view(1)[0].length);
    if not copy {
        return NULL;
    }
    if PyBuffer_ToContiguous(
        ptr(PyBytes_AsString(copy)), src, src.view(1)[0].length, ORDER_C
    )
        < i32(0) {
        object_decref(copy);
        return NULL;
    }
    ret = _Py_strhex_with_sep(
        ptr(PyBytes_AsString(copy)), object_size(copy), sep, bytes_per_sep
    );
    object_decref(copy);
    return ret;
}

impl memoryview_hex_bound(args: BoundArguments) -> ptr[PyObject] {
    bytes_per_sep = i32(1);
    if args.values[1] {
        bytes_per_sep = PyLong_AsInt(args.values[1]);
        if bytes_per_sep == i32(-1) and PyErr_Occurred() {
            return NULL;
        }
    }
    return memoryview_hex_impl(args.context, args.values[0], bytes_per_sep);
}

impl memoryview_hex(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs == 0 {
        return memoryview_hex_impl(op, NULL, i32(1));
    }
    return invoke_vector(hex_signature, args, nargs, kwnames, memoryview_hex_bound, op);
}

impl memory_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    if (mv_flags(op) & _Py_MEMORYVIEW_RELEASED) != i32(0) {
        return PyUnicode_FromFormat("<released memory at %p>", op);
    }
    return PyUnicode_FromFormat("<memory at %p>", op);
}

impl lookup_dimension(
    view: ptr[Py_buffer], p: ptr[u8], dim: i64, index_in: i64
) -> ptr[u8] {
    nitems = (view.view(1)[0].shape + dim).view(1)[0];
    index = index_in;
    if index < 0 {
        index += nitems;
    }
    if index < 0 or index >= nitems {
        PyErr_Format(
            PyExc_IndexError, "index out of bounds on dimension %d", i32(dim + 1)
        );
        return ptr[u8]();
    }
    q = p + (view.view(1)[0].strides + dim).view(1)[0] * index;
    return adjust_ptr(q, view.view(1)[0].suboffsets, dim);
}

impl ptr_from_index(view: ptr[Py_buffer], index: i64) -> ptr[u8] {
    return lookup_dimension(view, ptr[u8](view.view(1)[0].buf), 0, index);
}

impl ptr_from_tuple(view: ptr[Py_buffer], tup: ptr[PyObject]) -> ptr[u8] {
    p = ptr[u8](view.view(1)[0].buf);
    nindices = object_size(tup);
    if nindices > i64(view.view(1)[0].ndim) {
        PyErr_Format(
            PyExc_TypeError,
            "cannot index %d-dimension view with %zd-element tuple",
            view.view(1)[0].ndim,
            nindices
        );
        return ptr[u8]();
    }
    for dim in range(nindices) {
        index = PyNumber_AsSsize_t(tuple_get_item(tup, dim), PyExc_IndexError);
        if index == -1 and PyErr_Occurred() {
            return ptr[u8]();
        }
        p = lookup_dimension(view, p, dim, index);
        if not p {
            return ptr[u8]();
        }
    }
    return p;
}

impl memory_item(op: ptr[PyObject], index: i64) -> ptr[PyObject] {
    view = view_of(op);
    if check_released(op) {
        return NULL;
    }
    fmt = adjust_fmt(view);
    if not fmt {
        return NULL;
    }
    ndim = i64(view.view(1)[0].ndim);
    if ndim == 0 {
        PyErr_SetString(PyExc_TypeError, "invalid indexing of 0-dim memory");
        return NULL;
    }
    if ndim == 1 {
        p = ptr_from_index(view, index);
        if not p {
            return NULL;
        }
        return unpack_single(op, p, fmt);
    }
    PyErr_SetString(
        PyExc_NotImplementedError, "multi-dimensional sub-views are not implemented"
    );
    return NULL;
}

impl memory_item_multi(op: ptr[PyObject], tup: ptr[PyObject]) -> ptr[PyObject] {
    view = view_of(op);
    nindices = object_size(tup);
    if check_released(op) {
        return NULL;
    }
    fmt = adjust_fmt(view);
    if not fmt {
        return NULL;
    }
    if nindices < i64(view.view(1)[0].ndim) {
        PyErr_SetString(PyExc_NotImplementedError, "sub-views are not implemented");
        return NULL;
    }
    p = ptr_from_tuple(view, tup);
    if not p {
        return NULL;
    }
    return unpack_single(op, p, fmt);
}

impl init_slice(base: ptr[Py_buffer], key: ptr[PyObject], dim: i64) -> i32 {
    start: i64 = 0;
    stop: i64 = 0;
    step: i64 = 0;
    if PySlice_Unpack(key, &mut start, &mut stop, &mut step) < 0 {
        return i32(-1);
    }
    shape = base.view(1)[0].shape;
    strides = base.view(1)[0].strides;
    suboffsets = base.view(1)[0].suboffsets;
    slicelength = PySlice_AdjustIndices(
        (shape + dim).view(1)[0], &mut start, &mut stop, step
    );

    n: i64 = -1;
    if suboffsets and dim != 0 {
        n = dim - 1;
        while n >= 0 and (suboffsets + n).view(1)[0] < 0 {
            n -= 1;
        }
    }
    offset = (strides + dim).view(1)[0] * start;
    if n < 0 {
        base.view(1)[0].buf = ptr(ptr[u8](base.view(1)[0].buf) + offset);
    } else {
        (suboffsets + n).view(1)[0] = (suboffsets + n).view(1)[0] + offset;
    }
    (shape + dim).view(1)[0] = slicelength;
    (strides + dim).view(1)[0] = (strides + dim).view(1)[0] * step;
    return i32(0);
}

impl is_multislice(key: ptr[PyObject]) -> bool {
    if not is_tuple(key) {
        return False;
    }
    size = object_size(key);
    if size == 0 {
        return False;
    }
    for i in range(size) {
        if not is_slice(tuple_get_item(key, i)) {
            return False;
        }
    }
    return True;
}

impl is_multiindex(key: ptr[PyObject]) -> bool {
    if not is_tuple(key) {
        return False;
    }
    for i in range(object_size(key)) {
        if PyIndex_Check(tuple_get_item(key, i)) == 0 {
            return False;
        }
    }
    return True;
}

impl memory_subscript(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    view = view_of(op);
    if check_released(op) {
        return NULL;
    }
    if view.view(1)[0].ndim == i32(0) {
        if is_tuple(key) and object_size(key) == 0 {
            fmt = adjust_fmt(view);
            if not fmt {
                return NULL;
            }
            return unpack_single(op, ptr[u8](view.view(1)[0].buf), fmt);
        }
        if key == Py_Ellipsis {
            return object_new_ref(op);
        }
        PyErr_SetString(PyExc_TypeError, "invalid indexing of 0-dim memory");
        return NULL;
    }
    if PyIndex_Check(key) != 0 {
        index = PyNumber_AsSsize_t(key, PyExc_IndexError);
        if index == -1 and PyErr_Occurred() {
            return NULL;
        }
        return memory_item(op, index);
    }
    if is_slice(key) {
        if check_restricted(op) {
            return NULL;
        }
        sliced = mbuf_add_view(view_mbuf(op), view);
        if not sliced {
            return NULL;
        }
        if init_slice(view_of(sliced), key, 0) < i32(0) {
            object_decref(sliced);
            return NULL;
        }
        init_len(view_of(sliced));
        init_flags(sliced);
        return sliced;
    }
    if is_multiindex(key) {
        return memory_item_multi(op, key);
    }
    if is_multislice(key) {
        PyErr_SetString(
            PyExc_NotImplementedError, "multi-dimensional slicing is not implemented"
        );
        return NULL;
    }
    PyErr_SetString(PyExc_TypeError, "memoryview: invalid slice key");
    return NULL;
}

impl assign_slice(
    op: ptr[PyObject], view: ptr[Py_buffer], key: ptr[PyObject], src: ptr[Py_buffer]
) -> i32 {
    dest = ptr[Py_buffer](PyMem_Malloc(u64(buffer_size() + 3 * 8)));
    if not dest {
        PyErr_NoMemory();
        return i32(-1);
    }
    jacpy_memory_copy(ptr(dest), ptr(view), buffer_size());
    arrays = ptr[i64](ptr[u8](dest) + buffer_size());
    dest.view(1)[0].shape = arrays;
    arrays.view(1)[0] = view.view(1)[0].shape.view(1)[0];
    dest.view(1)[0].strides = arrays + 1;
    (arrays + 1).view(1)[0] = view.view(1)[0].strides.view(1)[0];
    if view.view(1)[0].suboffsets {
        dest.view(1)[0].suboffsets = arrays + 2;
        (arrays + 2).view(1)[0] = view.view(1)[0].suboffsets.view(1)[0];
    }
    ret = i32(-1);
    if init_slice(dest, key, 0) >= i32(0) {
        dest.view(1)[0].length = arrays.view(1)[0] * dest.view(1)[0].itemsize;
        ret = copy_single(op, dest, src);
    }
    PyMem_Free(ptr(dest));
    return ret;
}

impl memory_ass_sub(
    op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    view = view_of(op);
    if check_released(op) {
        return i32(-1);
    }
    fmt = adjust_fmt(view);
    if not fmt {
        return i32(-1);
    }
    if view.view(1)[0].readonly != i32(0) {
        PyErr_SetString(PyExc_TypeError, "cannot modify read-only memory");
        return i32(-1);
    }
    if not value {
        PyErr_SetString(PyExc_TypeError, "cannot delete memory");
        return i32(-1);
    }
    ndim = i64(view.view(1)[0].ndim);
    if ndim == 0 {
        if key == Py_Ellipsis or (is_tuple(key) and object_size(key) == 0) {
            return pack_single(op, ptr[u8](view.view(1)[0].buf), value, fmt);
        }
        PyErr_SetString(PyExc_TypeError, "invalid indexing of 0-dim memory");
        return i32(-1);
    }
    if PyIndex_Check(key) != 0 {
        if 1 < ndim {
            PyErr_SetString(PyExc_NotImplementedError, "sub-views are not implemented");
            return i32(-1);
        }
        index = PyNumber_AsSsize_t(key, PyExc_IndexError);
        if index == -1 and PyErr_Occurred() {
            return i32(-1);
        }
        p = ptr_from_index(view, index);
        if not p {
            return i32(-1);
        }
        return pack_single(op, p, value, fmt);
    }

    if is_slice(key) and ndim == 1 {
        src = ptr[Py_buffer](PyMem_Calloc(1, PY_BUFFER_SIZE));
        if not src {
            PyErr_NoMemory();
            return i32(-1);
        }
        if PyObject_GetBuffer(value, src, PyBUF_FULL_RO) < 0 {
            PyMem_Free(ptr(src));
            return i32(-1);
        }
        ret = assign_slice(op, view, key, src);
        PyBuffer_Release(src);
        PyMem_Free(ptr(src));
        return ret;
    }
    if is_multiindex(key) {
        if object_size(key) < ndim {
            PyErr_SetString(PyExc_NotImplementedError, "sub-views are not implemented");
            return i32(-1);
        }
        p = ptr_from_tuple(view, key);
        if not p {
            return i32(-1);
        }
        return pack_single(op, p, value, fmt);
    }
    if is_slice(key) or is_multislice(key) {
        PyErr_SetString(
            PyExc_NotImplementedError,
            "memoryview slice assignments are currently restricted to ndim = 1"
        );
        return i32(-1);
    }
    PyErr_SetString(PyExc_TypeError, "memoryview: invalid slice key");
    return i32(-1);
}

impl memory_length(op: ptr[PyObject]) -> i64 {
    if check_released(op) {
        return -1;
    }
    view = view_of(op);
    if view.view(1)[0].ndim == i32(0) {
        PyErr_SetString(PyExc_TypeError, "0-dim memory has no length");
        return -1;
    }
    return view.view(1)[0].shape.view(1)[0];
}

impl memoryview_count(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    iter = PyObject_GetIter(op);
    if not iter {
        return NULL;
    }
    count: i64 = 0;
    item: ptr[PyObject] = NULL;
    while PyIter_NextItem(iter, &mut item) != i32(0) {
        if not item {
            object_decref(iter);
            return NULL;
        }
        if item == value {
            object_decref(item);
            count += 1;
            continue;
        }
        contained = PyObject_RichCompareBool(item, value, Py_EQ);
        object_decref(item);
        if contained > 0 {
            count += 1;
        } elif contained < 0 {
            object_decref(iter);
            return NULL;
        }
    }
    object_decref(iter);
    return PyLong_FromSsize_t(count);
}

impl memoryview_index_impl(
    op: ptr[PyObject], value: ptr[PyObject], start_in: i64, stop_in: i64
) -> ptr[PyObject] {
    view = view_of(op);
    if check_released(op) {
        return NULL;
    }
    ndim = i64(view.view(1)[0].ndim);
    if ndim == 0 {
        PyErr_SetString(PyExc_TypeError, "invalid lookup on 0-dim memory");
        return NULL;
    }
    if ndim == 1 {
        n = view.view(1)[0].shape.view(1)[0];
        start = start_in;
        stop = stop_in;
        if start < 0 {
            start = max(start + n, 0);
        }
        if stop < 0 {
            stop = max(stop + n, 0);
        }
        stop = min(stop, n);
        start = min(start, stop);

        for index in range(start, stop) {
            item = memory_item(op, index);
            if not item {
                return NULL;
            }
            if item == value {
                object_decref(item);
                return PyLong_FromSsize_t(index);
            }
            contained = PyObject_RichCompareBool(item, value, Py_EQ);
            object_decref(item);
            if contained > 0 {
                return PyLong_FromSsize_t(index);
            }
            if contained < 0 {
                return NULL;
            }
        }
        PyErr_SetString(PyExc_ValueError, "memoryview.index(x): x not found");
        return NULL;
    }
    PyErr_SetString(
        PyExc_NotImplementedError, "multi-dimensional lookup is not implemented"
    );
    return NULL;
}

impl memoryview_index(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("index"), nargs, 1, 3) == 0 {
        return NULL;
    }
    value = args.view(1)[0];
    start: i64 = 0;
    stop: i64 = PY_SSIZE_T_MAX;
    if nargs >= 2
        and _PyEval_SliceIndexNotNone((args + 1).view(1)[0], &mut start) == 0 {
        return NULL;
    }
    if nargs >= 3
        and _PyEval_SliceIndexNotNone((args + 2).view(1)[0], &mut stop) == 0 {
        return NULL;
    }
    return memoryview_index_impl(op, value, start, stop);
}

impl fix_struct_error_int -> i32 {
    if PyErr_ExceptionMatches(PyExc_ImportError) != 0
        or PyErr_ExceptionMatches(PyExc_MemoryError) != 0 {
        return MV_COMPARE_EX;
    }
    PyErr_Clear();
    return i32(0);
}

impl struct_unpack_cmp(
    p: ptr[u8], q: ptr[u8], unpack_p: StructUnpacker, unpack_q: StructUnpacker
) -> i32 {
    v = struct_unpack_single(p, unpack_p);
    if not v {
        return MV_COMPARE_EX;
    }
    w = struct_unpack_single(q, unpack_q);
    if not w {
        object_decref(v);
        return MV_COMPARE_EX;
    }

    ret = PyObject_RichCompareBool(v, w, Py_EQ);
    object_decref(v);
    object_decref(w);
    return ret;
}

impl unpack_cmp(
    p: ptr[u8], q: ptr[u8], fmt: i64, unpack_p: StructUnpacker, unpack_q: StructUnpacker
) -> i32 {
    if fmt == FMT_UBYTE or fmt == FMT_CHAR {
        return as_i32(p.view(1)[0] == q.view(1)[0]);
    }
    if fmt == FMT_BYTE {
        return as_i32(ptr[i8](p).view(1)[0] == ptr[i8](q).view(1)[0]);
    }
    if fmt == FMT_SHORT {
        return as_i32(ptr[i16](p).view(1)[0] == ptr[i16](q).view(1)[0]);
    }
    if fmt == FMT_INT {
        return as_i32(ptr[i32](p).view(1)[0] == ptr[i32](q).view(1)[0]);
    }
    if fmt == FMT_LONG or fmt == FMT_LONGLONG or fmt == FMT_SSIZE {
        return as_i32(ptr[i64](p).view(1)[0] == ptr[i64](q).view(1)[0]);
    }
    if fmt == FMT_BOOL {
        return as_i32((p.view(1)[0] != u8(0)) == (q.view(1)[0] != u8(0)));
    }
    if fmt == FMT_USHORT {
        return as_i32(ptr[u16](p).view(1)[0] == ptr[u16](q).view(1)[0]);
    }
    if fmt == FMT_UINT {
        return as_i32(ptr[u32](p).view(1)[0] == ptr[u32](q).view(1)[0]);
    }
    if fmt == FMT_ULONG
        or fmt == FMT_ULONGLONG
        or fmt == FMT_SIZE
        or fmt == FMT_POINTER {
        return as_i32(ptr[u64](p).view(1)[0] == ptr[u64](q).view(1)[0]);
    }
    if fmt == FMT_FLOAT {
        return as_i32(ptr[f32](p).view(1)[0] == ptr[f32](q).view(1)[0]);
    }
    if fmt == FMT_DOUBLE {
        return as_i32(ptr[f64](p).view(1)[0] == ptr[f64](q).view(1)[0]);
    }
    if fmt == FMT_HALF {
        endian = native_endian();
        return as_i32(PyFloat_Unpack2(p, endian) == PyFloat_Unpack2(q, endian));
    }
    if fmt == FMT_STRUCT {
        return struct_unpack_cmp(p, q, unpack_p, unpack_q);
    }

    PyErr_SetString(PyExc_RuntimeError, "memoryview: internal error in richcompare");
    return MV_COMPARE_EX;
}

impl cmp_base(
    p_in: ptr[u8],
    q_in: ptr[u8],
    shape: ptr[i64],
    pstrides: ptr[i64],
    psuboffsets: ptr[i64],
    qstrides: ptr[i64],
    qsuboffsets: ptr[i64],
    fmt: i64,
    unpack_p: StructUnpacker,
    unpack_q: StructUnpacker
) -> i32 {
    p = p_in;
    q = q_in;
    for i in range(shape.view(1)[0]) {
        equal = unpack_cmp(
            adjust_ptr(p, psuboffsets, 0),
            adjust_ptr(q, qsuboffsets, 0),
            fmt,
            unpack_p,
            unpack_q
        );
        if equal <= i32(0) {
            return equal;
        }
        p = p + pstrides.view(1)[0];
        q = q + qstrides.view(1)[0];
    }
    return i32(1);
}

impl cmp_rec(
    p_in: ptr[u8],
    q_in: ptr[u8],
    ndim: i64,
    shape: ptr[i64],
    pstrides: ptr[i64],
    psuboffsets: ptr[i64],
    qstrides: ptr[i64],
    qsuboffsets: ptr[i64],
    fmt: i64,
    unpack_p: StructUnpacker,
    unpack_q: StructUnpacker
) -> i32 {
    if ndim == 1 {
        return cmp_base(
            p_in,
            q_in,
            shape,
            pstrides,
            psuboffsets,
            qstrides,
            qsuboffsets,
            fmt,
            unpack_p,
            unpack_q
        );
    }
    p = p_in;
    q = q_in;
    for i in range(shape.view(1)[0]) {
        equal = cmp_rec(
            adjust_ptr(p, psuboffsets, 0),
            adjust_ptr(q, qsuboffsets, 0),
            ndim - 1,
            shape + 1,
            pstrides + 1,
            next_suboffsets(psuboffsets),
            qstrides + 1,
            next_suboffsets(qsuboffsets),
            fmt,
            unpack_p,
            unpack_q
        );
        if equal <= i32(0) {
            return equal;
        }
        p = p + pstrides.view(1)[0];
        q = q + qstrides.view(1)[0];
    }
    return i32(1);
}

impl compare_buffers(vv: ptr[Py_buffer], ww: ptr[Py_buffer]) -> i32 {
    if not equiv_shape(vv, ww) {
        PyErr_Clear();
        return i32(0);
    }
    (vsize, vfmt) = get_native_fmtchar(vv.view(1)[0].format_);
    if vsize < 0 {
        vfmt = FMT_STRUCT;
    }
    (wsize, wfmt) = get_native_fmtchar(ww.view(1)[0].format_);
    if wsize < 0 {
        wfmt = FMT_STRUCT;
    }
    unpack_v = StructUnpacker();
    unpack_w = StructUnpacker();
    if vfmt == FMT_STRUCT or wfmt == FMT_STRUCT or vfmt != wfmt {
        vfmt = FMT_STRUCT;
        unpack_v = struct_get_unpacker(vv.view(1)[0].format_, vv.view(1)[0].itemsize);
        if not unpack_v.unpack_from {
            return fix_struct_error_int();
        }
        unpack_w = struct_get_unpacker(ww.view(1)[0].format_, ww.view(1)[0].itemsize);
        if not unpack_w.unpack_from {
            equal = fix_struct_error_int();
            unpacker_free(unpack_v);
            return equal;
        }
    }
    ndim = i64(vv.view(1)[0].ndim);
    vbuf = ptr[u8](vv.view(1)[0].buf);
    wbuf = ptr[u8](ww.view(1)[0].buf);
    equal = i32(0);
    if ndim == 0 {
        equal = unpack_cmp(vbuf, wbuf, vfmt, unpack_v, unpack_w);
    } elif ndim == 1 {
        equal = cmp_base(
            vbuf,
            wbuf,
            vv.view(1)[0].shape,
            vv.view(1)[0].strides,
            vv.view(1)[0].suboffsets,
            ww.view(1)[0].strides,
            ww.view(1)[0].suboffsets,
            vfmt,
            unpack_v,
            unpack_w
        );
    } else {
        equal = cmp_rec(
            vbuf,
            wbuf,
            ndim,
            vv.view(1)[0].shape,
            vv.view(1)[0].strides,
            vv.view(1)[0].suboffsets,
            ww.view(1)[0].strides,
            ww.view(1)[0].suboffsets,
            vfmt,
            unpack_v,
            unpack_w
        );
    }
    unpacker_free(unpack_v);
    unpacker_free(unpack_w);
    return equal;
}

impl memory_equal(v: ptr[PyObject], w: ptr[PyObject]) -> i32 {
    if base_inaccessible(v) {
        return as_i32(v == w);
    }
    if memoryview_check(w) {
        if base_inaccessible(w) {
            return as_i32(v == w);
        }
        return compare_buffers(view_of(v), view_of(w));
    }
    wbuf = ptr[Py_buffer](PyMem_Calloc(1, PY_BUFFER_SIZE));
    if not wbuf {
        PyErr_NoMemory();
        return MV_COMPARE_EX;
    }
    if PyObject_GetBuffer(w, wbuf, PyBUF_FULL_RO) < 0 {
        PyErr_Clear();
        PyMem_Free(ptr(wbuf));
        return MV_COMPARE_NOT_IMPL;
    }
    equal = compare_buffers(view_of(v), wbuf);
    PyBuffer_Release(wbuf);
    PyMem_Free(ptr(wbuf));
    return equal;
}

impl memory_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    equal = MV_COMPARE_NOT_IMPL;
    if op == Py_EQ or op == Py_NE {
        equal = memory_equal(v, w);
    }
    if equal == MV_COMPARE_NOT_IMPL {
        return object_new_ref(Py_NotImplemented);
    }
    if equal < i32(0) {
        return NULL;
    }
    if (equal != i32(0) and op == Py_EQ) or (equal == i32(0) and op == Py_NE) {
        return PyBool_FromLong(1);
    }
    return PyBool_FromLong(0);
}

impl memory_hash(op: ptr[PyObject]) -> i64 {
    mv = mv_of(op);
    if mv.view(1)[0].hash == -1 {
        view = view_of(op);
        if check_released(op) {
            return -1;
        }
        if view.view(1)[0].readonly == i32(0) {
            PyErr_SetString(PyExc_ValueError, "cannot hash writable memoryview object");
            return -1;
        }
        (size, fmt) = get_native_fmtchar(view.view(1)[0].format_);
        if size < 0 or not is_byte_format(fmt) {
            PyErr_SetString(
                PyExc_ValueError,
                "memoryview: hashing is restricted to formats 'B', 'b' or 'c'"
            );
            return -1;
        }
        owner = view.view(1)[0].owner;
        if owner {
            add_exports(op, 1);
            h = PyObject_Hash(owner);
            add_exports(op, -1);
            if h == -1 {
                return -1;
            }
        }
        length = view.view(1)[0].length;
        mem = ptr[u8](view.view(1)[0].buf);
        copied = False;
        if not mv_c_contiguous(mv_flags(op)) {
            mem = ptr[u8](PyMem_Malloc(u64(length)));
            if not mem {
                PyErr_NoMemory();
                return -1;
            }
            if buffer_to_contiguous(mem, view, ORDER_C) < i32(0) {
                PyMem_Free(ptr(mem));
                return -1;
            }
            copied = True;
        }

        mv.view(1)[0].hash = Py_HashBuffer(ptr(mem), length);
        if copied {
            PyMem_Free(ptr(mem));
        }
    }
    return mv.view(1)[0].hash;
}

impl int_tuple_from_ssizet(length: i64, vals: ptr[i64]) -> ptr[PyObject] {
    if not vals {
        return PyTuple_New(0);
    }
    int_tuple = PyTuple_New(length);
    if not int_tuple {
        return NULL;
    }
    for i in range(length) {
        o = PyLong_FromSsize_t((vals + i).view(1)[0]);
        if not o {
            object_decref(int_tuple);
            return NULL;
        }
        tuple_set_item(int_tuple, i, o);
    }
    return int_tuple;
}

impl memory_obj_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    owner = view_of(op).view(1)[0].owner;
    if not owner {
        return object_new_ref(Py_None);
    }
    return object_new_ref(owner);
}

impl memory_nbytes_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    return PyLong_FromSsize_t(view_of(op).view(1)[0].length);
}

impl memory_format_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    return PyUnicode_FromString(view_of(op).view(1)[0].format_);
}

impl memory_itemsize_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    return PyLong_FromSsize_t(view_of(op).view(1)[0].itemsize);
}

impl memory_shape_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    view = view_of(op);
    return int_tuple_from_ssizet(i64(view.view(1)[0].ndim), view.view(1)[0].shape);
}

impl memory_strides_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    view = view_of(op);
    return int_tuple_from_ssizet(i64(view.view(1)[0].ndim), view.view(1)[0].strides);
}

impl memory_suboffsets_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    view = view_of(op);
    return int_tuple_from_ssizet(i64(view.view(1)[0].ndim), view.view(1)[0].suboffsets);
}

impl memory_readonly_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    return PyBool_FromLong(i64(view_of(op).view(1)[0].readonly));
}

impl memory_ndim_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    return PyLong_FromLong(i64(view_of(op).view(1)[0].ndim));
}

impl memory_c_contiguous(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    return PyBool_FromLong(1 if mv_c_contiguous(mv_flags(op)) else 0);
}

impl memory_f_contiguous(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    return PyBool_FromLong(1 if mv_f_contiguous(mv_flags(op)) else 0);
}

impl memory_contiguous(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if check_released(op) {
        return NULL;
    }
    return PyBool_FromLong(1 if mv_any_contiguous(mv_flags(op)) else 0);
}

impl memoryiter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_xdecref(ptr[PyObject](memoryiter_of(op).view(1)[0].it_seq));
    PyObject_GC_Del(ptr(op));
}

impl memoryiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(
        ptr[PyObject](memoryiter_of(op).view(1)[0].it_seq), visitor, arg
    );
}

impl memoryiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = memoryiter_of(op);

    seq = ptr[PyObject](it.view(1)[0].it_seq);
    if not seq {
        return NULL;
    }
    index = it.view(1)[0].it_index;
    if index < it.view(1)[0].it_length {
        if check_released(seq) {
            return NULL;
        }
        view = view_of(seq);
        it.view(1)[0].it_index = index + 1;
        p = ptr[u8](view.view(1)[0].buf) + view.view(1)[0].strides.view(1)[0] * index;
        p = adjust_ptr(p, view.view(1)[0].suboffsets, 0);
        if not p {
            return NULL;
        }
        return unpack_single(seq, p, it.view(1)[0].it_fmt);
    }
    it.view(1)[0].it_seq = ptr[PyMemoryViewObject]();
    object_decref(seq);
    return NULL;
}

impl memory_iter(seq: ptr[PyObject]) -> ptr[PyObject] {
    if not memoryview_check(seq) {
        PyErr_BadInternalCall();
        return NULL;
    }
    if check_released(seq) {
        return NULL;
    }
    view = view_of(seq);
    ndims = i64(view.view(1)[0].ndim);
    if ndims == 0 {
        PyErr_SetString(PyExc_TypeError, "invalid indexing of 0-dim memory");
        return NULL;
    }
    if ndims != 1 {
        PyErr_SetString(
            PyExc_NotImplementedError, "multi-dimensional sub-views are not implemented"
        );
        return NULL;
    }
    fmt = adjust_fmt(view);
    if not fmt {
        return NULL;
    }
    op = _PyObject_GC_New(ptr[PyObject](addressof(_PyMemoryIter_Type)));
    if not op {
        return NULL;
    }
    it = memoryiter_of(op);
    it.view(1)[0].it_fmt = fmt;
    it.view(1)[0].it_length = memory_length(seq);
    it.view(1)[0].it_index = 0;
    it.view(1)[0].it_seq = ptr[PyMemoryViewObject](object_new_ref(seq));
    object_gc_track(op);
    return op;
}
