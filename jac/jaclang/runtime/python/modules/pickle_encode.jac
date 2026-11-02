import from c {
    obj MemoEntry {
        has me_key: ptr[PyObject] = ptr[PyObject](),
            me_value: i64 = 0;
    }  obj PicklerRec {
        has mt_table: ptr[MemoEntry] = ptr[MemoEntry](),
            mt_mask: u64 = 0,
            mt_used: i64 = 0,
            mt_allocated: i64 = 0,
            persistent_id: ptr[PyObject] = ptr[PyObject](),
            dispatch_table: ptr[PyObject] = ptr[PyObject](),
            reducer_override: ptr[PyObject] = ptr[PyObject](),
            write: ptr[PyObject] = ptr[PyObject](),
            output_buffer: ptr[PyObject] = ptr[PyObject](),
            output_len: i64 = 0,
            max_output_len: i64 = 0,
            frame_start: i64 = 0,
            proto: i32 = 0,
            bin: i32 = 0,
            framing: i32 = 0,
            fast: i32 = 0,
            fast_nesting: i32 = 0,
            fix_imports: i32 = 0,
            fast_memo: ptr[PyObject] = ptr[PyObject](),
            buffer_callback: ptr[PyObject] = ptr[PyObject](),
            error: ptr[PyObject] = ptr[PyObject](),
            module: ptr[PyObject] = ptr[PyObject]();
    }  obj PicklerStack {
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
            w31: u64 = 0;
    }  def jacpy_stack_address(slots: &mut PicklerStack) -> int;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memmove(target: ptr, source: ptr, size: u64) -> ptr;  def strlen(
        text: ptr[u8]
    ) -> u64;  def PyOS_snprintf(
        buffer: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def _PyErr_FormatNote(format: ptr[u8], *args: any);  def PyFloat_Pack8(
        x: f64, data: ptr[u8], le: i32
    ) -> i32;  def Py_EnterRecursiveCall(where: ptr[u8]) -> i32;  def PyMapping_GetOptionalItem(
        obj_: ptr[PyObject], key: ptr[PyObject], result: &mut ptr[PyObject]
    ) -> i32;  def PyUnicode_Split(
        s: ptr[PyObject], sep: ptr[PyObject], maxsplit: i64
    ) -> ptr[PyObject];  def PySys_GetObject(name: ptr[u8]) -> ptr[PyObject];  def _PySet_NextEntryRef(
        set: ptr[PyObject], pos: &mut i64, key: &mut ptr[PyObject], hash: &mut i64
    ) -> i32;  def PyUnicode_ReadChar(unicode: ptr[PyObject], index: i64) -> u32;  def _PySys_GetSizeOf(
        o: ptr[PyObject]
    ) -> u64;
}

glob:priv OP_MARK: Final[u8] = 40,
     OP_STOP: Final[u8] = 46,
     OP_POP: Final[u8] = 48,
     OP_POP_MARK: Final[u8] = 49,
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
     OP_LONG_BINGET: Final[u8] = 106,
     OP_LIST: Final[u8] = 108,
     OP_EMPTY_LIST: Final[u8] = 93,
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
     BATCHSIZE: Final[i64] = 1000,
     FAST_NESTING_LIMIT: Final[i32] = 50,
     WRITE_BUF_SIZE: Final[i64] = 4096,
     FRAME_SIZE_MIN: Final[i64] = 4,
     FRAME_SIZE_TARGET: Final[i64] = 65536,
     FRAME_HEADER_SIZE: Final[i64] = 9,
     MT_MINSIZE: Final[i64] = 8,
     MEMO_ENTRY_SIZE: Final[i64] = 16,
     MEMO_TABLE_SIZE: Final[i64] = 32,
     PICKLER_REC_SIZE: Final[u64] = 256,
     DEFAULT_PROTOCOL: Final[i64] = 5,
     HIGHEST_PROTOCOL: Final[i64] = 5,
     PICKLE_PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     PICKLE_BUFFER_VIEW_SIZE: Final[u64] = 80,
     PICKLE_BUF_FULL_RO: Final[i32] = 284;

glob:priv dot_text: ptr[PyObject] = NULL,
     reduce_ex_text: ptr[PyObject] = NULL,
     modules_main_text: ptr[PyObject] = NULL;

glob:priv SLOT_PICKLING_ERROR: Final[i64] = 5,
     SLOT_DISPATCH: Final[i64] = 7,
     SLOT_EXTENSION_REGISTRY: Final[i64] = 8,
     SLOT_NAME_MAPPING_3TO2: Final[i64] = 13,
     SLOT_IMPORT_MAPPING_3TO2: Final[i64] = 14,
     SLOT_CODECS_ENCODE: Final[i64] = 15,
     SLOT_GETATTR: Final[i64] = 16,
     SLOT_PARTIAL: Final[i64] = 17;

def save(p: ptr[PicklerRec], obj_: ptr[PyObject], pers_save: i32) -> i32;

def save_reduce(p: ptr[PicklerRec], args: ptr[PyObject], obj_: ptr[PyObject]) -> i32;

def batch_list(p: ptr[PicklerRec], iter: ptr[PyObject], origobj: ptr[PyObject]) -> i32;

def batch_dict(p: ptr[PicklerRec], iter: ptr[PyObject], origobj: ptr[PyObject]) -> i32;

def save_global(p: ptr[PicklerRec], obj_: ptr[PyObject], name: ptr[PyObject]) -> i32;

obj pickle_state {
    has rec: ptr[PicklerRec] = ptr[PicklerRec]();
}

def interned(slot: ptr[PyObject], text: ptr[u8]) -> ptr[PyObject];

def state_object(p: ptr[PicklerRec], slot: i64) -> ptr[PyObject];

def is_exact(op: ptr[PyObject], tp: ptr[PyObject]) -> bool;

def list_item(op: ptr[PyObject], i: i64) -> ptr[PyObject];

def py_true -> ptr[PyObject];

def py_false -> ptr[PyObject];

def copy_bytes(target: ptr[u8], source: ptr[u8], n: i64);

def put_le(out: ptr[u8], value: i64, width: i64);

def memo_alloc(p: ptr[PicklerRec], size: i64) -> i32;

def memo_release_keys(p: ptr[PicklerRec]);

def memo_free(p: ptr[PicklerRec]);

def memo_lookup(p: ptr[PicklerRec], key: ptr[PyObject]) -> ptr[MemoEntry];

def memo_resize(p: ptr[PicklerRec], min_size: i64) -> i32;

def memo_index(p: ptr[PicklerRec], key: ptr[PyObject]) -> i64;

def memo_set(p: ptr[PicklerRec], key: ptr[PyObject], value: i64) -> i32;

def clear_buffer(p: ptr[PicklerRec]) -> i32;

def commit_frame(p: ptr[PicklerRec]);

def get_string(p: ptr[PicklerRec]) -> ptr[PyObject];

def flush_to_file(p: ptr[PicklerRec]) -> i32;

def opcode_boundary(p: ptr[PicklerRec]) -> i32;

def grow_output(p: ptr[PicklerRec], n: i64) -> i32;

def reserve(p: ptr[PicklerRec], data_len: i64) -> ptr[u8];

def write(p: ptr[PicklerRec], data: ptr[u8], n: i64) -> i32;

def write_op(p: ptr[PicklerRec], op: u8) -> i32;

def write_op2(p: ptr[PicklerRec], op: u8, arg: u8) -> i32;

def write_text(p: ptr[PicklerRec], text: ptr[u8]) -> i32;

def write_decimal(p: ptr[PicklerRec], op: u8, value: i64) -> i32;

def write_blob(
    p: ptr[PicklerRec],
    op: u8,
    width: i64,
    data: ptr[u8],
    size: i64,
    payload: ptr[PyObject]
) -> i32;

def memo_get(p: ptr[PicklerRec], value: i64) -> i32;

def memo_put(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def fast_save_enter(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> bool;

def fast_save_leave(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> bool;

def save_bool(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_long(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_big_long(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_float(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_bytes_data(
    p: ptr[PicklerRec], obj_: ptr[PyObject], data: ptr[u8], size: i64
) -> i32;

def save_bytes(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_bytearray_data(
    p: ptr[PicklerRec], obj_: ptr[PyObject], data: ptr[u8], size: i64
) -> i32;

def save_bytearray(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_picklebuffer(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def hex_digit(value: u32) -> u8;

def write_raw_unicode_escape(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def write_unicode_binary(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_unicode(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def store_tuple_elements(p: ptr[PicklerRec], t: ptr[PyObject], n: i64) -> i32;

def save_tuple(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

impl batch_list(
    p: ptr[PicklerRec], iter: ptr[PyObject], origobj: ptr[PyObject]
) -> i32 {
    total: i64 = 0;
    if p.view(1)[0].proto == 0 {
        while True {
            item = PyIter_Next(iter);
            if not item {
                if PyErr_Occurred() {
                    return -1;
                }
                return 0;
            }
            status = save(p, item, 0);
            object_decref(item);
            if status < 0 {
                _PyErr_FormatNote(
                    ptr[u8]("when serializing %T item %zd"), origobj, total
                );
                return -1;
            }
            if write_op(p, OP_APPEND) < 0 {
                return -1;
            }
            total += 1;
        }
    }
    n: i64 = 0;
    while True {
        firstitem = PyIter_Next(iter);
        if not firstitem {
            if PyErr_Occurred() {
                return -1;
            }
            return 0;
        }
        item = PyIter_Next(iter);
        if not item {
            if PyErr_Occurred() {
                object_decref(firstitem);
                return -1;
            }
            status = save(p, firstitem, 0);
            object_decref(firstitem);
            if status < 0 {
                _PyErr_FormatNote(
                    ptr[u8]("when serializing %T item %zd"), origobj, total
                );
                return -1;
            }
            if write_op(p, OP_APPEND) < 0 {
                return -1;
            }
            return 0;
        }
        if write_op(p, OP_MARK) < 0 {
            object_decref(firstitem);
            object_decref(item);
            return -1;
        }
        status = save(p, firstitem, 0);
        object_decref(firstitem);
        if status < 0 {
            _PyErr_FormatNote(ptr[u8]("when serializing %T item %zd"), origobj, total);
            object_decref(item);
            return -1;
        }
        total += 1;
        n = 1;
        while item {
            status = save(p, item, 0);
            object_decref(item);
            item = NULL;
            if status < 0 {
                _PyErr_FormatNote(
                    ptr[u8]("when serializing %T item %zd"), origobj, total
                );
                return -1;
            }
            total += 1;
            n += 1;
            if n == BATCHSIZE {
                break;
            }
            item = PyIter_Next(iter);
            if not item and PyErr_Occurred() {
                return -1;
            }
        }
        if write_op(p, OP_APPENDS) < 0 {
            return -1;
        }
        if n != BATCHSIZE {
            return 0;
        }
    }
    return 0;
}

def batch_list_exact(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_list(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_pair(p: ptr[PicklerRec], pair: ptr[PyObject], origobj: ptr[PyObject]) -> i32;

def check_pair(pair: ptr[PyObject]) -> bool;

impl batch_dict(
    p: ptr[PicklerRec], iter: ptr[PyObject], origobj: ptr[PyObject]
) -> i32 {
    if p.view(1)[0].proto == 0 {
        while True {
            pair = PyIter_Next(iter);
            if not pair {
                if PyErr_Occurred() {
                    return -1;
                }
                return 0;
            }
            if not check_pair(pair) {
                object_decref(pair);
                return -1;
            }
            status = save_pair(p, pair, origobj);
            object_decref(pair);
            if status < 0 {
                return -1;
            }
            if write_op(p, OP_SETITEM) < 0 {
                return -1;
            }
        }
    }
    n: i64 = 0;
    while True {
        firstitem = PyIter_Next(iter);
        if not firstitem {
            if PyErr_Occurred() {
                return -1;
            }
            return 0;
        }
        if not check_pair(firstitem) {
            object_decref(firstitem);
            return -1;
        }
        pair = PyIter_Next(iter);
        if not pair {
            if PyErr_Occurred() {
                object_decref(firstitem);
                return -1;
            }
            status = save_pair(p, firstitem, origobj);
            object_decref(firstitem);
            if status < 0 {
                return -1;
            }
            return write_op(p, OP_SETITEM);
        }
        if write_op(p, OP_MARK) < 0 {
            object_decref(firstitem);
            object_decref(pair);
            return -1;
        }
        status = save_pair(p, firstitem, origobj);
        object_decref(firstitem);
        if status < 0 {
            object_decref(pair);
            return -1;
        }
        n = 1;
        while pair {
            if not check_pair(pair) {
                object_decref(pair);
                return -1;
            }
            status = save_pair(p, pair, origobj);
            object_decref(pair);
            pair = NULL;
            if status < 0 {
                return -1;
            }
            n += 1;
            if n == BATCHSIZE {
                break;
            }
            pair = PyIter_Next(iter);
            if not pair and PyErr_Occurred() {
                return -1;
            }
        }
        if write_op(p, OP_SETITEMS) < 0 {
            return -1;
        }
        if n != BATCHSIZE {
            return 0;
        }
    }
    return 0;
}

def save_item(
    p: ptr[PicklerRec], dict_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def batch_dict_exact(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_dict(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_dict_items(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_set(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_frozenset_impl(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_frozenset(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def fix_imports(
    p: ptr[PicklerRec], module_name: ptr[PyObject], global_name: ptr[PyObject]
) -> (i32, ptr[PyObject], ptr[PyObject]);

def check_dotted_path(
    p: ptr[PicklerRec], obj_: ptr[PyObject], dotted_path: ptr[PyObject]
) -> i32;

def getattribute(
    obj_: ptr[PyObject], names: ptr[PyObject], raises: bool
) -> ptr[PyObject];

def checkmodule(
    module_name: ptr[PyObject],
    module: ptr[PyObject],
    global_obj: ptr[PyObject],
    dotted_path: ptr[PyObject]
) -> i32;

def search_modules(
    global_obj: ptr[PyObject], dotted_path: ptr[PyObject]
) -> (i32, ptr[PyObject]);

def whichmodule(
    p: ptr[PicklerRec],
    global_obj: ptr[PyObject],
    global_name: ptr[PyObject],
    dotted_path: ptr[PyObject]
) -> ptr[PyObject];

def save_extension(
    p: ptr[PicklerRec], module_name: ptr[PyObject], global_name: ptr[PyObject]
) -> i32;

def write_identifier(p: ptr[PicklerRec], name: ptr[PyObject], module: bool) -> i32;

def save_global_text(
    p: ptr[PicklerRec],
    module_name: ptr[PyObject],
    global_name: ptr[PyObject],
    dotted_path: ptr[PyObject]
) -> (i32, ptr[PyObject], ptr[PyObject]);

impl save_global(p: ptr[PicklerRec], obj_: ptr[PyObject], name: ptr[PyObject]) -> i32 {
    s = p.view(1);
    global_name = NULL;
    if name {
        global_name = object_new_ref(name);
    } else {
        if PyObject_GetOptionalAttr(obj_, py_id(_Py_ID___qualname__), &mut global_name)
            < 0 {
            return -1;
        }
        if not global_name {
            global_name = PyObject_GetAttr(obj_, py_id(_Py_ID___name__));
            if not global_name {
                return -1;
            }
        }
    }
    dot_text = interned(dot_text, ptr[u8]("."));
    if not dot_text {
        object_decref(global_name);
        return -1;
    }
    dotted_path = PyUnicode_Split(global_name, dot_text, -1);
    if not dotted_path {
        object_decref(global_name);
        return -1;
    }
    module_name = whichmodule(p, obj_, global_name, dotted_path);
    if not module_name {
        object_decref(global_name);
        object_decref(dotted_path);
        return -1;
    }
    status: i32 = 0;
    extension: i32 = 0;
    if s[0].proto >= 2 {
        extension = save_extension(p, module_name, global_name);
        if extension < 0 {
            status = -1;
        }
    }
    if status == 0 and extension == 0 {
        if s[0].proto >= 4 {
            if save(p, module_name, 0) < 0
                or save(p, global_name, 0) < 0
                or write_op(p, OP_STACK_GLOBAL) < 0 {
                status = -1;
            }
        } else {
            (text_status, final_module, final_global) = save_global_text(
                p, module_name, global_name, dotted_path
            );
            module_name = final_module;
            global_name = final_global;
            status = text_status;
        }
        if status == 0 and memo_put(p, obj_) < 0 {
            status = -1;
        }
    }
    object_decref(module_name);
    object_decref(global_name);
    object_decref(dotted_path);
    return status;
}

def save_singleton_type(
    p: ptr[PicklerRec], obj_: ptr[PyObject], singleton: ptr[PyObject]
) -> i32;

def save_type(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def save_pers(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def get_class(obj_: ptr[PyObject]) -> ptr[PyObject];

def save_newobj_ex(
    p: ptr[PicklerRec], argtup: ptr[PyObject], obj_: ptr[PyObject]
) -> i32;

def save_newobj(p: ptr[PicklerRec], argtup: ptr[PyObject], obj_: ptr[PyObject]) -> i32;

def save_state(
    p: ptr[PicklerRec],
    obj_: ptr[PyObject],
    state: ptr[PyObject],
    state_setter: ptr[PyObject]
) -> i32;

impl save_reduce(p: ptr[PicklerRec], args: ptr[PyObject], obj_: ptr[PyObject]) -> i32 {
    s = p.view(1);
    error = s[0].error;
    size = PyTuple_Size(args);
    if size < 2 or size > 6 {
        PyErr_SetString(
            error,
            ptr[u8]("tuple returned by __reduce__ must contain 2 through 6 elements")
        );
        return -1;
    }
    callable = tuple_get_item(args, 0);
    argtup = tuple_get_item(args, 1);
    state = tuple_get_item(args, 2) if size > 2 else Py_None;
    listitems = tuple_get_item(args, 3) if size > 3 else Py_None;
    dictitems = tuple_get_item(args, 4) if size > 4 else Py_None;
    state_setter = tuple_get_item(args, 5) if size > 5 else Py_None;
    if PyCallable_Check(callable) == 0 {
        PyErr_Format(
            error,
            ptr[u8](
                "first item of the tuple returned by __reduce__ must be callable, not %T"
            ),
            callable
        );
        return -1;
    }
    if not tuple_check(argtup) {
        PyErr_Format(
            error,
            ptr[u8](
                "second item of the tuple returned by __reduce__ must be a tuple, not %T"
            ),
            argtup
        );
        return -1;
    }
    if state == Py_None {
        state = NULL;
    }
    if listitems == Py_None {
        listitems = NULL;
    } elif PyIter_Check(listitems) == 0 {
        PyErr_Format(
            error,
            ptr[u8](
                "fourth item of the tuple returned by __reduce__ must be an iterator, not %T"
            ),
            listitems
        );
        return -1;
    }
    if dictitems == Py_None {
        dictitems = NULL;
    } elif PyIter_Check(dictitems) == 0 {
        PyErr_Format(
            error,
            ptr[u8](
                "fifth item of the tuple returned by __reduce__ must be an iterator, not %T"
            ),
            dictitems
        );
        return -1;
    }
    if state_setter == Py_None {
        state_setter = NULL;
    } elif PyCallable_Check(state_setter) == 0 {
        PyErr_Format(
            error,
            ptr[u8](
                "sixth item of the tuple returned by __reduce__ must be callable, not %T"
            ),
            state_setter
        );
        return -1;
    }
    use_newobj = False;
    use_newobj_ex = False;
    if s[0].proto >= 2 {
        name = NULL;
        if PyObject_GetOptionalAttr(callable, py_id(_Py_ID___name__), &mut name) < 0 {
            return -1;
        }
        if name and unicode_check(name) {
            use_newobj_ex = _PyUnicode_EqualToASCIIString(
                name, ptr[u8]("__newobj_ex__")
            )
                != 0;
            if not use_newobj_ex {
                use_newobj = _PyUnicode_EqualToASCIIString(name, ptr[u8]("__newobj__"))
                    != 0;
            }
        }
        object_xdecref(name);
    }
    if use_newobj_ex {
        if save_newobj_ex(p, argtup, obj_) < 0 {
            return -1;
        }
    } elif use_newobj {
        if save_newobj(p, argtup, obj_) < 0 {
            return -1;
        }
    } else {
        if save(p, callable, 0) < 0 {
            _PyErr_FormatNote(ptr[u8]("when serializing %T reconstructor"), obj_);
            return -1;
        }
        if save(p, argtup, 0) < 0 {
            _PyErr_FormatNote(
                ptr[u8]("when serializing %T reconstructor arguments"), obj_
            );
            return -1;
        }
        if write_op(p, OP_REDUCE) < 0 {
            return -1;
        }
    }
    if obj_ {
        found = memo_index(p, obj_);
        if found >= 0 {
            if write_op(p, OP_POP) < 0 {
                return -1;
            }
            return memo_get(p, found);
        }
        if memo_put(p, obj_) < 0 {
            return -1;
        }
    }
    if listitems and batch_list(p, listitems, obj_) < 0 {
        return -1;
    }
    if dictitems and batch_dict(p, dictitems, obj_) < 0 {
        return -1;
    }
    if state {
        return save_state(p, obj_, state, state_setter);
    }
    return 0;
}

def save_reduce_value(
    p: ptr[PicklerRec], obj_: ptr[PyObject], reduce_value: ptr[PyObject]
) -> i32;

def save_object(p: ptr[PicklerRec], obj_: ptr[PyObject], type: ptr[PyObject]) -> i32;

impl save(p: ptr[PicklerRec], obj_: ptr[PyObject], pers_save: i32) -> i32 {
    s = p.view(1);
    if s[0].framing != 0 and s[0].frame_start != -1 {
        if opcode_boundary(p) < 0 {
            return -1;
        }
    }
    if pers_save == 0 and s[0].persistent_id {
        status = save_pers(p, obj_);
        if status != 0 {
            return status;
        }
    }
    type = ptr[PyObject](object_type(obj_));
    if obj_ == Py_None {
        return write_op(p, OP_NONE);
    }
    if type == addressof(PyBool_Type) {
        return save_bool(p, obj_);
    }
    if type == addressof(PyLong_Type) {
        return save_long(p, obj_);
    }
    if type == addressof(PyFloat_Type) {
        return save_float(p, obj_);
    }
    found = memo_index(p, obj_);
    if found >= 0 {
        return memo_get(p, found);
    }
    if type == addressof(PyBytes_Type) {
        return save_bytes(p, obj_);
    }
    if type == addressof(PyUnicode_Type) {
        return save_unicode(p, obj_);
    }
    if Py_EnterRecursiveCall(ptr[u8](" while pickling an object")) != 0 {
        return -1;
    }
    status = save_object(p, obj_, type);
    Py_LeaveRecursiveCall();
    return status;
}

def pickler_dump(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def set_protocol(
    p: ptr[PicklerRec], protocol: ptr[PyObject], fix_imports: bool
) -> i32;

def set_buffer_callback(p: ptr[PicklerRec], buffer_callback: ptr[PyObject]) -> i32;

def pickler_prepare(p: ptr[PicklerRec], module: ptr[PyObject]) -> i32;

def pickler_release(p: ptr[PicklerRec]);

def pickler_new -> ptr[PicklerRec];

def pickler_free(p: ptr[PicklerRec]);

def visit_slot(value: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def pickler_traverse(p: ptr[PicklerRec], visitor: ptr, context: ptr) -> i32;

def pickler_init(
    p: ptr[PicklerRec],
    module: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> i32;

def swap_slot(slot: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def pickler_dump_file(
    p: ptr[PicklerRec],
    obj_: ptr[PyObject],
    persistent_id: ptr[PyObject],
    reducer_override: ptr[PyObject],
    dispatch_table: ptr[PyObject],
    fast: i32
) -> i32;

def pickler_memo_copy(p: ptr[PicklerRec]) -> ptr[PyObject];

def pickler_memo_clear(p: ptr[PicklerRec]) -> i32;

def pickler_memo_set(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32;

def pickler_sizeof(p: ptr[PicklerRec]) -> i64;

def pickle_dumps(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject];

def pickle_dump(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject];

impl interned(slot: ptr[PyObject], text: ptr[u8]) -> ptr[PyObject] {
    if slot {
        return slot;
    }
    return PyUnicode_InternFromString(text);
}

impl state_object(p: ptr[PicklerRec], slot: i64) -> ptr[PyObject] {
    return jacpy_binding_state_get(p.view(1)[0].module, slot);
}

impl is_exact(op: ptr[PyObject], tp: ptr[PyObject]) -> bool {
    return ptr[PyObject](object_type(op)) == tp;
}

impl list_item(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
    return (ptr[PyListObject](op).view(1)[0].ob_item + i).view(1)[0];
}

impl py_true -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct));
}

impl py_false -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_FalseStruct));
}

impl copy_bytes(target: ptr[u8], source: ptr[u8], n: i64) {
    if n < 16 {
        i: i64 = 0;
        while i < n {
            (target + i).view(1)[0] = (source + i).view(1)[0];
            i += 1;
        }
    } else {
        memcpy(ptr(target), ptr(source), u64(n));
    }
}

impl put_le(out: ptr[u8], value: i64, width: i64) {
    i: i64 = 0;
    while i < width {
        (out + i).view(1)[0] = u8.wrap(value >> (8 * i));
        i += 1;
    }
}

impl memo_alloc(p: ptr[PicklerRec], size: i64) -> i32 {
    table = ptr[MemoEntry](PyMem_Calloc(u64(size), u64(MEMO_ENTRY_SIZE)));
    if not table {
        PyErr_NoMemory();
        return -1;
    }
    s = p.view(1);
    s[0].mt_table = table;
    s[0].mt_allocated = size;
    s[0].mt_mask = u64(size - 1);
    s[0].mt_used = 0;
    return 0;
}

impl memo_release_keys(p: ptr[PicklerRec]) {
    s = p.view(1);
    table = s[0].mt_table;
    if not table {
        return;
    }
    i = s[0].mt_allocated;
    while i > 0 {
        i -= 1;
        key = (table + i).view(1)[0].me_key;
        if key {
            (table + i).view(1)[0].me_key = ptr[PyObject]();
            object_decref(key);
        }
    }
    s[0].mt_used = 0;
}

impl memo_free(p: ptr[PicklerRec]) {
    memo_release_keys(p);
    s = p.view(1);
    table = s[0].mt_table;
    s[0].mt_table = ptr[MemoEntry]();
    s[0].mt_allocated = 0;
    s[0].mt_mask = 0;
    if table {
        PyMem_Free(ptr(table));
    }
}

impl memo_lookup(p: ptr[PicklerRec], key: ptr[PyObject]) -> ptr[MemoEntry] {
    s = p.view(1);
    mask = s[0].mt_mask;
    table = s[0].mt_table;
    hash = u64(int(key)) >> u64(3);
    i = hash & mask;
    cell = table + i64(i);
    found = cell.view(1)[0].me_key;
    if not found or found == key {
        return cell;
    }
    perturb = hash;
    while True {
        i = wrapping_add(wrapping_add(wrapping_mul(i, u64(5)), perturb), u64(1));
        cell = table + i64(i & mask);
        found = cell.view(1)[0].me_key;
        if not found or found == key {
            return cell;
        }
        perturb = perturb >> u64(5);
    }
    return cell;
}

impl memo_resize(p: ptr[PicklerRec], min_size: i64) -> i32 {
    new_size = MT_MINSIZE;
    while new_size < min_size {
        new_size = new_size * 2;
    }
    s = p.view(1);
    old_table = s[0].mt_table;
    old_allocated = s[0].mt_allocated;
    used = s[0].mt_used;
    table = ptr[MemoEntry](PyMem_Calloc(u64(new_size), u64(MEMO_ENTRY_SIZE)));
    if not table {
        PyErr_NoMemory();
        return -1;
    }
    s[0].mt_table = table;
    s[0].mt_allocated = new_size;
    s[0].mt_mask = u64(new_size - 1);
    i: i64 = 0;
    while i < old_allocated {
        key = (old_table + i).view(1)[0].me_key;
        if key {
            cell = memo_lookup(p, key);
            cell.view(1)[0].me_key = key;
            cell.view(1)[0].me_value = (old_table + i).view(1)[0].me_value;
        }
        i += 1;
    }
    s[0].mt_used = used;
    PyMem_Free(ptr(old_table));
    return 0;
}

impl memo_index(p: ptr[PicklerRec], key: ptr[PyObject]) -> i64 {
    cell = memo_lookup(p, key);
    if not cell.view(1)[0].me_key {
        return -1;
    }
    return cell.view(1)[0].me_value;
}

impl memo_set(p: ptr[PicklerRec], key: ptr[PyObject], value: i64) -> i32 {
    cell = memo_lookup(p, key);
    if cell.view(1)[0].me_key {
        cell.view(1)[0].me_value = value;
        return 0;
    }
    cell.view(1)[0].me_key = object_new_ref(key);
    cell.view(1)[0].me_value = value;
    s = p.view(1);
    used = s[0].mt_used + 1;
    s[0].mt_used = used;
    if used * 3 < s[0].mt_allocated * 2 {
        return 0;
    }
    factor: i64 = 4;
    if used > 50000 {
        factor = 2;
    }
    return memo_resize(p, factor * used);
}

impl clear_buffer(p: ptr[PicklerRec]) -> i32 {
    s = p.view(1);
    old = s[0].output_buffer;
    s[0].output_buffer = PyBytes_FromStringAndSize(ptr[u8](), s[0].max_output_len);
    object_xdecref(old);
    if not s[0].output_buffer {
        return -1;
    }
    s[0].output_len = 0;
    s[0].frame_start = -1;
    return 0;
}

impl commit_frame(p: ptr[PicklerRec]) {
    s = p.view(1);
    if s[0].framing == 0 or s[0].frame_start == -1 {
        return;
    }
    frame_len = s[0].output_len - s[0].frame_start - FRAME_HEADER_SIZE;
    qdata = bytes_data(s[0].output_buffer) + s[0].frame_start;
    if frame_len >= FRAME_SIZE_MIN {
        qdata.view(1)[0] = OP_FRAME;
        put_le(qdata + 1, frame_len, 8);
    } else {
        memmove(ptr(qdata), ptr(qdata + FRAME_HEADER_SIZE), u64(frame_len));
        s[0].output_len = s[0].output_len - FRAME_HEADER_SIZE;
    }
    s[0].frame_start = -1;
}

impl get_string(p: ptr[PicklerRec]) -> ptr[PyObject] {
    commit_frame(p);
    s = p.view(1);
    output = s[0].output_buffer;
    s[0].output_buffer = NULL;
    if _PyBytes_Resize(&mut output, s[0].output_len) < 0 {
        return NULL;
    }
    return output;
}

impl flush_to_file(p: ptr[PicklerRec]) -> i32 {
    output = get_string(p);
    if not output {
        return -1;
    }
    result = PyObject_CallOneArg(p.view(1)[0].write, output);
    object_decref(output);
    if not result {
        return -1;
    }
    object_decref(result);
    return 0;
}

impl opcode_boundary(p: ptr[PicklerRec]) -> i32 {
    s = p.view(1);
    if s[0].framing == 0 or s[0].frame_start == -1 {
        return 0;
    }
    frame_len = s[0].output_len - s[0].frame_start - FRAME_HEADER_SIZE;
    if frame_len >= FRAME_SIZE_TARGET {
        commit_frame(p);
        if s[0].write {
            if flush_to_file(p) < 0 {
                return -1;
            }
            if clear_buffer(p) < 0 {
                return -1;
            }
        }
    }
    return 0;
}

impl grow_output(p: ptr[PicklerRec], n: i64) -> i32 {
    s = p.view(1);
    if s[0].output_len >= PICKLE_PY_SSIZE_T_MAX // 2 - n {
        PyErr_NoMemory();
        return -1;
    }
    s[0].max_output_len = (s[0].output_len + n) // 2 * 3;
    output = s[0].output_buffer;
    status = _PyBytes_Resize(&mut output, s[0].max_output_len);
    s[0].output_buffer = output;
    return status;
}

impl reserve(p: ptr[PicklerRec], data_len: i64) -> ptr[u8] {
    s = p.view(1);
    need_new_frame = s[0].framing != 0 and s[0].frame_start == -1;
    n = data_len;
    if need_new_frame {
        n = data_len + FRAME_HEADER_SIZE;
    }
    if s[0].output_len + n > s[0].max_output_len {
        if grow_output(p, n) < 0 {
            return ptr[u8]();
        }
    }
    start = s[0].output_len;
    if need_new_frame {
        s[0].frame_start = start;
        start = start + FRAME_HEADER_SIZE;
    }
    s[0].output_len = start + data_len;
    return bytes_data(s[0].output_buffer) + start;
}

impl write(p: ptr[PicklerRec], data: ptr[u8], n: i64) -> i32 {
    out = reserve(p, n);
    if not out {
        return -1;
    }
    copy_bytes(out, data, n);
    return 0;
}

impl write_op(p: ptr[PicklerRec], op: u8) -> i32 {
    out = reserve(p, 1);
    if not out {
        return -1;
    }
    out.view(1)[0] = op;
    return 0;
}

impl write_op2(p: ptr[PicklerRec], op: u8, arg: u8) -> i32 {
    out = reserve(p, 2);
    if not out {
        return -1;
    }
    out.view(2)[0] = op;
    out.view(2)[1] = arg;
    return 0;
}

impl write_text(p: ptr[PicklerRec], text: ptr[u8]) -> i32 {
    return write(p, text, i64(strlen(text)));
}

impl write_decimal(p: ptr[PicklerRec], op: u8, value: i64) -> i32 {
    slots: own PicklerStack = PicklerStack();
    buffer = ptr[u8](jacpy_stack_address(&mut slots));
    PyOS_snprintf(buffer, u64(40), ptr[u8]("%c%lld\n"), i32(op), value);
    return write_text(p, buffer);
}

impl write_blob(
    p: ptr[PicklerRec],
    op: u8,
    width: i64,
    data: ptr[u8],
    size: i64,
    payload: ptr[PyObject]
) -> i32 {
    s = p.view(1);
    if size < FRAME_SIZE_TARGET {
        out = reserve(p, 1 + width + size);
        if not out {
            return -1;
        }
        out.view(1)[0] = op;
        put_le(out + 1, size, width);
        copy_bytes(out + 1 + width, data, size);
        return 0;
    }
    framing = s[0].framing;
    commit_frame(p);
    s[0].framing = 0;
    out = reserve(p, 1 + width);
    if not out {
        return -1;
    }
    out.view(1)[0] = op;
    put_le(out + 1, size, width);
    if s[0].write {
        if flush_to_file(p) < 0 {
            return -1;
        }
        mem = NULL;
        if not payload {
            mem = PyBytes_FromStringAndSize(data, size);
            if not mem {
                return -1;
            }
            payload = mem;
        }
        result = PyObject_CallOneArg(s[0].write, payload);
        object_xdecref(mem);
        if not result {
            return -1;
        }
        object_decref(result);
        if clear_buffer(p) < 0 {
            return -1;
        }
    } elif write(p, data, size) < 0 {
        return -1;
    }
    s[0].framing = framing;
    return 0;
}

impl memo_get(p: ptr[PicklerRec], value: i64) -> i32 {
    if p.view(1)[0].bin == 0 {
        return write_decimal(p, OP_GET, value);
    }
    if value < 256 {
        return write_op2(p, OP_BINGET, u8.wrap(value));
    }
    if value <= 0xffffffff {
        out = reserve(p, 5);
        if not out {
            return -1;
        }
        out.view(1)[0] = OP_LONG_BINGET;
        put_le(out + 1, value, 4);
        return 0;
    }
    PyErr_SetString(p.view(1)[0].error, ptr[u8]("memo id too large for LONG_BINGET"));
    return -1;
}

impl memo_put(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    s = p.view(1);
    if s[0].fast != 0 {
        return 0;
    }
    idx = s[0].mt_used;
    if memo_set(p, obj_, idx) < 0 {
        return -1;
    }
    if s[0].proto >= 4 {
        return write_op(p, OP_MEMOIZE);
    }
    if s[0].bin == 0 {
        return write_decimal(p, OP_PUT, idx);
    }
    if idx < 256 {
        return write_op2(p, OP_BINPUT, u8.wrap(idx));
    }
    if idx <= 0xffffffff {
        out = reserve(p, 5);
        if not out {
            return -1;
        }
        out.view(1)[0] = OP_LONG_BINPUT;
        put_le(out + 1, idx, 4);
        return 0;
    }
    PyErr_SetString(s[0].error, ptr[u8]("memo id too large for LONG_BINPUT"));
    return -1;
}

impl fast_save_enter(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> bool {
    s = p.view(1);
    s[0].fast_nesting = s[0].fast_nesting + 1;
    if s[0].fast_nesting >= FAST_NESTING_LIMIT {
        if not s[0].fast_memo {
            s[0].fast_memo = PyDict_New();
            if not s[0].fast_memo {
                s[0].fast_nesting = -1;
                return False;
            }
        }
        key = PyLong_FromVoidPtr(ptr(obj_));
        if not key {
            s[0].fast_nesting = -1;
            return False;
        }
        r = PyDict_Contains(s[0].fast_memo, key);
        if r > 0 {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8](
                    "fast mode: can't pickle cyclic objects including object type %.200s at %p"
                ),
                ptr[u8](object_type(obj_).view(1)[0].tp_name),
                ptr(obj_)
            );
        } elif r == 0 {
            r = PyDict_SetItem(s[0].fast_memo, key, Py_None);
        }
        object_decref(key);
        if r != 0 {
            s[0].fast_nesting = -1;
            return False;
        }
    }
    return True;
}

impl fast_save_leave(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> bool {
    s = p.view(1);
    nesting = s[0].fast_nesting;
    s[0].fast_nesting = nesting - 1;
    if nesting >= FAST_NESTING_LIMIT {
        key = PyLong_FromVoidPtr(ptr(obj_));
        if not key {
            return False;
        }
        if PyDict_DelItem(s[0].fast_memo, key) < 0 {
            object_decref(key);
            return False;
        }
        object_decref(key);
    }
    return True;
}

impl save_bool(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if p.view(1)[0].proto >= 2 {
        return write_op(p, OP_NEWTRUE if obj_ == py_true() else OP_NEWFALSE);
    }
    if obj_ == py_true() {
        return write_text(p, ptr[u8]("I01\n"));
    }
    return write_text(p, ptr[u8]("I00\n"));
}

impl save_long(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    overflow: i32 = 0;
    val = PyLong_AsLongAndOverflow(obj_, &mut overflow);
    if overflow == 0 and val <= 0x7fffffff and val >= -2147483648 {
        if p.view(1)[0].bin == 0 {
            return write_decimal(p, OP_INT, val);
        }
        b2 = u8.wrap(val >> 8);
        b3 = u8.wrap(val >> 16);
        b4 = u8.wrap(val >> 24);
        if b4 != 0 or b3 != 0 {
            out = reserve(p, 5);
            if not out {
                return -1;
            }
            out.view(5)[0] = OP_BININT;
            out.view(5)[1] = u8.wrap(val);
            out.view(5)[2] = b2;
            out.view(5)[3] = b3;
            out.view(5)[4] = b4;
            return 0;
        }
        if b2 != 0 {
            out = reserve(p, 3);
            if not out {
                return -1;
            }
            out.view(3)[0] = OP_BININT2;
            out.view(3)[1] = u8.wrap(val);
            out.view(3)[2] = b2;
            return 0;
        }
        return write_op2(p, OP_BININT1, u8.wrap(val));
    }
    return save_big_long(p, obj_);
}

impl save_big_long(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if p.view(1)[0].proto >= 2 {
        sign: i32 = 0;
        PyLong_GetSign(obj_, &mut sign);
        if sign == 0 {
            return write_op2(p, OP_LONG1, u8(0));
        }
        nbits = _PyLong_NumBits(obj_);
        nbytes = (nbits >> 3) + 1;
        if nbytes > 0x7fffffff {
            PyErr_SetString(PyExc_OverflowError, ptr[u8]("int too large to pickle"));
            return -1;
        }
        repr = PyBytes_FromStringAndSize(ptr[u8](), nbytes);
        if not repr {
            return -1;
        }
        pdata = bytes_data(repr);
        if _PyLong_AsByteArray(obj_, pdata, u64(nbytes), 1, 1, 1) < 0 {
            object_decref(repr);
            return -1;
        }
        if sign < 0
            and nbytes > 1
            and (pdata + (nbytes - 1)).view(1)[0] == 255
            and ((pdata + (nbytes - 2)).view(1)[0] & 128) != 0 {
            nbytes -= 1;
        }
        status: i32 = 0;
        if nbytes < 256 {
            status = write_blob(p, OP_LONG1, 1, pdata, nbytes, NULL);
        } else {
            status = write_blob(p, OP_LONG4, 4, pdata, nbytes, NULL);
        }
        object_decref(repr);
        return status;
    }
    repr = PyObject_Repr(obj_);
    if not repr {
        return -1;
    }
    size: i64 = 0;
    text = PyUnicode_AsUTF8AndSize(repr, &mut size);
    status: i32 = -1;
    if text
        and write_op(p, OP_LONG) == 0
        and write(p, text, size) == 0
        and write_text(p, ptr[u8]("L\n")) == 0 {
        status = 0;
    }
    object_decref(repr);
    return status;
}

impl save_float(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    x = ptr[PyFloatObject](obj_).view(1)[0].ob_fval;
    if p.view(1)[0].bin != 0 {
        out = reserve(p, 9);
        if not out {
            return -1;
        }
        out.view(1)[0] = OP_BINFLOAT;
        if PyFloat_Pack8(x, out + 1, 0) < 0 {
            return -1;
        }
        return 0;
    }
    if write_op(p, OP_FLOAT) < 0 {
        return -1;
    }
    text = PyOS_double_to_string(x, i8(114), 0, Py_DTSF_ADD_DOT_0, None);
    if not text {
        PyErr_NoMemory();
        return -1;
    }
    status: i32 = -1;
    if write_text(p, text) == 0 and write_text(p, ptr[u8]("\n")) == 0 {
        status = 0;
    }
    PyMem_Free(ptr(text));
    return status;
}

impl save_bytes_data(
    p: ptr[PicklerRec], obj_: ptr[PyObject], data: ptr[u8], size: i64
) -> i32 {
    if size < 0 {
        return -1;
    }
    status: i32 = 0;
    if size <= 0xff {
        status = write_blob(p, OP_SHORT_BINBYTES, 1, data, size, obj_);
    } elif size <= 0xffffffff {
        status = write_blob(p, OP_BINBYTES, 4, data, size, obj_);
    } elif p.view(1)[0].proto >= 4 {
        status = write_blob(p, OP_BINBYTES8, 8, data, size, obj_);
    } else {
        PyErr_SetString(
            PyExc_OverflowError,
            ptr[u8](
                "serializing a bytes object larger than 4 GiB requires pickle protocol 4 or higher"
            )
        );
        return -1;
    }
    if status < 0 {
        return -1;
    }
    return memo_put(p, obj_);
}

impl save_bytes(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if p.view(1)[0].proto >= 3 {
        return save_bytes_data(p, obj_, bytes_data(obj_), object_size(obj_));
    }
    reduce_value = NULL;
    if object_size(obj_) == 0 {
        reduce_value = Py_BuildValue(ptr[u8]("(O())"), addressof(PyBytes_Type));
    } else {
        unicode_str = PyUnicode_DecodeLatin1(
            ptr(bytes_data(obj_)), object_size(obj_), ptr[u8]("strict")
        );
        if not unicode_str {
            return -1;
        }
        reduce_value = Py_BuildValue(
            ptr[u8]("(O(Os))"),
            state_object(p, SLOT_CODECS_ENCODE),
            unicode_str,
            ptr[u8]("latin1")
        );
        object_decref(unicode_str);
    }
    if not reduce_value {
        return -1;
    }
    status = save_reduce(p, reduce_value, obj_);
    object_decref(reduce_value);
    return status;
}

impl save_bytearray_data(
    p: ptr[PicklerRec], obj_: ptr[PyObject], data: ptr[u8], size: i64
) -> i32 {
    if size < 0 {
        return -1;
    }
    if write_blob(p, OP_BYTEARRAY8, 8, data, size, obj_) < 0 {
        return -1;
    }
    return memo_put(p, obj_);
}

impl save_bytearray(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if p.view(1)[0].proto >= 5 {
        return save_bytearray_data(
            p, obj_, ptr[PyByteArrayObject](obj_).view(1)[0].ob_start, object_size(obj_)
        );
    }
    reduce_value = NULL;
    if object_size(obj_) == 0 {
        reduce_value = Py_BuildValue(ptr[u8]("(O())"), addressof(PyByteArray_Type));
    } else {
        bytes_obj = PyBytes_FromObject(obj_);
        if bytes_obj {
            reduce_value = Py_BuildValue(
                ptr[u8]("(O(O))"), addressof(PyByteArray_Type), bytes_obj
            );
            object_decref(bytes_obj);
        }
    }
    if not reduce_value {
        return -1;
    }
    status = save_reduce(p, reduce_value, obj_);
    object_decref(reduce_value);
    return status;
}

impl save_picklebuffer(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    s = p.view(1);
    if s[0].proto < 5 {
        PyErr_SetString(
            s[0].error, ptr[u8]("PickleBuffer can only be pickled with protocol >= 5")
        );
        return -1;
    }
    view = ptr[Py_buffer](PyMem_Calloc(u64(1), PICKLE_BUFFER_VIEW_SIZE));
    if not view {
        PyErr_NoMemory();
        return -1;
    }
    if PyObject_GetBuffer(obj_, view, PICKLE_BUF_FULL_RO) != 0 {
        PyMem_Free(ptr(view));
        return -1;
    }
    rc: i32 = 0;
    if view.view(1)[0].suboffsets or PyBuffer_IsContiguous(view, i8(65)) == 0 {
        PyErr_SetString(
            s[0].error,
            ptr[u8](
                "PickleBuffer can not be pickled when pointing to a non-contiguous buffer"
            )
        );
        rc = -1;
    } else {
        in_band: i32 = 1;
        if s[0].buffer_callback {
            ret = PyObject_CallOneArg(s[0].buffer_callback, obj_);
            if not ret {
                rc = -1;
            } else {
                in_band = PyObject_IsTrue(ret);
                object_decref(ret);
                if in_band == -1 {
                    rc = -1;
                }
            }
        }
        if rc == 0 {
            data = ptr[u8](view.view(1)[0].buf);
            length = view.view(1)[0].length;
            if in_band != 0 {
                if view.view(1)[0].readonly != 0 {
                    rc = save_bytes_data(p, obj_, data, length);
                } else {
                    rc = save_bytearray_data(p, obj_, data, length);
                }
            } elif write_op(p, OP_NEXT_BUFFER) < 0 {
                rc = -1;
            } elif view.view(1)[0].readonly != 0 {
                if write_op(p, OP_READONLY_BUFFER) < 0 {
                    rc = -1;
                }
            }
        }
    }
    PyBuffer_Release(view);
    PyMem_Free(ptr(view));
    return rc;
}

impl hex_digit(value: u32) -> u8 {
    nibble = u8.wrap(value & u32(15));
    if nibble < 10 {
        return u8(48) + nibble;
    }
    return u8(87) + nibble;
}

impl write_raw_unicode_escape(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    size = object_size(obj_);
    i: i64 = 0;
    while i < size {
        ch = PyUnicode_ReadChar(obj_, i);
        if ch >= u32(0x10000) {
            out = reserve(p, 10);
            if not out {
                return -1;
            }
            out.view(10)[0] = u8(92);
            out.view(10)[1] = u8(85);
            shift: u32 = 28;
            k: i64 = 2;
            while k < 10 {
                out.view(10)[k] = hex_digit(ch >> shift);
                if shift >= u32(4) {
                    shift = shift - u32(4);
                }
                k += 1;
            }
        } elif ch >= u32(256)
            or ch == u32(92)
            or ch == u32(0)
            or ch == u32(10)
            or ch == u32(13)
            or ch == u32(26) {
            out = reserve(p, 6);
            if not out {
                return -1;
            }
            out.view(6)[0] = u8(92);
            out.view(6)[1] = u8(117);
            out.view(6)[2] = hex_digit(ch >> u32(12));
            out.view(6)[3] = hex_digit(ch >> u32(8));
            out.view(6)[4] = hex_digit(ch >> u32(4));
            out.view(6)[5] = hex_digit(ch);
        } else {
            out = reserve(p, 1);
            if not out {
                return -1;
            }
            out.view(1)[0] = u8.wrap(ch);
        }
        i += 1;
    }
    return 0;
}

impl write_unicode_binary(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    size: i64 = 0;
    encoded = NULL;
    data = PyUnicode_AsUTF8AndSize(obj_, &mut size);
    if not data {
        PyErr_Clear();
        encoded = PyUnicode_AsEncodedString(
            obj_, ptr[u8]("utf-8"), ptr[u8]("surrogatepass")
        );
        if not encoded {
            return -1;
        }
        data = bytes_data(encoded);
        size = object_size(encoded);
    }
    status: i32 = 0;
    if size <= 0xff and p.view(1)[0].proto >= 4 {
        status = write_blob(p, OP_SHORT_BINUNICODE, 1, data, size, encoded);
    } elif size <= 0xffffffff {
        status = write_blob(p, OP_BINUNICODE, 4, data, size, encoded);
    } elif p.view(1)[0].proto >= 4 {
        status = write_blob(p, OP_BINUNICODE8, 8, data, size, encoded);
    } else {
        PyErr_SetString(
            PyExc_OverflowError,
            ptr[u8](
                "serializing a string larger than 4 GiB requires pickle protocol 4 or higher"
            )
        );
        status = -1;
    }
    object_xdecref(encoded);
    return status;
}

impl save_unicode(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if p.view(1)[0].bin != 0 {
        if write_unicode_binary(p, obj_) < 0 {
            return -1;
        }
    } elif write_op(p, OP_UNICODE) < 0
        or write_raw_unicode_escape(p, obj_) < 0
        or write_op(p, u8(10)) < 0 {
        return -1;
    }
    return memo_put(p, obj_);
}

impl store_tuple_elements(p: ptr[PicklerRec], t: ptr[PyObject], n: i64) -> i32 {
    i: i64 = 0;
    while i < n {
        if save(p, tuple_get_item(t, i), 0) < 0 {
            _PyErr_FormatNote(ptr[u8]("when serializing %T item %zd"), t, i);
            return -1;
        }
        i += 1;
    }
    return 0;
}

impl save_tuple(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    s = p.view(1);
    n = object_size(obj_);
    if n == 0 {
        if s[0].proto != 0 {
            return write_op(p, OP_EMPTY_TUPLE);
        }
        return write_op2(p, OP_MARK, OP_TUPLE);
    }
    if n <= 3 and s[0].proto >= 2 {
        if store_tuple_elements(p, obj_, n) < 0 {
            return -1;
        }
        found = memo_index(p, obj_);
        if found >= 0 {
            i: i64 = 0;
            while i < n {
                if write_op(p, OP_POP) < 0 {
                    return -1;
                }
                i += 1;
            }
            return memo_get(p, found);
        }
        if write_op(p, OP_TUPLE1 + u8.wrap(n - 1)) < 0 {
            return -1;
        }
        return memo_put(p, obj_);
    }
    if write_op(p, OP_MARK) < 0 {
        return -1;
    }
    if store_tuple_elements(p, obj_, n) < 0 {
        return -1;
    }
    found = memo_index(p, obj_);
    if found >= 0 {
        if s[0].bin != 0 {
            if write_op(p, OP_POP_MARK) < 0 {
                return -1;
            }
        } else {
            i: i64 = 0;
            while i <= n {
                if write_op(p, OP_POP) < 0 {
                    return -1;
                }
                i += 1;
            }
        }
        return memo_get(p, found);
    }
    if write_op(p, OP_TUPLE) < 0 {
        return -1;
    }
    return memo_put(p, obj_);
}

impl batch_list_exact(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if object_size(obj_) == 1 {
        item = object_new_ref(list_item(obj_, 0));
        status = save(p, item, 0);
        object_decref(item);
        if status < 0 {
            _PyErr_FormatNote(ptr[u8]("when serializing %T item 0"), obj_);
            return -1;
        }
        return write_op(p, OP_APPEND);
    }
    total: i64 = 0;
    while True {
        this_batch: i64 = 0;
        if write_op(p, OP_MARK) < 0 {
            return -1;
        }
        while total < object_size(obj_) {
            item = object_new_ref(list_item(obj_, total));
            status = save(p, item, 0);
            object_decref(item);
            if status < 0 {
                _PyErr_FormatNote(ptr[u8]("when serializing %T item %zd"), obj_, total);
                return -1;
            }
            total += 1;
            this_batch += 1;
            if this_batch == BATCHSIZE {
                break;
            }
        }
        if write_op(p, OP_APPENDS) < 0 {
            return -1;
        }
        if total >= object_size(obj_) {
            break;
        }
    }
    return 0;
}

impl save_list(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    s = p.view(1);
    status: i32 = 0;
    if s[0].fast != 0 and not fast_save_enter(p, obj_) {
        status = -1;
    } else {
        header_status: i32 = 0;
        if s[0].bin != 0 {
            header_status = write_op(p, OP_EMPTY_LIST);
        } else {
            header_status = write_op2(p, OP_MARK, OP_LIST);
        }
        if header_status < 0 or memo_put(p, obj_) < 0 {
            status = -1;
        } elif object_size(obj_) != 0 {
            if is_exact(obj_, addressof(PyList_Type)) and s[0].proto > 0 {
                if Py_EnterRecursiveCall(ptr[u8](" while pickling an object")) != 0 {
                    status = -1;
                } else {
                    status = batch_list_exact(p, obj_);
                    Py_LeaveRecursiveCall();
                }
            } else {
                iter = PyObject_GetIter(obj_);
                if not iter {
                    status = -1;
                } elif Py_EnterRecursiveCall(ptr[u8](" while pickling an object"))
                    != 0 {
                    object_decref(iter);
                    status = -1;
                } else {
                    status = batch_list(p, iter, obj_);
                    Py_LeaveRecursiveCall();
                    object_decref(iter);
                }
            }
        }
    }
    if s[0].fast != 0 and not fast_save_leave(p, obj_) {
        status = -1;
    }
    return status;
}

impl save_pair(p: ptr[PicklerRec], pair: ptr[PyObject], origobj: ptr[PyObject]) -> i32 {
    if save(p, tuple_get_item(pair, 0), 0) < 0 {
        return -1;
    }
    if save(p, tuple_get_item(pair, 1), 0) < 0 {
        _PyErr_FormatNote(
            ptr[u8]("when serializing %T item %R"), origobj, tuple_get_item(pair, 0)
        );
        return -1;
    }
    return 0;
}

impl check_pair(pair: ptr[PyObject]) -> bool {
    if not tuple_check(pair) or object_size(pair) != 2 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("dict items iterator must return 2-tuples")
        );
        return False;
    }
    return True;
}

impl save_item(
    p: ptr[PicklerRec], dict_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    object_incref(key);
    object_incref(value);
    status: i32 = 0;
    if save(p, key, 0) < 0 {
        status = -1;
    } elif save(p, value, 0) < 0 {
        _PyErr_FormatNote(ptr[u8]("when serializing %T item %R"), dict_, key);
        status = -1;
    }
    object_decref(key);
    object_decref(value);
    return status;
}

impl batch_dict_exact(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    dict_size = object_size(obj_);
    ppos: i64 = 0;
    key = NULL;
    value = NULL;
    if dict_size == 1 {
        PyDict_Next(obj_, &mut ppos, &mut key, &mut value);
        if save_item(p, obj_, key, value) < 0 {
            return -1;
        }
        return write_op(p, OP_SETITEM);
    }
    while True {
        i: i64 = 0;
        if write_op(p, OP_MARK) < 0 {
            return -1;
        }
        while PyDict_Next(obj_, &mut ppos, &mut key, &mut value) != 0 {
            if save_item(p, obj_, key, value) < 0 {
                return -1;
            }
            i += 1;
            if i == BATCHSIZE {
                break;
            }
        }
        if write_op(p, OP_SETITEMS) < 0 {
            return -1;
        }
        if object_size(obj_) != dict_size {
            PyErr_Format(
                PyExc_RuntimeError, ptr[u8]("dictionary changed size during iteration")
            );
            return -1;
        }
        if i != BATCHSIZE {
            break;
        }
    }
    return 0;
}

impl save_dict(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    s = p.view(1);
    status: i32 = 0;
    if s[0].fast != 0 and not fast_save_enter(p, obj_) {
        status = -1;
    } else {
        header_status: i32 = 0;
        if s[0].bin != 0 {
            header_status = write_op(p, OP_EMPTY_DICT);
        } else {
            header_status = write_op2(p, OP_MARK, OP_DICT);
        }
        if header_status < 0 or memo_put(p, obj_) < 0 {
            status = -1;
        } elif object_size(obj_) != 0 {
            if is_exact(obj_, addressof(PyDict_Type)) and s[0].proto > 0 {
                if Py_EnterRecursiveCall(ptr[u8](" while pickling an object")) != 0 {
                    status = -1;
                } else {
                    status = batch_dict_exact(p, obj_);
                    Py_LeaveRecursiveCall();
                }
            } else {
                status = save_dict_items(p, obj_);
            }
        }
    }
    if s[0].fast != 0 and not fast_save_leave(p, obj_) {
        status = -1;
    }
    return status;
}

impl save_dict_items(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    method = PyObject_GetAttr(obj_, py_id(_Py_ID_items));
    if not method {
        return -1;
    }
    items = PyObject_CallNoArgs(method);
    object_decref(method);
    if not items {
        return -1;
    }
    iter = PyObject_GetIter(items);
    object_decref(items);
    if not iter {
        return -1;
    }
    if Py_EnterRecursiveCall(ptr[u8](" while pickling an object")) != 0 {
        object_decref(iter);
        return -1;
    }
    status = batch_dict(p, iter, obj_);
    Py_LeaveRecursiveCall();
    object_decref(iter);
    return status;
}

impl save_set(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if p.view(1)[0].proto < 4 {
        items = PySequence_List(obj_);
        if not items {
            return -1;
        }
        reduce_value = Py_BuildValue(ptr[u8]("(O(O))"), addressof(PySet_Type), items);
        object_decref(items);
        if not reduce_value {
            return -1;
        }
        status = save_reduce(p, reduce_value, obj_);
        object_decref(reduce_value);
        return status;
    }
    if write_op(p, OP_EMPTY_SET) < 0 {
        return -1;
    }
    if memo_put(p, obj_) < 0 {
        return -1;
    }
    set_size = object_size(obj_);
    if set_size == 0 {
        return 0;
    }
    ppos: i64 = 0;
    item = NULL;
    hash: i64 = 0;
    while True {
        i: i64 = 0;
        if write_op(p, OP_MARK) < 0 {
            return -1;
        }
        while _PySet_NextEntryRef(obj_, &mut ppos, &mut item, &mut hash) != 0 {
            err = save(p, item, 0);
            object_decref(item);
            if err < 0 {
                _PyErr_FormatNote(ptr[u8]("when serializing %T element"), obj_);
                return -1;
            }
            i += 1;
            if i == BATCHSIZE {
                break;
            }
        }
        if write_op(p, OP_ADDITEMS) < 0 {
            return -1;
        }
        if object_size(obj_) != set_size {
            PyErr_Format(
                PyExc_RuntimeError, ptr[u8]("set changed size during iteration")
            );
            return -1;
        }
        if i != BATCHSIZE {
            break;
        }
    }
    return 0;
}

impl save_frozenset_impl(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if p.view(1)[0].proto < 4 {
        items = PySequence_List(obj_);
        if not items {
            return -1;
        }
        reduce_value = Py_BuildValue(
            ptr[u8]("(O(O))"), addressof(PyFrozenSet_Type), items
        );
        object_decref(items);
        if not reduce_value {
            return -1;
        }
        status = save_reduce(p, reduce_value, obj_);
        object_decref(reduce_value);
        return status;
    }
    if write_op(p, OP_MARK) < 0 {
        return -1;
    }
    iter = PyObject_GetIter(obj_);
    if not iter {
        return -1;
    }
    while True {
        item = PyIter_Next(iter);
        if not item {
            if PyErr_Occurred() {
                object_decref(iter);
                return -1;
            }
            break;
        }
        if save(p, item, 0) < 0 {
            _PyErr_FormatNote(ptr[u8]("when serializing %T element"), obj_);
            object_decref(item);
            object_decref(iter);
            return -1;
        }
        object_decref(item);
    }
    object_decref(iter);
    found = memo_index(p, obj_);
    if found >= 0 {
        if write_op(p, OP_POP_MARK) < 0 {
            return -1;
        }
        return memo_get(p, found);
    }
    if write_op(p, OP_FROZENSET) < 0 {
        return -1;
    }
    return memo_put(p, obj_);
}

impl save_frozenset(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    s = p.view(1);
    if s[0].fast != 0 and not fast_save_enter(p, obj_) {
        return -1;
    }
    status = save_frozenset_impl(p, obj_);
    if s[0].fast != 0 and not fast_save_leave(p, obj_) {
        return -1;
    }
    return status;
}

impl fix_imports(
    p: ptr[PicklerRec], module_name: ptr[PyObject], global_name: ptr[PyObject]
) -> (i32, ptr[PyObject], ptr[PyObject]) {
    key = PyTuple_Pack(2, module_name, global_name);
    if not key {
        return (i32(-1), module_name, global_name);
    }
    item = PyDict_GetItemWithError(state_object(p, SLOT_NAME_MAPPING_3TO2), key);
    object_decref(key);
    if item {
        if not tuple_check(item) or object_size(item) != 2 {
            PyErr_Format(
                PyExc_RuntimeError,
                ptr[u8](
                    "_compat_pickle.REVERSE_NAME_MAPPING values should be 2-tuples, not %.200s"
                ),
                ptr[u8](object_type(item).view(1)[0].tp_name)
            );
            return (i32(-1), module_name, global_name);
        }
        fixed_module_name = tuple_get_item(item, 0);
        fixed_global_name = tuple_get_item(item, 1);
        if not unicode_check(fixed_module_name)
            or not unicode_check(fixed_global_name) {
            PyErr_Format(
                PyExc_RuntimeError,
                ptr[u8](
                    "_compat_pickle.REVERSE_NAME_MAPPING values should be pairs of str, not (%.200s, %.200s)"
                ),
                ptr[u8](object_type(fixed_module_name).view(1)[0].tp_name),
                ptr[u8](object_type(fixed_global_name).view(1)[0].tp_name)
            );
            return (i32(-1), module_name, global_name);
        }
        object_decref(module_name);
        object_decref(global_name);
        return (
            i32(0),
            object_new_ref(fixed_module_name),
            object_new_ref(fixed_global_name)
        );
    }
    if PyErr_Occurred() {
        return (i32(-1), module_name, global_name);
    }
    item = PyDict_GetItemWithError(
        state_object(p, SLOT_IMPORT_MAPPING_3TO2), module_name
    );
    if item {
        if not unicode_check(item) {
            PyErr_Format(
                PyExc_RuntimeError,
                ptr[u8](
                    "_compat_pickle.REVERSE_IMPORT_MAPPING values should be strings, not %.200s"
                ),
                ptr[u8](object_type(item).view(1)[0].tp_name)
            );
            return (i32(-1), module_name, global_name);
        }
        object_decref(module_name);
        return (i32(0), object_new_ref(item), global_name);
    }
    if PyErr_Occurred() {
        return (i32(-1), module_name, global_name);
    }
    return (i32(0), module_name, global_name);
}

impl check_dotted_path(
    p: ptr[PicklerRec], obj_: ptr[PyObject], dotted_path: ptr[PyObject]
) -> i32 {
    n = object_size(dotted_path);
    i: i64 = 0;
    while i < n {
        if _PyUnicode_EqualToASCIIString(list_item(dotted_path, i), ptr[u8]("<locals>"))
            != 0 {
            PyErr_Format(
                p.view(1)[0].error, ptr[u8]("Can't pickle local object %R"), obj_
            );
            return -1;
        }
        i += 1;
    }
    return 0;
}

impl getattribute(
    obj_: ptr[PyObject], names: ptr[PyObject], raises: bool
) -> ptr[PyObject] {
    object_incref(obj_);
    n = object_size(names);
    i: i64 = 0;
    while i < n {
        name = list_item(names, i);
        parent = obj_;
        if raises {
            obj_ = PyObject_GetAttr(parent, name);
        } else {
            found = NULL;
            PyObject_GetOptionalAttr(parent, name, &mut found);
            obj_ = found;
        }
        object_decref(parent);
        if not obj_ {
            return NULL;
        }
        i += 1;
    }
    return obj_;
}

impl checkmodule(
    module_name: ptr[PyObject],
    module: ptr[PyObject],
    global_obj: ptr[PyObject],
    dotted_path: ptr[PyObject]
) -> i32 {
    if module == Py_None {
        return -1;
    }
    if unicode_check(module_name)
        and _PyUnicode_EqualToASCIIString(module_name, ptr[u8]("__main__")) != 0 {
        return -1;
    }
    candidate = getattribute(module, dotted_path, False);
    if not candidate {
        return -1;
    }
    same = candidate == global_obj;
    object_decref(candidate);
    if same {
        return 0;
    }
    return -1;
}

impl search_modules(
    global_obj: ptr[PyObject], dotted_path: ptr[PyObject]
) -> (i32, ptr[PyObject]) {
    modules = PySys_GetObject(ptr[u8]("modules"));
    if not modules {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("lost sys.modules"));
        return (i32(-1), NULL);
    }
    object_incref(modules);
    if dict_check_exact(modules) {
        i: i64 = 0;
        module_name = NULL;
        module = NULL;
        while PyDict_Next(modules, &mut i, &mut module_name, &mut module) != 0 {
            object_incref(module_name);
            object_incref(module);
            if checkmodule(module_name, module, global_obj, dotted_path) == 0 {
                object_decref(module);
                object_decref(modules);
                return (i32(0), module_name);
            }
            object_decref(module);
            object_decref(module_name);
            if PyErr_Occurred() {
                object_decref(modules);
                return (i32(-1), NULL);
            }
        }
    } else {
        iterator = PyObject_GetIter(modules);
        if not iterator {
            object_decref(modules);
            return (i32(-1), NULL);
        }
        while True {
            module_name = PyIter_Next(iterator);
            if not module_name {
                break;
            }
            module = PyObject_GetItem(modules, module_name);
            if not module {
                object_decref(module_name);
                object_decref(iterator);
                object_decref(modules);
                return (i32(-1), NULL);
            }
            if checkmodule(module_name, module, global_obj, dotted_path) == 0 {
                object_decref(module);
                object_decref(iterator);
                object_decref(modules);
                return (i32(0), module_name);
            }
            object_decref(module);
            object_decref(module_name);
            if PyErr_Occurred() {
                object_decref(iterator);
                object_decref(modules);
                return (i32(-1), NULL);
            }
        }
        object_decref(iterator);
    }
    object_decref(modules);
    if PyErr_Occurred() {
        return (i32(-1), NULL);
    }
    return (i32(0), NULL);
}

impl whichmodule(
    p: ptr[PicklerRec],
    global_obj: ptr[PyObject],
    global_name: ptr[PyObject],
    dotted_path: ptr[PyObject]
) -> ptr[PyObject] {
    error = p.view(1)[0].error;
    if check_dotted_path(p, global_obj, dotted_path) < 0 {
        return NULL;
    }
    module_name = NULL;
    if PyObject_GetOptionalAttr(global_obj, py_id(_Py_ID___module__), &mut module_name)
        < 0 {
        return NULL;
    }
    if not module_name or module_name == Py_None {
        object_xdecref(module_name);
        (status, found) = search_modules(global_obj, dotted_path);
        if status < 0 {
            return NULL;
        }
        module_name = found;
        if not module_name {
            module_name = object_new_ref(py_id(_Py_ID___main__));
        }
    }
    module = PyImport_Import(module_name);
    if not module {
        if PyErr_ExceptionMatches(PyExc_ImportError) != 0
            or PyErr_ExceptionMatches(PyExc_ValueError) != 0 {
            exc = PyErr_GetRaisedException();
            PyErr_Format(error, ptr[u8]("Can't pickle %R: %S"), global_obj, exc);
            _PyErr_ChainExceptions1(exc);
        }
        object_decref(module_name);
        return NULL;
    }
    actual = getattribute(module, dotted_path, True);
    object_decref(module);
    if not actual {
        if PyErr_ExceptionMatches(PyExc_AttributeError) != 0 {
            exc = PyErr_GetRaisedException();
            PyErr_Format(
                error,
                ptr[u8]("Can't pickle %R: it's not found as %S.%S"),
                global_obj,
                module_name,
                global_name
            );
            _PyErr_ChainExceptions1(exc);
        }
        object_decref(module_name);
        return NULL;
    }
    if actual != global_obj {
        object_decref(actual);
        PyErr_Format(
            error,
            ptr[u8]("Can't pickle %R: it's not the same object as %S.%S"),
            global_obj,
            module_name,
            global_name
        );
        object_decref(module_name);
        return NULL;
    }
    object_decref(actual);
    return module_name;
}

impl save_extension(
    p: ptr[PicklerRec], module_name: ptr[PyObject], global_name: ptr[PyObject]
) -> i32 {
    extension_key = PyTuple_Pack(2, module_name, global_name);
    if not extension_key {
        return -1;
    }
    code_obj = NULL;
    if PyDict_GetItemRef(
        state_object(p, SLOT_EXTENSION_REGISTRY), extension_key, &mut code_obj
    )
        < 0 {
        object_decref(extension_key);
        return -1;
    }
    object_decref(extension_key);
    if not code_obj {
        return 0;
    }
    code = PyLong_AsLong(code_obj);
    object_decref(code_obj);
    if code <= 0 or code > 0x7fffffff {
        if not PyErr_Occurred() {
            PyErr_Format(
                PyExc_RuntimeError, ptr[u8]("extension code %ld is out of range"), code
            );
        }
        return -1;
    }
    status: i32 = 0;
    if code <= 0xff {
        status = write_op2(p, OP_EXT1, u8.wrap(code));
    } elif code <= 0xffff {
        out = reserve(p, 3);
        if not out {
            return -1;
        }
        out.view(1)[0] = OP_EXT2;
        put_le(out + 1, code, 2);
    } else {
        out = reserve(p, 5);
        if not out {
            return -1;
        }
        out.view(1)[0] = OP_EXT4;
        put_le(out + 1, code, 4);
    }
    if status < 0 {
        return -1;
    }
    return 1;
}

impl write_identifier(p: ptr[PicklerRec], name: ptr[PyObject], module: bool) -> i32 {
    s = p.view(1);
    encoded = NULL;
    if s[0].proto == 3 {
        encoded = PyUnicode_AsUTF8String(name);
    } else {
        encoded = PyUnicode_AsASCIIString(name);
    }
    if not encoded {
        if PyErr_ExceptionMatches(PyExc_UnicodeEncodeError) != 0 {
            exc = PyErr_GetRaisedException();
            if module {
                PyErr_Format(
                    s[0].error,
                    ptr[u8](
                        "can't pickle module identifier %R using pickle protocol %i"
                    ),
                    name,
                    s[0].proto
                );
            } else {
                PyErr_Format(
                    s[0].error,
                    ptr[u8](
                        "can't pickle global identifier %R using pickle protocol %i"
                    ),
                    name,
                    s[0].proto
                );
            }
            _PyErr_ChainExceptions1(exc);
        }
        return -1;
    }
    status: i32 = 0;
    if write(p, bytes_data(encoded), object_size(encoded)) < 0
        or write_op(p, u8(10)) < 0 {
        status = -1;
    }
    object_decref(encoded);
    return status;
}

impl save_global_text(
    p: ptr[PicklerRec],
    module_name: ptr[PyObject],
    global_name: ptr[PyObject],
    dotted_path: ptr[PyObject]
) -> (i32, ptr[PyObject], ptr[PyObject]) {
    s = p.view(1);
    parts = object_size(dotted_path);
    if parts > 1 {
        first = object_new_ref(list_item(dotted_path, 0));
        object_decref(global_name);
        global_name = first;
    }
    i: i64 = 1;
    while i < parts {
        if save(p, state_object(p, SLOT_GETATTR), 0) < 0 {
            return (i32(-1), module_name, global_name);
        }
        if s[0].proto < 2 and write_op(p, OP_MARK) < 0 {
            return (i32(-1), module_name, global_name);
        }
        i += 1;
    }
    if write_op(p, OP_GLOBAL) < 0 {
        return (i32(-1), module_name, global_name);
    }
    if s[0].proto < 3 and s[0].fix_imports != 0 {
        (status, fixed_module, fixed_global) = fix_imports(p, module_name, global_name);
        module_name = fixed_module;
        global_name = fixed_global;
        if status < 0 {
            return (i32(-1), module_name, global_name);
        }
    }
    if write_identifier(p, module_name, True) < 0
        or write_identifier(p, global_name, False) < 0 {
        return (i32(-1), module_name, global_name);
    }
    tupletwo_op = OP_TUPLE if s[0].proto < 2 else OP_TUPLE2;
    i = 1;
    while i < parts {
        if save(p, list_item(dotted_path, i), 0) < 0
            or write_op2(p, tupletwo_op, OP_REDUCE) < 0 {
            return (i32(-1), module_name, global_name);
        }
        i += 1;
    }
    return (i32(0), module_name, global_name);
}

impl save_singleton_type(
    p: ptr[PicklerRec], obj_: ptr[PyObject], singleton: ptr[PyObject]
) -> i32 {
    reduce_value = Py_BuildValue(ptr[u8]("O(O)"), addressof(PyType_Type), singleton);
    if not reduce_value {
        return -1;
    }
    status = save_reduce(p, reduce_value, obj_);
    object_decref(reduce_value);
    return status;
}

impl save_type(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if obj_ == ptr[PyObject](object_type(Py_None)) {
        return save_singleton_type(p, obj_, Py_None);
    }
    if obj_ == ptr[PyObject](object_type(Py_Ellipsis)) {
        return save_singleton_type(p, obj_, Py_Ellipsis);
    }
    if obj_ == ptr[PyObject](object_type(Py_NotImplemented)) {
        return save_singleton_type(p, obj_, Py_NotImplemented);
    }
    return save_global(p, obj_, NULL);
}

impl save_pers(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    s = p.view(1);
    pid = PyObject_CallOneArg(s[0].persistent_id, obj_);
    if not pid {
        return -1;
    }
    status: i32 = 0;
    if pid != Py_None {
        status = 1;
        if s[0].bin != 0 {
            if save(p, pid, 1) < 0 or write_op(p, OP_BINPERSID) < 0 {
                status = -1;
            }
        } else {
            pid_str = PyObject_Str(pid);
            if not pid_str {
                status = -1;
            } else {
                encoded = PyUnicode_AsASCIIString(pid_str);
                if not encoded {
                    if PyErr_ExceptionMatches(PyExc_UnicodeEncodeError) != 0 {
                        PyErr_SetString(
                            s[0].error,
                            ptr[u8](
                                "persistent IDs in protocol 0 must be ASCII strings"
                            )
                        );
                    }
                    status = -1;
                } else {
                    if write_op(p, OP_PERSID) < 0
                        or write(p, bytes_data(encoded), object_size(encoded)) < 0
                        or write_op(p, u8(10)) < 0 {
                        status = -1;
                    }
                    object_decref(encoded);
                }
                object_decref(pid_str);
            }
        }
    }
    object_decref(pid);
    return status;
}

impl get_class(obj_: ptr[PyObject]) -> ptr[PyObject] {
    cls = NULL;
    if PyObject_GetOptionalAttr(obj_, py_id(_Py_ID___class__), &mut cls) == 0 {
        cls = object_new_ref(ptr[PyObject](object_type(obj_)));
    }
    return cls;
}

impl save_newobj_ex(
    p: ptr[PicklerRec], argtup: ptr[PyObject], obj_: ptr[PyObject]
) -> i32 {
    s = p.view(1);
    if object_size(argtup) != 3 {
        PyErr_Format(
            s[0].error,
            ptr[u8]("__newobj_ex__ expected 3 arguments, got %zd"),
            object_size(argtup)
        );
        return -1;
    }
    cls = tuple_get_item(argtup, 0);
    if not type_check(cls) {
        PyErr_Format(
            s[0].error,
            ptr[u8]("first argument to __newobj_ex__() must be a class, not %T"),
            cls
        );
        return -1;
    }
    args = tuple_get_item(argtup, 1);
    if not tuple_check(args) {
        PyErr_Format(
            s[0].error,
            ptr[u8]("second argument to __newobj_ex__() must be a tuple, not %T"),
            args
        );
        return -1;
    }
    kwargs = tuple_get_item(argtup, 2);
    if not dict_check(kwargs) {
        PyErr_Format(
            s[0].error,
            ptr[u8]("third argument to __newobj_ex__() must be a dict, not %T"),
            kwargs
        );
        return -1;
    }
    if s[0].proto >= 4 {
        if save(p, cls, 0) < 0 {
            _PyErr_FormatNote(ptr[u8]("when serializing %T class"), obj_);
            return -1;
        }
        if save(p, args, 0) < 0 or save(p, kwargs, 0) < 0 {
            _PyErr_FormatNote(ptr[u8]("when serializing %T __new__ arguments"), obj_);
            return -1;
        }
        return write_op(p, OP_NEWOBJ_EX);
    }
    count = object_size(args);
    newargs = PyTuple_New(count + 2);
    if not newargs {
        return -1;
    }
    cls_new = PyObject_GetAttr(cls, py_id(_Py_ID___new__));
    if not cls_new {
        object_decref(newargs);
        return -1;
    }
    tuple_set_item(newargs, 0, cls_new);
    tuple_set_item(newargs, 1, object_new_ref(cls));
    i: i64 = 0;
    while i < count {
        tuple_set_item(newargs, i + 2, object_new_ref(tuple_get_item(args, i)));
        i += 1;
    }
    callable = PyObject_Call(state_object(p, SLOT_PARTIAL), newargs, kwargs);
    object_decref(newargs);
    if not callable {
        return -1;
    }
    empty = PyTuple_New(0);
    if not empty {
        object_decref(callable);
        return -1;
    }
    if save(p, callable, 0) < 0 or save(p, empty, 0) < 0 {
        _PyErr_FormatNote(ptr[u8]("when serializing %T reconstructor"), obj_);
        object_decref(empty);
        object_decref(callable);
        return -1;
    }
    object_decref(empty);
    object_decref(callable);
    return write_op(p, OP_REDUCE);
}

impl save_newobj(
    p: ptr[PicklerRec], argtup: ptr[PyObject], obj_: ptr[PyObject]
) -> i32 {
    s = p.view(1);
    if object_size(argtup) < 1 {
        PyErr_Format(
            s[0].error,
            ptr[u8]("__newobj__ expected at least 1 argument, got %zd"),
            object_size(argtup)
        );
        return -1;
    }
    cls = tuple_get_item(argtup, 0);
    if not type_check(cls) {
        PyErr_Format(
            s[0].error,
            ptr[u8]("first argument to __newobj__() must be a class, not %T"),
            cls
        );
        return -1;
    }
    if obj_ {
        obj_class = get_class(obj_);
        if not obj_class {
            return -1;
        }
        if obj_class != cls {
            PyErr_Format(
                s[0].error,
                ptr[u8]("first argument to __newobj__() must be %R, not %R"),
                obj_class,
                cls
            );
            object_decref(obj_class);
            return -1;
        }
        object_decref(obj_class);
    }
    if save(p, cls, 0) < 0 {
        _PyErr_FormatNote(ptr[u8]("when serializing %T class"), obj_);
        return -1;
    }
    newargtup = PyTuple_GetSlice(argtup, 1, object_size(argtup));
    if not newargtup {
        return -1;
    }
    status = save(p, newargtup, 0);
    object_decref(newargtup);
    if status < 0 {
        _PyErr_FormatNote(ptr[u8]("when serializing %T __new__ arguments"), obj_);
        return -1;
    }
    return write_op(p, OP_NEWOBJ);
}

impl save_state(
    p: ptr[PicklerRec],
    obj_: ptr[PyObject],
    state: ptr[PyObject],
    state_setter: ptr[PyObject]
) -> i32 {
    if not state_setter {
        if save(p, state, 0) < 0 {
            _PyErr_FormatNote(ptr[u8]("when serializing %T state"), obj_);
            return -1;
        }
        return write_op(p, OP_BUILD);
    }
    if save(p, state_setter, 0) < 0 {
        _PyErr_FormatNote(ptr[u8]("when serializing %T state setter"), obj_);
        return -1;
    }
    if save(p, obj_, 0) < 0 {
        return -1;
    }
    if save(p, state, 0) < 0 {
        _PyErr_FormatNote(ptr[u8]("when serializing %T state"), obj_);
        return -1;
    }
    out = reserve(p, 3);
    if not out {
        return -1;
    }
    out.view(3)[0] = OP_TUPLE2;
    out.view(3)[1] = OP_REDUCE;
    out.view(3)[2] = OP_POP;
    return 0;
}

impl save_reduce_value(
    p: ptr[PicklerRec], obj_: ptr[PyObject], reduce_value: ptr[PyObject]
) -> i32 {
    if unicode_check(reduce_value) {
        return save_global(p, obj_, reduce_value);
    }
    if not tuple_check(reduce_value) {
        PyErr_Format(
            p.view(1)[0].error,
            ptr[u8]("__reduce__ must return a string or tuple, not %T"),
            reduce_value
        );
        _PyErr_FormatNote(ptr[u8]("when serializing %T object"), obj_);
        return -1;
    }
    status = save_reduce(p, reduce_value, obj_);
    if status < 0 {
        _PyErr_FormatNote(ptr[u8]("when serializing %T object"), obj_);
    }
    return status;
}

impl save_object(p: ptr[PicklerRec], obj_: ptr[PyObject], type: ptr[PyObject]) -> i32 {
    s = p.view(1);
    if type == addressof(PyDict_Type) {
        return save_dict(p, obj_);
    }
    if type == addressof(PySet_Type) {
        return save_set(p, obj_);
    }
    if type == addressof(PyFrozenSet_Type) {
        return save_frozenset(p, obj_);
    }
    if type == addressof(PyList_Type) {
        return save_list(p, obj_);
    }
    if type == addressof(PyTuple_Type) {
        return save_tuple(p, obj_);
    }
    if type == addressof(PyByteArray_Type) {
        return save_bytearray(p, obj_);
    }
    if type == addressof(PyPickleBuffer_Type) {
        return save_picklebuffer(p, obj_);
    }
    if s[0].reducer_override {
        reduce_value = PyObject_CallOneArg(s[0].reducer_override, obj_);
        if not reduce_value {
            return -1;
        }
        if reduce_value != Py_NotImplemented {
            status = save_reduce_value(p, obj_, reduce_value);
            object_decref(reduce_value);
            return status;
        }
        object_decref(reduce_value);
    }
    if type == ptr[PyObject](addressof(PyType_Type)) {
        return save_type(p, obj_);
    }
    if type == addressof(PyFunction_Type) {
        return save_global(p, obj_, NULL);
    }
    reduce_func = NULL;
    if not s[0].dispatch_table {
        reduce_func = PyDict_GetItemWithError(state_object(p, SLOT_DISPATCH), type);
        if not reduce_func {
            if PyErr_Occurred() {
                return -1;
            }
        } else {
            object_incref(reduce_func);
        }
    } elif PyMapping_GetOptionalItem(s[0].dispatch_table, type, &mut reduce_func) < 0 {
        return -1;
    }
    reduce_value = NULL;
    if reduce_func {
        reduce_value = PyObject_CallOneArg(reduce_func, obj_);
    } elif PyType_IsSubtype(type, ptr[PyObject](addressof(PyType_Type))) != 0 {
        return save_global(p, obj_, NULL);
    } else {
        reduce_ex_text = interned(reduce_ex_text, ptr[u8]("__reduce_ex__"));
        if not reduce_ex_text {
            return -1;
        }
        if PyObject_GetOptionalAttr(obj_, reduce_ex_text, &mut reduce_func) < 0 {
            return -1;
        }
        if reduce_func {
            proto = PyLong_FromLong(i64(s[0].proto));
            if proto {
                reduce_value = PyObject_CallOneArg(reduce_func, proto);
                object_decref(proto);
            }
        } else {
            if PyObject_GetOptionalAttr(
                obj_, py_id(_Py_ID___reduce__), &mut reduce_func
            )
                < 0 {
                return -1;
            }
            if reduce_func {
                reduce_value = PyObject_CallNoArgs(reduce_func);
            } else {
                PyErr_Format(s[0].error, ptr[u8]("Can't pickle %T object"), obj_);
                return -1;
            }
        }
    }
    object_decref(reduce_func);
    if not reduce_value {
        return -1;
    }
    status = save_reduce_value(p, obj_, reduce_value);
    object_decref(reduce_value);
    return status;
}

impl pickler_dump(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    s = p.view(1);
    status: i32 = -1;
    proto_ok = True;
    if s[0].proto >= 2 {
        if write_op2(p, OP_PROTO, u8.wrap(s[0].proto)) < 0 {
            proto_ok = False;
        } elif s[0].proto >= 4 {
            s[0].framing = 1;
        }
    }
    if proto_ok and save(p, obj_, 0) >= 0 and write_op(p, OP_STOP) == 0 {
        commit_frame(p);
        status = 0;
    }
    s[0].framing = 0;
    return status;
}

impl set_protocol(
    p: ptr[PicklerRec], protocol: ptr[PyObject], fix_imports: bool
) -> i32 {
    proto = DEFAULT_PROTOCOL;
    if protocol != Py_None {
        proto = PyLong_AsLong(protocol);
        if proto < 0 {
            if proto == -1 and PyErr_Occurred() {
                return -1;
            }
            proto = HIGHEST_PROTOCOL;
        } elif proto > HIGHEST_PROTOCOL {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("pickle protocol must be <= %d"),
                i32(HIGHEST_PROTOCOL)
            );
            return -1;
        }
    }
    s = p.view(1);
    s[0].proto = i32(proto);
    s[0].bin = i32(1) if proto > 0 else i32(0);
    s[0].fix_imports = i32(1) if fix_imports and proto < 3 else i32(0);
    return 0;
}

impl set_buffer_callback(p: ptr[PicklerRec], buffer_callback: ptr[PyObject]) -> i32 {
    if buffer_callback == Py_None {
        buffer_callback = NULL;
    }
    s = p.view(1);
    if buffer_callback and s[0].proto < 5 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("buffer_callback needs protocol >= 5")
        );
        return -1;
    }
    old = s[0].buffer_callback;
    s[0].buffer_callback = ptr[PyObject]();
    if buffer_callback {
        s[0].buffer_callback = object_new_ref(buffer_callback);
    }
    object_xdecref(old);
    return 0;
}

impl pickler_prepare(p: ptr[PicklerRec], module: ptr[PyObject]) -> i32 {
    s = p.view(1);
    s[0].module = module;
    s[0].frame_start = -1;
    if not s[0].error {
        s[0].error = object_new_ref(
            jacpy_binding_state_get(module, SLOT_PICKLING_ERROR)
        );
    }
    if not s[0].mt_table and memo_alloc(p, MT_MINSIZE) < 0 {
        return -1;
    }
    s[0].output_len = 0;
    if not s[0].output_buffer {
        s[0].max_output_len = WRITE_BUF_SIZE;
        s[0].output_buffer = PyBytes_FromStringAndSize(ptr[u8](), WRITE_BUF_SIZE);
        if not s[0].output_buffer {
            return -1;
        }
    }
    return 0;
}

impl pickler_release(p: ptr[PicklerRec]) {
    s = p.view(1);
    memo_free(p);
    output = s[0].output_buffer;
    s[0].output_buffer = ptr[PyObject]();
    object_xdecref(output);
    write_ = s[0].write;
    s[0].write = ptr[PyObject]();
    object_xdecref(write_);
    pid = s[0].persistent_id;
    s[0].persistent_id = ptr[PyObject]();
    object_xdecref(pid);
    dispatch = s[0].dispatch_table;
    s[0].dispatch_table = ptr[PyObject]();
    object_xdecref(dispatch);
    reducer = s[0].reducer_override;
    s[0].reducer_override = ptr[PyObject]();
    object_xdecref(reducer);
    fast_memo = s[0].fast_memo;
    s[0].fast_memo = ptr[PyObject]();
    object_xdecref(fast_memo);
    callback = s[0].buffer_callback;
    s[0].buffer_callback = ptr[PyObject]();
    object_xdecref(callback);
    error = s[0].error;
    s[0].error = ptr[PyObject]();
    object_xdecref(error);
}

impl pickler_new -> ptr[PicklerRec] {
    p = ptr[PicklerRec](PyMem_Calloc(u64(1), PICKLER_REC_SIZE));
    if not p {
        PyErr_NoMemory();
        return ptr[PicklerRec]();
    }
    p.view(1)[0].frame_start = -1;
    return p;
}

impl pickler_free(p: ptr[PicklerRec]) {
    pickler_release(p);
    PyMem_Free(ptr(p));
}

impl visit_slot(value: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    if not value {
        return 0;
    }
    return visit_reference(value, visitor, context);
}

impl pickler_traverse(p: ptr[PicklerRec], visitor: ptr, context: ptr) -> i32 {
    s = p.view(1);
    status = visit_slot(s[0].write, visitor, context);
    if status == 0 {
        status = visit_slot(s[0].persistent_id, visitor, context);
    }
    if status == 0 {
        status = visit_slot(s[0].dispatch_table, visitor, context);
    }
    if status == 0 {
        status = visit_slot(s[0].fast_memo, visitor, context);
    }
    if status == 0 {
        status = visit_slot(s[0].reducer_override, visitor, context);
    }
    if status == 0 {
        status = visit_slot(s[0].buffer_callback, visitor, context);
    }
    table = s[0].mt_table;
    if status == 0 and table {
        i = s[0].mt_allocated;
        while i > 0 and status == 0 {
            i -= 1;
            status = visit_slot((table + i).view(1)[0].me_key, visitor, context);
        }
    }
    return status;
}

impl pickler_init(
    p: ptr[PicklerRec],
    module: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> i32 {
    s = p.view(1);
    if s[0].write {
        pickler_release(p);
    }
    if set_protocol(p, protocol, fix_imports) < 0 {
        return -1;
    }
    write_ = NULL;
    if PyObject_GetOptionalAttr(file, py_id(_Py_ID_write), &mut write_) < 0 {
        return -1;
    }
    if not write_ {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("file must have a 'write' attribute"));
        return -1;
    }
    s[0].write = write_;
    if set_buffer_callback(p, buffer_callback) < 0 {
        return -1;
    }
    if pickler_prepare(p, module) < 0 {
        return -1;
    }
    s[0].fast = 0;
    s[0].fast_nesting = 0;
    return 0;
}

impl swap_slot(slot: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    object_xdecref(slot);
    if value {
        return object_new_ref(value);
    }
    return ptr[PyObject]();
}

impl pickler_dump_file(
    p: ptr[PicklerRec],
    obj_: ptr[PyObject],
    persistent_id: ptr[PyObject],
    reducer_override: ptr[PyObject],
    dispatch_table: ptr[PyObject],
    fast: i32
) -> i32 {
    s = p.view(1);
    s[0].fast = fast;
    if clear_buffer(p) < 0 {
        return -1;
    }
    s[0].persistent_id = swap_slot(s[0].persistent_id, persistent_id);
    s[0].reducer_override = swap_slot(s[0].reducer_override, reducer_override);
    s[0].dispatch_table = swap_slot(s[0].dispatch_table, dispatch_table);
    status = pickler_dump(p, obj_);
    s[0].persistent_id = swap_slot(s[0].persistent_id, NULL);
    s[0].reducer_override = swap_slot(s[0].reducer_override, NULL);
    s[0].dispatch_table = swap_slot(s[0].dispatch_table, NULL);
    if status == 0 {
        status = flush_to_file(p);
    }
    return status;
}

impl pickler_memo_copy(p: ptr[PicklerRec]) -> ptr[PyObject] {
    new_memo = PyDict_New();
    if not new_memo {
        return NULL;
    }
    s = p.view(1);
    table = s[0].mt_table;
    i: i64 = 0;
    while i < s[0].mt_allocated {
        entry_key = (table + i).view(1)[0].me_key;
        if entry_key {
            key = PyLong_FromVoidPtr(ptr(entry_key));
            if not key {
                object_decref(new_memo);
                return NULL;
            }
            value = Py_BuildValue(
                ptr[u8]("nO"), (table + i).view(1)[0].me_value, entry_key
            );
            if not value {
                object_decref(key);
                object_decref(new_memo);
                return NULL;
            }
            status = PyDict_SetItem(new_memo, key, value);
            object_decref(key);
            object_decref(value);
            if status < 0 {
                object_decref(new_memo);
                return NULL;
            }
        }
        i += 1;
    }
    return new_memo;
}

impl pickler_memo_clear(p: ptr[PicklerRec]) -> i32 {
    memo_free(p);
    return memo_alloc(p, MT_MINSIZE);
}

impl pickler_memo_set(p: ptr[PicklerRec], obj_: ptr[PyObject]) -> i32 {
    if not dict_check(obj_) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "'memo' attribute must be a PicklerMemoProxy object or dict, not %.200s"
            ),
            ptr[u8](object_type(obj_).view(1)[0].tp_name)
        );
        return -1;
    }
    s = p.view(1);
    old_table = s[0].mt_table;
    old_mask = s[0].mt_mask;
    old_used = s[0].mt_used;
    old_allocated = s[0].mt_allocated;
    s[0].mt_table = ptr[MemoEntry]();
    status: i32 = memo_alloc(p, MT_MINSIZE);
    pos: i64 = 0;
    key = NULL;
    value = NULL;
    while status == 0 and PyDict_Next(obj_, &mut pos, &mut key, &mut value) != 0 {
        if not tuple_check(value) or object_size(value) != 2 {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("'memo' values must be 2-item tuples")
            );
            status = -1;
        } else {
            memo_id = PyLong_AsSsize_t(tuple_get_item(value, 0));
            if memo_id == -1 and PyErr_Occurred() {
                status = -1;
            } else {
                status = memo_set(p, tuple_get_item(value, 1), memo_id);
            }
        }
    }
    if status < 0 {
        memo_free(p);
        s[0].mt_table = old_table;
        s[0].mt_mask = old_mask;
        s[0].mt_used = old_used;
        s[0].mt_allocated = old_allocated;
        return -1;
    }
    new_table = s[0].mt_table;
    new_mask = s[0].mt_mask;
    new_used = s[0].mt_used;
    new_allocated = s[0].mt_allocated;
    s[0].mt_table = old_table;
    s[0].mt_mask = old_mask;
    s[0].mt_used = old_used;
    s[0].mt_allocated = old_allocated;
    memo_free(p);
    s[0].mt_table = new_table;
    s[0].mt_mask = new_mask;
    s[0].mt_used = new_used;
    s[0].mt_allocated = new_allocated;
    return 0;
}

impl pickler_sizeof(p: ptr[PicklerRec]) -> i64 {
    s = p.view(1);
    res: i64 = 0;
    if s[0].mt_table {
        res = MEMO_TABLE_SIZE + s[0].mt_allocated * MEMO_ENTRY_SIZE;
    }
    if s[0].output_buffer {
        size = _PySys_GetSizeOf(s[0].output_buffer);
        if size == u64(0xFFFFFFFFFFFFFFFF) {
            return -1;
        }
        res += i64(size);
    }
    return res;
}

impl pickle_dumps(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own PicklerStack = PicklerStack();
    p = ptr[PicklerRec](jacpy_stack_address(&mut slots));
    result = NULL;
    if pickler_prepare(p, module) == 0
        and set_protocol(p, protocol, fix_imports) == 0
        and set_buffer_callback(p, buffer_callback) == 0
        and pickler_dump(p, obj_) == 0 {
        result = get_string(p);
    }
    pickler_release(p);
    return result;
}

impl pickle_dump(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own PicklerStack = PicklerStack();
    p = ptr[PicklerRec](jacpy_stack_address(&mut slots));
    status: i32 = -1;
    if pickler_prepare(p, module) == 0
        and set_protocol(p, protocol, fix_imports) == 0 {
        write_ = NULL;
        if PyObject_GetOptionalAttr(file, py_id(_Py_ID_write), &mut write_) >= 0 {
            if not write_ {
                PyErr_SetString(
                    PyExc_TypeError, ptr[u8]("file must have a 'write' attribute")
                );
            } else {
                p.view(1)[0].write = write_;
                if set_buffer_callback(p, buffer_callback) == 0
                    and pickler_dump(p, obj_) == 0
                    and flush_to_file(p) == 0 {
                    status = 0;
                }
            }
        }
    }
    pickler_release(p);
    if status < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}
