import from c {
    def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  obj StgdictArgs {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject](),
            s5: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut StgdictArgs) -> int;  def PyCStgInfo_clone(
        dst_info: ptr[StgInfo], src_info: ptr[StgInfo]
    ) -> i32 {
        ctype_free_stginfo_members(dst_info);

        memcpy(ptr(dst_info), ptr(src_info), u64(SIZEOF_STGINFO));
        dst_info.view(1)[0].dict_final = 0;

        object_xincref(dst_info.view(1)[0].proto);
        object_xincref(dst_info.view(1)[0].argtypes);
        object_xincref(dst_info.view(1)[0].converters);
        object_xincref(dst_info.view(1)[0].restype);
        object_xincref(dst_info.view(1)[0].checker);
        object_xincref(dst_info.view(1)[0].module);

        dst_info.view(1)[0].pointer_type = NULL;

        if src_info.view(1)[0].format_ {
            dst_info.view(1)[0].format_ = ptr[u8](
                PyMem_Malloc(strlen(src_info.view(1)[0].format_) + u64(1))
            );
            if not dst_info.view(1)[0].format_ {
                PyErr_NoMemory();
                return -1;
            }
            strcpy(dst_info.view(1)[0].format_, src_info.view(1)[0].format_);
        }
        if src_info.view(1)[0].shape {
            shape_size = u64(8) * u64(src_info.view(1)[0].ndim);
            dst_info.view(1)[0].shape = ptr[i64](PyMem_Malloc(shape_size));
            if not dst_info.view(1)[0].shape {
                PyErr_NoMemory();
                return -1;
            }
            memcpy(
                ptr(dst_info.view(1)[0].shape),
                ptr(src_info.view(1)[0].shape),
                shape_size
            );
        }

        src_ffi = stginfo_ffi_type(src_info);
        dst_ffi = stginfo_ffi_type(dst_info);
        if not src_ffi.view(1)[0].elements {
            return 0;
        }
        size = u64(8) * u64(src_info.view(1)[0].length + 1);
        dst_ffi.view(1)[0].elements = ptr[ptr[ffi_type]](PyMem_Malloc(size));
        if not dst_ffi.view(1)[0].elements {
            PyErr_NoMemory();
            return -1;
        }
        memcpy(
            ptr(dst_ffi.view(1)[0].elements), ptr(src_ffi.view(1)[0].elements), size
        );
        return 0;
    }  def strlen(text: ptr[u8]) -> u64;  def strcpy(
        target: ptr[u8], source: ptr[u8]
    ) -> ptr[u8];  def PyCStructUnionType_update_stginfo(
        type: ptr[PyObject], fields: ptr[PyObject], isStruct: i32
    ) -> i32 {
        ffi_ofs: i64 = 0;
        arrays_seen = False;

        retval: i32 = -1;

        layout_func = NULL;
        kwnames = NULL;
        align_obj = NULL;
        size_obj = NULL;
        layout_fields_obj = NULL;
        layout_fields = NULL;
        layout = NULL;
        format_spec_obj = NULL;

        if not fields {
            return 0;
        }

        st = get_module_state_by_def(object_type(type));
        (status, stginfo) = PyStgInfo_FromType(st, type);
        if status < 0 {
            return -1;
        }
        if not stginfo {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("ctypes state is not initialized")
            );
            return -1;
        }
        base = ptr[PyObject](ptr[PyTypeObject](type).view(1)[0].tp_base);
        (base_status, baseinfo) = PyStgInfo_FromType(st, base);
        if base_status < 0 {
            return -1;
        }

        while True {
            if stginfo_get_dict_final(stginfo) == 1 {
                PyErr_SetString(PyExc_AttributeError, ptr[u8]("_fields_ is final"));
                break;
            }

            layout_func = PyImport_ImportModuleAttrString(
                ptr[u8]("ctypes._layout"), ptr[u8]("get_layout")
            );
            if not layout_func {
                break;
            }
            kwnames = PyTuple_Pack(i64(2), py_id(_Py_ID_is_struct), py_id(_Py_ID_base));
            if not kwnames {
                break;
            }
            slots: own StgdictArgs = StgdictArgs();
            stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
            stack.view(5)[0] = NULL;

            stack.view(5)[1] = type;
            stack.view(5)[2] = fields;

            if isStruct != 0 {
                stack.view(5)[3] = ptr[PyObject](addressof(_Py_TrueStruct));
            } else {
                stack.view(5)[3] = ptr[PyObject](addressof(_Py_FalseStruct));
            }
            if baseinfo {
                stack.view(5)[4] = base;
            } else {
                stack.view(5)[4] = Py_None;
            }
            layout = PyObject_Vectorcall(
                layout_func, stack + 1, u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET, kwnames
            );
            object_decref(kwnames);
            kwnames = NULL;
            object_decref(layout_func);
            layout_func = NULL;
            if not layout {
                break;
            }

            align_obj = PyObject_GetAttr(layout, py_id(_Py_ID_align));
            if not align_obj {
                break;
            }
            total_align = PyLong_AsSsize_t(align_obj);
            object_decref(align_obj);
            align_obj = NULL;
            if total_align < 0 {
                if not PyErr_Occurred() {
                    PyErr_SetString(
                        PyExc_ValueError,
                        ptr[u8]("align must be a non-negative integer")
                    );
                }
                break;
            }

            size_obj = PyObject_GetAttr(layout, py_id(_Py_ID_size));
            if not size_obj {
                break;
            }
            total_size = PyLong_AsSsize_t(size_obj);
            object_decref(size_obj);
            size_obj = NULL;
            if total_size < 0 {
                if not PyErr_Occurred() {
                    PyErr_SetString(
                        PyExc_ValueError, ptr[u8]("size must be a non-negative integer")
                    );
                }
                break;
            }

            format_spec_obj = PyObject_GetAttr(layout, py_id(_Py_ID_format_spec));
            if not format_spec_obj {
                break;
            }
            format_spec_size: i64 = 0;
            format_spec = PyUnicode_AsUTF8AndSize(
                format_spec_obj, &mut format_spec_size
            );
            if not format_spec {
                break;
            }

            if stginfo.view(1)[0].format_ {
                PyMem_Free(ptr(stginfo.view(1)[0].format_));
                stginfo.view(1)[0].format_ = ptr[u8]();
            }
            stginfo.view(1)[0].format_ = ptr[u8](
                PyMem_Malloc(u64(format_spec_size + 1))
            );
            if not stginfo.view(1)[0].format_ {
                PyErr_NoMemory();
                break;
            }
            memcpy(
                ptr(stginfo.view(1)[0].format_),
                ptr(format_spec),
                u64(format_spec_size + 1)
            );

            layout_fields_obj = PyObject_GetAttr(layout, py_id(_Py_ID_fields));
            if not layout_fields_obj {
                break;
            }
            layout_fields = PySequence_Tuple(layout_fields_obj);
            if not layout_fields {
                break;
            }
            object_decref(layout_fields_obj);
            layout_fields_obj = NULL;
            object_decref(layout);
            layout = NULL;

            len = object_size(layout_fields);

            ffi = stginfo_ffi_type(stginfo);
            if ffi.view(1)[0].elements {
                PyMem_Free(ptr(ffi.view(1)[0].elements));
                ffi.view(1)[0].elements = ptr[ptr[ffi_type]]();
            }

            if baseinfo {
                ffi.view(1)[0].type = FFI_TYPE_STRUCT;
                ffi.view(1)[0].elements = ptr[ptr[ffi_type]](
                    pymem_new_pointers(baseinfo.view(1)[0].length + len + 1)
                );
                if not ffi.view(1)[0].elements {
                    PyErr_NoMemory();
                    break;
                }
                memset(
                    ptr(ffi.view(1)[0].elements),
                    0,
                    u64(8) * u64(baseinfo.view(1)[0].length + len + 1)
                );
                if baseinfo.view(1)[0].length > 0 {
                    memcpy(
                        ptr(ffi.view(1)[0].elements),
                        ptr(stginfo_ffi_type(baseinfo).view(1)[0].elements),
                        u64(8) * u64(baseinfo.view(1)[0].length)
                    );
                }
                ffi_ofs = baseinfo.view(1)[0].length;
            } else {
                ffi.view(1)[0].type = FFI_TYPE_STRUCT;
                ffi.view(1)[0].elements = ptr[ptr[ffi_type]](
                    pymem_new_pointers(len + 1)
                );
                if not ffi.view(1)[0].elements {
                    PyErr_NoMemory();
                    break;
                }
                memset(ptr(ffi.view(1)[0].elements), 0, u64(8) * u64(len + 1));
                ffi_ofs = 0;
            }

            failed = False;
            for i in range(len) {
                prop_obj = tuple_get_item(layout_fields, i);
                if PyType_IsSubtype(
                    ptr[PyObject](object_type(prop_obj)),
                    ptr[PyObject](st.view(1)[0].PyCField_Type)
                )
                    == 0 {
                    PyErr_Format(
                        PyExc_TypeError,
                        ptr[u8]("fields must be of type CField, got %T"),
                        prop_obj
                    );
                    failed = True;
                    break;
                }

                prop = ptr[CFieldObject](prop_obj);

                if prop.view(1)[0].index != i {
                    index_expected: i64 = i;
                    index_got: i64 = prop.view(1)[0].index;
                    PyErr_Format(
                        PyExc_ValueError,
                        ptr[u8]("field %R index mismatch (expected %zd, got %zd)"),
                        prop.view(1)[0].name,
                        index_expected,
                        index_got
                    );
                    failed = True;
                    break;
                }

                if PyCArrayTypeObject_Check(st, prop.view(1)[0].proto) {
                    arrays_seen = True;
                }

                (info_status, info) = PyStgInfo_FromType(st, prop.view(1)[0].proto);
                if info_status < 0 {
                    failed = True;
                    break;
                }
                (ffi.view(1)[0].elements + (ffi_ofs + i)).view(1)[0] = stginfo_ffi_type(
                    info
                );
                if (info.view(1)[0].flags & (TYPEFLAG_ISPOINTER | TYPEFLAG_HASPOINTER))
                    != 0 {
                    stginfo.view(1)[0].flags = stginfo.view(1)[0].flags
                        | TYPEFLAG_HASPOINTER;
                }

                stginfo_set_dict_final_lock_held(info);
                if PyObject_SetAttr(type, prop.view(1)[0].name, prop_obj) == -1 {
                    failed = True;
                    break;
                }
            }
            if failed {
                break;
            }

            ffi.view(1)[0].alignment = u16.wrap(total_align);
            ffi.view(1)[0].size = u64(total_size);

            stginfo.view(1)[0].size = total_size;
            stginfo.view(1)[0].align = total_align;
            stginfo.view(1)[0].length = ffi_ofs + len;

            if arrays_seen and total_size <= max_struct_size() {
                if _replace_array_elements(
                    st, layout_fields, ffi_ofs, baseinfo, stginfo
                )
                    < 0 {
                    break;
                }
            }

            if stginfo_get_dict_final(stginfo) == 1 {
                PyErr_SetString(
                    PyExc_AttributeError,
                    ptr[u8]("Structure or union cannot contain itself")
                );
                break;
            }
            stginfo_set_dict_final_lock_held(stginfo);

            retval = MakeAnonFields(type);
            break;
        }
        object_xdecref(layout_func);
        object_xdecref(kwnames);
        object_xdecref(align_obj);
        object_xdecref(size_obj);
        object_xdecref(layout_fields_obj);
        object_xdecref(layout_fields);
        object_xdecref(layout);
        object_xdecref(format_spec_obj);
        return retval;
    }  def memset(target: ptr, value: i32, size: u64) -> ptr;  def _replace_array_elements(
        st: ptr[ctypes_state],
        layout_fields: ptr[PyObject],
        ffi_ofs: i64,
        baseinfo: ptr[StgInfo],
        stginfo: ptr[StgInfo]
    ) -> i32 {
        num_ffi_type_pointers: i64 = 0;

        num_ffi_types: i64 = 0;
        dummy_index: i64 = 0;
        struct_index: i64 = 0;

        len = object_size(layout_fields);

        for i in range(len) {
            prop = ptr[CFieldObject](tuple_get_item(layout_fields, i));

            (info_status, info) = PyStgInfo_FromType(st, prop.view(1)[0].proto);
            if info_status < 0 {
                return -1;
            }

            if not PyCArrayTypeObject_Check(st, prop.view(1)[0].proto) {
                num_ffi_type_pointers += 1;
            } else {
                length = info.view(1)[0].length;
                (einfo_status, einfo) = PyStgInfo_FromType(st, info.view(1)[0].proto);
                if einfo_status < 0 {
                    return -1;
                }
                if not einfo {
                    field_index: i64 = i;
                    PyErr_Format(
                        PyExc_TypeError,
                        ptr[u8](
                            "second item in _fields_ tuple (index %zd) must be a C type"
                        ),
                        field_index
                    );
                    return -1;
                }
                num_ffi_types += 1;
                num_ffi_type_pointers += length + 1;
            }
        }

        alloc_size = (ffi_ofs + 1 + len + num_ffi_type_pointers) * 8
            + num_ffi_types * SIZEOF_FFI_TYPE;
        type_block = PyMem_Malloc(u64(alloc_size));

        if not type_block {
            PyErr_NoMemory();
            return -1;
        }
        element_types = ptr[ptr[ffi_type]](type_block);
        dummy_types = ptr[ptr[ffi_type]](ptr[u8](type_block) + (ffi_ofs + len + 1) * 8);
        structs = ptr[u8](dummy_types) + num_ffi_type_pointers * 8;

        if num_ffi_types > 0 {
            memset(ptr(structs), 0, u64(num_ffi_types * SIZEOF_FFI_TYPE));
        }
        if ffi_ofs != 0 and baseinfo {
            memcpy(
                ptr(element_types),
                ptr(stginfo_ffi_type(baseinfo).view(1)[0].elements),
                u64(ffi_ofs * 8)
            );
        }
        element_index = ffi_ofs;

        for i in range(len) {
            prop = ptr[CFieldObject](tuple_get_item(layout_fields, i));

            (info_status, info) = PyStgInfo_FromType(st, prop.view(1)[0].proto);
            if info_status < 0 {
                PyMem_Free(type_block);
                return -1;
            }

            if not PyCArrayTypeObject_Check(st, prop.view(1)[0].proto) {
                (element_types + element_index).view(1)[0] = stginfo_ffi_type(info);
                element_index += 1;
            } else {
                length = info.view(1)[0].length;
                (einfo_status, einfo) = PyStgInfo_FromType(st, info.view(1)[0].proto);
                if einfo_status < 0 {
                    PyMem_Free(type_block);
                    return -1;
                }
                if not einfo {
                    field_index: i64 = i;
                    PyErr_Format(
                        PyExc_TypeError,
                        ptr[u8](
                            "second item in _fields_ tuple (index %zd) must be a C type"
                        ),
                        field_index
                    );
                    PyMem_Free(type_block);
                    return -1;
                }
                alias = ptr[ffi_type](structs + struct_index * SIZEOF_FFI_TYPE);
                (element_types + element_index).view(1)[0] = alias;
                element_index += 1;
                elem_ffi = stginfo_ffi_type(einfo);
                alias.view(1)[0].size = u64(length) * elem_ffi.view(1)[0].size;
                alias.view(1)[0].alignment = elem_ffi.view(1)[0].alignment;
                alias.view(1)[0].type = FFI_TYPE_STRUCT;
                alias.view(1)[0].elements = dummy_types + dummy_index;
                struct_index += 1;
                while length > 0 {
                    (dummy_types + dummy_index).view(1)[0] = elem_ffi;
                    dummy_index += 1;
                    length -= 1;
                }
                (dummy_types + dummy_index).view(1)[0] = ptr[ffi_type]();
                dummy_index += 1;
            }
        }

        (element_types + element_index).view(1)[0] = ptr[ffi_type]();

        ffi = stginfo_ffi_type(stginfo);
        PyMem_Free(ptr(ffi.view(1)[0].elements));
        ffi.view(1)[0].elements = element_types;

        return 0;
    }
}

