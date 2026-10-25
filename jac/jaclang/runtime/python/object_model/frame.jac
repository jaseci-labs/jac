import from c {
    glob PyType_Type: PyTypeObject,
         PyCell_Type: PyTypeObject,
         PyBool_Type: PyTypeObject,
         PyLong_Type: PyTypeObject,
         PyFunction_Type: PyTypeObject,
         _Py_TrueStruct: PyObject,
         _Py_FalseStruct: PyObject,
         PyExc_NameError: ptr[PyObject],
         _PyOpcode_Caches: u8; def _PyErr_SetKeyError(key: ptr[PyObject]);  def _PyUnicode_Equal(
        str1: ptr[PyObject], str2: ptr[PyObject]
    ) -> i32;  def _PyDict_LoadBuiltinsFromGlobals(
        globals: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyFunction_FromConstructor(
        constr: ptr[u8]
    ) -> ptr[PyObject];  def _PyEval_SetOpcodeTrace(
        frame: ptr[PyObject], enable: bool
    ) -> i32;  def _PyFrame_Traverse(frame: ptr[u8], visitor: ptr, arg: ptr) -> i32;  def _PyFrame_MakeAndSetFrameObject(
        frame: ptr[u8]
    ) -> ptr[PyObject];  def PyUnstable_InterpreterFrame_GetLine(
        frame: ptr[u8]
    ) -> i32;  def PyUnstable_InterpreterFrame_GetLasti(frame: ptr[u8]) -> i32;  def PyCompile_OpcodeStackEffect(
        opcode: i32, oparg: i32
    ) -> i32;  def _PyGen_Finalize(self: ptr[PyObject]);  def _PyCode_GetCode(
        co: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_GetBaseCodeUnit(
        co: ptr[PyObject], offset: i32
    ) -> u16;  def _PyCode_InitAddressRange(
        co: ptr[PyObject], bounds: ptr[u8]
    ) -> i32;  def _PyLineTable_NextAddressRange(bounds: ptr[u8]) -> i32;  glob:priv framelocalsproxy_as_number:
             PyNumberMethods = PyNumberMethods(
             nb_or=framelocalsproxy_or, nb_inplace_or=framelocalsproxy_inplace_or
         ),
         framelocalsproxy_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_contains=framelocalsproxy_contains
         ),
         framelocalsproxy_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=framelocalsproxy_length,
             mp_subscript=framelocalsproxy_getitem,
             mp_ass_subscript=framelocalsproxy_setitem
         ),
         framelocalsproxy_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__contains__"),
                 ml_meth=ptr(framelocalsproxy___contains__),
                 ml_flags=METH_O | METH_COEXIST,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__getitem__"),
                 ml_meth=ptr(framelocalsproxy_getitem),
                 ml_flags=METH_O | METH_COEXIST,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("update"),
                 ml_meth=ptr(framelocalsproxy_update),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(framelocalsproxy_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy"),
                 ml_meth=ptr(framelocalsproxy_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("keys"),
                 ml_meth=ptr(framelocalsproxy_keys),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("values"),
                 ml_meth=ptr(framelocalsproxy_values),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("items"),
                 ml_meth=ptr(framelocalsproxy_items),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get"),
                 ml_meth=ptr(framelocalsproxy_get),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("pop"),
                 ml_meth=ptr(framelocalsproxy_pop),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("setdefault"),
                 ml_meth=ptr(framelocalsproxy_setdefault),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         frame_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("f_trace_lines"),
                 type_=Py_T_BOOL,
                 offset=PyFrameObject_TRACE_LINES,
                 flags=0
             ),
             PyMemberDef()
         ],
         frame_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("f_back"), get=frame_back_get),
             PyGetSetDef(
                 name=ptr[u8]("f_locals"),
                 get=frame_locals_get,
                 doc=ptr[u8](
                     "Return the mapping used by the frame to look up local variables."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("f_lineno"),
                 get=frame_lineno_get,
                 set=frame_lineno_set,
                 doc=ptr[u8]("Return the current line number in the frame.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("f_trace"),
                 get=frame_trace_get,
                 set=frame_trace_set,
                 doc=ptr[u8](
                     "Return the trace function for this frame, or None if no trace function is set."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("f_lasti"),
                 get=frame_lasti_get,
                 doc=ptr[u8](
                     "Return the index of the last attempted instruction in the frame."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("f_globals"),
                 get=frame_globals_get,
                 doc=ptr[u8]("Return the global variables in the frame.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("f_builtins"),
                 get=frame_builtins_get,
                 doc=ptr[u8]("Return the built-in variables in the frame.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("f_code"),
                 get=frame_code_get,
                 doc=ptr[u8]("Return the code object being executed in this frame.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("f_trace_opcodes"),
                 get=frame_trace_opcodes_get,
                 set=frame_trace_opcodes_set,
                 doc=ptr[u8](
                     "Return True if opcode tracing is enabled, False otherwise."
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("f_generator"),
                 get=frame_generator_get,
                 doc=ptr[u8](
                     "Return the generator or coroutine associated with this frame, or None."
                 )
             ),
             PyGetSetDef()
         ],
         frame_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("clear"),
                 ml_meth=ptr(frame_clear),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "clear($self, /)\n--\n\nClear all references held by the frame."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(frame___sizeof__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__sizeof__($self, /)\n--\n\nReturn the size of the frame in memory, in bytes."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyFrameLocalsProxy_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("FrameLocalsProxy"),
             tp_basicsize=PyFrameLocalsProxyObject_SIZE,
             tp_dealloc=framelocalsproxy_dealloc,
             tp_repr=framelocalsproxy_repr,
             tp_as_number=addressof(framelocalsproxy_as_number),
             tp_as_sequence=addressof(framelocalsproxy_as_sequence),
             tp_as_mapping=addressof(framelocalsproxy_as_mapping),
             tp_getattro=PyObject_GenericGetAttr,
             tp_setattro=PyObject_GenericSetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_MAPPING,
             tp_traverse=framelocalsproxy_visit,
             tp_clear=framelocalsproxy_tp_clear,
             tp_richcompare=framelocalsproxy_richcompare,
             tp_iter=framelocalsproxy_iter,
             tp_methods=addressof(framelocalsproxy_methods),
             tp_alloc=PyType_GenericAlloc,
             tp_new=framelocalsproxy_new,
             tp_free=PyObject_GC_Del
         ),
         PyFrame_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("frame"),
             tp_basicsize=PyFrameObject_SIZE,
             tp_itemsize=8,
             tp_dealloc=frame_dealloc,
             tp_repr=frame_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_setattro=PyObject_GenericSetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=frame_traverse,
             tp_clear=frame_tp_clear,
             tp_methods=addressof(frame_methods),
             tp_members=addressof(frame_memberlist),
             tp_getset=addressof(frame_getsetlist)
         );
}

glob:priv STACKREF_NULL: u64 = u64(1),
     STACKREF_REFCNT_TAG: u64 = u64(1),
     STACKREF_PTR_MASK: u64 = u64(0xFFFFFFFFFFFFFFFE),
     KIND_ITERATOR: i64 = 1,
     KIND_EXCEPT: i64 = 2,
     KIND_OBJECT: i64 = 3,
     KIND_NULL: i64 = 4,
     KIND_LASTI: i64 = 5,
     BITS_PER_BLOCK: i64 = 3,
     STACK_MASK: i64 = 7,
     UNINITIALIZED: i64 = -2,
     OVERFLOWED: i64 = -1,
     EMPTY_STACK: i64 = 0,
     WILL_OVERFLOW: u64 = u64(0x1000000000000000),
     INT_MAX: i64 = 2147483647,
     INT_MIN: i64 = -2147483648,
     EVENT_PY_START: i32 = 0,
     EVENT_PY_RESUME: i32 = 1,
     EVENT_PY_RETURN: i32 = 2,
     EVENT_PY_YIELD: i32 = 3,
     EVENT_CALL: i32 = 4,
     EVENT_LINE: i32 = 5,
     EVENT_INSTRUCTION: i32 = 6,
     EVENT_JUMP: i32 = 7,
     EVENT_BRANCH_LEFT: i32 = 8,
     EVENT_BRANCH_RIGHT: i32 = 9,
     EVENT_RAISE: i32 = 11,
     EVENT_EXCEPTION_HANDLED: i32 = 12,
     EVENT_PY_UNWIND: i32 = 13,
     EVENT_PY_THROW: i32 = 14,
     EVENT_C_RETURN: i32 = 16,
     EVENT_C_RAISE: i32 = 17,
     EVENT_BRANCH: i32 = 18;

def field(op: ptr[PyObject], offset: i64) -> ptr[PyObject];

def set_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def clear_field(op: ptr[PyObject], offset: i64);

def replace_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def code_i32(code: ptr[PyObject], offset: i64) -> i32;

def code_nlocalsplus(code: ptr[PyObject]) -> i64;

def code_bytecode(code: ptr[PyObject]) -> ptr[u8];

def local_kind(code: ptr[PyObject], i: i64) -> int;

def local_name(code: ptr[PyObject], i: i64) -> ptr[PyObject];

def dict_check(op: ptr[PyObject]) -> bool;

def unicode_check(op: ptr[PyObject]) -> bool;

def cell_check(op: ptr[PyObject]) -> bool;

def frame_check(op: ptr[PyObject]) -> bool;

def proxy_check(op: ptr[PyObject]) -> bool;

def function_check(op: ptr[PyObject]) -> bool;

def object_is_immortal(op: ptr[PyObject]) -> bool;

def cell_get_ref(cell: ptr[PyObject]) -> ptr[PyObject];

def cell_set_take_ref(cell: ptr[PyObject], value: ptr[PyObject]);

def stackref_borrow(bits: u64) -> ptr[PyObject];

def stackref_new(op: ptr[PyObject]) -> u64;

def stackref_none -> u64;

def stackref_close(bits: u64);

def stackref_clear(slot: ptr[u64]);

def frame_iframe(f: ptr[PyObject]) -> ptr[u8];

def set_frame_iframe(f: ptr[PyObject], iframe: ptr[u8]);

def frame_data(f: ptr[PyObject]) -> ptr[u8];

def frame_lineno(f: ptr[PyObject]) -> i32;

def set_frame_lineno(f: ptr[PyObject], lineno: i32);

def frame_trace_opcodes(f: ptr[PyObject]) -> u8;

def set_frame_char(f: ptr[PyObject], offset: i64, value: u8);

def iframe_object(frame: ptr[u8], offset: i64) -> ptr[PyObject];

def set_iframe_object(frame: ptr[u8], offset: i64, value: ptr[PyObject]);

def iframe_previous(frame: ptr[u8]) -> ptr[u8];

def iframe_owner(frame: ptr[u8]) -> i32;

def set_iframe_owner(frame: ptr[u8], owner: i32);

def iframe_instr_ptr(frame: ptr[u8]) -> ptr[u8];

def set_iframe_instr_ptr(frame: ptr[u8], instr: ptr[u8]);

def iframe_localsplus(frame: ptr[u8]) -> ptr[u64];

def iframe_stackpointer(frame: ptr[u8]) -> ptr[u64];

def set_iframe_stackpointer(frame: ptr[u8], sp: ptr[u64]);

def iframe_code(frame: ptr[u8]) -> ptr[PyObject];

def iframe_bytecode(frame: ptr[u8]) -> ptr[u8];

def iframe_lasti(frame: ptr[u8]) -> i32;

def iframe_is_incomplete(frame: ptr[u8]) -> bool;

def iframe_first_complete(frame_in: ptr[u8]) -> ptr[u8];

def iframe_frame_object(frame: ptr[u8]) -> ptr[PyObject];

def iframe_stack_pop(frame: ptr[u8]) -> u64;

def iframe_generator(frame: ptr[u8]) -> ptr[PyObject];

def gen_frame_state(gen: ptr[PyObject]) -> i32;

def frame_state_suspended(state: i32) -> bool;

def frame_initialize(
    frame: ptr[u8],
    func: u64,
    locals: ptr[PyObject],
    code: ptr[PyObject],
    null_locals_from: i64,
    previous: ptr[u8]
);

def opcode_caches(opcode: int) -> int;

def proxy_frame(self: ptr[PyObject]) -> ptr[PyObject];

def framelocalsproxy_getval(
    frame: ptr[u8], co: ptr[PyObject], i: i64
) -> ptr[PyObject];

def framelocalsproxy_hasval(frame: ptr[u8], co: ptr[PyObject], i: i64) -> bool;

def framelocalsproxy_getkeyindex(
    frame: ptr[PyObject], key: ptr[PyObject], read_mode: bool, want_value: bool
) -> tuple[i32, ptr[PyObject]];

def framelocalsproxy_getitem(self: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];

def add_overwritten_fast_local(frame: ptr[PyObject], ob: ptr[PyObject]) -> i32;

def framelocalsproxy_setitem(
    self: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def framelocalsproxy_merge(self: ptr[PyObject], other: ptr[PyObject]) -> i32;

def framelocalsproxy_keys(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def framelocalsproxy_dealloc(self: ptr[PyObject]);

def framelocalsproxy_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def framelocalsproxy_tp_clear(self: ptr[PyObject]) -> i32;

def framelocalsproxy_visit(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def framelocalsproxy_iter(self: ptr[PyObject]) -> ptr[PyObject];

def framelocalsproxy_richcompare(
    lhs: ptr[PyObject], rhs: ptr[PyObject], op: i32
) -> ptr[PyObject];

def framelocalsproxy_repr(self: ptr[PyObject]) -> ptr[PyObject];

def framelocalsproxy_or(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def framelocalsproxy_inplace_or(
    self: ptr[PyObject], other: ptr[PyObject]
) -> ptr[PyObject];

def framelocalsproxy_values(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def framelocalsproxy_items(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def framelocalsproxy_length(self: ptr[PyObject]) -> i64;

def framelocalsproxy_contains(self: ptr[PyObject], key: ptr[PyObject]) -> i32;

def framelocalsproxy___contains__(
    self: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject];

def framelocalsproxy_update(
    self: ptr[PyObject], other: ptr[PyObject]
) -> ptr[PyObject];

def framelocalsproxy_get(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def framelocalsproxy_setdefault(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def framelocalsproxy_pop(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def framelocalsproxy_copy(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def framelocalsproxy_reversed(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def frame_locals_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def frame_lineno_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def frame_lasti_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def frame_globals_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def frame_builtins_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def frame_code_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def frame_back_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def frame_trace_opcodes_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def frame_trace_opcodes_set(
    self: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32;

def compatible_kind(from_kind: i64, to_kind: i64) -> bool;

def push_value(stack: i64, kind: i64) -> i64;

def pop_value(stack: i64) -> i64;

def top_of_stack(stack: i64) -> i64;

def peek(stack: i64, n: i64) -> i64;

def stack_swap(stack: i64, n: i64) -> i64;

def pop_to_level(stack_in: i64, level: i64) -> i64;

def parse_varint(p_in: ptr[u8]) -> tuple[ptr[u8], i64];

def stack_at(stacks: ptr[i64], i: i64) -> i64;

def stack_put(stacks: ptr[i64], i: i64, value: i64);

def is_block_end(opcode: int) -> bool;

def is_pop_jump(opcode: int) -> bool;

def mark_stacks(code_obj: ptr[PyObject], n_units: i64) -> ptr[i64];

def compatible_stack(from_in: i64, to_in: i64) -> bool;

def explain_incompatible_stack(to_stack: i64) -> ptr[u8];

def marklines(code: ptr[PyObject], n_units: i64) -> ptr[i32];

def first_line_not_before(lines: ptr[i32], n_units: i64, line: i32) -> i32;

def frame_is_suspended(frame: ptr[PyObject]) -> bool;

def frame_lineno_set(self: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32;

def frame_trace_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def frame_trace_set(self: ptr[PyObject], value_in: ptr[PyObject], closure: ptr) -> i32;

def frame_generator_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def clear_stack_down_to_locals(frame: ptr[u8]);

def frame_dealloc(op: ptr[PyObject]);

def frame_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def frame_tp_clear(op: ptr[PyObject]) -> i32;

def frame_clear(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def frame___sizeof__(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def frame_repr(op: ptr[PyObject]) -> ptr[PyObject];

def init_frame(
    tstate: ptr[u8], frame: ptr[u8], func: ptr[PyObject], locals: ptr[PyObject]
);

def frame_init_get_vars(frame: ptr[u8]);

def frame_get_var(
    frame: ptr[u8], co: ptr[PyObject], i: i64
) -> tuple[i32, ptr[PyObject]];

import from c {
    def _PyFrameLocalsProxy_New(frame: ptr[PyObject]) -> ptr[PyObject] {
        args = PyTuple_Pack(1, frame);
        if not args {
            return NULL;
        }
        proxy = framelocalsproxy_new(addressof(PyFrameLocalsProxy_Type), args, NULL);
        object_decref(args);
        return proxy;
    }  def PyFrame_GetLineNumber(f: ptr[PyObject]) -> i32 {
        if frame_lineno(f) == -1 {
            set_frame_lineno(f, PyUnstable_InterpreterFrame_GetLine(frame_iframe(f)));
            if frame_lineno(f) < 0 {
                set_frame_lineno(f, i32(0));
                return i32(-1);
            }
        }
        if frame_lineno(f) > 0 {
            return frame_lineno(f);
        }
        return PyUnstable_InterpreterFrame_GetLine(frame_iframe(f));
    }  def _PyFrame_New_NoTrack(code: ptr[PyObject]) -> ptr[PyObject] {
        slots = code_nlocalsplus(code) + i64(code_i32(code, PyCodeObject_STACKSIZE));
        f = _PyObject_GC_NewVar(ptr[PyObject](addressof(PyFrame_Type)), slots);
        if not f {
            return NULL;
        }
        set_field(f, PyFrameObject_BACK, NULL);
        set_field(f, PyFrameObject_TRACE, NULL);
        set_frame_char(f, PyFrameObject_TRACE_LINES, u8(1));
        set_frame_char(f, PyFrameObject_TRACE_OPCODES, u8(0));
        set_frame_lineno(f, i32(0));
        set_field(f, PyFrameObject_EXTRA_LOCALS, NULL);
        set_field(f, PyFrameObject_LOCALS_CACHE, NULL);
        set_field(f, PyFrameObject_OVERWRITTEN_FAST_LOCALS, NULL);
        return f;
    }  def PyFrame_New(
        tstate: ptr[u8],
        code: ptr[PyObject],
        globals: ptr[PyObject],
        locals: ptr[PyObject]
    ) -> ptr[PyObject] {
        builtins = _PyDict_LoadBuiltinsFromGlobals(globals);
        if not builtins {
            return NULL;
        }
        desc = ptr[PyObject](PyMem_Malloc(u64(PyFrameConstructor_SIZE)));
        if not desc {
            object_decref(builtins);
            PyErr_NoMemory();
            return NULL;
        }
        name = field(code, PyCodeObject_NAME);
        set_field(desc, PyFrameConstructor_GLOBALS, globals);
        set_field(desc, PyFrameConstructor_BUILTINS, builtins);
        set_field(desc, PyFrameConstructor_NAME, name);
        set_field(desc, PyFrameConstructor_QUALNAME, name);
        set_field(desc, PyFrameConstructor_CODE, code);
        set_field(desc, PyFrameConstructor_DEFAULTS, NULL);
        set_field(desc, PyFrameConstructor_KWDEFAULTS, NULL);
        set_field(desc, PyFrameConstructor_CLOSURE, NULL);
        func = _PyFunction_FromConstructor(ptr[u8](desc));
        PyMem_Free(ptr(desc));
        object_decref(builtins);
        if not func {
            return NULL;
        }
        f = _PyFrame_New_NoTrack(code);
        if not f {
            object_decref(func);
            return NULL;
        }
        data = frame_data(f);
        init_frame(tstate, data, func, locals);
        set_frame_iframe(f, data);
        set_iframe_owner(data, FRAME_OWNED_BY_FRAME_OBJECT);
        set_iframe_instr_ptr(
            data,
            code_bytecode(code)
                + 2 * (i64(code_i32(code, PyCodeObject_FIRSTTRACEABLE)) + 1)
        );
        object_decref(func);
        object_gc_track(f);
        return f;
    }  def _PyFrame_HasHiddenLocals(frame: ptr[u8]) -> bool {
        co = iframe_code(frame);
        n = code_nlocalsplus(co);
        i: i64 = 0;
        while i < n {
            if (local_kind(co, i) & CO_FAST_HIDDEN) != 0 {
                if framelocalsproxy_hasval(frame, co, i) {
                    return True;
                }
            }
            i += 1;
        }
        return False;
    }  def _PyFrame_GetLocals(frame: ptr[u8]) -> ptr[PyObject] {
        co = iframe_code(frame);
        if (code_i32(co, PyCodeObject_FLAGS) & CO_OPTIMIZED) == 0
            and not _PyFrame_HasHiddenLocals(frame) {
            if not iframe_object(frame, _PyInterpreterFrame_F_LOCALS) {
                set_iframe_object(frame, _PyInterpreterFrame_F_LOCALS, PyDict_New());
                if not iframe_object(frame, _PyInterpreterFrame_F_LOCALS) {
                    return NULL;
                }
            }
            return object_new_ref(iframe_object(frame, _PyInterpreterFrame_F_LOCALS));
        }
        f = iframe_frame_object(frame);
        if not f {
            return NULL;
        }
        return _PyFrameLocalsProxy_New(f);
    }  def PyFrame_GetVar(
        frame_obj: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not unicode_check(name) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("name must be str, not %s"),
                object_type(name).view(1)[0].tp_name
            );
            return NULL;
        }
        frame = frame_iframe(frame_obj);
        frame_init_get_vars(frame);
        co = iframe_code(frame);
        n = code_nlocalsplus(co);
        i: i64 = 0;
        while i < n {
            var_name = local_name(co, i);
            if _PyUnicode_Equal(var_name, name) != 0 {
                (ok, value) = frame_get_var(frame, co, i);
                if ok == 0 or not value {
                    break;
                }
                return value;
            }
            i += 1;
        }
        PyErr_Format(PyExc_NameError, ptr[u8]("variable %R does not exist"), name);
        return NULL;
    }  def PyFrame_GetVarString(frame: ptr[PyObject], name: ptr[u8]) -> ptr[PyObject] {
        name_obj = PyUnicode_FromString(name);
        if not name_obj {
            return NULL;
        }
        value = PyFrame_GetVar(frame, name_obj);
        object_decref(name_obj);
        return value;
    }  def PyFrame_FastToLocalsWithError(f: ptr[PyObject]) -> i32 {
        return i32(0);
    }  def PyFrame_FastToLocals(f: ptr[PyObject]) -> None {
        return;
    }  def PyFrame_LocalsToFast(f: ptr[PyObject], clear: i32) -> None {
        return;
    }  def _PyFrame_IsEntryFrame(frame: ptr[PyObject]) -> i32 {
        prev = iframe_previous(frame_iframe(frame));
        if prev and iframe_owner(prev) == FRAME_OWNED_BY_INTERPRETER {
            return i32(1);
        }
        return i32(0);
    }  def PyFrame_GetCode(frame: ptr[PyObject]) -> ptr[PyObject] {
        return object_new_ref(iframe_code(frame_iframe(frame)));
    }  def PyFrame_GetBack(frame: ptr[PyObject]) -> ptr[PyObject] {
        back = field(frame, PyFrameObject_BACK);
        if not back {
            prev = iframe_first_complete(iframe_previous(frame_iframe(frame)));
            if prev {
                back = iframe_frame_object(prev);
            }
        }
        return Py_XNewRef(back);
    }  def PyFrame_GetLocals(frame: ptr[PyObject]) -> ptr[PyObject] {
        return frame_locals_get(frame, ptr());
    }  def PyFrame_GetGlobals(frame: ptr[PyObject]) -> ptr[PyObject] {
        return frame_globals_get(frame, ptr());
    }  def PyFrame_GetBuiltins(frame: ptr[PyObject]) -> ptr[PyObject] {
        return frame_builtins_get(frame, ptr());
    }  def PyFrame_GetLasti(frame: ptr[PyObject]) -> i32 {
        lasti = iframe_lasti(frame_iframe(frame));
        if lasti < 0 {
            return i32(-1);
        }
        return lasti * i32(2);
    }  def PyFrame_GetGenerator(frame: ptr[PyObject]) -> ptr[PyObject] {
        return frame_generator_get(frame, ptr());
    }
}

impl field(op: ptr[PyObject], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](op) + offset).view(1)[0];
}

impl set_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](ptr[u8](op) + offset).view(1)[0] = value;
}

impl clear_field(op: ptr[PyObject], offset: i64) {
    old = field(op, offset);
    if old {
        set_field(op, offset, NULL);
        object_decref(old);
    }
}

impl replace_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]) {
    old = field(op, offset);
    set_field(op, offset, value);
    object_xdecref(old);
}

impl code_i32(code: ptr[PyObject], offset: i64) -> i32 {
    return ptr[i32](ptr[u8](code) + offset).view(1)[0];
}

impl code_nlocalsplus(code: ptr[PyObject]) -> i64 {
    return i64(code_i32(code, PyCodeObject_NLOCALSPLUS));
}

impl code_bytecode(code: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](code) + PyCodeObject_CODE_ADAPTIVE;
}

impl local_kind(code: ptr[PyObject], i: i64) -> int {
    kinds = field(code, PyCodeObject_LOCALSPLUSKINDS);
    return int((ptr[u8](kinds) + PyBytesObject_OB_SVAL + i).view(1)[0]);
}

impl local_name(code: ptr[PyObject], i: i64) -> ptr[PyObject] {
    return tuple_get_item(field(code, PyCodeObject_LOCALSPLUSNAMES), i);
}

impl dict_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl cell_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyCell_Type));
}

impl frame_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyFrame_Type));
}

impl proxy_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyFrameLocalsProxy_Type));
}

impl function_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyFunction_Type));
}

