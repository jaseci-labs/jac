import from c {
    def memset(target: ptr, value: i32, size: u64) -> ptr;  def memcmp(
        left: ptr, right: ptr, size: u64
    ) -> i32;  def memchr(source: ptr, value: i32, size: u64) -> ptr;  obj PatternObject {
        has ob_base: PyVarObject,
            groups: i64,
            groupindex: ptr[PyObject],
            indexgroup: ptr[PyObject],
            pattern: ptr[PyObject],
            flags: i32,
            weakreflist: ptr[PyObject],
            isbytes: i32,
            codesize: i64,
            code: u32;
    }  obj MatchObject {
        has ob_base: PyVarObject,
            string: ptr[PyObject],
            regs: ptr[PyObject],
            pattern: ptr[PyObject],
            pos: i64,
            endpos: i64,
            lastindex: i64,
            groups: i64,
            mark: i64;
    }  obj TemplateObject {
        has ob_base: PyVarObject,
            chunks: i64,
            literal: ptr[PyObject];
    }  obj TemplateItem {
        has index: i64,
            literal: ptr[PyObject];
    }  obj ScannerObject {
        has ob_base: _object,
            pattern: ptr[PyObject],
            state: SreState,
            executing: i32;
    }
}

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
     STATE_BUFFER: Final[int] = 40;

glob PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     SRE_MAXGROUPS: Final[int] = 1073741823,
     SRE_CODE_SIZE: Final[int] = 4,
     COPYRIGHT: str = " SRE 2.2.2 Copyright (c) 1997-2002 by Secret Labs AB ";

glob STATE_PATTERN_TYPE: Final[int] = 0,
     STATE_MATCH_TYPE: Final[int] = 1,
     STATE_SCANNER_TYPE: Final[int] = 2,
     STATE_TEMPLATE_TYPE: Final[int] = 3,
     STATE_COMPILE_TEMPLATE: Final[int] = 4,
     STATE_COUNT: Final[int] = 5;

glob SRE_Pattern_token = ClassToken(),
     SRE_Scanner_token = ClassToken();

def pattern_record(op: ptr[PyObject]) -> ptr[PatternObject];

def match_record(op: ptr[PyObject]) -> ptr[MatchObject];

def template_record(op: ptr[PyObject]) -> ptr[TemplateObject];

def scanner_record(op: ptr[PyObject]) -> ptr[ScannerObject];

def pattern_code(op: ptr[PyObject]) -> ptr[u32];

def match_marks(op: ptr[PyObject]) -> ptr[i64];

def template_items(op: ptr[PyObject]) -> ptr[TemplateItem];

def scanner_state(op: ptr[PyObject]) -> ptr[SreState];

def type_object(op: ptr[PyObject]) -> ptr[PyObject];

def tp_name(op: ptr[PyObject]) -> ptr[u8];

def module_slot(cls: ptr[PyObject], slot: int) -> ptr[PyObject];

def free_object(op: ptr[PyObject]);

def _sre_getcodesize_impl(module: ptr[PyObject]) -> i32;

def:priv as_code(character: i32) -> u32;

def:priv as_int(value: u32) -> i32;

def _sre_ascii_iscased_impl(module: ptr[PyObject], character: i32) -> i32;

def _sre_unicode_iscased_impl(module: ptr[PyObject], character: i32) -> i32;

def _sre_ascii_tolower_impl(module: ptr[PyObject], character: i32) -> i32;

def _sre_unicode_tolower_impl(module: ptr[PyObject], character: i32) -> i32;

def state_reset(state: ptr[SreState]);

def getstring(string: ptr[PyObject], view: ptr[Py_buffer]) -> ptr;

def string_length(string: ptr[PyObject], view: ptr[Py_buffer]) -> i64;

def string_charsize(string: ptr[PyObject]) -> i32;

def new_view -> ptr[Py_buffer];

def free_view(view: ptr[Py_buffer]);

def state_new(pattern: ptr[PyObject]) -> ptr[SreState];

def state_init(
    state: ptr[SreState],
    pattern: ptr[PyObject],
    string: ptr[PyObject],
    start: i64,
    end: i64,
    inline_marks: bool
) -> ptr[PyObject];

def:priv state_init_failed(state: ptr[SreState], inline_marks: bool);

def state_fini(state: ptr[SreState], inline_marks: bool);

def state_offset(state: ptr[SreState], member: ptr) -> i64;

