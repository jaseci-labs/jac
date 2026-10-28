import from c {
    def PyUnicode_AsEncodedString(
        unicode: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject];  def _PyUnicode_DecodeUnicodeEscapeInternal2(
        s: ptr[u8],
        size: i64,
        errors: ptr[u8],
        consumed: ptr[i64],
        first_invalid_escape_char: ptr[i32],
        first_invalid_escape_ptr: ptr[ptr[u8]]
    ) -> ptr[PyObject];  def _PyBytes_DecodeEscape2(
        s: ptr[u8],
        len: i64,
        errors: ptr[u8],
        first_invalid_escape_char: ptr[i32],
        first_invalid_escape_ptr: ptr[ptr[u8]]
    ) -> ptr[PyObject];  def PyUnicode_DecodeUTF8(
        s: ptr[u8], size: i64, errors: ptr[u8]
    ) -> ptr[PyObject];  def PyLong_FromUnicodeObject(
        u: ptr[PyObject], base: i32
    ) -> ptr[PyObject];  def PyMarshal_WriteObjectToString(
        x: ptr[PyObject], version: i32
    ) -> ptr[PyObject];  def PyFloat_FromString(v: ptr[PyObject]) -> ptr[PyObject];  def PyAST_Check(
        obj_: ptr[PyObject]
    ) -> i32;  def PyType_GenericAlloc(
        type: ptr[PyTypeObject], nitems: i64
    ) -> ptr[PyObject];  def PyObject_SetAttr(
        v: ptr[PyObject], name: ptr[PyObject], w: ptr[PyObject]
    ) -> i32;  def PyObject_GetOptionalAttr(
        v: ptr[PyObject], name: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32;  def PyList_New(size: i64) -> ptr[PyObject];  def PyList_Append(
        lst: ptr[PyObject], item: ptr[PyObject]
    ) -> i32;  def _PyCode_Validate(con: ptr[u8]) -> i32;  def _PyCode_New(
        con: ptr[u8]
    ) -> ptr[PyObject];  def PyErr_GetRaisedException -> ptr[PyObject];  def PyObject_Str(
        v: ptr[PyObject]
    ) -> ptr[PyObject];  def PyLong_FromVoidPtr(p: ptr) -> ptr[PyObject];  def PyType_FromSpec(
        spec: ptr[PyType_Spec]
    ) -> ptr[PyObject];  def PyInterpreterState_Get -> ptr[u8];  def PyInterpreterState_GetDict(
        interp: ptr[u8]
    ) -> ptr[PyObject];  def PyDict_GetItemString(
        dp: ptr[PyObject], key: ptr[u8]
    ) -> ptr[PyObject];  def PyDict_SetItemString(
        dp: ptr[PyObject], key: ptr[u8], item: ptr[PyObject]
    ) -> i32;  def PyDict_SetItem(
        op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
    ) -> i32;  def PyErr_ExceptionMatches(exc: ptr[PyObject]) -> i32;  def PyErr_Clear;  def PyCodec_Encoder(
        encoding: ptr[u8]
    ) -> ptr[PyObject];  def PyByteArray_FromStringAndSize(
        bytes_: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyByteArray_Resize(
        self_: ptr[PyObject], size: i64
    ) -> i32;  def PyBytes_FromObject(x: ptr[PyObject]) -> ptr[PyObject];  def PyErr_CheckSignals -> i32;  def PyErr_SetFromErrno(
        exc: ptr[PyObject]
    ) -> ptr[PyObject];  def read(fd: i32, buffer: ptr, size: u64) -> i64;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def __jac_errno -> ptr[i32];  def PyObject_GC_UnTrack(op: ptr);  obj SymtableEntryObject {
        has ob_base: _object,
            name: ptr[PyObject],
            symbols: ptr[PyObject],
            varnames: ptr[PyObject],
            children: ptr[PyObject],
            type: i32,
            lineno: i32,
            nested: i32;
    }  obj CompilerObjectsCall {
        has visit_call: Callable[[ptr[PyObject], ptr], i32] = 0;
    }  glob:priv AST_KIND_TYPES: list[i64] = [
             ast_state_Module_type,
             ast_state_Interactive_type,
             ast_state_Expression_type,
             ast_state_FunctionType_type,
             ast_state_FunctionDef_type,
             ast_state_AsyncFunctionDef_type,
             ast_state_ClassDef_type,
             ast_state_Return_type,
             ast_state_Delete_type,
             ast_state_Assign_type,
             ast_state_TypeAlias_type,
             ast_state_AugAssign_type,
             ast_state_AnnAssign_type,
             ast_state_For_type,
             ast_state_AsyncFor_type,
             ast_state_While_type,
             ast_state_If_type,
             ast_state_With_type,
             ast_state_AsyncWith_type,
             ast_state_Match_type,
             ast_state_Raise_type,
             ast_state_Try_type,
             ast_state_TryStar_type,
             ast_state_Assert_type,
             ast_state_Import_type,
             ast_state_ImportFrom_type,
             ast_state_Global_type,
             ast_state_Nonlocal_type,
             ast_state_Expr_type,
             ast_state_Pass_type,
             ast_state_Break_type,
             ast_state_Continue_type,
             ast_state_BoolOp_type,
             ast_state_NamedExpr_type,
             ast_state_BinOp_type,
             ast_state_UnaryOp_type,
             ast_state_Lambda_type,
             ast_state_IfExp_type,
             ast_state_Dict_type,
             ast_state_Set_type,
             ast_state_ListComp_type,
             ast_state_SetComp_type,
             ast_state_DictComp_type,
             ast_state_GeneratorExp_type,
             ast_state_Await_type,
             ast_state_Yield_type,
             ast_state_YieldFrom_type,
             ast_state_Compare_type,
             ast_state_Call_type,
             ast_state_FormattedValue_type,
             ast_state_Interpolation_type,
             ast_state_JoinedStr_type,
             ast_state_TemplateStr_type,
             ast_state_Constant_type,
             ast_state_Attribute_type,
             ast_state_Subscript_type,
             ast_state_Starred_type,
             ast_state_Name_type,
             ast_state_List_type,
             ast_state_Tuple_type,
             ast_state_Slice_type,
             ast_state_Load_type,
             ast_state_Store_type,
             ast_state_Del_type,
             ast_state_And_type,
             ast_state_Or_type,
             ast_state_Add_type,
             ast_state_Sub_type,
             ast_state_Mult_type,
             ast_state_MatMult_type,
             ast_state_Div_type,
             ast_state_Mod_type,
             ast_state_Pow_type,
             ast_state_LShift_type,
             ast_state_RShift_type,
             ast_state_BitOr_type,
             ast_state_BitXor_type,
             ast_state_BitAnd_type,
             ast_state_FloorDiv_type,
             ast_state_Invert_type,
             ast_state_Not_type,
             ast_state_UAdd_type,
             ast_state_USub_type,
             ast_state_Eq_type,
             ast_state_NotEq_type,
             ast_state_Lt_type,
             ast_state_LtE_type,
             ast_state_Gt_type,
             ast_state_GtE_type,
             ast_state_Is_type,
             ast_state_IsNot_type,
             ast_state_In_type,
             ast_state_NotIn_type,
             ast_state_comprehension_type,
             ast_state_ExceptHandler_type,
             ast_state_arguments_type,
             ast_state_arg_type,
             ast_state_keyword_type,
             ast_state_alias_type,
             ast_state_withitem_type,
             ast_state_match_case_type,
             ast_state_MatchValue_type,
             ast_state_MatchSingleton_type,
             ast_state_MatchSequence_type,
             ast_state_MatchMapping_type,
             ast_state_MatchClass_type,
             ast_state_MatchStar_type,
             ast_state_MatchAs_type,
             ast_state_MatchOr_type,
             ast_state_TypeIgnore_type,
             ast_state_TypeVar_type,
             ast_state_ParamSpec_type,
             ast_state_TypeVarTuple_type
         ],
         AST_KIND_SINGLETONS: list[i64] = [
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             ast_state_Load_singleton,
             ast_state_Store_singleton,
             ast_state_Del_singleton,
             ast_state_And_singleton,
             ast_state_Or_singleton,
             ast_state_Add_singleton,
             ast_state_Sub_singleton,
             ast_state_Mult_singleton,
             ast_state_MatMult_singleton,
             ast_state_Div_singleton,
             ast_state_Mod_singleton,
             ast_state_Pow_singleton,
             ast_state_LShift_singleton,
             ast_state_RShift_singleton,
             ast_state_BitOr_singleton,
             ast_state_BitXor_singleton,
             ast_state_BitAnd_singleton,
             ast_state_FloorDiv_singleton,
             ast_state_Invert_singleton,
             ast_state_Not_singleton,
             ast_state_UAdd_singleton,
             ast_state_USub_singleton,
             ast_state_Eq_singleton,
             ast_state_NotEq_singleton,
             ast_state_Lt_singleton,
             ast_state_LtE_singleton,
             ast_state_Gt_singleton,
             ast_state_GtE_singleton,
             ast_state_Is_singleton,
             ast_state_IsNot_singleton,
             ast_state_In_singleton,
             ast_state_NotIn_singleton,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1,
             -1
         ],
         AST_FIELDS: list[i64] = [
             ast_state_field_annotation,
             ast_state_field_arg,
             ast_state_field_args,
             ast_state_field_argtypes,
             ast_state_field_asname,
             ast_state_field_attr,
             ast_state_field_bases,
             ast_state_field_body,
             ast_state_field_bound,
             ast_state_field_cases,
             ast_state_field_cause,
             ast_state_field_cls,
             ast_state_field_col_offset,
             ast_state_field_comparators,
             ast_state_field_context_expr,
             ast_state_field_conversion,
             ast_state_field_ctx,
             ast_state_field_decorator_list,
             ast_state_field_default_value,
             ast_state_field_defaults,
             ast_state_field_elt,
             ast_state_field_elts,
             ast_state_field_end_col_offset,
             ast_state_field_end_lineno,
             ast_state_field_exc,
             ast_state_field_finalbody,
             ast_state_field_format_spec,
             ast_state_field_func,
             ast_state_field_generators,
             ast_state_field_guard,
             ast_state_field_handlers,
             ast_state_field_id,
             ast_state_field_ifs,
             ast_state_field_is_async,
             ast_state_field_items,
             ast_state_field_iter,
             ast_state_field_key,
             ast_state_field_keys,
             ast_state_field_keywords,
             ast_state_field_kind,
             ast_state_field_kw_defaults,
             ast_state_field_kwarg,
             ast_state_field_kwd_attrs,
             ast_state_field_kwd_patterns,
             ast_state_field_kwonlyargs,
             ast_state_field_left,
             ast_state_field_level,
             ast_state_field_lineno,
             ast_state_field_lower,
             ast_state_field_module,
             ast_state_field_msg,
             ast_state_field_name,
             ast_state_field_names,
             ast_state_field_op,
             ast_state_field_operand,
             ast_state_field_ops,
             ast_state_field_optional_vars,
             ast_state_field_orelse,
             ast_state_field_pattern,
             ast_state_field_patterns,
             ast_state_field_posonlyargs,
             ast_state_field_rest,
             ast_state_field_returns,
             ast_state_field_right,
             ast_state_field_simple,
             ast_state_field_slice,
             ast_state_field_step,
             ast_state_field_str,
             ast_state_field_subject,
             ast_state_field_tag,
             ast_state_field_target,
             ast_state_field_targets,
             ast_state_field_test,
             ast_state_field_type,
             ast_state_field_type_comment,
             ast_state_field_type_ignores,
             ast_state_field_type_params,
             ast_state_field_upper,
             ast_state_field_value,
             ast_state_field_values,
             ast_state_field_vararg
         ],
         entry_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("name"), type_=16, offset=16, flags=1, doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("symbols"), type_=16, offset=24, flags=1, doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("varnames"), type_=16, offset=32, flags=1, doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("children"), type_=16, offset=40, flags=1, doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("type"), type_=1, offset=48, flags=1, doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("lineno"), type_=1, offset=52, flags=1, doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("nested"), type_=1, offset=56, flags=1, doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         entry_getsets: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("id"), get=entry_id),
             PyGetSetDef()
         ],
         entry_slots: list[PyType_Slot] = [
             PyType_Slot(slot=52, pfunc=ptr(entry_dealloc)),
             PyType_Slot(slot=71, pfunc=ptr(entry_traverse)),
             PyType_Slot(slot=51, pfunc=ptr(entry_clear)),
             PyType_Slot(slot=66, pfunc=ptr(entry_repr)),
             PyType_Slot(slot=72, pfunc=ptr(addressof(entry_members))),
             PyType_Slot(slot=73, pfunc=ptr(addressof(entry_getsets))),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         entry_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_symtable.SymtableEntry"),
             basicsize=64,
             itemsize=0,
             flags=u32(Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC),
             slots=addressof(entry_slots)
         );
}