impl object_is_immortal(op: ptr[PyObject]) -> bool {
    return (ptr[_object](op).view(1)[0].ob_refcnt_full & 0x80000000) != 0;
}

impl cell_get_ref(cell: ptr[PyObject]) -> ptr[PyObject] {
    return Py_XNewRef(ptr[PyCellObject](cell).view(1)[0].ob_ref);
}

impl cell_set_take_ref(cell: ptr[PyObject], value: ptr[PyObject]) {
    old = ptr[PyCellObject](cell).view(1)[0].ob_ref;
    ptr[PyCellObject](cell).view(1)[0].ob_ref = value;
    object_xdecref(old);
}

impl stackref_borrow(bits: u64) -> ptr[PyObject] {
    return ptr[PyObject](i64.wrap(bits & STACKREF_PTR_MASK));
}

impl stackref_new(op: ptr[PyObject]) -> u64 {
    if object_is_immortal(op) {
        return u64.wrap(int(op)) | STACKREF_REFCNT_TAG;
    }
    header = ptr[_object](op);
    header.view(1)[0].ob_refcnt_full = header.view(1)[0].ob_refcnt_full + 1;
    return u64.wrap(int(op));
}

impl stackref_none -> u64 {
    return u64.wrap(int(Py_None)) | STACKREF_REFCNT_TAG;
}

