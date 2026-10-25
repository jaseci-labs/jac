import from c {
    def Py_GenericAlias(origin: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];  def PySeqIter_New(
        seq: ptr[PyObject]
    ) -> ptr[PyObject];  def PyDict_Values(op: ptr[PyObject]) -> ptr[PyObject];  def PyLong_FromUnicodeObject(
        u: ptr[PyObject], base: i32
    ) -> ptr[PyObject];  def _PyLong_Copy(src: ptr[PyLongObject]) -> ptr[PyObject];  def _PyLong_Format(
        ob: ptr[PyObject], base: i32
    ) -> ptr[PyObject];  def _PyLong_FromBytes(
        s: ptr[u8], length: i64, base: i32
    ) -> ptr[PyObject];  def _PyList_Extend(
        op: ptr[PyObject], iterable: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyList_AsTupleAndClear(
        op: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyList_AppendTakeRefListResize(
        op: ptr[PyObject], newitem: ptr[PyObject]
    ) -> i32;  def _PyTuple_FromArraySteal(
        src: ptr[ptr[PyObject]], n: i64
    ) -> ptr[PyObject];  def _Py_union_args(op: ptr[PyObject]) -> ptr[PyObject];  def _PySlice_FromIndices(
        istart: i64, istop: i64
    ) -> ptr[PyObject];  def _PyObject_NextNotImplemented(
        op: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_CallInInterpreter(
        interp: ptr[PyInterpreterState], func: ptr, arg: ptr
    ) -> i32;  def _Py_CallInInterpreterAndRawFree(
        interp: ptr[PyInterpreterState], func: ptr, arg: ptr
    ) -> i32;  def PyUnicode_FromStringAndSize(
        u: ptr[u8], size: i64
    ) -> ptr[PyObject];  def Py_EnterRecursiveCall(where: ptr[u8]) -> i32;  def strlen(
        s: ptr[u8]
    ) -> u64;  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  obj StackSlots {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject](),
            s5: ptr[PyObject] = ptr[PyObject](),
            s6: ptr[PyObject] = ptr[PyObject](),
            s7: ptr[PyObject] = ptr[PyObject](),
            s8: ptr[PyObject] = ptr[PyObject](),
            s9: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut StackSlots) -> int;  obj NumberCall {
        has binary: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            ternary:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            repeat: Callable[[ptr[PyObject], i64], ptr[PyObject]] = 0;
    }  glob:priv length_hint_key: ptr[PyObject] = ptr[PyObject](),
         class_getitem_key: ptr[PyObject] = ptr[PyObject](),
         format_key: ptr[PyObject] = ptr[PyObject](),
         keys_key: ptr[PyObject] = ptr[PyObject](),
         items_key: ptr[PyObject] = ptr[PyObject](),
         values_key: ptr[PyObject] = ptr[PyObject](),
         bases_key: ptr[PyObject] = ptr[PyObject](),
         class_key: ptr[PyObject] = ptr[PyObject](),
         instancecheck_key: ptr[PyObject] = ptr[PyObject](),
         subclasscheck_key: ptr[PyObject] = ptr[PyObject](),
         send_key: ptr[PyObject] = ptr[PyObject]();
}

glob:priv PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     PY_SSIZE_T_MIN: i64 = -0x7FFFFFFFFFFFFFFF - 1,
     LONG_SIGN_NEGATIVE: u64 = u64(2),
     ORDER_C: i8 = i8(67),
     ORDER_F: i8 = i8(70),
     ORDER_A: i8 = i8(65);

def interned_length_hint -> ptr[PyObject];

def interned_class_getitem -> ptr[PyObject];

def interned_format -> ptr[PyObject];

def interned_keys -> ptr[PyObject];

def interned_items -> ptr[PyObject];

def interned_values -> ptr[PyObject];

def interned_bases -> ptr[PyObject];

def interned_class -> ptr[PyObject];

def interned_instancecheck -> ptr[PyObject];

def interned_subclasscheck -> ptr[PyObject];

def interned_send -> ptr[PyObject];

def tp_name(op: ptr[PyObject]) -> ptr[u8];

def index_check(obj_: ptr[PyObject]) -> bool;

def long_check(op: ptr[PyObject]) -> bool;

def long_check_exact(op: ptr[PyObject]) -> bool;

def long_is_negative(op: ptr[PyObject]) -> bool;

def float_check_exact(op: ptr[PyObject]) -> bool;

def float_check(op: ptr[PyObject]) -> bool;

def float_value(op: ptr[PyObject]) -> f64;

def complex_check(op: ptr[PyObject]) -> bool;

def unicode_check(op: ptr[PyObject]) -> bool;

def unicode_check_exact(op: ptr[PyObject]) -> bool;

def unicode_length(op: ptr[PyObject]) -> i64;

def bytes_check(op: ptr[PyObject]) -> bool;

def bytes_data(op: ptr[PyObject]) -> ptr[u8];

def bytearray_check(op: ptr[PyObject]) -> bool;

def tuple_check(op: ptr[PyObject]) -> bool;

def tuple_check_exact(op: ptr[PyObject]) -> bool;

def list_check_exact(op: ptr[PyObject]) -> bool;

def dict_check(op: ptr[PyObject]) -> bool;

def dict_check_exact(op: ptr[PyObject]) -> bool;

def type_check(op: ptr[PyObject]) -> bool;

def type_check_exact(op: ptr[PyObject]) -> bool;

def union_check(op: ptr[PyObject]) -> bool;

def item_array(address: int) -> ptr[ptr[PyObject]];

def buffer_at(address: int) -> ptr[Py_buffer];

def unicode_from_c(s: ptr[u8]) -> ptr[PyObject];

def set_c_string(exception: ptr[PyObject], message: ptr[u8]);

def type_error(msg: ptr[u8], op: ptr[PyObject]) -> ptr[PyObject];

def null_error -> ptr[PyObject];

def call_method_no_args(self_obj: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def call_method_one_arg(
    self_obj: ptr[PyObject], name: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def nb_slot(nb: ptr[PyNumberMethods], slot: i64) -> int;

def call_binary(func: int, v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def call_ternary(
    func: int, v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
) -> ptr[PyObject];

def call_repeat(func: int, seq: ptr[PyObject], count: i64) -> ptr[PyObject];

def binary_op1(v: ptr[PyObject], w: ptr[PyObject], op_slot: i64) -> ptr[PyObject];

def binop_type_error(
    v: ptr[PyObject], w: ptr[PyObject], op_name: ptr[u8]
) -> ptr[PyObject];

def binary_op(
    v: ptr[PyObject], w: ptr[PyObject], op_slot: i64, op_name: ptr[u8]
) -> ptr[PyObject];

def ternary_op(
    v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject], op_slot: i64, op_name: ptr[u8]
) -> ptr[PyObject];

def sequence_repeat(
    repeatfunc: int, seq: ptr[PyObject], n: ptr[PyObject]
) -> ptr[PyObject];

def binary_iop1(
    v: ptr[PyObject], w: ptr[PyObject], iop_slot: i64, op_slot: i64
) -> ptr[PyObject];

def binary_iop(
    v: ptr[PyObject], w: ptr[PyObject], iop_slot: i64, op_slot: i64, op_name: ptr[u8]
) -> ptr[PyObject];

def ternary_iop(
    v: ptr[PyObject],
    w: ptr[PyObject],
    z: ptr[PyObject],
    iop_slot: i64,
    op_slot: i64,
    op_name: ptr[u8]
) -> ptr[PyObject];

def is_fortran_contiguous(view: ptr[Py_buffer]) -> i32;

def is_c_contiguous(view: ptr[Py_buffer]) -> i32;

def add_one_to_index_F(nd: i64, index: ptr[i64], shape: ptr[i64]);

def add_one_to_index_C(nd: i64, index: ptr[i64], shape: ptr[i64]);

def as_read_buffer(obj_: ptr[PyObject], buffer: ptr[ptr], buffer_len: ptr[i64]) -> i32;

def buffer_release_call(arg: ptr) -> i32;

def list_append_take_ref(list_op: ptr[PyObject], newitem: ptr[PyObject]) -> i32;

def release_items(items: ptr[ptr[PyObject]], n: i64);

def method_output_as_list(o: ptr[PyObject], meth: ptr[PyObject]) -> ptr[PyObject];

def get_optional_item(
    obj_: ptr[PyObject], key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def get_optional_item_string(
    obj_: ptr[PyObject], key: ptr[u8]
) -> tuple[i32, ptr[PyObject]];

def abstract_get_bases(cls: ptr[PyObject]) -> ptr[PyObject];

def abstract_issubclass(derived_in: ptr[PyObject], cls: ptr[PyObject]) -> i32;

def check_class(cls: ptr[PyObject], error: ptr[u8]) -> i32;

def object_isinstance(inst: ptr[PyObject], cls: ptr[PyObject]) -> i32;

def object_recursive_isinstance(inst: ptr[PyObject], cls_in: ptr[PyObject]) -> i32;

def recursive_issubclass(derived: ptr[PyObject], cls: ptr[PyObject]) -> i32;

def object_issubclass(derived: ptr[PyObject], cls_in: ptr[PyObject]) -> i32;

def iter_check(obj_: ptr[PyObject]) -> bool;

def iternext(iter: ptr[PyObject]) -> tuple[i32, ptr[PyObject]];

import from c {
    def PyObject_Type(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        return object_new_ref(ptr[PyObject](object_type(o)));
    }  def PyObject_Size(o: ptr[PyObject]) -> i64 {
        if not o {
            null_error();
            return -1;
        }
        m = object_type(o).view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_length) != 0 {
            return m.view(1)[0].sq_length(o);
        }
        return PyMapping_Size(o);
    }  def PyObject_Length(o: ptr[PyObject]) -> i64 {
        return PyObject_Size(o);
    }  def _PyObject_HasLen(o: ptr[PyObject]) -> i32 {
        tp = object_type(o);
        sq = tp.view(1)[0].tp_as_sequence;
        if sq and int(sq.view(1)[0].sq_length) != 0 {
            return i32(1);
        }
        mp = tp.view(1)[0].tp_as_mapping;
        if mp and int(mp.view(1)[0].mp_length) != 0 {
            return i32(1);
        }
        return i32(0);
    }  def PyObject_LengthHint(o: ptr[PyObject], defaultvalue: i64) -> i64 {
        if _PyObject_HasLen(o) != i32(0) {
            res = PyObject_Size(o);
            if res >= 0 {
                return res;
            }
            if PyErr_ExceptionMatches(PyExc_TypeError) == 0 {
                return -1;
            }
            PyErr_Clear();
        }
        hint = _PyObject_LookupSpecial(o, interned_length_hint());
        if not hint {
            if PyErr_Occurred() {
                return -1;
            }
            return defaultvalue;
        }
        result = vectorcall_tstate(
            thread_state(), hint, ptr[ptr[PyObject]](), u64(0), NULL
        );
        object_decref(hint);
        if not result {
            if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
                PyErr_Clear();
                return defaultvalue;
            }
            return -1;
        } elif result == Py_NotImplemented {
            object_decref(result);
            return defaultvalue;
        }
        if not long_check(result) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("__length_hint__ must be an integer, not %.100s"),
                tp_name(result)
            );
            object_decref(result);
            return -1;
        }
        hinted = PyLong_AsSsize_t(result);
        object_decref(result);
        if hinted < 0 and PyErr_Occurred() {
            return -1;
        }
        if hinted < 0 {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("__length_hint__() should return >= 0")
            );
            return -1;
        }
        return hinted;
    }  def PyObject_GetItem(o: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
        if not o or not key {
            return null_error();
        }
        tp = object_type(o);
        m = tp.view(1)[0].tp_as_mapping;
        if m and int(m.view(1)[0].mp_subscript) != 0 {
            return m.view(1)[0].mp_subscript(o, key);
        }
        ms = tp.view(1)[0].tp_as_sequence;
        if ms and int(ms.view(1)[0].sq_item) != 0 {
            if index_check(key) {
                key_value = PyNumber_AsSsize_t(key, PyExc_IndexError);
                if key_value == -1 and PyErr_Occurred() {
                    return NULL;
                }
                return PySequence_GetItem(o, key_value);
            }
            return type_error(
                ptr[u8]("sequence index must be integer, not '%.200s'"), key
            );
        }
        if type_check(o) {
            if o == ptr[PyObject](addressof(PyType_Type)) {
                return Py_GenericAlias(o, key);
            }
            meth = NULL;
            if PyObject_GetOptionalAttr(o, interned_class_getitem(), &mut meth) < 0 {
                return NULL;
            }
            if meth and meth != Py_None {
                result = PyObject_CallOneArg(meth, key);
                object_decref(meth);
                return result;
            }
            object_xdecref(meth);
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("type '%.200s' is not subscriptable"),
                ptr[PyTypeObject](o).view(1)[0].tp_name
            );
            return NULL;
        }
        return type_error(ptr[u8]("'%.200s' object is not subscriptable"), o);
    }  def PyMapping_GetOptionalItem(
        obj_: ptr[PyObject], key: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32 {
        (rc, item) = get_optional_item(obj_, key);
        result.view(1)[0] = item;
        return rc;
    }  def PyObject_SetItem(
        o: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
    ) -> i32 {
        if not o or not key or not value {
            null_error();
            return i32(-1);
        }
        tp = object_type(o);
        m = tp.view(1)[0].tp_as_mapping;
        if m and int(m.view(1)[0].mp_ass_subscript) != 0 {
            return m.view(1)[0].mp_ass_subscript(o, key, value);
        }
        sq = tp.view(1)[0].tp_as_sequence;
        if sq {
            if index_check(key) {
                key_value = PyNumber_AsSsize_t(key, PyExc_IndexError);
                if key_value == -1 and PyErr_Occurred() {
                    return i32(-1);
                }
                return PySequence_SetItem(o, key_value, value);
            } elif int(sq.view(1)[0].sq_ass_item) != 0 {
                type_error(
                    ptr[u8]("sequence index must be integer, not '%.200s'"), key
                );
                return i32(-1);
            }
        }
        type_error(ptr[u8]("'%.200s' object does not support item assignment"), o);
        return i32(-1);
    }  def PyObject_DelItem(o: ptr[PyObject], key: ptr[PyObject]) -> i32 {
        if not o or not key {
            null_error();
            return i32(-1);
        }
        tp = object_type(o);
        m = tp.view(1)[0].tp_as_mapping;
        if m and int(m.view(1)[0].mp_ass_subscript) != 0 {
            return m.view(1)[0].mp_ass_subscript(o, key, NULL);
        }
        sq = tp.view(1)[0].tp_as_sequence;
        if sq {
            if index_check(key) {
                key_value = PyNumber_AsSsize_t(key, PyExc_IndexError);
                if key_value == -1 and PyErr_Occurred() {
                    return i32(-1);
                }
                return PySequence_DelItem(o, key_value);
            } elif int(sq.view(1)[0].sq_ass_item) != 0 {
                type_error(
                    ptr[u8]("sequence index must be integer, not '%.200s'"), key
                );
                return i32(-1);
            }
        }
        type_error(ptr[u8]("'%.200s' object does not support item deletion"), o);
        return i32(-1);
    }  def PyObject_DelItemString(o: ptr[PyObject], key: ptr[u8]) -> i32 {
        if not o or not key {
            null_error();
            return i32(-1);
        }
        okey = unicode_from_c(key);
        if not okey {
            return i32(-1);
        }
        ret = PyObject_DelItem(o, okey);
        object_decref(okey);
        return ret;
    }  def PyObject_CheckBuffer(obj_: ptr[PyObject]) -> i32 {
        pb = object_type(obj_).view(1)[0].tp_as_buffer;
        if pb and int(pb.view(1)[0].bf_getbuffer) != 0 {
            return i32(1);
        }
        return i32(0);
    }  def PyObject_CheckReadBuffer(obj_: ptr[PyObject]) -> i32 {
        pb = object_type(obj_).view(1)[0].tp_as_buffer;
        if not pb or int(pb.view(1)[0].bf_getbuffer) == 0 {
            return i32(0);
        }
        slots: own StackSlots = StackSlots();
        view = buffer_at(jacpy_stack_address(&mut slots));
        if pb.view(1)[0].bf_getbuffer(obj_, view, PyBUF_SIMPLE) == i32(-1) {
            PyErr_Clear();
            return i32(0);
        }
        PyBuffer_Release(view);
        return i32(1);
    }  def PyObject_AsCharBuffer(
        obj_: ptr[PyObject], buffer: ptr[ptr[u8]], buffer_len: ptr[i64]
    ) -> i32 {
        return as_read_buffer(obj_, ptr[ptr](buffer), buffer_len);
    }  def PyObject_AsReadBuffer(
        obj_: ptr[PyObject], buffer: ptr[ptr], buffer_len: ptr[i64]
    ) -> i32 {
        return as_read_buffer(obj_, buffer, buffer_len);
    }  def PyObject_AsWriteBuffer(
        obj_: ptr[PyObject], buffer: ptr[ptr], buffer_len: ptr[i64]
    ) -> i32 {
        if not obj_ or not buffer or not buffer_len {
            null_error();
            return i32(-1);
        }
        pb = object_type(obj_).view(1)[0].tp_as_buffer;
        slots: own StackSlots = StackSlots();
        view = buffer_at(jacpy_stack_address(&mut slots));
        if not pb
            or int(pb.view(1)[0].bf_getbuffer) == 0
            or pb.view(1)[0].bf_getbuffer(obj_, view, PyBUF_WRITABLE) != i32(0) {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("expected a writable bytes-like object")
            );
            return i32(-1);
        }
        buffer.view(1)[0] = view.view(1)[0].buf;
        buffer_len.view(1)[0] = view.view(1)[0].length;
        PyBuffer_Release(view);
        return i32(0);
    }  def PyObject_GetBuffer(
        obj_: ptr[PyObject], view: ptr[Py_buffer], flags: i32
    ) -> i32 {
        if flags != PyBUF_SIMPLE {
            if flags == PyBUF_READ or flags == PyBUF_WRITE {
                PyErr_BadInternalCall();
                return i32(-1);
            }
        }
        pb = object_type(obj_).view(1)[0].tp_as_buffer;
        if not pb or int(pb.view(1)[0].bf_getbuffer) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("a bytes-like object is required, not '%.100s'"),
                tp_name(obj_)
            );
            return i32(-1);
        }
        return pb.view(1)[0].bf_getbuffer(obj_, view, flags);
    }  def PyBuffer_IsContiguous(view: ptr[Py_buffer], order: i8) -> i32 {
        if view.view(1)[0].suboffsets {
            return i32(0);
        }
        if order == ORDER_C {
            return is_c_contiguous(view);
        } elif order == ORDER_F {
            return is_fortran_contiguous(view);
        } elif order == ORDER_A {
            if is_c_contiguous(view) != i32(0)
                or is_fortran_contiguous(view) != i32(0) {
                return i32(1);
            }
            return i32(0);
        }
        return i32(0);
    }  def PyBuffer_GetPointer(view: ptr[Py_buffer], indices: ptr[i64]) -> ptr {
        pointer = ptr[u8](view.view(1)[0].buf);
        strides = view.view(1)[0].strides;
        suboffsets = view.view(1)[0].suboffsets;
        for i in range(i64(view.view(1)[0].ndim)) {
            pointer = pointer + (strides + i).view(1)[0] * (indices + i).view(1)[0];
            if suboffsets and (suboffsets + i).view(1)[0] >= 0 {
                pointer = ptr[ptr[u8]](pointer).view(1)[0]
                    + (suboffsets + i).view(1)[0];
            }
        }
        return ptr(pointer);
    }  def PyBuffer_SizeFromFormat(format: ptr[u8]) -> i64 {
        itemsize: i64 = -1;
        fmt = NULL;
        res = NULL;
        calcsize = PyImport_ImportModuleAttrString(
            ptr[u8]("struct"), ptr[u8]("calcsize")
        );
        if calcsize {
            fmt = unicode_from_c(format);
            if fmt {
                res = PyObject_CallFunctionObjArgs(calcsize, fmt, NULL);
                if res {
                    itemsize = PyLong_AsSsize_t(res);
                }
            }
        }
        object_xdecref(calcsize);
        object_xdecref(fmt);
        object_xdecref(res);
        return itemsize;
    }  def PyBuffer_FromContiguous(
        view: ptr[Py_buffer], buf: ptr, length_in: i64, fort: i8
    ) -> i32 {
        length = length_in;
        if length > view.view(1)[0].length {
            length = view.view(1)[0].length;
        }
        if PyBuffer_IsContiguous(view, fort) != i32(0) {
            memcpy(view.view(1)[0].buf, buf, u64(length));
            return i32(0);
        }

        ndim = i64(view.view(1)[0].ndim);
        indices = ptr[i64](PyMem_Malloc(u64(8 * ndim)));
        if not indices {
            PyErr_NoMemory();
            return i32(-1);
        }
        for k in range(ndim) {
            (indices + k).view(1)[0] = 0;
        }
        itemsize = view.view(1)[0].itemsize;
        shape = view.view(1)[0].shape;
        src = ptr[u8](buf);
        elements = length // itemsize;
        while elements > 0 {
            elements -= 1;
            dest = PyBuffer_GetPointer(view, indices);
            memcpy(dest, ptr(src), u64(itemsize));
            src = src + itemsize;
            if fort == ORDER_F {
                add_one_to_index_F(ndim, indices, shape);
            } else {
                add_one_to_index_C(ndim, indices, shape);
            }
        }
        PyMem_Free(ptr(indices));
        return i32(0);
    }  def PyObject_CopyData(dest: ptr[PyObject], src: ptr[PyObject]) -> i32 {
        if PyObject_CheckBuffer(dest) == i32(0)
            or PyObject_CheckBuffer(src) == i32(0) {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8]("both destination and source must be bytes-like objects")
            );
            return i32(-1);
        }
        dest_slots: own StackSlots = StackSlots();
        view_dest = buffer_at(jacpy_stack_address(&mut dest_slots));
        src_slots: own StackSlots = StackSlots();
        view_src = buffer_at(jacpy_stack_address(&mut src_slots));
        if PyObject_GetBuffer(dest, view_dest, PyBUF_FULL) != i32(0) {
            return i32(-1);
        }
        if PyObject_GetBuffer(src, view_src, PyBUF_FULL_RO) != i32(0) {
            PyBuffer_Release(view_dest);
            return i32(-1);
        }
        if view_dest.view(1)[0].length < view_src.view(1)[0].length {
            PyErr_SetString(
                PyExc_BufferError,
                ptr[u8]("destination is too small to receive data from source")
            );
            PyBuffer_Release(view_dest);
            PyBuffer_Release(view_src);
            return i32(-1);
        }
        if (
            PyBuffer_IsContiguous(view_dest, ORDER_C) != i32(0)
            and PyBuffer_IsContiguous(view_src, ORDER_C) != i32(0)
        )
            or (
                PyBuffer_IsContiguous(view_dest, ORDER_F) != i32(0)
                and PyBuffer_IsContiguous(view_src, ORDER_F) != i32(0)
            ) {
            memcpy(
                view_dest.view(1)[0].buf,
                view_src.view(1)[0].buf,
                u64(view_src.view(1)[0].length)
            );
            PyBuffer_Release(view_dest);
            PyBuffer_Release(view_src);
            return i32(0);
        }

        ndim = i64(view_src.view(1)[0].ndim);
        indices = ptr[i64](PyMem_Malloc(u64(8 * ndim)));
        if not indices {
            PyErr_NoMemory();
            PyBuffer_Release(view_dest);
            PyBuffer_Release(view_src);
            return i32(-1);
        }
        for k in range(ndim) {
            (indices + k).view(1)[0] = 0;
        }
        shape = view_src.view(1)[0].shape;
        elements: i64 = 1;
        for k in range(ndim) {
            elements *= (shape + k).view(1)[0];
        }
        itemsize = view_src.view(1)[0].itemsize;
        while elements > 0 {
            elements -= 1;
            add_one_to_index_C(ndim, indices, shape);
            dptr = PyBuffer_GetPointer(view_dest, indices);
            sptr = PyBuffer_GetPointer(view_src, indices);
            memcpy(dptr, sptr, u64(itemsize));
        }
        PyMem_Free(ptr(indices));
        PyBuffer_Release(view_dest);
        PyBuffer_Release(view_src);
        return i32(0);
    }  def PyBuffer_FillContiguousStrides(
        nd: i32, shape: ptr[i64], strides: ptr[i64], itemsize: i32, fort: i8
    ) {
        sd = i64(itemsize);
        if fort == ORDER_F {
            for k in range(i64(nd)) {
                (strides + k).view(1)[0] = sd;
                sd *= (shape + k).view(1)[0];
            }
        } else {
            k = i64(nd) - 1;
            while k >= 0 {
                (strides + k).view(1)[0] = sd;
                sd *= (shape + k).view(1)[0];
                k -= 1;
            }
        }
    }  def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        exporter: ptr[PyObject],
        buf: ptr,
        length: i64,
        readonly: i32,
        flags: i32
    ) -> i32 {
        if not view {
            PyErr_SetString(
                PyExc_BufferError,
                ptr[u8]("PyBuffer_FillInfo: view==NULL argument is obsolete")
            );
            return i32(-1);
        }

        if flags != PyBUF_SIMPLE {
            if flags == PyBUF_READ or flags == PyBUF_WRITE {
                PyErr_BadInternalCall();
                return i32(-1);
            }
            if (flags & PyBUF_WRITABLE) == PyBUF_WRITABLE and readonly == i32(1) {
                PyErr_SetString(PyExc_BufferError, ptr[u8]("Object is not writable."));
                return i32(-1);
            }
        }
        if exporter {
            object_incref(exporter);
        }
        view.view(1)[0].owner = exporter;
        view.view(1)[0].buf = buf;
        view.view(1)[0].length = length;
        view.view(1)[0].readonly = readonly;
        view.view(1)[0].itemsize = 1;
        view.view(1)[0].format_ = ptr[u8]();
        if (flags & PyBUF_FORMAT) == PyBUF_FORMAT {
            view.view(1)[0].format_ = ptr[u8]("B");
        }
        view.view(1)[0].ndim = i32(1);
        view.view(1)[0].shape = ptr[i64]();
        if (flags & PyBUF_ND) == PyBUF_ND {
            view.view(1)[0].shape = ptr[i64](ptr[u8](view) + Py_buffer_LEN);
        }
        view.view(1)[0].strides = ptr[i64]();
        if (flags & PyBUF_STRIDES) == PyBUF_STRIDES {
            view.view(1)[0].strides = ptr[i64](ptr[u8](view) + Py_buffer_ITEMSIZE);
        }
        view.view(1)[0].suboffsets = ptr[i64]();
        view.view(1)[0].internal = ptr();
        return i32(0);
    }  def PyBuffer_Release(view: ptr[Py_buffer]) {
        exporter = view.view(1)[0].owner;
        if not exporter {
            return;
        }
        pb = object_type(exporter).view(1)[0].tp_as_buffer;
        if pb and int(pb.view(1)[0].bf_releasebuffer) != 0 {
            pb.view(1)[0].bf_releasebuffer(exporter, view);
        }
        view.view(1)[0].owner = NULL;
        object_decref(exporter);
    }  def _PyBuffer_ReleaseInInterpreter(
        interp: ptr[PyInterpreterState], view: ptr[Py_buffer]
    ) -> i32 {
        return _Py_CallInInterpreter(interp, ptr(buffer_release_call), ptr(view));
    }  def _PyBuffer_ReleaseInInterpreterAndRawFree(
        interp: ptr[PyInterpreterState], view: ptr[Py_buffer]
    ) -> i32 {
        return _Py_CallInInterpreterAndRawFree(
            interp, ptr(buffer_release_call), ptr(view)
        );
    }  def PyObject_Format(
        obj_: ptr[PyObject], format_spec: ptr[PyObject]
    ) -> ptr[PyObject] {
        if format_spec and not unicode_check(format_spec) {
            PyErr_Format(
                PyExc_SystemError,
                ptr[u8]("Format specifier must be a string, not %.200s"),
                tp_name(format_spec)
            );
            return NULL;
        }

        if not format_spec or unicode_length(format_spec) == 0 {
            if unicode_check_exact(obj_) {
                return object_new_ref(obj_);
            }
            if long_check_exact(obj_) {
                return PyObject_Str(obj_);
            }
        }

        empty = NULL;
        spec = format_spec;
        if not spec {
            empty = Py_GetConstant(Py_CONSTANT_EMPTY_STR);
            spec = empty;
        }
        result = NULL;

        meth = _PyObject_LookupSpecial(obj_, interned_format());
        if not meth {
            if not exception_raised(thread_state()) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("Type %.100s doesn't define __format__"),
                    tp_name(obj_)
                );
            }
        } else {
            result = PyObject_CallOneArg(meth, spec);
            object_decref(meth);
            if result and not unicode_check(result) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("__format__ must return a str, not %.200s"),
                    tp_name(result)
                );
                object_decref(result);
                result = NULL;
            }
        }
        object_xdecref(empty);
        return result;
    }  def PyNumber_Check(o: ptr[PyObject]) -> i32 {
        if not o {
            return i32(0);
        }
        nb = object_type(o).view(1)[0].tp_as_number;
        if not nb {
            return i32(0);
        }
        if int(nb.view(1)[0].nb_index) != 0
            or int(nb.view(1)[0].nb_int) != 0
            or int(nb.view(1)[0].nb_float) != 0
            or complex_check(o) {
            return i32(1);
        }
        return i32(0);
    }  def PyNumber_Or(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_OR, ptr[u8]("|"));
    }  def PyNumber_Xor(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_XOR, ptr[u8]("^"));
    }  def PyNumber_And(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_AND, ptr[u8]("&"));
    }  def PyNumber_Lshift(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_LSHIFT, ptr[u8]("<<"));
    }  def PyNumber_Rshift(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_RSHIFT, ptr[u8](">>"));
    }  def PyNumber_Subtract(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_SUBTRACT, ptr[u8]("-"));
    }  def PyNumber_Divmod(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_DIVMOD, ptr[u8]("divmod()"));
    }  def PyNumber_Add(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        result = binary_op1(v, w, PyNumberMethods_NB_ADD);
        if result != Py_NotImplemented {
            return result;
        }
        object_decref(result);
        m = object_type(v).view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_concat) != 0 {
            return m.view(1)[0].sq_concat(v, w);
        }
        return binop_type_error(v, w, ptr[u8]("+"));
    }  def PyNumber_Multiply(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        result = binary_op1(v, w, PyNumberMethods_NB_MULTIPLY);
        if result == Py_NotImplemented {
            mv = object_type(v).view(1)[0].tp_as_sequence;
            mw = object_type(w).view(1)[0].tp_as_sequence;
            object_decref(result);
            if mv and int(mv.view(1)[0].sq_repeat) != 0 {
                return sequence_repeat(int(mv.view(1)[0].sq_repeat), v, w);
            } elif mw and int(mw.view(1)[0].sq_repeat) != 0 {
                return sequence_repeat(int(mw.view(1)[0].sq_repeat), w, v);
            }
            result = binop_type_error(v, w, ptr[u8]("*"));
        }
        return result;
    }  def PyNumber_MatrixMultiply(
        v: ptr[PyObject], w: ptr[PyObject]
    ) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_MATRIX_MULTIPLY, ptr[u8]("@"));
    }  def PyNumber_FloorDivide(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_FLOOR_DIVIDE, ptr[u8]("//"));
    }  def PyNumber_TrueDivide(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_TRUE_DIVIDE, ptr[u8]("/"));
    }  def PyNumber_Remainder(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_op(v, w, PyNumberMethods_NB_REMAINDER, ptr[u8]("%"));
    }  def PyNumber_Power(
        v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
    ) -> ptr[PyObject] {
        return ternary_op(v, w, z, PyNumberMethods_NB_POWER, ptr[u8]("** or pow()"));
    }  def _PyNumber_PowerNoMod(
        lhs: ptr[PyObject], rhs: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyNumber_Power(lhs, rhs, Py_None);
    }  def PyNumber_InPlaceOr(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_iop(
            v, w, PyNumberMethods_NB_INPLACE_OR, PyNumberMethods_NB_OR, ptr[u8]("|=")
        );
    }  def PyNumber_InPlaceXor(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_iop(
            v, w, PyNumberMethods_NB_INPLACE_XOR, PyNumberMethods_NB_XOR, ptr[u8]("^=")
        );
    }  def PyNumber_InPlaceAnd(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_iop(
            v, w, PyNumberMethods_NB_INPLACE_AND, PyNumberMethods_NB_AND, ptr[u8]("&=")
        );
    }  def PyNumber_InPlaceLshift(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_iop(
            v,
            w,
            PyNumberMethods_NB_INPLACE_LSHIFT,
            PyNumberMethods_NB_LSHIFT,
            ptr[u8]("<<=")
        );
    }  def PyNumber_InPlaceRshift(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        return binary_iop(
            v,
            w,
            PyNumberMethods_NB_INPLACE_RSHIFT,
            PyNumberMethods_NB_RSHIFT,
            ptr[u8](">>=")
        );
    }  def PyNumber_InPlaceSubtract(
        v: ptr[PyObject], w: ptr[PyObject]
    ) -> ptr[PyObject] {
        return binary_iop(
            v,
            w,
            PyNumberMethods_NB_INPLACE_SUBTRACT,
            PyNumberMethods_NB_SUBTRACT,
            ptr[u8]("-=")
        );
    }  def PyNumber_InPlaceMatrixMultiply(
        v: ptr[PyObject], w: ptr[PyObject]
    ) -> ptr[PyObject] {
        return binary_iop(
            v,
            w,
            PyNumberMethods_NB_INPLACE_MATRIX_MULTIPLY,
            PyNumberMethods_NB_MATRIX_MULTIPLY,
            ptr[u8]("@=")
        );
    }  def PyNumber_InPlaceFloorDivide(
        v: ptr[PyObject], w: ptr[PyObject]
    ) -> ptr[PyObject] {
        return binary_iop(
            v,
            w,
            PyNumberMethods_NB_INPLACE_FLOOR_DIVIDE,
            PyNumberMethods_NB_FLOOR_DIVIDE,
            ptr[u8]("//=")
        );
    }  def PyNumber_InPlaceTrueDivide(
        v: ptr[PyObject], w: ptr[PyObject]
    ) -> ptr[PyObject] {
        return binary_iop(
            v,
            w,
            PyNumberMethods_NB_INPLACE_TRUE_DIVIDE,
            PyNumberMethods_NB_TRUE_DIVIDE,
            ptr[u8]("/=")
        );
    }  def PyNumber_InPlaceRemainder(
        v: ptr[PyObject], w: ptr[PyObject]
    ) -> ptr[PyObject] {
        return binary_iop(
            v,
            w,
            PyNumberMethods_NB_INPLACE_REMAINDER,
            PyNumberMethods_NB_REMAINDER,
            ptr[u8]("%=")
        );
    }  def PyNumber_InPlaceAdd(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
        result = binary_iop1(
            v, w, PyNumberMethods_NB_INPLACE_ADD, PyNumberMethods_NB_ADD
        );
        if result == Py_NotImplemented {
            m = object_type(v).view(1)[0].tp_as_sequence;
            object_decref(result);
            if m {
                func = int(m.view(1)[0].sq_inplace_concat);
                if func == 0 {
                    func = int(m.view(1)[0].sq_concat);
                }
                if func != 0 {
                    return call_binary(func, v, w);
                }
            }
            result = binop_type_error(v, w, ptr[u8]("+="));
        }
        return result;
    }  def PyNumber_InPlaceMultiply(
        v: ptr[PyObject], w: ptr[PyObject]
    ) -> ptr[PyObject] {
        result = binary_iop1(
            v, w, PyNumberMethods_NB_INPLACE_MULTIPLY, PyNumberMethods_NB_MULTIPLY
        );
        if result == Py_NotImplemented {
            mv = object_type(v).view(1)[0].tp_as_sequence;
            mw = object_type(w).view(1)[0].tp_as_sequence;
            object_decref(result);
            if mv {
                f = int(mv.view(1)[0].sq_inplace_repeat);
                if f == 0 {
                    f = int(mv.view(1)[0].sq_repeat);
                }
                if f != 0 {
                    return sequence_repeat(f, v, w);
                }
            } elif mw {
                if int(mw.view(1)[0].sq_repeat) != 0 {
                    return sequence_repeat(int(mw.view(1)[0].sq_repeat), w, v);
                }
            }
            result = binop_type_error(v, w, ptr[u8]("*="));
        }
        return result;
    }  def PyNumber_InPlacePower(
        v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
    ) -> ptr[PyObject] {
        return ternary_iop(
            v,
            w,
            z,
            PyNumberMethods_NB_INPLACE_POWER,
            PyNumberMethods_NB_POWER,
            ptr[u8]("**=")
        );
    }  def _PyNumber_InPlacePowerNoMod(
        lhs: ptr[PyObject], rhs: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyNumber_InPlacePower(lhs, rhs, Py_None);
    }  def PyNumber_Negative(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        m = object_type(o).view(1)[0].tp_as_number;
        if m and int(m.view(1)[0].nb_negative) != 0 {
            return m.view(1)[0].nb_negative(o);
        }
        return type_error(ptr[u8]("bad operand type for unary -: '%.200s'"), o);
    }  def PyNumber_Positive(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        m = object_type(o).view(1)[0].tp_as_number;
        if m and int(m.view(1)[0].nb_positive) != 0 {
            return m.view(1)[0].nb_positive(o);
        }
        return type_error(ptr[u8]("bad operand type for unary +: '%.200s'"), o);
    }  def PyNumber_Invert(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        m = object_type(o).view(1)[0].tp_as_number;
        if m and int(m.view(1)[0].nb_invert) != 0 {
            return m.view(1)[0].nb_invert(o);
        }
        return type_error(ptr[u8]("bad operand type for unary ~: '%.200s'"), o);
    }  def PyNumber_Absolute(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        m = object_type(o).view(1)[0].tp_as_number;
        if m and int(m.view(1)[0].nb_absolute) != 0 {
            return m.view(1)[0].nb_absolute(o);
        }
        return type_error(ptr[u8]("bad operand type for abs(): '%.200s'"), o);
    }  def PyIndex_Check(obj_: ptr[PyObject]) -> i32 {
        return i32(1) if index_check(obj_) else i32(0);
    }  def _PyNumber_Index(item: ptr[PyObject]) -> ptr[PyObject] {
        if not item {
            return null_error();
        }
        if long_check(item) {
            return object_new_ref(item);
        }
        if not index_check(item) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("'%.200s' object cannot be interpreted as an integer"),
                tp_name(item)
            );
            return NULL;
        }
        result = object_type(item).view(1)[0].tp_as_number.view(1)[0].nb_index(item);
        if not result or long_check_exact(result) {
            return result;
        }
        if not long_check(result) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("__index__ returned non-int (type %.200s)"),
                tp_name(result)
            );
            object_decref(result);
            return NULL;
        }

        if PyErr_WarnFormat(
            PyExc_DeprecationWarning,
            1,
            ptr[u8](
                "__index__ returned non-int (type %.200s).  The ability to return an instance of a strict subclass of int is deprecated, and may be removed in a future version of Python."
            ),
            tp_name(result)
        )
            != 0 {
            object_decref(result);
            return NULL;
        }
        return result;
    }  def PyNumber_Index(item: ptr[PyObject]) -> ptr[PyObject] {
        result = _PyNumber_Index(item);
        if result and not long_check_exact(result) {
            copy = _PyLong_Copy(ptr[PyLongObject](result));
            object_decref(result);
            result = copy;
        }
        return result;
    }  def PyNumber_AsSsize_t(item: ptr[PyObject], err: ptr[PyObject]) -> i64 {
        value = _PyNumber_Index(item);
        if not value {
            return -1;
        }

        result = PyLong_AsSsize_t(value);
        if result == -1 {
            runerr = error_occurred(thread_state());

            if runerr
                and PyErr_GivenExceptionMatches(runerr, PyExc_OverflowError) != 0 {
                PyErr_Clear();
                if not err {
                    result = PY_SSIZE_T_MIN
                        if long_is_negative(value)
                        else PY_SSIZE_T_MAX;
                } else {
                    PyErr_Format(
                        err,
                        ptr[u8]("cannot fit '%.200s' into an index-sized integer"),
                        tp_name(item)
                    );
                }
            }
        }
        object_decref(value);
        return result;
    }  def PyNumber_Long(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        if long_check_exact(o) {
            return object_new_ref(o);
        }
        m = object_type(o).view(1)[0].tp_as_number;

        if m and int(m.view(1)[0].nb_int) != 0 {
            result = m.view(1)[0].nb_int(o);
            if not result or long_check_exact(result) {
                return result;
            }
            if not long_check(result) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("__int__ returned non-int (type %.200s)"),
                    tp_name(result)
                );
                object_decref(result);
                return NULL;
            }

            if PyErr_WarnFormat(
                PyExc_DeprecationWarning,
                1,
                ptr[u8](
                    "__int__ returned non-int (type %.200s).  The ability to return an instance of a strict subclass of int is deprecated, and may be removed in a future version of Python."
                ),
                tp_name(result)
            )
                != 0 {
                object_decref(result);
                return NULL;
            }
            copy = _PyLong_Copy(ptr[PyLongObject](result));
            object_decref(result);
            return copy;
        }
        if m and int(m.view(1)[0].nb_index) != 0 {
            return PyNumber_Index(o);
        }
        if unicode_check(o) {
            return PyLong_FromUnicodeObject(o, i32(10));
        }
        if bytes_check(o) {
            return _PyLong_FromBytes(bytes_data(o), object_size(o), i32(10));
        }
        if bytearray_check(o) {
            return _PyLong_FromBytes(PyByteArray_AsString(o), object_size(o), i32(10));
        }
        slots: own StackSlots = StackSlots();
        view = buffer_at(jacpy_stack_address(&mut slots));
        if PyObject_GetBuffer(o, view, PyBUF_SIMPLE) == i32(0) {
            data = PyBytes_FromStringAndSize(
                ptr[u8](view.view(1)[0].buf), view.view(1)[0].length
            );
            if not data {
                PyBuffer_Release(view);
                return NULL;
            }
            converted = _PyLong_FromBytes(bytes_data(data), object_size(data), i32(10));
            object_decref(data);
            PyBuffer_Release(view);
            return converted;
        }
        return type_error(
            ptr[u8](
                "int() argument must be a string, a bytes-like object or a real number, not '%.200s'"
            ),
            o
        );
    }  def PyNumber_Float(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        if float_check_exact(o) {
            return object_new_ref(o);
        }
        m = object_type(o).view(1)[0].tp_as_number;

        if m and int(m.view(1)[0].nb_float) != 0 {
            res = m.view(1)[0].nb_float(o);
            if not res or float_check_exact(res) {
                return res;
            }
            if not float_check(res) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("%.50s.__float__ returned non-float (type %.50s)"),
                    tp_name(o),
                    tp_name(res)
                );
                object_decref(res);
                return NULL;
            }

            if PyErr_WarnFormat(
                PyExc_DeprecationWarning,
                1,
                ptr[u8](
                    "%.50s.__float__ returned non-float (type %.50s).  The ability to return an instance of a strict subclass of float is deprecated, and may be removed in a future version of Python."
                ),
                tp_name(o),
                tp_name(res)
            )
                != 0 {
                object_decref(res);
                return NULL;
            }
            val = float_value(res);
            object_decref(res);
            return PyFloat_FromDouble(val);
        }
        if m and int(m.view(1)[0].nb_index) != 0 {
            index = _PyNumber_Index(o);
            if not index {
                return NULL;
            }
            converted = PyLong_AsDouble(index);
            object_decref(index);
            if converted == -1.0 and PyErr_Occurred() {
                return NULL;
            }
            return PyFloat_FromDouble(converted);
        }

        if float_check(o) {
            return PyFloat_FromDouble(float_value(o));
        }
        return PyFloat_FromString(o);
    }  def PyNumber_ToBase(n: ptr[PyObject], base: i32) -> ptr[PyObject] {
        if not (
            base == i32(2) or base == i32(8) or base == i32(10) or base == i32(16)
        ) {
            PyErr_SetString(
                PyExc_SystemError,
                ptr[u8]("PyNumber_ToBase: base must be 2, 8, 10 or 16")
            );
            return NULL;
        }
        index = _PyNumber_Index(n);
        if not index {
            return NULL;
        }
        res = _PyLong_Format(index, base);
        object_decref(index);
        return res;
    }  def PySequence_Check(s: ptr[PyObject]) -> i32 {
        if dict_check(s) {
            return i32(0);
        }
        m = object_type(s).view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_item) != 0 {
            return i32(1);
        }
        return i32(0);
    }  def PySequence_Size(s: ptr[PyObject]) -> i64 {
        if not s {
            null_error();
            return -1;
        }
        tp = object_type(s);
        m = tp.view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_length) != 0 {
            return m.view(1)[0].sq_length(s);
        }
        mp = tp.view(1)[0].tp_as_mapping;
        if mp and int(mp.view(1)[0].mp_length) != 0 {
            type_error(ptr[u8]("%.200s is not a sequence"), s);
            return -1;
        }
        type_error(ptr[u8]("object of type '%.200s' has no len()"), s);
        return -1;
    }  def PySequence_Length(s: ptr[PyObject]) -> i64 {
        return PySequence_Size(s);
    }  def PySequence_Concat(s: ptr[PyObject], o: ptr[PyObject]) -> ptr[PyObject] {
        if not s or not o {
            return null_error();
        }
        m = object_type(s).view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_concat) != 0 {
            return m.view(1)[0].sq_concat(s, o);
        }

        if PySequence_Check(s) != i32(0) and PySequence_Check(o) != i32(0) {
            result = binary_op1(s, o, PyNumberMethods_NB_ADD);
            if result != Py_NotImplemented {
                return result;
            }
            object_decref(result);
        }
        return type_error(ptr[u8]("'%.200s' object can't be concatenated"), s);
    }  def PySequence_Repeat(o: ptr[PyObject], count: i64) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        m = object_type(o).view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_repeat) != 0 {
            return m.view(1)[0].sq_repeat(o, count);
        }

        if PySequence_Check(o) != i32(0) {
            n = PyLong_FromSsize_t(count);
            if not n {
                return NULL;
            }
            result = binary_op1(o, n, PyNumberMethods_NB_MULTIPLY);
            object_decref(n);
            if result != Py_NotImplemented {
                return result;
            }
            object_decref(result);
        }
        return type_error(ptr[u8]("'%.200s' object can't be repeated"), o);
    }  def PySequence_InPlaceConcat(
        s: ptr[PyObject], o: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not s or not o {
            return null_error();
        }
        m = object_type(s).view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_inplace_concat) != 0 {
            return m.view(1)[0].sq_inplace_concat(s, o);
        }
        if m and int(m.view(1)[0].sq_concat) != 0 {
            return m.view(1)[0].sq_concat(s, o);
        }
        if PySequence_Check(s) != i32(0) and PySequence_Check(o) != i32(0) {
            result = binary_iop1(
                s, o, PyNumberMethods_NB_INPLACE_ADD, PyNumberMethods_NB_ADD
            );
            if result != Py_NotImplemented {
                return result;
            }
            object_decref(result);
        }
        return type_error(ptr[u8]("'%.200s' object can't be concatenated"), s);
    }  def PySequence_InPlaceRepeat(o: ptr[PyObject], count: i64) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        m = object_type(o).view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_inplace_repeat) != 0 {
            return m.view(1)[0].sq_inplace_repeat(o, count);
        }
        if m and int(m.view(1)[0].sq_repeat) != 0 {
            return m.view(1)[0].sq_repeat(o, count);
        }
        if PySequence_Check(o) != i32(0) {
            n = PyLong_FromSsize_t(count);
            if not n {
                return NULL;
            }
            result = binary_iop1(
                o, n, PyNumberMethods_NB_INPLACE_MULTIPLY, PyNumberMethods_NB_MULTIPLY
            );
            object_decref(n);
            if result != Py_NotImplemented {
                return result;
            }
            object_decref(result);
        }
        return type_error(ptr[u8]("'%.200s' object can't be repeated"), o);
    }  def PySequence_GetItem(s: ptr[PyObject], i_in: i64) -> ptr[PyObject] {
        if not s {
            return null_error();
        }
        tp = object_type(s);
        m = tp.view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_item) != 0 {
            i = i_in;
            if i < 0 and int(m.view(1)[0].sq_length) != 0 {
                l = m.view(1)[0].sq_length(s);
                if l < 0 {
                    return NULL;
                }
                i += l;
            }
            return m.view(1)[0].sq_item(s, i);
        }
        mp = tp.view(1)[0].tp_as_mapping;
        if mp and int(mp.view(1)[0].mp_subscript) != 0 {
            return type_error(ptr[u8]("%.200s is not a sequence"), s);
        }
        return type_error(ptr[u8]("'%.200s' object does not support indexing"), s);
    }  def PySequence_GetSlice(s: ptr[PyObject], i1: i64, i2: i64) -> ptr[PyObject] {
        if not s {
            return null_error();
        }
        mp = object_type(s).view(1)[0].tp_as_mapping;
        if mp and int(mp.view(1)[0].mp_subscript) != 0 {
            slice = _PySlice_FromIndices(i1, i2);
            if not slice {
                return NULL;
            }
            res = mp.view(1)[0].mp_subscript(s, slice);
            object_decref(slice);
            return res;
        }
        return type_error(ptr[u8]("'%.200s' object is unsliceable"), s);
    }  def PySequence_SetItem(s: ptr[PyObject], i_in: i64, o: ptr[PyObject]) -> i32 {
        if not s {
            null_error();
            return i32(-1);
        }
        tp = object_type(s);
        m = tp.view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_ass_item) != 0 {
            i = i_in;
            if i < 0 and int(m.view(1)[0].sq_length) != 0 {
                l = m.view(1)[0].sq_length(s);
                if l < 0 {
                    return i32(-1);
                }
                i += l;
            }
            return m.view(1)[0].sq_ass_item(s, i, o);
        }
        mp = tp.view(1)[0].tp_as_mapping;
        if mp and int(mp.view(1)[0].mp_ass_subscript) != 0 {
            type_error(ptr[u8]("%.200s is not a sequence"), s);
            return i32(-1);
        }
        type_error(ptr[u8]("'%.200s' object does not support item assignment"), s);
        return i32(-1);
    }  def PySequence_DelItem(s: ptr[PyObject], i_in: i64) -> i32 {
        if not s {
            null_error();
            return i32(-1);
        }
        tp = object_type(s);
        m = tp.view(1)[0].tp_as_sequence;
        if m and int(m.view(1)[0].sq_ass_item) != 0 {
            i = i_in;
            if i < 0 and int(m.view(1)[0].sq_length) != 0 {
                l = m.view(1)[0].sq_length(s);
                if l < 0 {
                    return i32(-1);
                }
                i += l;
            }
            return m.view(1)[0].sq_ass_item(s, i, NULL);
        }
        mp = tp.view(1)[0].tp_as_mapping;
        if mp and int(mp.view(1)[0].mp_ass_subscript) != 0 {
            type_error(ptr[u8]("%.200s is not a sequence"), s);
            return i32(-1);
        }
        type_error(ptr[u8]("'%.200s' object doesn't support item deletion"), s);
        return i32(-1);
    }  def PySequence_SetSlice(
        s: ptr[PyObject], i1: i64, i2: i64, o: ptr[PyObject]
    ) -> i32 {
        if not s {
            null_error();
            return i32(-1);
        }
        mp = object_type(s).view(1)[0].tp_as_mapping;
        if mp and int(mp.view(1)[0].mp_ass_subscript) != 0 {
            slice = _PySlice_FromIndices(i1, i2);
            if not slice {
                return i32(-1);
            }
            res = mp.view(1)[0].mp_ass_subscript(s, slice, o);
            object_decref(slice);
            return res;
        }
        type_error(ptr[u8]("'%.200s' object doesn't support slice assignment"), s);
        return i32(-1);
    }  def PySequence_DelSlice(s: ptr[PyObject], i1: i64, i2: i64) -> i32 {
        if not s {
            null_error();
            return i32(-1);
        }
        mp = object_type(s).view(1)[0].tp_as_mapping;
        if mp and int(mp.view(1)[0].mp_ass_subscript) != 0 {
            slice = _PySlice_FromIndices(i1, i2);
            if not slice {
                return i32(-1);
            }
            res = mp.view(1)[0].mp_ass_subscript(s, slice, NULL);
            object_decref(slice);
            return res;
        }
        type_error(ptr[u8]("'%.200s' object doesn't support slice deletion"), s);
        return i32(-1);
    }  def PySequence_Tuple(v: ptr[PyObject]) -> ptr[PyObject] {
        if not v {
            return null_error();
        }

        if tuple_check_exact(v) {
            return object_new_ref(v);
        }
        if list_check_exact(v) {
            return PyList_AsTuple(v);
        }

        it = PyObject_GetIter(v);
        if not it {
            return NULL;
        }

        slots: own StackSlots = StackSlots();
        buffer = item_array(jacpy_stack_address(&mut slots));
        n: i64 = 0;
        while n < 8 {
            item = PyIter_Next(it);
            if not item {
                if PyErr_Occurred() {
                    object_decref(it);
                    release_items(buffer, n);
                    return NULL;
                }
                object_decref(it);
                return _PyTuple_FromArraySteal(buffer, n);
            }
            (buffer + n).view(1)[0] = item;
            n += 1;
        }
        result_list = PyList_New(16);
        if not result_list {
            object_decref(it);
            release_items(buffer, n);
            return NULL;
        }
        ptr[PyVarObject](result_list).view(1)[0].ob_size = n;
        list_items = ptr[PyListObject](result_list).view(1)[0].ob_item;
        for j in range(n) {
            (list_items + j).view(1)[0] = (buffer + j).view(1)[0];
        }
        while True {
            item = PyIter_Next(it);
            if not item {
                if PyErr_Occurred() {
                    object_decref(result_list);
                    object_decref(it);
                    return NULL;
                }
                break;
            }
            if list_append_take_ref(result_list, item) < i32(0) {
                object_decref(result_list);
                object_decref(it);
                return NULL;
            }
        }
        object_decref(it);
        res = _PyList_AsTupleAndClear(result_list);
        object_decref(result_list);
        return res;
    }  def PySequence_List(v: ptr[PyObject]) -> ptr[PyObject] {
        if not v {
            return null_error();
        }
        result = PyList_New(0);
        if not result {
            return NULL;
        }
        rv = _PyList_Extend(result, v);
        if not rv {
            object_decref(result);
            return NULL;
        }
        object_decref(rv);
        return result;
    }  def PySequence_Fast(v: ptr[PyObject], m: ptr[u8]) -> ptr[PyObject] {
        if not v {
            return null_error();
        }
        if list_check_exact(v) or tuple_check_exact(v) {
            return object_new_ref(v);
        }
        it = PyObject_GetIter(v);
        if not it {
            if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
                set_c_string(PyExc_TypeError, m);
            }
            return NULL;
        }
        result = PySequence_List(it);
        object_decref(it);
        return result;
    }  def _PySequence_IterSearch(
        seq: ptr[PyObject], obj_: ptr[PyObject], operation: i32
    ) -> i64 {
        if not seq or not obj_ {
            null_error();
            return -1;
        }
        it = PyObject_GetIter(seq);
        if not it {
            if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
                if operation == PY_ITERSEARCH_CONTAINS {
                    type_error(
                        ptr[u8](
                            "argument of type '%.200s' is not a container or iterable"
                        ),
                        seq
                    );
                } else {
                    type_error(
                        ptr[u8]("argument of type '%.200s' is not iterable"), seq
                    );
                }
            }
            return -1;
        }
        n: i64 = 0;

        wrapped = False;
        failed = False;
        done = False;
        while True {
            item = PyIter_Next(it);
            if not item {
                if PyErr_Occurred() {
                    failed = True;
                }
                break;
            }
            cmp = PyObject_RichCompareBool(item, obj_, Py_EQ);
            object_decref(item);
            if cmp < i32(0) {
                failed = True;
                break;
            }
            if cmp > i32(0) {
                if operation == PY_ITERSEARCH_COUNT {
                    if n == PY_SSIZE_T_MAX {
                        PyErr_SetString(
                            PyExc_OverflowError, ptr[u8]("count exceeds C integer size")
                        );
                        failed = True;
                        break;
                    }
                    n += 1;
                } elif operation == PY_ITERSEARCH_INDEX {
                    if wrapped {
                        PyErr_SetString(
                            PyExc_OverflowError, ptr[u8]("index exceeds C integer size")
                        );
                        failed = True;
                    } else {
                        done = True;
                    }
                    break;
                } else {
                    n = 1;
                    done = True;
                    break;
                }
            }
            if operation == PY_ITERSEARCH_INDEX {
                if n == PY_SSIZE_T_MAX {
                    wrapped = True;
                }
                n = wrapping_add(n, 1);
            }
        }
        if not failed and not done and operation == PY_ITERSEARCH_INDEX {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("sequence.index(x): x not in sequence")
            );
            failed = True;
        }
        if failed {
            n = -1;
        }
        object_decref(it);
        return n;
    }  def PySequence_Count(s: ptr[PyObject], o: ptr[PyObject]) -> i64 {
        return _PySequence_IterSearch(s, o, PY_ITERSEARCH_COUNT);
    }  def PySequence_Contains(seq: ptr[PyObject], ob: ptr[PyObject]) -> i32 {
        sqm = object_type(seq).view(1)[0].tp_as_sequence;
        if sqm and int(sqm.view(1)[0].sq_contains) != 0 {
            return sqm.view(1)[0].sq_contains(seq, ob);
        }
        return i32(_PySequence_IterSearch(seq, ob, PY_ITERSEARCH_CONTAINS));
    }  def PySequence_In(w: ptr[PyObject], v: ptr[PyObject]) -> i32 {
        return PySequence_Contains(w, v);
    }  def PySequence_Index(s: ptr[PyObject], o: ptr[PyObject]) -> i64 {
        return _PySequence_IterSearch(s, o, PY_ITERSEARCH_INDEX);
    }  def PyMapping_Check(o: ptr[PyObject]) -> i32 {
        if not o {
            return i32(0);
        }
        mp = object_type(o).view(1)[0].tp_as_mapping;
        if mp and int(mp.view(1)[0].mp_subscript) != 0 {
            return i32(1);
        }
        return i32(0);
    }  def PyMapping_Size(o: ptr[PyObject]) -> i64 {
        if not o {
            null_error();
            return -1;
        }
        tp = object_type(o);
        m = tp.view(1)[0].tp_as_mapping;
        if m and int(m.view(1)[0].mp_length) != 0 {
            return m.view(1)[0].mp_length(o);
        }
        sq = tp.view(1)[0].tp_as_sequence;
        if sq and int(sq.view(1)[0].sq_length) != 0 {
            type_error(ptr[u8]("%.200s is not a mapping"), o);
            return -1;
        }

        type_error(ptr[u8]("object of type '%.200s' has no len()"), o);
        return -1;
    }  def PyMapping_Length(o: ptr[PyObject]) -> i64 {
        return PyMapping_Size(o);
    }  def PyMapping_GetItemString(o: ptr[PyObject], key: ptr[u8]) -> ptr[PyObject] {
        if not key {
            return null_error();
        }
        okey = unicode_from_c(key);
        if not okey {
            return NULL;
        }
        r = PyObject_GetItem(o, okey);
        object_decref(okey);
        return r;
    }  def PyMapping_GetOptionalItemString(
        obj_: ptr[PyObject], key: ptr[u8], result: ptr[ptr[PyObject]]
    ) -> i32 {
        (rc, item) = get_optional_item_string(obj_, key);
        result.view(1)[0] = item;
        return rc;
    }  def PyMapping_SetItemString(
        o: ptr[PyObject], key: ptr[u8], value: ptr[PyObject]
    ) -> i32 {
        if not key {
            null_error();
            return i32(-1);
        }
        okey = unicode_from_c(key);
        if not okey {
            return i32(-1);
        }
        r = PyObject_SetItem(o, okey, value);
        object_decref(okey);
        return r;
    }  def PyMapping_HasKeyStringWithError(obj_: ptr[PyObject], key: ptr[u8]) -> i32 {
        (rc, res) = get_optional_item_string(obj_, key);
        object_xdecref(res);
        return rc;
    }  def PyMapping_HasKeyWithError(obj_: ptr[PyObject], key: ptr[PyObject]) -> i32 {
        (rc, res) = get_optional_item(obj_, key);
        object_xdecref(res);
        return rc;
    }  def PyMapping_HasKeyString(obj_: ptr[PyObject], key: ptr[u8]) -> i32 {
        rc = i32(-1);
        value = NULL;
        if not obj_ {
            null_error();
        } else {
            (rc, value) = get_optional_item_string(obj_, key);
        }
        if rc < i32(0) {
            PyErr_FormatUnraisable(
                ptr[u8](
                    "Exception ignored in PyMapping_HasKeyString(); consider using PyMapping_HasKeyStringWithError(), PyMapping_GetOptionalItemString() or PyMapping_GetItemString()"
                )
            );
            return i32(0);
        }
        object_xdecref(value);
        return rc;
    }  def PyMapping_HasKey(obj_: ptr[PyObject], key: ptr[PyObject]) -> i32 {
        rc = i32(-1);
        value = NULL;
        if not obj_ or not key {
            null_error();
        } else {
            (rc, value) = get_optional_item(obj_, key);
        }
        if rc < i32(0) {
            PyErr_FormatUnraisable(
                ptr[u8](
                    "Exception ignored in PyMapping_HasKey(); consider using PyMapping_HasKeyWithError(), PyMapping_GetOptionalItem() or PyObject_GetItem()"
                )
            );
            return i32(0);
        }
        object_xdecref(value);
        return rc;
    }  def PyMapping_Keys(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        if dict_check_exact(o) {
            return PyDict_Keys(o);
        }
        return method_output_as_list(o, interned_keys());
    }  def PyMapping_Items(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        if dict_check_exact(o) {
            return PyDict_Items(o);
        }
        return method_output_as_list(o, interned_items());
    }  def PyMapping_Values(o: ptr[PyObject]) -> ptr[PyObject] {
        if not o {
            return null_error();
        }
        if dict_check_exact(o) {
            return PyDict_Values(o);
        }
        return method_output_as_list(o, interned_values());
    }  def PyObject_IsInstance(inst: ptr[PyObject], cls: ptr[PyObject]) -> i32 {
        return object_recursive_isinstance(inst, cls);
    }  def PyObject_IsSubclass(derived: ptr[PyObject], cls: ptr[PyObject]) -> i32 {
        return object_issubclass(derived, cls);
    }  def _PyObject_RealIsInstance(inst: ptr[PyObject], cls: ptr[PyObject]) -> i32 {
        return object_isinstance(inst, cls);
    }  def _PyObject_RealIsSubclass(derived: ptr[PyObject], cls: ptr[PyObject]) -> i32 {
        return recursive_issubclass(derived, cls);
    }  def PyObject_GetIter(o: ptr[PyObject]) -> ptr[PyObject] {
        t = object_type(o);
        if int(t.view(1)[0].tp_iter) == 0 {
            if PySequence_Check(o) != i32(0) {
                return PySeqIter_New(o);
            }
            return type_error(ptr[u8]("'%.200s' object is not iterable"), o);
        }
        res = t.view(1)[0].tp_iter(o);
        if res and not iter_check(res) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("iter() returned non-iterator of type '%.100s'"),
                tp_name(res)
            );
            object_decref(res);
            return NULL;
        }
        return res;
    }  def PyObject_GetAIter(o: ptr[PyObject]) -> ptr[PyObject] {
        am = object_type(o).view(1)[0].tp_as_async;
        if not am or int(am.view(1)[0].am_aiter) == 0 {
            return type_error(ptr[u8]("'%.200s' object is not an async iterable"), o);
        }
        it = am.view(1)[0].am_aiter(o);
        if it and PyAIter_Check(it) == i32(0) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("aiter() returned not an async iterator of type '%.100s'"),
                tp_name(it)
            );
            object_decref(it);
            return NULL;
        }
        return it;
    }  def PyIter_Check(obj_: ptr[PyObject]) -> i32 {
        return i32(1) if iter_check(obj_) else i32(0);
    }  def PyAIter_Check(obj_: ptr[PyObject]) -> i32 {
        am = object_type(obj_).view(1)[0].tp_as_async;
        if not am {
            return i32(0);
        }
        anext = int(am.view(1)[0].am_anext);
        if anext != 0 and anext != int(ptr(_PyObject_NextNotImplemented)) {
            return i32(1);
        }
        return i32(0);
    }  def PyIter_NextItem(iter: ptr[PyObject], item: ptr[ptr[PyObject]]) -> i32 {
        if int(object_type(iter).view(1)[0].tp_iternext) == 0 {
            item.view(1)[0] = NULL;
            PyErr_Format(
                PyExc_TypeError, ptr[u8]("expected an iterator, got '%T'"), iter
            );
            return i32(-1);
        }
        (status, next) = iternext(iter);
        item.view(1)[0] = next;
        return status;
    }  def PyIter_Next(iter: ptr[PyObject]) -> ptr[PyObject] {
        (status, item) = iternext(iter);
        return item;
    }  def PyIter_Send(
        iter: ptr[PyObject], arg: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32 {
        tp = object_type(iter);
        am = tp.view(1)[0].tp_as_async;
        if am and int(am.view(1)[0].am_send) != 0 {
            return am.view(1)[0].am_send(iter, arg, result);
        }
        if arg == Py_None and iter_check(iter) {
            result.view(1)[0] = tp.view(1)[0].tp_iternext(iter);
        } else {
            result.view(1)[0] = call_method_one_arg(iter, interned_send(), arg);
        }
        if result.view(1)[0] {
            return PYGEN_NEXT;
        }
        value = NULL;
        status = _PyGen_FetchStopIterationValue(&mut value);
        result.view(1)[0] = value;
        if status == i32(0) {
            return PYGEN_RETURN;
        }
        return PYGEN_ERROR;
    }
}

