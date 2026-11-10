import from c {
    obj UnpicklerRec {
        has stack: ptr[ptr[PyObject]] = ptr[ptr[PyObject]](),
            stack_len: i64 = 0,
            stack_allocated: i64 = 0,
            fence: i64 = 0,
            mark_set: i32 = 0,
            proto: i32 = 0,
            memo: ptr[ptr[PyObject]] = ptr[ptr[PyObject]](),
            memo_size: i64 = 0,
            memo_len: i64 = 0,
            persistent_load: ptr[PyObject] = ptr[PyObject](),
            find_class: ptr[PyObject] = ptr[PyObject](),
            view: ptr[Py_buffer] = ptr[Py_buffer](),
            input_obj: ptr[PyObject] = ptr[PyObject](),
            input_buffer: ptr[u8] = ptr[u8](),
            input_line: ptr[u8] = ptr[u8](),
            input_len: i64 = 0,
            next_read_idx: i64 = 0,
            prefetched_idx: i64 = 0,
            read: ptr[PyObject] = ptr[PyObject](),
            readinto: ptr[PyObject] = ptr[PyObject](),
            readline: ptr[PyObject] = ptr[PyObject](),
            peek: ptr[PyObject] = ptr[PyObject](),
            buffers: ptr[PyObject] = ptr[PyObject](),
            encoding: ptr[PyObject] = ptr[PyObject](),
            errors: ptr[PyObject] = ptr[PyObject](),
            marks: ptr[i64] = ptr[i64](),
            num_marks: i64 = 0,
            marks_size: i64 = 0,
            fix_imports: i32 = 0,
            view_active: i32 = 0,
            error: ptr[PyObject] = ptr[PyObject](),
            module: ptr[PyObject] = ptr[PyObject]();
    }  obj UnpicklerStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0,
            w4: u64 = 0,
            w5: u64 = 0,
            w6: u64 = 0,
            w7: u64 = 0,
            w8: u64 = 0,
            w9: u64 = 0,
            w10: u64 = 0,
            w11: u64 = 0,
            w12: u64 = 0,
            w13: u64 = 0,
            w14: u64 = 0,
            w15: u64 = 0,
            w16: u64 = 0,
            w17: u64 = 0,
            w18: u64 = 0,
            w19: u64 = 0,
            w20: u64 = 0,
            w21: u64 = 0,
            w22: u64 = 0,
            w23: u64 = 0,
            w24: u64 = 0,
            w25: u64 = 0,
            w26: u64 = 0,
            w27: u64 = 0,
            w28: u64 = 0,
            w29: u64 = 0,
            w30: u64 = 0,
            w31: u64 = 0,
            w32: u64 = 0,
            w33: u64 = 0,
            w34: u64 = 0,
            w35: u64 = 0,
            w36: u64 = 0,
            w37: u64 = 0,
            w38: u64 = 0,
            w39: u64 = 0;
    }  def jacpy_stack_address(slots: &mut UnpicklerStack) -> int;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def strlen(text: ptr[u8]) -> u64;  def PyFloat_Unpack8(
        data: ptr[u8], le: i32
    ) -> f64;  def PyUnicode_DecodeUTF8(
        s: ptr[u8], size: i64, errors: ptr[u8]
    ) -> ptr[PyObject];  def PyUnicode_DecodeRawUnicodeEscape(
        s: ptr[u8], size: i64, errors: ptr[u8]
    ) -> ptr[PyObject];  def PyLong_FromString(
        text: ptr[u8], pend: ptr, base: i32
    ) -> ptr[PyObject];  def PyByteArray_FromStringAndSize(
        data: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyMemoryView_FromMemory(
        mem: ptr[u8], size: i64, flags: i32
    ) -> ptr[PyObject];  def _PySet_Update(
        set: ptr[PyObject], iterable: ptr[PyObject]
    ) -> i32;  def _PyUnicode_InternMortal(interp: ptr[u8], p: &mut ptr[PyObject]);  def PyUnicode_Split(
        s: ptr[PyObject], sep: ptr[PyObject], maxsplit: i64
    ) -> ptr[PyObject];  def PyFrozenSet_New(iterable: ptr[PyObject]) -> ptr[PyObject];
}

glob:priv OP_MARK: Final[u8] = 40,
     OP_STOP: Final[u8] = 46,
     OP_POP: Final[u8] = 48,
     OP_POP_MARK: Final[u8] = 49,
     OP_DUP: Final[u8] = 50,
     OP_FLOAT: Final[u8] = 70,
     OP_INT: Final[u8] = 73,
     OP_BININT: Final[u8] = 74,
     OP_BININT1: Final[u8] = 75,
     OP_LONG: Final[u8] = 76,
     OP_BININT2: Final[u8] = 77,
     OP_NONE: Final[u8] = 78,
     OP_PERSID: Final[u8] = 80,
     OP_BINPERSID: Final[u8] = 81,
     OP_REDUCE: Final[u8] = 82,
     OP_STRING: Final[u8] = 83,
     OP_BINSTRING: Final[u8] = 84,
     OP_SHORT_BINSTRING: Final[u8] = 85,
     OP_UNICODE: Final[u8] = 86,
     OP_BINUNICODE: Final[u8] = 88,
     OP_APPEND: Final[u8] = 97,
     OP_BUILD: Final[u8] = 98,
     OP_GLOBAL: Final[u8] = 99,
     OP_DICT: Final[u8] = 100,
     OP_EMPTY_DICT: Final[u8] = 125,
     OP_APPENDS: Final[u8] = 101,
     OP_GET: Final[u8] = 103,
     OP_BINGET: Final[u8] = 104,
     OP_INST: Final[u8] = 105,
     OP_LONG_BINGET: Final[u8] = 106,
     OP_LIST: Final[u8] = 108,
     OP_EMPTY_LIST: Final[u8] = 93,
     OP_OBJ: Final[u8] = 111,
     OP_PUT: Final[u8] = 112,
     OP_BINPUT: Final[u8] = 113,
     OP_LONG_BINPUT: Final[u8] = 114,
     OP_SETITEM: Final[u8] = 115,
     OP_TUPLE: Final[u8] = 116,
     OP_EMPTY_TUPLE: Final[u8] = 41,
     OP_SETITEMS: Final[u8] = 117,
     OP_BINFLOAT: Final[u8] = 71,
     OP_PROTO: Final[u8] = 128,
     OP_NEWOBJ: Final[u8] = 129,
     OP_EXT1: Final[u8] = 130,
     OP_EXT2: Final[u8] = 131,
     OP_EXT4: Final[u8] = 132,
     OP_TUPLE1: Final[u8] = 133,
     OP_TUPLE2: Final[u8] = 134,
     OP_TUPLE3: Final[u8] = 135,
     OP_NEWTRUE: Final[u8] = 136,
     OP_NEWFALSE: Final[u8] = 137,
     OP_LONG1: Final[u8] = 138,
     OP_LONG4: Final[u8] = 139,
     OP_BINBYTES: Final[u8] = 66,
     OP_SHORT_BINBYTES: Final[u8] = 67,
     OP_SHORT_BINUNICODE: Final[u8] = 140,
     OP_BINUNICODE8: Final[u8] = 141,
     OP_BINBYTES8: Final[u8] = 142,
     OP_EMPTY_SET: Final[u8] = 143,
     OP_ADDITEMS: Final[u8] = 144,
     OP_FROZENSET: Final[u8] = 145,
     OP_NEWOBJ_EX: Final[u8] = 146,
     OP_STACK_GLOBAL: Final[u8] = 147,
     OP_MEMOIZE: Final[u8] = 148,
     OP_FRAME: Final[u8] = 149,
     OP_BYTEARRAY8: Final[u8] = 150,
     OP_NEXT_BUFFER: Final[u8] = 151,
     OP_READONLY_BUFFER: Final[u8] = 152,
     HIGHEST_PROTOCOL: Final[i32] = 5,
     PREFETCH: Final[i64] = 131072,
     READ_WHOLE_LINE: Final[i64] = -1,
     MEMO_SIZE: Final[i64] = 32,
     STACK_SIZE: Final[i64] = 8,
     UNPICKLER_REC_SIZE: Final[u64] = 320,
     UNPICKLE_PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     UNPICKLE_BUFFER_VIEW_SIZE: Final[u64] = 80,
     UNPICKLE_BUF_CONTIG_RO: Final[i32] = 8,
     UNPICKLE_BUF_WRITE: Final[i32] = 512;

glob:priv SLOT_UNPICKLING_ERROR: Final[i64] = 6,
     SLOT_EXTENSION_CACHE: Final[i64] = 9,
     SLOT_INVERTED_REGISTRY: Final[i64] = 10,
     SLOT_NAME_MAPPING_2TO3: Final[i64] = 11,
     SLOT_IMPORT_MAPPING_2TO3: Final[i64] = 12;

glob:priv dot_text: ptr[PyObject] = NULL,
     getinitargs_text: ptr[PyObject] = NULL,
     add_text: ptr[PyObject] = NULL;

obj unpickle_state {
    has rec: ptr[UnpicklerRec] = ptr[UnpicklerRec]();
}

def interned(slot: ptr[PyObject], text: ptr[u8]) -> ptr[PyObject];

def state_object(u: ptr[UnpicklerRec], slot: i64) -> ptr[PyObject];

def stack_item(u: ptr[UnpicklerRec], i: i64) -> ptr[PyObject];

def tp_name_of(op: ptr[PyObject]) -> ptr[u8];

def stack_underflow(u: ptr[UnpicklerRec]) -> i32;

def stack_grow(u: ptr[UnpicklerRec]) -> i32;

def push(u: ptr[UnpicklerRec], obj_: ptr[PyObject]) -> i32;

def push_new_ref(u: ptr[UnpicklerRec], obj_: ptr[PyObject]) -> i32;

def pop(u: ptr[UnpicklerRec]) -> ptr[PyObject];

def poptuple(u: ptr[UnpicklerRec], start: i64) -> ptr[PyObject];

def poplist(u: ptr[UnpicklerRec], start: i64) -> ptr[PyObject];

def stack_clear(u: ptr[UnpicklerRec], clearto: i64);

def marker(u: ptr[UnpicklerRec]) -> i64;

def bad_readline(u: ptr[UnpicklerRec]) -> i32;

def release_input(u: ptr[UnpicklerRec]);

def set_string_input(u: ptr[UnpicklerRec], input: ptr[PyObject]) -> i64;

def call_with_size(func: ptr[PyObject], n: i64) -> ptr[PyObject];

def skip_consumed(u: ptr[UnpicklerRec]) -> i32;

def read_from_file(u: ptr[UnpicklerRec], n: i64) -> i64;

def read_impl(u: ptr[UnpicklerRec], n: i64) -> ptr[u8];

def read_n(u: ptr[UnpicklerRec], n: i64) -> ptr[u8];

def read_into(u: ptr[UnpicklerRec], buf: ptr[u8], n: i64) -> i64;