impl stackref_close(bits: u64) {
    if (bits & STACKREF_REFCNT_TAG) == u64(0) {
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
    stackref_close(old);
}

impl frame_iframe(f: ptr[PyObject]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](f) + PyFrameObject_FRAME).view(1)[0];
}

impl set_frame_iframe(f: ptr[PyObject], iframe: ptr[u8]) {
    ptr[ptr[u8]](ptr[u8](f) + PyFrameObject_FRAME).view(1)[0] = iframe;
}

impl frame_data(f: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](f) + PyFrameObject_FRAME_DATA;
}

impl frame_lineno(f: ptr[PyObject]) -> i32 {
    return ptr[i32](ptr[u8](f) + PyFrameObject_LINENO).view(1)[0];
}

impl set_frame_lineno(f: ptr[PyObject], lineno: i32) {
    ptr[i32](ptr[u8](f) + PyFrameObject_LINENO).view(1)[0] = lineno;
}

impl frame_trace_opcodes(f: ptr[PyObject]) -> u8 {
    return (ptr[u8](f) + PyFrameObject_TRACE_OPCODES).view(1)[0];
}

impl set_frame_char(f: ptr[PyObject], offset: i64, value: u8) {
    (ptr[u8](f) + offset).view(1)[0] = value;
}

impl iframe_object(frame: ptr[u8], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](frame + offset).view(1)[0];
}

impl set_iframe_object(frame: ptr[u8], offset: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](frame + offset).view(1)[0] = value;
}

impl iframe_previous(frame: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](frame + _PyInterpreterFrame_PREVIOUS).view(1)[0];
}

impl iframe_owner(frame: ptr[u8]) -> i32 {
    return i32((frame + _PyInterpreterFrame_OWNER).view(1)[0]);
}

impl set_iframe_owner(frame: ptr[u8], owner: i32) {
    (frame + _PyInterpreterFrame_OWNER).view(1)[0] = u8(owner);
}

impl iframe_instr_ptr(frame: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](frame + _PyInterpreterFrame_INSTR_PTR).view(1)[0];
}

impl set_iframe_instr_ptr(frame: ptr[u8], instr: ptr[u8]) {
    ptr[ptr[u8]](frame + _PyInterpreterFrame_INSTR_PTR).view(1)[0] = instr;
}

impl iframe_localsplus(frame: ptr[u8]) -> ptr[u64] {
    return ptr[u64](frame + _PyInterpreterFrame_LOCALSPLUS);
}

impl iframe_stackpointer(frame: ptr[u8]) -> ptr[u64] {
    return ptr[ptr[u64]](frame + _PyInterpreterFrame_STACKPOINTER).view(1)[0];
}