impl interned_length_hint -> ptr[PyObject] {
    if not length_hint_key {
        length_hint_key = PyUnicode_InternFromString(ptr[u8]("__length_hint__"));
    }
    return length_hint_key;
}

impl interned_class_getitem -> ptr[PyObject] {
    if not class_getitem_key {
        class_getitem_key = PyUnicode_InternFromString(ptr[u8]("__class_getitem__"));
    }
    return class_getitem_key;
}

impl interned_format -> ptr[PyObject] {
    if not format_key {
        format_key = PyUnicode_InternFromString(ptr[u8]("__format__"));
    }
    return format_key;
}

impl interned_keys -> ptr[PyObject] {
    if not keys_key {
        keys_key = PyUnicode_InternFromString(ptr[u8]("keys"));
    }
    return keys_key;
}

impl interned_items -> ptr[PyObject] {
    if not items_key {
        items_key = PyUnicode_InternFromString(ptr[u8]("items"));
    }
    return items_key;
}

impl interned_values -> ptr[PyObject] {
    if not values_key {
        values_key = PyUnicode_InternFromString(ptr[u8]("values"));
    }
    return values_key;
}

impl interned_bases -> ptr[PyObject] {
    if not bases_key {
        bases_key = PyUnicode_InternFromString(ptr[u8]("__bases__"));
    }
    return bases_key;
}