def copy_line(u: ptr[UnpicklerRec], line: ptr[u8], n: i64) -> (i64, ptr[u8]);

def readline(u: ptr[UnpicklerRec]) -> (i64, ptr[u8]);

def memo_resize(u: ptr[UnpicklerRec], new_size: i64) -> i32;

def memo_get(u: ptr[UnpicklerRec], idx: i64) -> ptr[PyObject];

def memo_put(u: ptr[UnpicklerRec], idx: i64, value: ptr[PyObject]) -> i32;

def memo_new(size: i64) -> ptr[ptr[PyObject]];

def memo_cleanup(u: ptr[UnpicklerRec]);

def calc_binsize(data: ptr[u8], nbytes: i64) -> i64;

def calc_binint(data: ptr[u8], nbytes: i64) -> i64;

def find_class_object(
    u: ptr[UnpicklerRec], module_name: ptr[PyObject], global_name: ptr[PyObject]
) -> ptr[PyObject];

def find_class(
    u: ptr[UnpicklerRec], module_name: ptr[PyObject], global_name: ptr[PyObject]
) -> ptr[PyObject];

def load_int(u: ptr[UnpicklerRec]) -> i32;

def load_binintx(u: ptr[UnpicklerRec], nbytes: i64) -> i32;

def load_long(u: ptr[UnpicklerRec]) -> i32;

def load_counted_long(u: ptr[UnpicklerRec], nbytes: i64) -> i32;

def load_float(u: ptr[UnpicklerRec]) -> i32;

def load_binfloat(u: ptr[UnpicklerRec]) -> i32;

def codec_text(name: ptr[PyObject], dflt: ptr[u8]) -> ptr[u8];

def wants_bytes(u: ptr[UnpicklerRec]) -> bool;

def load_string(u: ptr[UnpicklerRec]) -> i32;

def load_counted_binstring(u: ptr[UnpicklerRec], nbytes: i64) -> i32;

def load_counted_binbytes(u: ptr[UnpicklerRec], nbytes: i64) -> i32;

def load_counted_bytearray(u: ptr[UnpicklerRec]) -> i32;

def load_next_buffer(u: ptr[UnpicklerRec]) -> i32;

def load_readonly_buffer(u: ptr[UnpicklerRec]) -> i32;

def load_unicode(u: ptr[UnpicklerRec]) -> i32;

def load_counted_binunicode(u: ptr[UnpicklerRec], nbytes: i64) -> i32;

def load_counted_tuple(u: ptr[UnpicklerRec], n: i64) -> i32;

def load_tuple(u: ptr[UnpicklerRec]) -> i32;

def load_list(u: ptr[UnpicklerRec]) -> i32;

def load_dict(u: ptr[UnpicklerRec]) -> i32;

def load_frozenset(u: ptr[UnpicklerRec]) -> i32;

def instantiate(cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def load_obj(u: ptr[UnpicklerRec]) -> i32;

def decode_name(line: ptr[u8], n: i64, ascii: bool) -> ptr[PyObject];

def read_global(u: ptr[UnpicklerRec], ascii: bool) -> ptr[PyObject];

def load_inst(u: ptr[UnpicklerRec]) -> i32;

def newobj_error(
    u: ptr[UnpicklerRec], use_kwargs: bool, message: ptr[u8], arg: ptr[PyObject]
);

def load_newobj(u: ptr[UnpicklerRec], use_kwargs: bool) -> i32;

def load_global(u: ptr[UnpicklerRec]) -> i32;

def load_stack_global(u: ptr[UnpicklerRec]) -> i32;

def call_persistent_load(u: ptr[UnpicklerRec], pid: ptr[PyObject]) -> ptr[PyObject];

def load_persid(u: ptr[UnpicklerRec]) -> i32;

def load_binpersid(u: ptr[UnpicklerRec]) -> i32;

def load_pop(u: ptr[UnpicklerRec]) -> i32;

def load_pop_mark(u: ptr[UnpicklerRec]) -> i32;

def load_dup(u: ptr[UnpicklerRec]) -> i32;

def memo_missing(u: ptr[UnpicklerRec], idx: i64) -> i32;

def load_get(u: ptr[UnpicklerRec]) -> i32;

def load_binget(u: ptr[UnpicklerRec], nbytes: i64) -> i32;

def load_extension(u: ptr[UnpicklerRec], nbytes: i64) -> i32;

def top_value(u: ptr[UnpicklerRec]) -> ptr[PyObject];

def load_put(u: ptr[UnpicklerRec]) -> i32;

def load_binput(u: ptr[UnpicklerRec], nbytes: i64) -> i32;

def load_memoize(u: ptr[UnpicklerRec]) -> i32;

def do_append(u: ptr[UnpicklerRec], x: i64) -> i32;

def load_appends(u: ptr[UnpicklerRec]) -> i32;

def do_setitems(u: ptr[UnpicklerRec], x: i64) -> i32;

def load_setitems(u: ptr[UnpicklerRec]) -> i32;

def load_additems(u: ptr[UnpicklerRec]) -> i32;

def build_dict_state(
    u: ptr[UnpicklerRec], inst: ptr[PyObject], state: ptr[PyObject]
) -> i32;

def build_slot_state(
    u: ptr[UnpicklerRec], inst: ptr[PyObject], slotstate: ptr[PyObject]
) -> i32;

def load_build(u: ptr[UnpicklerRec]) -> i32;

def load_mark(u: ptr[UnpicklerRec]) -> i32;

def load_reduce(u: ptr[UnpicklerRec]) -> i32;

def load_proto(u: ptr[UnpicklerRec]) -> i32;

def load_frame(u: ptr[UnpicklerRec]) -> i32;

def invalid_key(u: ptr[UnpicklerRec], c: u8) -> i32;

def load_rare(u: ptr[UnpicklerRec], op: u8) -> i32;

def load(u: ptr[UnpicklerRec]) -> ptr[PyObject];

impl find_class_object(
    u: ptr[UnpicklerRec], module_name: ptr[PyObject], global_name: ptr[PyObject]
) -> ptr[PyObject] {
    s = u.view(1);
    if PySys_Audit(
        ptr[u8]("pickle.find_class"), ptr[u8]("OO"), module_name, global_name
    )
        < 0 {
        return NULL;
    }
    if s[0].proto < 3 and s[0].fix_imports != 0 {
        key = PyTuple_Pack(2, module_name, global_name);
        if not key {
            return NULL;
        }
        item = PyDict_GetItemWithError(state_object(u, SLOT_NAME_MAPPING_2TO3), key);
        object_decref(key);
        if item {
            if not tuple_check(item) or object_size(item) != 2 {
                PyErr_Format(
                    PyExc_RuntimeError,
                    ptr[u8](
                        "_compat_pickle.NAME_MAPPING values should be 2-tuples, not %.200s"
                    ),
                    tp_name_of(item)
                );
                return NULL;
            }
            module_name = tuple_get_item(item, 0);
            global_name = tuple_get_item(item, 1);
            if not unicode_check(module_name) or not unicode_check(global_name) {
                PyErr_Format(
                    PyExc_RuntimeError,
                    ptr[u8](
                        "_compat_pickle.NAME_MAPPING values should be pairs of str, not (%.200s, %.200s)"
                    ),
                    tp_name_of(module_name),
                    tp_name_of(global_name)
                );
                return NULL;
            }
        } elif PyErr_Occurred() {
            return NULL;
        } else {
            item = PyDict_GetItemWithError(
                state_object(u, SLOT_IMPORT_MAPPING_2TO3), module_name
            );
            if item {
                if not unicode_check(item) {
                    PyErr_Format(
                        PyExc_RuntimeError,
                        ptr[u8](
                            "_compat_pickle.IMPORT_MAPPING values should be strings, not %.200s"
                        ),
                        tp_name_of(item)
                    );
                    return NULL;
                }
                module_name = item;
            } elif PyErr_Occurred() {
                return NULL;
            }
        }
    }
    module = PyImport_Import(module_name);
    if not module {
        return NULL;
    }
    found = NULL;
    if s[0].proto >= 4 {
        dot_text = interned(dot_text, ptr[u8]("."));
        if not dot_text {
            object_decref(module);
            return NULL;
        }
        dotted_path = PyUnicode_Split(global_name, dot_text, -1);
        if not dotted_path {
            object_decref(module);
            return NULL;
        }
        found = object_new_ref(module);
        n = object_size(dotted_path);
        i: i64 = 0;
        while i < n and found {
            parent = found;
            found = PyObject_GetAttr(
                parent,
                (ptr[PyListObject](dotted_path).view(1)[0].ob_item + i).view(1)[0]
            );
            object_decref(parent);
            i += 1;
        }
        if not found and n > 1 {
            exc = PyErr_GetRaisedException();
            PyErr_Format(
                PyExc_AttributeError,
                ptr[u8]("Can't resolve path %R on module %R"),
                global_name,
                module_name
            );
            _PyErr_ChainExceptions1(exc);
        }
        object_decref(dotted_path);
    } else {
        found = PyObject_GetAttr(module, global_name);
    }
    object_decref(module);
    return found;
}

def unpickler_new -> ptr[UnpicklerRec];

def clear_slot(slot: ptr[PyObject]) -> ptr[PyObject];

def unpickler_release(u: ptr[UnpicklerRec]);

def unpickler_free(u: ptr[UnpicklerRec]);

def visit_slot(value: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def unpickler_traverse(u: ptr[UnpicklerRec], visitor: ptr, context: ptr) -> i32;

def unpickler_prepare(
    u: ptr[UnpicklerRec],
    module: ptr[PyObject],
    fix_imports: bool,
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    buffers: ptr[PyObject]
) -> i32;

def set_input_stream(u: ptr[UnpicklerRec], file: ptr[PyObject]) -> i32;

def unpickler_init(
    u: ptr[UnpicklerRec],
    module: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    buffers: ptr[PyObject]
) -> i32;

def unpickler_run(
    u: ptr[UnpicklerRec], find_class: ptr[PyObject], persistent_load: ptr[PyObject]
) -> ptr[PyObject];

def unpickler_memo_copy(u: ptr[UnpicklerRec]) -> ptr[PyObject];

def unpickler_memo_clear(u: ptr[UnpicklerRec]) -> i32;

def unpickler_memo_set(u: ptr[UnpicklerRec], obj_: ptr[PyObject]) -> i32;

def unpickler_sizeof(u: ptr[UnpicklerRec]) -> i64;

def pickle_loads(
    module: ptr[PyObject],
    data: ptr[PyObject],
    fix_imports: bool,
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    buffers: ptr[PyObject]
) -> ptr[PyObject];

def pickle_load(
    module: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    buffers: ptr[PyObject]
) -> ptr[PyObject];

impl interned(slot: ptr[PyObject], text: ptr[u8]) -> ptr[PyObject] {
    if slot {
        return slot;
    }
    return PyUnicode_InternFromString(text);
}

impl state_object(u: ptr[UnpicklerRec], slot: i64) -> ptr[PyObject] {
    return jacpy_binding_state_get(u.view(1)[0].module, slot);
}

impl stack_item(u: ptr[UnpicklerRec], i: i64) -> ptr[PyObject] {
    return (u.view(1)[0].stack + i).view(1)[0];
}

impl tp_name_of(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](object_type(op).view(1)[0].tp_name);
}

impl stack_underflow(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    if s[0].mark_set != 0 {
        PyErr_SetString(s[0].error, ptr[u8]("unexpected MARK found"));
    } else {
        PyErr_SetString(s[0].error, ptr[u8]("unpickling stack underflow"));
    }
    return -1;
}

impl stack_grow(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    allocated = s[0].stack_allocated;
    new_allocated = (allocated >> 3) + 6;
    if new_allocated > UNPICKLE_PY_SSIZE_T_MAX // 8 - allocated {
        PyErr_NoMemory();
        return -1;
    }
    new_allocated += allocated;
    data = ptr[ptr[PyObject]](
        PyMem_Realloc(ptr(s[0].stack), u64(new_allocated) * u64(8))
    );
    if not data {
        PyErr_NoMemory();
        return -1;
    }
    s[0].stack = data;
    s[0].stack_allocated = new_allocated;
    return 0;
}

