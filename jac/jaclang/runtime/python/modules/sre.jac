"""The _sre module: Secret Labs' Regular Expression Engine.

Modules/_sre/sre.c and sre.h in native Jac: the Pattern, Match, Scanner and
Template objects, laid out as sre.h lays them out (a pattern's code and a
match's marks inside the object), the matching state, the code validator and
the module functions. The engine is modules/sre_engine.jac and the
per-width matchers modules/sre_ucs{1,2,4}.jac. The module state is the
binding layer's reference slots, indexed by the STATE_* constants. See
../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBuffer_Release,
    PyBytes_FromObject,
    PyBytes_Join,
    PyBytes_Type,
    PyCallable_Check,
    PyDictProxy_New,
    PyDict_GetItemWithError,
    PyDict_New,
    PyDict_Next,
    PyDict_SetItem,
    PyDict_Size,
    PyErr_Clear,
    PyErr_ExceptionMatches,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetString,
    PyExc_IndexError,
    PyExc_OverflowError,
    PyExc_RecursionError,
    PyExc_RuntimeError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyImport_ImportModuleAttrString,
    PyIndex_Check,
    PyList_Append,
    PyList_GetItem,
    PyList_New,
    PyList_Size,
    PyLong_AsSsize_t,
    PyLong_AsUnsignedLong,
    PyLong_FromSsize_t,
    PyMem_Calloc,
    PyMem_Free,
    PyMem_Malloc,
    PyNumber_AsSsize_t,
    PyObject,
    PyObject_CheckBuffer,
    PyObject_ClearWeakRefs,
    PyObject_GC_Del,
    PyObject_GC_Track,
    PyObject_GC_UnTrack,
    PyObject_GetAttrString,
    PyObject_GetBuffer,
    PyObject_Hash,
    PyObject_RichCompareBool,
    PyObject_Vectorcall,
    PyTuple_New,
    PyTuple_Size,
    PyType_GetModule,
    PyUnicode_FindChar,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    PyUnicode_Join,
    PyUnicode_New,
    PyUnicode_Substring,
    Py_HashBuffer,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    Py_XNewRef,
    Py_buffer,
    _PyObject_GC_NewVar,
    _PyObject_GC_New,
    _PyUnicode_Copy,
    _PyUnicode_JoinArray,
    jacpy_buffer_new,
    jacpy_bytes_from_memory,
    jacpy_is_bytes,
    jacpy_is_long,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_unicode_data,
    jacpy_unicode_kind,
    jacpy_unicode_size
}
import from jaclang.runtime.python.layouts {
    PyTypeObject,
    PyBUF_SIMPLE,
    Py_EQ,
    Py_NE,
    _object
}
import from jaclang.runtime.python.object_model.header {
    object_size,
    object_type,
    tuple_get_item,
    tuple_set_item
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.object_model.iterator { PyCallIter_New }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_state_get,
    jacpy_binding_state_set,
    visit_reference
}
import from jaclang.runtime.python.modules.sre_constants {
    SRE_AT_BEGINNING,
    SRE_AT_BEGINNING_LINE,
    SRE_AT_BEGINNING_STRING,
    SRE_AT_BOUNDARY,
    SRE_AT_END,
    SRE_AT_END_LINE,
    SRE_AT_END_STRING,
    SRE_AT_LOC_BOUNDARY,
    SRE_AT_LOC_NON_BOUNDARY,
    SRE_AT_NON_BOUNDARY,
    SRE_AT_UNI_BOUNDARY,
    SRE_AT_UNI_NON_BOUNDARY,
    SRE_FLAG_ASCII,
    SRE_FLAG_DEBUG,
    SRE_FLAG_DOTALL,
    SRE_FLAG_IGNORECASE,
    SRE_FLAG_LOCALE,
    SRE_FLAG_MULTILINE,
    SRE_FLAG_UNICODE,
    SRE_FLAG_VERBOSE,
    SRE_INFO_CHARSET,
    SRE_INFO_LITERAL,
    SRE_INFO_PREFIX,
    SRE_OP_ANY,
    SRE_OP_ANY_ALL,
    SRE_OP_ASSERT,
    SRE_OP_ASSERT_NOT,
    SRE_OP_AT,
    SRE_OP_ATOMIC_GROUP,
    SRE_OP_BIGCHARSET,
    SRE_OP_BRANCH,
    SRE_OP_CATEGORY,
    SRE_OP_CHARSET,
    SRE_OP_FAILURE,
    SRE_OP_GROUPREF,
    SRE_OP_GROUPREF_EXISTS,
    SRE_OP_GROUPREF_IGNORE,
    SRE_OP_GROUPREF_LOC_IGNORE,
    SRE_OP_GROUPREF_UNI_IGNORE,
    SRE_OP_IN,
    SRE_OP_IN_IGNORE,
    SRE_OP_IN_LOC_IGNORE,
    SRE_OP_IN_UNI_IGNORE,
    SRE_OP_INFO,
    SRE_OP_JUMP,
    SRE_OP_LITERAL,
    SRE_OP_LITERAL_IGNORE,
    SRE_OP_LITERAL_LOC_IGNORE,
    SRE_OP_LITERAL_UNI_IGNORE,
    SRE_OP_MARK,
    SRE_OP_MAX_UNTIL,
    SRE_OP_MIN_REPEAT_ONE,
    SRE_OP_MIN_UNTIL,
    SRE_OP_NEGATE,
    SRE_OP_NOT_LITERAL,
    SRE_OP_NOT_LITERAL_IGNORE,
    SRE_OP_NOT_LITERAL_LOC_IGNORE,
    SRE_OP_NOT_LITERAL_UNI_IGNORE,
    SRE_OP_POSSESSIVE_REPEAT,
    SRE_OP_POSSESSIVE_REPEAT_ONE,
    SRE_OP_RANGE,
    SRE_OP_RANGE_UNI_IGNORE,
    SRE_OP_REPEAT,
    SRE_OP_REPEAT_ONE,
    SRE_OP_SUCCESS
}
import from jaclang.runtime.python.modules.sre_engine {
    SRE_ERROR_INTERRUPTED,
    SRE_ERROR_MEMORY,
    SRE_ERROR_RECURSION_LIMIT,
    SRE_MAXREPEAT,
    SRE_STATE_SIZE,
    SreRepeat,
    SreState,
    ascii_is_alpha,
    data_stack_dealloc,
    repeat_pool_clear,
    sre_lower_ascii,
    sre_lower_unicode,
    sre_upper_unicode
}
import from jaclang.runtime.python.modules.sre_ucs1 {
    sre_match as ucs1_match,
    sre_search as ucs1_search
}
import from jaclang.runtime.python.modules.sre_ucs2 {
    sre_match as ucs2_match,
    sre_search as ucs2_search
}
import from jaclang.runtime.python.modules.sre_ucs4 {
    sre_match as ucs4_match,
    sre_search as ucs4_search
}

import from c {
    def memset(target: ptr, value: i32, size: u64) -> ptr;  def memcmp(
        left: ptr, right: ptr, size: u64
    ) -> i32;  def memchr(source: ptr, value: i32, size: u64) -> ptr;
    # PatternObject: `code` is the first of `codesize` code words.
    obj PatternObject {
        has ob_refcnt: i64,
            ob_type: ptr,
            ob_size: i64,
            groups: i64,
            groupindex: ptr[PyObject],
            indexgroup: ptr[PyObject],
            pattern: ptr[PyObject],
            flags: i32,
            weakreflist: ptr[PyObject],
            isbytes: i32,
            codesize: i64,
            code: u32;
    }
    # MatchObject: `mark` is the first of 2 * `groups` marks.
    obj MatchObject {
        has ob_refcnt: i64,
            ob_type: ptr,
            ob_size: i64,
            string: ptr[PyObject],
            regs: ptr[PyObject],
            pattern: ptr[PyObject],
            pos: i64,
            endpos: i64,
            lastindex: i64,
            groups: i64,
            mark: i64;
    }
    # TemplateObject; its Py_SIZE items (TemplateItem) follow the header.
    obj TemplateObject {
        has ob_refcnt: i64,
            ob_type: ptr,
            ob_size: i64,
            chunks: i64,
            literal: ptr[PyObject];
    }  obj TemplateItem {
        has index: i64,
            literal: ptr[PyObject];
    }
    # ScannerObject: the matching state (SRE_STATE) is embedded at
    # SCANNER_STATE and the `executing` flag follows it at SCANNER_EXECUTING.
    obj ScannerObject {
        has ob_refcnt: i64,
            ob_type: ptr,
            pattern: ptr[PyObject];
    }
}

# The objects' sizes, the offsets of their variable parts and of the fields
# their member descriptors publish.
glob PATTERN_SIZE: Final[int] = 96,
     PATTERN_GROUPS: Final[int] = 24,
     PATTERN_PATTERN: Final[int] = 48,
     PATTERN_FLAGS: Final[int] = 56,
     PATTERN_WEAKREFLIST: Final[int] = 64,
     PATTERN_CODE: Final[int] = 88,
     MATCH_SIZE: Final[int] = 88,
     MATCH_STRING: Final[int] = 24,
     MATCH_PATTERN: Final[int] = 40,
     MATCH_POS: Final[int] = 48,
     MATCH_ENDPOS: Final[int] = 56,
     MATCH_MARK: Final[int] = 80,
     TEMPLATE_SIZE: Final[int] = 40,
     TEMPLATE_ITEM_SIZE: Final[int] = 16,
     SCANNER_SIZE: Final[int] = 264,
     SCANNER_PATTERN: Final[int] = 16,
     SCANNER_STATE: Final[int] = 24,
     SCANNER_EXECUTING: Final[int] = 256,
     # offsetof(SRE_STATE, buffer)
     STATE_BUFFER: Final[int] = 40;

glob PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     # SRE_MAXGROUPS on a 64-bit build: (SRE_CODE)INT32_MAX / 2.
     SRE_MAXGROUPS: Final[int] = 1073741823,
     SRE_CODE_SIZE: Final[int] = 4,
     COPYRIGHT: str = " SRE 2.2.2 Copyright (c) 1997-2002 by Secret Labs AB ";

# The module state slots (_sremodulestate).
glob STATE_PATTERN_TYPE: Final[int] = 0,
     STATE_MATCH_TYPE: Final[int] = 1,
     STATE_SCANNER_TYPE: Final[int] = 2,
     STATE_TEMPLATE_TYPE: Final[int] = 3,
     STATE_COMPILE_TEMPLATE: Final[int] = 4,
     STATE_COUNT: Final[int] = 5;

# The classes whose methods take defining_class; the binding points them at
# the created types' specs.
glob SRE_Pattern_token = ClassToken(),
     SRE_Scanner_token = ClassToken();

# ------------------------------------------------------------------ access

def pattern_record(op: ptr[PyObject]) -> ptr[PatternObject] {
    return ptr[PatternObject](op);
}

def match_record(op: ptr[PyObject]) -> ptr[MatchObject] {
    return ptr[MatchObject](op);
}

def template_record(op: ptr[PyObject]) -> ptr[TemplateObject] {
    return ptr[TemplateObject](op);
}

def scanner_record(op: ptr[PyObject]) -> ptr[ScannerObject] {
    return ptr[ScannerObject](op);
}

# PatternObject_GetCode
def pattern_code(op: ptr[PyObject]) -> ptr[u32] {
    return ptr[u32](ptr[u8](op) + PATTERN_CODE);
}

# The match's mark array.
def match_marks(op: ptr[PyObject]) -> ptr[i64] {
    return ptr[i64](ptr[u8](op) + MATCH_MARK);
}

# The scanner's `executing` flag.
def scanner_executing(op: ptr[PyObject]) -> ptr[i32] {
    return ptr[i32](ptr[u8](op) + SCANNER_EXECUTING);
}

# The template's items.
def template_items(op: ptr[PyObject]) -> ptr[TemplateItem] {
    return ptr[TemplateItem](ptr[u8](op) + TEMPLATE_SIZE);
}

# The scanner's embedded matching state.
def scanner_state(op: ptr[PyObject]) -> ptr[SreState] {
    return ptr[SreState](ptr[u8](op) + SCANNER_STATE);
}

def type_object(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](object_type(op));
}

def tp_name(op: ptr[PyObject]) -> ptr[u8] {
    return object_type(op).view(1)[0].tp_name;
}

# get_sre_module_state_by_class(cls)->slot (borrowed).
def module_slot(cls: ptr[PyObject], slot: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(PyType_GetModule(cls), i64(slot));
}

# Py_TYPE(op)->tp_free(op); Py_DECREF(Py_TYPE(op)) for these GC heap types.
def free_object(op: ptr[PyObject]) {
    tp = type_object(op);
    PyObject_GC_Del(op);
    jacpy_release(tp);
}

# ------------------------------------------------------------------ helpers

# _sre.getcodesize() -> int
def _sre_getcodesize_impl(module: ptr[PyObject]) -> i32 {
    return i32(SRE_CODE_SIZE);
}

# The code point C reads as `(unsigned int)character`.
def:priv as_code(character: i32) -> u32 {
    return u32(i64(character) & 0xFFFFFFFF);
}

# The int C returns for an unsigned int result.
def:priv as_int(value: u32) -> i32 {
    wide = i64(value);
    return i32(wide - 4294967296 if wide > 2147483647 else wide);
}

# _sre.ascii_iscased(character, /) -> bool
def _sre_ascii_iscased_impl(module: ptr[PyObject], character: i32) -> i32 {
    ch = as_code(character);
    return i32(ch < 128 and ascii_is_alpha(ch));
}

# _sre.unicode_iscased(character, /) -> bool
def _sre_unicode_iscased_impl(module: ptr[PyObject], character: i32) -> i32 {
    ch = as_code(character);
    return i32(ch != sre_lower_unicode(ch) or ch != sre_upper_unicode(ch));
}

# _sre.ascii_tolower(character, /) -> int
def _sre_ascii_tolower_impl(module: ptr[PyObject], character: i32) -> i32 {
    return as_int(sre_lower_ascii(as_code(character)));
}

# _sre.unicode_tolower(character, /) -> int
def _sre_unicode_tolower_impl(module: ptr[PyObject], character: i32) -> i32 {
    return as_int(sre_lower_unicode(as_code(character)));
}

def state_reset(state: ptr[SreState]) {
    # state->mark will be set to 0 in SRE_OP_MARK dynamically.
    st = state.view(1);
    st[0].lastmark = -1;
    st[0].lastindex = -1;
    st[0].repeat = ptr[SreRepeat]();
    data_stack_dealloc(state);
}

# getstring(): the data of `string`, or NULL with the exception set. A str's
# length and character size are its own; any other object is exported
# through the buffer protocol into `view` (whose `buf` is then non-NULL),
# which the caller releases, and its characters are bytes.
def getstring(string: ptr[PyObject], view: ptr[Py_buffer]) -> ptr {
    # Unicode objects do not support the buffer API. So, get the data
    # directly instead.
    if jacpy_is_unicode(string) != 0 {
        return jacpy_unicode_data(string);
    }
    # get pointer to byte string buffer
    if PyObject_GetBuffer(string, view, PyBUF_SIMPLE) != 0 {
        PyErr_Format(
            PyExc_TypeError,
            "expected string or bytes-like object, got '%.200s'",
            tp_name(string)
        );
        return ptr();
    }
    if not view.view(1)[0].buf {
        PyErr_SetString(PyExc_ValueError, "Buffer is NULL");
        PyBuffer_Release(view);
        view.view(1)[0].buf = ptr();
        return ptr();
    }
    return view.view(1)[0].buf;
}

# The length in characters of `string` after getstring().
def string_length(string: ptr[PyObject], view: ptr[Py_buffer]) -> i64 {
    if jacpy_is_unicode(string) != 0 {
        return jacpy_unicode_size(string);
    }
    return view.view(1)[0].length;
}

# The character size of `string` after getstring().
def string_charsize(string: ptr[PyObject]) -> i32 {
    if jacpy_is_unicode(string) != 0 {
        return i32(jacpy_unicode_kind(string));
    }
    return i32(1);
}

# A zeroed Py_buffer for getstring(); NULL with MemoryError.
def new_view -> ptr[Py_buffer] {
    view = ptr[Py_buffer](PyMem_Calloc(1, 80));
    if not view {
        PyErr_NoMemory();
    }
    return view;
}

# Release the buffer getstring() exported into `view`, if any, and free it.
def free_view(view: ptr[Py_buffer]) {
    if view.view(1)[0].buf {
        PyBuffer_Release(view);
    }
    PyMem_Free(view);
}

# A matching state for `pattern`, with its marks in the same allocation;
# NULL with MemoryError.
def state_new(pattern: ptr[PyObject]) -> ptr[SreState] {
    groups = pattern_record(pattern).view(1)[0].groups;
    state = ptr[SreState](PyMem_Malloc(u64(SRE_STATE_SIZE + groups * 16)));
    if not state {
        PyErr_NoMemory();
    }
    return state;
}

# state_init(): prepare `state` to match `pattern` against string[start:end].
# The marks live after the state when `inline_marks`, otherwise in their own
# allocation. `string`, or NULL with the exception set.
def state_init(
    state: ptr[SreState],
    pattern: ptr[PyObject],
    string: ptr[PyObject],
    start: i64,
    end: i64,
    inline_marks: bool
) -> ptr[PyObject] {
    memset(state, 0, u64(SRE_STATE_SIZE));
    st = state.view(1);
    p = pattern_record(pattern).view(1);
    if inline_marks {
        st[0].mark = ptr[ptr](ptr[u8](state) + SRE_STATE_SIZE);
    } else {
        marks = PyMem_Malloc(u64(p[0].groups * 16));
        if not marks {
            PyErr_NoMemory();
            return NULL;
        }
        st[0].mark = ptr[ptr](marks);
    }
    st[0].lastmark = -1;
    st[0].lastindex = -1;
    view = ptr[Py_buffer](ptr[u8](state) + STATE_BUFFER);
    data = getstring(string, view);
    if not data {
        state_init_failed(state, inline_marks);
        return NULL;
    }
    length = string_length(string, view);
    isbytes = not view.view(1)[0].buf.is_null();
    if isbytes and p[0].isbytes == 0 {
        PyErr_SetString(
            PyExc_TypeError, "cannot use a string pattern on a bytes-like object"
        );
        state_init_failed(state, inline_marks);
        return NULL;
    }
    if not isbytes and p[0].isbytes > 0 {
        PyErr_SetString(
            PyExc_TypeError, "cannot use a bytes pattern on a string-like object"
        );
        state_init_failed(state, inline_marks);
        return NULL;
    }
    # adjust boundaries
    if start < 0 {
        start = 0;
    } elif start > length {
        start = length;
    }
    if end < 0 {
        end = 0;
    } elif end > length {
        end = length;
    }
    charsize = string_charsize(string);
    st[0].isbytes = i32(isbytes);
    st[0].charsize = charsize;
    st[0].match_all = 0;
    st[0].must_advance = 0;
    st[0].debug = i32((p[0].flags & SRE_FLAG_DEBUG) != 0);
    st[0].beginning = data;
    st[0].start = ptr(ptr[u8](data) + start * i64(charsize));
    st[0].end = ptr(ptr[u8](data) + end * i64(charsize));
    st[0].string = Py_NewRef(string);
    st[0].pos = start;
    st[0].endpos = end;
    return string;
}

def:priv state_init_failed(state: ptr[SreState], inline_marks: bool) {
    st = state.view(1);
    if not inline_marks {
        PyMem_Free(st[0].mark);
    }
    st[0].mark = ptr[ptr]();
    view = ptr[Py_buffer](ptr[u8](state) + STATE_BUFFER);
    if view.view(1)[0].buf {
        PyBuffer_Release(view);
    }
}

# state_fini(): release what state_init() and the matcher acquired.
def state_fini(state: ptr[SreState], inline_marks: bool) {
    st = state.view(1);
    view = ptr[Py_buffer](ptr[u8](state) + STATE_BUFFER);
    if view.view(1)[0].buf {
        PyBuffer_Release(view);
    }
    jacpy_release(st[0].string);
    data_stack_dealloc(state);
    if not inline_marks {
        PyMem_Free(st[0].mark);
    }
    st[0].mark = ptr[ptr]();
    # SRE_REPEAT pool
    repeat_pool_clear(state);
}

# STATE_OFFSET: the offset of `member` from the start of the string, in
# characters.
def state_offset(state: ptr[SreState], member: ptr) -> i64 {
    st = state.view(1);
    return (ptr[u8](member) - ptr[u8](st[0].beginning)) // i64(st[0].charsize);
}

# getslice(): string[start:end], the object itself for a whole bytes.
def getslice(
    isbytes: i32, data: ptr, string: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject] {
    if isbytes != 0 {
        if object_type(string) == ptr[PyTypeObject](addressof(PyBytes_Type))
            and start == 0
            and end == object_size(string) {
            return Py_NewRef(string);
        }
        return jacpy_bytes_from_memory(ptr(ptr[u8](data) + start), end - start);
    }
    return PyUnicode_Substring(string, start, end);
}

# state_getslice(): group `index` of the state's match; an empty slice
# instead of None for an unmatched group when `empty`.
def state_getslice(
    state: ptr[SreState], index: i64, string: ptr[PyObject], empty: bool
) -> ptr[PyObject] {
    st = state.view(1);
    index = (index - 1) * 2;
    i: i64 = 0;
    j: i64 = 0;
    if string == Py_None
        or index >= i64(st[0].lastmark)
        or not (st[0].mark + index).view(1)[0]
        or not (st[0].mark + (index + 1)).view(1)[0] {
        if not empty {
            return Py_NewRef(Py_None);
        }
    } else {
        i = state_offset(state, (st[0].mark + index).view(1)[0]);
        j = state_offset(state, (st[0].mark + (index + 1)).view(1)[0]);
        # check wrong span
        if i > j {
            PyErr_SetString(
                PyExc_SystemError,
                "The span of capturing group is wrong, please report a bug for the re module."
            );
            return NULL;
        }
    }
    return getslice(st[0].isbytes, st[0].beginning, string, i, j);
}

def pattern_error(status: i64) {
    if status == SRE_ERROR_RECURSION_LIMIT {
        # This error code seems to be unused.
        PyErr_SetString(PyExc_RecursionError, "maximum recursion limit exceeded");
    } elif status == SRE_ERROR_MEMORY {
        PyErr_NoMemory();
    } elif status == SRE_ERROR_INTERRUPTED {
        # An exception has already been raised, so let it fly
        return;
    } else {
        # other error codes indicate compiler/engine bugs
        PyErr_SetString(
            PyExc_RuntimeError, "internal error in regular expression engine"
        );
    }
}

# sre_match() and sre_search(): the matcher for the state's character size.
def sre_match(state: ptr[SreState], pattern: ptr[u32]) -> i64 {
    charsize = state.view(1)[0].charsize;
    if charsize == 1 {
        return ucs1_match(state, pattern, i32(1));
    }
    if charsize == 2 {
        return ucs2_match(state, pattern, i32(1));
    }
    return ucs4_match(state, pattern, i32(1));
}

def sre_search(state: ptr[SreState], pattern: ptr[u32]) -> i64 {
    charsize = state.view(1)[0].charsize;
    if charsize == 1 {
        return ucs1_search(state, pattern);
    }
    if charsize == 2 {
        return ucs2_search(state, pattern);
    }
    return ucs4_search(state, pattern);
}

# ------------------------------------------------------------------ Pattern

def pattern_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    p = pattern_record(op).view(1);
    result = visit_one(type_object(op), visitor, context);
    if result == 0 {
        result = visit_one(p[0].groupindex, visitor, context);
    }
    if result == 0 {
        result = visit_one(p[0].indexgroup, visitor, context);
    }
    if result == 0 {
        result = visit_one(p[0].pattern, visitor, context);
    }
    return result;
}

def pattern_clear(op: ptr[PyObject]) -> i32 {
    p = pattern_record(op).view(1);
    groupindex = p[0].groupindex;
    p[0].groupindex = NULL;
    jacpy_release(groupindex);
    indexgroup = p[0].indexgroup;
    p[0].indexgroup = NULL;
    jacpy_release(indexgroup);
    source = p[0].pattern;
    p[0].pattern = NULL;
    jacpy_release(source);
    return i32(0);
}

def pattern_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    if pattern_record(op).view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    pattern_clear(op);
    free_object(op);
}

# Run `matcher` (match, fullmatch or search) over string[pos:endpos] and
# build its Match object.
def:priv pattern_run(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64,
    kind: int
) -> ptr[PyObject] {
    state = state_new(self);
    if not state {
        return NULL;
    }
    if not state_init(state, self, string, pos, endpos, True) {
        PyMem_Free(state);
        return NULL;
    }
    st = state.view(1);
    st[0].position = st[0].start;
    if kind == 2 {
        status = sre_search(state, pattern_code(self));
    } else {
        st[0].match_all = i32(kind == 1);
        status = sre_match(state, pattern_code(self));
    }
    if PyErr_Occurred() {
        state_fini(state, True);
        PyMem_Free(state);
        return NULL;
    }
    match_object = pattern_new_match(
        module_slot(cls, STATE_MATCH_TYPE), self, state, status
    );
    state_fini(state, True);
    PyMem_Free(state);
    return match_object;
}

# _sre.SRE_Pattern.match(cls, /, string, pos=0, endpos=sys.maxsize)
def _sre_SRE_Pattern_match_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    return pattern_run(self, cls, string, pos, endpos, 0);
}

# _sre.SRE_Pattern.fullmatch(cls, /, string, pos=0, endpos=sys.maxsize)
def _sre_SRE_Pattern_fullmatch_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    return pattern_run(self, cls, string, pos, endpos, 1);
}

# _sre.SRE_Pattern.search(cls, /, string, pos=0, endpos=sys.maxsize)
def _sre_SRE_Pattern_search_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    return pattern_run(self, cls, string, pos, endpos, 2);
}

# _sre.SRE_Pattern.findall(string, pos=0, endpos=sys.maxsize)
def _sre_SRE_Pattern_findall_impl(
    self: ptr[PyObject], string: ptr[PyObject], pos: i64, endpos: i64
) -> ptr[PyObject] {
    state = state_new(self);
    if not state {
        return NULL;
    }
    if not state_init(state, self, string, pos, endpos, True) {
        PyMem_Free(state);
        return NULL;
    }
    result = PyList_New(0);
    if result and not findall_into(self, state, string, result) {
        jacpy_release(result);
        result = NULL;
    }
    state_fini(state, True);
    PyMem_Free(state);
    return result;
}

def:priv findall_into(
    self: ptr[PyObject],
    state: ptr[SreState],
    string: ptr[PyObject],
    list: ptr[PyObject]
) -> bool {
    st = state.view(1);
    groups = pattern_record(self).view(1)[0].groups;
    while st[0].start <= st[0].end {
        state_reset(state);
        st[0].position = st[0].start;
        status = sre_search(state, pattern_code(self));
        if PyErr_Occurred() {
            return False;
        }
        if status <= 0 {
            if status == 0 {
                break;
            }
            pattern_error(status);
            return False;
        }
        # don't bother to build a match object
        item = NULL;
        if groups == 0 {
            b = state_offset(state, st[0].start);
            e = state_offset(state, st[0].position);
            item = getslice(st[0].isbytes, st[0].beginning, string, b, e);
            if not item {
                return False;
            }
        } elif groups == 1 {
            item = state_getslice(state, 1, string, True);
            if not item {
                return False;
            }
        } else {
            item = PyTuple_New(groups);
            if not item {
                return False;
            }
            for i in range(groups) {
                o = state_getslice(state, i + 1, string, True);
                if not o {
                    jacpy_release(item);
                    return False;
                }
                tuple_set_item(item, i, o);
            }
        }
        status = i64(PyList_Append(list, item));
        jacpy_release(item);
        if status < 0 {
            return False;
        }
        st[0].must_advance = i32(st[0].position == st[0].start);
        st[0].start = st[0].position;
    }
    return True;
}

# _sre.SRE_Pattern.finditer(cls, /, string, pos=0, endpos=sys.maxsize)
def _sre_SRE_Pattern_finditer_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    scanner = pattern_scanner(
        module_slot(cls, STATE_SCANNER_TYPE), self, string, pos, endpos
    );
    if not scanner {
        return NULL;
    }
    search = PyObject_GetAttrString(scanner, "search");
    jacpy_release(scanner);
    if not search {
        return NULL;
    }
    iterator = PyCallIter_New(search, Py_None);
    jacpy_release(search);
    return iterator;
}

# _sre.SRE_Pattern.scanner(cls, /, string, pos=0, endpos=sys.maxsize)
def _sre_SRE_Pattern_scanner_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    return pattern_scanner(
        module_slot(cls, STATE_SCANNER_TYPE), self, string, pos, endpos
    );
}

# _sre.SRE_Pattern.split(string, maxsplit=0)
def _sre_SRE_Pattern_split_impl(
    self: ptr[PyObject], string: ptr[PyObject], maxsplit: i64
) -> ptr[PyObject] {
    state = state_new(self);
    if not state {
        return NULL;
    }
    if not state_init(state, self, string, 0, PY_SSIZE_T_MAX, True) {
        PyMem_Free(state);
        return NULL;
    }
    result = PyList_New(0);
    if result and not split_into(self, state, string, maxsplit, result) {
        jacpy_release(result);
        result = NULL;
    }
    state_fini(state, True);
    PyMem_Free(state);
    return result;
}

def:priv split_into(
    self: ptr[PyObject],
    state: ptr[SreState],
    string: ptr[PyObject],
    maxsplit: i64,
    list: ptr[PyObject]
) -> bool {
    st = state.view(1);
    groups = pattern_record(self).view(1)[0].groups;
    n: i64 = 0;
    last = st[0].start;
    while maxsplit == 0 or n < maxsplit {
        state_reset(state);
        st[0].position = st[0].start;
        status = sre_search(state, pattern_code(self));
        if PyErr_Occurred() {
            return False;
        }
        if status <= 0 {
            if status == 0 {
                break;
            }
            pattern_error(status);
            return False;
        }
        # get segment before this match
        item = getslice(
            st[0].isbytes,
            st[0].beginning,
            string,
            state_offset(state, last),
            state_offset(state, st[0].start)
        );
        if not append_owned(list, item) {
            return False;
        }
        # add groups (if any)
        for i in range(groups) {
            item = state_getslice(state, i + 1, string, False);
            if not append_owned(list, item) {
                return False;
            }
        }
        n = n + 1;
        st[0].must_advance = i32(st[0].position == st[0].start);
        st[0].start = st[0].position;
        last = st[0].start;
    }
    # get segment following last match (even if empty)
    item = getslice(
        st[0].isbytes, st[0].beginning, string, state_offset(state, last), st[0].endpos
    );
    return append_owned(list, item);
}

# PyList_Append of a new reference, which it releases; False on failure
# (also when `item` is NULL).
def:priv append_owned(list: ptr[PyObject], item: ptr[PyObject]) -> bool {
    if not item {
        return False;
    }
    status = PyList_Append(list, item);
    jacpy_release(item);
    return status >= 0;
}

# compile_template(): delegate compiling the replacement `template` to
# re._compile_template, imported once.
def compile_template(
    module: ptr[PyObject], pattern: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject] {
    func = jacpy_binding_state_get(module, i64(STATE_COMPILE_TEMPLATE));
    if not func {
        imported = PyImport_ImportModuleAttrString("re", "_compile_template");
        if not imported {
            return NULL;
        }
        # the state keeps it
        set_module_slot(module, STATE_COMPILE_TEMPLATE, imported);
        jacpy_release(imported);
        func = imported;
    }
    result = call_template_compiler(func, pattern, template);
    if not result and PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
        # If the replacement string is unhashable (e.g. bytearray), convert
        # it to the basic type (str or bytes) and repeat.
        if jacpy_is_unicode(template) != 0 and not is_exact_unicode(template) {
            PyErr_Clear();
            template = _PyUnicode_Copy(template);
        } elif PyObject_CheckBuffer(template) != 0
            and object_type(template) != ptr[PyTypeObject](addressof(PyBytes_Type)) {
            PyErr_Clear();
            template = PyBytes_FromObject(template);
        } else {
            return NULL;
        }
        if not template {
            return NULL;
        }
        result = call_template_compiler(func, pattern, template);
        jacpy_release(template);
    }
    template_type = jacpy_binding_state_get(module, i64(STATE_TEMPLATE_TYPE));
    if result and type_object(result) != template_type {
        PyErr_Format(
            PyExc_RuntimeError,
            "the result of compiling a replacement string is %.200s",
            tp_name(result)
        );
        jacpy_release(result);
        return NULL;
    }
    return result;
}

import from c {
    obj TemplateArguments {
        has pattern: ptr[PyObject],
            template: ptr[PyObject];
    }
}

def:priv call_template_compiler(
    func: ptr[PyObject], pattern: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject] {
    arguments = ptr[TemplateArguments](PyMem_Malloc(16));
    if not arguments {
        PyErr_NoMemory();
        return NULL;
    }
    arguments.view(1)[0].pattern = pattern;
    arguments.view(1)[0].template = template;
    result = PyObject_Vectorcall(func, ptr[ptr[PyObject]](arguments), 2, NULL);
    PyMem_Free(arguments);
    return result;
}

def:priv is_exact_unicode(value: ptr[PyObject]) -> bool {
    return object_type(value) == object_type(PyUnicode_New(0, 0));
}

def:priv set_module_slot(module: ptr[PyObject], slot: int, value: ptr[PyObject]) {
    jacpy_binding_state_set(module, i64(slot), value);
}

# pattern_subx(): sub() and subn() over `ptemplate` (a replacement string,
# template or callable).
def pattern_subx(
    module: ptr[PyObject],
    self: ptr[PyObject],
    ptemplate: ptr[PyObject],
    string: ptr[PyObject],
    count: i64,
    subn: bool
) -> ptr[PyObject] {
    # 0: LITERAL, 1: TEMPLATE, 2: CALLABLE
    filter_type = 0;
    filter = NULL;
    if PyCallable_Check(ptemplate) != 0 {
        # sub/subn takes either a function or a template
        filter = Py_NewRef(ptemplate);
        filter_type = 2;
    } else {
        # if not callable, check if it's a literal string
        literal = False;
        view = new_view();
        if not view {
            return NULL;
        }
        data = getstring(ptemplate, view);
        if data {
            n = string_length(ptemplate, view);
            if string_charsize(ptemplate) == 1 {
                literal = memchr(data, 92, u64(n)).is_null();
            } else {
                literal = PyUnicode_FindChar(ptemplate, u32(92), 0, n, 1) == -1;
            }
        } else {
            PyErr_Clear();
        }
        free_view(view);
        if literal {
            filter = Py_NewRef(ptemplate);
        } else {
            # not a literal; hand it over to the template compiler
            filter = compile_template(module, self, ptemplate);
            if not filter {
                return NULL;
            }
            if object_size(filter) == 0 {
                literal_value = Py_NewRef(template_record(filter).view(1)[0].literal);
                jacpy_release(filter);
                filter = literal_value;
            } else {
                filter_type = 1;
            }
        }
    }
    state = state_new(self);
    if not state {
        jacpy_release(filter);
        return NULL;
    }
    if not state_init(state, self, string, 0, PY_SSIZE_T_MAX, True) {
        PyMem_Free(state);
        jacpy_release(filter);
        return NULL;
    }
    result = subx_run(module, self, state, filter, filter_type, string, count, subn);
    state_fini(state, True);
    PyMem_Free(state);
    jacpy_release(filter);
    return result;
}

def:priv subx_run(
    module: ptr[PyObject],
    self: ptr[PyObject],
    state: ptr[SreState],
    filter: ptr[PyObject],
    filter_type: int,
    string: ptr[PyObject],
    count: i64,
    subn: bool
) -> ptr[PyObject] {
    st = state.view(1);
    list = PyList_New(0);
    if not list {
        return NULL;
    }
    match_type = jacpy_binding_state_get(module, i64(STATE_MATCH_TYPE));
    n: i64 = 0;
    i: i64 = 0;
    while count == 0 or n < count {
        state_reset(state);
        st[0].position = st[0].start;
        status = sre_search(state, pattern_code(self));
        if PyErr_Occurred() {
            jacpy_release(list);
            return NULL;
        }
        if status <= 0 {
            if status == 0 {
                break;
            }
            pattern_error(status);
            jacpy_release(list);
            return NULL;
        }
        b = state_offset(state, st[0].start);
        e = state_offset(state, st[0].position);
        if i < b {
            # get segment before this match
            if not append_owned(
                list, getslice(st[0].isbytes, st[0].beginning, string, i, b)
            ) {
                jacpy_release(list);
                return NULL;
            }
        }
        item = NULL;
        if filter_type != 0 {
            # pass match object through filter
            match_object = pattern_new_match(match_type, self, state, 1);
            if not match_object {
                jacpy_release(list);
                return NULL;
            }
            if filter_type == 1 {
                item = expand_template(filter, match_object);
            } else {
                item = call_one(filter, match_object);
            }
            jacpy_release(match_object);
            if not item {
                jacpy_release(list);
                return NULL;
            }
        } else {
            # filter is literal string
            item = Py_NewRef(filter);
        }
        # add to list
        if item != Py_None {
            if not append_owned(list, item) {
                jacpy_release(list);
                return NULL;
            }
        } else {
            jacpy_release(item);
        }
        i = e;
        n = n + 1;
        st[0].must_advance = i32(st[0].position == st[0].start);
        st[0].start = st[0].position;
    }
    # get segment following last match
    if i < st[0].endpos {
        if not append_owned(
            list, getslice(st[0].isbytes, st[0].beginning, string, i, st[0].endpos)
        ) {
            jacpy_release(list);
            return NULL;
        }
    }
    # convert list to single string (also removes list)
    joiner = getslice(st[0].isbytes, st[0].beginning, string, 0, 0);
    if not joiner {
        jacpy_release(list);
        return NULL;
    }
    result = NULL;
    if PyList_Size(list) == 0 {
        jacpy_release(list);
        result = joiner;
    } else {
        if st[0].isbytes != 0 {
            result = PyBytes_Join(joiner, list);
        } else {
            result = PyUnicode_Join(joiner, list);
        }
        jacpy_release(joiner);
        jacpy_release(list);
        if not result {
            return NULL;
        }
    }
    if subn {
        pair = PyTuple_New(2);
        if not pair {
            jacpy_release(result);
            return NULL;
        }
        tuple_set_item(pair, 0, result);
        count_object = PyLong_FromSsize_t(n);
        if not count_object {
            jacpy_release(pair);
            return NULL;
        }
        tuple_set_item(pair, 1, count_object);
        return pair;
    }
    return result;
}

import from c {
    obj OneArgument {
        has value: ptr[PyObject];
    }
}

# PyObject_CallOneArg(callable, value)
def call_one(callable: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    arguments = ptr[OneArgument](PyMem_Malloc(8));
    if not arguments {
        PyErr_NoMemory();
        return NULL;
    }
    arguments.view(1)[0].value = value;
    result = PyObject_Vectorcall(callable, ptr[ptr[PyObject]](arguments), 1, NULL);
    PyMem_Free(arguments);
    return result;
}

# _sre.SRE_Pattern.sub(cls, /, repl, string, count=0)
def _sre_SRE_Pattern_sub_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    repl: ptr[PyObject],
    string: ptr[PyObject],
    count: i64
) -> ptr[PyObject] {
    return pattern_subx(PyType_GetModule(cls), self, repl, string, count, False);
}

# _sre.SRE_Pattern.subn(cls, /, repl, string, count=0)
def _sre_SRE_Pattern_subn_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    repl: ptr[PyObject],
    string: ptr[PyObject],
    count: i64
) -> ptr[PyObject] {
    return pattern_subx(PyType_GetModule(cls), self, repl, string, count, True);
}

def _sre_SRE_Pattern___copy___impl(self: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(self);
}

def _sre_SRE_Pattern___deepcopy___impl(
    self: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_NewRef(self);
}

glob:priv FLAG_NAMES: list[tuple[str, int]] = [
         ("re.IGNORECASE", SRE_FLAG_IGNORECASE),
         ("re.LOCALE", SRE_FLAG_LOCALE),
         ("re.MULTILINE", SRE_FLAG_MULTILINE),
         ("re.DOTALL", SRE_FLAG_DOTALL),
         ("re.UNICODE", SRE_FLAG_UNICODE),
         ("re.VERBOSE", SRE_FLAG_VERBOSE),
         ("re.DEBUG", SRE_FLAG_DEBUG),
         ("re.ASCII", SRE_FLAG_ASCII)
     ];

def pattern_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    p = pattern_record(self).view(1);
    flags = int(p[0].flags);
    # Omit re.UNICODE for valid string patterns.
    if p[0].isbytes == 0
        and (flags & (SRE_FLAG_LOCALE | SRE_FLAG_UNICODE | SRE_FLAG_ASCII))
            == SRE_FLAG_UNICODE {
        flags &= ~SRE_FLAG_UNICODE;
    }
    flag_items = PyList_New(0);
    if not flag_items {
        return NULL;
    }
    result = NULL;
    failed = False;
    for (name, value) in FLAG_NAMES {
        if (flags & value) != 0 {
            if not append_owned(flag_items, PyUnicode_FromString(name)) {
                failed = True;
                break;
            }
            flags &= ~value;
        }
    }
    if not failed and flags != 0 {
        failed = not append_owned(flag_items, PyUnicode_FromFormat("0x%x", i32(flags)));
    }
    if not failed {
        if PyList_Size(flag_items) > 0 {
            sep = PyUnicode_FromString("|");
            if sep {
                flags_result = PyUnicode_Join(sep, flag_items);
                jacpy_release(sep);
                if flags_result {
                    result = PyUnicode_FromFormat(
                        "re.compile(%.200R, %S)", p[0].pattern, flags_result
                    );
                    jacpy_release(flags_result);
                }
            }
        } else {
            result = PyUnicode_FromFormat("re.compile(%.200R)", p[0].pattern);
        }
    }
    jacpy_release(flag_items);
    return result;
}

# PatternObject's 'groupindex' getter.
def pattern_groupindex(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    groupindex = pattern_record(op).view(1)[0].groupindex;
    if not groupindex {
        return PyDict_New();
    }
    return PyDictProxy_New(groupindex);
}

def pattern_hash(op: ptr[PyObject]) -> i64 {
    p = pattern_record(op).view(1);
    hash = PyObject_Hash(p[0].pattern);
    if hash == -1 {
        return -1;
    }
    hash2 = Py_HashBuffer(ptr(pattern_code(op)), p[0].codesize * SRE_CODE_SIZE);
    hash = hash ^ hash2;
    hash = hash ^ i64(p[0].flags);
    hash = hash ^ i64(p[0].isbytes);
    hash = hash ^ p[0].codesize;
    if hash == -1 {
        hash = -2;
    }
    return hash;
}

def pattern_richcompare(
    lefto: ptr[PyObject], righto: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if op != Py_EQ and op != Py_NE {
        return Py_NewRef(Py_NotImplemented);
    }
    pattern_type = module_slot(type_object(lefto), STATE_PATTERN_TYPE);
    if type_object(righto) != pattern_type {
        return Py_NewRef(Py_NotImplemented);
    }
    if lefto == righto {
        # a pattern is equal to itself
        return PyBool_FromLong(i64(op == Py_EQ));
    }
    left = pattern_record(lefto).view(1);
    right = pattern_record(righto).view(1);
    cmp = left[0].flags == right[0].flags
        and left[0].isbytes == right[0].isbytes
        and left[0].codesize == right[0].codesize;
    if cmp {
        # Compare the code and the pattern because the same pattern can
        # produce different codes depending on the locale used to compile
        # the pattern when the re.LOCALE flag is used. Don't compare groups,
        # indexgroup nor groupindex: they are derivated from the pattern.
        cmp = memcmp(
            pattern_code(lefto),
            pattern_code(righto),
            u64(left[0].codesize * SRE_CODE_SIZE)
        )
            == 0;
    }
    if cmp {
        status = PyObject_RichCompareBool(left[0].pattern, right[0].pattern, Py_EQ);
        if status < 0 {
            return NULL;
        }
        cmp = status != 0;
    }
    if op == Py_NE {
        cmp = not cmp;
    }
    return PyBool_FromLong(i64(cmp));
}

# _sre.compile(pattern, flags, code, groups, groupindex, indexgroup)
def _sre_compile_impl(
    module: ptr[PyObject],
    pattern: ptr[PyObject],
    flags: i32,
    code: ptr[PyObject],
    groups: i64,
    groupindex: ptr[PyObject],
    indexgroup: ptr[PyObject]
) -> ptr[PyObject] {
    # "compile" pattern descriptor to pattern object
    pattern_type = jacpy_binding_state_get(module, i64(STATE_PATTERN_TYPE));
    n = PyList_Size(code);
    self = _PyObject_GC_NewVar(pattern_type, n);
    if not self {
        return NULL;
    }
    p = pattern_record(self).view(1);
    p[0].weakreflist = NULL;
    p[0].pattern = NULL;
    p[0].groupindex = NULL;
    p[0].indexgroup = NULL;
    p[0].codesize = n;
    codes = pattern_code(self);
    for i in range(n) {
        o = PyList_GetItem(code, i);
        value = PyLong_AsUnsignedLong(o);
        if value == ~u64(0) and PyErr_Occurred() {
            break;
        }
        if value > u64(0xFFFFFFFF) {
            (codes + i).view(1)[0] = u32(value & u64(0xFFFFFFFF));
            PyErr_SetString(
                PyExc_OverflowError, "regular expression code size limit exceeded"
            );
            break;
        }
        (codes + i).view(1)[0] = u32(value);
    }
    PyObject_GC_Track(self);
    if PyErr_Occurred() {
        jacpy_release(self);
        return NULL;
    }
    if pattern == Py_None {
        p[0].isbytes = -1;
    } else {
        view = new_view();
        if not view {
            jacpy_release(self);
            return NULL;
        }
        if not getstring(pattern, view) {
            PyMem_Free(view);
            jacpy_release(self);
            return NULL;
        }
        p[0].isbytes = i32(not view.view(1)[0].buf.is_null());
        free_view(view);
    }
    p[0].pattern = Py_NewRef(pattern);
    p[0].flags = flags;
    p[0].groups = groups;
    if PyDict_Size(groupindex) > 0 {
        p[0].groupindex = Py_NewRef(groupindex);
        if PyTuple_Size(indexgroup) > 0 {
            p[0].indexgroup = Py_NewRef(indexgroup);
        }
    }
    if not validate(self) {
        jacpy_release(self);
        return NULL;
    }
    return self;
}

# _sre.template(pattern, template, /)
def _sre_template_impl(
    module: ptr[PyObject], pattern: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject] {
    # template is a list containing interleaved literal strings (str or
    # bytes) and group indices (int), as returned by
    # _parser.parse_template: [literal1, group1, literal2, ..., literalN].
    template_type = jacpy_binding_state_get(module, i64(STATE_TEMPLATE_TYPE));
    n = PyList_Size(template);
    if (n & 1) == 0 or n < 1 {
        PyErr_SetString(PyExc_TypeError, "invalid template");
        return NULL;
    }
    n = n // 2;
    self = _PyObject_GC_NewVar(template_type, n);
    if not self {
        return NULL;
    }
    t = template_record(self).view(1);
    t[0].chunks = 1 + 2 * n;
    t[0].literal = Py_NewRef(PyList_GetItem(template, 0));
    items = template_items(self);
    for i in range(n) {
        index = PyLong_AsSsize_t(PyList_GetItem(template, 2 * i + 1));
        if index == -1 and PyErr_Occurred() {
            template_record(self).view(1)[0].ob_size = i;
            jacpy_release(self);
            return NULL;
        }
        if index < 0 {
            template_record(self).view(1)[0].ob_size = i;
            PyErr_SetString(PyExc_TypeError, "invalid template");
            jacpy_release(self);
            return NULL;
        }
        item = (items + i).view(1);
        item[0].index = index;
        literal = PyList_GetItem(template, 2 * i + 2);
        # Skip empty literals.
        if (jacpy_is_unicode(literal) != 0 and jacpy_unicode_size(literal) == 0)
            or (jacpy_is_bytes(literal) != 0 and object_size(literal) == 0) {
            literal = NULL;
            t[0].chunks -= 1;
        }
        item[0].literal = Py_XNewRef(literal);
    }
    PyObject_GC_Track(self);
    return self;
}

# ------------------------------------------------------------ validation

# The code validator (_validate): the code that re's compiler generates is
# position-independent, all jumps are relative jumps forward, and jumps don't
# cross each other. These check the code array for conformance with the code
# patterns Lib/re/_compiler.py generates. A failure is -1.

obj:priv CodeCursor {
    has code: ptr[u32],
        end: ptr[u32],
        op: u32 = 0,
        arg: u32 = 0,
        skip_count: u32 = 0;

    # GET_OP
    def get_op -> bool {
        if self.code >= self.end {
            return False;
        }
        self.op = self.code.view(1)[0];
        self.code += 1;
        return True;
    }

    # GET_ARG
    def get_arg -> bool {
        if self.code >= self.end {
            return False;
        }
        self.arg = self.code.view(1)[0];
        self.code += 1;
        return True;
    }

    # GET_SKIP_ADJ(adj)
    def get_skip(adj: int = 0) -> bool {
        if self.code >= self.end {
            return False;
        }
        self.skip_count = self.code.view(1)[0];
        # skip_count - adj as the C's unsigned SRE_CODE arithmetic computes it
        if ((i64(self.skip_count) - adj) & 0xFFFFFFFF) > self.end - self.code {
            return False;
        }
        self.code += 1;
        return True;
    }
}

def:priv validate_charset(code: ptr[u32], end: ptr[u32]) -> int {
    cursor = CodeCursor(code=code, end=end);
    while cursor.code < cursor.end {
        if not cursor.get_op() {
            return -1;
        }
        op = int(cursor.op);
        if op == SRE_OP_NEGATE {
            continue;
        } elif op == SRE_OP_LITERAL {
            if not cursor.get_arg() {
                return -1;
            }
        } elif op == SRE_OP_RANGE or op == SRE_OP_RANGE_UNI_IGNORE {
            if not cursor.get_arg() or not cursor.get_arg() {
                return -1;
            }
        } elif op == SRE_OP_CHARSET {
            # 256-bit bitmap
            if 8 > cursor.end - cursor.code {
                return -1;
            }
            cursor.code += 8;
        } elif op == SRE_OP_BIGCHARSET {
            # Number of blocks
            if not cursor.get_arg() {
                return -1;
            }
            # 256-byte table
            if 64 > cursor.end - cursor.code {
                return -1;
            }
            # Make sure that each byte points to a valid block
            table = ptr[u8](cursor.code);
            for i in range(256) {
                if u32((table + i).view(1)[0]) >= cursor.arg {
                    return -1;
                }
            }
            cursor.code += 64;
            # 256-bit bitmap times arg
            offset = i64(cursor.arg) * 8;
            if offset > cursor.end - cursor.code {
                return -1;
            }
            cursor.code += offset;
        } elif op == SRE_OP_CATEGORY {
            if not cursor.get_arg() {
                return -1;
            }
            if cursor.arg > 17 {
                return -1;
            }
        } else {
            return -1;
        }
    }
    return 0;
}

# Returns 0 on success, -1 on failure, and 1 if the last op is JUMP.
def:priv validate_inner(code: ptr[u32], end: ptr[u32], groups: i64) -> int {
    if code > end {
        return -1;
    }
    cursor = CodeCursor(code=code, end=end);
    while cursor.code < cursor.end {
        if not cursor.get_op() {
            return -1;
        }
        op = int(cursor.op);
        if op == SRE_OP_MARK {
            # We don't check whether marks are properly nested; the
            # sre_match() code is robust even if they don't, and the worst
            # you can get is nonsensical match results.
            if not cursor.get_arg() or i64(cursor.arg) >= 2 * groups {
                return -1;
            }
        } elif op == SRE_OP_LITERAL
            or op == SRE_OP_NOT_LITERAL
            or op == SRE_OP_LITERAL_IGNORE
            or op == SRE_OP_NOT_LITERAL_IGNORE
            or op == SRE_OP_LITERAL_UNI_IGNORE
            or op == SRE_OP_NOT_LITERAL_UNI_IGNORE
            or op == SRE_OP_LITERAL_LOC_IGNORE
            or op == SRE_OP_NOT_LITERAL_LOC_IGNORE {
            # The arg is just a character, nothing to check
            if not cursor.get_arg() {
                return -1;
            }
        } elif op == SRE_OP_SUCCESS or op == SRE_OP_FAILURE {
            # Nothing to check; these normally end the matching process
            continue;
        } elif op == SRE_OP_AT {
            if not cursor.get_arg() or cursor.arg > 11 {
                return -1;
            }
        } elif op == SRE_OP_ANY or op == SRE_OP_ANY_ALL {
            # These have no operands
            continue;
        } elif op == SRE_OP_IN
            or op == SRE_OP_IN_IGNORE
            or op == SRE_OP_IN_UNI_IGNORE
            or op == SRE_OP_IN_LOC_IGNORE {
            if not cursor.get_skip() {
                return -1;
            }
            # Stop 1 before the end; we check the FAILURE below
            skip_count = int(cursor.skip_count);
            if validate_charset(cursor.code, cursor.code + (skip_count - 2)) != 0 {
                return -1;
            }
            if (cursor.code + (skip_count - 2)).view(1)[0] != u32(SRE_OP_FAILURE) {
                return -1;
            }
            cursor.code += skip_count - 1;
        } elif op == SRE_OP_INFO {
            if validate_info(cursor) != 0 {
                return -1;
            }
        } elif op == SRE_OP_BRANCH {
            if validate_branch(cursor, groups) != 0 {
                return -1;
            }
        } elif op == SRE_OP_REPEAT_ONE
            or op == SRE_OP_MIN_REPEAT_ONE
            or op == SRE_OP_POSSESSIVE_REPEAT_ONE {
            if not cursor.get_skip() {
                return -1;
            }
            skip_count = int(cursor.skip_count);
            if not cursor.get_arg() {
                return -1;
            }
            minimum = cursor.arg;
            if not cursor.get_arg() {
                return -1;
            }
            maximum = cursor.arg;
            if minimum > maximum or maximum > SRE_MAXREPEAT {
                return -1;
            }
            if validate_inner(cursor.code, cursor.code + (skip_count - 4), groups)
                != 0 {
                return -1;
            }
            cursor.code += skip_count - 4;
            if not cursor.get_op() or cursor.op != u32(SRE_OP_SUCCESS) {
                return -1;
            }
        } elif op == SRE_OP_REPEAT or op == SRE_OP_POSSESSIVE_REPEAT {
            if not cursor.get_skip() {
                return -1;
            }
            skip_count = int(cursor.skip_count);
            if not cursor.get_arg() {
                return -1;
            }
            minimum = cursor.arg;
            if not cursor.get_arg() {
                return -1;
            }
            maximum = cursor.arg;
            if minimum > maximum or maximum > SRE_MAXREPEAT {
                return -1;
            }
            if validate_inner(cursor.code, cursor.code + (skip_count - 3), groups)
                != 0 {
                return -1;
            }
            cursor.code += skip_count - 3;
            if not cursor.get_op() {
                return -1;
            }
            if op == SRE_OP_POSSESSIVE_REPEAT {
                if cursor.op != u32(SRE_OP_SUCCESS) {
                    return -1;
                }
            } elif cursor.op != u32(SRE_OP_MAX_UNTIL)
                and cursor.op != u32(SRE_OP_MIN_UNTIL) {
                return -1;
            }
        } elif op == SRE_OP_ATOMIC_GROUP {
            if not cursor.get_skip() {
                return -1;
            }
            skip_count = int(cursor.skip_count);
            if validate_inner(cursor.code, cursor.code + (skip_count - 2), groups)
                != 0 {
                return -1;
            }
            cursor.code += skip_count - 2;
            if not cursor.get_op() or cursor.op != u32(SRE_OP_SUCCESS) {
                return -1;
            }
        } elif op == SRE_OP_GROUPREF
            or op == SRE_OP_GROUPREF_IGNORE
            or op == SRE_OP_GROUPREF_UNI_IGNORE
            or op == SRE_OP_GROUPREF_LOC_IGNORE {
            if not cursor.get_arg() or i64(cursor.arg) >= groups {
                return -1;
            }
        } elif op == SRE_OP_GROUPREF_EXISTS {
            # The regex syntax for this is: '(?(group)then|else)', where
            # 'group' is either an integer group number or a group name,
            # 'then' and 'else' are sub-regexes, and 'else' is optional.
            if not cursor.get_arg() or i64(cursor.arg) >= groups {
                return -1;
            }
            if not cursor.get_skip(1) {
                return -1;
            }
            skip_count = int(cursor.skip_count);
            # The skip_count is relative to the first arg!
            cursor.code -= 1;
            # If there is both a 'then' part and an 'else' part, the 'then'
            # part ends with a JUMP to after the 'else' part; there is no
            # direct way to decide which it is, so look for a JUMP opcode
            # preceding our skip_count target.
            rc = validate_inner(
                cursor.code + 1, cursor.code + (skip_count - 1), groups
            );
            if rc == 1 {
                # Position after JUMP, at <skipno>
                cursor.code += skip_count - 2;
                if not cursor.get_skip() {
                    return -1;
                }
                skip_count = int(cursor.skip_count);
                rc = validate_inner(
                    cursor.code, cursor.code + (skip_count - 1), groups
                );
            }
            if rc != 0 {
                return -1;
            }
            cursor.code += skip_count - 1;
        } elif op == SRE_OP_ASSERT or op == SRE_OP_ASSERT_NOT {
            if not cursor.get_skip() {
                return -1;
            }
            skip_count = int(cursor.skip_count);
            # 0 for lookahead, width for lookbehind
            if not cursor.get_arg() {
                return -1;
            }
            # Back up over arg to simplify math below
            cursor.code -= 1;
            # Stop 1 before the end; we check the SUCCESS below
            if validate_inner(cursor.code + 1, cursor.code + (skip_count - 2), groups)
                != 0 {
                return -1;
            }
            cursor.code += skip_count - 2;
            if not cursor.get_op() or cursor.op != u32(SRE_OP_SUCCESS) {
                return -1;
            }
        } elif op == SRE_OP_JUMP {
            if cursor.code + 1 != cursor.end {
                return -1;
            }
            return 1;
        } else {
            return -1;
        }
    }
    return 0;
}

# `count > (uintptr_t)distance`: a negative distance is a huge unsigned one.
def:priv exceeds(count: i64, distance: i64) -> bool {
    return distance >= 0 and count > distance;
}

# An INFO block. A minimal info field is
# <INFO> <1=skip_count> <2=flags> <3=min> <4=max>; if SRE_INFO_PREFIX or
# SRE_INFO_CHARSET is in the flags, more follows.
def:priv validate_info(cursor: CodeCursor) -> int {
    if not cursor.get_skip() {
        return -1;
    }
    newcode = cursor.code + (int(cursor.skip_count) - 1);
    if not cursor.get_arg() {
        return -1;
    }
    flags = int(cursor.arg);
    if not cursor.get_arg() or not cursor.get_arg() {
        return -1;
    }
    # Check that only valid flags are present
    if (flags & ~(SRE_INFO_PREFIX | SRE_INFO_LITERAL | SRE_INFO_CHARSET)) != 0 {
        return -1;
    }
    # PREFIX and CHARSET are mutually exclusive
    if (flags & SRE_INFO_PREFIX) != 0 and (flags & SRE_INFO_CHARSET) != 0 {
        return -1;
    }
    # LITERAL implies PREFIX
    if (flags & SRE_INFO_LITERAL) != 0 and (flags & SRE_INFO_PREFIX) == 0 {
        return -1;
    }
    # Validate the prefix
    if (flags & SRE_INFO_PREFIX) != 0 {
        if not cursor.get_arg() {
            return -1;
        }
        prefix_len = i64(cursor.arg);
        if not cursor.get_arg() {
            return -1;
        }
        # Here comes the prefix string
        if exceeds(prefix_len, newcode - cursor.code) {
            return -1;
        }
        cursor.code += prefix_len;
        # And here comes the overlap table
        if exceeds(prefix_len, newcode - cursor.code) {
            return -1;
        }
        # Each overlap value should be < prefix_len
        for i in range(prefix_len) {
            if i64((cursor.code + i).view(1)[0]) >= prefix_len {
                return -1;
            }
        }
        cursor.code += prefix_len;
    }
    # Validate the charset
    if (flags & SRE_INFO_CHARSET) != 0 {
        if validate_charset(cursor.code, newcode - 1) != 0 {
            return -1;
        }
        if (newcode - 1).view(1)[0] != u32(SRE_OP_FAILURE) {
            return -1;
        }
        cursor.code = newcode;
    } elif cursor.code != newcode {
        return -1;
    }
    return 0;
}

# A BRANCH: each alternative ends with a JUMP to the same target.
def:priv validate_branch(cursor: CodeCursor, groups: i64) -> int {
    target = ptr[u32]();
    while True {
        if not cursor.get_skip() {
            return -1;
        }
        skip_count = int(cursor.skip_count);
        if skip_count == 0 {
            break;
        }
        # Stop 2 before the end; we check the JUMP below
        if validate_inner(cursor.code, cursor.code + (skip_count - 3), groups) != 0 {
            return -1;
        }
        cursor.code += skip_count - 3;
        # Check that it ends with a JUMP, and that each JUMP has the same
        # target
        if not cursor.get_op() or cursor.op != u32(SRE_OP_JUMP) {
            return -1;
        }
        if not cursor.get_skip() {
            return -1;
        }
        jump_target = cursor.code + (int(cursor.skip_count) - 1);
        if not target {
            target = jump_target;
        } elif jump_target != target {
            return -1;
        }
    }
    if cursor.code != target {
        return -1;
    }
    return 0;
}

def:priv validate_outer(code: ptr[u32], end: ptr[u32], groups: i64) -> int {
    if groups < 0
        or groups > SRE_MAXGROUPS
        or code >= end
        or (end - 1).view(1)[0] != u32(SRE_OP_SUCCESS) {
        return -1;
    }
    return validate_inner(code, end - 1, groups);
}

def validate(self: ptr[PyObject]) -> bool {
    p = pattern_record(self).view(1);
    code = pattern_code(self);
    if validate_outer(code, code + p[0].codesize, p[0].groups) != 0 {
        PyErr_SetString(PyExc_RuntimeError, "invalid SRE code");
        return False;
    }
    return True;
}

# ------------------------------------------------------------------ Match

def match_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    m = match_record(op).view(1);
    result = visit_one(type_object(op), visitor, context);
    if result == 0 {
        result = visit_one(m[0].string, visitor, context);
    }
    if result == 0 {
        result = visit_one(m[0].regs, visitor, context);
    }
    if result == 0 {
        result = visit_one(m[0].pattern, visitor, context);
    }
    return result;
}

def match_clear(op: ptr[PyObject]) -> i32 {
    m = match_record(op).view(1);
    string = m[0].string;
    m[0].string = NULL;
    jacpy_release(string);
    regs = m[0].regs;
    m[0].regs = NULL;
    jacpy_release(regs);
    pattern = m[0].pattern;
    m[0].pattern = NULL;
    jacpy_release(pattern);
    return i32(0);
}

def match_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    match_clear(op);
    free_object(op);
}

# match_getslice_by_index(): group `index` of the match, `default` (a new
# reference) when it or the string is undefined.
def match_getslice_by_index(
    self: ptr[PyObject], index: i64, default_value: ptr[PyObject]
) -> ptr[PyObject] {
    m = match_record(self).view(1);
    marks = match_marks(self);
    index *= 2;
    string = m[0].string;
    i = (marks + index).view(1)[0];
    if string == Py_None or i < 0 {
        # return default value if the string or group is undefined
        return Py_NewRef(default_value);
    }
    j = (marks + (index + 1)).view(1)[0];
    if jacpy_is_unicode(string) != 0 {
        length = jacpy_unicode_size(string);
        return PyUnicode_Substring(
            string, i if i < length else length, j if j < length else length
        );
    }
    view = new_view();
    if not view {
        return NULL;
    }
    data = getstring(string, view);
    if not data {
        PyMem_Free(view);
        return NULL;
    }
    length = view.view(1)[0].length;
    result = getslice(
        i32(1), data, string, i if i < length else length, j if j < length else length
    );
    free_view(view);
    return result;
}

# match_getindex(): the group number `index` (an int or a group name)
# names; -1 with IndexError when there is no such group.
def match_getindex(self: ptr[PyObject], index: ptr[PyObject]) -> i64 {
    if not index {
        # Default value
        return 0;
    }
    m = match_record(self).view(1);
    i: i64 = -1;
    if PyIndex_Check(index) != 0 {
        i = PyNumber_AsSsize_t(index, NULL);
    } else {
        groupindex = pattern_record(m[0].pattern).view(1)[0].groupindex;
        if groupindex {
            found = PyDict_GetItemWithError(groupindex, index);
            if found and jacpy_is_long(found) != 0 {
                i = PyLong_AsSsize_t(found);
            }
        }
    }
    if i < 0 or i >= m[0].groups {
        # raise IndexError if we were given a bad group number
        if not PyErr_Occurred() {
            PyErr_SetString(PyExc_IndexError, "no such group");
        }
        return -1;
    }
    return i;
}

def match_getslice(
    self: ptr[PyObject], index: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject] {
    i = match_getindex(self, index);
    if i < 0 {
        return NULL;
    }
    return match_getslice_by_index(self, i, default_value);
}

# _sre.SRE_Match.expand(template)
def _sre_SRE_Match_expand_impl(
    self: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject] {
    module = PyType_GetModule(type_object(self));
    filter = compile_template(module, match_record(self).view(1)[0].pattern, template);
    if not filter {
        return NULL;
    }
    result = expand_template(filter, self);
    jacpy_release(filter);
    return result;
}

# group([group1, ...]): the subgroup(s) of the match by indices or names.
def match_group(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    size = PyTuple_Size(args);
    if size == 0 {
        return match_getslice_by_index(self, 0, Py_None);
    }
    if size == 1 {
        return match_getslice(self, tuple_get_item(args, 0), Py_None);
    }
    # fetch multiple items
    result = PyTuple_New(size);
    if not result {
        return NULL;
    }
    for i in range(size) {
        item = match_getslice(self, tuple_get_item(args, i), Py_None);
        if not item {
            jacpy_release(result);
            return NULL;
        }
        tuple_set_item(result, i, item);
    }
    return result;
}

def match_getitem(self: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    return match_getslice(self, name, Py_None);
}

# _sre.SRE_Match.groups(default=None)
def _sre_SRE_Match_groups_impl(
    self: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject] {
    groups = match_record(self).view(1)[0].groups;
    result = PyTuple_New(groups - 1);
    if not result {
        return NULL;
    }
    for index in range(1, groups) {
        item = match_getslice_by_index(self, index, default_value);
        if not item {
            jacpy_release(result);
            return NULL;
        }
        tuple_set_item(result, index - 1, item);
    }
    return result;
}

# _sre.SRE_Match.groupdict(default=None)
def _sre_SRE_Match_groupdict_impl(
    self: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject] {
    result = PyDict_New();
    groupindex = pattern_record(match_record(self).view(1)[0].pattern).view(1)[
        0
    ].groupindex;
    if not result or not groupindex {
        return result;
    }
    pos: i64 = 0;
    key = NULL;
    record = NULL;
    while PyDict_Next(groupindex, &mut pos, &mut key, &mut record) != 0 {
        name = Py_NewRef(key);
        value = match_getslice(self, name, default_value);
        if not value {
            jacpy_release(name);
            jacpy_release(result);
            return NULL;
        }
        status = PyDict_SetItem(result, name, value);
        jacpy_release(value);
        jacpy_release(name);
        if status < 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}

# _sre.SRE_Match.start(group=0, /) -> Py_ssize_t
def _sre_SRE_Match_start_impl(self: ptr[PyObject], group: ptr[PyObject]) -> i64 {
    index = match_getindex(self, group);
    if index < 0 {
        return -1;
    }
    # mark is -1 if group is undefined
    return (match_marks(self) + index * 2).view(1)[0];
}

# _sre.SRE_Match.end(group=0, /) -> Py_ssize_t
def _sre_SRE_Match_end_impl(self: ptr[PyObject], group: ptr[PyObject]) -> i64 {
    index = match_getindex(self, group);
    if index < 0 {
        return -1;
    }
    # mark is -1 if group is undefined
    return (match_marks(self) + (index * 2 + 1)).view(1)[0];
}

def pair(i1: i64, i2: i64) -> ptr[PyObject] {
    result = PyTuple_New(2);
    if not result {
        return NULL;
    }
    item = PyLong_FromSsize_t(i1);
    if not item {
        jacpy_release(result);
        return NULL;
    }
    tuple_set_item(result, 0, item);
    item = PyLong_FromSsize_t(i2);
    if not item {
        jacpy_release(result);
        return NULL;
    }
    tuple_set_item(result, 1, item);
    return result;
}

# _sre.SRE_Match.span(group=0, /)
def _sre_SRE_Match_span_impl(
    self: ptr[PyObject], group: ptr[PyObject]
) -> ptr[PyObject] {
    index = match_getindex(self, group);
    if index < 0 {
        return NULL;
    }
    # marks are -1 if group is undefined
    marks = match_marks(self);
    return pair((marks + index * 2).view(1)[0], (marks + (index * 2 + 1)).view(1)[0]);
}

def match_regs(self: ptr[PyObject]) -> ptr[PyObject] {
    m = match_record(self).view(1);
    marks = match_marks(self);
    regs = PyTuple_New(m[0].groups);
    if not regs {
        return NULL;
    }
    for index in range(m[0].groups) {
        item = pair(
            (marks + index * 2).view(1)[0], (marks + (index * 2 + 1)).view(1)[0]
        );
        if not item {
            jacpy_release(regs);
            return NULL;
        }
        tuple_set_item(regs, index, item);
    }
    m[0].regs = Py_NewRef(regs);
    return regs;
}

def _sre_SRE_Match___copy___impl(self: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(self);
}

def _sre_SRE_Match___deepcopy___impl(
    self: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_NewRef(self);
}

def match_lastindex_get(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    lastindex = match_record(op).view(1)[0].lastindex;
    if lastindex >= 0 {
        return PyLong_FromSsize_t(lastindex);
    }
    return Py_NewRef(Py_None);
}

def match_lastgroup_get(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    m = match_record(op).view(1);
    indexgroup = pattern_record(m[0].pattern).view(1)[0].indexgroup;
    if indexgroup
        and m[0].lastindex >= 0
        and m[0].lastindex < PyTuple_Size(indexgroup) {
        return Py_NewRef(tuple_get_item(indexgroup, m[0].lastindex));
    }
    return Py_NewRef(Py_None);
}

def match_regs_get(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    regs = match_record(op).view(1)[0].regs;
    if regs {
        return Py_NewRef(regs);
    }
    return match_regs(op);
}

def match_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    group0 = match_getslice_by_index(self, 0, Py_None);
    if not group0 {
        return NULL;
    }
    marks = match_marks(self);
    result = PyUnicode_FromFormat(
        "<%s object; span=(%zd, %zd), match=%.50R>",
        tp_name(self),
        marks.view(1)[0],
        (marks + 1).view(1)[0],
        group0
    );
    jacpy_release(group0);
    return result;
}

# pattern_new_match(): the Match object of a successful match (status > 0),
# None for no match (0), NULL with the exception set for an error (< 0).
def pattern_new_match(
    match_type: ptr[PyObject], pattern: ptr[PyObject], state: ptr[SreState], status: i64
) -> ptr[PyObject] {
    if status > 0 {
        groups = pattern_record(pattern).view(1)[0].groups;
        # create match object (with room for extra group marks)
        match_object = _PyObject_GC_NewVar(match_type, 2 * (groups + 1));
        if not match_object {
            return NULL;
        }
        m = match_record(match_object).view(1);
        m[0].pattern = Py_NewRef(pattern);
        st = state.view(1);
        m[0].string = Py_NewRef(st[0].string);
        m[0].regs = NULL;
        m[0].groups = groups + 1;
        # fill in group slices
        base = ptr[u8](st[0].beginning);
        n = i64(st[0].charsize);
        marks = match_marks(match_object);
        marks.view(1)[0] = (ptr[u8](st[0].start) - base) // n;
        (marks + 1).view(1)[0] = (ptr[u8](st[0].position) - base) // n;
        lastmark = i64(st[0].lastmark);
        for i in range(groups) {
            j = i * 2;
            start = (st[0].mark + j).view(1)[0];
            end = (st[0].mark + (j + 1)).view(1)[0];
            if j + 1 <= lastmark and start and end {
                first = (ptr[u8](start) - base) // n;
                last = (ptr[u8](end) - base) // n;
                (marks + (j + 2)).view(1)[0] = first;
                (marks + (j + 3)).view(1)[0] = last;
                # check wrong span
                if first > last {
                    PyErr_SetString(
                        PyExc_SystemError,
                        "The span of capturing group is wrong, please report a bug for the re module."
                    );
                    jacpy_release(match_object);
                    return NULL;
                }
            } else {
                # undefined
                (marks + (j + 2)).view(1)[0] = -1;
                (marks + (j + 3)).view(1)[0] = -1;
            }
        }
        m[0].pos = st[0].pos;
        m[0].endpos = st[0].endpos;
        m[0].lastindex = i64(st[0].lastindex);
        PyObject_GC_Track(match_object);
        return match_object;
    } elif status == 0 {
        # no match
        return Py_NewRef(Py_None);
    }
    # internal error
    pattern_error(status);
    return NULL;
}

# ---------------------------------------------------------------- Scanner

def scanner_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    result = visit_one(type_object(op), visitor, context);
    if result != 0 {
        return result;
    }
    return visit_one(scanner_record(op).view(1)[0].pattern, visitor, context);
}

def scanner_clear(op: ptr[PyObject]) -> i32 {
    s = scanner_record(op).view(1);
    pattern = s[0].pattern;
    s[0].pattern = NULL;
    jacpy_release(pattern);
    return i32(0);
}

def scanner_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    state_fini(scanner_state(op), False);
    scanner_clear(op);
    free_object(op);
}

def:priv scanner_begin(self: ptr[PyObject]) -> bool {
    executing = scanner_executing(self).view(1);
    was_executing = executing[0];
    executing[0] = 1;
    if was_executing != 0 {
        PyErr_SetString(
            PyExc_ValueError, "regular expression scanner already executing"
        );
        return False;
    }
    return True;
}

def:priv scanner_end(self: ptr[PyObject]) {
    scanner_executing(self).view(1)[0] = 0;
}

def:priv scanner_next(
    self: ptr[PyObject], cls: ptr[PyObject], search: bool
) -> ptr[PyObject] {
    if not scanner_begin(self) {
        return NULL;
    }
    state = scanner_state(self);
    st = state.view(1);
    if not st[0].start {
        scanner_end(self);
        return Py_NewRef(Py_None);
    }
    state_reset(state);
    st[0].position = st[0].start;
    pattern = scanner_record(self).view(1)[0].pattern;
    if search {
        status = sre_search(state, pattern_code(pattern));
    } else {
        status = sre_match(state, pattern_code(pattern));
    }
    if PyErr_Occurred() {
        scanner_end(self);
        return NULL;
    }
    match_object = pattern_new_match(
        module_slot(cls, STATE_MATCH_TYPE), pattern, state, status
    );
    if status == 0 {
        st[0].start = ptr();
    } else {
        st[0].must_advance = i32(st[0].position == st[0].start);
        st[0].start = st[0].position;
    }
    scanner_end(self);
    return match_object;
}

# _sre.SRE_Scanner.match(cls, /)
def _sre_SRE_Scanner_match_impl(
    self: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return scanner_next(self, cls, False);
}

# _sre.SRE_Scanner.search(cls, /)
def _sre_SRE_Scanner_search_impl(
    self: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return scanner_next(self, cls, True);
}

def pattern_scanner(
    scanner_type: ptr[PyObject],
    self: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    # create scanner object
    scanner = _PyObject_GC_New(scanner_type);
    if not scanner {
        return NULL;
    }
    s = scanner_record(scanner).view(1);
    s[0].pattern = NULL;
    scanner_executing(scanner).view(1)[0] = 0;
    # create search state object
    if not state_init(scanner_state(scanner), self, string, pos, endpos, False) {
        # state_fini() of the scanner's dealloc finds nothing to release.
        memset(scanner_state(scanner), 0, u64(SRE_STATE_SIZE));
        jacpy_release(scanner);
        return NULL;
    }
    s[0].pattern = Py_NewRef(self);
    PyObject_GC_Track(scanner);
    return scanner;
}

# --------------------------------------------------------------- Template

def template_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    result = visit_one(type_object(op), visitor, context);
    if result != 0 {
        return result;
    }
    result = visit_one(template_record(op).view(1)[0].literal, visitor, context);
    if result != 0 {
        return result;
    }
    items = template_items(op);
    for i in range(object_size(op)) {
        result = visit_one((items + i).view(1)[0].literal, visitor, context);
        if result != 0 {
            return result;
        }
    }
    return i32(0);
}

def template_clear(op: ptr[PyObject]) -> i32 {
    t = template_record(op).view(1);
    literal = t[0].literal;
    t[0].literal = NULL;
    jacpy_release(literal);
    items = template_items(op);
    for i in range(object_size(op)) {
        item = (items + i).view(1);
        literal = item[0].literal;
        item[0].literal = NULL;
        jacpy_release(literal);
    }
    return i32(0);
}

def template_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    template_clear(op);
    free_object(op);
}

# expand_template(): the replacement a compiled template gives for `match`.
def expand_template(self: ptr[PyObject], match_object: ptr[PyObject]) -> ptr[PyObject] {
    t = template_record(self).view(1);
    size = object_size(self);
    if size == 0 {
        return Py_NewRef(t[0].literal);
    }
    unicode = jacpy_is_unicode(t[0].literal) != 0;
    # the non-empty chunks
    out = ptr[ptr[PyObject]](PyMem_Malloc(u64(t[0].chunks * 8)));
    if not out {
        PyErr_NoMemory();
        return NULL;
    }
    count: i64 = 0;
    out.view(1)[0] = Py_NewRef(t[0].literal);
    count += 1;
    items = template_items(self);
    groups = match_record(match_object).view(1)[0].groups;
    result = NULL;
    failed = False;
    for i in range(size) {
        item = (items + i).view(1);
        index = item[0].index;
        if index >= groups {
            PyErr_SetString(PyExc_IndexError, "no such group");
            failed = True;
            break;
        }
        group = match_getslice_by_index(match_object, index, Py_None);
        if not group {
            failed = True;
            break;
        }
        if group != Py_None {
            (out + count).view(1)[0] = Py_NewRef(group);
            count += 1;
        }
        jacpy_release(group);
        literal = item[0].literal;
        if literal {
            (out + count).view(1)[0] = Py_NewRef(literal);
            count += 1;
        }
    }
    if not failed {
        if unicode {
            empty = PyUnicode_New(0, 0);
            result = _PyUnicode_JoinArray(empty, out, count);
            jacpy_release(empty);
        } else {
            list = PyList_New(0);
            if list {
                ok = True;
                for k in range(count) {
                    if PyList_Append(list, (out + k).view(1)[0]) < 0 {
                        ok = False;
                        break;
                    }
                }
                if ok {
                    empty = jacpy_buffer_new(0);
                    if empty {
                        result = PyBytes_Join(empty, list);
                        jacpy_release(empty);
                    }
                }
                jacpy_release(list);
            }
        }
    }
    for k in range(count) {
        jacpy_release((out + k).view(1)[0]);
    }
    PyMem_Free(out);
    return result;
}

# Py_VISIT
def:priv visit_one(value: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return visit_reference(value, visitor, context);
}