def getslice(
    isbytes: i32, data: ptr, string: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject];

def state_getslice(
    state: ptr[SreState], index: i64, string: ptr[PyObject], empty: bool
) -> ptr[PyObject];

def pattern_error(status: i64);

def sre_match(state: ptr[SreState], pattern: ptr[u32]) -> i64;

def sre_search(state: ptr[SreState], pattern: ptr[u32]) -> i64;

def pattern_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def pattern_clear(op: ptr[PyObject]) -> i32;

def pattern_dealloc(op: ptr[PyObject]);

def:priv pattern_run(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64,
    kind: int
) -> ptr[PyObject];

def _sre_SRE_Pattern_match_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject];

def _sre_SRE_Pattern_fullmatch_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject];

def _sre_SRE_Pattern_search_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject];

def _sre_SRE_Pattern_findall_impl(
    self: ptr[PyObject], string: ptr[PyObject], pos: i64, endpos: i64
) -> ptr[PyObject];

def:priv findall_into(
    self: ptr[PyObject],
    state: ptr[SreState],
    string: ptr[PyObject],
    list: ptr[PyObject]
) -> bool;

def _sre_SRE_Pattern_finditer_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject];

def _sre_SRE_Pattern_scanner_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject];

def _sre_SRE_Pattern_split_impl(
    self: ptr[PyObject], string: ptr[PyObject], maxsplit: i64
) -> ptr[PyObject];

def:priv split_into(
    self: ptr[PyObject],
    state: ptr[SreState],
    string: ptr[PyObject],
    maxsplit: i64,
    list: ptr[PyObject]
) -> bool;

def:priv append_owned(list: ptr[PyObject], item: ptr[PyObject]) -> bool;

def compile_template(
    module: ptr[PyObject], pattern: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    obj TemplateArguments {
        has pattern: ptr[PyObject],
            template: ptr[PyObject];
    }
}

def:priv call_template_compiler(
    func: ptr[PyObject], pattern: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject];

def:priv is_exact_unicode(value: ptr[PyObject]) -> bool;

def:priv set_module_slot(module: ptr[PyObject], slot: int, value: ptr[PyObject]);

def pattern_subx(
    module: ptr[PyObject],
    self: ptr[PyObject],
    ptemplate: ptr[PyObject],
    string: ptr[PyObject],
    count: i64,
    subn: bool
) -> ptr[PyObject];

def:priv subx_run(
    module: ptr[PyObject],
    self: ptr[PyObject],
    state: ptr[SreState],
    filter: ptr[PyObject],
    filter_type: int,
    string: ptr[PyObject],
    count: i64,
    subn: bool
) -> ptr[PyObject];

import from c {
    obj OneArgument {
        has value: ptr[PyObject];
    }
}

def call_one(callable: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def _sre_SRE_Pattern_sub_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    repl: ptr[PyObject],
    string: ptr[PyObject],
    count: i64
) -> ptr[PyObject];

def _sre_SRE_Pattern_subn_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    repl: ptr[PyObject],
    string: ptr[PyObject],
    count: i64
) -> ptr[PyObject];

def _sre_SRE_Pattern___copy___impl(self: ptr[PyObject]) -> ptr[PyObject];

def _sre_SRE_Pattern___deepcopy___impl(
    self: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject];

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

def pattern_repr(self: ptr[PyObject]) -> ptr[PyObject];