impl push(u: ptr[UnpicklerRec], obj_: ptr[PyObject]) -> i32 {
    if not obj_ {
        return -1;
    }
    s = u.view(1);
    n = s[0].stack_len;
    if n == s[0].stack_allocated and stack_grow(u) < 0 {
        object_decref(obj_);
        return -1;
    }
    (s[0].stack + n).view(1)[0] = obj_;
    s[0].stack_len = n + 1;
    return 0;
}

impl push_new_ref(u: ptr[UnpicklerRec], obj_: ptr[PyObject]) -> i32 {
    return push(u, object_new_ref(obj_));
}

impl pop(u: ptr[UnpicklerRec]) -> ptr[PyObject] {
    s = u.view(1);
    n = s[0].stack_len;
    if n <= s[0].fence {
        stack_underflow(u);
        return NULL;
    }
    s[0].stack_len = n - 1;
    return (s[0].stack + (n - 1)).view(1)[0];
}

impl poptuple(u: ptr[UnpicklerRec], start: i64) -> ptr[PyObject] {
    s = u.view(1);
    if start < s[0].fence {
        stack_underflow(u);
        return NULL;
    }
    n = s[0].stack_len - start;
    tuple_ = PyTuple_New(n);
    if not tuple_ {
        return NULL;
    }
    data = s[0].stack + start;
    i: i64 = 0;
    while i < n {
        tuple_set_item(tuple_, i, (data + i).view(1)[0]);
        i += 1;
    }
    s[0].stack_len = start;
    return tuple_;
}

impl poplist(u: ptr[UnpicklerRec], start: i64) -> ptr[PyObject] {
    s = u.view(1);
    n = s[0].stack_len - start;
    lst = PyList_New(n);
    if not lst {
        return NULL;
    }
    items = ptr[PyListObject](lst).view(1)[0].ob_item;
    data = s[0].stack + start;
    i: i64 = 0;
    while i < n {
        (items + i).view(1)[0] = (data + i).view(1)[0];
        i += 1;
    }
    s[0].stack_len = start;
    return lst;
}

impl stack_clear(u: ptr[UnpicklerRec], clearto: i64) {
    s = u.view(1);
    i = s[0].stack_len;
    if clearto >= i {
        return;
    }
    while i > clearto {
        i -= 1;
        item = (s[0].stack + i).view(1)[0];
        (s[0].stack + i).view(1)[0] = ptr[PyObject]();
        object_decref(item);
    }
    s[0].stack_len = clearto;
}

impl marker(u: ptr[UnpicklerRec]) -> i64 {
    s = u.view(1);
    if s[0].num_marks < 1 {
        PyErr_SetString(s[0].error, ptr[u8]("could not find MARK"));
        return -1;
    }
    n = s[0].num_marks - 1;
    s[0].num_marks = n;
    mark = (s[0].marks + n).view(1)[0];
    s[0].mark_set = i32(1) if n != 0 else i32(0);
    if n != 0 {
        s[0].fence = (s[0].marks + (n - 1)).view(1)[0];
    } else {
        s[0].fence = 0;
    }
    return mark;
}

impl bad_readline(u: ptr[UnpicklerRec]) -> i32 {
    PyErr_SetString(u.view(1)[0].error, ptr[u8]("pickle data was truncated"));
    return -1;
}

impl release_input(u: ptr[UnpicklerRec]) {
    s = u.view(1);
    if s[0].view_active != 0 {
        s[0].view_active = 0;
        PyBuffer_Release(s[0].view);
    }
    held = s[0].input_obj;
    s[0].input_obj = ptr[PyObject]();
    object_xdecref(held);
    s[0].input_buffer = ptr[u8]();
}

impl set_string_input(u: ptr[UnpicklerRec], input: ptr[PyObject]) -> i64 {
    release_input(u);
    s = u.view(1);
    if ptr[PyObject](object_type(input)) == addressof(PyBytes_Type) {
        s[0].input_obj = object_new_ref(input);
        s[0].input_buffer = bytes_data(input);
        s[0].input_len = object_size(input);
    } else {
        if not s[0].view {
            s[0].view = ptr[Py_buffer](PyMem_Calloc(u64(1), UNPICKLE_BUFFER_VIEW_SIZE));
            if not s[0].view {
                PyErr_NoMemory();
                return -1;
            }
        }
        if PyObject_GetBuffer(input, s[0].view, UNPICKLE_BUF_CONTIG_RO) < 0 {
            return -1;
        }
        s[0].view_active = 1;
        s[0].input_buffer = ptr[u8](s[0].view.view(1)[0].buf);
        s[0].input_len = s[0].view.view(1)[0].length;
    }
    s[0].next_read_idx = 0;
    s[0].prefetched_idx = s[0].input_len;
    return s[0].input_len;
}

impl call_with_size(func: ptr[PyObject], n: i64) -> ptr[PyObject] {
    size = PyLong_FromSsize_t(n);
    if not size {
        return NULL;
    }
    result = PyObject_CallOneArg(func, size);
    object_decref(size);
    return result;
}

impl skip_consumed(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    consumed = s[0].next_read_idx - s[0].prefetched_idx;
    if consumed <= 0 {
        return 0;
    }
    r = call_with_size(s[0].read, consumed);
    if not r {
        return -1;
    }
    object_decref(r);
    s[0].prefetched_idx = s[0].next_read_idx;
    return 0;
}

impl read_from_file(u: ptr[UnpicklerRec], n: i64) -> i64 {
    s = u.view(1);
    if skip_consumed(u) < 0 {
        return -1;
    }
    data = NULL;
    if n == READ_WHOLE_LINE {
        data = PyObject_CallNoArgs(s[0].readline);
    } else {
        if s[0].peek and n < PREFETCH {
            data = call_with_size(s[0].peek, PREFETCH);
            if not data {
                if PyErr_ExceptionMatches(PyExc_NotImplementedError) == 0 {
                    return -1;
                }
                PyErr_Clear();
                peek = s[0].peek;
                s[0].peek = ptr[PyObject]();
                object_decref(peek);
            } else {
                read_size = set_string_input(u, data);
                object_decref(data);
                if read_size < 0 {
                    return -1;
                }
                s[0].prefetched_idx = 0;
                if n <= read_size {
                    return n;
                }
            }
        }
        data = call_with_size(s[0].read, n);
    }
    if not data {
        return -1;
    }
    read_size = set_string_input(u, data);
    object_decref(data);
    return read_size;
}

impl read_impl(u: ptr[UnpicklerRec], n: i64) -> ptr[u8] {
    s = u.view(1);
    if s[0].next_read_idx > UNPICKLE_PY_SSIZE_T_MAX - n {
        PyErr_SetString(s[0].error, ptr[u8]("read would overflow (invalid bytecode)"));
        return ptr[u8]();
    }
    if not s[0].read {
        bad_readline(u);
        return ptr[u8]();
    }
    num_read = read_from_file(u, n);
    if num_read < 0 {
        return ptr[u8]();
    }
    if num_read < n {
        bad_readline(u);
        return ptr[u8]();
    }
    s[0].next_read_idx = n;
    return s[0].input_buffer;
}

impl read_n(u: ptr[UnpicklerRec], n: i64) -> ptr[u8] {
    s = u.view(1);
    idx = s[0].next_read_idx;
    if n <= s[0].input_len - idx {
        s[0].next_read_idx = idx + n;
        return s[0].input_buffer + idx;
    }
    return read_impl(u, n);
}

impl read_into(u: ptr[UnpicklerRec], buf: ptr[u8], n: i64) -> i64 {
    s = u.view(1);
    in_buffer = s[0].input_len - s[0].next_read_idx;
    if in_buffer > 0 {
        to_read = in_buffer if in_buffer < n else n;
        memcpy(ptr(buf), ptr(s[0].input_buffer + s[0].next_read_idx), u64(to_read));
        s[0].next_read_idx = s[0].next_read_idx + to_read;
        buf = buf + to_read;
        n -= to_read;
        if n == 0 {
            return n;
        }
    }
    if not s[0].read {
        return i64(bad_readline(u));
    }
    if skip_consumed(u) < 0 {
        return -1;
    }
    if not s[0].readinto {
        data = call_with_size(s[0].read, n);
        if not data {
            return -1;
        }
        if not bytes_check(data) {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("read() returned non-bytes object (%R)"),
                ptr[PyObject](object_type(data))
            );
            object_decref(data);
            return -1;
        }
        if object_size(data) < n {
            object_decref(data);
            return i64(bad_readline(u));
        }
        memcpy(ptr(buf), ptr(bytes_data(data)), u64(n));
        object_decref(data);
        return n;
    }
    buf_obj = PyMemoryView_FromMemory(buf, n, UNPICKLE_BUF_WRITE);
    if not buf_obj {
        return -1;
    }
    read_size_obj = PyObject_CallOneArg(s[0].readinto, buf_obj);
    object_decref(buf_obj);
    if not read_size_obj {
        return -1;
    }
    read_size = PyLong_AsSsize_t(read_size_obj);
    object_decref(read_size_obj);
    if read_size < 0 {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("readinto() returned negative size")
            );
        }
        return -1;
    }
    if read_size < n {
        return i64(bad_readline(u));
    }
    return n;
}

impl copy_line(u: ptr[UnpicklerRec], line: ptr[u8], n: i64) -> (i64, ptr[u8]) {
    s = u.view(1);
    input_line = ptr[u8](PyMem_Realloc(ptr(s[0].input_line), u64(n + 1)));
    if not input_line {
        PyErr_NoMemory();
        return (-1, ptr[u8]());
    }
    memcpy(ptr(input_line), ptr(line), u64(n));
    (input_line + n).view(1)[0] = u8(0);
    s[0].input_line = input_line;
    return (n, input_line);
}