impl interned_class -> ptr[PyObject] {
    if not class_key {
        class_key = PyUnicode_InternFromString(ptr[u8]("__class__"));
    }
    return class_key;
}

impl interned_instancecheck -> ptr[PyObject] {
    if not instancecheck_key {
        instancecheck_key = PyUnicode_InternFromString(ptr[u8]("__instancecheck__"));
    }
    return instancecheck_key;
}

impl interned_subclasscheck -> ptr[PyObject] {
    if not subclasscheck_key {
        subclasscheck_key = PyUnicode_InternFromString(ptr[u8]("__subclasscheck__"));
    }
    return subclasscheck_key;
}

impl interned_send -> ptr[PyObject] {
    if not send_key {
        send_key = PyUnicode_InternFromString(ptr[u8]("send"));
    }
    return send_key;
}

impl tp_name(op: ptr[PyObject]) -> ptr[u8] {
    return object_type(op).view(1)[0].tp_name;
}

impl index_check(obj_: ptr[PyObject]) -> bool {
    nb = object_type(obj_).view(1)[0].tp_as_number;
    if not nb {
        return False;
    }
    return int(nb.view(1)[0].nb_index) != 0;
}

impl long_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl long_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyLong_Type)));
}

impl long_is_negative(op: ptr[PyObject]) -> bool {
    return (ptr[PyLongObject](op).view(1)[0].long_value.lv_tag & _PyLong_SIGN_MASK)
        == LONG_SIGN_NEGATIVE;
}