glob:priv PYBUF_SIMPLE: Final[i32] = 0,
     ERRNO_EINTR: Final[i32] = 4,
     CODE_MARSHAL_VERSION: Final[i32] = 4;

def utf8_result(value: ptr[PyObject]) -> ptr[PyObject];

def bytes_data(op: ptr[PyObject]) -> ptr[u8];

def interp_ast_state -> ptr[u8];

def ast_slot(state: ptr[u8], offset: i64) -> ptr[PyObject];

def ast_kind_count -> i64;

def ast_kind_type(state: ptr[u8], kind: i64) -> ptr[PyObject];

def ast_field_name(field: i64) -> ptr[PyObject];

def entry_of(op: ptr[PyObject]) -> ptr[SymtableEntryObject];

def entry_visit(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def entry_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def entry_clear(op: ptr[PyObject]) -> i32;

def entry_dealloc(op: ptr[PyObject]);

def entry_id(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def entry_repr(op: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def jacpy_unicode_escape(source: ptr[u8], size: i64) -> ptr[PyObject] {
        invalid = ptr[ptr[u8]](__alloca(8));
        invalid.view(1)[0] = ptr[u8]();
        invalid_char = ptr[i32](__alloca(8));
        invalid_char.view(1)[0] = i32(-1);
        return utf8_result(
            _PyUnicode_DecodeUnicodeEscapeInternal2(
                source, size, ptr[u8](), ptr[i64](), invalid_char, invalid
            )
        );
    }  def jacpy_bytes_escape(source: ptr[u8], size: i64) -> ptr[PyObject] {
        invalid = ptr[ptr[u8]](__alloca(8));
        invalid.view(1)[0] = ptr[u8]();
        invalid_char = ptr[i32](__alloca(8));
        invalid_char.view(1)[0] = i32(-1);
        return _PyBytes_DecodeEscape2(source, size, ptr[u8](), invalid_char, invalid);
    }  def jacpy_buffer_size(handle: ptr[PyObject]) -> i64 {
        return object_size(handle);
    }  def jacpy_buffer_byte(handle: ptr[PyObject], index: i64) -> i64 {
        return i64((bytes_data(handle) + index).view(1)[0]);
    }  def jacpy_release(handle: ptr[PyObject]) {
        object_xdecref(handle);
    }  def jacpy_parse_long(source: ptr[u8], size: i64) -> ptr[PyObject] {
        text = PyUnicode_DecodeUTF8(source, size, ptr[u8]("strict"));
        if not text {
            return NULL;
        }
        value = PyLong_FromUnicodeObject(text, 0);
        object_decref(text);
        if not value {
            return NULL;
        }
        data = PyMarshal_WriteObjectToString(value, CODE_MARSHAL_VERSION);
        object_decref(value);
        return data;
    }  def jacpy_parse_float(source: ptr[u8], size: i64) -> ptr[PyObject] {
        text = PyUnicode_DecodeUTF8(source, size, ptr[u8]("strict"));
        if not text {
            return NULL;
        }
        value = PyFloat_FromString(text);
        object_decref(text);
        return value;
    }  def jacpy_float_value(handle: ptr[PyObject]) -> f64 {
        return ptr[PyFloatObject](handle).view(1)[0].ob_fval;
    }  def jacpy_ast_kind(handle: ptr[PyObject]) -> i64 {
        state = interp_ast_state();
        if not state {
            return -2;
        }
        type = ptr[PyObject](object_type(handle));
        count = ast_kind_count();
        for kind in range(count) {
            if type == ast_kind_type(state, kind) {
                return kind;
            }
        }
        for kind in range(count) {
            if PyType_IsSubtype(type, ast_kind_type(state, kind)) != 0 {
                return kind;
            }
        }
        return -1;
    }  def jacpy_ast_new(kind: i64) -> ptr[PyObject] {
        state = interp_ast_state();
        if not state {
            return NULL;
        }
        singleton = (addressof(AST_KIND_SINGLETONS) + kind).view(1)[0];
        if singleton >= 0 {
            return object_new_ref(ast_slot(state, singleton));
        }
        return PyType_GenericAlloc(ptr[PyTypeObject](ast_kind_type(state, kind)), 0);
    }  def jacpy_set_owned(
        target: ptr[PyObject], field: i64, value: ptr[PyObject]
    ) -> i64 {
        if not value {
            return -1;
        }
        name = ast_field_name(field);
        status: i32 = -1;
        if name {
            status = PyObject_SetAttr(target, name, value);
        }
        object_decref(value);
        return i64(status);
    }  def jacpy_field(handle: ptr[PyObject], field: i64) -> ptr[PyObject] {
        name = ast_field_name(field);
        if not name {
            return NULL;
        }
        slot = ptr[ptr[PyObject]](__alloca(8));
        slot.view(1)[0] = NULL;
        if PyObject_GetOptionalAttr(handle, name, slot) < 0 {
            return NULL;
        }
        value = slot.view(1)[0];
        if not value {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("required field \"%U\" missing from %s"),
                name,
                object_type(handle).view(1)[0].tp_name
            );
        }
        return value;
    }  def jacpy_optional_field(handle: ptr[PyObject], field: i64) -> ptr[PyObject] {
        name = ast_field_name(field);
        if not name {
            return NULL;
        }
        slot = ptr[ptr[PyObject]](__alloca(8));
        slot.view(1)[0] = NULL;
        if PyObject_GetOptionalAttr(handle, name, slot) < 0 {
            return NULL;
        }
        value = slot.view(1)[0];
        if value {
            return value;
        }
        return object_new_ref(Py_None);
    }  def jacpy_list_new -> ptr[PyObject] {
        return PyList_New(0);
    }  def jacpy_list_append_owned(target: ptr[PyObject], value: ptr[PyObject]) -> i64 {
        if not value {
            return -1;
        }
        status = PyList_Append(target, value);
        object_decref(value);
        return i64(status);
    }  def jacpy_text(value: ptr[u8], size: i64) -> ptr[PyObject] {
        return PyUnicode_DecodeUTF8(value, size, ptr[u8]("surrogatepass"));
    }  def jacpy_buffer_new(size: i64) -> ptr[PyObject] {
        return PyBytes_FromStringAndSize(ptr[u8](), size);
    }  def jacpy_buffer_set(handle: ptr[PyObject], index: i64, value: i64) {
        (bytes_data(handle) + index).view(1)[0] = u8.wrap(value);
    }  def jacpy_code_new(
        argcount: i64,
        posonlyargcount: i64,
        kwonlyargcount: i64,
        stacksize: i64,
        flags: i64,
        code: ptr[PyObject],
        consts: ptr[PyObject],
        names: ptr[PyObject],
        localsplusnames: ptr[PyObject],
        localspluskinds: ptr[PyObject],
        filename: ptr[PyObject],
        name: ptr[PyObject],
        qualname: ptr[PyObject],
        firstlineno: i64,
        linetable: ptr[PyObject],
        exceptiontable: ptr[PyObject]
    ) -> ptr[PyObject] {
        con = ptr[u8](__alloca(_PyCodeConstructor_SIZE));
        memset(ptr(con), 0, u64(_PyCodeConstructor_SIZE));
        ptr[ptr[PyObject]](con + _PyCodeConstructor_FILENAME).view(1)[0] = filename;
        ptr[ptr[PyObject]](con + _PyCodeConstructor_NAME).view(1)[0] = name;
        ptr[ptr[PyObject]](con + _PyCodeConstructor_QUALNAME).view(1)[0] = qualname;
        ptr[i32](con + _PyCodeConstructor_FLAGS).view(1)[0] = i32.wrap(flags);
        ptr[ptr[PyObject]](con + _PyCodeConstructor_CODE).view(1)[0] = code;
        ptr[i32](con + _PyCodeConstructor_FIRSTLINENO).view(1)[0] = i32.wrap(
            firstlineno
        );
        ptr[ptr[PyObject]](con + _PyCodeConstructor_LINETABLE).view(1)[0] = linetable;
        ptr[ptr[PyObject]](con + _PyCodeConstructor_CONSTS).view(1)[0] = consts;
        ptr[ptr[PyObject]](con + _PyCodeConstructor_NAMES).view(1)[0] = names;
        ptr[ptr[PyObject]](con + _PyCodeConstructor_LOCALSPLUSNAMES).view(1)[0] = localsplusnames;
        ptr[ptr[PyObject]](con + _PyCodeConstructor_LOCALSPLUSKINDS).view(1)[0] = localspluskinds;
        ptr[i32](con + _PyCodeConstructor_ARGCOUNT).view(1)[0] = i32.wrap(argcount);
        ptr[i32](con + _PyCodeConstructor_POSONLYARGCOUNT).view(1)[0] = i32.wrap(
            posonlyargcount
        );
        ptr[i32](con + _PyCodeConstructor_KWONLYARGCOUNT).view(1)[0] = i32.wrap(
            kwonlyargcount
        );
        ptr[i32](con + _PyCodeConstructor_STACKSIZE).view(1)[0] = i32.wrap(stacksize);
        ptr[ptr[PyObject]](con + _PyCodeConstructor_EXCEPTIONTABLE).view(1)[0] = exceptiontable;
        if _PyCode_Validate(con) < 0 {
            return NULL;
        }
        return _PyCode_New(con);
    }  def jacpy_value_kind(handle: ptr[PyObject]) -> i64 {
        if handle == Py_None {
            return 0;
        }
        if handle == Py_Ellipsis {
            return 1;
        }
        type = object_type(handle);
        if type == ptr[PyTypeObject](addressof(PyBool_Type)) {
            return 2;
        }
        if type_has_feature(type, Py_TPFLAGS_LONG_SUBCLASS) {
            return 3;
        }
        if object_type_check(handle, ptr[PyTypeObject](addressof(PyFloat_Type))) {
            return 4;
        }
        if object_type_check(handle, ptr[PyTypeObject](addressof(PyComplex_Type))) {
            return 5;
        }
        if type_has_feature(type, Py_TPFLAGS_UNICODE_SUBCLASS) {
            return 6;
        }
        if type_has_feature(type, Py_TPFLAGS_BYTES_SUBCLASS) {
            return 7;
        }
        if type_has_feature(type, Py_TPFLAGS_TUPLE_SUBCLASS) {
            return 8;
        }
        if object_type_check(handle, ptr[PyTypeObject](addressof(PyFrozenSet_Type))) {
            return 9;
        }
        return -1;
    }  def jacpy_marshal(handle: ptr[PyObject]) -> ptr[PyObject] {
        return PyMarshal_WriteObjectToString(handle, CODE_MARSHAL_VERSION);
    }  def jacpy_utf8(handle: ptr[PyObject]) -> ptr[PyObject] {
        return PyUnicode_AsEncodedString(
            handle, ptr[u8]("utf-8"), ptr[u8]("surrogatepass")
        );
    }  def jacpy_sequence_size(handle: ptr[PyObject]) -> i64 {
        return object_size(handle);
    }  def jacpy_sequence_item(handle: ptr[PyObject], index: i64) -> ptr[PyObject] {
        return object_new_ref(
            (ptr[PyListObject](handle).view(1)[0].ob_item + index).view(1)[0]
        );
    }  def jacpy_is_list(handle: ptr[PyObject]) -> i64 {
        return 1
            if type_has_feature(object_type(handle), Py_TPFLAGS_LIST_SUBCLASS)
            else 0;
    }  def jacpy_error_pending -> i64 {
        return 1 if PyErr_Occurred() else 0;
    }  def jacpy_decode(handle: ptr[PyObject], encoding: ptr[u8]) -> ptr[PyObject] {
        return utf8_result(
            PyUnicode_Decode(
                bytes_data(handle), object_size(handle), encoding, ptr[u8]("strict")
            )
        );
    }  def jacpy_take_error_text -> ptr[PyObject] {
        error = PyErr_GetRaisedException();
        if not error {
            PyErr_SetString(PyExc_SystemError, ptr[u8]("missing boundary exception"));
            return NULL;
        }
        text = PyObject_Str(error);
        object_decref(error);
        return utf8_result(text);
    }  def jacpy_symtable_entry(
        name: ptr[PyObject],
        kind: i64,
        lineno: i64,
        nested: i64,
        symbols: ptr[PyObject],
        varnames: ptr[PyObject],
        children: ptr[PyObject]
    ) -> ptr[PyObject] {
        state = PyInterpreterState_GetDict(PyInterpreterState_Get());
        if not state {
            return NULL;
        }
        type = PyDict_GetItemString(state, ptr[u8]("_jacpython_symtable_type"));
        if not type {
            created = PyType_FromSpec(addressof(entry_spec));
            if not created {
                return NULL;
            }
            status = PyDict_SetItemString(
                state, ptr[u8]("_jacpython_symtable_type"), created
            );
            object_decref(created);
            if status < 0 {
                return NULL;
            }
            type = PyDict_GetItemString(state, ptr[u8]("_jacpython_symtable_type"));
        }
        op = PyType_GenericAlloc(ptr[PyTypeObject](type), 0);
        if not op {
            return NULL;
        }
        entry_item = entry_of(op);
        entry_item.view(1)[0].name = object_new_ref(name);
        entry_item.view(1)[0].symbols = object_new_ref(symbols);
        entry_item.view(1)[0].varnames = object_new_ref(varnames);
        entry_item.view(1)[0].children = object_new_ref(children);
        entry_item.view(1)[0].type = i32.wrap(kind);
        entry_item.view(1)[0].lineno = i32.wrap(lineno);
        entry_item.view(1)[0].nested = i32.wrap(nested);
        return op;
    }  def jacpy_dict_set_owned(
        dictionary: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
    ) -> i64 {
        if not key or not value {
            object_xdecref(key);
            object_xdecref(value);
            return -1;
        }
        status = PyDict_SetItem(dictionary, key, value);
        object_decref(key);
        object_decref(value);
        return i64(status);
    }  def jacpy_readline(
        reader: ptr[PyObject], encoding: ptr[u8], decode: i64
    ) -> ptr[PyObject] {
        line = PyObject_CallNoArgs(reader);
        if not line {
            if PyErr_ExceptionMatches(PyExc_StopIteration) == 0 {
                return NULL;
            }
            PyErr_Clear();
            return PyBytes_FromStringAndSize(ptr[u8](""), 0);
        }
        if decode != 0 {
            if not type_has_feature(object_type(line), Py_TPFLAGS_BYTES_SUBCLASS) {
                object_decref(line);
                PyErr_SetString(
                    PyExc_TypeError, ptr[u8]("readline() returned a non-bytes object")
                );
                return NULL;
            }
            text = PyUnicode_Decode(
                bytes_data(line), object_size(line), encoding, ptr[u8]("replace")
            );
            object_decref(line);
            line = text;
        } elif not type_has_feature(object_type(line), Py_TPFLAGS_UNICODE_SUBCLASS) {
            object_decref(line);
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("readline() returned a non-string")
            );
            return NULL;
        }
        return utf8_result(line);
    }  def jacpy_source_bytes(handle: ptr[PyObject]) -> ptr[PyObject] {
        view = ptr[Py_buffer](__alloca(Py_buffer_SIZE));
        if PyObject_GetBuffer(handle, view, PYBUF_SIMPLE) < 0 {
            return NULL;
        }
        copy = PyBytes_FromStringAndSize(
            ptr[u8](view.view(1)[0].buf), view.view(1)[0].length
        );
        PyBuffer_Release(view);
        return copy;
    }  def jacpy_source_kind(handle: ptr[PyObject]) -> i64 {
        if type_has_feature(object_type(handle), Py_TPFLAGS_UNICODE_SUBCLASS) {
            return 0;
        }
        if PyObject_CheckBuffer(handle) != 0 {
            return 1;
        }
        is_ast = PyAST_Check(handle);
        return 2 if is_ast > 0 else -1;
    }  def jacpy_codec_valid(name: ptr[u8]) -> i64 {
        codec = PyCodec_Encoder(name);
        if not codec {
            return 0;
        }
        object_decref(codec);
        return 1;
    }  def jacpy_fd_line(fd: i64) -> ptr[PyObject] {
        line = PyByteArray_FromStringAndSize(ptr[u8](), 0);
        if not line {
            return NULL;
        }
        ch = ptr[u8](__alloca(8));
        while True {
            count = read(i32.wrap(fd), ptr(ch), u64(1));
            if count < 0 {
                if __jac_errno().view(1)[0] == ERRNO_EINTR {
                    if PyErr_CheckSignals() < 0 {
                        object_decref(line);
                        return NULL;
                    }
                    continue;
                }
                object_decref(line);
                PyErr_SetFromErrno(PyExc_OSError);
                return NULL;
            }
            if count == 0 {
                break;
            }
            length = object_size(line);
            if PyByteArray_Resize(line, length + 1) < 0 {
                object_decref(line);
                return NULL;
            }
            (ptr[PyByteArrayObject](line).view(1)[0].ob_start + length).view(1)[0] = ch.view(
                1
            )[0];
            if ch.view(1)[0] == u8(10) {
                break;
            }
        }
        result = PyBytes_FromObject(line);
        object_decref(line);
        return result;
    }
}