impl readline(u: ptr[UnpicklerRec]) -> (i64, ptr[u8]) {
    s = u.view(1);
    i = s[0].next_read_idx;
    while i < s[0].input_len {
        if (s[0].input_buffer + i).view(1)[0] == 10 {
            line_start = s[0].input_buffer + s[0].next_read_idx;
            num_read = i - s[0].next_read_idx + 1;
            s[0].next_read_idx = i + 1;
            return copy_line(u, line_start, num_read);
        }
        i += 1;
    }
    if not s[0].read {
        bad_readline(u);
        return (-1, ptr[u8]());
    }
    num_read = read_from_file(u, READ_WHOLE_LINE);
    if num_read < 0 {
        return (-1, ptr[u8]());
    }
    if num_read == 0 or (s[0].input_buffer + (num_read - 1)).view(1)[0] != 10 {
        bad_readline(u);
        return (-1, ptr[u8]());
    }
    s[0].next_read_idx = num_read;
    return copy_line(u, s[0].input_buffer, num_read);
}

impl memo_resize(u: ptr[UnpicklerRec], new_size: i64) -> i32 {
    s = u.view(1);
    memo = ptr[ptr[PyObject]](PyMem_Realloc(ptr(s[0].memo), u64(new_size) * u64(8)));
    if not memo {
        PyErr_NoMemory();
        return -1;
    }
    i = s[0].memo_size;
    while i < new_size {
        (memo + i).view(1)[0] = ptr[PyObject]();
        i += 1;
    }
    s[0].memo = memo;
    s[0].memo_size = new_size;
    return 0;
}

impl memo_get(u: ptr[UnpicklerRec], idx: i64) -> ptr[PyObject] {
    s = u.view(1);
    if idx < 0 or idx >= s[0].memo_size {
        return NULL;
    }
    return (s[0].memo + idx).view(1)[0];
}

impl memo_put(u: ptr[UnpicklerRec], idx: i64, value: ptr[PyObject]) -> i32 {
    s = u.view(1);
    if idx >= s[0].memo_size {
        new_size = idx * 2;
        if new_size < MEMO_SIZE {
            new_size = MEMO_SIZE;
        }
        if memo_resize(u, new_size) < 0 {
            return -1;
        }
    }
    cell = s[0].memo + idx;
    old_item = cell.view(1)[0];
    cell.view(1)[0] = object_new_ref(value);
    if old_item {
        object_decref(old_item);
    } else {
        s[0].memo_len = s[0].memo_len + 1;
    }
    return 0;
}

impl memo_new(size: i64) -> ptr[ptr[PyObject]] {
    memo = ptr[ptr[PyObject]](PyMem_Calloc(u64(size), u64(8)));
    if not memo {
        PyErr_NoMemory();
    }
    return memo;
}

impl memo_cleanup(u: ptr[UnpicklerRec]) {
    s = u.view(1);
    memo = s[0].memo;
    if not memo {
        return;
    }
    s[0].memo = ptr[ptr[PyObject]]();
    i = s[0].memo_size;
    while i > 0 {
        i -= 1;
        object_xdecref((memo + i).view(1)[0]);
    }
    PyMem_Free(ptr(memo));
}

impl calc_binsize(data: ptr[u8], nbytes: i64) -> i64 {
    x: u64 = 0;
    i: i64 = 0;
    while i < nbytes {
        x = x | (u64((data + i).view(1)[0]) << u64(8 * i));
        i += 1;
    }
    if x > u64(UNPICKLE_PY_SSIZE_T_MAX) {
        return -1;
    }
    return i64(x);
}

impl calc_binint(data: ptr[u8], nbytes: i64) -> i64 {
    x: i64 = 0;
    i: i64 = 0;
    while i < nbytes {
        x = x | (i64((data + i).view(1)[0]) << (8 * i));
        i += 1;
    }
    if nbytes == 4 and (x & 0x80000000) != 0 {
        x = x - 0x100000000;
    }
    return x;
}

impl find_class(
    u: ptr[UnpicklerRec], module_name: ptr[PyObject], global_name: ptr[PyObject]
) -> ptr[PyObject] {
    method = u.view(1)[0].find_class;
    if not method {
        return find_class_object(u, module_name, global_name);
    }
    args = PyTuple_Pack(2, module_name, global_name);
    if not args {
        return NULL;
    }
    result = PyObject_Call(method, args, NULL);
    object_decref(args);
    return result;
}

impl load_int(u: ptr[UnpicklerRec]) -> i32 {
    (n, line) = readline(u);
    if n < 0 {
        return -1;
    }
    if n < 2 {
        return bad_readline(u);
    }
    value = PyLong_FromString(line, ptr(), 10);
    if not value {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("could not convert string to int"));
        return -1;
    }
    if n == 3 {
        overflow: i32 = 0;
        x = PyLong_AsLongAndOverflow(value, &mut overflow);
        if overflow == 0 and (x == 0 or x == 1) {
            object_decref(value);
            return push(u, PyBool_FromLong(x));
        }
    }
    return push(u, value);
}

impl load_binintx(u: ptr[UnpicklerRec], nbytes: i64) -> i32 {
    data = read_n(u, nbytes);
    if not data {
        return -1;
    }
    return push(u, PyLong_FromLong(calc_binint(data, nbytes)));
}

impl load_long(u: ptr[UnpicklerRec]) -> i32 {
    (n, line) = readline(u);
    if n < 0 {
        return -1;
    }
    if n < 2 {
        return bad_readline(u);
    }
    if (line + (n - 2)).view(1)[0] == 76 {
        (line + (n - 2)).view(1)[0] = u8(0);
    }
    return push(u, PyLong_FromString(line, ptr(), 10));
}

impl load_counted_long(u: ptr[UnpicklerRec], nbytes: i64) -> i32 {
    data = read_n(u, nbytes);
    if not data {
        return -1;
    }
    size = calc_binint(data, nbytes);
    if size < 0 {
        PyErr_SetString(
            u.view(1)[0].error, ptr[u8]("LONG pickle has negative byte count")
        );
        return -1;
    }
    if size == 0 {
        return push(u, PyLong_FromLong(0));
    }
    pdata = read_n(u, size);
    if not pdata {
        return -1;
    }
    return push(u, _PyLong_FromByteArray(pdata, u64(size), 1, 1));
}

impl load_float(u: ptr[UnpicklerRec]) -> i32 {
    (n, line) = readline(u);
    if n < 0 {
        return -1;
    }
    if n < 2 {
        return bad_readline(u);
    }
    slots: own UnpicklerStack = UnpicklerStack();
    endptr = ptr[ptr[u8]](jacpy_stack_address(&mut slots));
    d = PyOS_string_to_double(ptr(line), ptr(endptr), PyExc_OverflowError);
    if d == -1.0 and PyErr_Occurred() {
        return -1;
    }
    end = endptr.view(1)[0].view(1)[0];
    if end != 10 and end != 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("could not convert string to float"));
        return -1;
    }
    return push(u, PyFloat_FromDouble(d));
}

impl load_binfloat(u: ptr[UnpicklerRec]) -> i32 {
    data = read_n(u, 8);
    if not data {
        return -1;
    }
    x = PyFloat_Unpack8(data, 0);
    if x == -1.0 and PyErr_Occurred() {
        return -1;
    }
    return push(u, PyFloat_FromDouble(x));
}

impl codec_text(name: ptr[PyObject], dflt: ptr[u8]) -> ptr[u8] {
    if name {
        return PyUnicode_AsUTF8(name);
    }
    return dflt;
}

impl wants_bytes(u: ptr[UnpicklerRec]) -> bool {
    encoding = u.view(1)[0].encoding;
    if not encoding {
        return False;
    }
    return _PyUnicode_EqualToASCIIString(encoding, ptr[u8]("bytes")) != 0;
}

impl load_string(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    (n, line) = readline(u);
    if n < 0 {
        return -1;
    }
    n -= 1;
    first = line.view(1)[0];
    if n >= 2
        and first == (line + (n - 1)).view(1)[0]
        and (first == 39 or first == 34) {
        n -= 2;
    } else {
        PyErr_SetString(
            s[0].error, ptr[u8]("the STRING opcode argument must be quoted")
        );
        return -1;
    }
    bytes_obj = PyBytes_DecodeEscape(ptr(line + 1), n, ptr[u8](), 0, ptr[u8]());
    if not bytes_obj {
        return -1;
    }
    if wants_bytes(u) {
        return push(u, bytes_obj);
    }
    encoding = codec_text(s[0].encoding, ptr[u8]("ASCII"));
    errors = codec_text(s[0].errors, ptr[u8]("strict"));
    if not encoding or not errors {
        object_decref(bytes_obj);
        return -1;
    }
    obj_ = PyUnicode_FromEncodedObject(bytes_obj, encoding, errors);
    object_decref(bytes_obj);
    return push(u, obj_);
}

impl load_counted_binstring(u: ptr[UnpicklerRec], nbytes: i64) -> i32 {
    s = u.view(1);
    data = read_n(u, nbytes);
    if not data {
        return -1;
    }
    size = calc_binint(data, nbytes);
    if size < 0 {
        PyErr_SetString(
            s[0].error, ptr[u8]("BINSTRING pickle has negative byte count")
        );
        return -1;
    }
    data = read_n(u, size);
    if not data {
        return -1;
    }
    if wants_bytes(u) {
        return push(u, PyBytes_FromStringAndSize(data, size));
    }
    encoding = codec_text(s[0].encoding, ptr[u8]("ASCII"));
    errors = codec_text(s[0].errors, ptr[u8]("strict"));
    if not encoding or not errors {
        return -1;
    }
    return push(u, PyUnicode_Decode(data, size, encoding, errors));
}

impl load_counted_binbytes(u: ptr[UnpicklerRec], nbytes: i64) -> i32 {
    data = read_n(u, nbytes);
    if not data {
        return -1;
    }
    size = calc_binsize(data, nbytes);
    if size < 0 {
        PyErr_Format(
            PyExc_OverflowError,
            ptr[u8]("BINBYTES exceeds system's maximum size of %zd bytes"),
            UNPICKLE_PY_SSIZE_T_MAX
        );
        return -1;
    }
    s = u.view(1);
    idx = s[0].next_read_idx;
    if size <= s[0].input_len - idx {
        s[0].next_read_idx = idx + size;
        return push(u, PyBytes_FromStringAndSize(s[0].input_buffer + idx, size));
    }
    bytes_obj = PyBytes_FromStringAndSize(ptr[u8](), size);
    if not bytes_obj {
        return -1;
    }
    if read_into(u, bytes_data(bytes_obj), size) < 0 {
        object_decref(bytes_obj);
        return -1;
    }
    return push(u, bytes_obj);
}