impl float_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyFloat_Type)));
}

impl float_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(PyFloat_Type)));
}

impl float_value(op: ptr[PyObject]) -> f64 {
    return ptr[PyFloatObject](op).view(1)[0].ob_fval;
}

impl complex_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(PyComplex_Type)));
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl unicode_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyUnicode_Type)));
}

impl unicode_length(op: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](op) + PyASCIIObject_LENGTH).view(1)[0];
}

impl bytes_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BYTES_SUBCLASS);
}

impl bytes_data(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + PyBytesObject_OB_SVAL;
}

impl bytearray_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(PyByteArray_Type)));
}

impl tuple_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl tuple_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyTuple_Type)));
}

impl list_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyList_Type)));
}

impl dict_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}

impl dict_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyDict_Type)));
}

impl type_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TYPE_SUBCLASS);
}

impl type_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyType_Type)));
}

impl union_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(_PyUnion_Type)));
}

impl item_array(address: int) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](address);
}

impl buffer_at(address: int) -> ptr[Py_buffer] {
    return ptr[Py_buffer](address);
}

impl unicode_from_c(s: ptr[u8]) -> ptr[PyObject] {
    return PyUnicode_FromStringAndSize(s, i64(strlen(s)));
}

impl set_c_string(exception: ptr[PyObject], message: ptr[u8]) {
    value = unicode_from_c(message);
    if value {
        PyErr_SetObject(exception, value);
        object_decref(value);
    }
}