def max_struct_size -> i64;

def pymem_new_pointers(n: i64) -> ptr;

def fast_get_item(seq: ptr[PyObject], i: i64) -> ptr[PyObject];

def MakeFields(
    type: ptr[PyObject], descr: ptr[CFieldObject], index: i64, offset: i64
) -> i32;

def MakeAnonFields(type: ptr[PyObject]) -> i32;

impl max_struct_size -> i64 {
    return MAX_STRUCT_SIZE;
}

impl pymem_new_pointers(n: i64) -> ptr {
    if n > 0x7FFFFFFFFFFFFFFF // 8 {
        return ptr();
    }
    return PyMem_Malloc(u64(n * 8));
}

impl fast_get_item(seq: ptr[PyObject], i: i64) -> ptr[PyObject] {
    if list_check(seq) {
        return (ptr[PyListObject](seq).view(1)[0].ob_item + i).view(1)[0];
    }
    return tuple_get_item(seq, i);
}

impl MakeFields(
    type: ptr[PyObject], descr: ptr[CFieldObject], index: i64, offset: i64
) -> i32 {
    fields = PyObject_GetAttrString(descr.view(1)[0].proto, ptr[u8]("_fields_"));
    if not fields {
        return -1;
    }
    fieldlist = PySequence_Fast(fields, ptr[u8]("_fields_ must be a sequence"));
    object_decref(fields);
    if not fieldlist {
        return -1;
    }

    st = get_module_state_by_class(object_type(ptr[PyObject](descr)));
    cfield_tp = st.view(1)[0].PyCField_Type;
    i: i64 = 0;
    while i < object_size(fieldlist) {
        pair = fast_get_item(fieldlist, i);
        fname: ptr[PyObject] = NULL;
        ftype: ptr[PyObject] = NULL;
        bits: ptr[PyObject] = NULL;
        if PyArg_ParseTuple(pair, ptr[u8]("OO|O"), &mut fname, &mut ftype, &mut bits)
            == 0 {
            object_decref(fieldlist);
            return -1;
        }
        fdescr = ptr[CFieldObject](PyObject_GetAttr(descr.view(1)[0].proto, fname));
        if not fdescr {
            object_decref(fieldlist);
            return -1;
        }
        if object_type(ptr[PyObject](fdescr)) != cfield_tp {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("unexpected type"));
            object_decref(ptr[PyObject](fdescr));
            object_decref(fieldlist);
            return -1;
        }
        if fdescr.view(1)[0].anonymous != 0 {
            rc = MakeFields(
                type,
                fdescr,
                index + fdescr.view(1)[0].index,
                offset + fdescr.view(1)[0].byte_offset
            );
            object_decref(ptr[PyObject](fdescr));
            if rc == -1 {
                object_decref(fieldlist);
                return -1;
            }
            i += 1;
            continue;
        }
        new_descr = ptr[CFieldObject](cfield_tp.view(1)[0].tp_alloc(cfield_tp, 0));
        if not new_descr {
            object_decref(ptr[PyObject](fdescr));
            object_decref(fieldlist);
            return -1;
        }
        new_descr.view(1)[0].byte_size = fdescr.view(1)[0].byte_size;
        new_descr.view(1)[0].byte_offset = fdescr.view(1)[0].byte_offset + offset;
        new_descr.view(1)[0].bitfield_size = fdescr.view(1)[0].bitfield_size;
        new_descr.view(1)[0].bit_offset = fdescr.view(1)[0].bit_offset;
        new_descr.view(1)[0].index = fdescr.view(1)[0].index + index;
        new_descr.view(1)[0].proto = object_xnewref(fdescr.view(1)[0].proto);
        new_descr.view(1)[0].getfunc = fdescr.view(1)[0].getfunc;
        new_descr.view(1)[0].setfunc = fdescr.view(1)[0].setfunc;
        new_descr.view(1)[0].name = object_new_ref(fdescr.view(1)[0].name);
        new_descr.view(1)[0].anonymous = fdescr.view(1)[0].anonymous;

        object_decref(ptr[PyObject](fdescr));

        if PyObject_SetAttr(type, fname, ptr[PyObject](new_descr)) == -1 {
            object_decref(fieldlist);
            object_decref(ptr[PyObject](new_descr));
            return -1;
        }
        object_decref(ptr[PyObject](new_descr));
        i += 1;
    }
    object_decref(fieldlist);
    return 0;
}