impl load_counted_bytearray(u: ptr[UnpicklerRec]) -> i32 {
    data = read_n(u, 8);
    if not data {
        return -1;
    }
    size = calc_binsize(data, 8);
    if size < 0 {
        PyErr_Format(
            PyExc_OverflowError,
            ptr[u8]("BYTEARRAY8 exceeds system's maximum size of %zd bytes"),
            UNPICKLE_PY_SSIZE_T_MAX
        );
        return -1;
    }
    bytearray = PyByteArray_FromStringAndSize(ptr[u8](), size);
    if not bytearray {
        return -1;
    }
    if size > 0 {
        target = ptr[PyByteArrayObject](bytearray).view(1)[0].ob_start;
        if read_into(u, target, size) < 0 {
            object_decref(bytearray);
            return -1;
        }
    }
    return push(u, bytearray);
}

impl load_next_buffer(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    if not s[0].buffers {
        PyErr_SetString(
            s[0].error,
            ptr[u8](
                "pickle stream refers to out-of-band data but no *buffers* argument was given"
            )
        );
        return -1;
    }
    buf = PyIter_Next(s[0].buffers);
    if not buf {
        if not PyErr_Occurred() {
            PyErr_SetString(s[0].error, ptr[u8]("not enough out-of-band buffers"));
        }
        return -1;
    }
    return push(u, buf);
}

impl load_readonly_buffer(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    n = s[0].stack_len;
    if n <= s[0].fence {
        return stack_underflow(u);
    }
    obj_ = stack_item(u, n - 1);
    view = PyMemoryView_FromObject(obj_);
    if not view {
        return -1;
    }
    buffer = ptr[Py_buffer](ptr[u8](view) + PyMemoryViewObject_VIEW);
    if buffer.view(1)[0].readonly == 0 {
        buffer.view(1)[0].readonly = 1;
        (s[0].stack + (n - 1)).view(1)[0] = view;
        object_decref(obj_);
    } else {
        object_decref(view);
    }
    return 0;
}

impl load_unicode(u: ptr[UnpicklerRec]) -> i32 {
    (n, line) = readline(u);
    if n < 0 {
        return -1;
    }
    if n < 1 {
        return bad_readline(u);
    }
    return push(u, PyUnicode_DecodeRawUnicodeEscape(line, n - 1, ptr[u8]()));
}

impl load_counted_binunicode(u: ptr[UnpicklerRec], nbytes: i64) -> i32 {
    data = read_n(u, nbytes);
    if not data {
        return -1;
    }
    size = calc_binsize(data, nbytes);
    if size < 0 {
        PyErr_Format(
            PyExc_OverflowError,
            ptr[u8]("BINUNICODE exceeds system's maximum size of %zd bytes"),
            UNPICKLE_PY_SSIZE_T_MAX
        );
        return -1;
    }
    data = read_n(u, size);
    if not data {
        return -1;
    }
    return push(u, PyUnicode_DecodeUTF8(data, size, ptr[u8]("surrogatepass")));
}

impl load_counted_tuple(u: ptr[UnpicklerRec], n: i64) -> i32 {
    s = u.view(1);
    if s[0].stack_len < n {
        return stack_underflow(u);
    }
    return push(u, poptuple(u, s[0].stack_len - n));
}

impl load_tuple(u: ptr[UnpicklerRec]) -> i32 {
    i = marker(u);
    if i < 0 {
        return -1;
    }
    return load_counted_tuple(u, u.view(1)[0].stack_len - i);
}

impl load_list(u: ptr[UnpicklerRec]) -> i32 {
    i = marker(u);
    if i < 0 {
        return -1;
    }
    return push(u, poplist(u, i));
}

impl load_dict(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    i = marker(u);
    if i < 0 {
        return -1;
    }
    j = s[0].stack_len;
    dict_ = PyDict_New();
    if not dict_ {
        return -1;
    }
    if (j - i) % 2 != 0 {
        PyErr_SetString(s[0].error, ptr[u8]("odd number of items for DICT"));
        object_decref(dict_);
        return -1;
    }
    k = i + 1;
    while k < j {
        if PyDict_SetItem(dict_, stack_item(u, k - 1), stack_item(u, k)) < 0 {
            object_decref(dict_);
            return -1;
        }
        k += 2;
    }
    stack_clear(u, i);
    return push(u, dict_);
}

impl load_frozenset(u: ptr[UnpicklerRec]) -> i32 {
    i = marker(u);
    if i < 0 {
        return -1;
    }
    items = poptuple(u, i);
    if not items {
        return -1;
    }
    frozen = PyFrozenSet_New(items);
    object_decref(items);
    return push(u, frozen);
}

impl instantiate(cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if object_size(args) == 0 and type_check(cls) {
        getinitargs_text = interned(getinitargs_text, ptr[u8]("__getinitargs__"));
        if not getinitargs_text {
            return NULL;
        }
        rc = PyObject_HasAttrWithError(cls, getinitargs_text);
        if rc < 0 {
            return NULL;
        }
        if rc == 0 {
            new_func = PyObject_GetAttr(cls, py_id(_Py_ID___new__));
            if not new_func {
                return NULL;
            }
            result = PyObject_CallOneArg(new_func, cls);
            object_decref(new_func);
            return result;
        }
    }
    return PyObject_CallObject(cls, args);
}

impl load_obj(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    i = marker(u);
    if i < 0 {
        return -1;
    }
    if s[0].stack_len - i < 1 {
        return stack_underflow(u);
    }
    args = poptuple(u, i + 1);
    if not args {
        return -1;
    }
    cls = pop(u);
    obj_ = NULL;
    if cls {
        obj_ = instantiate(cls, args);
        object_decref(cls);
    }
    object_decref(args);
    return push(u, obj_);
}

impl decode_name(line: ptr[u8], n: i64, ascii: bool) -> ptr[PyObject] {
    if ascii {
        return PyUnicode_DecodeASCII(ptr(line), n - 1, ptr[u8]("strict"));
    }
    return PyUnicode_DecodeUTF8(line, n - 1, ptr[u8]("strict"));
}

impl read_global(u: ptr[UnpicklerRec], ascii: bool) -> ptr[PyObject] {
    (n, line) = readline(u);
    if n < 0 {
        return NULL;
    }
    if n < 2 {
        bad_readline(u);
        return NULL;
    }
    module_name = decode_name(line, n, ascii);
    if not module_name {
        return NULL;
    }
    found = NULL;
    (m, name_line) = readline(u);
    if m >= 0 {
        if m < 2 {
            object_decref(module_name);
            bad_readline(u);
            return NULL;
        }
        class_name = decode_name(name_line, m, ascii);
        if class_name {
            found = find_class(u, module_name, class_name);
            object_decref(class_name);
        }
    }
    object_decref(module_name);
    return found;
}

impl load_inst(u: ptr[UnpicklerRec]) -> i32 {
    i = marker(u);
    if i < 0 {
        return -1;
    }
    cls = read_global(u, True);
    if not cls {
        return -1;
    }
    obj_ = NULL;
    args = poptuple(u, i);
    if args {
        obj_ = instantiate(cls, args);
        object_decref(args);
    }
    object_decref(cls);
    return push(u, obj_);
}

impl newobj_error(
    u: ptr[UnpicklerRec], use_kwargs: bool, message: ptr[u8], arg: ptr[PyObject]
) {
    kind = ptr[u8]("NEWOBJ_EX") if use_kwargs else ptr[u8]("NEWOBJ");
    PyErr_Format(u.view(1)[0].error, message, kind, tp_name_of(arg));
}

impl load_newobj(u: ptr[UnpicklerRec], use_kwargs: bool) -> i32 {
    kwargs = NULL;
    if use_kwargs {
        kwargs = pop(u);
        if not kwargs {
            return -1;
        }
    }
    args = pop(u);
    if not args {
        object_xdecref(kwargs);
        return -1;
    }
    cls = pop(u);
    if not cls {
        object_xdecref(kwargs);
        object_decref(args);
        return -1;
    }
    obj_ = NULL;
    if not type_check(cls) {
        newobj_error(
            u, use_kwargs, ptr[u8]("%s class argument must be a type, not %.200s"), cls
        );
    } elif int(ptr[PyTypeObject](cls).view(1)[0].tp_new) == 0 {
        newobj_error(
            u,
            use_kwargs,
            ptr[u8]("%s class argument '%.200s' doesn't have __new__"),
            cls
        );
    } elif not tuple_check(args) {
        newobj_error(
            u, use_kwargs, ptr[u8]("%s args argument must be a tuple, not %.200s"), args
        );
    } elif use_kwargs and not dict_check(kwargs) {
        newobj_error(
            u,
            use_kwargs,
            ptr[u8]("%s kwargs argument must be a dict, not %.200s"),
            kwargs
        );
    } else {
        obj_ = ptr[PyTypeObject](cls).view(1)[0].tp_new(
            ptr[PyTypeObject](cls), args, kwargs
        );
    }
    object_xdecref(kwargs);
    object_decref(args);
    object_decref(cls);
    if not obj_ {
        return -1;
    }
    return push(u, obj_);
}

impl load_global(u: ptr[UnpicklerRec]) -> i32 {
    found = read_global(u, False);
    if not found {
        return -1;
    }
    return push(u, found);
}

impl load_stack_global(u: ptr[UnpicklerRec]) -> i32 {
    global_name = pop(u);
    if not global_name {
        return -1;
    }
    module_name = pop(u);
    if not module_name {
        object_decref(global_name);
        return -1;
    }
    if not unicode_check_exact(module_name) or not unicode_check_exact(global_name) {
        PyErr_SetString(u.view(1)[0].error, ptr[u8]("STACK_GLOBAL requires str"));
        object_decref(global_name);
        object_decref(module_name);
        return -1;
    }
    found = find_class(u, module_name, global_name);
    object_decref(global_name);
    object_decref(module_name);
    return push(u, found);
}

impl call_persistent_load(u: ptr[UnpicklerRec], pid: ptr[PyObject]) -> ptr[PyObject] {
    method = u.view(1)[0].persistent_load;
    if not method {
        PyErr_SetString(
            u.view(1)[0].error,
            ptr[u8](
                "A load persistent id instruction was encountered, but no persistent_load function was specified."
            )
        );
        return NULL;
    }
    return PyObject_CallOneArg(method, pid);
}

impl load_persid(u: ptr[UnpicklerRec]) -> i32 {
    (n, line) = readline(u);
    if n < 0 {
        return -1;
    }
    if n < 1 {
        return bad_readline(u);
    }
    pid = PyUnicode_DecodeASCII(ptr(line), n - 1, ptr[u8]("strict"));
    if not pid {
        if PyErr_ExceptionMatches(PyExc_UnicodeDecodeError) != 0 {
            PyErr_SetString(
                u.view(1)[0].error,
                ptr[u8]("persistent IDs in protocol 0 must be ASCII strings")
            );
        }
        return -1;
    }
    obj_ = call_persistent_load(u, pid);
    object_decref(pid);
    return push(u, obj_);
}

impl load_binpersid(u: ptr[UnpicklerRec]) -> i32 {
    pid = pop(u);
    if not pid {
        return -1;
    }
    obj_ = call_persistent_load(u, pid);
    object_decref(pid);
    return push(u, obj_);
}

