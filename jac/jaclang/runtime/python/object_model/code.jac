import from c {
    glob PyType_Type: PyTypeObject,
         _Py_TrueStruct: PyObject,
         _Py_FalseStruct: PyObject; def _PyCode_Quicken(
        instructions: ptr[u16], size: i64, enable_counters: i32
    );  def _Py_GetBaseCodeUnit(code: ptr[PyObject], i: i32) -> u16;  def _PyInstruction_GetLength(
        code: ptr[PyObject], offset: i32
    ) -> i32;  def _Py_Instrumentation_GetLine(
        code: ptr[PyObject], line_data: ptr[u8], index: i32
    ) -> i32;  def _PyInstrumentation_BranchesIterator(
        code: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyFunction_ClearCodeByVersion(version: u32);  def _PyUnicode_InternMortal(
        interp: ptr[u8], p: ptr[ptr[PyObject]]
    );  def _PyUnicode_InternImmortal(interp: ptr[u8], p: ptr[ptr[PyObject]]);  def _PyObject_NewVar(
        tp: ptr[PyTypeObject], nitems: i64
    ) -> ptr[PyObject];  def _PySet_NextEntry(
        set: ptr[PyObject], pos: &mut i64, key: &mut ptr[PyObject], hash: &mut i64
    ) -> i32;  def _Py_GetConfig -> ptr[u8];  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  obj CodeCall {
        has watcher: Callable[[i32, ptr[PyObject]], i32] = 0,
            free: Callable[[ptr], None] = 0;
    }  glob:priv code_opcode_caches: list[u8] = [
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(1),
             u8(3),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(5),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(3),
             u8(0),
             u8(0),
             u8(3),
             u8(1),
             u8(1),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(1),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(1),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(9),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(4),
             u8(0),
             u8(0),
             u8(0),
             u8(1),
             u8(0),
             u8(0),
             u8(0),
             u8(1),
             u8(1),
             u8(1),
             u8(1),
             u8(0),
             u8(0),
             u8(1),
             u8(0),
             u8(0),
             u8(0),
             u8(4),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(1),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0)
         ],
         code_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("co_argcount"),
                 type_=Py_T_INT,
                 offset=PyCodeObject_ARGCOUNT,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_posonlyargcount"),
                 type_=Py_T_INT,
                 offset=PyCodeObject_POSONLYARGCOUNT,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_kwonlyargcount"),
                 type_=Py_T_INT,
                 offset=PyCodeObject_KWONLYARGCOUNT,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_stacksize"),
                 type_=Py_T_INT,
                 offset=PyCodeObject_STACKSIZE,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_flags"),
                 type_=Py_T_INT,
                 offset=PyCodeObject_FLAGS,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_nlocals"),
                 type_=Py_T_INT,
                 offset=PyCodeObject_NLOCALS,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_consts"),
                 type_=_Py_T_OBJECT,
                 offset=PyCodeObject_CONSTS,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_names"),
                 type_=_Py_T_OBJECT,
                 offset=PyCodeObject_NAMES,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_filename"),
                 type_=_Py_T_OBJECT,
                 offset=PyCodeObject_FILENAME,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_name"),
                 type_=_Py_T_OBJECT,
                 offset=PyCodeObject_NAME,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_qualname"),
                 type_=_Py_T_OBJECT,
                 offset=PyCodeObject_QUALNAME,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_firstlineno"),
                 type_=Py_T_INT,
                 offset=PyCodeObject_FIRSTLINENO,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_linetable"),
                 type_=_Py_T_OBJECT,
                 offset=PyCodeObject_LINETABLE,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("co_exceptiontable"),
                 type_=_Py_T_OBJECT,
                 offset=PyCodeObject_EXCEPTIONTABLE,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         code_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("co_lnotab"), get=code_getlnotab),
             PyGetSetDef(name=ptr[u8]("_co_code_adaptive"), get=code_getcodeadaptive),
             PyGetSetDef(name=ptr[u8]("co_varnames"), get=code_getvarnames),
             PyGetSetDef(name=ptr[u8]("co_cellvars"), get=code_getcellvars),
             PyGetSetDef(name=ptr[u8]("co_freevars"), get=code_getfreevars),
             PyGetSetDef(name=ptr[u8]("co_code"), get=code_getcode),
             PyGetSetDef()
         ],
         code_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(code_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("co_lines"),
                 ml_meth=ptr(code_linesiterator),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("co_branches"),
                 ml_meth=ptr(code_branchesiterator),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("co_positions"),
                 ml_meth=ptr(code_positionsiterator),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("replace"),
                 ml_meth=ptr(code_replace),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "replace($self, /, **changes)\n--\n\n"
                     "Return a copy of the code object with new values for the specified fields."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_varname_from_oparg"),
                 ml_meth=ptr(code__varname_from_oparg),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "_varname_from_oparg($self, /, oparg)\n--\n\n"
                     "(internal-only) Return the local variable name for the given oparg.\n\n"
                     "WARNING: this method is for internal use only and may change or go\n"
                     "away."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__replace__"),
                 ml_meth=ptr(code_replace),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "__replace__($self, /, **changes)\n--\n\nThe same as replace()."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyCode_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("code"),
             tp_basicsize=PyCodeObject_CODE_ADAPTIVE,
             tp_itemsize=2,
             tp_dealloc=code_dealloc,
             tp_repr=code_repr,
             tp_hash=code_hash,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_doc=ptr[u8](
                 "code(argcount, posonlyargcount, kwonlyargcount, nlocals, stacksize,\n"
                 "     flags, codestring, constants, names, varnames, filename, name,\n"
                 "     qualname, firstlineno, linetable, exceptiontable, freevars=(),\n"
                 "     cellvars=(), /)\n--\n\n"
                 "Create a code object.  Not for the faint of heart."
             ),
             tp_richcompare=code_richcompare,
             tp_weaklistoffset=PyCodeObject_WEAKREFLIST,
             tp_methods=addressof(code_methods),
             tp_members=addressof(code_memberlist),
             tp_getset=addressof(code_getsetlist),
             tp_new=code_new
         ),
         _PyLineIterator: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("line_iterator"),
             tp_basicsize=lineiterator_SIZE,
             tp_dealloc=lineiter_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_iter=PyObject_SelfIter,
             tp_iternext=lineiter_next,
             tp_free=PyObject_Free
         ),
         _PyPositionsIterator: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("positions_iterator"),
             tp_basicsize=positionsiterator_SIZE,
             tp_dealloc=positionsiter_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_iter=PyObject_SelfIter,
             tp_iternext=positionsiter_next,
             tp_free=PyObject_Free
         );
}

glob:priv CODEUNIT_SIZE: i64 = 2,
     NO_LINE_MARKER: i64 = 0x1f,
     INT_MAX: i64 = 0x7FFFFFFF,
     UINT_MASK: i64 = 0xFFFFFFFF,
     replace_signature = CallSignature(
         "replace",
         [
             "co_argcount",
             "co_posonlyargcount",
             "co_kwonlyargcount",
             "co_nlocals",
             "co_stacksize",
             "co_flags",
             "co_firstlineno",
             "co_code",
             "co_consts",
             "co_names",
             "co_varnames",
             "co_freevars",
             "co_cellvars",
             "co_filename",
             "co_name",
             "co_qualname",
             "co_linetable",
             "co_exceptiontable"
         ],
         0,
         0,
         0,
         parser=PARSE_KEYWORDS
     ),
     varname_from_oparg_signature = CallSignature(
         "_varname_from_oparg", ["oparg"], 1, 1, 0, parser=PARSE_KEYWORDS
     );


def m_obj(base: ptr[u8], offset: i64) -> ptr[PyObject];

def m_set_obj(base: ptr[u8], offset: i64, value: ptr[PyObject]);

def m_ptr(base: ptr[u8], offset: i64) -> ptr[u8];

def m_set_ptr(base: ptr[u8], offset: i64, value: ptr[u8]);

def m_int(base: ptr[u8], offset: i64) -> i64;

def m_set_int(base: ptr[u8], offset: i64, value: i64);

def co_obj(co: ptr[PyObject], offset: i64) -> ptr[PyObject];

def co_set_obj(co: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def co_slot(co: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]];

def co_ptr(co: ptr[PyObject], offset: i64) -> ptr[u8];

def co_set_ptr(co: ptr[PyObject], offset: i64, value: ptr[u8]);

def co_int(co: ptr[PyObject], offset: i64) -> i64;

def co_set_int(co: ptr[PyObject], offset: i64, value: i64);

def co_flags(co: ptr[PyObject]) -> i32;

def co_version(co: ptr[PyObject]) -> u32;

def code_units(co: ptr[PyObject]) -> ptr[u16];

def opcode_caches(opcode: i64) -> i64;

def unit_opcode(unit: u16) -> i64;

def unit_oparg(unit: u16) -> i64;

def base_unit(co: ptr[PyObject], i: i64) -> u16;

def instruction_length(co: ptr[PyObject], i: i64) -> i64;

def bytes_data(op: ptr[PyObject]) -> ptr[u8];

def kind_at(kinds: ptr[PyObject], i: i64) -> i64;

def set_kind_at(kinds: ptr[PyObject], i: i64, kind: i64);

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

def type_of(tp: ptr[PyObject]) -> ptr[PyTypeObject];

def code_check(op: ptr[PyObject]) -> bool;

def bytes_check(op: ptr[PyObject]) -> bool;

def tuple_check(op: ptr[PyObject]) -> bool;

def unicode_check(op: ptr[PyObject]) -> bool;

def unicode_check_exact(op: ptr[PyObject]) -> bool;

def tuple_check_exact(op: ptr[PyObject]) -> bool;

def frozenset_check_exact(op: ptr[PyObject]) -> bool;

def set_check(op: ptr[PyObject]) -> bool;

def bytes_empty -> ptr[PyObject];

def code_debug_ranges -> i64;

def unicode_is_ascii(op: ptr[PyObject]) -> bool;

def unicode_ascii_data(op: ptr[PyObject]) -> ptr[u8];

def unicode_length(op: ptr[PyObject]) -> i64;

def ascii_alnum(c: i64) -> bool;

def refcnt_is_immortal(op: ptr[PyObject]) -> bool;

def set_refcnt(op: ptr[PyObject], refcnt: i64);

def resurrect_start(op: ptr[PyObject]);

def resurrect_end(op: ptr[PyObject]) -> bool;

def offset_value(value: i64) -> ptr[PyObject];

def pack3(a: ptr[PyObject], b: ptr[PyObject], c: ptr[PyObject]) -> ptr[PyObject];

def pack4(
    a: ptr[PyObject], b: ptr[PyObject], c: ptr[PyObject], d: ptr[PyObject]
) -> ptr[PyObject];

def arg_int(op: ptr[PyObject]) -> tuple[bool, i32];

def code_event_name(event: i32) -> str;

def active_code_watchers(interp: ptr[u8]) -> ptr[u8];

def code_watcher_slot(interp: ptr[u8], i: i64) -> ptr[int];

def notify_code_watchers(event: i32, co: ptr[PyObject]);

def validate_watcher_id(interp: ptr[u8], watcher_id: i32) -> i32;

def should_intern_string(o: ptr[PyObject]) -> bool;

def intern_strings(tup: ptr[PyObject]) -> i32;

def intern_constants(tup: ptr[PyObject]) -> tuple[i32, bool];

def validate_and_copy_tuple(tup: ptr[PyObject]) -> ptr[PyObject];

def init_co_cached(co: ptr[PyObject]) -> i32;

def get_localsplus_counts(
    names: ptr[PyObject], kinds: ptr[PyObject]
) -> tuple[i64, i64, i64];

def get_localsplus_names(co: ptr[PyObject], kind: i64, num: i64) -> ptr[PyObject];

def init_code(co: ptr[PyObject], con: ptr[u8]) -> i32;

def scan_varint(p: ptr[u8]) -> i64;

def scan_signed_varint(p: ptr[u8]) -> i64;

def get_line_delta(p: ptr[u8]) -> i64;

def is_no_line_marker(b: i64) -> bool;

def entry_code_delta(first: i64) -> i64;

def write_varint(p: ptr[u8], value: i64) -> i64;

def write_signed_varint(p: ptr[u8], val: i64) -> i64;

def read_varint(p: ptr[u8]) -> tuple[i64, ptr[u8]];

def read_signed_varint(p: ptr[u8]) -> tuple[i64, ptr[u8]];

def decode_location(
    p: ptr[u8], computed_line: i64
) -> tuple[ptr[u8], i64, i64, i64, i64, i64];

def r_lo(bounds: ptr[u8]) -> ptr[u8];

def r_limit(bounds: ptr[u8]) -> ptr[u8];

def at_end(bounds: ptr[u8]) -> bool;

def previous_code_delta(ar_start: i64, lo_next: ptr[u8]) -> i64;

def retreat(bounds: ptr[u8]);

def advance(bounds: ptr[u8]);

def advance_with_locations(bounds: ptr[u8]) -> tuple[i64, i64, i64];

def line_scan(co: ptr[PyObject], lasti: i64) -> i64;

def location_scan(co: ptr[PyObject], addrq: i64) -> tuple[i64, i64, i64, i64];

def emit_pair(
    buf: ptr[PyObject], offset: i64, a: i64, b: i64
) -> tuple[ptr[PyObject], i64];

def emit_delta(
    buf: ptr[PyObject], bdelta_in: i64, ldelta_in: i64, offset_in: i64
) -> tuple[ptr[PyObject], i64];

def decode_linetable(code: ptr[PyObject]) -> ptr[PyObject];

def remove_column_info(locations: ptr[PyObject]) -> ptr[PyObject];

def intern_code_constants(con: ptr[u8]) -> i32;

def code_extra_size(n: i64) -> i64;

def extra_slots(co_extra: ptr[u8]) -> ptr[ptr];

def extra_size(co_extra: ptr[u8]) -> i64;

def extra_freefunc(interp: ptr[u8], index: i64) -> int;

def call_free_extra(free_extra: int, value: ptr);

def code_extra_grow_gil(
    co: ptr[PyObject],
    old_co_extra: ptr[u8],
    old_ce_size: i64,
    new_ce_size: i64,
    index: i64,
    extra: ptr
) -> i32;

def get_cached_locals(
    co: ptr[PyObject], cached_field: i64, kind: i64, num: i64
) -> ptr[PyObject];

def identify_unbound_names(
    co: ptr[PyObject],
    globalnames: ptr[PyObject],
    attrnames: ptr[PyObject],
    globalsns: ptr[PyObject],
    builtinsns: ptr[PyObject]
) -> tuple[i32, i64, i64, i64, i64, i64, i64, i64];

def internal_state_error(co: ptr[PyObject]) -> ptr[u8];

def external_state_error(counts: ptr[u8]) -> ptr[u8];

def pure_function_error(co: ptr[PyObject]) -> ptr[u8];

def verify_stateless_with(
    tstate: ptr,
    co: ptr[PyObject],
    globalnames: ptr[PyObject],
    globalsns: ptr[PyObject],
    builtinsns: ptr[PyObject],
    counts: ptr[u8]
) -> i32;

def code_returns_only_none(co: ptr[PyObject]) -> i32;

def deopt_code(code: ptr[PyObject], instructions: ptr[u16]);

def free_monitoring_field(data: ptr[u8], offset: i64);

def free_monitoring_data(data: ptr[u8]);

def code_equal(co: ptr[PyObject], cp: ptr[PyObject]) -> i32;

def scramble(uhash: u64, value: u64) -> u64;

def scramble_int(uhash: u64, value: i64) -> u64;