impl type_error(msg: ptr[u8], op: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_Format(PyExc_TypeError, msg, tp_name(op));
    return NULL;
}

impl null_error -> ptr[PyObject] {
    if not exception_raised(thread_state()) {
        PyErr_SetString(
            PyExc_SystemError, ptr[u8]("null argument to internal routine")
        );
    }
    return NULL;
}

impl call_method_no_args(
    self_obj: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackSlots = StackSlots();
    args = item_array(jacpy_stack_address(&mut slots)) + 1;
    args.view(1)[0] = self_obj;
    return PyObject_VectorcallMethod(
        name, args, u64(1) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
}

impl call_method_one_arg(
    self_obj: ptr[PyObject], name: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own StackSlots = StackSlots();
    args = item_array(jacpy_stack_address(&mut slots)) + 1;
    args.view(1)[0] = self_obj;
    (args + 1).view(1)[0] = arg;
    return PyObject_VectorcallMethod(
        name, args, u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
}

impl nb_slot(nb: ptr[PyNumberMethods], slot: i64) -> int {
    return int(ptr[ptr](ptr[u8](nb) + slot).view(1)[0]);
}

impl call_binary(func: int, v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    slot = ptr[NumberCall](
        __thread_local_block("jac_object_model_abstract_number_call", 24)
    );
    slot.view(1)[0].binary = func;
    return slot.view(1)[0].binary(v, w);
}

impl call_ternary(
    func: int, v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
) -> ptr[PyObject] {
    slot = ptr[NumberCall](
        __thread_local_block("jac_object_model_abstract_number_call", 24)
    );
    slot.view(1)[0].ternary = func;
    return slot.view(1)[0].ternary(v, w, z);
}

impl call_repeat(func: int, seq: ptr[PyObject], count: i64) -> ptr[PyObject] {
    slot = ptr[NumberCall](
        __thread_local_block("jac_object_model_abstract_number_call", 24)
    );
    slot.view(1)[0].repeat = func;
    return slot.view(1)[0].repeat(seq, count);
}

impl binary_op1(v: ptr[PyObject], w: ptr[PyObject], op_slot: i64) -> ptr[PyObject] {
    tv = object_type(v);
    tw = object_type(w);
    slotv = 0;
    mv = tv.view(1)[0].tp_as_number;
    if mv {
        slotv = nb_slot(mv, op_slot);
    }
    slotw = 0;
    if tw != tv {
        mw = tw.view(1)[0].tp_as_number;
        if mw {
            slotw = nb_slot(mw, op_slot);
            if slotw == slotv {
                slotw = 0;
            }
        }
    }
    if slotv != 0 {
        if slotw != 0 and PyType_IsSubtype(ptr[PyObject](tw), ptr[PyObject](tv)) != 0 {
            x = call_binary(slotw, v, w);
            if x != Py_NotImplemented {
                return x;
            }

            object_decref(x);
            slotw = 0;
        }
        x = call_binary(slotv, v, w);
        if x != Py_NotImplemented {
            return x;
        }
        object_decref(x);
    }
    if slotw != 0 {
        x = call_binary(slotw, v, w);
        if x != Py_NotImplemented {
            return x;
        }
        object_decref(x);
    }
    return object_new_ref(Py_NotImplemented);
}

impl binop_type_error(
    v: ptr[PyObject], w: ptr[PyObject], op_name: ptr[u8]
) -> ptr[PyObject] {
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("unsupported operand type(s) for %.100s: '%.100s' and '%.100s'"),
        op_name,
        tp_name(v),
        tp_name(w)
    );
    return NULL;
}

impl binary_op(
    v: ptr[PyObject], w: ptr[PyObject], op_slot: i64, op_name: ptr[u8]
) -> ptr[PyObject] {
    result = binary_op1(v, w, op_slot);
    if result == Py_NotImplemented {
        object_decref(result);
        return binop_type_error(v, w, op_name);
    }
    return result;
}

impl ternary_op(
    v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject], op_slot: i64, op_name: ptr[u8]
) -> ptr[PyObject] {
    tv = object_type(v);
    tw = object_type(w);
    mv = tv.view(1)[0].tp_as_number;
    mw = tw.view(1)[0].tp_as_number;
    slotv = 0;
    if mv {
        slotv = nb_slot(mv, op_slot);
    }
    slotw = 0;
    if tw != tv and mw {
        slotw = nb_slot(mw, op_slot);
        if slotw == slotv {
            slotw = 0;
        }
    }
    if slotv != 0 {
        if slotw != 0 and PyType_IsSubtype(ptr[PyObject](tw), ptr[PyObject](tv)) != 0 {
            x = call_ternary(slotw, v, w, z);
            if x != Py_NotImplemented {
                return x;
            }

            object_decref(x);
            slotw = 0;
        }
        x = call_ternary(slotv, v, w, z);
        if x != Py_NotImplemented {
            return x;
        }
        object_decref(x);
    }
    if slotw != 0 {
        x = call_ternary(slotw, v, w, z);
        if x != Py_NotImplemented {
            return x;
        }
        object_decref(x);
    }
    mz = object_type(z).view(1)[0].tp_as_number;
    if mz {
        slotz = nb_slot(mz, op_slot);
        if slotz == slotv or slotz == slotw {
            slotz = 0;
        }
        if slotz != 0 {
            x = call_ternary(slotz, v, w, z);
            if x != Py_NotImplemented {
                return x;
            }
            object_decref(x);
        }
    }
    if z == Py_None {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("unsupported operand type(s) for %.100s: '%.100s' and '%.100s'"),
            op_name,
            tp_name(v),
            tp_name(w)
        );
    } else {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "unsupported operand type(s) for %.100s: '%.100s', '%.100s', '%.100s'"
            ),
            op_name,
            tp_name(v),
            tp_name(w),
            tp_name(z)
        );
    }
    return NULL;
}