impl load_pop(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    n = s[0].stack_len;
    nm = s[0].num_marks;
    if nm > 0 and (s[0].marks + (nm - 1)).view(1)[0] == n {
        nm -= 1;
        s[0].num_marks = nm;
        s[0].mark_set = i32(1) if nm != 0 else i32(0);
        if nm != 0 {
            s[0].fence = (s[0].marks + (nm - 1)).view(1)[0];
        } else {
            s[0].fence = 0;
        }
    } elif n <= s[0].fence {
        return stack_underflow(u);
    } else {
        n -= 1;
        object_decref(stack_item(u, n));
        s[0].stack_len = n;
    }
    return 0;
}

impl load_pop_mark(u: ptr[UnpicklerRec]) -> i32 {
    i = marker(u);
    if i < 0 {
        return -1;
    }
    stack_clear(u, i);
    return 0;
}

impl load_dup(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    n = s[0].stack_len;
    if n <= s[0].fence {
        return stack_underflow(u);
    }
    return push_new_ref(u, stack_item(u, n - 1));
}

impl memo_missing(u: ptr[UnpicklerRec], idx: i64) -> i32 {
    if not PyErr_Occurred() {
        PyErr_Format(
            u.view(1)[0].error, ptr[u8]("Memo value not found at index %ld"), idx
        );
    }
    return -1;
}

impl load_get(u: ptr[UnpicklerRec]) -> i32 {
    (n, line) = readline(u);
    if n < 0 {
        return -1;
    }
    if n < 2 {
        return bad_readline(u);
    }
    key = PyLong_FromString(line, ptr(), 10);
    if not key {
        return -1;
    }
    idx = PyLong_AsSsize_t(key);
    object_decref(key);
    if idx == -1 and PyErr_Occurred() {
        return -1;
    }
    value = memo_get(u, idx);
    if not value {
        return memo_missing(u, idx);
    }
    return push_new_ref(u, value);
}

impl load_binget(u: ptr[UnpicklerRec], nbytes: i64) -> i32 {
    data = read_n(u, nbytes);
    if not data {
        return -1;
    }
    idx = calc_binsize(data, nbytes);
    value = memo_get(u, idx);
    if not value {
        return memo_missing(u, idx);
    }
    return push_new_ref(u, value);
}

impl load_extension(u: ptr[UnpicklerRec], nbytes: i64) -> i32 {
    data = read_n(u, nbytes);
    if not data {
        return -1;
    }
    code = calc_binint(data, nbytes);
    if code <= 0 {
        PyErr_SetString(u.view(1)[0].error, ptr[u8]("EXT specifies code <= 0"));
        return -1;
    }
    py_code = PyLong_FromLong(code);
    if not py_code {
        return -1;
    }
    cache = state_object(u, SLOT_EXTENSION_CACHE);
    obj_ = PyDict_GetItemWithError(cache, py_code);
    if obj_ {
        object_decref(py_code);
        return push_new_ref(u, obj_);
    }
    if PyErr_Occurred() {
        object_decref(py_code);
        return -1;
    }
    pair = PyDict_GetItemWithError(state_object(u, SLOT_INVERTED_REGISTRY), py_code);
    if not pair {
        object_decref(py_code);
        if not PyErr_Occurred() {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("unregistered extension code %ld"), code
            );
        }
        return -1;
    }
    if not tuple_check(pair)
        or object_size(pair) != 2
        or not unicode_check(tuple_get_item(pair, 0))
        or not unicode_check(tuple_get_item(pair, 1)) {
        object_decref(py_code);
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("_inverted_registry[%ld] isn't a 2-tuple of strings"),
            code
        );
        return -1;
    }
    obj_ = find_class(u, tuple_get_item(pair, 0), tuple_get_item(pair, 1));
    if not obj_ {
        object_decref(py_code);
        return -1;
    }
    status = PyDict_SetItem(cache, py_code, obj_);
    object_decref(py_code);
    if status < 0 {
        object_decref(obj_);
        return -1;
    }
    return push(u, obj_);
}

impl top_value(u: ptr[UnpicklerRec]) -> ptr[PyObject] {
    s = u.view(1);
    if s[0].stack_len <= s[0].fence {
        stack_underflow(u);
        return NULL;
    }
    return stack_item(u, s[0].stack_len - 1);
}

impl load_put(u: ptr[UnpicklerRec]) -> i32 {
    (n, line) = readline(u);
    if n < 0 {
        return -1;
    }
    if n < 2 {
        return bad_readline(u);
    }
    value = top_value(u);
    if not value {
        return -1;
    }
    key = PyLong_FromString(line, ptr(), 10);
    if not key {
        return -1;
    }
    idx = PyLong_AsSsize_t(key);
    object_decref(key);
    if idx < 0 {
        if not PyErr_Occurred() {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("negative PUT argument"));
        }
        return -1;
    }
    return memo_put(u, idx, value);
}

impl load_binput(u: ptr[UnpicklerRec], nbytes: i64) -> i32 {
    data = read_n(u, nbytes);
    if not data {
        return -1;
    }
    value = top_value(u);
    if not value {
        return -1;
    }
    idx = calc_binsize(data, nbytes);
    if idx < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("negative LONG_BINPUT argument"));
        return -1;
    }
    return memo_put(u, idx, value);
}

impl load_memoize(u: ptr[UnpicklerRec]) -> i32 {
    value = top_value(u);
    if not value {
        return -1;
    }
    return memo_put(u, u.view(1)[0].memo_len, value);
}

impl do_append(u: ptr[UnpicklerRec], x: i64) -> i32 {
    s = u.view(1);
    n = s[0].stack_len;
    if x > n or x <= s[0].fence {
        return stack_underflow(u);
    }
    if n == x {
        return 0;
    }
    lst = stack_item(u, x - 1);
    if list_check_exact(lst) {
        slice = poplist(u, x);
        if not slice {
            return -1;
        }
        list_len = object_size(lst);
        ret = PyList_SetSlice(lst, list_len, list_len, slice);
        object_decref(slice);
        return ret;
    }
    extend_func = NULL;
    if PyObject_GetOptionalAttr(lst, py_id(_Py_ID_extend), &mut extend_func) < 0 {
        return -1;
    }
    if extend_func {
        slice = poplist(u, x);
        if not slice {
            object_decref(extend_func);
            return -1;
        }
        result = PyObject_CallOneArg(extend_func, slice);
        object_decref(slice);
        object_decref(extend_func);
        if not result {
            return -1;
        }
        object_decref(result);
        return 0;
    }
    append_func = PyObject_GetAttr(lst, py_id(_Py_ID_append));
    if not append_func {
        return -1;
    }
    i = x;
    while i < n {
        value = stack_item(u, i);
        result = PyObject_CallOneArg(append_func, value);
        object_decref(value);
        if not result {
            stack_clear(u, i + 1);
            s[0].stack_len = x;
            object_decref(append_func);
            return -1;
        }
        object_decref(result);
        i += 1;
    }
    s[0].stack_len = x;
    object_decref(append_func);
    return 0;
}

impl load_appends(u: ptr[UnpicklerRec]) -> i32 {
    i = marker(u);
    if i < 0 {
        return -1;
    }
    return do_append(u, i);
}

impl do_setitems(u: ptr[UnpicklerRec], x: i64) -> i32 {
    s = u.view(1);
    n = s[0].stack_len;
    if x > n or x <= s[0].fence {
        return stack_underflow(u);
    }
    if n == x {
        return 0;
    }
    if (n - x) % 2 != 0 {
        PyErr_SetString(s[0].error, ptr[u8]("odd number of items for SETITEMS"));
        return -1;
    }
    dict_ = stack_item(u, x - 1);
    status: i32 = 0;
    i = x + 1;
    while i < n {
        if PyObject_SetItem(dict_, stack_item(u, i - 1), stack_item(u, i)) < 0 {
            status = -1;
            break;
        }
        i += 2;
    }
    stack_clear(u, x);
    return status;
}

impl load_setitems(u: ptr[UnpicklerRec]) -> i32 {
    i = marker(u);
    if i < 0 {
        return -1;
    }
    return do_setitems(u, i);
}

impl load_additems(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    mark = marker(u);
    if mark < 0 {
        return -1;
    }
    n = s[0].stack_len;
    if mark > n or mark <= s[0].fence {
        return stack_underflow(u);
    }
    if n == mark {
        return 0;
    }
    set_obj = stack_item(u, mark - 1);
    if set_check(set_obj) {
        items = poptuple(u, mark);
        if not items {
            return -1;
        }
        status = _PySet_Update(set_obj, items);
        object_decref(items);
        return status;
    }
    add_text = interned(add_text, ptr[u8]("add"));
    if not add_text {
        return -1;
    }
    add_func = PyObject_GetAttr(set_obj, add_text);
    if not add_func {
        return -1;
    }
    i = mark;
    while i < n {
        item = stack_item(u, i);
        result = PyObject_CallOneArg(add_func, item);
        object_decref(item);
        if not result {
            stack_clear(u, i + 1);
            s[0].stack_len = mark;
            object_decref(add_func);
            return -1;
        }
        object_decref(result);
        i += 1;
    }
    s[0].stack_len = mark;
    object_decref(add_func);
    return 0;
}

impl build_dict_state(
    u: ptr[UnpicklerRec], inst: ptr[PyObject], state: ptr[PyObject]
) -> i32 {
    if not dict_check(state) {
        PyErr_SetString(u.view(1)[0].error, ptr[u8]("state is not a dictionary"));
        return -1;
    }
    dict_ = PyObject_GetAttr(inst, py_id(_Py_ID___dict__));
    if not dict_ {
        return -1;
    }
    i: i64 = 0;
    d_key = NULL;
    d_value = NULL;
    while PyDict_Next(state, &mut i, &mut d_key, &mut d_value) != 0 {
        key = object_new_ref(d_key);
        if unicode_check_exact(key) {
            _PyUnicode_InternMortal(current_interp(), &mut key);
        }
        if PyObject_SetItem(dict_, key, d_value) < 0 {
            object_decref(key);
            object_decref(dict_);
            return -1;
        }
        object_decref(key);
    }
    object_decref(dict_);
    return 0;
}

impl build_slot_state(
    u: ptr[UnpicklerRec], inst: ptr[PyObject], slotstate: ptr[PyObject]
) -> i32 {
    if not dict_check(slotstate) {
        PyErr_SetString(u.view(1)[0].error, ptr[u8]("slot state is not a dictionary"));
        return -1;
    }
    i: i64 = 0;
    d_key = NULL;
    d_value = NULL;
    while PyDict_Next(slotstate, &mut i, &mut d_key, &mut d_value) != 0 {
        if PyObject_SetAttr(inst, d_key, d_value) < 0 {
            return -1;
        }
    }
    return 0;
}