import from c {
    def PyCode_AddWatcher(callback: ptr) -> i32 {
        interp = current_interp();
        for i in range(CODE_MAX_WATCHERS) {
            slot = code_watcher_slot(interp, i);
            if slot.view(1)[0] == 0 {
                slot.view(1)[0] = int(callback);
                active = active_code_watchers(interp);
                active.view(1)[0] = active.view(1)[0] | u8(1 << i);
                return i32(i);
            }
        }
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("no more code watcher IDs available")
        );
        return i32(-1);
    }  def PyCode_ClearWatcher(watcher_id: i32) -> i32 {
        interp = current_interp();
        if validate_watcher_id(interp, watcher_id) < 0 {
            return i32(-1);
        }
        code_watcher_slot(interp, i64(watcher_id)).view(1)[0] = 0;
        active = active_code_watchers(interp);
        active.view(1)[0] = active.view(1)[0] & ~u8(1 << i64(watcher_id));
        return i32(0);
    }  def _Py_set_localsplus_info(
        offset: i32,
        name: ptr[PyObject],
        kind: u8,
        names: ptr[PyObject],
        kinds: ptr[PyObject]
    ) {
        tuple_set_item(names, i64(offset), object_new_ref(name));
        set_kind_at(kinds, i64(offset), i64(kind));
    }  def _PyCode_Validate(con: ptr[u8]) -> i32 {
        argcount = m_int(con, _PyCodeConstructor_ARGCOUNT);
        posonlyargcount = m_int(con, _PyCodeConstructor_POSONLYARGCOUNT);
        kwonlyargcount = m_int(con, _PyCodeConstructor_KWONLYARGCOUNT);
        flags = m_int(con, _PyCodeConstructor_FLAGS);
        code = m_obj(con, _PyCodeConstructor_CODE);
        consts = m_obj(con, _PyCodeConstructor_CONSTS);
        names = m_obj(con, _PyCodeConstructor_NAMES);
        localsplusnames = m_obj(con, _PyCodeConstructor_LOCALSPLUSNAMES);
        localspluskinds = m_obj(con, _PyCodeConstructor_LOCALSPLUSKINDS);
        name = m_obj(con, _PyCodeConstructor_NAME);
        qualname = m_obj(con, _PyCodeConstructor_QUALNAME);
        filename = m_obj(con, _PyCodeConstructor_FILENAME);
        linetable = m_obj(con, _PyCodeConstructor_LINETABLE);
        exceptiontable = m_obj(con, _PyCodeConstructor_EXCEPTIONTABLE);
        if argcount < posonlyargcount
            or posonlyargcount < 0
            or kwonlyargcount < 0
            or m_int(con, _PyCodeConstructor_STACKSIZE) < 0
            or flags < 0
            or not code
            or not bytes_check(code)
            or not consts
            or not tuple_check(consts)
            or not names
            or not tuple_check(names)
            or not localsplusnames
            or not tuple_check(localsplusnames)
            or not localspluskinds
            or not bytes_check(localspluskinds)
            or object_size(localsplusnames) != object_size(localspluskinds)
            or not name
            or not unicode_check(name)
            or not qualname
            or not unicode_check(qualname)
            or not filename
            or not unicode_check(filename)
            or not linetable
            or not bytes_check(linetable)
            or not exceptiontable
            or not bytes_check(exceptiontable) {
            PyErr_BadInternalCall();
            return i32(-1);
        }

        if object_size(code) > INT_MAX {
            PyErr_SetString(
                PyExc_OverflowError, ptr[u8]("code: co_code larger than INT_MAX")
            );
            return i32(-1);
        }
        if object_size(code) % CODEUNIT_SIZE != 0
            or (int(bytes_data(code)) % CODEUNIT_SIZE) != 0 {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("code: co_code is malformed"));
            return i32(-1);
        }

        (nlocals, ncellvars, nfreevars) = get_localsplus_counts(
            localsplusnames, localspluskinds
        );
        nplainlocals = nlocals - argcount - kwonlyargcount;
        if (flags & i64(CO_VARARGS)) != 0 {
            nplainlocals -= 1;
        }
        if (flags & i64(CO_VARKEYWORDS)) != 0 {
            nplainlocals -= 1;
        }
        if nplainlocals < 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("code: co_varnames is too small")
            );
            return i32(-1);
        }
        return i32(0);
    }  def _PyCode_New(con: ptr[u8]) -> ptr[PyObject] {
        if intern_code_constants(con) < 0 {
            return NULL;
        }

        replacement_locations: ptr[PyObject] = NULL;
        if code_debug_ranges() == 0 {
            replacement_locations = remove_column_info(
                m_obj(con, _PyCodeConstructor_LINETABLE)
            );
            if not replacement_locations {
                return NULL;
            }
            m_set_obj(con, _PyCodeConstructor_LINETABLE, replacement_locations);
        }

        size = object_size(m_obj(con, _PyCodeConstructor_CODE)) // CODEUNIT_SIZE;
        co = _PyObject_NewVar(addressof(PyCode_Type), size);
        if not co {
            object_xdecref(replacement_locations);
            PyErr_NoMemory();
            return NULL;
        }

        if init_code(co, con) < 0 {
            object_decref(co);
            return NULL;
        }
        object_xdecref(replacement_locations);
        return co;
    }  def PyUnstable_Code_NewWithPosOnlyArgs(
        argcount: i32,
        posonlyargcount: i32,
        kwonlyargcount: i32,
        nlocals: i32,
        stacksize: i32,
        flags: i32,
        code: ptr[PyObject],
        consts: ptr[PyObject],
        names: ptr[PyObject],
        varnames: ptr[PyObject],
        freevars: ptr[PyObject],
        cellvars: ptr[PyObject],
        filename: ptr[PyObject],
        name: ptr[PyObject],
        qualname: ptr[PyObject],
        firstlineno: i32,
        linetable: ptr[PyObject],
        exceptiontable: ptr[PyObject]
    ) -> ptr[PyObject] {
        co: ptr[PyObject] = NULL;
        localsplusnames: ptr[PyObject] = NULL;
        localspluskinds: ptr[PyObject] = NULL;

        if not varnames
            or not tuple_check(varnames)
            or not cellvars
            or not tuple_check(cellvars)
            or not freevars
            or not tuple_check(freevars) {
            PyErr_BadInternalCall();
            return NULL;
        }

        nvarnames = object_size(varnames);
        ncellvars = object_size(cellvars);
        nfreevars = object_size(freevars);
        nlocalsplus = nvarnames + ncellvars + nfreevars;
        ok = True;
        localsplusnames = PyTuple_New(nlocalsplus);
        if not localsplusnames {
            ok = False;
        }
        if ok {
            localspluskinds = PyBytes_FromStringAndSize(ptr[u8](), nlocalsplus);
            if not localspluskinds {
                ok = False;
            }
        }
        if ok {
            offset: i64 = 0;
            for i in range(nvarnames) {
                _Py_set_localsplus_info(
                    i32(offset),
                    tuple_get_item(varnames, i),
                    u8.wrap(CO_FAST_LOCAL),
                    localsplusnames,
                    localspluskinds
                );
                offset += 1;
            }
            for i in range(ncellvars) {
                cellname = tuple_get_item(cellvars, i);
                argoffset: i64 = -1;
                for j in range(nvarnames) {
                    cmp = PyUnicode_Compare(tuple_get_item(varnames, j), cellname);
                    if cmp == 0 {
                        argoffset = j;
                        break;
                    }
                }
                if argoffset >= 0 {
                    nlocalsplus -= 1;
                    set_kind_at(
                        localspluskinds,
                        argoffset,
                        kind_at(localspluskinds, argoffset) | CO_FAST_CELL
                    );
                    continue;
                }
                _Py_set_localsplus_info(
                    i32(offset),
                    cellname,
                    u8.wrap(CO_FAST_CELL),
                    localsplusnames,
                    localspluskinds
                );
                offset += 1;
            }
            for i in range(nfreevars) {
                _Py_set_localsplus_info(
                    i32(offset),
                    tuple_get_item(freevars, i),
                    u8.wrap(CO_FAST_FREE),
                    localsplusnames,
                    localspluskinds
                );
                offset += 1;
            }
        }

        if ok and (flags & CO_OPTIMIZED) == 0 {
            code_data = ptr[u16](bytes_data(code));
            num_code_units = object_size(code) // CODEUNIT_SIZE;
            extended_arg: i64 = 0;
            ui: i64 = 0;
            while ui < num_code_units {
                unit = (code_data + ui).view(1)[0];
                opcode = unit_opcode(unit);
                step = 1 + opcode_caches(opcode);
                if opcode == i64(EXTENDED_ARG) {
                    extended_arg = ((extended_arg & 0xFFFFFF) << 8) | unit_oparg(unit);
                    ui += step;
                    continue;
                }
                if opcode == i64(LOAD_FAST_AND_CLEAR) {
                    oparg = ((extended_arg & 0xFFFFFF) << 8) | unit_oparg(unit);
                    if oparg >= nlocalsplus {
                        PyErr_Format(
                            PyExc_ValueError,
                            ptr[u8]("code: LOAD_FAST_AND_CLEAR oparg %d out of range"),
                            i32.wrap(oparg)
                        );
                        ok = False;
                        break;
                    }
                    set_kind_at(
                        localspluskinds,
                        oparg,
                        kind_at(localspluskinds, oparg) | CO_FAST_HIDDEN
                    );
                }
                extended_arg = 0;
                ui += step;
            }
        }

        if ok and nlocalsplus != object_size(localsplusnames) {
            if _PyTuple_Resize(&mut localsplusnames, nlocalsplus) < 0
                or _PyBytes_Resize(&mut localspluskinds, nlocalsplus) < 0 {
                ok = False;
            }
        }

        con = ptr[u8]();
        if ok {
            con = ptr[u8](PyMem_Calloc(u64(1), u64(_PyCodeConstructor_SIZE)));
            if not con {
                PyErr_NoMemory();
                ok = False;
            }
        }
        if ok {
            m_set_obj(con, _PyCodeConstructor_FILENAME, filename);
            m_set_obj(con, _PyCodeConstructor_NAME, name);
            m_set_obj(con, _PyCodeConstructor_QUALNAME, qualname);
            m_set_int(con, _PyCodeConstructor_FLAGS, i64(flags));
            m_set_obj(con, _PyCodeConstructor_CODE, code);
            m_set_int(con, _PyCodeConstructor_FIRSTLINENO, i64(firstlineno));
            m_set_obj(con, _PyCodeConstructor_LINETABLE, linetable);
            m_set_obj(con, _PyCodeConstructor_CONSTS, consts);
            m_set_obj(con, _PyCodeConstructor_NAMES, names);
            m_set_obj(con, _PyCodeConstructor_LOCALSPLUSNAMES, localsplusnames);
            m_set_obj(con, _PyCodeConstructor_LOCALSPLUSKINDS, localspluskinds);
            m_set_int(con, _PyCodeConstructor_ARGCOUNT, i64(argcount));
            m_set_int(con, _PyCodeConstructor_POSONLYARGCOUNT, i64(posonlyargcount));
            m_set_int(con, _PyCodeConstructor_KWONLYARGCOUNT, i64(kwonlyargcount));
            m_set_int(con, _PyCodeConstructor_STACKSIZE, i64(stacksize));
            m_set_obj(con, _PyCodeConstructor_EXCEPTIONTABLE, exceptiontable);
            if _PyCode_Validate(con) < 0 {
                ok = False;
            }
        }
        if ok and i64(nlocals) != object_size(varnames) {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("code: co_nlocals != len(co_varnames)")
            );
            ok = False;
        }
        if ok {
            co = _PyCode_New(con);
        }
        if con {
            PyMem_Free(ptr(con));
        }
        object_xdecref(localsplusnames);
        object_xdecref(localspluskinds);
        return co;
    }  def PyUnstable_Code_New(
        argcount: i32,
        kwonlyargcount: i32,
        nlocals: i32,
        stacksize: i32,
        flags: i32,
        code: ptr[PyObject],
        consts: ptr[PyObject],
        names: ptr[PyObject],
        varnames: ptr[PyObject],
        freevars: ptr[PyObject],
        cellvars: ptr[PyObject],
        filename: ptr[PyObject],
        name: ptr[PyObject],
        qualname: ptr[PyObject],
        firstlineno: i32,
        linetable: ptr[PyObject],
        exceptiontable: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyUnstable_Code_NewWithPosOnlyArgs(
            argcount,
            i32(0),
            kwonlyargcount,
            nlocals,
            stacksize,
            flags,
            code,
            consts,
            names,
            varnames,
            freevars,
            cellvars,
            filename,
            name,
            qualname,
            firstlineno,
            linetable,
            exceptiontable
        );
    }  def PyCode_NewEmpty(
        filename: ptr[u8], funcname: ptr[u8], firstlineno: i32
    ) -> ptr[PyObject] {
        result: ptr[PyObject] = NULL;
        funcname_ob: ptr[PyObject] = NULL;
        filename_ob: ptr[PyObject] = NULL;
        code_ob: ptr[PyObject] = NULL;
        linetable_ob: ptr[PyObject] = NULL;

        nulltuple = PyTuple_New(0);
        if nulltuple {
            funcname_ob = PyUnicode_FromString(funcname);
        }
        if funcname_ob {
            filename_ob = PyUnicode_DecodeFSDefault(ptr(filename));
        }
        if filename_ob {
            code_ob = PyBytes_FromStringAndSize(ptr[u8](), 6);
            if code_ob {
                assert0 = bytes_data(code_ob);
                assert0.view(6)[0] = u8.wrap(i64(RESUME));
                assert0.view(6)[1] = u8.wrap(i64(RESUME_AT_FUNC_START));
                assert0.view(6)[2] = u8.wrap(i64(LOAD_COMMON_CONSTANT));
                assert0.view(6)[3] = u8.wrap(i64(CONSTANT_ASSERTIONERROR));
                assert0.view(6)[4] = u8.wrap(i64(RAISE_VARARGS));
                assert0.view(6)[5] = u8(1);
            }
        }
        if code_ob {
            linetable_ob = PyBytes_FromStringAndSize(ptr[u8](), 2);
            if linetable_ob {
                entry_bytes = bytes_data(linetable_ob);
                entry_bytes.view(2)[0] = u8.wrap(
                    (1 << 7) | (PY_CODE_LOCATION_INFO_NO_COLUMNS << 3) | (3 - 1)
                );
                entry_bytes.view(2)[1] = u8(0);
            }
        }
        if linetable_ob {
            con = ptr[u8](PyMem_Calloc(u64(1), u64(_PyCodeConstructor_SIZE)));
            if not con {
                PyErr_NoMemory();
            } else {
                emptystring = bytes_empty();
                m_set_obj(con, _PyCodeConstructor_FILENAME, filename_ob);
                m_set_obj(con, _PyCodeConstructor_NAME, funcname_ob);
                m_set_obj(con, _PyCodeConstructor_QUALNAME, funcname_ob);
                m_set_obj(con, _PyCodeConstructor_CODE, code_ob);
                m_set_int(con, _PyCodeConstructor_FIRSTLINENO, i64(firstlineno));
                m_set_obj(con, _PyCodeConstructor_LINETABLE, linetable_ob);
                m_set_obj(con, _PyCodeConstructor_CONSTS, nulltuple);
                m_set_obj(con, _PyCodeConstructor_NAMES, nulltuple);
                m_set_obj(con, _PyCodeConstructor_LOCALSPLUSNAMES, nulltuple);
                m_set_obj(con, _PyCodeConstructor_LOCALSPLUSKINDS, emptystring);
                m_set_obj(con, _PyCodeConstructor_EXCEPTIONTABLE, emptystring);
                m_set_int(con, _PyCodeConstructor_STACKSIZE, 1);
                result = _PyCode_New(con);
                PyMem_Free(ptr(con));
            }
        }

        object_xdecref(nulltuple);
        object_xdecref(funcname_ob);
        object_xdecref(filename_ob);
        object_xdecref(code_ob);
        object_xdecref(linetable_ob);
        return result;
    }  def PyCode_Addr2Line(co: ptr[PyObject], addrq: i32) -> i32 {
        if addrq < 0 {
            return i32(co_int(co, PyCodeObject_FIRSTLINENO));
        }
        data = co_ptr(co, PyCodeObject_MONITORING);
        if data {
            lines = m_ptr(data, _PyCoMonitoringData_LINES);
            if lines {
                return _Py_Instrumentation_GetLine(
                    co, lines, i32(i64(addrq) // CODEUNIT_SIZE)
                );
            }
        }
        return i32.wrap(line_scan(co, i64(addrq)));
    }  def _PyCode_SafeAddr2Line(co: ptr[PyObject], addrq: i32) -> i32 {
        if addrq < 0 {
            return i32(co_int(co, PyCodeObject_FIRSTLINENO));
        }
        data = co_ptr(co, PyCodeObject_MONITORING);
        if data and m_ptr(data, _PyCoMonitoringData_LINES) {
            return _Py_Instrumentation_GetLine(
                co,
                m_ptr(data, _PyCoMonitoringData_LINES),
                i32(i64(addrq) // CODEUNIT_SIZE)
            );
        }
        if not (i64(addrq) >= 0 and i64(addrq) < object_size(co) * CODEUNIT_SIZE) {
            return i32(-1);
        }
        return i32.wrap(line_scan(co, i64(addrq)));
    }  def _PyLineTable_InitAddressRange(
        linetable: ptr[u8], length: i64, firstlineno: i32, addr_range: ptr[u8]
    ) {
        m_set_ptr(addr_range, PyCodeAddressRange_LO_NEXT, linetable);
        m_set_ptr(addr_range, PyCodeAddressRange_LIMIT, linetable + length);
        m_set_int(addr_range, PyCodeAddressRange_AR_START, -1);
        m_set_int(addr_range, PyCodeAddressRange_AR_END, 0);
        m_set_int(addr_range, PyCodeAddressRange_COMPUTED_LINE, i64(firstlineno));
        m_set_int(addr_range, PyCodeAddressRange_AR_LINE, -1);
    }  def _PyCode_InitAddressRange(co: ptr[PyObject], bounds: ptr[u8]) -> i32 {
        linetable = co_obj(co, PyCodeObject_LINETABLE);
        _PyLineTable_InitAddressRange(
            bytes_data(linetable),
            object_size(linetable),
            i32(co_int(co, PyCodeObject_FIRSTLINENO)),
            bounds
        );
        return i32(m_int(bounds, PyCodeAddressRange_AR_LINE));
    }  def _PyCode_CheckLineNumber(lasti: i32, bounds: ptr[u8]) -> i32 {
        target = i64(lasti);
        while m_int(bounds, PyCodeAddressRange_AR_END) <= target {
            if _PyLineTable_NextAddressRange(bounds) == 0 {
                return i32(-1);
            }
        }
        while m_int(bounds, PyCodeAddressRange_AR_START) > target {
            if _PyLineTable_PreviousAddressRange(bounds) == 0 {
                return i32(-1);
            }
        }
        return i32(m_int(bounds, PyCodeAddressRange_AR_LINE));
    }  def PyCode_Addr2Location(
        co: ptr[PyObject],
        addrq: i32,
        start_line: ptr[i32],
        start_column: ptr[i32],
        end_line: ptr[i32],
        end_column: ptr[i32]
    ) -> i32 {
        if addrq < 0 {
            firstlineno = i32(co_int(co, PyCodeObject_FIRSTLINENO));
            end_line.view(1)[0] = firstlineno;
            start_line.view(1)[0] = firstlineno;
            end_column.view(1)[0] = i32(0);
            start_column.view(1)[0] = i32(0);
            return i32(1);
        }
        (line, column, endline, endcolumn) = location_scan(co, i64(addrq));
        end_line.view(1)[0] = i32.wrap(endline);
        start_column.view(1)[0] = i32.wrap(column);
        end_column.view(1)[0] = i32.wrap(endcolumn);
        start_line.view(1)[0] = i32.wrap(line);
        return i32(1);
    }  def _PyLineTable_PreviousAddressRange(addr_range: ptr[u8]) -> i32 {
        if m_int(addr_range, PyCodeAddressRange_AR_START) <= 0 {
            return i32(0);
        }
        retreat(addr_range);
        return i32(1);
    }  def _PyLineTable_NextAddressRange(addr_range: ptr[u8]) -> i32 {
        if at_end(addr_range) {
            return i32(0);
        }
        advance(addr_range);
        return i32(1);
    }  def PyUnstable_Code_GetExtra(
        code: ptr[PyObject], index: i64, extra: ptr[ptr]
    ) -> i32 {
        if not code_check(code) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        extra.view(1)[0] = ptr();
        if index < 0 {
            return i32(0);
        }
        co_extra = co_ptr(code, PyCodeObject_EXTRA);
        if co_extra and index < extra_size(co_extra) {
            extra.view(1)[0] = (extra_slots(co_extra) + index).view(1)[0];
        }
        return i32(0);
    }  def PyUnstable_Code_SetExtra(
        code: ptr[PyObject], index: i64, extra: ptr
    ) -> i32 {
        interp = current_interp();
        user_count = ptr[i64](interp + PyInterpreterState_CO_EXTRA_USER_COUNT).view(1)[
            0
        ];
        if not code_check(code) or index < 0 or index >= user_count {
            PyErr_BadInternalCall();
            return i32(-1);
        }

        result = i32(0);
        old_slot_value = ptr();
        old_co_extra = co_ptr(code, PyCodeObject_EXTRA);
        old_ce_size: i64 = 0;
        if old_co_extra {
            old_ce_size = extra_size(old_co_extra);
        }
        if index < old_ce_size {
            slot = extra_slots(old_co_extra) + index;
            old_slot_value = slot.view(1)[0];
            slot.view(1)[0] = extra;
        } else {
            result = code_extra_grow_gil(
                code, old_co_extra, old_ce_size, user_count, index, extra
            );
        }
        if int(old_slot_value) != 0 {
            free_extra = extra_freefunc(interp, index);
            if free_extra != 0 {
                call_free_extra(free_extra, old_slot_value);
            }
        }
        return result;
    }  def _PyCode_GetVarnames(co: ptr[PyObject]) -> ptr[PyObject] {
        if init_co_cached(co) != 0 {
            return NULL;
        }
        return get_cached_locals(
            co, _PyCoCached_VARNAMES, CO_FAST_LOCAL, co_int(co, PyCodeObject_NLOCALS)
        );
    }  def PyCode_GetVarnames(code: ptr[PyObject]) -> ptr[PyObject] {
        return _PyCode_GetVarnames(code);
    }  def _PyCode_GetCellvars(co: ptr[PyObject]) -> ptr[PyObject] {
        if init_co_cached(co) != 0 {
            return NULL;
        }
        return get_cached_locals(
            co, _PyCoCached_CELLVARS, CO_FAST_CELL, co_int(co, PyCodeObject_NCELLVARS)
        );
    }  def PyCode_GetCellvars(code: ptr[PyObject]) -> ptr[PyObject] {
        return _PyCode_GetCellvars(code);
    }  def _PyCode_GetFreevars(co: ptr[PyObject]) -> ptr[PyObject] {
        if init_co_cached(co) != 0 {
            return NULL;
        }
        return get_cached_locals(
            co, _PyCoCached_FREEVARS, CO_FAST_FREE, co_int(co, PyCodeObject_NFREEVARS)
        );
    }  def PyCode_GetFreevars(code: ptr[PyObject]) -> ptr[PyObject] {
        return _PyCode_GetFreevars(code);
    }  def _PyCode_GetVarCounts(co: ptr[PyObject], counts: ptr[u8]) {
        locals_total: i64 = 0;
        args_total: i64 = 0;
        numposonly: i64 = 0;
        numposorkw: i64 = 0;
        numkwonly: i64 = 0;
        varargs: i64 = 0;
        varkwargs: i64 = 0;
        numpure: i64 = 0;
        cells_total: i64 = 0;
        cells_numargs: i64 = 0;
        cells_numothers: i64 = 0;
        hidden_total: i64 = 0;
        hidden_numpure: i64 = 0;
        hidden_numcells: i64 = 0;
        numfree: i64 = 0;
        kinds = co_obj(co, PyCodeObject_LOCALSPLUSKINDS);
        for i in range(object_size(kinds)) {
            kind = kind_at(kinds, i);
            if (kind & CO_FAST_FREE) != 0 {
                numfree += 1;
            } else {
                locals_total += 1;
                if (kind & CO_FAST_ARG) != 0 {
                    args_total += 1;
                    if (kind & CO_FAST_ARG_VAR) != 0 {
                        if (kind & CO_FAST_ARG_POS) != 0 {
                            varargs = 1;
                        } else {
                            varkwargs = 1;
                        }
                    } elif (kind & CO_FAST_ARG_POS) != 0 {
                        if (kind & CO_FAST_ARG_KW) != 0 {
                            numposorkw += 1;
                        } else {
                            numposonly += 1;
                        }
                    } else {
                        numkwonly += 1;
                    }
                    if (kind & CO_FAST_CELL) != 0 {
                        cells_total += 1;
                        cells_numargs += 1;
                    }
                } elif (kind & CO_FAST_CELL) != 0 {
                    cells_total += 1;
                    cells_numothers += 1;
                    if (kind & CO_FAST_HIDDEN) != 0 {
                        hidden_total += 1;
                        hidden_numcells += 1;
                    }
                } else {
                    numpure += 1;
                    if (kind & CO_FAST_HIDDEN) != 0 {
                        hidden_total += 1;
                        hidden_numpure += 1;
                    }
                }
            }
        }

        numunbound = object_size(co_obj(co, PyCodeObject_NAMES));
        m_set_int(
            counts, _PyCode_var_counts_t_TOTAL, locals_total + numfree + numunbound
        );
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_TOTAL, locals_total);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_ARGS_TOTAL, args_total);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_ARGS_NUMPOSONLY, numposonly);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_ARGS_NUMPOSORKW, numposorkw);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_ARGS_NUMKWONLY, numkwonly);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_ARGS_VARARGS, varargs);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_ARGS_VARKWARGS, varkwargs);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_NUMPURE, numpure);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_CELLS_TOTAL, cells_total);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_CELLS_NUMARGS, cells_numargs);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_CELLS_NUMOTHERS, cells_numothers);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_HIDDEN_TOTAL, hidden_total);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_HIDDEN_NUMPURE, hidden_numpure);
        m_set_int(counts, _PyCode_var_counts_t_LOCALS_HIDDEN_NUMCELLS, hidden_numcells);
        m_set_int(counts, _PyCode_var_counts_t_NUMFREE, numfree);
        m_set_int(counts, _PyCode_var_counts_t_UNBOUND_TOTAL, numunbound);
        m_set_int(counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_TOTAL, 0);
        m_set_int(counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMGLOBAL, 0);
        m_set_int(counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMBUILTIN, 0);
        m_set_int(counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMUNKNOWN, 0);
        m_set_int(counts, _PyCode_var_counts_t_UNBOUND_NUMATTRS, 0);
        m_set_int(counts, _PyCode_var_counts_t_UNBOUND_NUMUNKNOWN, numunbound);
    }  def _PyCode_SetUnboundVarCounts(
        tstate: ptr,
        co: ptr[PyObject],
        counts: ptr[u8],
        globalnames_in: ptr[PyObject],
        attrnames_in: ptr[PyObject],
        globalsns: ptr[PyObject],
        builtinsns: ptr[PyObject]
    ) -> i32 {
        res = i32(-1);
        globalnames_owned: ptr[PyObject] = NULL;
        attrnames_owned: ptr[PyObject] = NULL;
        globalnames = globalnames_in;
        attrnames = attrnames_in;
        ok = True;

        if not globalnames {
            globalnames_owned = PySet_New(NULL);
            if not globalnames_owned {
                ok = False;
            }
            globalnames = globalnames_owned;
        } elif not set_check(globalnames) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("expected a set for \"globalnames\", got %R"),
                globalnames
            );
            ok = False;
        }
        if ok {
            if not attrnames {
                attrnames_owned = PySet_New(NULL);
                if not attrnames_owned {
                    ok = False;
                }
                attrnames = attrnames_owned;
            } elif not set_check(attrnames) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("expected a set for \"attrnames\", got %R"),
                    attrnames
                );
                ok = False;
            }
        }

        if ok {
            (
                status,
                total,
                globals_total,
                numglobal,
                numbuiltin,
                numunknown,
                numattrs,
                numdupes
            ) = identify_unbound_names(
                co, globalnames, attrnames, globalsns, builtinsns
            );
            if status >= 0 {
                totalunbound = m_int(counts, _PyCode_var_counts_t_UNBOUND_TOTAL)
                    + numdupes;
                m_set_int(counts, _PyCode_var_counts_t_UNBOUND_TOTAL, totalunbound);
                m_set_int(
                    counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_TOTAL, globals_total
                );
                m_set_int(
                    counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMGLOBAL, numglobal
                );
                m_set_int(
                    counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMBUILTIN, numbuiltin
                );
                m_set_int(
                    counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMUNKNOWN, numunknown
                );
                m_set_int(counts, _PyCode_var_counts_t_UNBOUND_NUMATTRS, numattrs);
                m_set_int(
                    counts,
                    _PyCode_var_counts_t_UNBOUND_NUMUNKNOWN,
                    totalunbound - total
                );
                m_set_int(
                    counts,
                    _PyCode_var_counts_t_TOTAL,
                    m_int(counts, _PyCode_var_counts_t_TOTAL) + numdupes
                );
                res = i32(0);
            }
        }

        object_xdecref(globalnames_owned);
        object_xdecref(attrnames_owned);
        return res;
    }  def _PyCode_CheckNoInternalState(
        co: ptr[PyObject], p_errmsg: ptr[ptr[u8]]
    ) -> i32 {
        errmsg = internal_state_error(co);
        if errmsg {
            if p_errmsg {
                p_errmsg.view(1)[0] = errmsg;
            }
            return i32(0);
        }
        return i32(1);
    }  def _PyCode_CheckNoExternalState(
        co: ptr[PyObject], counts: ptr[u8], p_errmsg: ptr[ptr[u8]]
    ) -> i32 {
        errmsg = external_state_error(counts);
        if errmsg {
            if p_errmsg {
                p_errmsg.view(1)[0] = errmsg;
            }
            return i32(0);
        }
        return i32(1);
    }  def _PyCode_VerifyStateless(
        tstate: ptr,
        co: ptr[PyObject],
        globalnames: ptr[PyObject],
        globalsns: ptr[PyObject],
        builtinsns: ptr[PyObject]
    ) -> i32 {
        counts = ptr[u8](PyMem_Calloc(u64(1), u64(_PyCode_var_counts_t_SIZE)));
        if not counts {
            PyErr_NoMemory();
            return i32(-1);
        }
        result = verify_stateless_with(
            tstate, co, globalnames, globalsns, builtinsns, counts
        );
        PyMem_Free(ptr(counts));
        return result;
    }  def _PyCode_CheckPureFunction(co: ptr[PyObject], p_errmsg: ptr[ptr[u8]]) -> i32 {
        errmsg = pure_function_error(co);
        if errmsg {
            if p_errmsg {
                p_errmsg.view(1)[0] = errmsg;
            }
            return i32(0);
        }
        return i32(1);
    }  def _PyCode_ReturnsOnlyNone(co: ptr[PyObject]) -> i32 {
        return code_returns_only_none(co);
    }  def _PyCode_GetCode(co: ptr[PyObject]) -> ptr[PyObject] {
        if init_co_cached(co) != 0 {
            return NULL;
        }
        slot = ptr[ptr[PyObject]](
            co_ptr(co, PyCodeObject_CO_CACHED) + _PyCoCached_CODE
        );
        code = slot.view(1)[0];
        if code {
            return object_new_ref(code);
        }
        code = PyBytes_FromStringAndSize(
            ptr[u8](code_units(co)), object_size(co) * CODEUNIT_SIZE
        );
        if code {
            deopt_code(co, ptr[u16](bytes_data(code)));
            slot.view(1)[0] = code;
        }
        return object_xnew_ref(code);
    }  def PyCode_GetCode(co: ptr[PyObject]) -> ptr[PyObject] {
        return _PyCode_GetCode(co);
    }  def _PyCode_ConstantKey(op: ptr[PyObject]) -> ptr[PyObject] {
        if op == Py_None
            or op == Py_Ellipsis
            or object_is_type(op, type_of(addressof(PyLong_Type)))
            or unicode_check_exact(op)
            or code_check(op) {
            return object_new_ref(op);
        }
        optype = ptr[PyObject](object_type(op));
        if object_is_type(op, type_of(addressof(PyBool_Type)))
            or object_is_type(op, type_of(addressof(PyBytes_Type))) {
            return PyTuple_Pack(2, optype, op);
        }
        if object_is_type(op, type_of(addressof(PyFloat_Type))) {
            d = ptr[PyFloatObject](op).view(1)[0].ob_fval;
            if d == 0.0 and copysign(1.0, d) < 0.0 {
                return PyTuple_Pack(3, optype, op, Py_None);
            }
            return PyTuple_Pack(2, optype, op);
        }
        if object_is_type(op, type_of(addressof(PyComplex_Type))) {
            real = ptr[PyComplexObject](op).view(1)[0].cval.real;
            imag = ptr[PyComplexObject](op).view(1)[0].cval.imag;
            real_negzero = real == 0.0 and copysign(1.0, real) < 0.0;
            imag_negzero = imag == 0.0 and copysign(1.0, imag) < 0.0;
            if real_negzero and imag_negzero {
                return PyTuple_Pack(
                    3, optype, op, ptr[PyObject](addressof(_Py_TrueStruct))
                );
            }
            if imag_negzero {
                return PyTuple_Pack(
                    3, optype, op, ptr[PyObject](addressof(_Py_FalseStruct))
                );
            }
            if real_negzero {
                return PyTuple_Pack(3, optype, op, Py_None);
            }
            return PyTuple_Pack(2, optype, op);
        }
        if tuple_check_exact(op) {
            n = object_size(op);
            items = PyTuple_New(n);
            if not items {
                return NULL;
            }
            for i in range(n) {
                item_key = _PyCode_ConstantKey(tuple_get_item(op, i));
                if not item_key {
                    object_decref(items);
                    return NULL;
                }
                tuple_set_item(items, i, item_key);
            }
            key = PyTuple_Pack(2, items, op);
            object_decref(items);
            return key;
        }
        if frozenset_check_exact(op) {
            pos: i64 = 0;
            entry_item: ptr[PyObject] = NULL;
            entry_hash: i64 = 0;
            members = PyTuple_New(ptr[PySetObject](op).view(1)[0].used);
            if not members {
                return NULL;
            }
            i: i64 = 0;
            while _PySet_NextEntry(op, &mut pos, &mut entry_item, &mut entry_hash)
                != 0 {
                member_key = _PyCode_ConstantKey(entry_item);
                if not member_key {
                    object_decref(members);
                    return NULL;
                }
                tuple_set_item(members, i, member_key);
                i += 1;
            }
            frozen = PyFrozenSet_New(members);
            object_decref(members);
            if not frozen {
                return NULL;
            }
            set_key = PyTuple_Pack(2, frozen, op);
            object_decref(frozen);
            return set_key;
        }
        if object_is_type(op, type_of(addressof(PySlice_Type))) {
            slice_obj = ptr[PySliceObject](op);
            slice_key: ptr[PyObject] = NULL;
            start_key = _PyCode_ConstantKey(slice_obj.view(1)[0].start);
            stop_key: ptr[PyObject] = NULL;
            step_key: ptr[PyObject] = NULL;
            if start_key {
                stop_key = _PyCode_ConstantKey(slice_obj.view(1)[0].stop);
            }
            if stop_key {
                step_key = _PyCode_ConstantKey(slice_obj.view(1)[0].step);
            }
            if step_key {
                fresh_slice = PySlice_New(start_key, stop_key, step_key);
                if fresh_slice {
                    slice_key = PyTuple_Pack(2, fresh_slice, op);
                    object_decref(fresh_slice);
                }
            }
            object_xdecref(start_key);
            object_xdecref(stop_key);
            object_xdecref(step_key);
            return slice_key;
        }
        obj_id = PyLong_FromVoidPtr(ptr(op));
        if not obj_id {
            return NULL;
        }
        id_key = PyTuple_Pack(2, obj_id, op);
        object_decref(obj_id);
        return id_key;
    }  def _PyCode_Init(interp: ptr) -> PyStatus {
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }  def _PyCode_Fini(interp: ptr) -> None {
        return;
    }
}


