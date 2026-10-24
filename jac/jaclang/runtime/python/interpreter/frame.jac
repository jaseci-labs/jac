import from c {
    glob _PyNone_Type: PyTypeObject,
         PyCode_Type: PyTypeObject,
         PyMethod_Type: PyTypeObject,
         PyMethodDescr_Type: PyTypeObject,
         PyDict_Type: PyTypeObject; def strlen(text: ptr[u8]) -> u64;  def _PyFrame_New_NoTrack(
        code: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyFrame_GetLocals(frame: ptr[u8]) -> ptr[PyObject];  def _PyGC_VisitFrameStack(
        frame: ptr[u8], visitor: ptr, arg: ptr
    ) -> i32;  def _PyGC_VisitStackRef(ref: ptr[u64], visitor: ptr, arg: ptr) -> i32;  def PyCode_Addr2Line(
        co: ptr[PyObject], addrq: i32
    ) -> i32;  def _PySys_GetRequiredAttr(name: ptr[PyObject]) -> ptr[PyObject];  def _PyUnicode_FromASCII(
        buffer: ptr[u8], size: i64
    ) -> ptr[PyObject];  def _PyAsyncGenValueWrapperNew(
        tstate: ptr, val: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_make_typevar(
        name: ptr[PyObject],
        evaluate_bound: ptr[PyObject],
        evaluate_constraints: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_make_paramspec(
        _tstate: ptr, v: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_make_typevartuple(
        _tstate: ptr, v: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_subscript_generic(
        _tstate: ptr, params_in: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_make_typealias(
        _tstate: ptr, args: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_set_function_type_params(
        _tstate: ptr, func: ptr[PyObject], type_params: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_set_typeparam_default(
        _tstate: ptr, typeparam: ptr[PyObject], evaluate_default: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyExc_PrepReraiseStar(
        orig: ptr[PyObject], excs: ptr[PyObject]
    ) -> ptr[PyObject];  obj intrinsic_func1_info {
        has func: Callable[[ptr, ptr[PyObject]], ptr[PyObject]] = 0,
            name: ptr[u8] = ptr[u8]();
    }  obj intrinsic_func2_info {
        has func: Callable[[ptr, ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            name: ptr[u8] = ptr[u8]();
    }
}

glob:priv STACKREF_NULL: u64 = u64(1),
     STACKREF_TAG_REFCNT: u64 = u64(1),
     STACKREF_TAG_BITS: u64 = u64(3),
     STACKREF_INT_TAG: u64 = u64(3),
     STACKREF_PTR_MASK: u64 = u64(0xFFFFFFFFFFFFFFFE),
     MAX_INTRINSIC_1: i32 = 11,
     MAX_INTRINSIC_2: i32 = 5,
     Py_object_stack_chunks_MAXFREELIST: i64 = 4;

def object_is_immortal(op: ptr[PyObject]) -> bool;

def stackref_borrow(bits: u64) -> ptr[PyObject];

def stackref_is_null_or_int(bits: u64) -> bool;

def stackref_xclose(bits: u64);

def stackref_clear(slot: ptr[u64]);

def stackref_dup(bits: u64) -> u64;

def stackref_is_heap_safe(bits: u64) -> bool;

def stackref_make_heap_safe(bits: u64) -> u64;

def iframe_ref(frame: ptr[u8], offset: i64) -> u64;

def set_iframe_ref(frame: ptr[u8], offset: i64, bits: u64);

def iframe_ptr(frame: ptr[u8], offset: i64) -> ptr[u8];

def set_iframe_ptr(frame: ptr[u8], offset: i64, value: ptr[u8]);

def iframe_object(frame: ptr[u8], offset: i64) -> ptr[PyObject];

def set_iframe_object(frame: ptr[u8], offset: i64, value: ptr[PyObject]);

def code_i32(code: ptr[PyObject], offset: i64) -> i32;

def iframe_code(frame: ptr[u8]) -> ptr[PyObject];

def iframe_bytecode(frame: ptr[u8]) -> ptr[u8];

def iframe_lasti(frame: ptr[u8]) -> i32;

def iframe_is_incomplete(frame: ptr[u8]) -> bool;

def iframe_first_complete(frame_in: ptr[u8]) -> ptr[u8];

def iframe_copy(src: ptr[u8], dest: ptr[u8]);

def tstate_current_frame(tstate: ptr) -> ptr[u8];

def py_id(offset: i64) -> ptr[PyObject];

def unicode_check(op: ptr[PyObject]) -> bool;

def dict_check_exact(op: ptr[PyObject]) -> bool;

def freelist_pop_mem(offset: i64) -> ptr[u8];

def chunk_prev(buf: ptr[u8]) -> ptr[u8];

def set_chunk_prev(buf: ptr[u8], prev: ptr[u8]);

def set_chunk_n(buf: ptr[u8], n: i64);

def stack_head(stack: ptr[u8]) -> ptr[u8];

def set_stack_head(stack: ptr[u8], head: ptr[u8]);

import from c {
    def _PyFrame_Traverse(frame: ptr[u8], visitor: ptr, arg: ptr) -> i32 {
        vret: i32 = 0;
        vret = visit_reference(
            iframe_object(frame, _PyInterpreterFrame_FRAME_OBJ), visitor, arg
        );
        if vret != 0 {
            return vret;
        }
        vret = visit_reference(
            iframe_object(frame, _PyInterpreterFrame_F_LOCALS), visitor, arg
        );
        if vret != 0 {
            return vret;
        }
        if not stackref_is_null_or_int(
            iframe_ref(frame, _PyInterpreterFrame_F_FUNCOBJ)
        ) {
            vret = _PyGC_VisitStackRef(
                ptr[u64](frame + _PyInterpreterFrame_F_FUNCOBJ), visitor, arg
            );
            if vret != 0 {
                return vret;
            }
        }
        if not stackref_is_null_or_int(
            iframe_ref(frame, _PyInterpreterFrame_F_EXECUTABLE)
        ) {
            vret = _PyGC_VisitStackRef(
                ptr[u64](frame + _PyInterpreterFrame_F_EXECUTABLE), visitor, arg
            );
            if vret != 0 {
                return vret;
            }
        }
        return _PyGC_VisitFrameStack(frame, visitor, arg);
    }  def _PyFrame_MakeAndSetFrameObject(frame: ptr[u8]) -> ptr[PyObject] {
        exc = PyErr_GetRaisedException();
        f = _PyFrame_New_NoTrack(iframe_code(frame));
        if not f {
            object_xdecref(exc);
            return NULL;
        }
        PyErr_SetRaisedException(exc);
        ptr[ptr[u8]](ptr[u8](f) + PyFrameObject_FRAME).view(1)[0] = frame;
        set_iframe_object(frame, _PyInterpreterFrame_FRAME_OBJ, f);
        return f;
    }
}

def take_ownership(f: ptr[PyObject], frame: ptr[u8]);

import from c {
    def _PyFrame_ClearLocals(frame: ptr[u8]) {
        spp = ptr[ptr[u64]](frame + _PyInterpreterFrame_STACKPOINTER);
        sp = spp.view(1)[0];
        locals = ptr[u64](frame + _PyInterpreterFrame_LOCALSPLUS);
        spp.view(1)[0] = locals;
        while int(sp) > int(locals) {
            sp = sp - 1;
            stackref_xclose(sp.view(1)[0]);
        }
        slot = ptr[ptr[PyObject]](frame + _PyInterpreterFrame_F_LOCALS);
        old = slot.view(1)[0];
        if old {
            slot.view(1)[0] = NULL;
            object_decref(old);
        }
    }  def _PyFrame_ClearExceptCode(frame: ptr[u8]) {
        f = iframe_object(frame, _PyInterpreterFrame_FRAME_OBJ);
        if f {
            set_iframe_object(frame, _PyInterpreterFrame_FRAME_OBJ, NULL);
            if object_refcount(f) != 1 {
                take_ownership(f, frame);
                object_decref(f);
                return;
            }
            object_decref(f);
        }
        _PyFrame_ClearLocals(frame);
        stackref_clear(ptr[u64](frame + _PyInterpreterFrame_F_FUNCOBJ));
    }  def PyUnstable_InterpreterFrame_GetCode(frame: ptr[u8]) -> ptr[PyObject] {
        return object_new_ref(
            stackref_borrow(iframe_ref(frame, _PyInterpreterFrame_F_EXECUTABLE))
        );
    }  def PyUnstable_InterpreterFrame_GetLasti(frame: ptr[u8]) -> i32 {
        return i32.wrap(i64(iframe_lasti(frame)) * 2);
    }  def PyUnstable_InterpreterFrame_GetLine(frame: ptr[u8]) -> i32 {
        addr = i32.wrap(i64(iframe_lasti(frame)) * 2);
        return PyCode_Addr2Line(iframe_code(frame), addr);
    }  glob PyUnstable_ExecutableKinds: list[ptr[PyTypeObject]] = [
             addressof(_PyNone_Type),
             addressof(PyCode_Type),
             ptr[PyTypeObject](),
             addressof(PyMethod_Type),
             addressof(PyMethodDescr_Type),
             ptr[PyTypeObject]()
         ];
}

import from c {
    def _PyObjectStackChunk_New -> ptr[u8] {
        buf = freelist_pop_mem(_Py_freelists_OBJECT_STACK_CHUNKS);
        if not buf {
            buf = ptr[u8](PyMem_RawMalloc(u64(_PyObjectStackChunk_SIZE)));
            if not buf {
                return ptr[u8]();
            }
        }
        set_chunk_prev(buf, ptr[u8]());
        set_chunk_n(buf, 0);
        return buf;
    }  def _PyObjectStackChunk_Free(buf: ptr[u8]) {
        if not freelist_push(
            _Py_freelists_OBJECT_STACK_CHUNKS,
            ptr[PyObject](buf),
            Py_object_stack_chunks_MAXFREELIST
        ) {
            PyMem_RawFree(ptr(buf));
        }
    }  def _PyObjectStack_Clear(queue: ptr[u8]) {
        while stack_head(queue) {
            buf = stack_head(queue);
            set_chunk_n(buf, 0);
            set_stack_head(queue, chunk_prev(buf));
            _PyObjectStackChunk_Free(buf);
        }
    }  def _PyObjectStack_Merge(dst: ptr[u8], src: ptr[u8]) {
        if not stack_head(src) {
            return;
        }
        if stack_head(dst) {
            last = stack_head(src);
            while chunk_prev(last) {
                last = chunk_prev(last);
            }
            set_chunk_prev(last, stack_head(dst));
        }
        set_stack_head(dst, stack_head(src));
        set_stack_head(src, ptr[u8]());
    }
}

def no_intrinsic1(tstate: ptr, unused: ptr[PyObject]) -> ptr[PyObject];

def print_expr(ignored: ptr, value: ptr[PyObject]) -> ptr[PyObject];

def import_all_from(tstate: ptr, locals: ptr[PyObject], v: ptr[PyObject]) -> i32;

def import_star(tstate: ptr, from_: ptr[PyObject]) -> ptr[PyObject];

def stopiteration_error(tstate: ptr, exc: ptr[PyObject]) -> ptr[PyObject];

def unary_pos(unused: ptr, value: ptr[PyObject]) -> ptr[PyObject];

def list_to_tuple(unused: ptr, v: ptr[PyObject]) -> ptr[PyObject];

def make_typevar(ignored: ptr, v: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob _PyIntrinsics_UnaryFunctions: list[intrinsic_func1_info] = [
             intrinsic_func1_info(
                 func=no_intrinsic1, name=ptr[u8]("INTRINSIC_1_INVALID")
             ),
             intrinsic_func1_info(func=print_expr, name=ptr[u8]("INTRINSIC_PRINT")),
             intrinsic_func1_info(
                 func=import_star, name=ptr[u8]("INTRINSIC_IMPORT_STAR")
             ),
             intrinsic_func1_info(
                 func=stopiteration_error, name=ptr[u8]("INTRINSIC_STOPITERATION_ERROR")
             ),
             intrinsic_func1_info(
                 func=_PyAsyncGenValueWrapperNew,
                 name=ptr[u8]("INTRINSIC_ASYNC_GEN_WRAP")
             ),
             intrinsic_func1_info(
                 func=unary_pos, name=ptr[u8]("INTRINSIC_UNARY_POSITIVE")
             ),
             intrinsic_func1_info(
                 func=list_to_tuple, name=ptr[u8]("INTRINSIC_LIST_TO_TUPLE")
             ),
             intrinsic_func1_info(func=make_typevar, name=ptr[u8]("INTRINSIC_TYPEVAR")),
             intrinsic_func1_info(
                 func=_Py_make_paramspec, name=ptr[u8]("INTRINSIC_PARAMSPEC")
             ),
             intrinsic_func1_info(
                 func=_Py_make_typevartuple, name=ptr[u8]("INTRINSIC_TYPEVARTUPLE")
             ),
             intrinsic_func1_info(
                 func=_Py_subscript_generic, name=ptr[u8]("INTRINSIC_SUBSCRIPT_GENERIC")
             ),
             intrinsic_func1_info(
                 func=_Py_make_typealias, name=ptr[u8]("INTRINSIC_TYPEALIAS")
             )
         ];
}

def no_intrinsic2(
    tstate: ptr, unused1: ptr[PyObject], unused2: ptr[PyObject]
) -> ptr[PyObject];

def prep_reraise_star(
    unused: ptr, orig: ptr[PyObject], excs: ptr[PyObject]
) -> ptr[PyObject];

def make_typevar_with_bound(
    ignored: ptr, name: ptr[PyObject], evaluate_bound: ptr[PyObject]
) -> ptr[PyObject];

def make_typevar_with_constraints(
    ignored: ptr, name: ptr[PyObject], evaluate_constraints: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    glob _PyIntrinsics_BinaryFunctions: list[intrinsic_func2_info] = [
             intrinsic_func2_info(
                 func=no_intrinsic2, name=ptr[u8]("INTRINSIC_2_INVALID")
             ),
             intrinsic_func2_info(
                 func=prep_reraise_star, name=ptr[u8]("INTRINSIC_PREP_RERAISE_STAR")
             ),
             intrinsic_func2_info(
                 func=make_typevar_with_bound,
                 name=ptr[u8]("INTRINSIC_TYPEVAR_WITH_BOUND")
             ),
             intrinsic_func2_info(
                 func=make_typevar_with_constraints,
                 name=ptr[u8]("INTRINSIC_TYPEVAR_WITH_CONSTRAINTS")
             ),
             intrinsic_func2_info(
                 func=_Py_set_function_type_params,
                 name=ptr[u8]("INTRINSIC_SET_FUNCTION_TYPE_PARAMS")
             ),
             intrinsic_func2_info(
                 func=_Py_set_typeparam_default,
                 name=ptr[u8]("INTRINSIC_SET_TYPEPARAM_DEFAULT")
             )
         ]; def _PyCompile_GetUnaryIntrinsicName(index: i32) -> ptr[PyObject] {
        if index < 0 or index > MAX_INTRINSIC_1 {
            return NULL;
        }
        table = ptr[intrinsic_func1_info](addressof(_PyIntrinsics_UnaryFunctions));
        return PyUnicode_FromString((table + i64(index)).view(1)[0].name);
    }  def _PyCompile_GetBinaryIntrinsicName(index: i32) -> ptr[PyObject] {
        if index < 0 or index > MAX_INTRINSIC_2 {
            return NULL;
        }
        table = ptr[intrinsic_func2_info](addressof(_PyIntrinsics_BinaryFunctions));
        return PyUnicode_FromString((table + i64(index)).view(1)[0].name);
    }
}

impl object_is_immortal(op: ptr[PyObject]) -> bool {
    return (ptr[_object](op).view(1)[0].ob_refcnt_full & 0x80000000) != 0;
}

impl stackref_borrow(bits: u64) -> ptr[PyObject] {
    return ptr[PyObject](i64.wrap(bits & STACKREF_PTR_MASK));
}

impl stackref_is_null_or_int(bits: u64) -> bool {
    return bits == STACKREF_NULL or (bits & STACKREF_INT_TAG) == STACKREF_INT_TAG;
}

impl stackref_xclose(bits: u64) {
    if (bits & STACKREF_TAG_REFCNT) == u64(0) {
        op = ptr[PyObject](i64.wrap(bits));
        header = ptr[_object](op);
        full = header.view(1)[0].ob_refcnt_full - 1;
        header.view(1)[0].ob_refcnt_full = full;
        if (full & 0xFFFFFFFF) == 0 {
            _Py_Dealloc(op);
        }
    }
}

impl stackref_clear(slot: ptr[u64]) {
    old = slot.view(1)[0];
    slot.view(1)[0] = STACKREF_NULL;
    stackref_xclose(old);
}

impl stackref_dup(bits: u64) -> u64 {
    if (bits & STACKREF_TAG_REFCNT) == u64(0) {
        header = ptr[_object](ptr[PyObject](i64.wrap(bits)));
        header.view(1)[0].ob_refcnt_full = header.view(1)[0].ob_refcnt_full + 1;
    }
    return bits;
}

impl stackref_is_heap_safe(bits: u64) -> bool {
    return (bits & STACKREF_TAG_BITS) != STACKREF_TAG_REFCNT
        or bits == STACKREF_NULL
        or object_is_immortal(stackref_borrow(bits));
}

impl stackref_make_heap_safe(bits: u64) -> u64 {
    if stackref_is_heap_safe(bits) {
        return bits;
    }
    op = stackref_borrow(bits);
    object_incref(op);
    return u64.wrap(int(op));
}

impl iframe_ref(frame: ptr[u8], offset: i64) -> u64 {
    return ptr[u64](frame + offset).view(1)[0];
}

impl set_iframe_ref(frame: ptr[u8], offset: i64, bits: u64) {
    ptr[u64](frame + offset).view(1)[0] = bits;
}

impl iframe_ptr(frame: ptr[u8], offset: i64) -> ptr[u8] {
    return ptr[ptr[u8]](frame + offset).view(1)[0];
}

impl set_iframe_ptr(frame: ptr[u8], offset: i64, value: ptr[u8]) {
    ptr[ptr[u8]](frame + offset).view(1)[0] = value;
}

impl iframe_object(frame: ptr[u8], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](frame + offset).view(1)[0];
}

impl set_iframe_object(frame: ptr[u8], offset: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](frame + offset).view(1)[0] = value;
}

impl code_i32(code: ptr[PyObject], offset: i64) -> i32 {
    return ptr[i32](ptr[u8](code) + offset).view(1)[0];
}

impl iframe_code(frame: ptr[u8]) -> ptr[PyObject] {
    return stackref_borrow(iframe_ref(frame, _PyInterpreterFrame_F_EXECUTABLE));
}

impl iframe_bytecode(frame: ptr[u8]) -> ptr[u8] {
    return ptr[u8](iframe_code(frame)) + PyCodeObject_CODE_ADAPTIVE;
}

impl iframe_lasti(frame: ptr[u8]) -> i32 {
    instr = int(iframe_ptr(frame, _PyInterpreterFrame_INSTR_PTR));
    return i32.wrap((instr - int(iframe_bytecode(frame))) // 2);
}

impl iframe_is_incomplete(frame: ptr[u8]) -> bool {
    owner = i32((frame + _PyInterpreterFrame_OWNER).view(1)[0]);
    if owner >= FRAME_OWNED_BY_INTERPRETER {
        return True;
    }
    if owner == FRAME_OWNED_BY_GENERATOR {
        return False;
    }
    first = i64(code_i32(iframe_code(frame), PyCodeObject_FIRSTTRACEABLE));
    instr = int(iframe_ptr(frame, _PyInterpreterFrame_INSTR_PTR));
    return instr < int(iframe_bytecode(frame)) + first * 2;
}

impl iframe_first_complete(frame_in: ptr[u8]) -> ptr[u8] {
    frame = frame_in;
    while frame and iframe_is_incomplete(frame) {
        frame = iframe_ptr(frame, _PyInterpreterFrame_PREVIOUS);
    }
    return frame;
}

impl iframe_copy(src: ptr[u8], dest: ptr[u8]) {
    set_iframe_ref(
        dest,
        _PyInterpreterFrame_F_EXECUTABLE,
        stackref_make_heap_safe(iframe_ref(src, _PyInterpreterFrame_F_EXECUTABLE))
    );
    set_iframe_ptr(dest, _PyInterpreterFrame_PREVIOUS, ptr[u8]());
    set_iframe_ref(
        dest,
        _PyInterpreterFrame_F_FUNCOBJ,
        stackref_make_heap_safe(iframe_ref(src, _PyInterpreterFrame_F_FUNCOBJ))
    );
    set_iframe_ptr(
        dest,
        _PyInterpreterFrame_F_GLOBALS,
        iframe_ptr(src, _PyInterpreterFrame_F_GLOBALS)
    );
    set_iframe_ptr(
        dest,
        _PyInterpreterFrame_F_BUILTINS,
        iframe_ptr(src, _PyInterpreterFrame_F_BUILTINS)
    );
    set_iframe_ptr(
        dest,
        _PyInterpreterFrame_F_LOCALS,
        iframe_ptr(src, _PyInterpreterFrame_F_LOCALS)
    );
    set_iframe_ptr(
        dest,
        _PyInterpreterFrame_FRAME_OBJ,
        iframe_ptr(src, _PyInterpreterFrame_FRAME_OBJ)
    );
    set_iframe_ptr(
        dest,
        _PyInterpreterFrame_INSTR_PTR,
        iframe_ptr(src, _PyInterpreterFrame_INSTR_PTR)
    );
    src_locals = ptr[u64](src + _PyInterpreterFrame_LOCALSPLUS);
    dest_locals = ptr[u64](dest + _PyInterpreterFrame_LOCALSPLUS);
    stacktop = i64(
        (int(iframe_ptr(src, _PyInterpreterFrame_STACKPOINTER)) - int(src_locals)) // 8
    );
    set_iframe_ptr(
        dest, _PyInterpreterFrame_STACKPOINTER, ptr[u8](dest_locals + stacktop)
    );
    (dest + _PyInterpreterFrame_VISITED).view(1)[0] = u8(0);
    i: i64 = 0;
    while i < stacktop {
        (dest_locals + i).view(1)[0] = stackref_make_heap_safe(
            (src_locals + i).view(1)[0]
        );
        i += 1;
    }
}

impl tstate_current_frame(tstate: ptr) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0];
}

impl py_id(offset: i64) -> ptr[PyObject] {
    return ptr[PyObject](
        ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_GLOBAL_STRINGS + offset
    );
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl dict_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyDict_Type));
}

impl freelist_pop_mem(offset: i64) -> ptr[u8] {
    fl = freelist(offset);
    block = ptr[u8](fl.view(1)[0].freelist);
    if block {
        fl.view(1)[0].freelist = ptr[ptr](block).view(1)[0];
        fl.view(1)[0].size -= 1;
    }
    return block;
}

impl chunk_prev(buf: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](buf + _PyObjectStackChunk_PREV).view(1)[0];
}

impl set_chunk_prev(buf: ptr[u8], prev: ptr[u8]) {
    ptr[ptr[u8]](buf + _PyObjectStackChunk_PREV).view(1)[0] = prev;
}

impl set_chunk_n(buf: ptr[u8], n: i64) {
    ptr[i64](buf + _PyObjectStackChunk_N).view(1)[0] = n;
}

impl stack_head(stack: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](stack + _PyObjectStack_HEAD).view(1)[0];
}

impl set_stack_head(stack: ptr[u8], head: ptr[u8]) {
    ptr[ptr[u8]](stack + _PyObjectStack_HEAD).view(1)[0] = head;
}

impl take_ownership(f: ptr[PyObject], frame: ptr[u8]) {
    new_frame = ptr[u8](f) + PyFrameObject_FRAME_DATA;
    iframe_copy(frame, new_frame);

    set_iframe_ref(
        new_frame,
        _PyInterpreterFrame_F_EXECUTABLE,
        stackref_dup(iframe_ref(new_frame, _PyInterpreterFrame_F_EXECUTABLE))
    );
    ptr[ptr[u8]](ptr[u8](f) + PyFrameObject_FRAME).view(1)[0] = new_frame;
    (new_frame + _PyInterpreterFrame_OWNER).view(1)[0] = u8(
        FRAME_OWNED_BY_FRAME_OBJECT
    );
    if iframe_is_incomplete(new_frame) {
        code = iframe_code(new_frame);
        set_iframe_ptr(
            new_frame,
            _PyInterpreterFrame_INSTR_PTR,
            iframe_bytecode(new_frame)
                + 2 * (i64(code_i32(code, PyCodeObject_FIRSTTRACEABLE)) + 1)
        );
    }
    prev = iframe_first_complete(iframe_ptr(frame, _PyInterpreterFrame_PREVIOUS));
    if prev {
        exc = PyErr_GetRaisedException();

        back = iframe_object(prev, _PyInterpreterFrame_FRAME_OBJ);
        if not back {
            back = _PyFrame_MakeAndSetFrameObject(prev);
        }
        if not back {
            PyErr_Clear();
        } else {
            ptr[ptr[PyObject]](ptr[u8](f) + PyFrameObject_BACK).view(1)[0] = object_new_ref(
                back
            );
        }
        PyErr_SetRaisedException(exc);
    }
    if not object_gc_is_tracked(f) {
        object_gc_track(f);
    }
}

impl no_intrinsic1(tstate: ptr, unused: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_SetString(PyExc_SystemError, "invalid intrinsic function");
    return NULL;
}

impl print_expr(ignored: ptr, value: ptr[PyObject]) -> ptr[PyObject] {
    hook = _PySys_GetRequiredAttr(py_id(_Py_ID_displayhook));
    if not hook {
        return NULL;
    }
    res = PyObject_CallOneArg(hook, value);
    object_decref(hook);
    return res;
}

impl import_all_from(tstate: ptr, locals: ptr[PyObject], v: ptr[PyObject]) -> i32 {
    skip_leading_underscores = False;
    all_names = NULL;
    if PyObject_GetOptionalAttr(v, py_id(_Py_ID___all__), &mut all_names) < 0 {
        return -1;
    }
    if not all_names {
        dct = NULL;
        if PyObject_GetOptionalAttr(v, py_id(_Py_ID___dict__), &mut dct) < 0 {
            return -1;
        }
        if not dct {
            PyErr_SetString(
                PyExc_ImportError, "from-import-* object has no __dict__ and no __all__"
            );
            return -1;
        }
        all_names = PyMapping_Keys(dct);
        object_decref(dct);
        if not all_names {
            return -1;
        }
        skip_leading_underscores = True;
    }
    err: i32 = 0;
    pos: i64 = 0;
    while True {
        name = PySequence_GetItem(all_names, pos);
        if not name {
            if PyErr_ExceptionMatches(PyExc_IndexError) == 0 {
                err = -1;
            } else {
                PyErr_Clear();
            }
            break;
        }
        if not unicode_check(name) {
            modname = PyObject_GetAttr(v, py_id(_Py_ID___name__));
            if not modname {
                object_decref(name);
                err = -1;
                break;
            }
            if not unicode_check(modname) {
                PyErr_Format(
                    PyExc_TypeError,
                    "module __name__ must be a string, not %.100s",
                    object_type(modname).view(1)[0].tp_name
                );
            } elif skip_leading_underscores {
                PyErr_Format(
                    PyExc_TypeError,
                    "%s in %U.%s must be str, not %.100s",
                    ptr[u8]("Key"),
                    modname,
                    ptr[u8]("__dict__"),
                    object_type(name).view(1)[0].tp_name
                );
            } else {
                PyErr_Format(
                    PyExc_TypeError,
                    "%s in %U.%s must be str, not %.100s",
                    ptr[u8]("Item"),
                    modname,
                    ptr[u8]("__all__"),
                    object_type(name).view(1)[0].tp_name
                );
            }
            object_decref(modname);
            object_decref(name);
            err = -1;
            break;
        }
        if skip_leading_underscores {
            if PyUnicode_GetLength(name) > 0
                and PyUnicode_ReadChar(name, 0) == u32(95) {
                object_decref(name);
                pos += 1;
                continue;
            }
        }
        value = PyObject_GetAttr(v, name);
        if not value {
            err = -1;
        } elif dict_check_exact(locals) {
            err = PyDict_SetItem(locals, name, value);
        } else {
            err = PyObject_SetItem(locals, name, value);
        }
        object_decref(name);
        object_xdecref(value);
        if err < 0 {
            break;
        }
        pos += 1;
    }
    object_decref(all_names);
    return err;
}

impl import_star(tstate: ptr, from_: ptr[PyObject]) -> ptr[PyObject] {
    frame = tstate_current_frame(tstate);
    locals = _PyFrame_GetLocals(frame);
    if not locals {
        PyErr_SetString(PyExc_SystemError, "no locals found during 'import *'");
        return NULL;
    }
    err = import_all_from(tstate, locals, from_);
    object_decref(locals);
    if err < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl stopiteration_error(tstate: ptr, exc: ptr[PyObject]) -> ptr[PyObject] {
    frame = tstate_current_frame(tstate);
    flags = code_i32(iframe_code(frame), PyCodeObject_FLAGS);
    msg = ptr[u8]();
    if PyErr_GivenExceptionMatches(exc, PyExc_StopIteration) != 0 {
        msg = ptr[u8]("generator raised StopIteration");
        if (flags & CO_ASYNC_GENERATOR) != 0 {
            msg = ptr[u8]("async generator raised StopIteration");
        } elif (flags & CO_COROUTINE) != 0 {
            msg = ptr[u8]("coroutine raised StopIteration");
        }
    } elif (flags & CO_ASYNC_GENERATOR) != 0
        and PyErr_GivenExceptionMatches(exc, PyExc_StopAsyncIteration) != 0 {
        msg = ptr[u8]("async generator raised StopAsyncIteration");
    }
    if msg {
        message = _PyUnicode_FromASCII(msg, i64(strlen(msg)));
        if not message {
            return NULL;
        }
        error = PyObject_CallOneArg(PyExc_RuntimeError, message);
        if not error {
            object_decref(message);
            return NULL;
        }
        PyException_SetCause(error, object_new_ref(exc));
        PyException_SetContext(error, object_new_ref(exc));
        object_decref(message);
        return error;
    }
    return object_new_ref(exc);
}

impl unary_pos(unused: ptr, value: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Positive(value);
}

impl list_to_tuple(unused: ptr, v: ptr[PyObject]) -> ptr[PyObject] {
    return _PyTuple_FromArray(ptr[PyListObject](v).view(1)[0].ob_item, object_size(v));
}

impl make_typevar(ignored: ptr, v: ptr[PyObject]) -> ptr[PyObject] {
    return _Py_make_typevar(v, NULL, NULL);
}

impl no_intrinsic2(
    tstate: ptr, unused1: ptr[PyObject], unused2: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetString(PyExc_SystemError, "invalid intrinsic function");
    return NULL;
}

impl prep_reraise_star(
    unused: ptr, orig: ptr[PyObject], excs: ptr[PyObject]
) -> ptr[PyObject] {
    return _PyExc_PrepReraiseStar(orig, excs);
}

impl make_typevar_with_bound(
    ignored: ptr, name: ptr[PyObject], evaluate_bound: ptr[PyObject]
) -> ptr[PyObject] {
    return _Py_make_typevar(name, evaluate_bound, NULL);
}

impl make_typevar_with_constraints(
    ignored: ptr, name: ptr[PyObject], evaluate_constraints: ptr[PyObject]
) -> ptr[PyObject] {
    return _Py_make_typevar(name, NULL, evaluate_constraints);
}