impl load_build(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    if s[0].stack_len - 2 < s[0].fence {
        return stack_underflow(u);
    }
    state = pop(u);
    if not state {
        return -1;
    }
    inst = stack_item(u, s[0].stack_len - 1);
    setstate = NULL;
    if PyObject_GetOptionalAttr(inst, py_id(_Py_ID___setstate__), &mut setstate) < 0 {
        object_decref(state);
        return -1;
    }
    if setstate {
        result = PyObject_CallOneArg(setstate, state);
        object_decref(state);
        object_decref(setstate);
        if not result {
            return -1;
        }
        object_decref(result);
        return 0;
    }
    slotstate = NULL;
    if tuple_check(state) and object_size(state) == 2 {
        tmp = state;
        state = object_new_ref(tuple_get_item(tmp, 0));
        slotstate = object_new_ref(tuple_get_item(tmp, 1));
        object_decref(tmp);
    }
    status: i32 = 0;
    if state != Py_None {
        status = build_dict_state(u, inst, state);
    }
    if status == 0 and slotstate {
        status = build_slot_state(u, inst, slotstate);
    }
    object_decref(state);
    object_xdecref(slotstate);
    return status;
}

impl load_mark(u: ptr[UnpicklerRec]) -> i32 {
    s = u.view(1);
    nm = s[0].num_marks;
    if nm >= s[0].marks_size {
        alloc = (nm << 1) + 20;
        marks = ptr[i64](PyMem_Realloc(ptr(s[0].marks), u64(alloc) * u64(8)));
        if not marks {
            PyErr_NoMemory();
            return -1;
        }
        s[0].marks = marks;
        s[0].marks_size = alloc;
    }
    s[0].mark_set = 1;
    n = s[0].stack_len;
    s[0].fence = n;
    (s[0].marks + nm).view(1)[0] = n;
    s[0].num_marks = nm + 1;
    return 0;
}

impl load_reduce(u: ptr[UnpicklerRec]) -> i32 {
    argtup = pop(u);
    if not argtup {
        return -1;
    }
    callable = pop(u);
    obj_ = NULL;
    if callable {
        obj_ = PyObject_CallObject(callable, argtup);
        object_decref(callable);
    }
    object_decref(argtup);
    return push(u, obj_);
}

impl load_proto(u: ptr[UnpicklerRec]) -> i32 {
    data = read_n(u, 1);
    if not data {
        return -1;
    }
    i = i32(data.view(1)[0]);
    if i <= HIGHEST_PROTOCOL {
        u.view(1)[0].proto = i;
        return 0;
    }
    PyErr_Format(PyExc_ValueError, ptr[u8]("unsupported pickle protocol: %d"), i);
    return -1;
}

impl load_frame(u: ptr[UnpicklerRec]) -> i32 {
    data = read_n(u, 8);
    if not data {
        return -1;
    }
    frame_len = calc_binsize(data, 8);
    if frame_len < 0 {
        PyErr_Format(
            PyExc_OverflowError,
            ptr[u8]("FRAME length exceeds system's maximum of %zd bytes"),
            UNPICKLE_PY_SSIZE_T_MAX
        );
        return -1;
    }
    if not read_n(u, frame_len) {
        return -1;
    }
    s = u.view(1);
    s[0].next_read_idx = s[0].next_read_idx - frame_len;
    return 0;
}

impl invalid_key(u: ptr[UnpicklerRec], c: u8) -> i32 {
    if c >= 32 and c <= 126 and c != 39 and c != 92 {
        PyErr_Format(u.view(1)[0].error, ptr[u8]("invalid load key, '%c'."), i32(c));
    } else {
        PyErr_Format(
            u.view(1)[0].error, ptr[u8]("invalid load key, '\\x%02x'."), i32(c)
        );
    }
    return -1;
}

impl load_rare(u: ptr[UnpicklerRec], op: u8) -> i32 {
    if op == OP_BINUNICODE {
        return load_counted_binunicode(u, 4);
    }
    if op == OP_BINUNICODE8 {
        return load_counted_binunicode(u, 8);
    }
    if op == OP_SHORT_BINBYTES {
        return load_counted_binbytes(u, 1);
    }
    if op == OP_BINBYTES {
        return load_counted_binbytes(u, 4);
    }
    if op == OP_BINBYTES8 {
        return load_counted_binbytes(u, 8);
    }
    if op == OP_BYTEARRAY8 {
        return load_counted_bytearray(u);
    }
    if op == OP_NEXT_BUFFER {
        return load_next_buffer(u);
    }
    if op == OP_READONLY_BUFFER {
        return load_readonly_buffer(u);
    }
    if op == OP_SHORT_BINSTRING {
        return load_counted_binstring(u, 1);
    }
    if op == OP_BINSTRING {
        return load_counted_binstring(u, 4);
    }
    if op == OP_STRING {
        return load_string(u);
    }
    if op == OP_UNICODE {
        return load_unicode(u);
    }
    if op == OP_INT {
        return load_int(u);
    }
    if op == OP_LONG {
        return load_long(u);
    }
    if op == OP_LONG1 {
        return load_counted_long(u, 1);
    }
    if op == OP_LONG4 {
        return load_counted_long(u, 4);
    }
    if op == OP_FLOAT {
        return load_float(u);
    }
    if op == OP_TUPLE {
        return load_tuple(u);
    }
    if op == OP_LIST {
        return load_list(u);
    }
    if op == OP_DICT {
        return load_dict(u);
    }
    if op == OP_EMPTY_SET {
        return push(u, PySet_New(NULL));
    }
    if op == OP_ADDITEMS {
        return load_additems(u);
    }
    if op == OP_FROZENSET {
        return load_frozenset(u);
    }
    if op == OP_OBJ {
        return load_obj(u);
    }
    if op == OP_INST {
        return load_inst(u);
    }
    if op == OP_NEWOBJ {
        return load_newobj(u, False);
    }
    if op == OP_NEWOBJ_EX {
        return load_newobj(u, True);
    }
    if op == OP_GLOBAL {
        return load_global(u);
    }
    if op == OP_DUP {
        return load_dup(u);
    }
    if op == OP_GET {
        return load_get(u);
    }
    if op == OP_PUT {
        return load_put(u);
    }
    if op == OP_POP {
        return load_pop(u);
    }
    if op == OP_POP_MARK {
        return load_pop_mark(u);
    }
    if op == OP_PERSID {
        return load_persid(u);
    }
    if op == OP_BINPERSID {
        return load_binpersid(u);
    }
    if op == OP_PROTO {
        return load_proto(u);
    }
    if op == OP_EXT1 {
        return load_extension(u, 1);
    }
    if op == OP_EXT2 {
        return load_extension(u, 2);
    }
    if op == OP_EXT4 {
        return load_extension(u, 4);
    }
    return invalid_key(u, op);
}

impl load(u: ptr[UnpicklerRec]) -> ptr[PyObject] {
    s = u.view(1);
    s[0].num_marks = 0;
    s[0].mark_set = 0;
    s[0].fence = 0;
    s[0].proto = 0;
    if s[0].stack_len != 0 {
        stack_clear(u, 0);
    }
    while True {
        op: u8 = 0;
        idx = s[0].next_read_idx;
        if idx < s[0].input_len {
            op = (s[0].input_buffer + idx).view(1)[0];
            s[0].next_read_idx = idx + 1;
        } else {
            data = read_impl(u, 1);
            if not data {
                if PyErr_ExceptionMatches(s[0].error) != 0 {
                    PyErr_Format(PyExc_EOFError, ptr[u8]("Ran out of input"));
                }
                return NULL;
            }
            op = data.view(1)[0];
        }
        status: i32 = 0;
        if op == OP_SHORT_BINUNICODE {
            status = load_counted_binunicode(u, 1);
        } elif op == OP_MEMOIZE {
            status = load_memoize(u);
        } elif op == OP_BININT1 {
            status = load_binintx(u, 1);
        } elif op == OP_BINGET {
            status = load_binget(u, 1);
        } elif op == OP_MARK {
            status = load_mark(u);
        } elif op == OP_BININT {
            status = load_binintx(u, 4);
        } elif op == OP_BININT2 {
            status = load_binintx(u, 2);
        } elif op == OP_EMPTY_LIST {
            status = push(u, PyList_New(0));
        } elif op == OP_EMPTY_DICT {
            status = push(u, PyDict_New());
        } elif op == OP_APPENDS {
            status = load_appends(u);
        } elif op == OP_SETITEMS {
            status = load_setitems(u);
        } elif op == OP_BINPUT {
            status = load_binput(u, 1);
        } elif op == OP_LONG_BINPUT {
            status = load_binput(u, 4);
        } elif op == OP_LONG_BINGET {
            status = load_binget(u, 4);
        } elif op == OP_TUPLE1 {
            status = load_counted_tuple(u, 1);
        } elif op == OP_TUPLE2 {
            status = load_counted_tuple(u, 2);
        } elif op == OP_TUPLE3 {
            status = load_counted_tuple(u, 3);
        } elif op == OP_EMPTY_TUPLE {
            status = load_counted_tuple(u, 0);
        } elif op == OP_NONE {
            status = push_new_ref(u, Py_None);
        } elif op == OP_NEWTRUE {
            status = push_new_ref(u, ptr[PyObject](addressof(_Py_TrueStruct)));
        } elif op == OP_NEWFALSE {
            status = push_new_ref(u, ptr[PyObject](addressof(_Py_FalseStruct)));
        } elif op == OP_BINFLOAT {
            status = load_binfloat(u);
        } elif op == OP_APPEND {
            if s[0].stack_len - 1 <= s[0].fence {
                status = stack_underflow(u);
            } else {
                status = do_append(u, s[0].stack_len - 1);
            }
        } elif op == OP_SETITEM {
            status = do_setitems(u, s[0].stack_len - 2);
        } elif op == OP_FRAME {
            status = load_frame(u);
        } elif op == OP_STACK_GLOBAL {
            status = load_stack_global(u);
        } elif op == OP_REDUCE {
            status = load_reduce(u);
        } elif op == OP_BUILD {
            status = load_build(u);
        } elif op == OP_STOP {
            break;
        } else {
            status = load_rare(u, op);
        }
        if status < 0 {
            return NULL;
        }
    }
    if PyErr_Occurred() {
        return NULL;
    }
    if skip_consumed(u) < 0 {
        return NULL;
    }
    return pop(u);
}

impl unpickler_new -> ptr[UnpicklerRec] {
    u = ptr[UnpicklerRec](PyMem_Calloc(u64(1), UNPICKLER_REC_SIZE));
    if not u {
        PyErr_NoMemory();
    }
    return u;
}

impl clear_slot(slot: ptr[PyObject]) -> ptr[PyObject] {
    object_xdecref(slot);
    return ptr[PyObject]();
}