impl set_iframe_stackpointer(frame: ptr[u8], sp: ptr[u64]) {
    ptr[ptr[u64]](frame + _PyInterpreterFrame_STACKPOINTER).view(1)[0] = sp;
}

impl iframe_code(frame: ptr[u8]) -> ptr[PyObject] {
    return stackref_borrow(
        ptr[u64](frame + _PyInterpreterFrame_F_EXECUTABLE).view(1)[0]
    );
}

impl iframe_bytecode(frame: ptr[u8]) -> ptr[u8] {
    return code_bytecode(iframe_code(frame));
}

impl iframe_lasti(frame: ptr[u8]) -> i32 {
    return i32((int(iframe_instr_ptr(frame)) - int(iframe_bytecode(frame))) // 2);
}

impl iframe_is_incomplete(frame: ptr[u8]) -> bool {
    owner = iframe_owner(frame);
    if owner >= FRAME_OWNED_BY_INTERPRETER {
        return True;
    }
    if owner == FRAME_OWNED_BY_GENERATOR {
        return False;
    }
    code = iframe_code(frame);
    first = int(code_bytecode(code))
        + 2 * int(code_i32(code, PyCodeObject_FIRSTTRACEABLE));
    return int(iframe_instr_ptr(frame)) < first;
}

impl iframe_first_complete(frame_in: ptr[u8]) -> ptr[u8] {
    frame = frame_in;
    while frame and iframe_is_incomplete(frame) {
        frame = iframe_previous(frame);
    }
    return frame;
}

impl iframe_frame_object(frame: ptr[u8]) -> ptr[PyObject] {
    res = iframe_object(frame, _PyInterpreterFrame_FRAME_OBJ);
    if res {
        return res;
    }
    return _PyFrame_MakeAndSetFrameObject(frame);
}

impl iframe_stack_pop(frame: ptr[u8]) -> u64 {
    sp = iframe_stackpointer(frame) - 1;
    set_iframe_stackpointer(frame, sp);
    return sp.view(1)[0];
}

impl iframe_generator(frame: ptr[u8]) -> ptr[PyObject] {
    return ptr[PyObject](int(frame) - PyGenObject_IFRAME);
}

impl gen_frame_state(gen: ptr[PyObject]) -> i32 {
    state = i32((ptr[u8](gen) + PyGenObject_FRAME_STATE).view(1)[0]);
    if state >= 128 {
        state -= 256;
    }
    return state;
}

impl frame_state_suspended(state: i32) -> bool {
    return state == FRAME_SUSPENDED or state == FRAME_SUSPENDED_YIELD_FROM;
}

impl frame_initialize(
    frame: ptr[u8],
    func: u64,
    locals: ptr[PyObject],
    code: ptr[PyObject],
    null_locals_from: i64,
    previous: ptr[u8]
) {
    ptr[ptr[u8]](frame + _PyInterpreterFrame_PREVIOUS).view(1)[0] = previous;
    ptr[u64](frame + _PyInterpreterFrame_F_FUNCOBJ).view(1)[0] = func;
    ptr[u64](frame + _PyInterpreterFrame_F_EXECUTABLE).view(1)[0] = stackref_new(code);
    func_obj = stackref_borrow(func);
    set_iframe_object(
        frame,
        _PyInterpreterFrame_F_BUILTINS,
        field(func_obj, PyFunctionObject_BUILTINS)
    );
    set_iframe_object(
        frame, _PyInterpreterFrame_F_GLOBALS, field(func_obj, PyFunctionObject_GLOBALS)
    );
    set_iframe_object(frame, _PyInterpreterFrame_F_LOCALS, locals);
    nlocalsplus = code_nlocalsplus(code);
    set_iframe_stackpointer(frame, iframe_localsplus(frame) + nlocalsplus);
    set_iframe_object(frame, _PyInterpreterFrame_FRAME_OBJ, NULL);
    set_iframe_instr_ptr(frame, code_bytecode(code));
    ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16(0);
    set_iframe_owner(frame, FRAME_OWNED_BY_THREAD);
    (frame + _PyInterpreterFrame_VISITED).view(1)[0] = u8(0);
    i = null_locals_from;
    while i < nlocalsplus {
        (iframe_localsplus(frame) + i).view(1)[0] = STACKREF_NULL;
        i += 1;
    }
}

impl opcode_caches(opcode: int) -> int {
    return int((addressof(_PyOpcode_Caches) + i64(opcode)).view(1)[0]);
}

impl proxy_frame(self: ptr[PyObject]) -> ptr[PyObject] {
    return field(self, PyFrameLocalsProxyObject_FRAME);
}

impl framelocalsproxy_getval(
    frame: ptr[u8], co: ptr[PyObject], i: i64
) -> ptr[PyObject] {
    fast = iframe_localsplus(frame);
    kind = local_kind(co, i);
    value = stackref_borrow((fast + i).view(1)[0]);
    cell: ptr[PyObject] = NULL;
    if not value {
        return NULL;
    }
    if kind == CO_FAST_FREE or (kind & CO_FAST_CELL) != 0 {
        if cell_check(value) {
            cell = value;
        }
    }
    if cell {
        value = cell_get_ref(cell);
    } else {
        object_incref(value);
    }
    if not value {
        return NULL;
    }
    return value;
}

impl framelocalsproxy_hasval(frame: ptr[u8], co: ptr[PyObject], i: i64) -> bool {
    value = framelocalsproxy_getval(frame, co, i);
    if not value {
        return False;
    }
    object_decref(value);
    return True;
}

impl framelocalsproxy_getkeyindex(
    frame: ptr[PyObject], key: ptr[PyObject], read_mode: bool, want_value: bool
) -> tuple[i32, ptr[PyObject]] {
    iframe = frame_iframe(frame);
    co = iframe_code(iframe);
    key_hash = PyObject_Hash(key);
    if key_hash == -1 {
        return (i32(-2), NULL);
    }
    found = False;
    n = code_nlocalsplus(co);
    i: i64 = 0;
    while i < n {
        name = local_name(co, i);
        if name == key {
            if read_mode {
                value = framelocalsproxy_getval(iframe, co, i);
                if value {
                    if want_value {
                        return (i32(i), value);
                    }
                    object_decref(value);
                    return (i32(i), NULL);
                }
            } elif (local_kind(co, i) & CO_FAST_HIDDEN) == 0 {
                return (i32(i), NULL);
            }
            found = True;
        }
        i += 1;
    }
    if found {
        return (i32(-1), NULL);
    }
    i = 0;
    while i < n {
        name = local_name(co, i);
        name_hash = PyObject_Hash(name);
        if name_hash == key_hash {
            same = PyObject_RichCompareBool(name, key, Py_EQ);
            if same < 0 {
                return (i32(-2), NULL);
            }
            if same != 0 {
                if read_mode {
                    value = framelocalsproxy_getval(iframe, co, i);
                    if value {
                        if want_value {
                            return (i32(i), value);
                        }
                        object_decref(value);
                        return (i32(i), NULL);
                    }
                } elif (local_kind(co, i) & CO_FAST_HIDDEN) == 0 {
                    return (i32(i), NULL);
                }
            }
        }
        i += 1;
    }
    return (i32(-1), NULL);
}

impl framelocalsproxy_getitem(
    self: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    frame = proxy_frame(self);
    (i, value) = framelocalsproxy_getkeyindex(frame, key, True, True);
    if i == -2 {
        return NULL;
    }
    if i >= 0 {
        return value;
    }
    extra = field(frame, PyFrameObject_EXTRA_LOCALS);
    if extra {
        extra_value: ptr[PyObject] = NULL;
        if PyDict_GetItemRef(extra, key, &mut extra_value) < 0 {
            return NULL;
        }
        if extra_value {
            return extra_value;
        }
    }
    PyErr_Format(PyExc_KeyError, ptr[u8]("local variable '%R' is not defined"), key);
    return NULL;
}

impl add_overwritten_fast_local(frame: ptr[PyObject], ob: ptr[PyObject]) -> i32 {
    overwritten = field(frame, PyFrameObject_OVERWRITTEN_FAST_LOCALS);
    new_size: i64 = 1;
    if overwritten {
        size = PyTuple_Size(overwritten);
        if size == -1 {
            return i32(-1);
        }
        new_size = size + 1;
    }
    new_tuple = PyTuple_New(new_size);
    if not new_tuple {
        return i32(-1);
    }
    i: i64 = 0;
    while i < new_size - 1 {
        o = tuple_get_item(overwritten, i);
        tuple_set_item(new_tuple, i, object_new_ref(o));
        i += 1;
    }
    tuple_set_item(new_tuple, new_size - 1, object_new_ref(ob));
    replace_field(frame, PyFrameObject_OVERWRITTEN_FAST_LOCALS, new_tuple);
    return i32(0);
}

impl framelocalsproxy_setitem(
    self: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    frame = proxy_frame(self);
    fast = iframe_localsplus(frame_iframe(frame));
    co = iframe_code(frame_iframe(frame));
    (i, unused) = framelocalsproxy_getkeyindex(frame, key, False, False);
    if i == -2 {
        return i32(-1);
    }
    if i >= 0 {
        if not value {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("cannot remove local variables from FrameLocalsProxy")
            );
            return i32(-1);
        }
        index = i64(i);
        kind = local_kind(co, index);
        oldvalue = (fast + index).view(1)[0];
        cell: ptr[PyObject] = NULL;
        if kind == CO_FAST_FREE {
            cell = stackref_borrow(oldvalue);
        } elif (kind & CO_FAST_CELL) != 0 and oldvalue != STACKREF_NULL {
            as_obj = stackref_borrow(oldvalue);
            if cell_check(as_obj) {
                cell = as_obj;
            }
        }
        if cell {
            object_incref(value);
            cell_set_take_ref(cell, value);
        } elif value != stackref_borrow(oldvalue) {
            old_obj = stackref_borrow((fast + index).view(1)[0]);
            if old_obj and not object_is_immortal(old_obj) {
                if add_overwritten_fast_local(frame, old_obj) < 0 {
                    return i32(-1);
                }
                stackref_close((fast + index).view(1)[0]);
            }
            (fast + index).view(1)[0] = stackref_new(value);
        }
        return i32(0);
    }
    extra = field(frame, PyFrameObject_EXTRA_LOCALS);
    if not extra {
        if not value {
            _PyErr_SetKeyError(key);
            return i32(-1);
        }
        extra = PyDict_New();
        if not extra {
            return i32(-1);
        }
        set_field(frame, PyFrameObject_EXTRA_LOCALS, extra);
    }
    if not value {
        return PyDict_DelItem(extra, key);
    }
    return PyDict_SetItem(extra, key, value);
}