impl utf8_result(value: ptr[PyObject]) -> ptr[PyObject] {
    if not value {
        return NULL;
    }
    data = PyUnicode_AsEncodedString(value, ptr[u8]("utf-8"), ptr[u8]("surrogatepass"));
    object_decref(value);
    return data;
}

impl bytes_data(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + PyBytesObject_OB_SVAL;
}

impl interp_ast_state -> ptr[u8] {
    state = current_interp() + PyInterpreterState_AST;
    if u8.wrap(__atomic_load_i8(int(state), 5)) == _Py_ONCE_INITIALIZED {
        return state;
    }
    if PyAST_Check(Py_None) < 0 {
        return ptr[u8]();
    }
    return state;
}

impl ast_slot(state: ptr[u8], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](state + offset).view(1)[0];
}

impl ast_kind_count -> i64 {
    return 113;
}

impl ast_kind_type(state: ptr[u8], kind: i64) -> ptr[PyObject] {
    return ast_slot(state, (addressof(AST_KIND_TYPES) + kind).view(1)[0]);
}

impl ast_field_name(field: i64) -> ptr[PyObject] {
    state = interp_ast_state();
    if not state {
        return NULL;
    }
    return ast_slot(state, (addressof(AST_FIELDS) + field).view(1)[0]);
}

