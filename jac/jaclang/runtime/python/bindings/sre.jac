"""The _sre module's definition: Modules/_sre/sre.c's type specs and tables.

The Pattern, Match, Scanner and Template types are heap types made from C
data specs, as sre.c makes them, with the member, getter and slot tables of
the C module; the Pattern and Scanner specs are their types' tokens, which
the clinic glue's defining_class finds. Methods take their arguments
through the generated clinic glue, and Match.group through a METH_VARARGS
callback as in the C. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyLong_FromUnsignedLong,
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

# --------------------------------------------------------- method tables

def:priv class_getitem(doc: str) -> MethodDefinition {
    return MethodDefinition(
        "__class_getitem__",
        MethodCallbacks(positional=Py_GenericAlias),
        doc,
        i64(METH_O | METH_CLASS)
    );
}

def:priv pattern_methods -> ptr[PyMethodDef] {
    methods = list(SRE_Pattern_methods);
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
    methods.extend(SRE_Match_methods);
    methods.append(
        class_getitem(
            "Matches are generic over the type of string which was matched (str or bytes)"
        )
    );
    return method_table(methods);
}

def:priv scanner_methods -> ptr[PyMethodDef] {
    return method_table(SRE_Scanner_methods);
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