impl sequence_repeat(
    repeatfunc: int, seq: ptr[PyObject], n: ptr[PyObject]
) -> ptr[PyObject] {
    if not index_check(n) {
        return type_error(
            ptr[u8]("can't multiply sequence by non-int of type '%.200s'"), n
        );
    }
    count = PyNumber_AsSsize_t(n, PyExc_OverflowError);
    if count == -1 and PyErr_Occurred() {
        return NULL;
    }
    return call_repeat(repeatfunc, seq, count);
}

impl binary_iop1(
    v: ptr[PyObject], w: ptr[PyObject], iop_slot: i64, op_slot: i64
) -> ptr[PyObject] {
    mv = object_type(v).view(1)[0].tp_as_number;
    if mv {
        slot = nb_slot(mv, iop_slot);
        if slot != 0 {
            x = call_binary(slot, v, w);
            if x != Py_NotImplemented {
                return x;
            }
            object_decref(x);
        }
    }
    return binary_op1(v, w, op_slot);
}

impl binary_iop(
    v: ptr[PyObject], w: ptr[PyObject], iop_slot: i64, op_slot: i64, op_name: ptr[u8]
) -> ptr[PyObject] {
    result = binary_iop1(v, w, iop_slot, op_slot);
    if result == Py_NotImplemented {
        object_decref(result);
        return binop_type_error(v, w, op_name);
    }
    return result;
}