impl framelocalsproxy_merge(self: ptr[PyObject], other: ptr[PyObject]) -> i32 {
    if not dict_check(other) and not proxy_check(other) {
        return i32(-1);
    }
    keys = PyMapping_Keys(other);
    if not keys {
        return i32(-1);
    }
    it = PyObject_GetIter(keys);
    object_decref(keys);
    if not it {
        return i32(-1);
    }
    key = PyIter_Next(it);
    while key {
        value = PyObject_GetItem(other, key);
        if not value {
            object_decref(key);
            object_decref(it);
            return i32(-1);
        }
        if framelocalsproxy_setitem(self, key, value) < 0 {
            object_decref(key);
            object_decref(value);
            object_decref(it);
            return i32(-1);
        }
        object_decref(key);
        object_decref(value);
        key = PyIter_Next(it);
    }
    object_decref(it);
    if PyErr_Occurred() {
        return i32(-1);
    }
    return i32(0);
}

impl framelocalsproxy_keys(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    frame = proxy_frame(self);
    iframe = frame_iframe(frame);
    co = iframe_code(iframe);
    names = PyList_New(0);
    if not names {
        return NULL;
    }
    n = code_nlocalsplus(co);
    i: i64 = 0;
    while i < n {
        if framelocalsproxy_hasval(iframe, co, i) {
            if PyList_Append(names, local_name(co, i)) < 0 {
                object_decref(names);
                return NULL;
            }
        }
        i += 1;
    }
    extra = field(frame, PyFrameObject_EXTRA_LOCALS);
    if extra {
        pos: i64 = 0;
        key: ptr[PyObject] = NULL;
        value: ptr[PyObject] = NULL;
        while PyDict_Next(extra, &mut pos, &mut key, &mut value) != 0 {
            if PyList_Append(names, key) < 0 {
                object_decref(names);
                return NULL;
            }
        }
    }
    return names;
}

impl framelocalsproxy_dealloc(self: ptr[PyObject]) {
    PyObject_GC_UnTrack(ptr(self));
    clear_field(self, PyFrameLocalsProxyObject_FRAME);
    object_type(self).view(1)[0].tp_free(ptr(self));
}

impl framelocalsproxy_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if object_size(args) != 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("FrameLocalsProxy expected 1 argument, got %zd"),
            object_size(args)
        );
        return NULL;
    }
    item = tuple_get_item(args, 0);
    if not frame_check(item) {
        PyErr_Format(PyExc_TypeError, ptr[u8]("expect frame, not %T"), item);
        return NULL;
    }
    if kwds and PyDict_Size(kwds) != 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("FrameLocalsProxy takes no keyword arguments")
        );
        return NULL;
    }
    proxy = type.view(1)[0].tp_alloc(type, 0);
    if not proxy {
        return NULL;
    }
    set_field(proxy, PyFrameLocalsProxyObject_FRAME, object_new_ref(item));
    return proxy;
}

impl framelocalsproxy_tp_clear(self: ptr[PyObject]) -> i32 {
    clear_field(self, PyFrameLocalsProxyObject_FRAME);
    return i32(0);
}

impl framelocalsproxy_visit(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(proxy_frame(self), visitor, arg);
}

impl framelocalsproxy_iter(self: ptr[PyObject]) -> ptr[PyObject] {
    keys = framelocalsproxy_keys(self, NULL);
    if not keys {
        return NULL;
    }
    it = PyObject_GetIter(keys);
    object_xdecref(keys);
    return it;
}

impl framelocalsproxy_richcompare(
    lhs: ptr[PyObject], rhs: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if proxy_check(rhs) {
        same = proxy_frame(lhs) == proxy_frame(rhs);
        if op == Py_EQ {
            return PyBool_FromLong(1 if same else 0);
        } elif op == Py_NE {
            return PyBool_FromLong(0 if same else 1);
        }
    } elif dict_check(rhs) {
        dct = PyDict_New();
        if not dct {
            return NULL;
        }
        if PyDict_Update(dct, lhs) < 0 {
            object_decref(dct);
            return NULL;
        }
        result = PyObject_RichCompare(dct, rhs, op);
        object_decref(dct);
        return result;
    }
    return Py_NewRef(Py_NotImplemented);
}

impl framelocalsproxy_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    i = Py_ReprEnter(self);
    if i != 0 {
        if i > 0 {
            return PyUnicode_FromString(ptr[u8]("{...}"));
        }
        return NULL;
    }
    dct = PyDict_New();
    if not dct {
        Py_ReprLeave(self);
        return NULL;
    }
    if PyDict_Update(dct, self) < 0 {
        object_decref(dct);
        Py_ReprLeave(self);
        return NULL;
    }
    repr = PyObject_Repr(dct);
    object_decref(dct);
    Py_ReprLeave(self);
    return repr;
}

impl framelocalsproxy_or(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    if not dict_check(other) and not proxy_check(other) {
        return Py_NewRef(Py_NotImplemented);
    }
    result = PyDict_New();
    if not result {
        return NULL;
    }
    if PyDict_Update(result, self) < 0 {
        object_decref(result);
        return NULL;
    }
    if PyDict_Update(result, other) < 0 {
        object_decref(result);
        return NULL;
    }
    return result;
}

impl framelocalsproxy_inplace_or(
    self: ptr[PyObject], other: ptr[PyObject]
) -> ptr[PyObject] {
    if not dict_check(other) and not proxy_check(other) {
        return Py_NewRef(Py_NotImplemented);
    }
    if framelocalsproxy_merge(self, other) < 0 {
        return Py_NewRef(Py_NotImplemented);
    }
    return object_new_ref(self);
}

impl framelocalsproxy_values(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    frame = proxy_frame(self);
    iframe = frame_iframe(frame);
    co = iframe_code(iframe);
    values = PyList_New(0);
    if not values {
        return NULL;
    }
    n = code_nlocalsplus(co);
    i: i64 = 0;
    while i < n {
        value = framelocalsproxy_getval(iframe, co, i);
        if value {
            if PyList_Append(values, value) < 0 {
                object_decref(values);
                object_decref(value);
                return NULL;
            }
            object_decref(value);
        }
        i += 1;
    }
    extra = field(frame, PyFrameObject_EXTRA_LOCALS);
    if extra {
        pos: i64 = 0;
        key: ptr[PyObject] = NULL;
        extra_value: ptr[PyObject] = NULL;
        while PyDict_Next(extra, &mut pos, &mut key, &mut extra_value) != 0 {
            if PyList_Append(values, extra_value) < 0 {
                object_decref(values);
                return NULL;
            }
        }
    }
    return values;
}

impl framelocalsproxy_items(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    frame = proxy_frame(self);
    iframe = frame_iframe(frame);
    co = iframe_code(iframe);
    items = PyList_New(0);
    if not items {
        return NULL;
    }
    n = code_nlocalsplus(co);
    i: i64 = 0;
    while i < n {
        name = local_name(co, i);
        value = framelocalsproxy_getval(iframe, co, i);
        if value {
            pair = PyTuple_Pack(2, name, value);
            if not pair {
                object_decref(items);
                object_decref(value);
                return NULL;
            }
            if PyList_Append(items, pair) < 0 {
                object_decref(items);
                object_decref(pair);
                object_decref(value);
                return NULL;
            }
            object_decref(pair);
            object_decref(value);
        }
        i += 1;
    }
    extra = field(frame, PyFrameObject_EXTRA_LOCALS);
    if extra {
        pos: i64 = 0;
        key: ptr[PyObject] = NULL;
        extra_value: ptr[PyObject] = NULL;
        while PyDict_Next(extra, &mut pos, &mut key, &mut extra_value) != 0 {
            extra_pair = PyTuple_Pack(2, key, extra_value);
            if not extra_pair {
                object_decref(items);
                return NULL;
            }
            if PyList_Append(items, extra_pair) < 0 {
                object_decref(items);
                object_decref(extra_pair);
                return NULL;
            }
            object_decref(extra_pair);
        }
    }
    return items;
}

impl framelocalsproxy_length(self: ptr[PyObject]) -> i64 {
    frame = proxy_frame(self);
    iframe = frame_iframe(frame);
    co = iframe_code(iframe);
    size: i64 = 0;
    extra = field(frame, PyFrameObject_EXTRA_LOCALS);
    if extra {
        size += PyDict_Size(extra);
    }
    n = code_nlocalsplus(co);
    i: i64 = 0;
    while i < n {
        if framelocalsproxy_hasval(iframe, co, i) {
            size += 1;
        }
        i += 1;
    }
    return size;
}

impl framelocalsproxy_contains(self: ptr[PyObject], key: ptr[PyObject]) -> i32 {
    frame = proxy_frame(self);
    (i, unused) = framelocalsproxy_getkeyindex(frame, key, True, False);
    if i == -2 {
        return i32(-1);
    }
    if i >= 0 {
        return i32(1);
    }
    extra = field(frame, PyFrameObject_EXTRA_LOCALS);
    if extra {
        return PyDict_Contains(extra, key);
    }
    return i32(0);
}

impl framelocalsproxy___contains__(
    self: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    result = framelocalsproxy_contains(self, key);
    if result < 0 {
        return NULL;
    }
    return PyBool_FromLong(i64(result));
}