impl MakeAnonFields(type: ptr[PyObject]) -> i32 {
    anon: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(type, py_id(_Py_ID__anonymous_), &mut anon) < 0 {
        return -1;
    }
    if not anon {
        return 0;
    }
    anon_names = PySequence_Fast(anon, ptr[u8]("_anonymous_ must be a sequence"));
    object_decref(anon);
    if not anon_names {
        return -1;
    }

    st = get_module_state_by_def(object_type(type));
    cfield_tp = st.view(1)[0].PyCField_Type;
    i: i64 = 0;
    while i < object_size(anon_names) {
        fname = fast_get_item(anon_names, i);
        descr = ptr[CFieldObject](PyObject_GetAttr(type, fname));
        if not descr {
            object_decref(anon_names);
            return -1;
        }
        if object_type(ptr[PyObject](descr)) != cfield_tp {
            PyErr_Format(
                PyExc_AttributeError,
                ptr[u8]("'%U' is specified in _anonymous_ but not in _fields_"),
                fname
            );
            object_decref(anon_names);
            object_decref(ptr[PyObject](descr));
            return -1;
        }
        descr.view(1)[0].anonymous = 1;

        if MakeFields(type, descr, descr.view(1)[0].index, descr.view(1)[0].byte_offset)
            == -1 {
            object_decref(ptr[PyObject](descr));
            object_decref(anon_names);
            return -1;
        }
        object_decref(ptr[PyObject](descr));
        i += 1;
    }

    object_decref(anon_names);
    return 0;
}