impl ternary_iop(
    v: ptr[PyObject],
    w: ptr[PyObject],
    z: ptr[PyObject],
    iop_slot: i64,
    op_slot: i64,
    op_name: ptr[u8]
) -> ptr[PyObject] {
    mv = object_type(v).view(1)[0].tp_as_number;
    if mv {
        slot = nb_slot(mv, iop_slot);
        if slot != 0 {
            x = call_ternary(slot, v, w, z);
            if x != Py_NotImplemented {
                return x;
            }
            object_decref(x);
        }
    }
    return ternary_op(v, w, z, op_slot, op_name);
}

impl is_fortran_contiguous(view: ptr[Py_buffer]) -> i32 {
    if view.view(1)[0].length == 0 {
        return i32(1);
    }
    ndim = i64(view.view(1)[0].ndim);
    shape = view.view(1)[0].shape;
    strides = view.view(1)[0].strides;
    if not strides {
        if ndim <= 1 {
            return i32(1);
        }
        sd: i64 = 0;
        for i in range(ndim) {
            if (shape + i).view(1)[0] > 1 {
                sd += 1;
            }
        }
        return i32(1) if sd <= 1 else i32(0);
    }
    sd = view.view(1)[0].itemsize;
    for i in range(ndim) {
        dim = (shape + i).view(1)[0];
        if dim > 1 and (strides + i).view(1)[0] != sd {
            return i32(0);
        }
        sd *= dim;
    }
    return i32(1);
}