def lineiter_dealloc(self: ptr[PyObject]);

def lineiter_next(self: ptr[PyObject]) -> ptr[PyObject];

def new_linesiterator(code: ptr[PyObject]) -> ptr[PyObject];

def positionsiter_dealloc(self: ptr[PyObject]);

def positionsiter_next(self: ptr[PyObject]) -> ptr[PyObject];

def code_positionsiterator(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def code_new_impl(
    type: ptr[PyTypeObject],
    argcount: i32,
    posonlyargcount: i32,
    kwonlyargcount: i32,
    nlocals: i32,
    stacksize: i32,
    flags: i32,
    code: ptr[PyObject],
    consts: ptr[PyObject],
    names: ptr[PyObject],
    varnames: ptr[PyObject],
    filename: ptr[PyObject],
    name: ptr[PyObject],
    qualname: ptr[PyObject],
    firstlineno: i32,
    linetable: ptr[PyObject],
    exceptiontable: ptr[PyObject],
    freevars: ptr[PyObject],
    cellvars: ptr[PyObject]
) -> ptr[PyObject];

def code_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def code_dealloc(self: ptr[PyObject]);

def code_repr(self: ptr[PyObject]) -> ptr[PyObject];

def code_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject];

def code_hash(self: ptr[PyObject]) -> i64;