impl framelocalsproxy_update(
    self: ptr[PyObject], other: ptr[PyObject]
) -> ptr[PyObject] {
    if framelocalsproxy_merge(self, other) < 0 {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("update() argument must be dict or another FrameLocalsProxy")
        );
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl framelocalsproxy_get(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs < 1 or nargs > 2 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("get expected 1 or 2 arguments"));
        return NULL;
    }
    key = args.view(1)[0];
    default_value = Py_None;
    if nargs == 2 {
        default_value = (args + 1).view(1)[0];
    }
    result = framelocalsproxy_getitem(self, key);
    if not result {
        if PyErr_ExceptionMatches(PyExc_KeyError) != 0 {
            PyErr_Clear();
            return Py_XNewRef(default_value);
        }
        return NULL;
    }
    return result;
}

impl framelocalsproxy_setdefault(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs < 1 or nargs > 2 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("setdefault expected 1 or 2 arguments")
        );
        return NULL;
    }
    key = args.view(1)[0];
    default_value = Py_None;
    if nargs == 2 {
        default_value = (args + 1).view(1)[0];
    }
    result = framelocalsproxy_getitem(self, key);
    if not result {
        if PyErr_ExceptionMatches(PyExc_KeyError) != 0 {
            PyErr_Clear();
            if framelocalsproxy_setitem(self, key, default_value) < 0 {
                return NULL;
            }
            return Py_XNewRef(default_value);
        }
        return NULL;
    }
    return result;
}

impl framelocalsproxy_pop(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("pop"), nargs, 1, 2) == 0 {
        return NULL;
    }
    key = args.view(1)[0];
    default_value: ptr[PyObject] = NULL;
    if nargs == 2 {
        default_value = (args + 1).view(1)[0];
    }
    frame = proxy_frame(self);
    (i, unused) = framelocalsproxy_getkeyindex(frame, key, False, False);
    if i == -2 {
        return NULL;
    }
    if i >= 0 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("cannot remove local variables from FrameLocalsProxy")
        );
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    extra = field(frame, PyFrameObject_EXTRA_LOCALS);
    if not extra {
        if default_value {
            return Py_XNewRef(default_value);
        }
        _PyErr_SetKeyError(key);
        return NULL;
    }
    if PyDict_Pop(extra, key, &mut result) < 0 {
        return NULL;
    }
    if not result {
        if default_value {
            return Py_XNewRef(default_value);
        }
        _PyErr_SetKeyError(key);
        return NULL;
    }
    return result;
}

impl framelocalsproxy_copy(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    result = PyDict_New();
    if not result {
        return NULL;
    }
    if PyDict_Update(result, self) < 0 {
        object_decref(result);
        return NULL;
    }
    return result;
}

impl framelocalsproxy_reversed(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    result = framelocalsproxy_keys(self, NULL);
    if not result {
        return NULL;
    }
    if PyList_Reverse(result) < 0 {
        object_decref(result);
        return NULL;
    }
    return result;
}

impl frame_locals_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    iframe = frame_iframe(self);
    co = iframe_code(iframe);
    if (code_i32(co, PyCodeObject_FLAGS) & CO_OPTIMIZED) == 0
        and not _PyFrame_HasHiddenLocals(iframe) {
        if not iframe_object(iframe, _PyInterpreterFrame_F_LOCALS) {
            set_iframe_object(iframe, _PyInterpreterFrame_F_LOCALS, PyDict_New());
            if not iframe_object(iframe, _PyInterpreterFrame_F_LOCALS) {
                return NULL;
            }
        }
        return object_new_ref(iframe_object(iframe, _PyInterpreterFrame_F_LOCALS));
    }
    return _PyFrameLocalsProxy_New(self);
}

impl frame_lineno_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    lineno = PyFrame_GetLineNumber(self);
    if lineno < 0 {
        return Py_NewRef(Py_None);
    }
    return PyLong_FromLong(i64(lineno));
}

impl frame_lasti_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    lasti = PyUnstable_InterpreterFrame_GetLasti(frame_iframe(self));
    if lasti < 0 {
        return PyLong_FromLong(-1);
    }
    return PyLong_FromLong(i64(lasti));
}

impl frame_globals_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    globals = iframe_object(frame_iframe(self), _PyInterpreterFrame_F_GLOBALS);
    if not globals {
        globals = Py_None;
    }
    return object_new_ref(globals);
}

impl frame_builtins_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    builtins = iframe_object(frame_iframe(self), _PyInterpreterFrame_F_BUILTINS);
    if not builtins {
        builtins = Py_None;
    }
    return object_new_ref(builtins);
}

impl frame_code_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    if PySys_Audit("object.__getattr__", "Os", self, "f_code") < 0 {
        return NULL;
    }
    return PyFrame_GetCode(self);
}

impl frame_back_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    res = PyFrame_GetBack(self);
    if not res {
        return Py_NewRef(Py_None);
    }
    return res;
}

impl frame_trace_opcodes_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    if frame_trace_opcodes(self) != u8(0) {
        return addressof(_Py_TrueStruct);
    }
    return addressof(_Py_FalseStruct);
}

impl frame_trace_opcodes_set(
    self: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32 {
    if not object_is_type(value, addressof(PyBool_Type)) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("attribute value type must be bool"));
        return i32(-1);
    }
    if value == addressof(_Py_TrueStruct) {
        set_frame_char(self, PyFrameObject_TRACE_OPCODES, u8(1));
        if field(self, PyFrameObject_TRACE) {
            return _PyEval_SetOpcodeTrace(self, True);
        }
    } else {
        set_frame_char(self, PyFrameObject_TRACE_OPCODES, u8(0));
        return _PyEval_SetOpcodeTrace(self, False);
    }
    return i32(0);
}

impl compatible_kind(from_kind: i64, to_kind: i64) -> bool {
    if to_kind == 0 {
        return False;
    }
    if to_kind == KIND_OBJECT {
        return from_kind != KIND_NULL;
    }
    if to_kind == KIND_NULL {
        return True;
    }
    return from_kind == to_kind;
}

impl push_value(stack: i64, kind: i64) -> i64 {
    if u64.wrap(stack) >= WILL_OVERFLOW {
        return OVERFLOWED;
    }
    return (stack << BITS_PER_BLOCK) | kind;
}

impl pop_value(stack: i64) -> i64 {
    return stack >> BITS_PER_BLOCK;
}

impl top_of_stack(stack: i64) -> i64 {
    return stack & STACK_MASK;
}

impl peek(stack: i64, n: i64) -> i64 {
    return (stack >> (BITS_PER_BLOCK * (n - 1))) & STACK_MASK;
}

impl stack_swap(stack: i64, n: i64) -> i64 {
    to_swap = u64.wrap(peek(stack, n));
    top = u64.wrap(top_of_stack(stack));
    shift = u64.wrap(BITS_PER_BLOCK * (n - 1));
    mask = u64(7);
    bits = u64.wrap(stack);
    replaced_low = (bits & ~(mask << shift)) | (top << shift);
    replaced_top = (replaced_low & ~mask) | to_swap;
    return i64.wrap(replaced_top);
}

impl pop_to_level(stack_in: i64, level: i64) -> i64 {
    if level == 0 {
        return EMPTY_STACK;
    }
    max_item = u64(7);
    level_max_stack = i64.wrap(max_item << u64.wrap((level - 1) * BITS_PER_BLOCK));
    stack = stack_in;
    while stack > level_max_stack {
        stack = pop_value(stack);
    }
    return stack;
}

impl parse_varint(p_in: ptr[u8]) -> tuple[ptr[u8], i64] {
    p = p_in;
    val = i64(p.view(1)[0] & u8(63));
    while (p.view(1)[0] & u8(64)) != u8(0) {
        p = p + 1;
        val = (val << 6) | i64(p.view(1)[0] & u8(63));
    }
    return (p + 1, val);
}

impl stack_at(stacks: ptr[i64], i: i64) -> i64 {
    return (stacks + i).view(1)[0];
}

impl stack_put(stacks: ptr[i64], i: i64, value: i64) {
    (stacks + i).view(1)[0] = value;
}

impl is_block_end(opcode: int) -> bool {
    return opcode == OP_RETURN_VALUE
        or opcode == OP_RAISE_VARARGS
        or opcode == OP_RERAISE;
}

impl is_pop_jump(opcode: int) -> bool {
    return opcode == OP_POP_JUMP_IF_FALSE
        or opcode == OP_POP_JUMP_IF_TRUE
        or opcode == OP_POP_JUMP_IF_NONE
        or opcode == OP_POP_JUMP_IF_NOT_NONE;
}