impl is_c_contiguous(view: ptr[Py_buffer]) -> i32 {
    if view.view(1)[0].length == 0 {
        return i32(1);
    }
    strides = view.view(1)[0].strides;
    if not strides {
        return i32(1);
    }
    shape = view.view(1)[0].shape;
    sd = view.view(1)[0].itemsize;
    i = i64(view.view(1)[0].ndim) - 1;
    while i >= 0 {
        dim = (shape + i).view(1)[0];
        if dim > 1 and (strides + i).view(1)[0] != sd {
            return i32(0);
        }
        sd *= dim;
        i -= 1;
    }
    return i32(1);
}

impl add_one_to_index_F(nd: i64, index: ptr[i64], shape: ptr[i64]) {
    for k in range(nd) {
        if (index + k).view(1)[0] < (shape + k).view(1)[0] - 1 {
            (index + k).view(1)[0] = (index + k).view(1)[0] + 1;
            break;
        }
        (index + k).view(1)[0] = 0;
    }
}

impl add_one_to_index_C(nd: i64, index: ptr[i64], shape: ptr[i64]) {
    k = nd - 1;
    while k >= 0 {
        if (index + k).view(1)[0] < (shape + k).view(1)[0] - 1 {
            (index + k).view(1)[0] = (index + k).view(1)[0] + 1;
            break;
        }
        (index + k).view(1)[0] = 0;
        k -= 1;
    }
}

impl as_read_buffer(
    obj_: ptr[PyObject], buffer: ptr[ptr], buffer_len: ptr[i64]
) -> i32 {
    if not obj_ or not buffer or not buffer_len {
        null_error();
        return i32(-1);
    }
    slots: own StackSlots = StackSlots();
    view = buffer_at(jacpy_stack_address(&mut slots));
    if PyObject_GetBuffer(obj_, view, PyBUF_SIMPLE) != 0 {
        return i32(-1);
    }
    buffer.view(1)[0] = view.view(1)[0].buf;
    buffer_len.view(1)[0] = view.view(1)[0].length;
    PyBuffer_Release(view);
    return i32(0);
}

impl buffer_release_call(arg: ptr) -> i32 {
    PyBuffer_Release(ptr[Py_buffer](arg));
    return i32(0);
}

impl list_append_take_ref(list_op: ptr[PyObject], newitem: ptr[PyObject]) -> i32 {
    lo = ptr[PyListObject](list_op);
    length = object_size(list_op);
    if lo.view(1)[0].allocated > length {
        (lo.view(1)[0].ob_item + length).view(1)[0] = newitem;
        ptr[PyVarObject](list_op).view(1)[0].ob_size = length + 1;
        return i32(0);
    }
    return _PyList_AppendTakeRefListResize(list_op, newitem);
}

impl release_items(items: ptr[ptr[PyObject]], n: i64) {
    i = n;
    while i > 0 {
        i -= 1;
        object_decref((items + i).view(1)[0]);
    }
}

impl method_output_as_list(o: ptr[PyObject], meth: ptr[PyObject]) -> ptr[PyObject] {
    meth_output = call_method_no_args(o, meth);
    if not meth_output or list_check_exact(meth_output) {
        return meth_output;
    }
    it = PyObject_GetIter(meth_output);
    if not it {
        if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("%.200s.%U() returned a non-iterable (type %.200s)"),
                tp_name(o),
                meth,
                tp_name(meth_output)
            );
        }
        object_decref(meth_output);
        return NULL;
    }
    object_decref(meth_output);
    result = PySequence_List(it);
    object_decref(it);
    return result;
}

impl get_optional_item(
    obj_: ptr[PyObject], key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    item = NULL;
    if dict_check_exact(obj_) {
        rc = PyDict_GetItemRef(obj_, key, &mut item);
        return (rc, item);
    }
    item = PyObject_GetItem(obj_, key);
    if item {
        return (i32(1), item);
    }
    if PyErr_ExceptionMatches(PyExc_KeyError) == 0 {
        return (i32(-1), item);
    }
    PyErr_Clear();
    return (i32(0), item);
}

impl get_optional_item_string(
    obj_: ptr[PyObject], key: ptr[u8]
) -> tuple[i32, ptr[PyObject]] {
    if not key {
        null_error();
        return (i32(-1), NULL);
    }
    okey = unicode_from_c(key);
    if not okey {
        return (i32(-1), NULL);
    }
    (rc, item) = get_optional_item(obj_, okey);
    object_decref(okey);
    return (rc, item);
}

impl abstract_get_bases(cls: ptr[PyObject]) -> ptr[PyObject] {
    bases = NULL;
    PyObject_GetOptionalAttr(cls, interned_bases(), &mut bases);
    if bases and not tuple_check(bases) {
        object_decref(bases);
        return NULL;
    }
    return bases;
}

impl abstract_issubclass(derived_in: ptr[PyObject], cls: ptr[PyObject]) -> i32 {
    derived = derived_in;
    bases = NULL;
    n: i64 = 0;
    while True {
        if derived == cls {
            object_xdecref(bases);
            return i32(1);
        }

        next_bases = abstract_get_bases(derived);
        object_xdecref(bases);
        bases = next_bases;
        if not bases {
            if PyErr_Occurred() {
                return i32(-1);
            }
            return i32(0);
        }
        n = object_size(bases);
        if n == 0 {
            object_decref(bases);
            return i32(0);
        }

        if n == 1 {
            derived = tuple_get_item(bases, 0);
            continue;
        }
        break;
    }
    if Py_EnterRecursiveCall(ptr[u8](" in __issubclass__")) != 0 {
        object_decref(bases);
        return i32(-1);
    }
    r = i32(0);
    for i in range(n) {
        r = abstract_issubclass(tuple_get_item(bases, i), cls);
        if r != i32(0) {
            break;
        }
    }
    object_decref(bases);
    return r;
}

impl check_class(cls: ptr[PyObject], error: ptr[u8]) -> i32 {
    bases = abstract_get_bases(cls);
    if not bases {
        if not exception_raised(thread_state()) {
            PyErr_SetString(PyExc_TypeError, error);
        }
        return i32(0);
    }
    object_decref(bases);
    return i32(-1);
}

impl object_isinstance(inst: ptr[PyObject], cls: ptr[PyObject]) -> i32 {
    icls = NULL;
    retval = i32(0);
    if type_check(cls) {
        retval = i32(1) if object_type_check(inst, ptr[PyTypeObject](cls)) else i32(0);
        if retval == i32(0) {
            retval = PyObject_GetOptionalAttr(inst, interned_class(), &mut icls);
            if icls {
                if icls != ptr[PyObject](object_type(inst)) and type_check(icls) {
                    retval = PyType_IsSubtype(icls, cls);
                } else {
                    retval = i32(0);
                }
                object_decref(icls);
            }
        }
    } else {
        if check_class(
            cls,
            ptr[u8]("isinstance() arg 2 must be a type, a tuple of types, or a union")
        )
            == i32(0) {
            return i32(-1);
        }
        retval = PyObject_GetOptionalAttr(inst, interned_class(), &mut icls);
        if icls {
            retval = abstract_issubclass(icls, cls);
            object_decref(icls);
        }
    }
    return retval;
}

impl object_recursive_isinstance(inst: ptr[PyObject], cls_in: ptr[PyObject]) -> i32 {
    cls = cls_in;

    if object_is_type(inst, ptr[PyTypeObject](cls)) {
        return i32(1);
    }

    if type_check_exact(cls) {
        return object_isinstance(inst, cls);
    }
    if union_check(cls) {
        cls = _Py_union_args(cls);
    }
    if tuple_check(cls) {
        if Py_EnterRecursiveCall(ptr[u8](" in __instancecheck__")) != 0 {
            return i32(-1);
        }
        r = i32(0);
        for i in range(object_size(cls)) {
            r = object_recursive_isinstance(inst, tuple_get_item(cls, i));
            if r != i32(0) {
                break;
            }
        }
        return r;
    }
    checker = _PyObject_LookupSpecial(cls, interned_instancecheck());
    if checker {
        if Py_EnterRecursiveCall(ptr[u8](" in __instancecheck__")) != 0 {
            object_decref(checker);
            return i32(-1);
        }
        res = PyObject_CallOneArg(checker, inst);
        object_decref(checker);
        if not res {
            return i32(-1);
        }
        ok = PyObject_IsTrue(res);
        object_decref(res);
        return ok;
    } elif exception_raised(thread_state()) {
        return i32(-1);
    }

    return object_isinstance(inst, cls);
}

impl recursive_issubclass(derived: ptr[PyObject], cls: ptr[PyObject]) -> i32 {
    if type_check(cls) and type_check(derived) {
        return PyType_IsSubtype(derived, cls);
    }
    if check_class(derived, ptr[u8]("issubclass() arg 1 must be a class")) == i32(0) {
        return i32(-1);
    }
    if not union_check(cls)
        and check_class(
            cls,
            ptr[u8](
                "issubclass() arg 2 must be a class, a tuple of classes, or a union"
            )
        )
            == i32(0) {
        return i32(-1);
    }
    return abstract_issubclass(derived, cls);
}

impl object_issubclass(derived: ptr[PyObject], cls_in: ptr[PyObject]) -> i32 {
    cls = cls_in;

    if type_check_exact(cls) {
        if derived == cls {
            return i32(1);
        }
        return recursive_issubclass(derived, cls);
    }
    if union_check(cls) {
        cls = _Py_union_args(cls);
    }
    if tuple_check(cls) {
        if Py_EnterRecursiveCall(ptr[u8](" in __subclasscheck__")) != 0 {
            return i32(-1);
        }
        r = i32(0);
        for i in range(object_size(cls)) {
            r = object_issubclass(derived, tuple_get_item(cls, i));
            if r != i32(0) {
                break;
            }
        }
        return r;
    }
    checker = _PyObject_LookupSpecial(cls, interned_subclasscheck());
    if checker {
        ok = i32(-1);
        if Py_EnterRecursiveCall(ptr[u8](" in __subclasscheck__")) != 0 {
            object_decref(checker);
            return ok;
        }
        res = PyObject_CallOneArg(checker, derived);
        object_decref(checker);
        if res {
            ok = PyObject_IsTrue(res);
            object_decref(res);
        }
        return ok;
    } elif exception_raised(thread_state()) {
        return i32(-1);
    }

    return recursive_issubclass(derived, cls);
}

impl iter_check(obj_: ptr[PyObject]) -> bool {
    next = int(object_type(obj_).view(1)[0].tp_iternext);
    return next != 0 and next != int(ptr(_PyObject_NextNotImplemented));
}

impl iternext(iter: ptr[PyObject]) -> tuple[i32, ptr[PyObject]] {
    item = object_type(iter).view(1)[0].tp_iternext(iter);
    if item {
        return (i32(1), item);
    }

    exc = error_occurred(thread_state());
    if not exc {
        return (i32(0), item);
    }
    if PyErr_GivenExceptionMatches(exc, PyExc_StopIteration) != 0 {
        PyErr_Clear();
        return (i32(0), item);
    }

    return (i32(-1), item);
}