def code_getlnotab(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def code_getvarnames(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def code_getcellvars(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def code_getfreevars(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def code_getcodeadaptive(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def code_getcode(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def code_sizeof(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def code_linesiterator(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def code_branchesiterator(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def code_replace_impl(
    self: ptr[PyObject],
    co_argcount: i32,
    co_posonlyargcount: i32,
    co_kwonlyargcount: i32,
    co_nlocals: i32,
    co_stacksize: i32,
    co_flags_in: i32,
    co_firstlineno: i32,
    co_code_in: ptr[PyObject],
    co_consts: ptr[PyObject],
    co_names: ptr[PyObject],
    co_varnames_in: ptr[PyObject],
    co_freevars_in: ptr[PyObject],
    co_cellvars_in: ptr[PyObject],
    co_filename: ptr[PyObject],
    co_name: ptr[PyObject],
    co_qualname: ptr[PyObject],
    co_linetable: ptr[PyObject],
    co_exceptiontable: ptr[PyObject]
) -> ptr[PyObject];

def replace_object(
    value: ptr[PyObject], dflt: ptr[PyObject], kind: i64, argname: ptr[u8]
) -> tuple[bool, ptr[PyObject]];

def replace_int(value: ptr[PyObject], dflt: i64) -> tuple[bool, i32];

def code_replace_bound(args: BoundArguments) -> ptr[PyObject];

def code_replace(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def code__varname_from_oparg_impl(self: ptr[PyObject], oparg: i32) -> ptr[PyObject];

def code_varname_from_oparg_bound(args: BoundArguments) -> ptr[PyObject];

def code__varname_from_oparg(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

impl m_obj(base: ptr[u8], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](base + offset).view(1)[0];
}

impl m_set_obj(base: ptr[u8], offset: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](base + offset).view(1)[0] = value;
}

impl m_ptr(base: ptr[u8], offset: i64) -> ptr[u8] {
    return ptr[ptr[u8]](base + offset).view(1)[0];
}

impl m_set_ptr(base: ptr[u8], offset: i64, value: ptr[u8]) {
    ptr[ptr[u8]](base + offset).view(1)[0] = value;
}

impl m_int(base: ptr[u8], offset: i64) -> i64 {
    return i64(ptr[i32](base + offset).view(1)[0]);
}

impl m_set_int(base: ptr[u8], offset: i64, value: i64) {
    ptr[i32](base + offset).view(1)[0] = i32.wrap(value);
}

impl co_obj(co: ptr[PyObject], offset: i64) -> ptr[PyObject] {
    return m_obj(ptr[u8](co), offset);
}

impl co_set_obj(co: ptr[PyObject], offset: i64, value: ptr[PyObject]) {
    m_set_obj(ptr[u8](co), offset, value);
}

impl co_slot(co: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](co) + offset);
}

impl co_ptr(co: ptr[PyObject], offset: i64) -> ptr[u8] {
    return m_ptr(ptr[u8](co), offset);
}

impl co_set_ptr(co: ptr[PyObject], offset: i64, value: ptr[u8]) {
    m_set_ptr(ptr[u8](co), offset, value);
}

impl co_int(co: ptr[PyObject], offset: i64) -> i64 {
    return m_int(ptr[u8](co), offset);
}

impl co_set_int(co: ptr[PyObject], offset: i64, value: i64) {
    m_set_int(ptr[u8](co), offset, value);
}

impl co_flags(co: ptr[PyObject]) -> i32 {
    return ptr[i32](ptr[u8](co) + PyCodeObject_FLAGS).view(1)[0];
}

impl co_version(co: ptr[PyObject]) -> u32 {
    return ptr[u32](ptr[u8](co) + PyCodeObject_VERSION).view(1)[0];
}

impl code_units(co: ptr[PyObject]) -> ptr[u16] {
    return ptr[u16](ptr[u8](co) + PyCodeObject_CODE_ADAPTIVE);
}

impl opcode_caches(opcode: i64) -> i64 {
    return i64((addressof(code_opcode_caches) + opcode).view(1)[0]);
}

impl unit_opcode(unit: u16) -> i64 {
    return i64(unit) & 255;
}

impl unit_oparg(unit: u16) -> i64 {
    return (i64(unit) >> 8) & 255;
}

impl base_unit(co: ptr[PyObject], i: i64) -> u16 {
    return _Py_GetBaseCodeUnit(co, i32(i));
}

impl instruction_length(co: ptr[PyObject], i: i64) -> i64 {
    return i64(_PyInstruction_GetLength(co, i32(i)));
}

impl bytes_data(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + PyBytesObject_OB_SVAL;
}

impl kind_at(kinds: ptr[PyObject], i: i64) -> i64 {
    return i64((bytes_data(kinds) + i).view(1)[0]);
}

impl set_kind_at(kinds: ptr[PyObject], i: i64, kind: i64) {
    (bytes_data(kinds) + i).view(1)[0] = u8.wrap(kind);
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl type_of(tp: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[PyTypeObject](tp);
}

impl code_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyCode_Type));
}

impl bytes_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BYTES_SUBCLASS);
}

impl tuple_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl unicode_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, type_of(addressof(PyUnicode_Type)));
}

impl tuple_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, type_of(addressof(PyTuple_Type)));
}

impl frozenset_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, type_of(addressof(PyFrozenSet_Type)));
}

impl set_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, type_of(addressof(PySet_Type)));
}

impl bytes_empty -> ptr[PyObject] {
    return ptr[PyObject](int(addressof(_PyRuntime)) + _PyRuntimeState_BYTES_EMPTY);
}

impl code_debug_ranges -> i64 {
    return i64(ptr[i32](_Py_GetConfig() + PyConfig_CODE_DEBUG_RANGES).view(1)[0]);
}

impl unicode_is_ascii(op: ptr[PyObject]) -> bool {
    state = ptr[u32](ptr[u8](op) + PyASCIIObject_STATE).view(1)[0];
    return (state & u32(0x40)) != u32(0);
}

impl unicode_ascii_data(op: ptr[PyObject]) -> ptr[u8] {
    state = ptr[u32](ptr[u8](op) + PyASCIIObject_STATE).view(1)[0];
    if (state & u32(0x20)) != u32(0) {
        return ptr[u8](op) + PyASCIIObject_SIZE;
    }
    return m_ptr(ptr[u8](op), PyUnicodeObject_DATA);
}

impl unicode_length(op: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](op) + PyASCIIObject_LENGTH).view(1)[0];
}

impl ascii_alnum(c: i64) -> bool {
    return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122);
}

impl refcnt_is_immortal(op: ptr[PyObject]) -> bool {
    return (ptr[_object](op).view(1)[0].ob_refcnt_full & 0x80000000) != 0;
}

impl set_refcnt(op: ptr[PyObject], refcnt: i64) {
    if refcnt_is_immortal(op) {
        return;
    }
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    header.view(1)[0].ob_refcnt_full = (full & ~UINT_MASK) | (refcnt & UINT_MASK);
}

impl resurrect_start(op: ptr[PyObject]) {
    set_refcnt(op, 1);
}

impl resurrect_end(op: ptr[PyObject]) -> bool {
    set_refcnt(op, object_refcount(op) - 1);
    return object_refcount(op) != 0;
}

impl offset_value(value: i64) -> ptr[PyObject] {
    if value == -1 {
        return object_new_ref(Py_None);
    }
    return PyLong_FromLong(value);
}

impl pack3(a: ptr[PyObject], b: ptr[PyObject], c: ptr[PyObject]) -> ptr[PyObject] {
    result = NULL;
    if a and b and c {
        result = PyTuple_New(3);
    }
    if not result {
        object_xdecref(a);
        object_xdecref(b);
        object_xdecref(c);
        return NULL;
    }
    tuple_set_item(result, 0, a);
    tuple_set_item(result, 1, b);
    tuple_set_item(result, 2, c);
    return result;
}

impl pack4(
    a: ptr[PyObject], b: ptr[PyObject], c: ptr[PyObject], d: ptr[PyObject]
) -> ptr[PyObject] {
    result = NULL;
    if a and b and c and d {
        result = PyTuple_New(4);
    }
    if not result {
        object_xdecref(a);
        object_xdecref(b);
        object_xdecref(c);
        object_xdecref(d);
        return NULL;
    }
    tuple_set_item(result, 0, a);
    tuple_set_item(result, 1, b);
    tuple_set_item(result, 2, c);
    tuple_set_item(result, 3, d);
    return result;
}

impl arg_int(op: ptr[PyObject]) -> tuple[bool, i32] {
    value = PyLong_AsInt(op);
    if value == -1 and PyErr_Occurred() {
        return (False, value);
    }
    return (True, value);
}

impl code_event_name(event: i32) -> str {
    if event == PY_CODE_EVENT_CREATE {
        return "PY_CODE_EVENT_CREATE";
    }
    return "PY_CODE_EVENT_DESTROY";
}

impl active_code_watchers(interp: ptr[u8]) -> ptr[u8] {
    return interp + PyInterpreterState_ACTIVE_CODE_WATCHERS;
}

impl code_watcher_slot(interp: ptr[u8], i: i64) -> ptr[int] {
    return ptr[int](interp + PyInterpreterState_CODE_WATCHERS) + i;
}

impl notify_code_watchers(event: i32, co: ptr[PyObject]) {
    interp = current_interp();
    bits = active_code_watchers(interp).view(1)[0];
    i: i64 = 0;
    calls = ptr[CodeCall](__thread_local_block("jac_object_model_code_call_slot", 16));
    while bits != u8(0) {
        if (bits & u8(1)) != u8(0) {
            calls.view(1)[0].watcher = code_watcher_slot(interp, i).view(1)[0];
            if calls.view(1)[0].watcher(event, co) < 0 {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored in %s watcher callback for %R"),
                    code_event_name(event),
                    co
                );
            }
        }
        i += 1;
        bits = bits >> u8(1);
    }
}

impl validate_watcher_id(interp: ptr[u8], watcher_id: i32) -> i32 {
    if watcher_id < 0 or i64(watcher_id) >= CODE_MAX_WATCHERS {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("Invalid code watcher ID %d"), watcher_id
        );
        return i32(-1);
    }
    if code_watcher_slot(interp, i64(watcher_id)).view(1)[0] == 0 {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("No code watcher set for ID %d"), watcher_id
        );
        return i32(-1);
    }
    return i32(0);
}

impl should_intern_string(o: ptr[PyObject]) -> bool {
    if not unicode_is_ascii(o) {
        return False;
    }
    s = unicode_ascii_data(o);
    n = unicode_length(o);
    for i in range(n) {
        c = i64((s + i).view(1)[0]);
        if not ascii_alnum(c) and c != 95 {
            return False;
        }
    }
    return True;
}

impl intern_strings(tup: ptr[PyObject]) -> i32 {
    interp = current_interp();
    i = object_size(tup) - 1;
    while i >= 0 {
        v = tuple_get_item(tup, i);
        if not v or not unicode_check_exact(v) {
            PyErr_SetString(
                PyExc_SystemError, ptr[u8]("non-string found in code slot")
            );
            return i32(-1);
        }
        _PyUnicode_InternImmortal(interp, tuple_items(tup) + i);
        i -= 1;
    }
    return i32(0);
}

impl intern_constants(tup: ptr[PyObject]) -> tuple[i32, bool] {
    interp = current_interp();
    modified = False;
    i = object_size(tup) - 1;
    while i >= 0 {
        v = tuple_get_item(tup, i);
        if unicode_check_exact(v) {
            if should_intern_string(v) {
                slot = tuple_items(tup) + i;
                _PyUnicode_InternMortal(interp, slot);
                if slot.view(1)[0] != v {
                    modified = True;
                }
            }
        } elif tuple_check_exact(v) {
            (inner_status, inner_modified) = intern_constants(v);
            if inner_status < 0 {
                return (i32(-1), modified);
            }
        } elif frozenset_check_exact(v) {
            w = v;
            tmp = PySequence_Tuple(v);
            if not tmp {
                return (i32(-1), modified);
            }
            (tmp_status, tmp_modified) = intern_constants(tmp);
            if tmp_status < 0 {
                object_decref(tmp);
                return (i32(-1), modified);
            }
            if tmp_modified {
                fresh = PyFrozenSet_New(tmp);
                if not fresh {
                    object_decref(tmp);
                    return (i32(-1), modified);
                }
                tuple_set_item(tup, i, fresh);
                object_decref(w);
                modified = True;
            }
            object_decref(tmp);
        }
        i -= 1;
    }
    return (i32(0), modified);
}