impl mark_stacks(code_obj: ptr[PyObject], n_units: i64) -> ptr[i64] {
    co_code = _PyCode_GetCode(code_obj);
    if not co_code {
        return ptr[i64]();
    }
    stacks = ptr[i64](PyMem_Malloc(u64(n_units + 1) * u64(8)));
    if not stacks {
        PyErr_NoMemory();
        object_decref(co_code);
        return ptr[i64]();
    }
    k: i64 = 1;
    while k <= n_units {
        stack_put(stacks, k, UNINITIALIZED);
        k += 1;
    }
    stack_put(stacks, 0, EMPTY_STACK);
    i: i64 = 0;
    j: i64 = 0;
    oparg: int = 0;
    todo = True;
    while todo {
        todo = False;
        i = 0;
        while i < n_units {
            next_stack = stack_at(stacks, i);
            inst = _Py_GetBaseCodeUnit(code_obj, i32(i));
            opcode = int(inst & u16(255));
            oparg = 0;
            while opcode == OP_EXTENDED_ARG {
                oparg = (oparg << 8) | int(inst >> u16(8));
                i += 1;
                inst = _Py_GetBaseCodeUnit(code_obj, i32(i));
                opcode = int(inst & u16(255));
                stack_put(stacks, i, next_stack);
            }
            oparg = (oparg << 8) | int(inst >> u16(8));
            next_i = i + i64(opcode_caches(opcode)) + 1;
            if next_stack == UNINITIALIZED {
                i = next_i;
                continue;
            }
            if is_pop_jump(opcode) {
                j = next_i + i64(oparg);
                next_stack = pop_value(next_stack);
                target_stack = next_stack;
                stack_put(stacks, j, target_stack);
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_SEND {
                j = i64(oparg) + i + INLINE_CACHE_ENTRIES_SEND + 1;
                stack_put(stacks, j, next_stack);
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_JUMP_FORWARD {
                j = i64(oparg) + i + 1;
                stack_put(stacks, j, next_stack);
            } elif opcode == OP_JUMP_BACKWARD
                or opcode == OP_JUMP_BACKWARD_NO_INTERRUPT {
                j = next_i - i64(oparg);
                if stack_at(stacks, j) == UNINITIALIZED and j < i {
                    todo = True;
                }
                stack_put(stacks, j, next_stack);
            } elif opcode == OP_GET_ITER or opcode == OP_GET_AITER {
                next_stack = push_value(pop_value(next_stack), KIND_ITERATOR);
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_FOR_ITER {
                for_target = push_value(next_stack, KIND_OBJECT);
                stack_put(stacks, next_i, for_target);
                j = i64(oparg) + 1 + INLINE_CACHE_ENTRIES_FOR_ITER + i;
                stack_put(stacks, j, for_target);
            } elif opcode == OP_END_ASYNC_FOR {
                next_stack = pop_value(pop_value(next_stack));
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_PUSH_EXC_INFO {
                next_stack = push_value(next_stack, KIND_EXCEPT);
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_POP_EXCEPT {
                next_stack = pop_value(next_stack);
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_PUSH_NULL {
                next_stack = push_value(next_stack, KIND_NULL);
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_LOAD_GLOBAL {
                next_stack = push_value(next_stack, KIND_OBJECT);
                if (oparg & 1) != 0 {
                    next_stack = push_value(next_stack, KIND_NULL);
                }
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_LOAD_ATTR {
                if (oparg & 1) != 0 {
                    next_stack = pop_value(next_stack);
                    next_stack = push_value(next_stack, KIND_OBJECT);
                    next_stack = push_value(next_stack, KIND_NULL);
                }
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_SWAP {
                next_stack = stack_swap(next_stack, i64(oparg));
                stack_put(stacks, next_i, next_stack);
            } elif opcode == OP_COPY {
                next_stack = push_value(next_stack, peek(next_stack, i64(oparg)));
                stack_put(stacks, next_i, next_stack);
            } elif not is_block_end(opcode) {
                delta = PyCompile_OpcodeStackEffect(i32(opcode), i32(oparg));
                while delta < 0 {
                    next_stack = pop_value(next_stack);
                    delta += 1;
                }
                while delta > 0 {
                    next_stack = push_value(next_stack, KIND_OBJECT);
                    delta -= 1;
                }
                stack_put(stacks, next_i, next_stack);
            }
            i = next_i;
        }
        table = field(code_obj, PyCodeObject_EXCEPTIONTABLE);
        scan = ptr[u8](table) + PyBytesObject_OB_SVAL;
        end = scan + object_size(table);
        while scan < end {
            (scan, start_offset) = parse_varint(scan);
            (scan, size) = parse_varint(scan);
            (scan, handler) = parse_varint(scan);
            (scan, depth_and_lasti) = parse_varint(scan);
            level = depth_and_lasti >> 1;
            lasti = depth_and_lasti & 1;
            if stack_at(stacks, start_offset) != UNINITIALIZED {
                if stack_at(stacks, handler) == UNINITIALIZED {
                    todo = True;
                    handler_stack = pop_to_level(stack_at(stacks, start_offset), level);
                    if lasti != 0 {
                        handler_stack = push_value(handler_stack, KIND_LASTI);
                    }
                    handler_stack = push_value(handler_stack, KIND_EXCEPT);
                    stack_put(stacks, handler, handler_stack);
                }
            }
        }
    }
    object_decref(co_code);
    return stacks;
}

impl compatible_stack(from_in: i64, to_in: i64) -> bool {
    if from_in < 0 or to_in < 0 {
        return False;
    }
    from_stack = from_in;
    to_stack = to_in;
    while from_stack > to_stack {
        from_stack = pop_value(from_stack);
    }
    while from_stack != 0 {
        if not compatible_kind(top_of_stack(from_stack), top_of_stack(to_stack)) {
            return False;
        }
        from_stack = pop_value(from_stack);
        to_stack = pop_value(to_stack);
    }
    return to_stack == 0;
}

impl explain_incompatible_stack(to_stack: i64) -> ptr[u8] {
    if to_stack == OVERFLOWED {
        return ptr[u8]("stack is too deep to analyze");
    }
    if to_stack == UNINITIALIZED {
        return ptr[u8](
            "can't jump into an exception handler, or code may be unreachable"
        );
    }
    target_kind = top_of_stack(to_stack);
    if target_kind == KIND_EXCEPT {
        return ptr[u8]("can't jump into an 'except' block as there's no exception");
    }
    if target_kind == KIND_LASTI {
        return ptr[u8]("can't jump into a re-raising block as there's no location");
    }
    if target_kind == KIND_OBJECT or target_kind == KIND_NULL {
        return ptr[u8]("incompatible stacks");
    }
    return ptr[u8]("can't jump into the body of a for loop");
}

impl marklines(code: ptr[PyObject], n_units: i64) -> ptr[i32] {
    bounds = ptr[u8](PyMem_Malloc(u64(PyCodeAddressRange_SIZE)));
    if not bounds {
        PyErr_NoMemory();
        return ptr[i32]();
    }
    _PyCode_InitAddressRange(code, bounds);
    last_line = i32(-1);
    linestarts = ptr[i32](PyMem_Malloc(u64(n_units) * u64(4)));
    if not linestarts {
        PyMem_Free(ptr(bounds));
        return ptr[i32]();
    }
    i: i64 = 0;
    while i < n_units {
        (linestarts + i).view(1)[0] = i32(-1);
        i += 1;
    }
    while _PyLineTable_NextAddressRange(bounds) != 0 {
        ar_start = ptr[i32](bounds + PyCodeAddressRange_AR_START).view(1)[0];
        ar_line = ptr[i32](bounds + PyCodeAddressRange_AR_LINE).view(1)[0];
        if ar_line != last_line and ar_line != -1 {
            (linestarts + i64(ar_start) // 2).view(1)[0] = ar_line;
            last_line = ar_line;
        }
    }
    PyMem_Free(ptr(bounds));
    return linestarts;
}

impl first_line_not_before(lines: ptr[i32], n_units: i64, line: i32) -> i32 {
    result = i32(INT_MAX);
    i: i64 = 0;
    while i < n_units {
        value = (lines + i).view(1)[0];
        if value < result and value >= line {
            result = value;
        }
        i += 1;
    }
    if i64(result) == INT_MAX {
        return i32(-1);
    }
    return result;
}

impl frame_is_suspended(frame: ptr[PyObject]) -> bool {
    iframe = frame_iframe(frame);
    if iframe_owner(iframe) == FRAME_OWNED_BY_GENERATOR {
        gen = iframe_generator(iframe);
        return frame_state_suspended(gen_frame_state(gen));
    }
    return False;
}

impl frame_lineno_set(self: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    iframe = frame_iframe(self);
    code = iframe_code(iframe);
    if not value {
        PyErr_SetString(PyExc_AttributeError, ptr[u8]("cannot delete attribute"));
        return i32(-1);
    }
    if not object_is_type(value, addressof(PyLong_Type)) {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("lineno must be an integer"));
        return i32(-1);
    }
    is_suspended = frame_is_suspended(self);
    tstate = ptr[u8](PyThreadState_Get());
    what_event = ptr[i32](tstate + PyThreadState_WHAT_EVENT).view(1)[0];
    if what_event < 0 {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("f_lineno can only be set in a trace function")
        );
        return i32(-1);
    }
    jump_allowed = what_event == EVENT_PY_RESUME
        or what_event == EVENT_JUMP
        or what_event == EVENT_BRANCH
        or what_event == EVENT_BRANCH_LEFT
        or what_event == EVENT_BRANCH_RIGHT
        or what_event == EVENT_LINE
        or what_event == EVENT_PY_YIELD;
    if not jump_allowed {
        if what_event == EVENT_PY_START {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("can't jump from the 'call' trace event of a new frame")
            );
        } elif what_event == EVENT_CALL or what_event == EVENT_C_RETURN {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("can't jump during a call"));
        } elif what_event == EVENT_PY_RETURN
            or what_event == EVENT_PY_UNWIND
            or what_event == EVENT_PY_THROW
            or what_event == EVENT_RAISE
            or what_event == EVENT_C_RAISE
            or what_event == EVENT_INSTRUCTION
            or what_event == EVENT_EXCEPTION_HANDLED {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("can only jump from a 'line' trace event")
            );
        } else {
            PyErr_SetString(PyExc_SystemError, ptr[u8]("unexpected event type"));
        }
        return i32(-1);
    }
    overflow = i32(0);
    l_new_lineno = PyLong_AsLongAndOverflow(value, &mut overflow);
    if overflow != 0 or l_new_lineno > INT_MAX or l_new_lineno < INT_MIN {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("lineno out of range"));
        return i32(-1);
    }
    new_lineno = i32(l_new_lineno);
    if new_lineno < code_i32(code, PyCodeObject_FIRSTLINENO) {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("line %d comes before the current code block"),
            new_lineno
        );
        return i32(-1);
    }
    n_units = i64(i32(object_size(code)));
    lines = marklines(code, n_units);
    if not lines {
        return i32(-1);
    }
    new_lineno = first_line_not_before(lines, n_units, new_lineno);
    if new_lineno < 0 {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("line %d comes after the current code block"),
            i32(l_new_lineno)
        );
        PyMem_Free(ptr(lines));
        return i32(-1);
    }
    stacks = mark_stacks(code, n_units);
    if not stacks {
        PyMem_Free(ptr(lines));
        return i32(-1);
    }
    best_stack = OVERFLOWED;
    best_addr: i64 = -1;
    start_stack = stack_at(stacks, i64(iframe_lasti(iframe)));
    err = -1;
    msg = ptr[u8]("cannot find bytecode for specified line");
    i: i64 = 0;
    while i < n_units {
        if (lines + i).view(1)[0] == new_lineno {
            target_stack = stack_at(stacks, i);
            if compatible_stack(start_stack, target_stack) {
                err = 0;
                if target_stack > best_stack {
                    best_stack = target_stack;
                    best_addr = i;
                }
            } elif err < 0 {
                if start_stack == OVERFLOWED {
                    msg = ptr[u8]("stack to deep to analyze");
                } elif start_stack == UNINITIALIZED {
                    msg = ptr[u8]("can't jump from unreachable code");
                } else {
                    msg = explain_incompatible_stack(target_stack);
                    err = 1;
                }
            }
        }
        i += 1;
    }
    PyMem_Free(ptr(stacks));
    PyMem_Free(ptr(lines));
    if err != 0 {
        PyErr_SetString(PyExc_ValueError, msg);
        return i32(-1);
    }
    fast = iframe_localsplus(iframe);
    nlocalsplus = code_nlocalsplus(code);
    unbound = i32(0);
    i = 0;
    while i < nlocalsplus {
        if (fast + i).view(1)[0] == STACKREF_NULL {
            unbound += 1;
        }
        i += 1;
    }
    if unbound != 0 {
        plural = "" if unbound == 1 else "s";
        if PyErr_WarnFormat(
            PyExc_RuntimeWarning,
            0,
            ptr[u8]("assigning None to %d unbound local%s"),
            unbound,
            plural
        )
            != 0 {
            return i32(-1);
        }
        i = 0;
        while i < nlocalsplus {
            if (fast + i).view(1)[0] == STACKREF_NULL {
                (fast + i).view(1)[0] = stackref_none();
                unbound -= 1;
            }
            i += 1;
        }
    }
    if is_suspended {
        start_stack = pop_value(start_stack);
    }
    while start_stack > best_stack {
        popped = iframe_stack_pop(iframe);
        if top_of_stack(start_stack) == KIND_EXCEPT {
            exc = stackref_borrow(popped);
            ts = ptr[u8](current_tstate());
            exc_info = ptr[ptr[u8]](ts + PyThreadState_EXC_INFO).view(1)[0];
            slot = ptr[ptr[PyObject]](exc_info + _PyErr_StackItem_EXC_VALUE);
            old = slot.view(1)[0];
            slot.view(1)[0] = NULL if exc == Py_None else exc;
            object_xdecref(old);
        } else {
            stackref_close(popped);
        }
        start_stack = pop_value(start_stack);
    }
    set_frame_lineno(self, i32(0));
    set_iframe_instr_ptr(iframe, iframe_bytecode(iframe) + 2 * best_addr);
    return i32(0);
}

impl frame_trace_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    trace = field(self, PyFrameObject_TRACE);
    if not trace {
        trace = Py_None;
    }
    return object_new_ref(trace);
}

impl frame_trace_set(
    self: ptr[PyObject], value_in: ptr[PyObject], closure: ptr
) -> i32 {
    value = value_in;
    if value == Py_None {
        value = NULL;
    }
    if value != field(self, PyFrameObject_TRACE) {
        replace_field(self, PyFrameObject_TRACE, Py_XNewRef(value));
        if value and frame_trace_opcodes(self) != u8(0) {
            return _PyEval_SetOpcodeTrace(self, True);
        }
    }
    return i32(0);
}

impl frame_generator_get(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    iframe = frame_iframe(self);
    if iframe_owner(iframe) == FRAME_OWNED_BY_GENERATOR {
        return object_new_ref(iframe_generator(iframe));
    }
    return Py_NewRef(Py_None);
}

impl clear_stack_down_to_locals(frame: ptr[u8]) {
    locals = iframe_localsplus(frame);
    sp = iframe_stackpointer(frame);
    while sp > locals {
        sp = sp - 1;
        stackref_clear(sp);
    }
}

impl frame_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    frame = frame_data(op);
    if frame_iframe(op) == frame
        and iframe_owner(frame) == FRAME_OWNED_BY_FRAME_OBJECT {
        stackref_clear(ptr[u64](frame + _PyInterpreterFrame_F_EXECUTABLE));
        stackref_clear(ptr[u64](frame + _PyInterpreterFrame_F_FUNCOBJ));
        locals = iframe_object(frame, _PyInterpreterFrame_F_LOCALS);
        if locals {
            set_iframe_object(frame, _PyInterpreterFrame_F_LOCALS, NULL);
            object_decref(locals);
        }
        clear_stack_down_to_locals(frame);
    }
    clear_field(op, PyFrameObject_BACK);
    clear_field(op, PyFrameObject_TRACE);
    clear_field(op, PyFrameObject_EXTRA_LOCALS);
    clear_field(op, PyFrameObject_LOCALS_CACHE);
    clear_field(op, PyFrameObject_OVERWRITTEN_FAST_LOCALS);
    PyObject_GC_Del(ptr(op));
}

