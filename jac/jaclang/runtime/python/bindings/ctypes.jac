def:pub PyInit__ctypes -> ptr[PyObject];

def:priv c_names_equal(left: ptr[u8], right: ptr[u8]) -> bool;

def:priv select_methods(
    table: list[MethodDefinition], names: list[str]
) -> list[MethodDefinition];

def:priv type_name_or_none(value: ptr[PyObject]) -> ptr[u8];

def:priv PyCData_setstate(
    myself: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv fill_slot(slots: ptr[PyType_Slot], index: int, table: ptr);

def:priv install_module_methods -> bool;

def:priv install_clinic_tables -> bool;

impl PyInit__ctypes -> ptr[PyObject] {
    definition = addressof(_ctypesmodule).view(1);
    if int(definition[0].m_free) == 0 {
        if not install_clinic_tables() {
            return NULL;
        }
        definition[0].m_traverse = int(ptr(module_traverse));
        definition[0].m_clear = int(ptr(module_clear));
        definition[0].m_free = int(ptr(module_free));
    }
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(_ctypesmodule)));
}

impl c_names_equal(left: ptr[u8], right: ptr[u8]) -> bool {
    index = 0;
    while True {
        a = (left + index).view(1)[0];
        b = (right + index).view(1)[0];
        if a != b {
            return False;
        }
        if a == 0 {
            return True;
        }
        index += 1;
    }
    return False;
}

impl select_methods(
    table: list[MethodDefinition], names: list[str]
) -> list[MethodDefinition] {
    selected: list[MethodDefinition] = [];
    for name in names {
        for method in table {
            if method.name == name {
                selected.append(method);
                break;
            }
        }
    }
    return selected;
}

impl type_name_or_none(value: ptr[PyObject]) -> ptr[u8] {
    if value == Py_None {
        return ptr[u8]("None");
    }
    return object_type(value).view(1)[0].tp_name;
}

impl PyCData_setstate(
    myself: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs != 2 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("__setstate__() takes exactly 2 arguments (%zd given)"),
            nargs
        );
        return NULL;
    }
    dct = args.view(2)[0];
    if not dict_check(dct) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("__setstate__() argument 1 must be dict, not %.50s"),
            type_name_or_none(dct)
        );
        return NULL;
    }
    arg = args.view(2)[1];
    data = ptr[u8]();
    data_length: i64 = 0;
    if unicode_check(arg) {
        data = PyUnicode_AsUTF8AndSize(arg, &mut data_length);
        if not data {
            return NULL;
        }
    } else {
        procs = object_type(arg).view(1)[0].tp_as_buffer;
        if procs and int(procs.view(1)[0].bf_releasebuffer) != 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "__setstate__() argument 2 must be read-only bytes-like object, not %.50s"
                ),
                type_name_or_none(arg)
            );
            return NULL;
        }
        view = ptr[Py_buffer](PyMem_Calloc(1, 80));
        if not view {
            PyErr_NoMemory();
            return NULL;
        }
        if PyObject_GetBuffer(arg, view, PyBUF_SIMPLE) != 0 {
            PyMem_Free(ptr(view));
            return NULL;
        }
        data = ptr[u8](view.view(1)[0].buf);
        data_length = view.view(1)[0].length;
        PyBuffer_Release(view);
        PyMem_Free(ptr(view));
    }
    return _ctypes_PyCData___setstate___impl(myself, dct, data, data_length);
}

impl fill_slot(slots: ptr[PyType_Slot], index: int, table: ptr) {
    (slots + index).view(1)[0].pfunc = table;
}

impl install_module_methods -> bool {
    clinic = method_table(module_methods);
    if not clinic {
        return False;
    }
    rows = addressof(_ctypes_module_methods);
    index = 0;
    while (rows + index).view(1)[0].ml_name {
        row = (rows + index).view(1);
        if not row[0].ml_meth {
            found = 0;
            while (clinic + found).view(1)[0].ml_name {
                if c_names_equal((clinic + found).view(1)[0].ml_name, row[0].ml_name) {
                    row[0].ml_meth = (clinic + found).view(1)[0].ml_meth;
                    row[0].ml_flags = (clinic + found).view(1)[0].ml_flags;
                    row[0].ml_doc = (clinic + found).view(1)[0].ml_doc;
                    break;
                }
                found += 1;
            }
        }
        if not HAS_DYLD_SHARED_CACHE
            and c_names_equal(
                row[0].ml_name, ptr[u8]("_dyld_shared_cache_contains_path")
            ) {
            row[0].ml_name = ptr[u8]();
            row[0].ml_meth = ptr();
            row[0].ml_flags = 0;
            row[0].ml_doc = ptr[u8]();
            break;
        }
        index += 1;
    }
    return True;
}