impl validate_and_copy_tuple(tup: ptr[PyObject]) -> ptr[PyObject] {
    n = object_size(tup);
    newtuple = PyTuple_New(n);
    if not newtuple {
        return NULL;
    }
    for i in range(n) {
        item = tuple_get_item(tup, i);
        if unicode_check_exact(item) {
            object_incref(item);
        } elif not unicode_check(item) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("name tuples must contain only strings, not '%.500s'"),
                object_type(item).view(1)[0].tp_name
            );
            object_decref(newtuple);
            return NULL;
        } else {
            item = _PyUnicode_Copy(item);
            if not item {
                object_decref(newtuple);
                return NULL;
            }
        }
        tuple_set_item(newtuple, i, item);
    }
    return newtuple;
}

impl init_co_cached(co: ptr[PyObject]) -> i32 {
    if co_ptr(co, PyCodeObject_CO_CACHED) {
        return i32(0);
    }
    cached = ptr[u8](PyMem_Malloc(u64(_PyCoCached_SIZE)));
    if not cached {
        PyErr_NoMemory();
        return i32(-1);
    }
    m_set_obj(cached, _PyCoCached_CODE, NULL);
    m_set_obj(cached, _PyCoCached_CELLVARS, NULL);
    m_set_obj(cached, _PyCoCached_FREEVARS, NULL);
    m_set_obj(cached, _PyCoCached_VARNAMES, NULL);
    co_set_ptr(co, PyCodeObject_CO_CACHED, cached);
    return i32(0);
}

impl get_localsplus_counts(
    names: ptr[PyObject], kinds: ptr[PyObject]
) -> tuple[i64, i64, i64] {
    nlocals: i64 = 0;
    ncellvars: i64 = 0;
    nfreevars: i64 = 0;
    nlocalsplus = object_size(names);
    for i in range(nlocalsplus) {
        kind = kind_at(kinds, i);
        if (kind & CO_FAST_LOCAL) != 0 {
            nlocals += 1;
            if (kind & CO_FAST_CELL) != 0 {
                ncellvars += 1;
            }
        } elif (kind & CO_FAST_CELL) != 0 {
            ncellvars += 1;
        } elif (kind & CO_FAST_FREE) != 0 {
            nfreevars += 1;
        }
    }
    return (nlocals, ncellvars, nfreevars);
}

impl get_localsplus_names(co: ptr[PyObject], kind: i64, num: i64) -> ptr[PyObject] {
    names = PyTuple_New(num);
    if not names {
        return NULL;
    }
    index: i64 = 0;
    kinds = co_obj(co, PyCodeObject_LOCALSPLUSKINDS);
    plusnames = co_obj(co, PyCodeObject_LOCALSPLUSNAMES);
    for offset in range(co_int(co, PyCodeObject_NLOCALSPLUS)) {
        if (kind_at(kinds, offset) & kind) == 0 {
            continue;
        }
        tuple_set_item(names, index, object_new_ref(tuple_get_item(plusnames, offset)));
        index += 1;
    }
    return names;
}

impl init_code(co: ptr[PyObject], con: ptr[u8]) -> i32 {
    localsplusnames = m_obj(con, _PyCodeConstructor_LOCALSPLUSNAMES);
    localspluskinds = m_obj(con, _PyCodeConstructor_LOCALSPLUSKINDS);
    nlocalsplus = object_size(localsplusnames);
    (nlocals, ncellvars, nfreevars) = get_localsplus_counts(
        localsplusnames, localspluskinds
    );
    if m_int(con, _PyCodeConstructor_STACKSIZE) == 0 {
        m_set_int(con, _PyCodeConstructor_STACKSIZE, 1);
    }

    interp = current_interp();
    co_set_obj(
        co,
        PyCodeObject_FILENAME,
        object_new_ref(m_obj(con, _PyCodeConstructor_FILENAME))
    );
    co_set_obj(
        co, PyCodeObject_NAME, object_new_ref(m_obj(con, _PyCodeConstructor_NAME))
    );
    co_set_obj(
        co,
        PyCodeObject_QUALNAME,
        object_new_ref(m_obj(con, _PyCodeConstructor_QUALNAME))
    );
    _PyUnicode_InternMortal(interp, co_slot(co, PyCodeObject_FILENAME));
    _PyUnicode_InternMortal(interp, co_slot(co, PyCodeObject_NAME));
    _PyUnicode_InternMortal(interp, co_slot(co, PyCodeObject_QUALNAME));
    co_set_int(co, PyCodeObject_FLAGS, m_int(con, _PyCodeConstructor_FLAGS));

    co_set_int(
        co, PyCodeObject_FIRSTLINENO, m_int(con, _PyCodeConstructor_FIRSTLINENO)
    );
    co_set_obj(
        co,
        PyCodeObject_LINETABLE,
        object_new_ref(m_obj(con, _PyCodeConstructor_LINETABLE))
    );

    co_set_obj(
        co, PyCodeObject_CONSTS, object_new_ref(m_obj(con, _PyCodeConstructor_CONSTS))
    );
    co_set_obj(
        co, PyCodeObject_NAMES, object_new_ref(m_obj(con, _PyCodeConstructor_NAMES))
    );

    co_set_obj(co, PyCodeObject_LOCALSPLUSNAMES, object_new_ref(localsplusnames));
    co_set_obj(co, PyCodeObject_LOCALSPLUSKINDS, object_new_ref(localspluskinds));

    co_set_int(co, PyCodeObject_ARGCOUNT, m_int(con, _PyCodeConstructor_ARGCOUNT));
    co_set_int(
        co, PyCodeObject_POSONLYARGCOUNT, m_int(con, _PyCodeConstructor_POSONLYARGCOUNT)
    );
    co_set_int(
        co, PyCodeObject_KWONLYARGCOUNT, m_int(con, _PyCodeConstructor_KWONLYARGCOUNT)
    );

    stacksize = m_int(con, _PyCodeConstructor_STACKSIZE);
    co_set_int(co, PyCodeObject_STACKSIZE, stacksize);

    co_set_obj(
        co,
        PyCodeObject_EXCEPTIONTABLE,
        object_new_ref(m_obj(con, _PyCodeConstructor_EXCEPTIONTABLE))
    );

    co_set_int(co, PyCodeObject_NLOCALSPLUS, nlocalsplus);
    co_set_int(co, PyCodeObject_NLOCALS, nlocals);
    co_set_int(
        co, PyCodeObject_FRAMESIZE, nlocalsplus + stacksize + i64(FRAME_SPECIALS_SIZE)
    );
    co_set_int(co, PyCodeObject_NCELLVARS, ncellvars);
    co_set_int(co, PyCodeObject_NFREEVARS, nfreevars);
    next_version = ptr[u32](interp + PyInterpreterState_FUNC_STATE_NEXT_VERSION);
    version = next_version.view(1)[0];
    ptr[u32](ptr[u8](co) + PyCodeObject_VERSION).view(1)[0] = version;
    if version != u32(0) {
        next_version.view(1)[0] = wrapping_add(version, u32(1));
    }
    co_set_ptr(co, PyCodeObject_MONITORING, ptr[u8]());
    ptr[u64](ptr[u8](co) + PyCodeObject_INSTRUMENTATION_VERSION).view(1)[0] = u64(0);
    co_set_obj(co, PyCodeObject_WEAKREFLIST, NULL);
    co_set_ptr(co, PyCodeObject_EXTRA, ptr[u8]());
    co_set_ptr(co, PyCodeObject_CO_CACHED, ptr[u8]());
    co_set_ptr(co, PyCodeObject_EXECUTORS, ptr[u8]());

    code = m_obj(con, _PyCodeConstructor_CODE);
    memcpy(ptr(code_units(co)), ptr(bytes_data(code)), u64(object_size(code)));
    units = code_units(co);
    size = object_size(co);
    entry_point: i64 = 0;
    while entry_point < size
        and unit_opcode((units + entry_point).view(1)[0]) != i64(RESUME) {
        entry_point += 1;
    }
    co_set_int(co, PyCodeObject_FIRSTTRACEABLE, entry_point);
    _PyCode_Quicken(units, size, i32(1));
    notify_code_watchers(PY_CODE_EVENT_CREATE, co);
    return i32(0);
}

impl scan_varint(p: ptr[u8]) -> i64 {
    q = p;
    read = i64(q.view(1)[0]);
    val = read & 63;
    shift: i64 = 0;
    while (read & 64) != 0 {
        q = q + 1;
        read = i64(q.view(1)[0]);
        shift += 6;
        if shift < 32 {
            val = (val | ((read & 63) << shift)) & UINT_MASK;
        }
    }
    return val;
}

impl scan_signed_varint(p: ptr[u8]) -> i64 {
    uval = scan_varint(p);
    if (uval & 1) != 0 {
        return -(uval >> 1);
    }
    return uval >> 1;
}

impl get_line_delta(p: ptr[u8]) -> i64 {
    code = (i64(p.view(1)[0]) >> 3) & 15;
    if code == PY_CODE_LOCATION_INFO_NO_COLUMNS or code == PY_CODE_LOCATION_INFO_LONG {
        return scan_signed_varint(p + 1);
    }
    if code == PY_CODE_LOCATION_INFO_ONE_LINE1 {
        return 1;
    }
    if code == PY_CODE_LOCATION_INFO_ONE_LINE2 {
        return 2;
    }
    return 0;
}

impl is_no_line_marker(b: i64) -> bool {
    return (b >> 3) == NO_LINE_MARKER;
}

impl entry_code_delta(first: i64) -> i64 {
    return ((first & 7) + 1) * CODEUNIT_SIZE;
}

impl write_varint(p: ptr[u8], value: i64) -> i64 {
    val = value & UINT_MASK;
    written: i64 = 1;
    q = p;
    while val >= 64 {
        q.view(1)[0] = u8.wrap(64 | (val & 63));
        q = q + 1;
        val = val >> 6;
        written += 1;
    }
    q.view(1)[0] = u8.wrap(val);
    return written;
}

impl write_signed_varint(p: ptr[u8], val: i64) -> i64 {
    uval: i64 = 0;
    if val < 0 {
        uval = (((0 - val) << 1) | 1) & UINT_MASK;
    } else {
        uval = (val << 1) & UINT_MASK;
    }
    return write_varint(p, uval);
}

impl read_varint(p: ptr[u8]) -> tuple[i64, ptr[u8]] {
    read = i64(p.view(1)[0]);
    q = p + 1;
    val = read & 63;
    shift: i64 = 0;
    while (read & 64) != 0 {
        read = i64(q.view(1)[0]);
        q = q + 1;
        shift += 6;
        if shift < 32 {
            val = (val | ((read & 63) << shift)) & UINT_MASK;
        }
    }
    return (val, q);
}

impl read_signed_varint(p: ptr[u8]) -> tuple[i64, ptr[u8]] {
    (uval, q) = read_varint(p);
    if (uval & 1) != 0 {
        return (-(uval >> 1), q);
    }
    return (uval >> 1, q);
}

impl decode_location(
    p: ptr[u8], computed_line: i64
) -> tuple[ptr[u8], i64, i64, i64, i64, i64] {
    first = i64(p.view(1)[0]);
    q = p + 1;
    code = (first >> 3) & 15;
    line = computed_line;
    if code == PY_CODE_LOCATION_INFO_NONE {
        return (q, line, -1, -1, -1, -1);
    }
    if code == PY_CODE_LOCATION_INFO_LONG {
        (delta, q1) = read_signed_varint(q);
        line = line + delta;
        (end_delta, q2) = read_varint(q1);
        (column1, q3) = read_varint(q2);
        (endcolumn1, q4) = read_varint(q3);
        return (q4, line, line, line + end_delta, column1 - 1, endcolumn1 - 1);
    }
    if code == PY_CODE_LOCATION_INFO_NO_COLUMNS {
        (delta2, q5) = read_signed_varint(q);
        line = line + delta2;
        return (q5, line, line, line, -1, -1);
    }
    if code == PY_CODE_LOCATION_INFO_ONE_LINE0
        or code == PY_CODE_LOCATION_INFO_ONE_LINE1
        or code == PY_CODE_LOCATION_INFO_ONE_LINE2 {
        line = line + (code - 10);
        column2 = i64(q.view(1)[0]);
        endcolumn2 = i64((q + 1).view(1)[0]);
        return (q + 2, line, line, line, column2, endcolumn2);
    }
    second = i64(q.view(1)[0]);
    column3 = (code << 3) | (second >> 4);
    return (q + 1, line, line, line, column3, column3 + (second & 15));
}

impl r_lo(bounds: ptr[u8]) -> ptr[u8] {
    return m_ptr(bounds, PyCodeAddressRange_LO_NEXT);
}

impl r_limit(bounds: ptr[u8]) -> ptr[u8] {
    return m_ptr(bounds, PyCodeAddressRange_LIMIT);
}

impl at_end(bounds: ptr[u8]) -> bool {
    return int(r_lo(bounds)) >= int(r_limit(bounds));
}

impl previous_code_delta(ar_start: i64, lo_next: ptr[u8]) -> i64 {
    if ar_start == 0 {
        return 1;
    }
    p = ptr[u8](int(lo_next) - 1);
    while (i64(p.view(1)[0]) & 128) == 0 {
        p = ptr[u8](int(p) - 1);
    }
    return entry_code_delta(i64(p.view(1)[0]));
}

impl retreat(bounds: ptr[u8]) {
    lo = ptr[u8](int(r_lo(bounds)) - 1);
    while (i64(lo.view(1)[0]) & 128) == 0 {
        lo = ptr[u8](int(lo) - 1);
    }
    m_set_ptr(bounds, PyCodeAddressRange_LO_NEXT, lo);
    line = m_int(bounds, PyCodeAddressRange_COMPUTED_LINE) - get_line_delta(lo);
    m_set_int(bounds, PyCodeAddressRange_COMPUTED_LINE, line);
    ar_start = m_int(bounds, PyCodeAddressRange_AR_START);
    m_set_int(bounds, PyCodeAddressRange_AR_END, ar_start);
    m_set_int(
        bounds,
        PyCodeAddressRange_AR_START,
        ar_start - previous_code_delta(ar_start, lo)
    );
    if is_no_line_marker(i64(ptr[u8](int(lo) - 1).view(1)[0])) {
        m_set_int(bounds, PyCodeAddressRange_AR_LINE, -1);
    } else {
        m_set_int(bounds, PyCodeAddressRange_AR_LINE, line);
    }
}

impl advance(bounds: ptr[u8]) {
    lo = r_lo(bounds);
    first = i64(lo.view(1)[0]);
    line = m_int(bounds, PyCodeAddressRange_COMPUTED_LINE) + get_line_delta(lo);
    m_set_int(bounds, PyCodeAddressRange_COMPUTED_LINE, line);
    if is_no_line_marker(first) {
        m_set_int(bounds, PyCodeAddressRange_AR_LINE, -1);
    } else {
        m_set_int(bounds, PyCodeAddressRange_AR_LINE, line);
    }
    ar_end = m_int(bounds, PyCodeAddressRange_AR_END);
    m_set_int(bounds, PyCodeAddressRange_AR_START, ar_end);
    m_set_int(bounds, PyCodeAddressRange_AR_END, ar_end + entry_code_delta(first));
    limit = int(r_limit(bounds));
    q = lo + 1;
    while int(q) < limit and (i64(q.view(1)[0]) & 128) == 0 {
        q = q + 1;
    }
    m_set_ptr(bounds, PyCodeAddressRange_LO_NEXT, q);
}

impl advance_with_locations(bounds: ptr[u8]) -> tuple[i64, i64, i64] {
    lo = r_lo(bounds);
    first = i64(lo.view(1)[0]);
    ar_start = m_int(bounds, PyCodeAddressRange_AR_END);
    m_set_int(bounds, PyCodeAddressRange_AR_START, ar_start);
    m_set_int(bounds, PyCodeAddressRange_AR_END, ar_start + entry_code_delta(first));
    (q, line, ar_line, endline, column, endcolumn) = decode_location(
        lo, m_int(bounds, PyCodeAddressRange_COMPUTED_LINE)
    );
    m_set_ptr(bounds, PyCodeAddressRange_LO_NEXT, q);
    m_set_int(bounds, PyCodeAddressRange_COMPUTED_LINE, line);
    m_set_int(bounds, PyCodeAddressRange_AR_LINE, ar_line);
    return (endline, column, endcolumn);
}

