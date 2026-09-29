"""The _sre module's definition: Modules/_sre/sre.c's type specs and tables.

The Pattern, Match, Scanner and Template types are heap types made from C
data specs, as sre.c makes them, with the member, getter and slot tables of
the C module; the Pattern and Scanner specs are their types' tokens, which
the clinic glue's defining_class finds. Methods take their arguments the
Argument Clinic way. The calls a regular expression makes most (Pattern.match_object,
search, fullmatch, findall, finditer, sub, subn and split, the Match group
accessors and the scanner steps) bind their positional arguments directly;
a call with keywords or with arguments that need conversion goes through the
generated glue, so its errors are the C module's. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Occurred,
    PyLong_AsSsize_t,
    PyLong_FromSsize_t,
    PyLong_FromUnsignedLong,
    PyLong_Type,
    PyMemberDef,
    PyMethodDef,
    PyModule_Add,
    PyModule_AddIntConstant,
    PyModule_AddStringConstant,
    PyObject,
    PyType_FromModuleAndSpec,
    PyType_Slot,
    PyType_Spec,
    Py_None,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_CLASS,
    METH_O,
    METH_VARARGS,
    PyGetSetDef,
    PyTypeObject,
    Py_READONLY,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_DISALLOW_INSTANTIATION,
    Py_TPFLAGS_HAVE_GC,
    Py_TPFLAGS_IMMUTABLETYPE,
    Py_T_INT,
    Py_T_PYSSIZET,
    Py_mp_subscript,
    Py_tp_clear,
    Py_tp_dealloc,
    Py_tp_doc,
    Py_tp_getset,
    Py_tp_hash,
    Py_tp_members,
    Py_tp_methods,
    Py_tp_repr,
    Py_tp_richcompare,
    Py_tp_token,
    Py_tp_traverse,
    _Py_T_OBJECT
}
import from jaclang.runtime.python.object_model.header { object_type }
import from jaclang.runtime.python.object_model.genericalias { Py_GenericAlias }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    jacpy_binding_state_set,
    method_table
}
import from jaclang.runtime.python.bindings.clinic.sre {
    SRE_Match_methods,
    SRE_Pattern_methods,
    SRE_Scanner_methods,
    module_methods
}
import from jaclang.runtime.python.modules.sre_constants { SRE_MAGIC }
import from jaclang.runtime.python.modules.sre_engine { SRE_MAXREPEAT }
import from jaclang.runtime.python.modules.sre {
    COPYRIGHT,
    MATCH_ENDPOS,
    MATCH_PATTERN,
    MATCH_POS,
    MATCH_SIZE,
    MATCH_STRING,
    PATTERN_FLAGS,
    PATTERN_GROUPS,
    PATTERN_PATTERN,
    PATTERN_SIZE,
    PATTERN_WEAKREFLIST,
    PY_SSIZE_T_MAX,
    SCANNER_PATTERN,
    SCANNER_SIZE,
    SRE_CODE_SIZE,
    SRE_MAXGROUPS,
    SRE_Pattern_token,
    SRE_Scanner_token,
    STATE_COUNT,
    STATE_MATCH_TYPE,
    STATE_PATTERN_TYPE,
    STATE_SCANNER_TYPE,
    STATE_TEMPLATE_TYPE,
    TEMPLATE_ITEM_SIZE,
    TEMPLATE_SIZE,
    _sre_SRE_Match_end_impl,
    _sre_SRE_Match_groupdict_impl,
    _sre_SRE_Match_groups_impl,
    _sre_SRE_Match_span_impl,
    _sre_SRE_Match_start_impl,
    _sre_SRE_Pattern_findall_impl,
    _sre_SRE_Pattern_finditer_impl,
    _sre_SRE_Pattern_fullmatch_impl,
    _sre_SRE_Pattern_match_impl,
    _sre_SRE_Pattern_scanner_impl,
    _sre_SRE_Pattern_search_impl,
    _sre_SRE_Pattern_split_impl,
    _sre_SRE_Pattern_sub_impl,
    _sre_SRE_Pattern_subn_impl,
    _sre_SRE_Scanner_match_impl,
    _sre_SRE_Scanner_search_impl,
    match_dealloc,
    match_getitem,
    match_group,
    match_lastgroup_get,
    match_lastindex_get,
    match_regs_get,
    match_repr,
    match_clear,
    match_traverse,
    pattern_clear,
    pattern_dealloc,
    pattern_groupindex,
    pattern_hash,
    pattern_repr,
    pattern_richcompare,
    pattern_traverse,
    scanner_clear,
    scanner_dealloc,
    scanner_traverse,
    template_clear,
    template_dealloc,
    template_traverse
}

# -------------------------------------------------------- the fast calls

import from c {
    # A METH_FASTCALL | METH_KEYWORDS callback, and a METH_FASTCALL one.
    obj KeywordCall {
        has call:
            Callable[
                [ptr[PyObject], ptr[ptr[PyObject]], i64, ptr[PyObject]],
                ptr[PyObject]
            ] = 0;
    }  obj VectorCall {
        has call: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0;
    }
    # The generated glue of the methods below, by the SLOW_* index: the
    # path of a call the fast binding does not take.
    glob:priv slow_keywords: list[KeywordCall] = [
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall(),
             KeywordCall()
         ],
         slow_vector: list[VectorCall] = [VectorCall(), VectorCall(), VectorCall()];
}

glob:priv SLOW_MATCH: Final[int] = 0,
     SLOW_FULLMATCH: Final[int] = 1,
     SLOW_SEARCH: Final[int] = 2,
     SLOW_FINDALL: Final[int] = 3,
     SLOW_FINDITER: Final[int] = 4,
     SLOW_SCANNER: Final[int] = 5,
     SLOW_SPLIT: Final[int] = 6,
     SLOW_SUB: Final[int] = 7,
     SLOW_SUBN: Final[int] = 8,
     SLOW_GROUPS: Final[int] = 9,
     SLOW_GROUPDICT: Final[int] = 10,
     SLOW_SCANNER_MATCH: Final[int] = 11,
     SLOW_SCANNER_SEARCH: Final[int] = 12,
     SLOW_START: Final[int] = 0,
     SLOW_END: Final[int] = 1,
     SLOW_SPAN: Final[int] = 2;

def:priv slow_keyword_call(
    index: int,
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    record: ptr[KeywordCall] = addressof(slow_keywords) + index;
    return record.view(1)[0].call(receiver, args, nargs, kwnames);
}

def:priv slow_vector_call(
    index: int, receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    record: ptr[VectorCall] = addressof(slow_vector) + index;
    return record.view(1)[0].call(receiver, args, nargs);
}

# args[index]
def:priv argument(args: ptr[ptr[PyObject]], index: int) -> ptr[PyObject] {
    return (args + index).view(1)[0];
}

# An argument the Py_ssize_t converter takes without calling back into
# Python: an exact int.
def:priv plain_int(value: ptr[PyObject]) -> bool {
    return object_type(value) == ptr[PyTypeObject](addressof(PyLong_Type));
}

# Whether the optional Py_ssize_t arguments from `first` bind directly.
def:priv direct_ints(
    args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject], first: int
) -> bool {
    if kwnames {
        return False;
    }
    for index in range(first, int(nargs)) {
        if not plain_int(argument(args, index)) {
            return False;
        }
    }
    return True;
}

# An optional Py_ssize_t argument (an exact int); `default` when absent.
# -1 with the exception set on overflow, as the converter fails.
def:priv ssize_argument(
    args: ptr[ptr[PyObject]], nargs: i64, index: int, default_value: i64
) -> i64 {
    if nargs <= index {
        return default_value;
    }
    return PyLong_AsSsize_t(argument(args, index));
}

def:priv failed -> bool {
    return not PyErr_Occurred().is_null();
}

# (string, pos=0, endpos=sys.maxsize) methods of Pattern, by SLOW_* index.
def:priv pattern_string_call(
    kind: int,
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs < 1 or nargs > 3 or not direct_ints(args, nargs, kwnames, 1) {
        return slow_keyword_call(kind, receiver, args, nargs, kwnames);
    }
    pos = ssize_argument(args, nargs, 1, 0);
    if pos == -1 and failed() {
        return NULL;
    }
    endpos = ssize_argument(args, nargs, 2, PY_SSIZE_T_MAX);
    if endpos == -1 and failed() {
        return NULL;
    }
    string = argument(args, 0);
    # A Pattern is not subclassable, so its type is the defining class.
    cls = ptr[PyObject](object_type(receiver));
    if kind == SLOW_MATCH {
        return _sre_SRE_Pattern_match_impl(receiver, cls, string, pos, endpos);
    }
    if kind == SLOW_FULLMATCH {
        return _sre_SRE_Pattern_fullmatch_impl(receiver, cls, string, pos, endpos);
    }
    if kind == SLOW_SEARCH {
        return _sre_SRE_Pattern_search_impl(receiver, cls, string, pos, endpos);
    }
    if kind == SLOW_FINDALL {
        return _sre_SRE_Pattern_findall_impl(receiver, string, pos, endpos);
    }
    if kind == SLOW_FINDITER {
        return _sre_SRE_Pattern_finditer_impl(receiver, cls, string, pos, endpos);
    }
    return _sre_SRE_Pattern_scanner_impl(receiver, cls, string, pos, endpos);
}

def:priv pattern_match_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return pattern_string_call(SLOW_MATCH, receiver, args, nargs, kwnames);
}

def:priv pattern_fullmatch_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return pattern_string_call(SLOW_FULLMATCH, receiver, args, nargs, kwnames);
}

def:priv pattern_search_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return pattern_string_call(SLOW_SEARCH, receiver, args, nargs, kwnames);
}

def:priv pattern_findall_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return pattern_string_call(SLOW_FINDALL, receiver, args, nargs, kwnames);
}

def:priv pattern_finditer_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return pattern_string_call(SLOW_FINDITER, receiver, args, nargs, kwnames);
}

def:priv pattern_scanner_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return pattern_string_call(SLOW_SCANNER, receiver, args, nargs, kwnames);
}

# split(string, maxsplit=0)
def:priv pattern_split_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs < 1 or nargs > 2 or not direct_ints(args, nargs, kwnames, 1) {
        return slow_keyword_call(SLOW_SPLIT, receiver, args, nargs, kwnames);
    }
    maxsplit = ssize_argument(args, nargs, 1, 0);
    if maxsplit == -1 and failed() {
        return NULL;
    }
    return _sre_SRE_Pattern_split_impl(receiver, argument(args, 0), maxsplit);
}

# sub(repl, string, count=0) and subn()
def:priv pattern_sub_call(
    subn: bool,
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs < 2 or nargs > 3 or not direct_ints(args, nargs, kwnames, 2) {
        return slow_keyword_call(
            SLOW_SUBN if subn else SLOW_SUB, receiver, args, nargs, kwnames
        );
    }
    count = ssize_argument(args, nargs, 2, 0);
    if count == -1 and failed() {
        return NULL;
    }
    cls = ptr[PyObject](object_type(receiver));
    if subn {
        return _sre_SRE_Pattern_subn_impl(
            receiver, cls, argument(args, 0), argument(args, 1), count
        );
    }
    return _sre_SRE_Pattern_sub_impl(
        receiver, cls, argument(args, 0), argument(args, 1), count
    );
}

def:priv pattern_sub_fast(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return pattern_sub_call(False, receiver, args, nargs, kwnames);
}

def:priv pattern_subn_fast(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return pattern_sub_call(True, receiver, args, nargs, kwnames);
}

# Match.groups(default=None) and groupdict(default=None)
def:priv match_groups_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames or nargs > 1 {
        return slow_keyword_call(SLOW_GROUPS, receiver, args, nargs, kwnames);
    }
    default_value = argument(args, 0) if nargs == 1 else Py_None;
    return _sre_SRE_Match_groups_impl(receiver, default_value);
}

def:priv match_groupdict_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames or nargs > 1 {
        return slow_keyword_call(SLOW_GROUPDICT, receiver, args, nargs, kwnames);
    }
    default_value = argument(args, 0) if nargs == 1 else Py_None;
    return _sre_SRE_Match_groupdict_impl(receiver, default_value);
}

# Match.start(group=0, /), end() and span()
def:priv match_start_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 {
        return slow_vector_call(SLOW_START, receiver, args, nargs);
    }
    value = _sre_SRE_Match_start_impl(
        receiver, argument(args, 0) if nargs == 1 else NULL
    );
    if value == -1 and failed() {
        return NULL;
    }
    return PyLong_FromSsize_t(value);
}

def:priv match_end_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 {
        return slow_vector_call(SLOW_END, receiver, args, nargs);
    }
    value = _sre_SRE_Match_end_impl(
        receiver, argument(args, 0) if nargs == 1 else NULL
    );
    if value == -1 and failed() {
        return NULL;
    }
    return PyLong_FromSsize_t(value);
}

def:priv match_span_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 {
        return slow_vector_call(SLOW_SPAN, receiver, args, nargs);
    }
    return _sre_SRE_Match_span_impl(
        receiver, argument(args, 0) if nargs == 1 else NULL
    );
}

# Scanner.match() and search()
def:priv scanner_match_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames or nargs != 0 {
        return slow_keyword_call(SLOW_SCANNER_MATCH, receiver, args, nargs, kwnames);
    }
    return _sre_SRE_Scanner_match_impl(receiver, ptr[PyObject](object_type(receiver)));
}

def:priv scanner_search_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames or nargs != 0 {
        return slow_keyword_call(SLOW_SCANNER_SEARCH, receiver, args, nargs, kwnames);
    }
    return _sre_SRE_Scanner_search_impl(receiver, ptr[PyObject](object_type(receiver)));
}

# --------------------------------------------------------- method tables

# `definitions` with the direct callbacks of `direct` (name -> callbacks),
# whose generated glue each goes to the slow slot `fallback[name]` names.
def:priv bind_methods(
    definitions: list[MethodDefinition],
    direct: dict[str, MethodCallbacks],
    fallback: dict[str, int]
) -> list[MethodDefinition] {
    bound: list[MethodDefinition] = [];
    for definition in definitions {
        if definition.name in direct {
            index = fallback[definition.name];
            if definition.callbacks.fast_keywords {
                record: ptr[KeywordCall] = addressof(slow_keywords) + index;
                record.view(1)[0].call = definition.callbacks.fast_keywords;
            } else {
                vector: ptr[VectorCall] = addressof(slow_vector) + index;
                vector.view(1)[0].call = definition.callbacks.fast;
            }
            bound.append(
                MethodDefinition(
                    definition.name,
                    direct[definition.name],
                    definition.doc,
                    definition.flags
                )
            );
        } else {
            bound.append(definition);
        }
    }
    return bound;
}

def:priv class_getitem(doc: str) -> MethodDefinition {
    return MethodDefinition(
        "__class_getitem__",
        MethodCallbacks(positional=Py_GenericAlias),
        doc,
        i64(METH_O | METH_CLASS)
    );
}

def:priv pattern_methods -> ptr[PyMethodDef] {
    methods = bind_methods(
        SRE_Pattern_methods,
        {
            "match": MethodCallbacks(fast_keywords=pattern_match_call),
            "fullmatch": MethodCallbacks(fast_keywords=pattern_fullmatch_call),
            "search": MethodCallbacks(fast_keywords=pattern_search_call),
            "sub": MethodCallbacks(fast_keywords=pattern_sub_fast),
            "subn": MethodCallbacks(fast_keywords=pattern_subn_fast),
            "findall": MethodCallbacks(fast_keywords=pattern_findall_call),
            "split": MethodCallbacks(fast_keywords=pattern_split_call),
            "finditer": MethodCallbacks(fast_keywords=pattern_finditer_call),
            "scanner": MethodCallbacks(fast_keywords=pattern_scanner_call)
        },
        {
            "match": SLOW_MATCH,
            "fullmatch": SLOW_FULLMATCH,
            "search": SLOW_SEARCH,
            "sub": SLOW_SUB,
            "subn": SLOW_SUBN,
            "findall": SLOW_FINDALL,
            "split": SLOW_SPLIT,
            "finditer": SLOW_FINDITER,
            "scanner": SLOW_SCANNER
        }
    );
    methods.append(
        class_getitem(
            "Patterns are generic over the type of string they handle (str or bytes)"
        )
    );
    return method_table(methods);
}

def:priv match_methods -> ptr[PyMethodDef] {
    methods = [
        MethodDefinition(
            "group",
            MethodCallbacks(positional=match_group),
            "group([group1, ...]) -> str or tuple.\n    Return subgroup(s) of the match by indices or names.\n    For 0 returns the entire match.",
            i64(METH_VARARGS)
        )
    ];
    methods.extend(
        bind_methods(
            SRE_Match_methods,
            {
                "start": MethodCallbacks(fast=match_start_call),
                "end": MethodCallbacks(fast=match_end_call),
                "span": MethodCallbacks(fast=match_span_call),
                "groups": MethodCallbacks(fast_keywords=match_groups_call),
                "groupdict": MethodCallbacks(fast_keywords=match_groupdict_call)
            },
            {
                "start": SLOW_START,
                "end": SLOW_END,
                "span": SLOW_SPAN,
                "groups": SLOW_GROUPS,
                "groupdict": SLOW_GROUPDICT
            }
        )
    );
    methods.append(
        class_getitem(
            "Matches are generic over the type of string which was matched (str or bytes)"
        )
    );
    return method_table(methods);
}

def:priv scanner_methods -> ptr[PyMethodDef] {
    return method_table(
        bind_methods(
            SRE_Scanner_methods,
            {
                "match": MethodCallbacks(fast_keywords=scanner_match_call),
                "search": MethodCallbacks(fast_keywords=scanner_search_call)
            },
            {"match": SLOW_SCANNER_MATCH, "search": SLOW_SCANNER_SEARCH}
        )
    );
}

# ------------------------------------------------------------- the types

import from c {
    glob:priv pattern_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("pattern"),
                 type_=_Py_T_OBJECT,
                 offset=PATTERN_PATTERN,
                 flags=Py_READONLY,
                 doc=ptr[u8](
                     "The pattern string from which the RE object was compiled."
                 )
             ),
             PyMemberDef(
                 name=ptr[u8]("flags"),
                 type_=Py_T_INT,
                 offset=PATTERN_FLAGS,
                 flags=Py_READONLY,
                 doc=ptr[u8]("The regex matching flags.")
             ),
             PyMemberDef(
                 name=ptr[u8]("groups"),
                 type_=Py_T_PYSSIZET,
                 offset=PATTERN_GROUPS,
                 flags=Py_READONLY,
                 doc=ptr[u8]("The number of capturing groups in the pattern.")
             ),
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=PATTERN_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         pattern_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("groupindex"),
                 get=pattern_groupindex,
                 doc=ptr[u8]("A dictionary mapping group names to group numbers.")
             ),
             PyGetSetDef()
         ],
         pattern_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(pattern_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(pattern_repr)),
             PyType_Slot(slot=Py_tp_hash, pfunc=ptr(pattern_hash)),
             PyType_Slot(
                 slot=Py_tp_doc, pfunc=ptr[u8]("Compiled regular expression object.")
             ),
             PyType_Slot(slot=Py_tp_richcompare, pfunc=ptr(pattern_richcompare)),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(pattern_members))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(pattern_getset))),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(pattern_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(pattern_clear)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob pattern_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("re.Pattern"),
             basicsize=i32(PATTERN_SIZE),
             itemsize=i32(SRE_CODE_SIZE),
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
                     | Py_TPFLAGS_HAVE_GC
             ),
             slots=addressof(pattern_slots)
         ); glob:priv match_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("string"),
                 type_=_Py_T_OBJECT,
                 offset=MATCH_STRING,
                 flags=Py_READONLY,
                 doc=ptr[u8]("The string passed to match() or search().")
             ),
             PyMemberDef(
                 name=ptr[u8]("re"),
                 type_=_Py_T_OBJECT,
                 offset=MATCH_PATTERN,
                 flags=Py_READONLY,
                 doc=ptr[u8]("The regular expression object.")
             ),
             PyMemberDef(
                 name=ptr[u8]("pos"),
                 type_=Py_T_PYSSIZET,
                 offset=MATCH_POS,
                 flags=Py_READONLY,
                 doc=ptr[u8](
                     "The index into the string at which the RE engine started looking for a match."
                 )
             ),
             PyMemberDef(
                 name=ptr[u8]("endpos"),
                 type_=Py_T_PYSSIZET,
                 offset=MATCH_ENDPOS,
                 flags=Py_READONLY,
                 doc=ptr[u8](
                     "The index into the string beyond which the RE engine will not go."
                 )
             ),
             PyMemberDef()
         ],
         match_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("lastindex"),
                 get=match_lastindex_get,
                 doc=ptr[u8]("The integer index of the last matched capturing group.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("lastgroup"),
                 get=match_lastgroup_get,
                 doc=ptr[u8]("The name of the last matched capturing group.")
             ),
             PyGetSetDef(name=ptr[u8]("regs"), get=match_regs_get),
             PyGetSetDef()
         ],
         match_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(match_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(match_repr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "The result of re.match() and re.search().\nMatch objects always have a boolean value of True."
                 )
             ),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(match_members))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(match_getset))),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(match_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(match_clear)),
             # As mapping. Match objects do not support length or
             # assignment, but do support __getitem__.
             PyType_Slot(slot=Py_mp_subscript, pfunc=ptr(match_getitem)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob match_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("re.Match"),
             basicsize=i32(MATCH_SIZE),
             itemsize=8,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
                     | Py_TPFLAGS_HAVE_GC
             ),
             slots=addressof(match_slots)
         ); glob:priv scanner_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("pattern"),
                 type_=_Py_T_OBJECT,
                 offset=SCANNER_PATTERN,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         scanner_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(scanner_dealloc)),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(scanner_members))),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(scanner_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(scanner_clear)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob scanner_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_sre.SRE_Scanner"),
             basicsize=i32(SCANNER_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
                     | Py_TPFLAGS_HAVE_GC
             ),
             slots=addressof(scanner_slots)
         ); glob:priv template_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(template_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(template_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(template_clear)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob template_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_sre.SRE_Template"),
             basicsize=i32(TEMPLATE_SIZE),
             itemsize=i32(TEMPLATE_ITEM_SIZE),
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
                     | Py_TPFLAGS_HAVE_GC
             ),
             slots=addressof(template_slots)
         );
}

# Fill the method slots (the first slot of each table) once: the tables,
# clinic glue included, live for the process as static ones do. False with
# the exception set.
def:priv install_method_tables -> bool {
    slots: list[ptr[PyType_Slot]] = [
        addressof(pattern_slots),
        addressof(match_slots),
        addressof(scanner_slots)
    ];
    if slots[0].view(1)[0].pfunc {
        return True;
    }
    tables = [pattern_methods(), match_methods(), scanner_methods()];
    for index in range(3) {
        if not tables[index] {
            return False;
        }
        slots[index].view(1)[0].pfunc = ptr(tables[index]);
    }
    return True;
}

# CREATE_TYPE: the type of `spec` into state slot `slot`.
def:priv create_type(module: ptr[PyObject], spec: ptr[PyType_Spec], slot: int) -> bool {
    type = PyType_FromModuleAndSpec(module, spec, NULL);
    if not type {
        return False;
    }
    jacpy_binding_state_set(module, i64(slot), type);
    jacpy_release(type);
    return True;
}

def:priv sre_exec(module: ptr[PyObject]) -> i32 {
    if not install_method_tables() {
        return i32(-1);
    }
    # Create heap types
    if not create_type(module, addressof(pattern_spec), STATE_PATTERN_TYPE)
        or not create_type(module, addressof(match_spec), STATE_MATCH_TYPE)
        or not create_type(module, addressof(scanner_spec), STATE_SCANNER_TYPE)
        or not create_type(module, addressof(template_spec), STATE_TEMPLATE_TYPE) {
        return i32(-1);
    }
    SRE_Pattern_token.handle = ptr(addressof(pattern_spec));
    SRE_Scanner_token.handle = ptr(addressof(scanner_spec));
    if PyModule_AddIntConstant(module, "MAGIC", SRE_MAGIC) < 0
        or PyModule_AddIntConstant(module, "CODESIZE", SRE_CODE_SIZE) < 0
        or PyModule_Add(
            module, "MAXREPEAT", PyLong_FromUnsignedLong(u64(SRE_MAXREPEAT))
        )
            < 0
        or PyModule_Add(
            module, "MAXGROUPS", PyLong_FromUnsignedLong(u64(SRE_MAXGROUPS))
        )
            < 0
        or PyModule_AddStringConstant(module, "copyright", COPYRIGHT) < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob sre_definition = ModuleDefinition(
         "_sre", "", module_methods, ModuleHooks(execute=sre_exec), STATE_COUNT
     );

def:pub PyInit__sre -> ptr[PyObject] {
    return sre_definition.initialize();
}