impl frame_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status: i32 = 0;
    status = visit_reference(field(op, PyFrameObject_BACK), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field(op, PyFrameObject_TRACE), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field(op, PyFrameObject_EXTRA_LOCALS), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field(op, PyFrameObject_LOCALS_CACHE), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(
        field(op, PyFrameObject_OVERWRITTEN_FAST_LOCALS), visitor, arg
    );
    if status != 0 {
        return status;
    }
    iframe = frame_iframe(op);
    if iframe_owner(iframe) != FRAME_OWNED_BY_FRAME_OBJECT {
        return i32(0);
    }
    return _PyFrame_Traverse(iframe, visitor, arg);
}

impl frame_tp_clear(op: ptr[PyObject]) -> i32 {
    clear_field(op, PyFrameObject_TRACE);
    clear_field(op, PyFrameObject_EXTRA_LOCALS);
    clear_field(op, PyFrameObject_LOCALS_CACHE);
    clear_field(op, PyFrameObject_OVERWRITTEN_FAST_LOCALS);
    iframe = frame_iframe(op);
    clear_stack_down_to_locals(iframe);
    set_iframe_stackpointer(iframe, iframe_localsplus(iframe));
    locals = iframe_object(iframe, _PyInterpreterFrame_F_LOCALS);
    if locals {
        set_iframe_object(iframe, _PyInterpreterFrame_F_LOCALS, NULL);
        object_decref(locals);
    }
    return i32(0);
}

impl frame_clear(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    iframe = frame_iframe(self);
    owner = iframe_owner(iframe);
    if owner == FRAME_OWNED_BY_GENERATOR {
        gen = iframe_generator(iframe);
        state = gen_frame_state(gen);
        if state == FRAME_EXECUTING {
            PyErr_SetString(
                PyExc_RuntimeError, ptr[u8]("cannot clear an executing frame")
            );
            return NULL;
        }
        if frame_state_suspended(state) {
            PyErr_SetString(
                PyExc_RuntimeError, ptr[u8]("cannot clear a suspended frame")
            );
            return NULL;
        }
        _PyGen_Finalize(gen);
    } elif owner == FRAME_OWNED_BY_THREAD {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("cannot clear an executing frame"));
        return NULL;
    } else {
        frame_tp_clear(self);
    }
    return Py_NewRef(Py_None);
}

impl frame___sizeof__(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    res = PyFrameObject_FRAME_DATA + _PyInterpreterFrame_LOCALSPLUS;
    code = iframe_code(frame_iframe(self));
    slots = i64(code_i32(code, PyCodeObject_FRAMESIZE)) - FRAME_SPECIALS_SIZE;
    res += slots * 8;
    return PyLong_FromSsize_t(res);
}

impl frame_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    lineno = PyFrame_GetLineNumber(op);
    code = iframe_code(frame_iframe(op));
    return PyUnicode_FromFormat(
        "<frame at %p, file %R, line %d, code %S>",
        op,
        field(code, PyCodeObject_FILENAME),
        lineno,
        field(code, PyCodeObject_NAME)
    );
}

impl init_frame(
    tstate: ptr[u8], frame: ptr[u8], func: ptr[PyObject], locals: ptr[PyObject]
) {
    code = field(func, PyFunctionObject_CODE);
    frame_initialize(frame, stackref_new(func), Py_XNewRef(locals), code, 0, ptr[u8]());
}

impl frame_init_get_vars(frame: ptr[u8]) {
    co = iframe_code(frame);
    lasti = iframe_lasti(frame);
    if not (
        lasti < 0
        and int(iframe_bytecode(frame).view(1)[0]) == OP_COPY_FREE_VARS
        and function_check(
            stackref_borrow(ptr[u64](frame + _PyInterpreterFrame_F_FUNCOBJ).view(1)[0])
        )
    ) {
        return;
    }
    func = stackref_borrow(ptr[u64](frame + _PyInterpreterFrame_F_FUNCOBJ).view(1)[0]);
    closure = field(func, PyFunctionObject_CLOSURE);
    nfreevars = i64(code_i32(co, PyCodeObject_NFREEVARS));
    offset = code_nlocalsplus(co) - nfreevars;
    i: i64 = 0;
    while i < nfreevars {
        o = tuple_get_item(closure, i);
        (iframe_localsplus(frame) + offset + i).view(1)[0] = stackref_new(o);
        i += 1;
    }
    set_iframe_instr_ptr(frame, iframe_bytecode(frame));
}

impl frame_get_var(
    frame: ptr[u8], co: ptr[PyObject], i: i64
) -> tuple[i32, ptr[PyObject]] {
    kind = local_kind(co, i);
    if (kind & CO_FAST_FREE) != 0
        and (code_i32(co, PyCodeObject_FLAGS) & CO_OPTIMIZED) == 0 {
        return (i32(0), NULL);
    }
    value: ptr[PyObject] = NULL;
    sp = iframe_stackpointer(frame);
    if not sp or int(sp) > int(iframe_localsplus(frame) + i) {
        value = stackref_borrow((iframe_localsplus(frame) + i).view(1)[0]);
        if (kind & CO_FAST_FREE) != 0 {
            value = cell_get_ref(value);
        } elif (kind & CO_FAST_CELL) != 0 {
            if value {
                if cell_check(value) {
                    value = cell_get_ref(value);
                } else {
                    object_incref(value);
                }
            }
        } elif value {
            object_incref(value);
        }
    }
    return (i32(1), value);
}