impl line_scan(co: ptr[PyObject], lasti: i64) -> i64 {
    linetable = co_obj(co, PyCodeObject_LINETABLE);
    table = bytes_data(linetable);
    length = object_size(linetable);
    lo: i64 = 0;
    computed_line = co_int(co, PyCodeObject_FIRSTLINENO);
    ar_end: i64 = 0;
    ar_line: i64 = -1;
    while ar_end <= lasti {
        if lo >= length {
            return -1;
        }
        first = i64((table + lo).view(1)[0]);
        computed_line = computed_line + get_line_delta(table + lo);
        if is_no_line_marker(first) {
            ar_line = -1;
        } else {
            ar_line = computed_line;
        }
        ar_end = ar_end + entry_code_delta(first);
        lo += 1;
        while lo < length and (i64((table + lo).view(1)[0]) & 128) == 0 {
            lo += 1;
        }
    }
    return ar_line;
}

impl location_scan(co: ptr[PyObject], addrq: i64) -> tuple[i64, i64, i64, i64] {
    linetable = co_obj(co, PyCodeObject_LINETABLE);
    table = bytes_data(linetable);
    length = object_size(linetable);
    lo: i64 = 0;
    computed_line = co_int(co, PyCodeObject_FIRSTLINENO);
    ar_end: i64 = 0;
    entry_lo: i64 = -1;
    base_line = computed_line;
    while ar_end <= addrq and lo < length {
        entry_lo = lo;
        base_line = computed_line;
        first = i64((table + lo).view(1)[0]);
        computed_line = computed_line + get_line_delta(table + lo);
        ar_end = ar_end + entry_code_delta(first);
        lo += 1;
        while lo < length and (i64((table + lo).view(1)[0]) & 128) == 0 {
            lo += 1;
        }
    }
    if entry_lo < 0 {
        return (-1, -1, -1, -1);
    }
    (q, line, ar_line, endline, column, endcolumn) = decode_location(
        table + entry_lo, base_line
    );
    return (ar_line, column, endline, endcolumn);
}

impl emit_pair(
    buf: ptr[PyObject], offset: i64, a: i64, b: i64
) -> tuple[ptr[PyObject], i64] {
    out = buf;
    n = object_size(out);
    if offset + 2 >= n {
        if _PyBytes_Resize(&mut out, n * 2) < 0 {
            return (NULL, offset);
        }
    }
    lnotab = bytes_data(out) + offset;
    lnotab.view(1)[0] = u8.wrap(a);
    (lnotab + 1).view(1)[0] = u8.wrap(b);
    return (out, offset + 2);
}

impl emit_delta(
    buf: ptr[PyObject], bdelta_in: i64, ldelta_in: i64, offset_in: i64
) -> tuple[ptr[PyObject], i64] {
    out = buf;
    offset = offset_in;
    bdelta = bdelta_in;
    ldelta = ldelta_in;
    while bdelta > 255 {
        (out, offset) = emit_pair(out, offset, 255, 0);
        if not out {
            return (NULL, offset);
        }
        bdelta -= 255;
    }
    while ldelta > 127 {
        (out, offset) = emit_pair(out, offset, bdelta, 127);
        if not out {
            return (NULL, offset);
        }
        bdelta = 0;
        ldelta -= 127;
    }
    while ldelta < -128 {
        (out, offset) = emit_pair(out, offset, bdelta, -128);
        if not out {
            return (NULL, offset);
        }
        bdelta = 0;
        ldelta += 128;
    }
    return emit_pair(out, offset, bdelta, ldelta);
}

impl decode_linetable(code: ptr[PyObject]) -> ptr[PyObject] {
    linetable = co_obj(code, PyCodeObject_LINETABLE);
    table = bytes_data(linetable);
    length = object_size(linetable);
    table_offset: i64 = 0;
    code_offset: i64 = 0;
    line = co_int(code, PyCodeObject_FIRSTLINENO);
    out = PyBytes_FromStringAndSize(ptr[u8](), 64);
    if not out {
        return NULL;
    }
    lo: i64 = 0;
    computed_line = line;
    ar_end: i64 = 0;
    while lo < length {
        first = i64((table + lo).view(1)[0]);
        computed_line = computed_line + get_line_delta(table + lo);
        ar_start = ar_end;
        ar_end = ar_end + entry_code_delta(first);
        lo += 1;
        while lo < length and (i64((table + lo).view(1)[0]) & 128) == 0 {
            lo += 1;
        }
        if computed_line != line {
            (out, table_offset) = emit_delta(
                out, ar_start - code_offset, computed_line - line, table_offset
            );
            if not out {
                return NULL;
            }
            code_offset = ar_start;
            line = computed_line;
        }
    }
    _PyBytes_Resize(&mut out, table_offset);
    return out;
}

impl remove_column_info(locations: ptr[PyObject]) -> ptr[PyObject] {
    offset: i64 = 0;
    data = bytes_data(locations);
    n = object_size(locations);
    res = PyBytes_FromStringAndSize(ptr[u8](), 32);
    if not res {
        PyErr_NoMemory();
        return NULL;
    }
    write_offset: i64 = 0;
    while offset < n {
        if write_offset + 16 >= object_size(res) {
            if _PyBytes_Resize(&mut res, object_size(res) * 2) < 0 {
                return NULL;
            }
        }
        output = bytes_data(res) + write_offset;
        first = i64((data + offset).view(1)[0]);
        code = (first >> 3) & 15;
        if code == PY_CODE_LOCATION_INFO_NONE {
            output.view(1)[0] = u8.wrap(first);
            write_offset += 1;
        } else {
            blength = (first & 7) + 1;
            output.view(1)[0] = u8.wrap(
                128 | (PY_CODE_LOCATION_INFO_NO_COLUMNS << 3) | (blength - 1)
            );
            write_offset += 1;
            ldelta = get_line_delta(data + offset);
            write_offset += write_signed_varint(bytes_data(res) + write_offset, ldelta);
        }
        offset += 1;
        while offset < n and (i64((data + offset).view(1)[0]) & 128) == 0 {
            offset += 1;
        }
    }
    if _PyBytes_Resize(&mut res, write_offset) != 0 {
        return NULL;
    }
    return res;
}

impl intern_code_constants(con: ptr[u8]) -> i32 {
    if intern_strings(m_obj(con, _PyCodeConstructor_NAMES)) < 0 {
        return i32(-1);
    }
    (consts_status, consts_modified) = intern_constants(
        m_obj(con, _PyCodeConstructor_CONSTS)
    );
    if consts_status < 0 {
        return i32(-1);
    }
    if intern_strings(m_obj(con, _PyCodeConstructor_LOCALSPLUSNAMES)) < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl code_extra_size(n: i64) -> i64 {
    return _PyCodeObjectExtra_SIZE + (n - 1) * 8;
}

impl extra_slots(co_extra: ptr[u8]) -> ptr[ptr] {
    return ptr[ptr](co_extra + _PyCodeObjectExtra_CE_EXTRAS);
}

impl extra_size(co_extra: ptr[u8]) -> i64 {
    return ptr[i64](co_extra + _PyCodeObjectExtra_CE_SIZE).view(1)[0];
}

impl extra_freefunc(interp: ptr[u8], index: i64) -> int {
    return (ptr[int](interp + PyInterpreterState_CO_EXTRA_FREEFUNCS) + index).view(1)[
        0
    ];
}

impl call_free_extra(free_extra: int, value: ptr) {
    calls = ptr[CodeCall](__thread_local_block("jac_object_model_code_call_slot", 16));
    calls.view(1)[0].free = free_extra;
    calls.view(1)[0].free(value);
}

impl code_extra_grow_gil(
    co: ptr[PyObject],
    old_co_extra: ptr[u8],
    old_ce_size: i64,
    new_ce_size: i64,
    index: i64,
    extra: ptr
) -> i32 {
    new_co_extra = ptr[u8](
        PyMem_Realloc(ptr(old_co_extra), u64(code_extra_size(new_ce_size)))
    );
    if not new_co_extra {
        PyErr_NoMemory();
        return i32(-1);
    }
    slots = extra_slots(new_co_extra);
    for i in range(old_ce_size, new_ce_size) {
        (slots + i).view(1)[0] = ptr();
    }
    ptr[i64](new_co_extra + _PyCodeObjectExtra_CE_SIZE).view(1)[0] = new_ce_size;
    (slots + index).view(1)[0] = extra;
    co_set_ptr(co, PyCodeObject_EXTRA, new_co_extra);
    return i32(0);
}

impl get_cached_locals(
    co: ptr[PyObject], cached_field: i64, kind: i64, num: i64
) -> ptr[PyObject] {
    slot = ptr[ptr[PyObject]](co_ptr(co, PyCodeObject_CO_CACHED) + cached_field);
    varnames = slot.view(1)[0];
    if varnames {
        return object_new_ref(varnames);
    }
    varnames = get_localsplus_names(co, kind, num);
    if varnames {
        slot.view(1)[0] = varnames;
    }
    return object_xnew_ref(varnames);
}

impl identify_unbound_names(
    co: ptr[PyObject],
    globalnames: ptr[PyObject],
    attrnames: ptr[PyObject],
    globalsns: ptr[PyObject],
    builtinsns: ptr[PyObject]
) -> tuple[i32, i64, i64, i64, i64, i64, i64, i64] {
    total: i64 = 0;
    globals_total: i64 = 0;
    numglobal: i64 = 0;
    numbuiltin: i64 = 0;
    numunknown: i64 = 0;
    numattrs: i64 = 0;
    numdupes: i64 = 0;
    names = co_obj(co, PyCodeObject_NAMES);
    n = object_size(co);
    i: i64 = 0;
    while i < n {
        inst = base_unit(co, i);
        i += instruction_length(co, i);
        opcode = unit_opcode(inst);
        if opcode == i64(LOAD_ATTR) {
            name = tuple_get_item(names, unit_oparg(inst) >> 1);
            if PySet_Contains(attrnames, name) != 0 {
                if PyErr_Occurred() {
                    return (i32(-1), 0, 0, 0, 0, 0, 0, 0);
                }
                continue;
            }
            total += 1;
            numattrs += 1;
            if PySet_Add(attrnames, name) < 0 {
                return (i32(-1), 0, 0, 0, 0, 0, 0, 0);
            }
            if PySet_Contains(globalnames, name) != 0 {
                if PyErr_Occurred() {
                    return (i32(-1), 0, 0, 0, 0, 0, 0, 0);
                }
                numdupes += 1;
            }
        } elif opcode == i64(LOAD_GLOBAL) {
            gname = tuple_get_item(names, unit_oparg(inst) >> 1);
            if PySet_Contains(globalnames, gname) != 0 {
                if PyErr_Occurred() {
                    return (i32(-1), 0, 0, 0, 0, 0, 0, 0);
                }
                continue;
            }
            total += 1;
            globals_total += 1;
            if globalsns and PyDict_Contains(globalsns, gname) != 0 {
                if PyErr_Occurred() {
                    return (i32(-1), 0, 0, 0, 0, 0, 0, 0);
                }
                numglobal += 1;
            } elif builtinsns and PyDict_Contains(builtinsns, gname) != 0 {
                if PyErr_Occurred() {
                    return (i32(-1), 0, 0, 0, 0, 0, 0, 0);
                }
                numbuiltin += 1;
            } else {
                numunknown += 1;
            }
            if PySet_Add(globalnames, gname) < 0 {
                return (i32(-1), 0, 0, 0, 0, 0, 0, 0);
            }
            if PySet_Contains(attrnames, gname) != 0 {
                if PyErr_Occurred() {
                    return (i32(-1), 0, 0, 0, 0, 0, 0, 0);
                }
                numdupes += 1;
            }
        }
    }
    return (
        i32(0),
        total,
        globals_total,
        numglobal,
        numbuiltin,
        numunknown,
        numattrs,
        numdupes
    );
}

impl internal_state_error(co: ptr[PyObject]) -> ptr[u8] {
    if co_ptr(co, PyCodeObject_EXTRA) {
        return ptr[u8]("only basic code objects are supported");
    }
    return ptr[u8]();
}

impl external_state_error(counts: ptr[u8]) -> ptr[u8] {
    if m_int(counts, _PyCode_var_counts_t_NUMFREE) > 0 {
        return ptr[u8]("closures not supported");
    }
    if m_int(counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMGLOBAL) > 0 {
        return ptr[u8]("globals not supported");
    }
    if m_int(counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMBUILTIN) > 0
        and m_int(counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMUNKNOWN) > 0 {
        return ptr[u8]("globals not supported");
    }
    return ptr[u8]();
}

impl pure_function_error(co: ptr[PyObject]) -> ptr[u8] {
    flags = co_flags(co);
    if (flags & CO_GENERATOR) != 0 {
        return ptr[u8]("generators not supported");
    }
    if (flags & CO_COROUTINE) != 0 {
        return ptr[u8]("coroutines not supported");
    }
    if (flags & CO_ITERABLE_COROUTINE) != 0 {
        return ptr[u8]("coroutines not supported");
    }
    if (flags & CO_ASYNC_GENERATOR) != 0 {
        return ptr[u8]("generators not supported");
    }
    return ptr[u8]();
}

impl verify_stateless_with(
    tstate: ptr,
    co: ptr[PyObject],
    globalnames: ptr[PyObject],
    globalsns: ptr[PyObject],
    builtinsns: ptr[PyObject],
    counts: ptr[u8]
) -> i32 {
    _PyCode_GetVarCounts(co, counts);
    if _PyCode_SetUnboundVarCounts(
        tstate, co, counts, globalnames, NULL, globalsns, builtinsns
    )
        < 0 {
        return i32(-1);
    }
    errmsg = internal_state_error(co);
    if errmsg {
        PyErr_Format(PyExc_ValueError, ptr[u8]("%s"), errmsg);
        return i32(-1);
    }
    if builtinsns {
        m_set_int(
            counts,
            _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMBUILTIN,
            m_int(counts, _PyCode_var_counts_t_UNBOUND_GLOBALS_NUMBUILTIN) + 1
        );
    }
    external = external_state_error(counts);
    if external {
        PyErr_Format(PyExc_ValueError, ptr[u8]("%s"), external);
        return i32(-1);
    }
    return i32(0);
}

impl code_returns_only_none(co: ptr[PyObject]) -> i32 {
    if pure_function_error(co) {
        return i32(0);
    }
    n = object_size(co);
    final_opcode = unit_opcode(base_unit(co, n - 1));
    consts = co_obj(co, PyCodeObject_CONSTS);
    nconsts = PyTuple_Size(consts);
    none_index: i64 = 0;
    while none_index < nconsts {
        if tuple_get_item(consts, none_index) == Py_None {
            break;
        }
        none_index += 1;
    }
    i: i64 = 0;
    if none_index == nconsts {
        if final_opcode == i64(RETURN_VALUE) {
            return i32(0);
        }
        while i < n {
            inst = base_unit(co, i);
            if unit_opcode(inst) == i64(RETURN_VALUE) {
                return i32(0);
            }
            i += instruction_length(co, i);
        }
    } else {
        while i < n {
            unit = base_unit(co, i);
            step = instruction_length(co, i);
            if unit_opcode(unit) == i64(RETURN_VALUE) {
                prev = base_unit(co, i - 1);
                if unit_opcode(prev) == i64(LOAD_CONST)
                    and unit_oparg(prev) == none_index {
                    i += step;
                    continue;
                }
                return i32(0);
            }
            i += step;
        }
    }
    return i32(1);
}

impl deopt_code(code: ptr[PyObject], instructions: ptr[u16]) {
    n = object_size(code);
    i: i64 = 0;
    while i < n {
        inst = base_unit(code, i);
        caches = opcode_caches(unit_opcode(inst));
        (instructions + i).view(1)[0] = inst;
        for j in range(1, caches + 1) {
            (instructions + i + j).view(1)[0] = u16(0);
        }
        i += caches + 1;
    }
}

impl free_monitoring_field(data: ptr[u8], offset: i64) {
    field = m_ptr(data, offset);
    if field {
        PyMem_Free(ptr(field));
    }
}

impl free_monitoring_data(data: ptr[u8]) {
    if not data {
        return;
    }
    free_monitoring_field(data, _PyCoMonitoringData_TOOLS);
    free_monitoring_field(data, _PyCoMonitoringData_LINES);
    free_monitoring_field(data, _PyCoMonitoringData_LINE_TOOLS);
    free_monitoring_field(data, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES);
    free_monitoring_field(data, _PyCoMonitoringData_PER_INSTRUCTION_TOOLS);
    PyMem_Free(ptr(data));
}

impl code_equal(co: ptr[PyObject], cp: ptr[PyObject]) -> i32 {
    eq = PyObject_RichCompareBool(
        co_obj(co, PyCodeObject_NAME), co_obj(cp, PyCodeObject_NAME), Py_EQ
    );
    if eq == 0 {
        return i32(0);
    }
    if co_int(co, PyCodeObject_ARGCOUNT) != co_int(cp, PyCodeObject_ARGCOUNT)
        or co_int(co, PyCodeObject_POSONLYARGCOUNT)
            != co_int(cp, PyCodeObject_POSONLYARGCOUNT)
        or co_int(co, PyCodeObject_KWONLYARGCOUNT)
            != co_int(cp, PyCodeObject_KWONLYARGCOUNT)
        or co_int(co, PyCodeObject_FLAGS) != co_int(cp, PyCodeObject_FLAGS)
        or co_int(co, PyCodeObject_FIRSTLINENO)
            != co_int(cp, PyCodeObject_FIRSTLINENO) {
        return i32(0);
    }
    n = object_size(co);
    if n != object_size(cp) {
        return i32(0);
    }
    i: i64 = 0;
    while i < n {
        co_instr = base_unit(co, i);
        cp_instr = base_unit(cp, i);
        if co_instr != cp_instr {
            return i32(0);
        }
        i += opcode_caches(unit_opcode(co_instr)) + 1;
    }