impl install_clinic_tables -> bool {
    set_class_tokens();
    from_address_to_in_dll = [
        "from_address",
        "from_buffer",
        "from_buffer_copy",
        "in_dll"
    ];
    ctype_methods = method_table(CType_Type_methods);
    cdatatype_methods = method_table(
        select_methods(
            CDataType_methods,
            ["from_param", "from_address", "from_buffer", "from_buffer_copy", "in_dll"]
        )
    );
    pointer_methods = select_methods(CDataType_methods, from_address_to_in_dll);
    pointer_methods.extend(
        select_methods(PyCPointerType_methods, ["from_param", "set_type"])
    );
    pycpointertype_methods = method_table(pointer_methods);
    simple_methods = select_methods(PyCSimpleType_methods, ["from_param"]);
    simple_methods.extend(select_methods(CDataType_methods, from_address_to_in_dll));
    pycsimpletype_methods = method_table(simple_methods);
    cdata_methods = select_methods(PyCData_methods, ["__ctypes_from_outparam__"]);
    cdata_methods.append(
        MethodDefinition(
            "__setstate__",
            MethodCallbacks(fast=PyCData_setstate),
            "__setstate__($self, dict, data, /)\n--\n\n",
            i64(METH_FASTCALL)
        )
    );
    cdata_methods.extend(select_methods(PyCData_methods, ["__reduce__"]));
    pycdata_methods = method_table(cdata_methods);
    simple_instance_methods = method_table(Simple_methods);
    funcptr_getsets = getset_table(CFuncPtr_getset);
    simple_getsets = getset_table(Simple_getset);
    chararray_getsets = getset_table(PyCArrayType_Type_getset);
    void_p_methods = method_table(c_void_p_methods);
    char_p_methods = method_table(c_char_p_methods);
    wchar_p_methods = method_table(c_wchar_p_methods);
    if not ctype_methods
        or not cdatatype_methods
        or not pycpointertype_methods
        or not pycsimpletype_methods
        or not pycdata_methods
        or not simple_instance_methods
        or not funcptr_getsets
        or not simple_getsets
        or not chararray_getsets
        or not void_p_methods
        or not char_p_methods
        or not wchar_p_methods {
        return False;
    }
    if not install_module_methods() {
        return False;
    }
    fill_slot(addressof(pyctype_type_slots), 0, ptr(ctype_methods));
    fill_slot(addressof(pycstruct_type_slots), 0, ptr(cdatatype_methods));
    fill_slot(addressof(union_type_slots), 0, ptr(cdatatype_methods));
    fill_slot(addressof(pycarray_type_slots), 0, ptr(cdatatype_methods));
    fill_slot(addressof(pycfuncptr_type_slots), 0, ptr(cdatatype_methods));
    fill_slot(addressof(pycpointer_type_slots), 0, ptr(pycpointertype_methods));
    fill_slot(addressof(pycsimple_type_slots), 0, ptr(pycsimpletype_methods));
    fill_slot(addressof(pycdata_slots), 0, ptr(pycdata_methods));
    fill_slot(addressof(pycfuncptr_slots), 0, ptr(funcptr_getsets));
    fill_slot(addressof(pycsimple_slots), 0, ptr(simple_instance_methods));
    fill_slot(addressof(pycsimple_slots), 1, ptr(simple_getsets));
    tables = addressof(ctypes_clinic_tables).view(1);
    tables[0].c_void_p_methods = void_p_methods;
    tables[0].c_char_p_methods = char_p_methods;
    tables[0].c_wchar_p_methods = wchar_p_methods;
    tables[0].CharArray_getsets = chararray_getsets;
    return True;
}