def pattern_groupindex(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def pattern_hash(op: ptr[PyObject]) -> i64;

def pattern_richcompare(
    lefto: ptr[PyObject], righto: ptr[PyObject], op: i32
) -> ptr[PyObject];

def _sre_compile_impl(
    module: ptr[PyObject],
    pattern: ptr[PyObject],
    flags: i32,
    code: ptr[PyObject],
    groups: i64,
    groupindex: ptr[PyObject],
    indexgroup: ptr[PyObject]
) -> ptr[PyObject];

def _sre_template_impl(
    module: ptr[PyObject], pattern: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject];

obj:priv CodeCursor {
    has code: ptr[u32],
        end: ptr[u32],
        op: u32 = 0,
        arg: u32 = 0,
        skip_count: u32 = 0;

    def get_op -> bool;
    def get_arg -> bool;
    def get_skip(adj: int = 0) -> bool;
}

def:priv validate_charset(code: ptr[u32], end: ptr[u32]) -> int;

def:priv validate_inner(code: ptr[u32], end: ptr[u32], groups: i64) -> int;

def:priv exceeds(count: i64, distance: i64) -> bool;

def:priv validate_info(cursor: CodeCursor) -> int;

def:priv validate_branch(cursor: CodeCursor, groups: i64) -> int;

def:priv validate_outer(code: ptr[u32], end: ptr[u32], groups: i64) -> int;

def validate(self: ptr[PyObject]) -> bool;

def match_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def match_clear(op: ptr[PyObject]) -> i32;

def match_dealloc(op: ptr[PyObject]);

def match_getslice_by_index(
    self: ptr[PyObject], index: i64, default_value: ptr[PyObject]
) -> ptr[PyObject];

def match_getindex(self: ptr[PyObject], index: ptr[PyObject]) -> i64;

def match_getslice(
    self: ptr[PyObject], index: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject];

def _sre_SRE_Match_expand_impl(
    self: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject];

def match_group(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def match_getitem(self: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def _sre_SRE_Match_groups_impl(
    self: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject];

def _sre_SRE_Match_groupdict_impl(
    self: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject];

def _sre_SRE_Match_start_impl(self: ptr[PyObject], group: ptr[PyObject]) -> i64;

def _sre_SRE_Match_end_impl(self: ptr[PyObject], group: ptr[PyObject]) -> i64;

def pair(i1: i64, i2: i64) -> ptr[PyObject];

def _sre_SRE_Match_span_impl(
    self: ptr[PyObject], group: ptr[PyObject]
) -> ptr[PyObject];

def match_regs(self: ptr[PyObject]) -> ptr[PyObject];

def _sre_SRE_Match___copy___impl(self: ptr[PyObject]) -> ptr[PyObject];

def _sre_SRE_Match___deepcopy___impl(
    self: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject];

def match_lastindex_get(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def match_lastgroup_get(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def match_regs_get(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def match_repr(self: ptr[PyObject]) -> ptr[PyObject];

def pattern_new_match(
    match_type: ptr[PyObject], pattern: ptr[PyObject], state: ptr[SreState], status: i64
) -> ptr[PyObject];

def scanner_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def scanner_clear(op: ptr[PyObject]) -> i32;

def scanner_dealloc(op: ptr[PyObject]);

def:priv scanner_begin(self: ptr[PyObject]) -> bool;

def:priv scanner_end(self: ptr[PyObject]);

def:priv scanner_next(
    self: ptr[PyObject], cls: ptr[PyObject], search: bool
) -> ptr[PyObject];

def _sre_SRE_Scanner_match_impl(
    self: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def _sre_SRE_Scanner_search_impl(
    self: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def pattern_scanner(
    scanner_type: ptr[PyObject],
    self: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject];

def template_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def template_clear(op: ptr[PyObject]) -> i32;

def template_dealloc(op: ptr[PyObject]);

def expand_template(self: ptr[PyObject], match_object: ptr[PyObject]) -> ptr[PyObject];

def:priv visit_one(value: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

impl pattern_record(op: ptr[PyObject]) -> ptr[PatternObject] {
    return ptr[PatternObject](op);
}

impl match_record(op: ptr[PyObject]) -> ptr[MatchObject] {
    return ptr[MatchObject](op);
}

impl template_record(op: ptr[PyObject]) -> ptr[TemplateObject] {
    return ptr[TemplateObject](op);
}

impl scanner_record(op: ptr[PyObject]) -> ptr[ScannerObject] {
    return ptr[ScannerObject](op);
}

impl pattern_code(op: ptr[PyObject]) -> ptr[u32] {
    return ptr[u32](ptr[u8](op) + PATTERN_CODE);
}

impl match_marks(op: ptr[PyObject]) -> ptr[i64] {
    return ptr[i64](ptr[u8](op) + MATCH_MARK);
}

impl template_items(op: ptr[PyObject]) -> ptr[TemplateItem] {
    return ptr[TemplateItem](ptr[u8](op) + TEMPLATE_SIZE);
}

impl scanner_state(op: ptr[PyObject]) -> ptr[SreState] {
    return ptr[SreState](ptr[u8](op) + SCANNER_STATE);
}

impl type_object(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](object_type(op));
}

impl tp_name(op: ptr[PyObject]) -> ptr[u8] {
    return object_type(op).view(1)[0].tp_name;
}

impl module_slot(cls: ptr[PyObject], slot: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(PyType_GetModule(cls), i64(slot));
}

impl free_object(op: ptr[PyObject]) {
    tp = type_object(op);
    PyObject_GC_Del(op);
    jacpy_release(tp);
}

impl _sre_getcodesize_impl(module: ptr[PyObject]) -> i32 {
    return i32(SRE_CODE_SIZE);
}

impl as_code(character: i32) -> u32 {
    return u32(i64(character) & 0xFFFFFFFF);
}

impl as_int(value: u32) -> i32 {
    wide = i64(value);
    return i32(wide - 4294967296 if wide > 2147483647 else wide);
}

impl _sre_ascii_iscased_impl(module: ptr[PyObject], character: i32) -> i32 {
    ch = as_code(character);
    return i32(ch < 128 and ascii_is_alpha(ch));
}

impl _sre_unicode_iscased_impl(module: ptr[PyObject], character: i32) -> i32 {
    ch = as_code(character);
    return i32(ch != sre_lower_unicode(ch) or ch != sre_upper_unicode(ch));
}

impl _sre_ascii_tolower_impl(module: ptr[PyObject], character: i32) -> i32 {
    return as_int(sre_lower_ascii(as_code(character)));
}

impl _sre_unicode_tolower_impl(module: ptr[PyObject], character: i32) -> i32 {
    return as_int(sre_lower_unicode(as_code(character)));
}

impl state_reset(state: ptr[SreState]) {
    st = state.view(1);
    st[0].lastmark = -1;
    st[0].lastindex = -1;
    st[0].repeat = ptr[SreRepeat]();
    data_stack_dealloc(state);
}

impl getstring(string: ptr[PyObject], view: ptr[Py_buffer]) -> ptr {
    if jacpy_is_unicode(string) != 0 {
        return jacpy_unicode_data(string);
    }

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

impl string_length(string: ptr[PyObject], view: ptr[Py_buffer]) -> i64 {
    if jacpy_is_unicode(string) != 0 {
        return jacpy_unicode_size(string);
    }
    return view.view(1)[0].length;
}

impl string_charsize(string: ptr[PyObject]) -> i32 {
    if jacpy_is_unicode(string) != 0 {
        return i32(jacpy_unicode_kind(string));
    }
    return i32(1);
}

impl new_view -> ptr[Py_buffer] {
    view = ptr[Py_buffer](PyMem_Calloc(1, 80));
    if not view {
        PyErr_NoMemory();
    }
    return view;
}

impl free_view(view: ptr[Py_buffer]) {
    if view.view(1)[0].buf {
        PyBuffer_Release(view);
    }
    PyMem_Free(view);
}

impl state_new(pattern: ptr[PyObject]) -> ptr[SreState] {
    groups = pattern_record(pattern).view(1)[0].groups;
    state = ptr[SreState](PyMem_Malloc(u64(SRE_STATE_SIZE + groups * 16)));
    if not state {
        PyErr_NoMemory();
    }
    return state;
}

impl state_init(
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

impl state_init_failed(state: ptr[SreState], inline_marks: bool) {
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

impl state_fini(state: ptr[SreState], inline_marks: bool) {
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

    repeat_pool_clear(state);
}

impl state_offset(state: ptr[SreState], member: ptr) -> i64 {
    st = state.view(1);
    return (ptr[u8](member) - ptr[u8](st[0].beginning)) // i64(st[0].charsize);
}

impl getslice(
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

impl state_getslice(
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

impl pattern_error(status: i64) {
    if status == SRE_ERROR_RECURSION_LIMIT {
        PyErr_SetString(PyExc_RecursionError, "maximum recursion limit exceeded");
    } elif status == SRE_ERROR_MEMORY {
        PyErr_NoMemory();
    } elif status == SRE_ERROR_INTERRUPTED {
        return;
    } else {
        PyErr_SetString(
            PyExc_RuntimeError, "internal error in regular expression engine"
        );
    }
}

impl sre_match(state: ptr[SreState], pattern: ptr[u32]) -> i64 {
    charsize = state.view(1)[0].charsize;
    if charsize == 1 {
        return ucs1_match(state, pattern, i32(1));
    }
    if charsize == 2 {
        return ucs2_match(state, pattern, i32(1));
    }
    return ucs4_match(state, pattern, i32(1));
}

impl sre_search(state: ptr[SreState], pattern: ptr[u32]) -> i64 {
    charsize = state.view(1)[0].charsize;
    if charsize == 1 {
        return ucs1_search(state, pattern);
    }
    if charsize == 2 {
        return ucs2_search(state, pattern);
    }
    return ucs4_search(state, pattern);
}

impl pattern_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
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

impl pattern_clear(op: ptr[PyObject]) -> i32 {
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

impl pattern_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    if pattern_record(op).view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    pattern_clear(op);
    free_object(op);
}

impl pattern_run(
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

impl _sre_SRE_Pattern_match_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    return pattern_run(self, cls, string, pos, endpos, 0);
}

impl _sre_SRE_Pattern_fullmatch_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    return pattern_run(self, cls, string, pos, endpos, 1);
}

impl _sre_SRE_Pattern_search_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    return pattern_run(self, cls, string, pos, endpos, 2);
}

impl _sre_SRE_Pattern_findall_impl(
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

impl findall_into(
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

impl _sre_SRE_Pattern_finditer_impl(
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
    search = PyObject_GetAttrString(scanner, ptr[u8]("search"));
    jacpy_release(scanner);
    if not search {
        return NULL;
    }
    iterator = PyCallIter_New(search, Py_None);
    jacpy_release(search);
    return iterator;
}

impl _sre_SRE_Pattern_scanner_impl(
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

impl _sre_SRE_Pattern_split_impl(
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

impl split_into(
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

    item = getslice(
        st[0].isbytes, st[0].beginning, string, state_offset(state, last), st[0].endpos
    );
    return append_owned(list, item);
}

impl append_owned(list: ptr[PyObject], item: ptr[PyObject]) -> bool {
    if not item {
        return False;
    }
    status = PyList_Append(list, item);
    jacpy_release(item);
    return status >= 0;
}

impl compile_template(
    module: ptr[PyObject], pattern: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject] {
    func = jacpy_binding_state_get(module, i64(STATE_COMPILE_TEMPLATE));
    if not func {
        imported = PyImport_ImportModuleAttrString("re", "_compile_template");
        if not imported {
            return NULL;
        }

        set_module_slot(module, STATE_COMPILE_TEMPLATE, imported);
        jacpy_release(imported);
        func = imported;
    }
    result = call_template_compiler(func, pattern, template);
    if not result and PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
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

impl call_template_compiler(
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

impl is_exact_unicode(value: ptr[PyObject]) -> bool {
    return object_type(value) == object_type(PyUnicode_New(0, 0));
}

impl set_module_slot(module: ptr[PyObject], slot: int, value: ptr[PyObject]) {
    jacpy_binding_state_set(module, i64(slot), value);
}

impl pattern_subx(
    module: ptr[PyObject],
    self: ptr[PyObject],
    ptemplate: ptr[PyObject],
    string: ptr[PyObject],
    count: i64,
    subn: bool
) -> ptr[PyObject] {
    filter_type = 0;
    filter = NULL;
    if PyCallable_Check(ptemplate) != 0 {
        filter = Py_NewRef(ptemplate);
        filter_type = 2;
    } else {
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

impl subx_run(
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
            if not append_owned(
                list, getslice(st[0].isbytes, st[0].beginning, string, i, b)
            ) {
                jacpy_release(list);
                return NULL;
            }
        }
        item = NULL;
        if filter_type != 0 {
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
            item = Py_NewRef(filter);
        }

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

    if i < st[0].endpos {
        if not append_owned(
            list, getslice(st[0].isbytes, st[0].beginning, string, i, st[0].endpos)
        ) {
            jacpy_release(list);
            return NULL;
        }
    }

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

impl call_one(callable: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
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

impl _sre_SRE_Pattern_sub_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    repl: ptr[PyObject],
    string: ptr[PyObject],
    count: i64
) -> ptr[PyObject] {
    return pattern_subx(PyType_GetModule(cls), self, repl, string, count, False);
}

impl _sre_SRE_Pattern_subn_impl(
    self: ptr[PyObject],
    cls: ptr[PyObject],
    repl: ptr[PyObject],
    string: ptr[PyObject],
    count: i64
) -> ptr[PyObject] {
    return pattern_subx(PyType_GetModule(cls), self, repl, string, count, True);
}

impl _sre_SRE_Pattern___copy___impl(self: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(self);
}

impl _sre_SRE_Pattern___deepcopy___impl(
    self: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_NewRef(self);
}

impl pattern_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    p = pattern_record(self).view(1);
    flags = int(p[0].flags);

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
            if not append_owned(flag_items, jacpy_unicode_from_text(name)) {
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
            sep = PyUnicode_FromString(ptr[u8]("|"));
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

impl pattern_groupindex(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    groupindex = pattern_record(op).view(1)[0].groupindex;
    if not groupindex {
        return PyDict_New();
    }
    return PyDictProxy_New(groupindex);
}

impl pattern_hash(op: ptr[PyObject]) -> i64 {
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

impl pattern_richcompare(
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
        return PyBool_FromLong(i64(op == Py_EQ));
    }
    left = pattern_record(lefto).view(1);
    right = pattern_record(righto).view(1);
    cmp = left[0].flags == right[0].flags
        and left[0].isbytes == right[0].isbytes
        and left[0].codesize == right[0].codesize;
    if cmp {
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

impl _sre_compile_impl(
    module: ptr[PyObject],
    pattern: ptr[PyObject],
    flags: i32,
    code: ptr[PyObject],
    groups: i64,
    groupindex: ptr[PyObject],
    indexgroup: ptr[PyObject]
) -> ptr[PyObject] {
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

impl _sre_template_impl(
    module: ptr[PyObject], pattern: ptr[PyObject], template: ptr[PyObject]
) -> ptr[PyObject] {
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
            template_record(self).view(1)[0].ob_base.ob_size = i;
            jacpy_release(self);
            return NULL;
        }
        if index < 0 {
            template_record(self).view(1)[0].ob_base.ob_size = i;
            PyErr_SetString(PyExc_TypeError, "invalid template");
            jacpy_release(self);
            return NULL;
        }
        item = (items + i).view(1);
        item[0].index = index;
        literal = PyList_GetItem(template, 2 * i + 2);

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

impl CodeCursor.get_op -> bool {
    if self.code >= self.end {
        return False;
    }
    self.op = self.code.view(1)[0];
    self.code += 1;
    return True;
}

impl CodeCursor.get_arg -> bool {
    if self.code >= self.end {
        return False;
    }
    self.arg = self.code.view(1)[0];
    self.code += 1;
    return True;
}

impl CodeCursor.get_skip(adj: int = 0) -> bool {
    if self.code >= self.end {
        return False;
    }
    self.skip_count = self.code.view(1)[0];

    if ((i64(self.skip_count) - adj) & 0xFFFFFFFF) > self.end - self.code {
        return False;
    }
    self.code += 1;
    return True;
}

impl validate_charset(code: ptr[u32], end: ptr[u32]) -> int {
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
            if 8 > cursor.end - cursor.code {
                return -1;
            }
            cursor.code += 8;
        } elif op == SRE_OP_BIGCHARSET {
            if not cursor.get_arg() {
                return -1;
            }
            if 64 > cursor.end - cursor.code {
                return -1;
            }
            table = ptr[u8](cursor.code);
            for i in range(256) {
                if u32((table + i).view(1)[0]) >= cursor.arg {
                    return -1;
                }
            }
            cursor.code += 64;
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

impl validate_inner(code: ptr[u32], end: ptr[u32], groups: i64) -> int {
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
            if not cursor.get_arg() {
                return -1;
            }
        } elif op == SRE_OP_SUCCESS or op == SRE_OP_FAILURE {
            continue;
        } elif op == SRE_OP_AT {
            if not cursor.get_arg() or cursor.arg > 11 {
                return -1;
            }
        } elif op == SRE_OP_ANY or op == SRE_OP_ANY_ALL {
            continue;
        } elif op == SRE_OP_IN
            or op == SRE_OP_IN_IGNORE
            or op == SRE_OP_IN_UNI_IGNORE
            or op == SRE_OP_IN_LOC_IGNORE {
            if not cursor.get_skip() {
                return -1;
            }
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
            if not cursor.get_arg() or i64(cursor.arg) >= groups {
                return -1;
            }
            if not cursor.get_skip(1) {
                return -1;
            }
            skip_count = int(cursor.skip_count);
            cursor.code -= 1;
            rc = validate_inner(
                cursor.code + 1, cursor.code + (skip_count - 1), groups
            );
            if rc == 1 {
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
            if not cursor.get_arg() {
                return -1;
            }
            cursor.code -= 1;
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

impl exceeds(count: i64, distance: i64) -> bool {
    return distance >= 0 and count > distance;
}

impl validate_info(cursor: CodeCursor) -> int {
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

    if (flags & ~(SRE_INFO_PREFIX | SRE_INFO_LITERAL | SRE_INFO_CHARSET)) != 0 {
        return -1;
    }

    if (flags & SRE_INFO_PREFIX) != 0 and (flags & SRE_INFO_CHARSET) != 0 {
        return -1;
    }

    if (flags & SRE_INFO_LITERAL) != 0 and (flags & SRE_INFO_PREFIX) == 0 {
        return -1;
    }

    if (flags & SRE_INFO_PREFIX) != 0 {
        if not cursor.get_arg() {
            return -1;
        }
        prefix_len = i64(cursor.arg);
        if not cursor.get_arg() {
            return -1;
        }

        if exceeds(prefix_len, newcode - cursor.code) {
            return -1;
        }
        cursor.code += prefix_len;

        if exceeds(prefix_len, newcode - cursor.code) {
            return -1;
        }

        for i in range(prefix_len) {
            if i64((cursor.code + i).view(1)[0]) >= prefix_len {
                return -1;
            }
        }
        cursor.code += prefix_len;
    }

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

impl validate_branch(cursor: CodeCursor, groups: i64) -> int {
    target = ptr[u32]();
    while True {
        if not cursor.get_skip() {
            return -1;
        }
        skip_count = int(cursor.skip_count);
        if skip_count == 0 {
            break;
        }

        if validate_inner(cursor.code, cursor.code + (skip_count - 3), groups) != 0 {
            return -1;
        }
        cursor.code += skip_count - 3;

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

impl validate_outer(code: ptr[u32], end: ptr[u32], groups: i64) -> int {
    if groups < 0
        or groups > SRE_MAXGROUPS
        or code >= end
        or (end - 1).view(1)[0] != u32(SRE_OP_SUCCESS) {
        return -1;
    }
    return validate_inner(code, end - 1, groups);
}

impl validate(self: ptr[PyObject]) -> bool {
    p = pattern_record(self).view(1);
    code = pattern_code(self);
    if validate_outer(code, code + p[0].codesize, p[0].groups) != 0 {
        PyErr_SetString(PyExc_RuntimeError, "invalid SRE code");
        return False;
    }
    return True;
}

impl match_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
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

impl match_clear(op: ptr[PyObject]) -> i32 {
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

impl match_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    match_clear(op);
    free_object(op);
}

impl match_getslice_by_index(
    self: ptr[PyObject], index: i64, default_value: ptr[PyObject]
) -> ptr[PyObject] {
    m = match_record(self).view(1);
    marks = match_marks(self);
    index *= 2;
    string = m[0].string;
    i = (marks + index).view(1)[0];
    if string == Py_None or i < 0 {
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

impl match_getindex(self: ptr[PyObject], index: ptr[PyObject]) -> i64 {
    if not index {
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
        if not PyErr_Occurred() {
            PyErr_SetString(PyExc_IndexError, "no such group");
        }
        return -1;
    }
    return i;
}

impl match_getslice(
    self: ptr[PyObject], index: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject] {
    i = match_getindex(self, index);
    if i < 0 {
        return NULL;
    }
    return match_getslice_by_index(self, i, default_value);
}

impl _sre_SRE_Match_expand_impl(
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

impl match_group(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    size = PyTuple_Size(args);
    if size == 0 {
        return match_getslice_by_index(self, 0, Py_None);
    }
    if size == 1 {
        return match_getslice(self, tuple_get_item(args, 0), Py_None);
    }

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

impl match_getitem(self: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    return match_getslice(self, name, Py_None);
}

impl _sre_SRE_Match_groups_impl(
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

impl _sre_SRE_Match_groupdict_impl(
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

impl _sre_SRE_Match_start_impl(self: ptr[PyObject], group: ptr[PyObject]) -> i64 {
    index = match_getindex(self, group);
    if index < 0 {
        return -1;
    }

    return (match_marks(self) + index * 2).view(1)[0];
}

impl _sre_SRE_Match_end_impl(self: ptr[PyObject], group: ptr[PyObject]) -> i64 {
    index = match_getindex(self, group);
    if index < 0 {
        return -1;
    }

    return (match_marks(self) + (index * 2 + 1)).view(1)[0];
}

impl pair(i1: i64, i2: i64) -> ptr[PyObject] {
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

impl _sre_SRE_Match_span_impl(
    self: ptr[PyObject], group: ptr[PyObject]
) -> ptr[PyObject] {
    index = match_getindex(self, group);
    if index < 0 {
        return NULL;
    }

    marks = match_marks(self);
    return pair((marks + index * 2).view(1)[0], (marks + (index * 2 + 1)).view(1)[0]);
}

impl match_regs(self: ptr[PyObject]) -> ptr[PyObject] {
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

impl _sre_SRE_Match___copy___impl(self: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(self);
}

impl _sre_SRE_Match___deepcopy___impl(
    self: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_NewRef(self);
}

impl match_lastindex_get(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    lastindex = match_record(op).view(1)[0].lastindex;
    if lastindex >= 0 {
        return PyLong_FromSsize_t(lastindex);
    }
    return Py_NewRef(Py_None);
}

impl match_lastgroup_get(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    m = match_record(op).view(1);
    indexgroup = pattern_record(m[0].pattern).view(1)[0].indexgroup;
    if indexgroup
        and m[0].lastindex >= 0
        and m[0].lastindex < PyTuple_Size(indexgroup) {
        return Py_NewRef(tuple_get_item(indexgroup, m[0].lastindex));
    }
    return Py_NewRef(Py_None);
}

impl match_regs_get(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    regs = match_record(op).view(1)[0].regs;
    if regs {
        return Py_NewRef(regs);
    }
    return match_regs(op);
}

impl match_repr(self: ptr[PyObject]) -> ptr[PyObject] {
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

impl pattern_new_match(
    match_type: ptr[PyObject], pattern: ptr[PyObject], state: ptr[SreState], status: i64
) -> ptr[PyObject] {
    if status > 0 {
        groups = pattern_record(pattern).view(1)[0].groups;

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

                if first > last {
                    PyErr_SetString(
                        PyExc_SystemError,
                        "The span of capturing group is wrong, please report a bug for the re module."
                    );
                    jacpy_release(match_object);
                    return NULL;
                }
            } else {
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
        return Py_NewRef(Py_None);
    }

    pattern_error(status);
    return NULL;
}

impl scanner_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    result = visit_one(type_object(op), visitor, context);
    if result != 0 {
        return result;
    }
    return visit_one(scanner_record(op).view(1)[0].pattern, visitor, context);
}

impl scanner_clear(op: ptr[PyObject]) -> i32 {
    s = scanner_record(op).view(1);
    pattern = s[0].pattern;
    s[0].pattern = NULL;
    jacpy_release(pattern);
    return i32(0);
}

impl scanner_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    state_fini(scanner_state(op), False);
    scanner_clear(op);
    free_object(op);
}

impl scanner_begin(self: ptr[PyObject]) -> bool {
    s = scanner_record(self).view(1);
    was_executing = s[0].executing;
    s[0].executing = 1;
    if was_executing != 0 {
        PyErr_SetString(
            PyExc_ValueError, "regular expression scanner already executing"
        );
        return False;
    }
    return True;
}

impl scanner_end(self: ptr[PyObject]) {
    scanner_record(self).view(1)[0].executing = 0;
}

impl scanner_next(
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

impl _sre_SRE_Scanner_match_impl(
    self: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return scanner_next(self, cls, False);
}

impl _sre_SRE_Scanner_search_impl(
    self: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return scanner_next(self, cls, True);
}

impl pattern_scanner(
    scanner_type: ptr[PyObject],
    self: ptr[PyObject],
    string: ptr[PyObject],
    pos: i64,
    endpos: i64
) -> ptr[PyObject] {
    scanner = _PyObject_GC_New(scanner_type);
    if not scanner {
        return NULL;
    }
    s = scanner_record(scanner).view(1);
    s[0].pattern = NULL;
    s[0].executing = 0;

    if not state_init(scanner_state(scanner), self, string, pos, endpos, False) {
        memset(scanner_state(scanner), 0, u64(SRE_STATE_SIZE));
        jacpy_release(scanner);
        return NULL;
    }
    s[0].pattern = Py_NewRef(self);
    PyObject_GC_Track(scanner);
    return scanner;
}

impl template_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
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

impl template_clear(op: ptr[PyObject]) -> i32 {
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

impl template_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    template_clear(op);
    free_object(op);
}

impl expand_template(
    self: ptr[PyObject], match_object: ptr[PyObject]
) -> ptr[PyObject] {
    t = template_record(self).view(1);
    size = object_size(self);
    if size == 0 {
        return Py_NewRef(t[0].literal);
    }
    unicode = jacpy_is_unicode(t[0].literal) != 0;

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

impl visit_one(value: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return visit_reference(value, visitor, context);
}