    consts1 = _PyCode_ConstantKey(co_obj(co, PyCodeObject_CONSTS));
    if not consts1 {
        return i32(-1);
    }
    consts2 = _PyCode_ConstantKey(co_obj(cp, PyCodeObject_CONSTS));
    if not consts2 {
        object_decref(consts1);
        return i32(-1);
    }
    eq = PyObject_RichCompareBool(consts1, consts2, Py_EQ);
    object_decref(consts1);
    object_decref(consts2);
    if eq <= 0 {
        return eq;
    }
    eq = PyObject_RichCompareBool(
        co_obj(co, PyCodeObject_NAMES), co_obj(cp, PyCodeObject_NAMES), Py_EQ
    );
    if eq <= 0 {
        return eq;
    }
    eq = PyObject_RichCompareBool(
        co_obj(co, PyCodeObject_LOCALSPLUSNAMES),
        co_obj(cp, PyCodeObject_LOCALSPLUSNAMES),
        Py_EQ
    );
    if eq <= 0 {
        return eq;
    }
    eq = PyObject_RichCompareBool(
        co_obj(co, PyCodeObject_LINETABLE), co_obj(cp, PyCodeObject_LINETABLE), Py_EQ
    );
    if eq <= 0 {
        return eq;
    }
    eq = PyObject_RichCompareBool(
        co_obj(co, PyCodeObject_EXCEPTIONTABLE),
        co_obj(cp, PyCodeObject_EXCEPTIONTABLE),
        Py_EQ
    );
    if eq <= 0 {
        return eq;
    }
    return i32(1);
}

impl scramble(uhash: u64, value: u64) -> u64 {
    return wrapping_mul(uhash ^ value, PyHASH_MULTIPLIER);
}

impl scramble_int(uhash: u64, value: i64) -> u64 {
    return scramble(uhash, u64.wrap(value));
}


impl lineiter_dealloc(self: ptr[PyObject]) {
    object_decref(m_obj(ptr[u8](self), lineiterator_LI_CODE));
    object_type(self).view(1)[0].tp_free(ptr(self));
}

impl lineiter_next(self: ptr[PyObject]) -> ptr[PyObject] {
    bounds = ptr[u8](self) + lineiterator_LI_LINE;
    if _PyLineTable_NextAddressRange(bounds) == 0 {
        return NULL;
    }
    start = m_int(bounds, PyCodeAddressRange_AR_START);
    line = m_int(bounds, PyCodeAddressRange_AR_LINE);
    while _PyLineTable_NextAddressRange(bounds) != 0 {
        if m_int(bounds, PyCodeAddressRange_AR_LINE) != line {
            _PyLineTable_PreviousAddressRange(bounds);
            break;
        }
    }
    return pack3(
        PyLong_FromLong(start),
        PyLong_FromLong(m_int(bounds, PyCodeAddressRange_AR_END)),
        offset_value(line)
    );
}

impl new_linesiterator(code: ptr[PyObject]) -> ptr[PyObject] {
    li = PyType_GenericAlloc(ptr[PyObject](addressof(_PyLineIterator)), 0);
    if not li {
        return NULL;
    }
    m_set_obj(ptr[u8](li), lineiterator_LI_CODE, object_new_ref(code));
    _PyCode_InitAddressRange(code, ptr[u8](li) + lineiterator_LI_LINE);
    return li;
}

impl positionsiter_dealloc(self: ptr[PyObject]) {
    object_decref(m_obj(ptr[u8](self), positionsiterator_PI_CODE));
    object_type(self).view(1)[0].tp_free(ptr(self));
}

impl positionsiter_next(self: ptr[PyObject]) -> ptr[PyObject] {
    pi = ptr[u8](self);
    pi_range = pi + positionsiterator_PI_RANGE;
    if m_int(pi, positionsiterator_PI_OFFSET)
        >= m_int(pi_range, PyCodeAddressRange_AR_END) {
        if at_end(pi_range) {
            return NULL;
        }
        (endline, column, endcolumn) = advance_with_locations(pi_range);
        m_set_int(pi, positionsiterator_PI_ENDLINE, endline);
        m_set_int(pi, positionsiterator_PI_COLUMN, column);
        m_set_int(pi, positionsiterator_PI_ENDCOLUMN, endcolumn);
    }
    m_set_int(
        pi,
        positionsiterator_PI_OFFSET,
        m_int(pi, positionsiterator_PI_OFFSET) + CODEUNIT_SIZE
    );
    return pack4(
        offset_value(m_int(pi_range, PyCodeAddressRange_AR_LINE)),
        offset_value(m_int(pi, positionsiterator_PI_ENDLINE)),
        offset_value(m_int(pi, positionsiterator_PI_COLUMN)),
        offset_value(m_int(pi, positionsiterator_PI_ENDCOLUMN))
    );
}

impl code_positionsiterator(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    pi = PyType_GenericAlloc(ptr[PyObject](addressof(_PyPositionsIterator)), 0);
    if not pi {
        return NULL;
    }
    base = ptr[u8](pi);
    m_set_obj(base, positionsiterator_PI_CODE, object_new_ref(self));
    pi_range = base + positionsiterator_PI_RANGE;
    _PyCode_InitAddressRange(self, pi_range);
    m_set_int(
        base, positionsiterator_PI_OFFSET, m_int(pi_range, PyCodeAddressRange_AR_END)
    );
    return pi;
}

impl code_new_impl(
    type: ptr[PyTypeObject],
    argcount: i32,
    posonlyargcount: i32,
    kwonlyargcount: i32,
    nlocals: i32,
    stacksize: i32,
    flags: i32,
    code: ptr[PyObject],
    consts: ptr[PyObject],
    names: ptr[PyObject],
    varnames: ptr[PyObject],
    filename: ptr[PyObject],
    name: ptr[PyObject],
    qualname: ptr[PyObject],
    firstlineno: i32,
    linetable: ptr[PyObject],
    exceptiontable: ptr[PyObject],
    freevars: ptr[PyObject],
    cellvars: ptr[PyObject]
) -> ptr[PyObject] {
    co: ptr[PyObject] = NULL;
    ournames: ptr[PyObject] = NULL;
    ourvarnames: ptr[PyObject] = NULL;
    ourfreevars: ptr[PyObject] = NULL;
    ourcellvars: ptr[PyObject] = NULL;
    ok = True;

    if PySys_Audit(
        "code.__new__",
        "OOOiiiiii",
        code,
        filename,
        name,
        argcount,
        posonlyargcount,
        kwonlyargcount,
        nlocals,
        stacksize,
        flags
    )
        < 0 {
        ok = False;
    }
    if ok and argcount < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("code: argcount must not be negative")
        );
        ok = False;
    }
    if ok and posonlyargcount < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("code: posonlyargcount must not be negative")
        );
        ok = False;
    }
    if ok and kwonlyargcount < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("code: kwonlyargcount must not be negative")
        );
        ok = False;
    }
    if ok and nlocals < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("code: nlocals must not be negative")
        );
        ok = False;
    }
    if ok {
        ournames = validate_and_copy_tuple(names);
        if not ournames {
            ok = False;
        }
    }
    if ok {
        ourvarnames = validate_and_copy_tuple(varnames);
        if not ourvarnames {
            ok = False;
        }
    }
    if ok {
        if freevars {
            ourfreevars = validate_and_copy_tuple(freevars);
        } else {
            ourfreevars = PyTuple_New(0);
        }
        if not ourfreevars {
            ok = False;
        }
    }
    if ok {
        if cellvars {
            ourcellvars = validate_and_copy_tuple(cellvars);
        } else {
            ourcellvars = PyTuple_New(0);
        }
        if not ourcellvars {
            ok = False;
        }
    }
    if ok {
        co = PyUnstable_Code_NewWithPosOnlyArgs(
            argcount,
            posonlyargcount,
            kwonlyargcount,
            nlocals,
            stacksize,
            flags,
            code,
            consts,
            ournames,
            ourvarnames,
            ourfreevars,
            ourcellvars,
            filename,
            name,
            qualname,
            firstlineno,
            linetable,
            exceptiontable
        );
    }
    object_xdecref(ournames);
    object_xdecref(ourvarnames);
    object_xdecref(ourfreevars);
    object_xdecref(ourcellvars);
    return co;
}

impl code_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    base_tp = addressof(PyCode_Type);
    if (
        type == base_tp
        or int(type.view(1)[0].tp_init) == int(base_tp.view(1)[0].tp_init)
    )
        and kwargs
        and _PyArg_NoKeywords(ptr[u8]("code"), kwargs) == 0 {
        return NULL;
    }
    nargs = object_size(args);
    if (nargs < 16 or nargs > 18)
        and _PyArg_CheckPositional(ptr[u8]("code"), nargs, 16, 18) == 0 {
        return NULL;
    }
    (ok0, argcount) = arg_int(tuple_get_item(args, 0));
    if not ok0 {
        return NULL;
    }
    (ok1, posonlyargcount) = arg_int(tuple_get_item(args, 1));
    if not ok1 {
        return NULL;
    }
    (ok2, kwonlyargcount) = arg_int(tuple_get_item(args, 2));
    if not ok2 {
        return NULL;
    }
    (ok3, nlocals) = arg_int(tuple_get_item(args, 3));
    if not ok3 {
        return NULL;
    }
    (ok4, stacksize) = arg_int(tuple_get_item(args, 4));
    if not ok4 {
        return NULL;
    }
    (ok5, flags) = arg_int(tuple_get_item(args, 5));
    if not ok5 {
        return NULL;
    }
    code = tuple_get_item(args, 6);
    if not bytes_check(code) {
        _PyArg_BadArgument(
            ptr[u8]("code"), ptr[u8]("argument 7"), ptr[u8]("bytes"), code
        );
        return NULL;
    }
    consts = tuple_get_item(args, 7);
    if not tuple_check(consts) {
        _PyArg_BadArgument(
            ptr[u8]("code"), ptr[u8]("argument 8"), ptr[u8]("tuple"), consts
        );
        return NULL;
    }
    names = tuple_get_item(args, 8);
    if not tuple_check(names) {
        _PyArg_BadArgument(
            ptr[u8]("code"), ptr[u8]("argument 9"), ptr[u8]("tuple"), names
        );
        return NULL;
    }
    varnames = tuple_get_item(args, 9);
    if not tuple_check(varnames) {
        _PyArg_BadArgument(
            ptr[u8]("code"), ptr[u8]("argument 10"), ptr[u8]("tuple"), varnames
        );
        return NULL;
    }
    filename = tuple_get_item(args, 10);
    if not unicode_check(filename) {
        _PyArg_BadArgument(
            ptr[u8]("code"), ptr[u8]("argument 11"), ptr[u8]("str"), filename
        );
        return NULL;
    }
    name = tuple_get_item(args, 11);
    if not unicode_check(name) {
        _PyArg_BadArgument(
            ptr[u8]("code"), ptr[u8]("argument 12"), ptr[u8]("str"), name
        );
        return NULL;
    }
    qualname = tuple_get_item(args, 12);
    if not unicode_check(qualname) {
        _PyArg_BadArgument(
            ptr[u8]("code"), ptr[u8]("argument 13"), ptr[u8]("str"), qualname
        );
        return NULL;
    }
    (ok13, firstlineno) = arg_int(tuple_get_item(args, 13));
    if not ok13 {
        return NULL;
    }
    linetable = tuple_get_item(args, 14);
    if not bytes_check(linetable) {
        _PyArg_BadArgument(
            ptr[u8]("code"), ptr[u8]("argument 15"), ptr[u8]("bytes"), linetable
        );
        return NULL;
    }
    exceptiontable = tuple_get_item(args, 15);
    if not bytes_check(exceptiontable) {
        _PyArg_BadArgument(
            ptr[u8]("code"), ptr[u8]("argument 16"), ptr[u8]("bytes"), exceptiontable
        );
        return NULL;
    }
    freevars: ptr[PyObject] = NULL;
    cellvars: ptr[PyObject] = NULL;
    if nargs >= 17 {
        freevars = tuple_get_item(args, 16);
        if not tuple_check(freevars) {
            _PyArg_BadArgument(
                ptr[u8]("code"), ptr[u8]("argument 17"), ptr[u8]("tuple"), freevars
            );
            return NULL;
        }
    }
    if nargs >= 18 {
        cellvars = tuple_get_item(args, 17);
        if not tuple_check(cellvars) {
            _PyArg_BadArgument(
                ptr[u8]("code"), ptr[u8]("argument 18"), ptr[u8]("tuple"), cellvars
            );
            return NULL;
        }
    }
    return code_new_impl(
        type,
        argcount,
        posonlyargcount,
        kwonlyargcount,
        nlocals,
        stacksize,
        flags,
        code,
        consts,
        names,
        varnames,
        filename,
        name,
        qualname,
        firstlineno,
        linetable,
        exceptiontable,
        freevars,
        cellvars
    );
}

impl code_dealloc(self: ptr[PyObject]) {
    interp = current_interp();
    generation = ptr[u64](interp + PyInterpreterState_CODE_OBJECT_GENERATION);
    generation.view(1)[0] = wrapping_add(generation.view(1)[0], u64(1));
    resurrect_start(self);
    notify_code_watchers(PY_CODE_EVENT_DESTROY, self);
    if resurrect_end(self) {
        return;
    }

    _PyFunction_ClearCodeByVersion(co_version(self));
    co_extra = co_ptr(self, PyCodeObject_EXTRA);
    if co_extra {
        slots = extra_slots(co_extra);
        for i in range(extra_size(co_extra)) {
            free_extra = extra_freefunc(interp, i);
            if free_extra != 0 {
                call_free_extra(free_extra, (slots + i).view(1)[0]);
            }
        }
        PyMem_Free(ptr(co_extra));
    }

    object_xdecref(co_obj(self, PyCodeObject_CONSTS));
    object_xdecref(co_obj(self, PyCodeObject_NAMES));
    object_xdecref(co_obj(self, PyCodeObject_LOCALSPLUSNAMES));
    object_xdecref(co_obj(self, PyCodeObject_LOCALSPLUSKINDS));
    object_xdecref(co_obj(self, PyCodeObject_FILENAME));
    object_xdecref(co_obj(self, PyCodeObject_NAME));
    object_xdecref(co_obj(self, PyCodeObject_QUALNAME));
    object_xdecref(co_obj(self, PyCodeObject_LINETABLE));
    object_xdecref(co_obj(self, PyCodeObject_EXCEPTIONTABLE));
    cached = co_ptr(self, PyCodeObject_CO_CACHED);
    if cached {
        object_xdecref(m_obj(cached, _PyCoCached_CODE));
        object_xdecref(m_obj(cached, _PyCoCached_CELLVARS));
        object_xdecref(m_obj(cached, _PyCoCached_FREEVARS));
        object_xdecref(m_obj(cached, _PyCoCached_VARNAMES));
        PyMem_Free(ptr(cached));
    }
    if co_obj(self, PyCodeObject_WEAKREFLIST) {
        PyObject_ClearWeakRefs(self);
    }
    free_monitoring_data(co_ptr(self, PyCodeObject_MONITORING));
    PyObject_Free(ptr(self));
}