impl entry_of(op: ptr[PyObject]) -> ptr[SymtableEntryObject] {
    return ptr[SymtableEntryObject](op);
}

impl entry_visit(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    if not op {
        return i32(0);
    }
    calls = ptr[CompilerObjectsCall](
        __thread_local_block("jac_object_model_compiler_objects_call_slot", 8)
    );
    calls.view(1)[0].visit_call = int(visitor);
    return calls.view(1)[0].visit_call(op, arg);
}

impl entry_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    entry_item = entry_of(op);
    status = entry_visit(ptr[PyObject](object_type(op)), visitor, arg);
    if status != i32(0) {
        return status;
    }
    status = entry_visit(entry_item.view(1)[0].name, visitor, arg);
    if status != i32(0) {
        return status;
    }
    status = entry_visit(entry_item.view(1)[0].symbols, visitor, arg);
    if status != i32(0) {
        return status;
    }
    status = entry_visit(entry_item.view(1)[0].varnames, visitor, arg);
    if status != i32(0) {
        return status;
    }
    return entry_visit(entry_item.view(1)[0].children, visitor, arg);
}

impl entry_clear(op: ptr[PyObject]) -> i32 {
    entry_item = entry_of(op);
    name = entry_item.view(1)[0].name;
    entry_item.view(1)[0].name = NULL;
    object_xdecref(name);
    symbols = entry_item.view(1)[0].symbols;
    entry_item.view(1)[0].symbols = NULL;
    object_xdecref(symbols);
    varnames = entry_item.view(1)[0].varnames;
    entry_item.view(1)[0].varnames = NULL;
    object_xdecref(varnames);
    children = entry_item.view(1)[0].children;
    entry_item.view(1)[0].children = NULL;
    object_xdecref(children);
    return i32(0);
}

impl entry_dealloc(op: ptr[PyObject]) {
    type = object_type(op);
    PyObject_GC_UnTrack(ptr(op));
    entry_clear(op);
    type.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](type));
}

impl entry_id(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromVoidPtr(ptr(op));
}

impl entry_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    entry_item = entry_of(op);
    address = u64(int(op));
    return PyUnicode_FromFormat(
        "<symtable entry %U(%llu), line %d>",
        entry_item.view(1)[0].name,
        address,
        entry_item.view(1)[0].lineno
    );
}