impl unpickler_release(u: ptr[UnpicklerRec]) {
    s = u.view(1);
    s[0].readline = clear_slot(s[0].readline);
    s[0].readinto = clear_slot(s[0].readinto);
    s[0].read = clear_slot(s[0].read);
    s[0].peek = clear_slot(s[0].peek);
    if s[0].stack {
        stack_clear(u, 0);
        PyMem_Free(ptr(s[0].stack));
        s[0].stack = ptr[ptr[PyObject]]();
        s[0].stack_allocated = 0;
    }
    s[0].persistent_load = clear_slot(s[0].persistent_load);
    s[0].find_class = clear_slot(s[0].find_class);
    s[0].buffers = clear_slot(s[0].buffers);
    release_input(u);
    if s[0].view {
        PyMem_Free(ptr(s[0].view));
        s[0].view = ptr[Py_buffer]();
    }
    s[0].input_len = 0;
    s[0].next_read_idx = 0;
    s[0].prefetched_idx = 0;
    memo_cleanup(u);
    s[0].memo_size = 0;
    s[0].memo_len = 0;
    if s[0].marks {
        PyMem_Free(ptr(s[0].marks));
        s[0].marks = ptr[i64]();
    }
    s[0].marks_size = 0;
    s[0].num_marks = 0;
    if s[0].input_line {
        PyMem_Free(ptr(s[0].input_line));
        s[0].input_line = ptr[u8]();
    }
    s[0].encoding = clear_slot(s[0].encoding);
    s[0].errors = clear_slot(s[0].errors);
    s[0].error = clear_slot(s[0].error);
}

impl unpickler_free(u: ptr[UnpicklerRec]) {
    unpickler_release(u);
    PyMem_Free(ptr(u));
}

impl visit_slot(value: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    if not value {
        return 0;
    }
    return visit_reference(value, visitor, context);
}

impl unpickler_traverse(u: ptr[UnpicklerRec], visitor: ptr, context: ptr) -> i32 {
    s = u.view(1);
    status = visit_slot(s[0].readline, visitor, context);
    if status == 0 {
        status = visit_slot(s[0].readinto, visitor, context);
    }
    if status == 0 {
        status = visit_slot(s[0].read, visitor, context);
    }
    if status == 0 {
        status = visit_slot(s[0].peek, visitor, context);
    }
    if status == 0 {
        status = visit_slot(s[0].persistent_load, visitor, context);
    }
    if status == 0 {
        status = visit_slot(s[0].find_class, visitor, context);
    }
    if status == 0 {
        status = visit_slot(s[0].buffers, visitor, context);
    }
    i: i64 = 0;
    while status == 0 and i < s[0].stack_len {
        status = visit_slot(stack_item(u, i), visitor, context);
        i += 1;
    }
    memo = s[0].memo;
    if status == 0 and memo {
        i = s[0].memo_size;
        while i > 0 and status == 0 {
            i -= 1;
            status = visit_slot((memo + i).view(1)[0], visitor, context);
        }
    }
    return status;
}

impl unpickler_prepare(
    u: ptr[UnpicklerRec],
    module: ptr[PyObject],
    fix_imports: bool,
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    buffers: ptr[PyObject]
) -> i32 {
    s = u.view(1);
    s[0].module = module;
    if not s[0].error {
        s[0].error = object_new_ref(
            jacpy_binding_state_get(module, SLOT_UNPICKLING_ERROR)
        );
    }
    s[0].encoding = clear_slot(s[0].encoding);
    s[0].errors = clear_slot(s[0].errors);
    if encoding {
        s[0].encoding = object_new_ref(encoding);
    }
    if errors {
        s[0].errors = object_new_ref(errors);
    }
    s[0].buffers = clear_slot(s[0].buffers);
    if buffers and buffers != Py_None {
        s[0].buffers = PyObject_GetIter(buffers);
        if not s[0].buffers {
            return -1;
        }
    }
    s[0].fix_imports = i32(1) if fix_imports else i32(0);
    if not s[0].stack {
        s[0].stack = ptr[ptr[PyObject]](PyMem_Malloc(u64(STACK_SIZE) * u64(8)));
        if not s[0].stack {
            PyErr_NoMemory();
            return -1;
        }
        s[0].stack_allocated = STACK_SIZE;
        s[0].stack_len = 0;
    }
    if not s[0].memo {
        s[0].memo = memo_new(MEMO_SIZE);
        if not s[0].memo {
            return -1;
        }
        s[0].memo_size = MEMO_SIZE;
        s[0].memo_len = 0;
    }
    s[0].proto = 0;
    return 0;
}

impl set_input_stream(u: ptr[UnpicklerRec], file: ptr[PyObject]) -> i32 {
    s = u.view(1);
    peek_m = NULL;
    readinto_m = NULL;
    read_m = NULL;
    readline_m = NULL;
    status: i32 = 0;
    if PyObject_GetOptionalAttr(file, py_id(_Py_ID_peek), &mut peek_m) < 0
        or PyObject_GetOptionalAttr(file, py_id(_Py_ID_readinto), &mut readinto_m) < 0
        or PyObject_GetOptionalAttr(file, py_id(_Py_ID_read), &mut read_m) < 0
        or PyObject_GetOptionalAttr(file, py_id(_Py_ID_readline), &mut readline_m)
            < 0 {
        status = -1;
    } elif not readline_m or not read_m {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("file must have 'read' and 'readline' attributes")
        );
        status = -1;
    }
    if status < 0 {
        object_xdecref(peek_m);
        object_xdecref(readinto_m);
        object_xdecref(read_m);
        object_xdecref(readline_m);
        return -1;
    }
    s[0].peek = peek_m;
    s[0].readinto = readinto_m;
    s[0].read = read_m;
    s[0].readline = readline_m;
    return 0;
}

impl unpickler_init(
    u: ptr[UnpicklerRec],
    module: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    buffers: ptr[PyObject]
) -> i32 {
    if u.view(1)[0].read {
        unpickler_release(u);
    }
    if set_input_stream(u, file) < 0 {
        return -1;
    }
    return unpickler_prepare(u, module, fix_imports, encoding, errors, buffers);
}

impl unpickler_run(
    u: ptr[UnpicklerRec], find_class: ptr[PyObject], persistent_load: ptr[PyObject]
) -> ptr[PyObject] {
    s = u.view(1);
    s[0].find_class = clear_slot(s[0].find_class);
    s[0].persistent_load = clear_slot(s[0].persistent_load);
    if find_class {
        s[0].find_class = object_new_ref(find_class);
    }
    if persistent_load {
        s[0].persistent_load = object_new_ref(persistent_load);
    }
    result = load(u);
    s[0].find_class = clear_slot(s[0].find_class);
    s[0].persistent_load = clear_slot(s[0].persistent_load);
    return result;
}

impl unpickler_memo_copy(u: ptr[UnpicklerRec]) -> ptr[PyObject] {
    new_memo = PyDict_New();
    if not new_memo {
        return NULL;
    }
    s = u.view(1);
    i: i64 = 0;
    while i < s[0].memo_size {
        value = (s[0].memo + i).view(1)[0];
        if value {
            key = PyLong_FromSsize_t(i);
            if not key {
                object_decref(new_memo);
                return NULL;
            }
            status = PyDict_SetItem(new_memo, key, value);
            object_decref(key);
            if status < 0 {
                object_decref(new_memo);
                return NULL;
            }
        }
        i += 1;
    }
    return new_memo;
}

impl unpickler_memo_clear(u: ptr[UnpicklerRec]) -> i32 {
    memo_cleanup(u);
    s = u.view(1);
    s[0].memo_size = 0;
    s[0].memo_len = 0;
    s[0].memo = memo_new(MEMO_SIZE);
    if not s[0].memo {
        return -1;
    }
    s[0].memo_size = MEMO_SIZE;
    return 0;
}

impl unpickler_memo_set(u: ptr[UnpicklerRec], obj_: ptr[PyObject]) -> i32 {
    if not dict_check(obj_) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "'memo' attribute must be an UnpicklerMemoProxy object or dict, not %.200s"
            ),
            tp_name_of(obj_)
        );
        return -1;
    }
    s = u.view(1);
    old_memo = s[0].memo;
    old_size = s[0].memo_size;
    old_len = s[0].memo_len;
    s[0].memo = memo_new(MEMO_SIZE);
    if not s[0].memo {
        s[0].memo = old_memo;
        return -1;
    }
    s[0].memo_size = MEMO_SIZE;
    s[0].memo_len = 0;
    status: i32 = 0;
    pos: i64 = 0;
    key = NULL;
    value = NULL;
    while status == 0 and PyDict_Next(obj_, &mut pos, &mut key, &mut value) != 0 {
        if not long_check(key) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("memo key must be integers"));
            status = -1;
        } else {
            idx = PyLong_AsSsize_t(key);
            if idx == -1 and PyErr_Occurred() {
                status = -1;
            } elif idx < 0 {
                PyErr_SetString(
                    PyExc_ValueError, ptr[u8]("memo key must be positive integers.")
                );
                status = -1;
            } else {
                status = memo_put(u, idx, value);
            }
        }
    }
    new_memo = s[0].memo;
    new_size = s[0].memo_size;
    new_len = s[0].memo_len;
    if status < 0 {
        s[0].memo = old_memo;
        s[0].memo_size = old_size;
        s[0].memo_len = old_len;
        old_memo = new_memo;
        old_size = new_size;
    } else {
        s[0].memo = new_memo;
        s[0].memo_size = new_size;
        s[0].memo_len = new_len;
    }
    i = old_size;
    while i > 0 {
        i -= 1;
        object_xdecref((old_memo + i).view(1)[0]);
    }
    PyMem_Free(ptr(old_memo));
    return status;
}

impl unpickler_sizeof(u: ptr[UnpicklerRec]) -> i64 {
    s = u.view(1);
    res: i64 = 0;
    if s[0].memo {
        res += s[0].memo_size * 8;
    }
    if s[0].marks {
        res += s[0].marks_size * 8;
    }
    if s[0].stack {
        res += s[0].stack_allocated * 8;
    }
    if s[0].input_line {
        res += i64(strlen(s[0].input_line)) + 1;
    }
    if s[0].encoding {
        res += object_size(s[0].encoding) + 1;
    } else {
        res += 6;
    }
    if s[0].errors {
        res += object_size(s[0].errors) + 1;
    } else {
        res += 7;
    }
    return res;
}

impl pickle_loads(
    module: ptr[PyObject],
    data: ptr[PyObject],
    fix_imports: bool,
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    buffers: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own UnpicklerStack = UnpicklerStack();
    u = ptr[UnpicklerRec](jacpy_stack_address(&mut slots));
    result = NULL;
    if set_string_input(u, data) >= 0
        and unpickler_prepare(u, module, fix_imports, encoding, errors, buffers) == 0 {
        result = load(u);
    }
    unpickler_release(u);
    return result;
}

impl pickle_load(
    module: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    buffers: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own UnpicklerStack = UnpicklerStack();
    u = ptr[UnpicklerRec](jacpy_stack_address(&mut slots));
    result = NULL;
    if set_input_stream(u, file) == 0
        and unpickler_prepare(u, module, fix_imports, encoding, errors, buffers) == 0 {
        result = load(u);
    }
    unpickler_release(u);
    return result;
}