impl code_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    lineno = i32(-1);
    if co_int(self, PyCodeObject_FIRSTLINENO) != 0 {
        lineno = i32(co_int(self, PyCodeObject_FIRSTLINENO));
    }
    filename = co_obj(self, PyCodeObject_FILENAME);
    if filename and unicode_check(filename) {
        return PyUnicode_FromFormat(
            "<code object %U at %p, file \"%U\", line %d>",
            co_obj(self, PyCodeObject_NAME),
            ptr(self),
            filename,
            lineno
        );
    }
    return PyUnicode_FromFormat(
        "<code object %U at %p, file ???, line %d>",
        co_obj(self, PyCodeObject_NAME),
        ptr(self),
        lineno
    );
}

impl code_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if (op != Py_EQ and op != Py_NE) or not code_check(self) or not code_check(other) {
        return object_new_ref(Py_NotImplemented);
    }
    eq = code_equal(self, other);
    if eq < 0 {
        return NULL;
    }
    res = ptr[PyObject](addressof(_Py_FalseStruct));
    if (eq > 0 and op == Py_EQ) or (eq == 0 and op == Py_NE) {
        res = ptr[PyObject](addressof(_Py_TrueStruct));
    }
    return object_new_ref(res);
}

impl code_hash(self: ptr[PyObject]) -> i64 {
    uhash = u64(20221211);
    h: i64 = 0;
    h = PyObject_Hash(co_obj(self, PyCodeObject_NAME));
    if h == -1 {
        return -1;
    }
    uhash = scramble_int(uhash, h);
    h = PyObject_Hash(co_obj(self, PyCodeObject_CONSTS));
    if h == -1 {
        return -1;
    }
    uhash = scramble_int(uhash, h);
    h = PyObject_Hash(co_obj(self, PyCodeObject_NAMES));
    if h == -1 {
        return -1;
    }
    uhash = scramble_int(uhash, h);
    h = PyObject_Hash(co_obj(self, PyCodeObject_LOCALSPLUSNAMES));
    if h == -1 {
        return -1;
    }
    uhash = scramble_int(uhash, h);
    h = PyObject_Hash(co_obj(self, PyCodeObject_LINETABLE));
    if h == -1 {
        return -1;
    }
    uhash = scramble_int(uhash, h);
    h = PyObject_Hash(co_obj(self, PyCodeObject_EXCEPTIONTABLE));
    if h == -1 {
        return -1;
    }
    uhash = scramble_int(uhash, h);
    uhash = scramble_int(uhash, co_int(self, PyCodeObject_ARGCOUNT));
    uhash = scramble_int(uhash, co_int(self, PyCodeObject_POSONLYARGCOUNT));
    uhash = scramble_int(uhash, co_int(self, PyCodeObject_KWONLYARGCOUNT));
    uhash = scramble_int(uhash, co_int(self, PyCodeObject_FLAGS));
    uhash = scramble_int(uhash, co_int(self, PyCodeObject_FIRSTLINENO));
    n = object_size(self);
    uhash = scramble_int(uhash, n);
    i: i64 = 0;
    while i < n {
        co_instr = base_unit(self, i);
        opcode = unit_opcode(co_instr);
        uhash = scramble_int(uhash, opcode);
        uhash = scramble_int(uhash, unit_oparg(co_instr));
        i += opcode_caches(opcode) + 1;
    }
    result = i64.wrap(uhash);
    if result == -1 {
        return -2;
    }
    return result;
}

impl code_getlnotab(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if PyErr_WarnEx(
        PyExc_DeprecationWarning,
        ptr[u8]("co_lnotab is deprecated, use co_lines instead."),
        1
    )
        < 0 {
        return NULL;
    }
    return decode_linetable(self);
}

impl code_getvarnames(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return _PyCode_GetVarnames(self);
}

impl code_getcellvars(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return _PyCode_GetCellvars(self);
}

impl code_getfreevars(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return _PyCode_GetFreevars(self);
}

impl code_getcodeadaptive(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return PyBytes_FromStringAndSize(
        ptr[u8](code_units(self)), object_size(self) * CODEUNIT_SIZE
    );
}

impl code_getcode(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return _PyCode_GetCode(self);
}

impl code_sizeof(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    tp = object_type(self);
    res = (
        tp.view(1)[0].tp_basicsize + object_size(self) * tp.view(1)[0].tp_itemsize + 7
    )
        & ~i64(7);
    co_extra = co_ptr(self, PyCodeObject_EXTRA);
    if co_extra {
        res += _PyCodeObjectExtra_SIZE;
        res += (extra_size(co_extra) - 1) * 8;
    }
    return PyLong_FromSize_t(u64.wrap(res));
}

impl code_linesiterator(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return new_linesiterator(self);
}

impl code_branchesiterator(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _PyInstrumentation_BranchesIterator(self);
}

impl code_replace_impl(
    self: ptr[PyObject],
    co_argcount: i32,
    co_posonlyargcount: i32,
    co_kwonlyargcount: i32,
    co_nlocals: i32,
    co_stacksize: i32,
    co_flags_in: i32,
    co_firstlineno: i32,
    co_code_in: ptr[PyObject],
    co_consts: ptr[PyObject],
    co_names: ptr[PyObject],
    co_varnames_in: ptr[PyObject],
    co_freevars_in: ptr[PyObject],
    co_cellvars_in: ptr[PyObject],
    co_filename: ptr[PyObject],
    co_name: ptr[PyObject],
    co_qualname: ptr[PyObject],
    co_linetable: ptr[PyObject],
    co_exceptiontable: ptr[PyObject]
) -> ptr[PyObject] {
    if co_argcount < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("co_argcount must be a positive integer")
        );
        return NULL;
    }
    if co_posonlyargcount < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("co_posonlyargcount must be a positive integer")
        );
        return NULL;
    }
    if co_kwonlyargcount < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("co_kwonlyargcount must be a positive integer")
        );
        return NULL;
    }
    if co_nlocals < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("co_nlocals must be a positive integer")
        );
        return NULL;
    }
    if co_stacksize < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("co_stacksize must be a positive integer")
        );
        return NULL;
    }
    if co_flags_in < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("co_flags must be a positive integer")
        );
        return NULL;
    }
    if co_firstlineno < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("co_firstlineno must be a positive integer")
        );
        return NULL;
    }

    code: ptr[PyObject] = NULL;
    co_code = co_code_in;
    if not co_code {
        code = _PyCode_GetCode(self);
        if not code {
            return NULL;
        }
        co_code = code;
    }

    if PySys_Audit(
        "code.__new__",
        "OOOiiiiii",
        co_code,
        co_filename,
        co_name,
        co_argcount,
        co_posonlyargcount,
        co_kwonlyargcount,
        co_nlocals,
        co_stacksize,
        co_flags_in
    )
        < 0 {
        object_xdecref(code);
        return NULL;
    }

    co: ptr[PyObject] = NULL;
    varnames: ptr[PyObject] = NULL;
    cellvars: ptr[PyObject] = NULL;
    freevars: ptr[PyObject] = NULL;
    co_varnames = co_varnames_in;
    co_cellvars = co_cellvars_in;
    co_freevars = co_freevars_in;
    ok = True;
    if not co_varnames {
        varnames = get_localsplus_names(
            self, CO_FAST_LOCAL, co_int(self, PyCodeObject_NLOCALS)
        );
        if not varnames {
            ok = False;
        }
        co_varnames = varnames;
    }
    if ok and not co_cellvars {
        cellvars = get_localsplus_names(
            self, CO_FAST_CELL, co_int(self, PyCodeObject_NCELLVARS)
        );
        if not cellvars {
            ok = False;
        }
        co_cellvars = cellvars;
    }
    if ok and not co_freevars {
        freevars = get_localsplus_names(
            self, CO_FAST_FREE, co_int(self, PyCodeObject_NFREEVARS)
        );
        if not freevars {
            ok = False;
        }
        co_freevars = freevars;
    }
    if ok {
        co = PyUnstable_Code_NewWithPosOnlyArgs(
            co_argcount,
            co_posonlyargcount,
            co_kwonlyargcount,
            co_nlocals,
            co_stacksize,
            co_flags_in,
            co_code,
            co_consts,
            co_names,
            co_varnames,
            co_freevars,
            co_cellvars,
            co_filename,
            co_name,
            co_qualname,
            co_firstlineno,
            co_linetable,
            co_exceptiontable
        );
    }
    object_xdecref(code);
    object_xdecref(varnames);
    object_xdecref(cellvars);
    object_xdecref(freevars);
    return co;
}

impl replace_object(
    value: ptr[PyObject], dflt: ptr[PyObject], kind: i64, argname: ptr[u8]
) -> tuple[bool, ptr[PyObject]] {
    if not value {
        return (True, dflt);
    }
    if kind == 0 and not bytes_check(value) {
        _PyArg_BadArgument(ptr[u8]("replace"), argname, ptr[u8]("bytes"), value);
        return (False, dflt);
    }
    if kind == 1 and not tuple_check(value) {
        _PyArg_BadArgument(ptr[u8]("replace"), argname, ptr[u8]("tuple"), value);
        return (False, dflt);
    }
    if kind == 2 and not unicode_check(value) {
        _PyArg_BadArgument(ptr[u8]("replace"), argname, ptr[u8]("str"), value);
        return (False, dflt);
    }
    return (True, value);
}

impl replace_int(value: ptr[PyObject], dflt: i64) -> tuple[bool, i32] {
    if not value {
        return (True, i32(dflt));
    }
    return arg_int(value);
}

impl code_replace_bound(args: BoundArguments) -> ptr[PyObject] {
    code_self = args.context;
    values = args.values;
    (ok0, co_argcount) = replace_int(
        values[0], co_int(code_self, PyCodeObject_ARGCOUNT)
    );
    if not ok0 {
        return NULL;
    }
    (ok1, co_posonlyargcount) = replace_int(
        values[1], co_int(code_self, PyCodeObject_POSONLYARGCOUNT)
    );
    if not ok1 {
        return NULL;
    }
    (ok2, co_kwonlyargcount) = replace_int(
        values[2], co_int(code_self, PyCodeObject_KWONLYARGCOUNT)
    );
    if not ok2 {
        return NULL;
    }
    (ok3, co_nlocals) = replace_int(values[3], co_int(code_self, PyCodeObject_NLOCALS));
    if not ok3 {
        return NULL;
    }
    (ok4, co_stacksize) = replace_int(
        values[4], co_int(code_self, PyCodeObject_STACKSIZE)
    );
    if not ok4 {
        return NULL;
    }
    (ok5, co_flags_value) = replace_int(
        values[5], co_int(code_self, PyCodeObject_FLAGS)
    );
    if not ok5 {
        return NULL;
    }
    (ok6, co_firstlineno) = replace_int(
        values[6], co_int(code_self, PyCodeObject_FIRSTLINENO)
    );
    if not ok6 {
        return NULL;
    }
    (ok7, co_code) = replace_object(values[7], NULL, 0, ptr[u8]("argument 'co_code'"));
    if not ok7 {
        return NULL;
    }
    (ok8, co_consts) = replace_object(
        values[8],
        co_obj(code_self, PyCodeObject_CONSTS),
        1,
        ptr[u8]("argument 'co_consts'")
    );
    if not ok8 {
        return NULL;
    }
    (ok9, co_names) = replace_object(
        values[9],
        co_obj(code_self, PyCodeObject_NAMES),
        1,
        ptr[u8]("argument 'co_names'")
    );
    if not ok9 {
        return NULL;
    }
    (ok10, co_varnames) = replace_object(
        values[10], NULL, 1, ptr[u8]("argument 'co_varnames'")
    );
    if not ok10 {
        return NULL;
    }
    (ok11, co_freevars) = replace_object(
        values[11], NULL, 1, ptr[u8]("argument 'co_freevars'")
    );
    if not ok11 {
        return NULL;
    }
    (ok12, co_cellvars) = replace_object(
        values[12], NULL, 1, ptr[u8]("argument 'co_cellvars'")
    );
    if not ok12 {
        return NULL;
    }
    (ok13, co_filename) = replace_object(
        values[13],
        co_obj(code_self, PyCodeObject_FILENAME),
        2,
        ptr[u8]("argument 'co_filename'")
    );
    if not ok13 {
        return NULL;
    }
    (ok14, co_name) = replace_object(
        values[14],
        co_obj(code_self, PyCodeObject_NAME),
        2,
        ptr[u8]("argument 'co_name'")
    );
    if not ok14 {
        return NULL;
    }
    (ok15, co_qualname) = replace_object(
        values[15],
        co_obj(code_self, PyCodeObject_QUALNAME),
        2,
        ptr[u8]("argument 'co_qualname'")
    );
    if not ok15 {
        return NULL;
    }
    (ok16, co_linetable) = replace_object(
        values[16],
        co_obj(code_self, PyCodeObject_LINETABLE),
        0,
        ptr[u8]("argument 'co_linetable'")
    );
    if not ok16 {
        return NULL;
    }
    (ok17, co_exceptiontable) = replace_object(
        values[17],
        co_obj(code_self, PyCodeObject_EXCEPTIONTABLE),
        0,
        ptr[u8]("argument 'co_exceptiontable'")
    );
    if not ok17 {
        return NULL;
    }
    return code_replace_impl(
        code_self,
        co_argcount,
        co_posonlyargcount,
        co_kwonlyargcount,
        co_nlocals,
        co_stacksize,
        co_flags_value,
        co_firstlineno,
        co_code,
        co_consts,
        co_names,
        co_varnames,
        co_freevars,
        co_cellvars,
        co_filename,
        co_name,
        co_qualname,
        co_linetable,
        co_exceptiontable
    );
}

impl code_replace(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 0 and not kwnames {
        return code_replace_impl(
            self,
            i32(co_int(self, PyCodeObject_ARGCOUNT)),
            i32(co_int(self, PyCodeObject_POSONLYARGCOUNT)),
            i32(co_int(self, PyCodeObject_KWONLYARGCOUNT)),
            i32(co_int(self, PyCodeObject_NLOCALS)),
            i32(co_int(self, PyCodeObject_STACKSIZE)),
            co_flags(self),
            i32(co_int(self, PyCodeObject_FIRSTLINENO)),
            NULL,
            co_obj(self, PyCodeObject_CONSTS),
            co_obj(self, PyCodeObject_NAMES),
            NULL,
            NULL,
            NULL,
            co_obj(self, PyCodeObject_FILENAME),
            co_obj(self, PyCodeObject_NAME),
            co_obj(self, PyCodeObject_QUALNAME),
            co_obj(self, PyCodeObject_LINETABLE),
            co_obj(self, PyCodeObject_EXCEPTIONTABLE)
        );
    }
    return invoke_vector(
        replace_signature, args, nargs, kwnames, code_replace_bound, self
    );
}

impl code__varname_from_oparg_impl(self: ptr[PyObject], oparg: i32) -> ptr[PyObject] {
    name = PyTuple_GetItem(co_obj(self, PyCodeObject_LOCALSPLUSNAMES), i64(oparg));
    if not name {
        return NULL;
    }
    return object_new_ref(name);
}

impl code_varname_from_oparg_bound(args: BoundArguments) -> ptr[PyObject] {
    (ok, oparg) = arg_int(args.values[0]);
    if not ok {
        return NULL;
    }
    return code__varname_from_oparg_impl(args.context, oparg);
}

impl code__varname_from_oparg(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 1 and not kwnames {
        (ok, oparg) = arg_int(args.view(1)[0]);
        if not ok {
            return NULL;
        }
        return code__varname_from_oparg_impl(self, oparg);
    }
    return invoke_vector(
        varname_from_oparg_signature,
        args,
        nargs,
        kwnames,
        code_varname_from_oparg_bound,
        self
    );
}
