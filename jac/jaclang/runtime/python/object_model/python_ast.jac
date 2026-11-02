import from c {
    def _PyOnceFlag_CallOnceSlow(flag: ptr[u8], once_fn: ptr, arg: ptr) -> i32;  def Py_EnterRecursiveCall(
        where: ptr[u8]
    ) -> i32;  def PyType_FromSpec(spec: ptr[PyType_Spec]) -> ptr[PyObject];  def PyModuleDef_Init(
        mdef: ptr[PyModuleDef]
    ) -> ptr[PyObject];  def PyUnicodeWriter_WriteUTF8(
        writer: ptr[PyUnicodeWriter], text: ptr[u8], size_in: i64
    ) -> i32;  def Py_GenericAlias(
        origin: ptr[PyObject], args: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_union_type_or(
        a: ptr[PyObject], b: ptr[PyObject]
    ) -> ptr[PyObject];  def _PySet_NextEntry(
        so: ptr[PyObject], pos: &mut i64, key: &mut ptr[PyObject], hash: &mut i64
    ) -> i32;  def _PySet_Update(so: ptr[PyObject], iterable: ptr[PyObject]) -> i32;  def _PyArena_Malloc(
        arena: ptr, size: u64
    ) -> ptr;  def _PyArena_AddPyObject(arena: ptr, op: ptr[PyObject]) -> i32;  def _Py_asdl_generic_seq_new(
        size: i64, arena: ptr
    ) -> ptr;  def _Py_asdl_int_seq_new(size: i64, arena: ptr) -> ptr;  def _Py_asdl_identifier_seq_new(
        size: i64, arena: ptr
    ) -> ptr;  def _Py_FatalErrorFunc(func: ptr[u8], message: ptr[u8]);  def jacpy_stack_address(
        slots: &mut AstStack
    ) -> int;  obj AstStack {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject]();
    }  obj AstCall {
        has free: Callable[[ptr], None] = 0;
    }  obj AST_object {
        has ob_base: _object,
            dct: ptr[PyObject];
    }  glob:priv ast_type_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=AST_OBJECT_DICT,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         ast_type_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(ast_type_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__replace__"),
                 ml_meth=ptr(ast_type_replace),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "__replace__($self, /, **fields)\n--\n\nReturn a copy of the AST node with new values for the specified fields."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         ast_type_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__dict__"),
                 get=PyObject_GenericGetDict,
                 set=PyObject_GenericSetDict
             ),
             PyGetSetDef()
         ],
         AST_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(ast_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(ast_repr)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(slot=Py_tp_setattro, pfunc=ptr(PyObject_GenericSetAttr)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(ast_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(ast_clear)),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(ast_type_members))),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(ast_type_methods))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(ast_type_getsets))),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(ast_type_init)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(PyType_GenericNew)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         AST_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("ast.AST"),
             basicsize=i32(AST_OBJECT_SIZE),
             itemsize=0,
             flags=u32(Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC),
             slots=addressof(AST_type_slots)
         ),
         astmodule_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(astmodule_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ],
         _astmodule: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_ast"),
             m_doc=ptr[u8](),
             m_size=0,
             m_methods=ptr[PyMethodDef](),
             m_slots=addressof(astmodule_slots)
         );
}

glob:priv AST_OBJECT_SIZE: Final[i64] = 24,
     AST_OBJECT_DICT: Final[i64] = 16;

def get_ast_state -> ptr[ast_state];

def long_check(op: ptr[PyObject]) -> bool;

def tuple_check(op: ptr[PyObject]) -> bool;

def list_check(op: ptr[PyObject]) -> bool;

def unicode_check_exact(op: ptr[PyObject]) -> bool;

def bytes_check_exact(op: ptr[PyObject]) -> bool;

def list_get_item(lst: ptr[PyObject], index: i64) -> ptr[PyObject];

def list_set_item(lst: ptr[PyObject], index: i64, value: ptr[PyObject]);

def asdl_seq_len(seq: ptr[asdl_seq]) -> i64;

def asdl_seq_get_untyped(seq: ptr[asdl_seq], index: i64) -> ptr;

def asdl_seq_set(seq: ptr[asdl_seq], index: i64, value: ptr);

def asdl_int_seq_get(seq: ptr[asdl_seq], index: i64) -> i32;

def asdl_int_seq_set(seq: ptr[asdl_seq], index: i64, value: i32);

def node_union(node_ptr: ptr) -> ptr[u8];

def ast_dealloc(op: ptr[PyObject]);

def ast_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def ast_clear(op: ptr[PyObject]) -> i32;

def init_cleanup(
    res: i32, attributes: ptr[PyObject], fields: ptr[PyObject], remaining: ptr[PyObject]
) -> i32;

def ast_type_init(self_: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]) -> i32;

def reduce_cleanup(
    result: ptr[PyObject], fields: ptr[PyObject], positional_args: ptr[PyObject]
) -> ptr[PyObject];

def ast_type_reduce(self_: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject];

def ast_type_replace_check(
    self_: ptr[PyObject],
    dct: ptr[PyObject],
    fields: ptr[PyObject],
    attributes: ptr[PyObject],
    kwargs: ptr[PyObject]
) -> i32;

def ast_type_replace_update_payload(
    payload: ptr[PyObject], keys: ptr[PyObject], dct: ptr[PyObject]
) -> i32;

def replace_cleanup(
    result: ptr[PyObject],
    payload: ptr[PyObject],
    empty_tuple: ptr[PyObject],
    dct: ptr[PyObject],
    attributes: ptr[PyObject],
    fields: ptr[PyObject]
) -> ptr[PyObject];

def ast_type_replace(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def repr_list_error(
    item0: ptr[PyObject], item1: ptr[PyObject], writer: ptr[PyUnicodeWriter]
) -> ptr[PyObject];

def ast_repr_list(lst: ptr[PyObject], depth: i32) -> ptr[PyObject];

def repr_error(
    self_: ptr[PyObject], fields: ptr[PyObject], writer: ptr[PyUnicodeWriter]
) -> ptr[PyObject];

def ast_repr_max_depth(self_: ptr[PyObject], depth: i32) -> ptr[PyObject];

def ast_repr(self_: ptr[PyObject]) -> ptr[PyObject];

def make_type(
    state: ptr[ast_state],
    type_name: ptr[u8],
    base: ptr[PyObject],
    fields: ptr[ptr[u8]],
    num_fields: i32,
    doc: ptr[u8]
) -> ptr[PyObject];

def add_attributes(
    state: ptr[ast_state], type: ptr[PyObject], attrs: ptr[ptr[u8]], num_fields: i32
) -> i32;

def add_field_annotation(
    annotations: ptr[PyObject],
    name: ptr[u8],
    field_type: ptr[PyObject],
    quantifier: i32
) -> bool;

def set_field_annotations(type: ptr[PyObject], annotations: ptr[PyObject]) -> bool;

def ast2obj_failed(result: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def ast2obj_object(state: ptr[ast_state], o: ptr[PyObject]) -> ptr[PyObject];

def ast2obj_int(state: ptr[ast_state], b: i64) -> ptr[PyObject];

def obj2ast_object(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[PyObject]];

def obj2ast_constant(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[PyObject]];

def obj2ast_identifier(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[PyObject]];

def obj2ast_string(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[PyObject]];

def obj2ast_int(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32];

def add_ast_fields(state: ptr[ast_state]) -> i32;

import from c {
    def PyAST_mod2obj(t: ptr[_mod]) -> ptr[PyObject] {
        state = get_ast_state();
        if not state {
            return NULL;
        }
        return ast2obj_mod(state, t);
    }  def PyAst_CheckMode(ast: ptr[PyObject], mode: i32) -> i32 {
        state = get_ast_state();
        if not state {
            return -1;
        }
        req_type = state.view(1)[0].Module_type;
        req_name = ptr[u8]("Module");
        if mode == 1 {
            req_type = state.view(1)[0].Expression_type;
            req_name = ptr[u8]("Expression");
        } elif mode == 2 {
            req_type = state.view(1)[0].Interactive_type;
            req_name = ptr[u8]("Interactive");
        }
        isinstance_ = PyObject_IsInstance(ast, req_type);
        if isinstance_ == -1 {
            return -1;
        }
        if isinstance_ == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("expected %s node, got %.400s"),
                req_name,
                _PyType_Name(ptr[PyObject](object_type(ast)))
            );
            return -1;
        }
        return 0;
    }  def PyAST_obj2mod(ast: ptr[PyObject], arena: ptr, mode: i32) -> ptr[_mod] {
        if PySys_Audit(ptr[u8]("compile"), ptr[u8]("OO"), ast, Py_None) < 0 {
            return ptr[_mod]();
        }
        state = get_ast_state();
        if not state {
            return ptr[_mod]();
        }
        if PyAst_CheckMode(ast, mode) < 0 {
            return ptr[_mod]();
        }
        (status, res) = obj2ast_mod(state, ast, arena);
        if status != 0 {
            return ptr[_mod]();
        }
        return res;
    }  def PyAST_Check(obj_: ptr[PyObject]) -> i32 {
        state = get_ast_state();
        if not state {
            return -1;
        }
        return PyObject_IsInstance(obj_, state.view(1)[0].AST_type);
    }  def PyInit__ast -> ptr[PyObject] {
        return PyModuleDef_Init(ptr[PyModuleDef](addressof(_astmodule)));
    }
}

glob Module_kind: Final[i32] = 1,
     Interactive_kind: Final[i32] = 2,
     Expression_kind: Final[i32] = 3,
     FunctionType_kind: Final[i32] = 4,
     FunctionDef_kind: Final[i32] = 1,
     AsyncFunctionDef_kind: Final[i32] = 2,
     ClassDef_kind: Final[i32] = 3,
     Return_kind: Final[i32] = 4,
     Delete_kind: Final[i32] = 5,
     Assign_kind: Final[i32] = 6,
     TypeAlias_kind: Final[i32] = 7,
     AugAssign_kind: Final[i32] = 8,
     AnnAssign_kind: Final[i32] = 9,
     For_kind: Final[i32] = 10,
     AsyncFor_kind: Final[i32] = 11,
     While_kind: Final[i32] = 12,
     If_kind: Final[i32] = 13,
     With_kind: Final[i32] = 14,
     AsyncWith_kind: Final[i32] = 15,
     Match_kind: Final[i32] = 16,
     Raise_kind: Final[i32] = 17,
     Try_kind: Final[i32] = 18,
     TryStar_kind: Final[i32] = 19,
     Assert_kind: Final[i32] = 20,
     Import_kind: Final[i32] = 21,
     ImportFrom_kind: Final[i32] = 22,
     Global_kind: Final[i32] = 23,
     Nonlocal_kind: Final[i32] = 24,
     Expr_kind: Final[i32] = 25,
     Pass_kind: Final[i32] = 26,
     Break_kind: Final[i32] = 27,
     Continue_kind: Final[i32] = 28,
     BoolOp_kind: Final[i32] = 1,
     NamedExpr_kind: Final[i32] = 2,
     BinOp_kind: Final[i32] = 3,
     UnaryOp_kind: Final[i32] = 4,
     Lambda_kind: Final[i32] = 5,
     IfExp_kind: Final[i32] = 6,
     Dict_kind: Final[i32] = 7,
     Set_kind: Final[i32] = 8,
     ListComp_kind: Final[i32] = 9,
     SetComp_kind: Final[i32] = 10,
     DictComp_kind: Final[i32] = 11,
     GeneratorExp_kind: Final[i32] = 12,
     Await_kind: Final[i32] = 13,
     Yield_kind: Final[i32] = 14,
     YieldFrom_kind: Final[i32] = 15,
     Compare_kind: Final[i32] = 16,
     Call_kind: Final[i32] = 17,
     FormattedValue_kind: Final[i32] = 18,
     Interpolation_kind: Final[i32] = 19,
     JoinedStr_kind: Final[i32] = 20,
     TemplateStr_kind: Final[i32] = 21,
     Constant_kind: Final[i32] = 22,
     Attribute_kind: Final[i32] = 23,
     Subscript_kind: Final[i32] = 24,
     Starred_kind: Final[i32] = 25,
     Name_kind: Final[i32] = 26,
     List_kind: Final[i32] = 27,
     Tuple_kind: Final[i32] = 28,
     Slice_kind: Final[i32] = 29,
     Load: Final[i32] = 1,
     Store: Final[i32] = 2,
     Del: Final[i32] = 3,
     And: Final[i32] = 1,
     Or: Final[i32] = 2,
     Add: Final[i32] = 1,
     Sub: Final[i32] = 2,
     Mult: Final[i32] = 3,
     MatMult: Final[i32] = 4,
     Div: Final[i32] = 5,
     Mod: Final[i32] = 6,
     Pow: Final[i32] = 7,
     LShift: Final[i32] = 8,
     RShift: Final[i32] = 9,
     BitOr: Final[i32] = 10,
     BitXor: Final[i32] = 11,
     BitAnd: Final[i32] = 12,
     FloorDiv: Final[i32] = 13,
     Invert: Final[i32] = 1,
     Not: Final[i32] = 2,
     UAdd: Final[i32] = 3,
     USub: Final[i32] = 4,
     Eq: Final[i32] = 1,
     NotEq: Final[i32] = 2,
     Lt: Final[i32] = 3,
     LtE: Final[i32] = 4,
     Gt: Final[i32] = 5,
     GtE: Final[i32] = 6,
     Is: Final[i32] = 7,
     IsNot: Final[i32] = 8,
     In: Final[i32] = 9,
     NotIn: Final[i32] = 10,
     ExceptHandler_kind: Final[i32] = 1,
     MatchValue_kind: Final[i32] = 1,
     MatchSingleton_kind: Final[i32] = 2,
     MatchSequence_kind: Final[i32] = 3,
     MatchMapping_kind: Final[i32] = 4,
     MatchClass_kind: Final[i32] = 5,
     MatchStar_kind: Final[i32] = 6,
     MatchAs_kind: Final[i32] = 7,
     MatchOr_kind: Final[i32] = 8,
     TypeIgnore_kind: Final[i32] = 1,
     TypeVar_kind: Final[i32] = 1,
     ParamSpec_kind: Final[i32] = 2,
     TypeVarTuple_kind: Final[i32] = 3,
     _mod_SIZE: Final[u64] = 24,
     _stmt_SIZE: Final[u64] = 80,
     _expr_SIZE: Final[u64] = 56,
     _comprehension_SIZE: Final[u64] = 32,
     _excepthandler_SIZE: Final[u64] = 48,
     _arguments_SIZE: Final[u64] = 56,
     _arg_SIZE: Final[u64] = 40,
     _keyword_SIZE: Final[u64] = 32,
     _alias_SIZE: Final[u64] = 32,
     _withitem_SIZE: Final[u64] = 16,
     _match_case_SIZE: Final[u64] = 24,
     _pattern_SIZE: Final[u64] = 56,
     _type_ignore_SIZE: Final[u64] = 24,
     _type_param_SIZE: Final[u64] = 48,
     AST_UNION_OFFSET: Final[i64] = 8;

import from c {
    obj _mod_Module {
        has body: ptr[asdl_seq],
            type_ignores: ptr[asdl_seq];
    }  obj _mod_Interactive {
        has body: ptr[asdl_seq];
    }  obj _mod_Expression {
        has body: ptr[_expr];
    }  obj _mod_FunctionType {
        has argtypes: ptr[asdl_seq],
            returns: ptr[_expr];
    }  obj _mod {
        has kind: i32,
            v: _mod_Module;
    }  obj _stmt_FunctionDef {
        has name: ptr[PyObject],
            args: ptr[_arguments],
            body: ptr[asdl_seq],
            decorator_list: ptr[asdl_seq],
            returns: ptr[_expr],
            type_comment: ptr[PyObject],
            type_params: ptr[asdl_seq];
    }  obj _stmt_AsyncFunctionDef {
        has name: ptr[PyObject],
            args: ptr[_arguments],
            body: ptr[asdl_seq],
            decorator_list: ptr[asdl_seq],
            returns: ptr[_expr],
            type_comment: ptr[PyObject],
            type_params: ptr[asdl_seq];
    }  obj _stmt_ClassDef {
        has name: ptr[PyObject],
            bases: ptr[asdl_seq],
            keywords: ptr[asdl_seq],
            body: ptr[asdl_seq],
            decorator_list: ptr[asdl_seq],
            type_params: ptr[asdl_seq];
    }  obj _stmt_Return {
        has value: ptr[_expr];
    }  obj _stmt_Delete {
        has targets: ptr[asdl_seq];
    }  obj _stmt_Assign {
        has targets: ptr[asdl_seq],
            value: ptr[_expr],
            type_comment: ptr[PyObject];
    }  obj _stmt_TypeAlias {
        has name: ptr[_expr],
            type_params: ptr[asdl_seq],
            value: ptr[_expr];
    }  obj _stmt_AugAssign {
        has target: ptr[_expr],
            op: i32,
            value: ptr[_expr];
    }  obj _stmt_AnnAssign {
        has target: ptr[_expr],
            annotation: ptr[_expr],
            value: ptr[_expr],
            simple: i32;
    }  obj _stmt_For {
        has target: ptr[_expr],
            iter: ptr[_expr],
            body: ptr[asdl_seq],
            orelse: ptr[asdl_seq],
            type_comment: ptr[PyObject];
    }  obj _stmt_AsyncFor {
        has target: ptr[_expr],
            iter: ptr[_expr],
            body: ptr[asdl_seq],
            orelse: ptr[asdl_seq],
            type_comment: ptr[PyObject];
    }  obj _stmt_While {
        has test_: ptr[_expr],
            body: ptr[asdl_seq],
            orelse: ptr[asdl_seq];
    }  obj _stmt_If {
        has test_: ptr[_expr],
            body: ptr[asdl_seq],
            orelse: ptr[asdl_seq];
    }  obj _stmt_With {
        has items: ptr[asdl_seq],
            body: ptr[asdl_seq],
            type_comment: ptr[PyObject];
    }  obj _stmt_AsyncWith {
        has items: ptr[asdl_seq],
            body: ptr[asdl_seq],
            type_comment: ptr[PyObject];
    }  obj _stmt_Match {
        has subject: ptr[_expr],
            cases: ptr[asdl_seq];
    }  obj _stmt_Raise {
        has exc: ptr[_expr],
            cause: ptr[_expr];
    }  obj _stmt_Try {
        has body: ptr[asdl_seq],
            handlers: ptr[asdl_seq],
            orelse: ptr[asdl_seq],
            finalbody: ptr[asdl_seq];
    }  obj _stmt_TryStar {
        has body: ptr[asdl_seq],
            handlers: ptr[asdl_seq],
            orelse: ptr[asdl_seq],
            finalbody: ptr[asdl_seq];
    }  obj _stmt_Assert {
        has test_: ptr[_expr],
            msg: ptr[_expr];
    }  obj _stmt_Import {
        has names: ptr[asdl_seq];
    }  obj _stmt_ImportFrom {
        has module: ptr[PyObject],
            names: ptr[asdl_seq],
            level: i32;
    }  obj _stmt_Global {
        has names: ptr[asdl_seq];
    }  obj _stmt_Nonlocal {
        has names: ptr[asdl_seq];
    }  obj _stmt_Expr {
        has value: ptr[_expr];
    }  obj _stmt {
        has kind: i32,
            v: _stmt_FunctionDef,
            lineno: i32,
            col_offset: i32,
            end_lineno: i32,
            end_col_offset: i32;
    }  obj _expr_BoolOp {
        has op: i32,
            values: ptr[asdl_seq];
    }  obj _expr_NamedExpr {
        has target: ptr[_expr],
            value: ptr[_expr];
    }  obj _expr_BinOp {
        has left: ptr[_expr],
            op: i32,
            right: ptr[_expr];
    }  obj _expr_UnaryOp {
        has op: i32,
            operand: ptr[_expr];
    }  obj _expr_Lambda {
        has args: ptr[_arguments],
            body: ptr[_expr];
    }  obj _expr_IfExp {
        has test_: ptr[_expr],
            body: ptr[_expr],
            orelse: ptr[_expr];
    }  obj _expr_Dict {
        has keys: ptr[asdl_seq],
            values: ptr[asdl_seq];
    }  obj _expr_Set {
        has elts: ptr[asdl_seq];
    }  obj _expr_ListComp {
        has elt: ptr[_expr],
            generators: ptr[asdl_seq];
    }  obj _expr_SetComp {
        has elt: ptr[_expr],
            generators: ptr[asdl_seq];
    }  obj _expr_DictComp {
        has key: ptr[_expr],
            value: ptr[_expr],
            generators: ptr[asdl_seq];
    }  obj _expr_GeneratorExp {
        has elt: ptr[_expr],
            generators: ptr[asdl_seq];
    }  obj _expr_Await {
        has value: ptr[_expr];
    }  obj _expr_Yield {
        has value: ptr[_expr];
    }  obj _expr_YieldFrom {
        has value: ptr[_expr];
    }  obj _expr_Compare {
        has left: ptr[_expr],
            ops: ptr[asdl_seq],
            comparators: ptr[asdl_seq];
    }  obj _expr_Call {
        has func: ptr[_expr],
            args: ptr[asdl_seq],
            keywords: ptr[asdl_seq];
    }  obj _expr_FormattedValue {
        has value: ptr[_expr],
            conversion: i32,
            format_spec: ptr[_expr];
    }  obj _expr_Interpolation {
        has value: ptr[_expr],
            str_: ptr[PyObject],
            conversion: i32,
            format_spec: ptr[_expr];
    }  obj _expr_JoinedStr {
        has values: ptr[asdl_seq];
    }  obj _expr_TemplateStr {
        has values: ptr[asdl_seq];
    }  obj _expr_Constant {
        has value: ptr[PyObject],
            kind: ptr[PyObject];
    }  obj _expr_Attribute {
        has value: ptr[_expr],
            attr: ptr[PyObject],
            ctx: i32;
    }  obj _expr_Subscript {
        has value: ptr[_expr],
            slice: ptr[_expr],
            ctx: i32;
    }  obj _expr_Starred {
        has value: ptr[_expr],
            ctx: i32;
    }  obj _expr_Name {
        has id: ptr[PyObject],
            ctx: i32;
    }  obj _expr_List {
        has elts: ptr[asdl_seq],
            ctx: i32;
    }  obj _expr_Tuple {
        has elts: ptr[asdl_seq],
            ctx: i32;
    }  obj _expr_Slice {
        has lower: ptr[_expr],
            upper: ptr[_expr],
            step: ptr[_expr];
    }  obj _expr {
        has kind: i32,
            v: _expr_Interpolation,
            lineno: i32,
            col_offset: i32,
            end_lineno: i32,
            end_col_offset: i32;
    }  obj _comprehension {
        has target: ptr[_expr],
            iter: ptr[_expr],
            ifs: ptr[asdl_seq],
            is_async: i32;
    }  obj _excepthandler_ExceptHandler {
        has type: ptr[_expr],
            name: ptr[PyObject],
            body: ptr[asdl_seq];
    }  obj _excepthandler {
        has kind: i32,
            v: _excepthandler_ExceptHandler,
            lineno: i32,
            col_offset: i32,
            end_lineno: i32,
            end_col_offset: i32;
    }  obj _arguments {
        has posonlyargs: ptr[asdl_seq],
            args: ptr[asdl_seq],
            vararg: ptr[_arg],
            kwonlyargs: ptr[asdl_seq],
            kw_defaults: ptr[asdl_seq],
            kwarg: ptr[_arg],
            defaults: ptr[asdl_seq];
    }  obj _arg {
        has arg: ptr[PyObject],
            annotation: ptr[_expr],
            type_comment: ptr[PyObject],
            lineno: i32,
            col_offset: i32,
            end_lineno: i32,
            end_col_offset: i32;
    }  obj _keyword {
        has arg: ptr[PyObject],
            value: ptr[_expr],
            lineno: i32,
            col_offset: i32,
            end_lineno: i32,
            end_col_offset: i32;
    }  obj _alias {
        has name: ptr[PyObject],
            asname: ptr[PyObject],
            lineno: i32,
            col_offset: i32,
            end_lineno: i32,
            end_col_offset: i32;
    }  obj _withitem {
        has context_expr: ptr[_expr],
            optional_vars: ptr[_expr];
    }  obj _match_case {
        has pattern: ptr[_pattern],
            guard: ptr[_expr],
            body: ptr[asdl_seq];
    }  obj _pattern_MatchValue {
        has value: ptr[_expr];
    }  obj _pattern_MatchSingleton {
        has value: ptr[PyObject];
    }  obj _pattern_MatchSequence {
        has patterns: ptr[asdl_seq];
    }  obj _pattern_MatchMapping {
        has keys: ptr[asdl_seq],
            patterns: ptr[asdl_seq],
            rest: ptr[PyObject];
    }  obj _pattern_MatchClass {
        has cls: ptr[_expr],
            patterns: ptr[asdl_seq],
            kwd_attrs: ptr[asdl_seq],
            kwd_patterns: ptr[asdl_seq];
    }  obj _pattern_MatchStar {
        has name: ptr[PyObject];
    }  obj _pattern_MatchAs {
        has pattern: ptr[_pattern],
            name: ptr[PyObject];
    }  obj _pattern_MatchOr {
        has patterns: ptr[asdl_seq];
    }  obj _pattern {
        has kind: i32,
            v: _pattern_MatchClass,
            lineno: i32,
            col_offset: i32,
            end_lineno: i32,
            end_col_offset: i32;
    }  obj _type_ignore_TypeIgnore {
        has lineno: i32,
            tag: ptr[PyObject];
    }  obj _type_ignore {
        has kind: i32,
            v: _type_ignore_TypeIgnore;
    }  obj _type_param_TypeVar {
        has name: ptr[PyObject],
            bound: ptr[_expr],
            default_value: ptr[_expr];
    }  obj _type_param_ParamSpec {
        has name: ptr[PyObject],
            default_value: ptr[_expr];
    }  obj _type_param_TypeVarTuple {
        has name: ptr[PyObject],
            default_value: ptr[_expr];
    }  obj _type_param {
        has kind: i32,
            v: _type_param_TypeVar,
            lineno: i32,
            col_offset: i32,
            end_lineno: i32,
            end_col_offset: i32;
    }  glob:priv Module_fields: list[ptr[u8]] = [
             ptr[u8]("body"),
             ptr[u8]("type_ignores")
         ],
         Interactive_fields: list[ptr[u8]] = [ptr[u8]("body")],
         Expression_fields: list[ptr[u8]] = [ptr[u8]("body")],
         FunctionType_fields: list[ptr[u8]] = [ptr[u8]("argtypes"), ptr[u8]("returns")],
         stmt_attributes: list[ptr[u8]] = [
             ptr[u8]("lineno"),
             ptr[u8]("col_offset"),
             ptr[u8]("end_lineno"),
             ptr[u8]("end_col_offset")
         ],
         FunctionDef_fields: list[ptr[u8]] = [
             ptr[u8]("name"),
             ptr[u8]("args"),
             ptr[u8]("body"),
             ptr[u8]("decorator_list"),
             ptr[u8]("returns"),
             ptr[u8]("type_comment"),
             ptr[u8]("type_params")
         ],
         AsyncFunctionDef_fields: list[ptr[u8]] = [
             ptr[u8]("name"),
             ptr[u8]("args"),
             ptr[u8]("body"),
             ptr[u8]("decorator_list"),
             ptr[u8]("returns"),
             ptr[u8]("type_comment"),
             ptr[u8]("type_params")
         ],
         ClassDef_fields: list[ptr[u8]] = [
             ptr[u8]("name"),
             ptr[u8]("bases"),
             ptr[u8]("keywords"),
             ptr[u8]("body"),
             ptr[u8]("decorator_list"),
             ptr[u8]("type_params")
         ],
         Return_fields: list[ptr[u8]] = [ptr[u8]("value")],
         Delete_fields: list[ptr[u8]] = [ptr[u8]("targets")],
         Assign_fields: list[ptr[u8]] = [
             ptr[u8]("targets"),
             ptr[u8]("value"),
             ptr[u8]("type_comment")
         ],
         TypeAlias_fields: list[ptr[u8]] = [
             ptr[u8]("name"),
             ptr[u8]("type_params"),
             ptr[u8]("value")
         ],
         AugAssign_fields: list[ptr[u8]] = [
             ptr[u8]("target"),
             ptr[u8]("op"),
             ptr[u8]("value")
         ],
         AnnAssign_fields: list[ptr[u8]] = [
             ptr[u8]("target"),
             ptr[u8]("annotation"),
             ptr[u8]("value"),
             ptr[u8]("simple")
         ],
         For_fields: list[ptr[u8]] = [
             ptr[u8]("target"),
             ptr[u8]("iter"),
             ptr[u8]("body"),
             ptr[u8]("orelse"),
             ptr[u8]("type_comment")
         ],
         AsyncFor_fields: list[ptr[u8]] = [
             ptr[u8]("target"),
             ptr[u8]("iter"),
             ptr[u8]("body"),
             ptr[u8]("orelse"),
             ptr[u8]("type_comment")
         ],
         While_fields: list[ptr[u8]] = [
             ptr[u8]("test"),
             ptr[u8]("body"),
             ptr[u8]("orelse")
         ],
         If_fields: list[ptr[u8]] = [
             ptr[u8]("test"),
             ptr[u8]("body"),
             ptr[u8]("orelse")
         ],
         With_fields: list[ptr[u8]] = [
             ptr[u8]("items"),
             ptr[u8]("body"),
             ptr[u8]("type_comment")
         ],
         AsyncWith_fields: list[ptr[u8]] = [
             ptr[u8]("items"),
             ptr[u8]("body"),
             ptr[u8]("type_comment")
         ],
         Match_fields: list[ptr[u8]] = [ptr[u8]("subject"), ptr[u8]("cases")],
         Raise_fields: list[ptr[u8]] = [ptr[u8]("exc"), ptr[u8]("cause")],
         Try_fields: list[ptr[u8]] = [
             ptr[u8]("body"),
             ptr[u8]("handlers"),
             ptr[u8]("orelse"),
             ptr[u8]("finalbody")
         ],
         TryStar_fields: list[ptr[u8]] = [
             ptr[u8]("body"),
             ptr[u8]("handlers"),
             ptr[u8]("orelse"),
             ptr[u8]("finalbody")
         ],
         Assert_fields: list[ptr[u8]] = [ptr[u8]("test"), ptr[u8]("msg")],
         Import_fields: list[ptr[u8]] = [ptr[u8]("names")],
         ImportFrom_fields: list[ptr[u8]] = [
             ptr[u8]("module"),
             ptr[u8]("names"),
             ptr[u8]("level")
         ],
         Global_fields: list[ptr[u8]] = [ptr[u8]("names")],
         Nonlocal_fields: list[ptr[u8]] = [ptr[u8]("names")],
         Expr_fields: list[ptr[u8]] = [ptr[u8]("value")],
         expr_attributes: list[ptr[u8]] = [
             ptr[u8]("lineno"),
             ptr[u8]("col_offset"),
             ptr[u8]("end_lineno"),
             ptr[u8]("end_col_offset")
         ],
         BoolOp_fields: list[ptr[u8]] = [ptr[u8]("op"), ptr[u8]("values")],
         NamedExpr_fields: list[ptr[u8]] = [ptr[u8]("target"), ptr[u8]("value")],
         BinOp_fields: list[ptr[u8]] = [
             ptr[u8]("left"),
             ptr[u8]("op"),
             ptr[u8]("right")
         ],
         UnaryOp_fields: list[ptr[u8]] = [ptr[u8]("op"), ptr[u8]("operand")],
         Lambda_fields: list[ptr[u8]] = [ptr[u8]("args"), ptr[u8]("body")],
         IfExp_fields: list[ptr[u8]] = [
             ptr[u8]("test"),
             ptr[u8]("body"),
             ptr[u8]("orelse")
         ],
         Dict_fields: list[ptr[u8]] = [ptr[u8]("keys"), ptr[u8]("values")],
         Set_fields: list[ptr[u8]] = [ptr[u8]("elts")],
         ListComp_fields: list[ptr[u8]] = [ptr[u8]("elt"), ptr[u8]("generators")],
         SetComp_fields: list[ptr[u8]] = [ptr[u8]("elt"), ptr[u8]("generators")],
         DictComp_fields: list[ptr[u8]] = [
             ptr[u8]("key"),
             ptr[u8]("value"),
             ptr[u8]("generators")
         ],
         GeneratorExp_fields: list[ptr[u8]] = [ptr[u8]("elt"), ptr[u8]("generators")],
         Await_fields: list[ptr[u8]] = [ptr[u8]("value")],
         Yield_fields: list[ptr[u8]] = [ptr[u8]("value")],
         YieldFrom_fields: list[ptr[u8]] = [ptr[u8]("value")],
         Compare_fields: list[ptr[u8]] = [
             ptr[u8]("left"),
             ptr[u8]("ops"),
             ptr[u8]("comparators")
         ],
         Call_fields: list[ptr[u8]] = [
             ptr[u8]("func"),
             ptr[u8]("args"),
             ptr[u8]("keywords")
         ],
         FormattedValue_fields: list[ptr[u8]] = [
             ptr[u8]("value"),
             ptr[u8]("conversion"),
             ptr[u8]("format_spec")
         ],
         Interpolation_fields: list[ptr[u8]] = [
             ptr[u8]("value"),
             ptr[u8]("str"),
             ptr[u8]("conversion"),
             ptr[u8]("format_spec")
         ],
         JoinedStr_fields: list[ptr[u8]] = [ptr[u8]("values")],
         TemplateStr_fields: list[ptr[u8]] = [ptr[u8]("values")],
         Constant_fields: list[ptr[u8]] = [ptr[u8]("value"), ptr[u8]("kind")],
         Attribute_fields: list[ptr[u8]] = [
             ptr[u8]("value"),
             ptr[u8]("attr"),
             ptr[u8]("ctx")
         ],
         Subscript_fields: list[ptr[u8]] = [
             ptr[u8]("value"),
             ptr[u8]("slice"),
             ptr[u8]("ctx")
         ],
         Starred_fields: list[ptr[u8]] = [ptr[u8]("value"), ptr[u8]("ctx")],
         Name_fields: list[ptr[u8]] = [ptr[u8]("id"), ptr[u8]("ctx")],
         List_fields: list[ptr[u8]] = [ptr[u8]("elts"), ptr[u8]("ctx")],
         Tuple_fields: list[ptr[u8]] = [ptr[u8]("elts"), ptr[u8]("ctx")],
         Slice_fields: list[ptr[u8]] = [
             ptr[u8]("lower"),
             ptr[u8]("upper"),
             ptr[u8]("step")
         ],
         comprehension_fields: list[ptr[u8]] = [
             ptr[u8]("target"),
             ptr[u8]("iter"),
             ptr[u8]("ifs"),
             ptr[u8]("is_async")
         ],
         excepthandler_attributes: list[ptr[u8]] = [
             ptr[u8]("lineno"),
             ptr[u8]("col_offset"),
             ptr[u8]("end_lineno"),
             ptr[u8]("end_col_offset")
         ],
         ExceptHandler_fields: list[ptr[u8]] = [
             ptr[u8]("type"),
             ptr[u8]("name"),
             ptr[u8]("body")
         ],
         arguments_fields: list[ptr[u8]] = [
             ptr[u8]("posonlyargs"),
             ptr[u8]("args"),
             ptr[u8]("vararg"),
             ptr[u8]("kwonlyargs"),
             ptr[u8]("kw_defaults"),
             ptr[u8]("kwarg"),
             ptr[u8]("defaults")
         ],
         arg_attributes: list[ptr[u8]] = [
             ptr[u8]("lineno"),
             ptr[u8]("col_offset"),
             ptr[u8]("end_lineno"),
             ptr[u8]("end_col_offset")
         ],
         arg_fields: list[ptr[u8]] = [
             ptr[u8]("arg"),
             ptr[u8]("annotation"),
             ptr[u8]("type_comment")
         ],
         keyword_attributes: list[ptr[u8]] = [
             ptr[u8]("lineno"),
             ptr[u8]("col_offset"),
             ptr[u8]("end_lineno"),
             ptr[u8]("end_col_offset")
         ],
         keyword_fields: list[ptr[u8]] = [ptr[u8]("arg"), ptr[u8]("value")],
         alias_attributes: list[ptr[u8]] = [
             ptr[u8]("lineno"),
             ptr[u8]("col_offset"),
             ptr[u8]("end_lineno"),
             ptr[u8]("end_col_offset")
         ],
         alias_fields: list[ptr[u8]] = [ptr[u8]("name"), ptr[u8]("asname")],
         withitem_fields: list[ptr[u8]] = [
             ptr[u8]("context_expr"),
             ptr[u8]("optional_vars")
         ],
         match_case_fields: list[ptr[u8]] = [
             ptr[u8]("pattern"),
             ptr[u8]("guard"),
             ptr[u8]("body")
         ],
         pattern_attributes: list[ptr[u8]] = [
             ptr[u8]("lineno"),
             ptr[u8]("col_offset"),
             ptr[u8]("end_lineno"),
             ptr[u8]("end_col_offset")
         ],
         MatchValue_fields: list[ptr[u8]] = [ptr[u8]("value")],
         MatchSingleton_fields: list[ptr[u8]] = [ptr[u8]("value")],
         MatchSequence_fields: list[ptr[u8]] = [ptr[u8]("patterns")],
         MatchMapping_fields: list[ptr[u8]] = [
             ptr[u8]("keys"),
             ptr[u8]("patterns"),
             ptr[u8]("rest")
         ],
         MatchClass_fields: list[ptr[u8]] = [
             ptr[u8]("cls"),
             ptr[u8]("patterns"),
             ptr[u8]("kwd_attrs"),
             ptr[u8]("kwd_patterns")
         ],
         MatchStar_fields: list[ptr[u8]] = [ptr[u8]("name")],
         MatchAs_fields: list[ptr[u8]] = [ptr[u8]("pattern"), ptr[u8]("name")],
         MatchOr_fields: list[ptr[u8]] = [ptr[u8]("patterns")],
         TypeIgnore_fields: list[ptr[u8]] = [ptr[u8]("lineno"), ptr[u8]("tag")],
         type_param_attributes: list[ptr[u8]] = [
             ptr[u8]("lineno"),
             ptr[u8]("col_offset"),
             ptr[u8]("end_lineno"),
             ptr[u8]("end_col_offset")
         ],
         TypeVar_fields: list[ptr[u8]] = [
             ptr[u8]("name"),
             ptr[u8]("bound"),
             ptr[u8]("default_value")
         ],
         ParamSpec_fields: list[ptr[u8]] = [ptr[u8]("name"), ptr[u8]("default_value")],
         TypeVarTuple_fields: list[ptr[u8]] = [
             ptr[u8]("name"),
             ptr[u8]("default_value")
         ];
}

import from c {
    def _PyAST_Fini(interp: ptr[u8]) {
        state = ptr[ast_state](interp + PyInterpreterState_AST);
        old = NULL;
        old = state.view(1)[0].AST_type;
        state.view(1)[0].AST_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Add_singleton;
        state.view(1)[0].Add_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Add_type;
        state.view(1)[0].Add_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].And_singleton;
        state.view(1)[0].And_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].And_type;
        state.view(1)[0].And_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].AnnAssign_type;
        state.view(1)[0].AnnAssign_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Assert_type;
        state.view(1)[0].Assert_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Assign_type;
        state.view(1)[0].Assign_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].AsyncFor_type;
        state.view(1)[0].AsyncFor_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].AsyncFunctionDef_type;
        state.view(1)[0].AsyncFunctionDef_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].AsyncWith_type;
        state.view(1)[0].AsyncWith_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Attribute_type;
        state.view(1)[0].Attribute_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].AugAssign_type;
        state.view(1)[0].AugAssign_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Await_type;
        state.view(1)[0].Await_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].BinOp_type;
        state.view(1)[0].BinOp_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].BitAnd_singleton;
        state.view(1)[0].BitAnd_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].BitAnd_type;
        state.view(1)[0].BitAnd_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].BitOr_singleton;
        state.view(1)[0].BitOr_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].BitOr_type;
        state.view(1)[0].BitOr_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].BitXor_singleton;
        state.view(1)[0].BitXor_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].BitXor_type;
        state.view(1)[0].BitXor_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].BoolOp_type;
        state.view(1)[0].BoolOp_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Break_type;
        state.view(1)[0].Break_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Call_type;
        state.view(1)[0].Call_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].ClassDef_type;
        state.view(1)[0].ClassDef_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Compare_type;
        state.view(1)[0].Compare_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Constant_type;
        state.view(1)[0].Constant_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Continue_type;
        state.view(1)[0].Continue_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Del_singleton;
        state.view(1)[0].Del_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Del_type;
        state.view(1)[0].Del_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Delete_type;
        state.view(1)[0].Delete_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].DictComp_type;
        state.view(1)[0].DictComp_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Dict_type;
        state.view(1)[0].Dict_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Div_singleton;
        state.view(1)[0].Div_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Div_type;
        state.view(1)[0].Div_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Eq_singleton;
        state.view(1)[0].Eq_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Eq_type;
        state.view(1)[0].Eq_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].ExceptHandler_type;
        state.view(1)[0].ExceptHandler_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Expr_type;
        state.view(1)[0].Expr_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Expression_type;
        state.view(1)[0].Expression_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].FloorDiv_singleton;
        state.view(1)[0].FloorDiv_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].FloorDiv_type;
        state.view(1)[0].FloorDiv_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].For_type;
        state.view(1)[0].For_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].FormattedValue_type;
        state.view(1)[0].FormattedValue_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].FunctionDef_type;
        state.view(1)[0].FunctionDef_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].FunctionType_type;
        state.view(1)[0].FunctionType_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].GeneratorExp_type;
        state.view(1)[0].GeneratorExp_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Global_type;
        state.view(1)[0].Global_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].GtE_singleton;
        state.view(1)[0].GtE_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].GtE_type;
        state.view(1)[0].GtE_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Gt_singleton;
        state.view(1)[0].Gt_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Gt_type;
        state.view(1)[0].Gt_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].IfExp_type;
        state.view(1)[0].IfExp_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].If_type;
        state.view(1)[0].If_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].ImportFrom_type;
        state.view(1)[0].ImportFrom_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Import_type;
        state.view(1)[0].Import_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].In_singleton;
        state.view(1)[0].In_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].In_type;
        state.view(1)[0].In_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Interactive_type;
        state.view(1)[0].Interactive_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Interpolation_type;
        state.view(1)[0].Interpolation_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Invert_singleton;
        state.view(1)[0].Invert_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Invert_type;
        state.view(1)[0].Invert_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].IsNot_singleton;
        state.view(1)[0].IsNot_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].IsNot_type;
        state.view(1)[0].IsNot_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Is_singleton;
        state.view(1)[0].Is_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Is_type;
        state.view(1)[0].Is_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].JoinedStr_type;
        state.view(1)[0].JoinedStr_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].LShift_singleton;
        state.view(1)[0].LShift_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].LShift_type;
        state.view(1)[0].LShift_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Lambda_type;
        state.view(1)[0].Lambda_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].ListComp_type;
        state.view(1)[0].ListComp_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].List_type;
        state.view(1)[0].List_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Load_singleton;
        state.view(1)[0].Load_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Load_type;
        state.view(1)[0].Load_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].LtE_singleton;
        state.view(1)[0].LtE_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].LtE_type;
        state.view(1)[0].LtE_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Lt_singleton;
        state.view(1)[0].Lt_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Lt_type;
        state.view(1)[0].Lt_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatMult_singleton;
        state.view(1)[0].MatMult_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatMult_type;
        state.view(1)[0].MatMult_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatchAs_type;
        state.view(1)[0].MatchAs_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatchClass_type;
        state.view(1)[0].MatchClass_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatchMapping_type;
        state.view(1)[0].MatchMapping_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatchOr_type;
        state.view(1)[0].MatchOr_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatchSequence_type;
        state.view(1)[0].MatchSequence_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatchSingleton_type;
        state.view(1)[0].MatchSingleton_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatchStar_type;
        state.view(1)[0].MatchStar_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].MatchValue_type;
        state.view(1)[0].MatchValue_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Match_type;
        state.view(1)[0].Match_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Mod_singleton;
        state.view(1)[0].Mod_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Mod_type;
        state.view(1)[0].Mod_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Module_type;
        state.view(1)[0].Module_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Mult_singleton;
        state.view(1)[0].Mult_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Mult_type;
        state.view(1)[0].Mult_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Name_type;
        state.view(1)[0].Name_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].NamedExpr_type;
        state.view(1)[0].NamedExpr_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Nonlocal_type;
        state.view(1)[0].Nonlocal_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].NotEq_singleton;
        state.view(1)[0].NotEq_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].NotEq_type;
        state.view(1)[0].NotEq_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].NotIn_singleton;
        state.view(1)[0].NotIn_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].NotIn_type;
        state.view(1)[0].NotIn_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Not_singleton;
        state.view(1)[0].Not_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Not_type;
        state.view(1)[0].Not_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Or_singleton;
        state.view(1)[0].Or_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Or_type;
        state.view(1)[0].Or_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].ParamSpec_type;
        state.view(1)[0].ParamSpec_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Pass_type;
        state.view(1)[0].Pass_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Pow_singleton;
        state.view(1)[0].Pow_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Pow_type;
        state.view(1)[0].Pow_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].RShift_singleton;
        state.view(1)[0].RShift_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].RShift_type;
        state.view(1)[0].RShift_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Raise_type;
        state.view(1)[0].Raise_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Return_type;
        state.view(1)[0].Return_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].SetComp_type;
        state.view(1)[0].SetComp_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Set_type;
        state.view(1)[0].Set_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Slice_type;
        state.view(1)[0].Slice_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Starred_type;
        state.view(1)[0].Starred_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Store_singleton;
        state.view(1)[0].Store_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Store_type;
        state.view(1)[0].Store_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Sub_singleton;
        state.view(1)[0].Sub_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Sub_type;
        state.view(1)[0].Sub_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Subscript_type;
        state.view(1)[0].Subscript_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].TemplateStr_type;
        state.view(1)[0].TemplateStr_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].TryStar_type;
        state.view(1)[0].TryStar_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Try_type;
        state.view(1)[0].Try_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Tuple_type;
        state.view(1)[0].Tuple_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].TypeAlias_type;
        state.view(1)[0].TypeAlias_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].TypeIgnore_type;
        state.view(1)[0].TypeIgnore_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].TypeVarTuple_type;
        state.view(1)[0].TypeVarTuple_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].TypeVar_type;
        state.view(1)[0].TypeVar_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].UAdd_singleton;
        state.view(1)[0].UAdd_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].UAdd_type;
        state.view(1)[0].UAdd_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].USub_singleton;
        state.view(1)[0].USub_singleton = NULL;
        object_xdecref(old);
        old = state.view(1)[0].USub_type;
        state.view(1)[0].USub_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].UnaryOp_type;
        state.view(1)[0].UnaryOp_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].While_type;
        state.view(1)[0].While_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].With_type;
        state.view(1)[0].With_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].YieldFrom_type;
        state.view(1)[0].YieldFrom_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].Yield_type;
        state.view(1)[0].Yield_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].__dict__;
        state.view(1)[0].__dict__ = NULL;
        object_xdecref(old);
        old = state.view(1)[0].__doc__;
        state.view(1)[0].__doc__ = NULL;
        object_xdecref(old);
        old = state.view(1)[0].__match_args__;
        state.view(1)[0].__match_args__ = NULL;
        object_xdecref(old);
        old = state.view(1)[0].__module__;
        state.view(1)[0].__module__ = NULL;
        object_xdecref(old);
        old = state.view(1)[0]._attributes;
        state.view(1)[0]._attributes = NULL;
        object_xdecref(old);
        old = state.view(1)[0]._fields;
        state.view(1)[0]._fields = NULL;
        object_xdecref(old);
        old = state.view(1)[0].alias_type;
        state.view(1)[0].alias_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].annotation;
        state.view(1)[0].annotation = NULL;
        object_xdecref(old);
        old = state.view(1)[0].arg;
        state.view(1)[0].arg = NULL;
        object_xdecref(old);
        old = state.view(1)[0].arg_type;
        state.view(1)[0].arg_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].args;
        state.view(1)[0].args = NULL;
        object_xdecref(old);
        old = state.view(1)[0].argtypes;
        state.view(1)[0].argtypes = NULL;
        object_xdecref(old);
        old = state.view(1)[0].arguments_type;
        state.view(1)[0].arguments_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].asname;
        state.view(1)[0].asname = NULL;
        object_xdecref(old);
        old = state.view(1)[0].ast;
        state.view(1)[0].ast = NULL;
        object_xdecref(old);
        old = state.view(1)[0].attr;
        state.view(1)[0].attr = NULL;
        object_xdecref(old);
        old = state.view(1)[0].bases;
        state.view(1)[0].bases = NULL;
        object_xdecref(old);
        old = state.view(1)[0].body;
        state.view(1)[0].body = NULL;
        object_xdecref(old);
        old = state.view(1)[0].boolop_type;
        state.view(1)[0].boolop_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].bound;
        state.view(1)[0].bound = NULL;
        object_xdecref(old);
        old = state.view(1)[0].cases;
        state.view(1)[0].cases = NULL;
        object_xdecref(old);
        old = state.view(1)[0].cause;
        state.view(1)[0].cause = NULL;
        object_xdecref(old);
        old = state.view(1)[0].cls;
        state.view(1)[0].cls = NULL;
        object_xdecref(old);
        old = state.view(1)[0].cmpop_type;
        state.view(1)[0].cmpop_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].col_offset;
        state.view(1)[0].col_offset = NULL;
        object_xdecref(old);
        old = state.view(1)[0].comparators;
        state.view(1)[0].comparators = NULL;
        object_xdecref(old);
        old = state.view(1)[0].comprehension_type;
        state.view(1)[0].comprehension_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].context_expr;
        state.view(1)[0].context_expr = NULL;
        object_xdecref(old);
        old = state.view(1)[0].conversion;
        state.view(1)[0].conversion = NULL;
        object_xdecref(old);
        old = state.view(1)[0].ctx;
        state.view(1)[0].ctx = NULL;
        object_xdecref(old);
        old = state.view(1)[0].decorator_list;
        state.view(1)[0].decorator_list = NULL;
        object_xdecref(old);
        old = state.view(1)[0].default_value;
        state.view(1)[0].default_value = NULL;
        object_xdecref(old);
        old = state.view(1)[0].defaults;
        state.view(1)[0].defaults = NULL;
        object_xdecref(old);
        old = state.view(1)[0].elt;
        state.view(1)[0].elt = NULL;
        object_xdecref(old);
        old = state.view(1)[0].elts;
        state.view(1)[0].elts = NULL;
        object_xdecref(old);
        old = state.view(1)[0].end_col_offset;
        state.view(1)[0].end_col_offset = NULL;
        object_xdecref(old);
        old = state.view(1)[0].end_lineno;
        state.view(1)[0].end_lineno = NULL;
        object_xdecref(old);
        old = state.view(1)[0].exc;
        state.view(1)[0].exc = NULL;
        object_xdecref(old);
        old = state.view(1)[0].excepthandler_type;
        state.view(1)[0].excepthandler_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].expr_context_type;
        state.view(1)[0].expr_context_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].expr_type;
        state.view(1)[0].expr_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].finalbody;
        state.view(1)[0].finalbody = NULL;
        object_xdecref(old);
        old = state.view(1)[0].format_spec;
        state.view(1)[0].format_spec = NULL;
        object_xdecref(old);
        old = state.view(1)[0].func;
        state.view(1)[0].func = NULL;
        object_xdecref(old);
        old = state.view(1)[0].generators;
        state.view(1)[0].generators = NULL;
        object_xdecref(old);
        old = state.view(1)[0].guard;
        state.view(1)[0].guard = NULL;
        object_xdecref(old);
        old = state.view(1)[0].handlers;
        state.view(1)[0].handlers = NULL;
        object_xdecref(old);
        old = state.view(1)[0].id;
        state.view(1)[0].id = NULL;
        object_xdecref(old);
        old = state.view(1)[0].ifs;
        state.view(1)[0].ifs = NULL;
        object_xdecref(old);
        old = state.view(1)[0].is_async;
        state.view(1)[0].is_async = NULL;
        object_xdecref(old);
        old = state.view(1)[0].items;
        state.view(1)[0].items = NULL;
        object_xdecref(old);
        old = state.view(1)[0].iter;
        state.view(1)[0].iter = NULL;
        object_xdecref(old);
        old = state.view(1)[0].key;
        state.view(1)[0].key = NULL;
        object_xdecref(old);
        old = state.view(1)[0].keys;
        state.view(1)[0].keys = NULL;
        object_xdecref(old);
        old = state.view(1)[0].keyword_type;
        state.view(1)[0].keyword_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].keywords;
        state.view(1)[0].keywords = NULL;
        object_xdecref(old);
        old = state.view(1)[0].kind;
        state.view(1)[0].kind = NULL;
        object_xdecref(old);
        old = state.view(1)[0].kw_defaults;
        state.view(1)[0].kw_defaults = NULL;
        object_xdecref(old);
        old = state.view(1)[0].kwarg;
        state.view(1)[0].kwarg = NULL;
        object_xdecref(old);
        old = state.view(1)[0].kwd_attrs;
        state.view(1)[0].kwd_attrs = NULL;
        object_xdecref(old);
        old = state.view(1)[0].kwd_patterns;
        state.view(1)[0].kwd_patterns = NULL;
        object_xdecref(old);
        old = state.view(1)[0].kwonlyargs;
        state.view(1)[0].kwonlyargs = NULL;
        object_xdecref(old);
        old = state.view(1)[0].left;
        state.view(1)[0].left = NULL;
        object_xdecref(old);
        old = state.view(1)[0].level;
        state.view(1)[0].level = NULL;
        object_xdecref(old);
        old = state.view(1)[0].lineno;
        state.view(1)[0].lineno = NULL;
        object_xdecref(old);
        old = state.view(1)[0].lower;
        state.view(1)[0].lower = NULL;
        object_xdecref(old);
        old = state.view(1)[0].match_case_type;
        state.view(1)[0].match_case_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].mod_type;
        state.view(1)[0].mod_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].module;
        state.view(1)[0].module = NULL;
        object_xdecref(old);
        old = state.view(1)[0].msg;
        state.view(1)[0].msg = NULL;
        object_xdecref(old);
        old = state.view(1)[0].name;
        state.view(1)[0].name = NULL;
        object_xdecref(old);
        old = state.view(1)[0].names;
        state.view(1)[0].names = NULL;
        object_xdecref(old);
        old = state.view(1)[0].op;
        state.view(1)[0].op = NULL;
        object_xdecref(old);
        old = state.view(1)[0].operand;
        state.view(1)[0].operand = NULL;
        object_xdecref(old);
        old = state.view(1)[0].operator_type;
        state.view(1)[0].operator_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].ops;
        state.view(1)[0].ops = NULL;
        object_xdecref(old);
        old = state.view(1)[0].optional_vars;
        state.view(1)[0].optional_vars = NULL;
        object_xdecref(old);
        old = state.view(1)[0].orelse;
        state.view(1)[0].orelse = NULL;
        object_xdecref(old);
        old = state.view(1)[0].pattern;
        state.view(1)[0].pattern = NULL;
        object_xdecref(old);
        old = state.view(1)[0].pattern_type;
        state.view(1)[0].pattern_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].patterns;
        state.view(1)[0].patterns = NULL;
        object_xdecref(old);
        old = state.view(1)[0].posonlyargs;
        state.view(1)[0].posonlyargs = NULL;
        object_xdecref(old);
        old = state.view(1)[0].rest;
        state.view(1)[0].rest = NULL;
        object_xdecref(old);
        old = state.view(1)[0].returns;
        state.view(1)[0].returns = NULL;
        object_xdecref(old);
        old = state.view(1)[0].right;
        state.view(1)[0].right = NULL;
        object_xdecref(old);
        old = state.view(1)[0].simple;
        state.view(1)[0].simple = NULL;
        object_xdecref(old);
        old = state.view(1)[0].slice;
        state.view(1)[0].slice = NULL;
        object_xdecref(old);
        old = state.view(1)[0].step;
        state.view(1)[0].step = NULL;
        object_xdecref(old);
        old = state.view(1)[0].stmt_type;
        state.view(1)[0].stmt_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].str;
        state.view(1)[0].str = NULL;
        object_xdecref(old);
        old = state.view(1)[0].subject;
        state.view(1)[0].subject = NULL;
        object_xdecref(old);
        old = state.view(1)[0].tag;
        state.view(1)[0].tag = NULL;
        object_xdecref(old);
        old = state.view(1)[0].target;
        state.view(1)[0].target = NULL;
        object_xdecref(old);
        old = state.view(1)[0].targets;
        state.view(1)[0].targets = NULL;
        object_xdecref(old);
        old = state.view(1)[0].test_;
        state.view(1)[0].test_ = NULL;
        object_xdecref(old);
        old = state.view(1)[0].type;
        state.view(1)[0].type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].type_comment;
        state.view(1)[0].type_comment = NULL;
        object_xdecref(old);
        old = state.view(1)[0].type_ignore_type;
        state.view(1)[0].type_ignore_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].type_ignores;
        state.view(1)[0].type_ignores = NULL;
        object_xdecref(old);
        old = state.view(1)[0].type_param_type;
        state.view(1)[0].type_param_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].type_params;
        state.view(1)[0].type_params = NULL;
        object_xdecref(old);
        old = state.view(1)[0].unaryop_type;
        state.view(1)[0].unaryop_type = NULL;
        object_xdecref(old);
        old = state.view(1)[0].upper;
        state.view(1)[0].upper = NULL;
        object_xdecref(old);
        old = state.view(1)[0].value;
        state.view(1)[0].value = NULL;
        object_xdecref(old);
        old = state.view(1)[0].values;
        state.view(1)[0].values = NULL;
        object_xdecref(old);
        old = state.view(1)[0].vararg;
        state.view(1)[0].vararg = NULL;
        object_xdecref(old);
        old = state.view(1)[0].withitem_type;
        state.view(1)[0].withitem_type = NULL;
        object_xdecref(old);
        state.view(1)[0].finalized = 1;
        ptr[_PyOnceFlag](state).view(1)[0].v = 0;
    }
}

def init_identifiers(state: ptr[ast_state]) -> i32;

def add_ast_annotations(state: ptr[ast_state]) -> i32;

def init_types(arg: ptr) -> i32;

import from c {
    def _Py_asdl_mod_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_stmt_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_expr_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_comprehension_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_excepthandler_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_arguments_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_arg_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_keyword_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_alias_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_withitem_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_match_case_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_pattern_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_type_ignore_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _Py_asdl_type_param_seq_new(size: i64, arena: ptr) -> ptr {
        return _Py_asdl_generic_seq_new(size, arena);
    }  def _PyAST_Module(
        body: ptr[asdl_seq], type_ignores: ptr[asdl_seq], arena: ptr
    ) -> ptr[_mod] {
        p = ptr[_mod](_PyArena_Malloc(arena, _mod_SIZE));
        if not p {
            return ptr[_mod]();
        }
        p.view(1)[0].kind = Module_kind;
        v = ptr[_mod_Module](node_union(ptr(p)));
        v.view(1)[0].body = body;
        v.view(1)[0].type_ignores = type_ignores;
        return p;
    }  def _PyAST_Interactive(body: ptr[asdl_seq], arena: ptr) -> ptr[_mod] {
        p = ptr[_mod](_PyArena_Malloc(arena, _mod_SIZE));
        if not p {
            return ptr[_mod]();
        }
        p.view(1)[0].kind = Interactive_kind;
        v = ptr[_mod_Interactive](node_union(ptr(p)));
        v.view(1)[0].body = body;
        return p;
    }  def _PyAST_Expression(body: ptr[_expr], arena: ptr) -> ptr[_mod] {
        if not body {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'body' is required for Expression")
            );
            return ptr[_mod]();
        }
        p = ptr[_mod](_PyArena_Malloc(arena, _mod_SIZE));
        if not p {
            return ptr[_mod]();
        }
        p.view(1)[0].kind = Expression_kind;
        v = ptr[_mod_Expression](node_union(ptr(p)));
        v.view(1)[0].body = body;
        return p;
    }  def _PyAST_FunctionType(
        argtypes: ptr[asdl_seq], returns: ptr[_expr], arena: ptr
    ) -> ptr[_mod] {
        if not returns {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("field 'returns' is required for FunctionType")
            );
            return ptr[_mod]();
        }
        p = ptr[_mod](_PyArena_Malloc(arena, _mod_SIZE));
        if not p {
            return ptr[_mod]();
        }
        p.view(1)[0].kind = FunctionType_kind;
        v = ptr[_mod_FunctionType](node_union(ptr(p)));
        v.view(1)[0].argtypes = argtypes;
        v.view(1)[0].returns = returns;
        return p;
    }  def _PyAST_FunctionDef(
        name: ptr[PyObject],
        args: ptr[_arguments],
        body: ptr[asdl_seq],
        decorator_list: ptr[asdl_seq],
        returns: ptr[_expr],
        type_comment: ptr[PyObject],
        type_params: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not name {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'name' is required for FunctionDef")
            );
            return ptr[_stmt]();
        }
        if not args {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'args' is required for FunctionDef")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = FunctionDef_kind;
        v = ptr[_stmt_FunctionDef](node_union(ptr(p)));
        v.view(1)[0].name = name;
        v.view(1)[0].args = args;
        v.view(1)[0].body = body;
        v.view(1)[0].decorator_list = decorator_list;
        v.view(1)[0].returns = returns;
        v.view(1)[0].type_comment = type_comment;
        v.view(1)[0].type_params = type_params;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_AsyncFunctionDef(
        name: ptr[PyObject],
        args: ptr[_arguments],
        body: ptr[asdl_seq],
        decorator_list: ptr[asdl_seq],
        returns: ptr[_expr],
        type_comment: ptr[PyObject],
        type_params: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not name {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("field 'name' is required for AsyncFunctionDef")
            );
            return ptr[_stmt]();
        }
        if not args {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("field 'args' is required for AsyncFunctionDef")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = AsyncFunctionDef_kind;
        v = ptr[_stmt_AsyncFunctionDef](node_union(ptr(p)));
        v.view(1)[0].name = name;
        v.view(1)[0].args = args;
        v.view(1)[0].body = body;
        v.view(1)[0].decorator_list = decorator_list;
        v.view(1)[0].returns = returns;
        v.view(1)[0].type_comment = type_comment;
        v.view(1)[0].type_params = type_params;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_ClassDef(
        name: ptr[PyObject],
        bases: ptr[asdl_seq],
        keywords: ptr[asdl_seq],
        body: ptr[asdl_seq],
        decorator_list: ptr[asdl_seq],
        type_params: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not name {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'name' is required for ClassDef")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = ClassDef_kind;
        v = ptr[_stmt_ClassDef](node_union(ptr(p)));
        v.view(1)[0].name = name;
        v.view(1)[0].bases = bases;
        v.view(1)[0].keywords = keywords;
        v.view(1)[0].body = body;
        v.view(1)[0].decorator_list = decorator_list;
        v.view(1)[0].type_params = type_params;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Return(
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Return_kind;
        v = ptr[_stmt_Return](node_union(ptr(p)));
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Delete(
        targets: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Delete_kind;
        v = ptr[_stmt_Delete](node_union(ptr(p)));
        v.view(1)[0].targets = targets;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Assign(
        targets: ptr[asdl_seq],
        value: ptr[_expr],
        type_comment: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for Assign")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Assign_kind;
        v = ptr[_stmt_Assign](node_union(ptr(p)));
        v.view(1)[0].targets = targets;
        v.view(1)[0].value = value;
        v.view(1)[0].type_comment = type_comment;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_TypeAlias(
        name: ptr[_expr],
        type_params: ptr[asdl_seq],
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not name {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'name' is required for TypeAlias")
            );
            return ptr[_stmt]();
        }
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for TypeAlias")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = TypeAlias_kind;
        v = ptr[_stmt_TypeAlias](node_union(ptr(p)));
        v.view(1)[0].name = name;
        v.view(1)[0].type_params = type_params;
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_AugAssign(
        target: ptr[_expr],
        op: i32,
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not target {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'target' is required for AugAssign")
            );
            return ptr[_stmt]();
        }
        if op == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'op' is required for AugAssign")
            );
            return ptr[_stmt]();
        }
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for AugAssign")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = AugAssign_kind;
        v = ptr[_stmt_AugAssign](node_union(ptr(p)));
        v.view(1)[0].target = target;
        v.view(1)[0].op = op;
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_AnnAssign(
        target: ptr[_expr],
        annotation: ptr[_expr],
        value: ptr[_expr],
        simple: i32,
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not target {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'target' is required for AnnAssign")
            );
            return ptr[_stmt]();
        }
        if not annotation {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("field 'annotation' is required for AnnAssign")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = AnnAssign_kind;
        v = ptr[_stmt_AnnAssign](node_union(ptr(p)));
        v.view(1)[0].target = target;
        v.view(1)[0].annotation = annotation;
        v.view(1)[0].value = value;
        v.view(1)[0].simple = simple;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_For(
        target: ptr[_expr],
        iter: ptr[_expr],
        body: ptr[asdl_seq],
        orelse: ptr[asdl_seq],
        type_comment: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not target {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'target' is required for For")
            );
            return ptr[_stmt]();
        }
        if not iter {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'iter' is required for For")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = For_kind;
        v = ptr[_stmt_For](node_union(ptr(p)));
        v.view(1)[0].target = target;
        v.view(1)[0].iter = iter;
        v.view(1)[0].body = body;
        v.view(1)[0].orelse = orelse;
        v.view(1)[0].type_comment = type_comment;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_AsyncFor(
        target: ptr[_expr],
        iter: ptr[_expr],
        body: ptr[asdl_seq],
        orelse: ptr[asdl_seq],
        type_comment: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not target {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'target' is required for AsyncFor")
            );
            return ptr[_stmt]();
        }
        if not iter {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'iter' is required for AsyncFor")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = AsyncFor_kind;
        v = ptr[_stmt_AsyncFor](node_union(ptr(p)));
        v.view(1)[0].target = target;
        v.view(1)[0].iter = iter;
        v.view(1)[0].body = body;
        v.view(1)[0].orelse = orelse;
        v.view(1)[0].type_comment = type_comment;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_While(
        test_: ptr[_expr],
        body: ptr[asdl_seq],
        orelse: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not test_ {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'test' is required for While")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = While_kind;
        v = ptr[_stmt_While](node_union(ptr(p)));
        v.view(1)[0].test_ = test_;
        v.view(1)[0].body = body;
        v.view(1)[0].orelse = orelse;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_If(
        test_: ptr[_expr],
        body: ptr[asdl_seq],
        orelse: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not test_ {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'test' is required for If")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = If_kind;
        v = ptr[_stmt_If](node_union(ptr(p)));
        v.view(1)[0].test_ = test_;
        v.view(1)[0].body = body;
        v.view(1)[0].orelse = orelse;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_With(
        items: ptr[asdl_seq],
        body: ptr[asdl_seq],
        type_comment: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = With_kind;
        v = ptr[_stmt_With](node_union(ptr(p)));
        v.view(1)[0].items = items;
        v.view(1)[0].body = body;
        v.view(1)[0].type_comment = type_comment;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_AsyncWith(
        items: ptr[asdl_seq],
        body: ptr[asdl_seq],
        type_comment: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = AsyncWith_kind;
        v = ptr[_stmt_AsyncWith](node_union(ptr(p)));
        v.view(1)[0].items = items;
        v.view(1)[0].body = body;
        v.view(1)[0].type_comment = type_comment;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Match(
        subject: ptr[_expr],
        cases: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not subject {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'subject' is required for Match")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Match_kind;
        v = ptr[_stmt_Match](node_union(ptr(p)));
        v.view(1)[0].subject = subject;
        v.view(1)[0].cases = cases;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Raise(
        exc: ptr[_expr],
        cause: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Raise_kind;
        v = ptr[_stmt_Raise](node_union(ptr(p)));
        v.view(1)[0].exc = exc;
        v.view(1)[0].cause = cause;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Try(
        body: ptr[asdl_seq],
        handlers: ptr[asdl_seq],
        orelse: ptr[asdl_seq],
        finalbody: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Try_kind;
        v = ptr[_stmt_Try](node_union(ptr(p)));
        v.view(1)[0].body = body;
        v.view(1)[0].handlers = handlers;
        v.view(1)[0].orelse = orelse;
        v.view(1)[0].finalbody = finalbody;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_TryStar(
        body: ptr[asdl_seq],
        handlers: ptr[asdl_seq],
        orelse: ptr[asdl_seq],
        finalbody: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = TryStar_kind;
        v = ptr[_stmt_TryStar](node_union(ptr(p)));
        v.view(1)[0].body = body;
        v.view(1)[0].handlers = handlers;
        v.view(1)[0].orelse = orelse;
        v.view(1)[0].finalbody = finalbody;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Assert(
        test_: ptr[_expr],
        msg: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not test_ {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'test' is required for Assert")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Assert_kind;
        v = ptr[_stmt_Assert](node_union(ptr(p)));
        v.view(1)[0].test_ = test_;
        v.view(1)[0].msg = msg;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Import(
        names: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Import_kind;
        v = ptr[_stmt_Import](node_union(ptr(p)));
        v.view(1)[0].names = names;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_ImportFrom(
        module: ptr[PyObject],
        names: ptr[asdl_seq],
        level: i32,
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = ImportFrom_kind;
        v = ptr[_stmt_ImportFrom](node_union(ptr(p)));
        v.view(1)[0].module = module;
        v.view(1)[0].names = names;
        v.view(1)[0].level = level;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Global(
        names: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Global_kind;
        v = ptr[_stmt_Global](node_union(ptr(p)));
        v.view(1)[0].names = names;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Nonlocal(
        names: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Nonlocal_kind;
        v = ptr[_stmt_Nonlocal](node_union(ptr(p)));
        v.view(1)[0].names = names;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Expr(
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_stmt] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for Expr")
            );
            return ptr[_stmt]();
        }
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Expr_kind;
        v = ptr[_stmt_Expr](node_union(ptr(p)));
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Pass(
        lineno: i32, col_offset: i32, end_lineno: i32, end_col_offset: i32, arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Pass_kind;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Break(
        lineno: i32, col_offset: i32, end_lineno: i32, end_col_offset: i32, arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Break_kind;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Continue(
        lineno: i32, col_offset: i32, end_lineno: i32, end_col_offset: i32, arena: ptr
    ) -> ptr[_stmt] {
        p = ptr[_stmt](_PyArena_Malloc(arena, _stmt_SIZE));
        if not p {
            return ptr[_stmt]();
        }
        p.view(1)[0].kind = Continue_kind;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_BoolOp(
        op: i32,
        values: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if op == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'op' is required for BoolOp")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = BoolOp_kind;
        v = ptr[_expr_BoolOp](node_union(ptr(p)));
        v.view(1)[0].op = op;
        v.view(1)[0].values = values;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_NamedExpr(
        target: ptr[_expr],
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not target {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'target' is required for NamedExpr")
            );
            return ptr[_expr]();
        }
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for NamedExpr")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = NamedExpr_kind;
        v = ptr[_expr_NamedExpr](node_union(ptr(p)));
        v.view(1)[0].target = target;
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_BinOp(
        left: ptr[_expr],
        op: i32,
        right: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not left {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'left' is required for BinOp")
            );
            return ptr[_expr]();
        }
        if op == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'op' is required for BinOp")
            );
            return ptr[_expr]();
        }
        if not right {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'right' is required for BinOp")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = BinOp_kind;
        v = ptr[_expr_BinOp](node_union(ptr(p)));
        v.view(1)[0].left = left;
        v.view(1)[0].op = op;
        v.view(1)[0].right = right;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_UnaryOp(
        op: i32,
        operand: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if op == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'op' is required for UnaryOp")
            );
            return ptr[_expr]();
        }
        if not operand {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'operand' is required for UnaryOp")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = UnaryOp_kind;
        v = ptr[_expr_UnaryOp](node_union(ptr(p)));
        v.view(1)[0].op = op;
        v.view(1)[0].operand = operand;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Lambda(
        args: ptr[_arguments],
        body: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not args {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'args' is required for Lambda")
            );
            return ptr[_expr]();
        }
        if not body {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'body' is required for Lambda")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Lambda_kind;
        v = ptr[_expr_Lambda](node_union(ptr(p)));
        v.view(1)[0].args = args;
        v.view(1)[0].body = body;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_IfExp(
        test_: ptr[_expr],
        body: ptr[_expr],
        orelse: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not test_ {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'test' is required for IfExp")
            );
            return ptr[_expr]();
        }
        if not body {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'body' is required for IfExp")
            );
            return ptr[_expr]();
        }
        if not orelse {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'orelse' is required for IfExp")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = IfExp_kind;
        v = ptr[_expr_IfExp](node_union(ptr(p)));
        v.view(1)[0].test_ = test_;
        v.view(1)[0].body = body;
        v.view(1)[0].orelse = orelse;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Dict(
        keys: ptr[asdl_seq],
        values: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Dict_kind;
        v = ptr[_expr_Dict](node_union(ptr(p)));
        v.view(1)[0].keys = keys;
        v.view(1)[0].values = values;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Set(
        elts: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Set_kind;
        v = ptr[_expr_Set](node_union(ptr(p)));
        v.view(1)[0].elts = elts;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_ListComp(
        elt: ptr[_expr],
        generators: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not elt {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'elt' is required for ListComp")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = ListComp_kind;
        v = ptr[_expr_ListComp](node_union(ptr(p)));
        v.view(1)[0].elt = elt;
        v.view(1)[0].generators = generators;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_SetComp(
        elt: ptr[_expr],
        generators: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not elt {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'elt' is required for SetComp")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = SetComp_kind;
        v = ptr[_expr_SetComp](node_union(ptr(p)));
        v.view(1)[0].elt = elt;
        v.view(1)[0].generators = generators;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_DictComp(
        key: ptr[_expr],
        value: ptr[_expr],
        generators: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not key {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'key' is required for DictComp")
            );
            return ptr[_expr]();
        }
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for DictComp")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = DictComp_kind;
        v = ptr[_expr_DictComp](node_union(ptr(p)));
        v.view(1)[0].key = key;
        v.view(1)[0].value = value;
        v.view(1)[0].generators = generators;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_GeneratorExp(
        elt: ptr[_expr],
        generators: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not elt {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'elt' is required for GeneratorExp")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = GeneratorExp_kind;
        v = ptr[_expr_GeneratorExp](node_union(ptr(p)));
        v.view(1)[0].elt = elt;
        v.view(1)[0].generators = generators;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Await(
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for Await")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Await_kind;
        v = ptr[_expr_Await](node_union(ptr(p)));
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Yield(
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Yield_kind;
        v = ptr[_expr_Yield](node_union(ptr(p)));
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_YieldFrom(
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for YieldFrom")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = YieldFrom_kind;
        v = ptr[_expr_YieldFrom](node_union(ptr(p)));
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Compare(
        left: ptr[_expr],
        ops: ptr[asdl_seq],
        comparators: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not left {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'left' is required for Compare")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Compare_kind;
        v = ptr[_expr_Compare](node_union(ptr(p)));
        v.view(1)[0].left = left;
        v.view(1)[0].ops = ops;
        v.view(1)[0].comparators = comparators;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Call(
        func: ptr[_expr],
        args: ptr[asdl_seq],
        keywords: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not func {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'func' is required for Call")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Call_kind;
        v = ptr[_expr_Call](node_union(ptr(p)));
        v.view(1)[0].func = func;
        v.view(1)[0].args = args;
        v.view(1)[0].keywords = keywords;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_FormattedValue(
        value: ptr[_expr],
        conversion: i32,
        format_spec: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("field 'value' is required for FormattedValue")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = FormattedValue_kind;
        v = ptr[_expr_FormattedValue](node_union(ptr(p)));
        v.view(1)[0].value = value;
        v.view(1)[0].conversion = conversion;
        v.view(1)[0].format_spec = format_spec;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Interpolation(
        value: ptr[_expr],
        str_: ptr[PyObject],
        conversion: i32,
        format_spec: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for Interpolation")
            );
            return ptr[_expr]();
        }
        if not str_ {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'str' is required for Interpolation")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Interpolation_kind;
        v = ptr[_expr_Interpolation](node_union(ptr(p)));
        v.view(1)[0].value = value;
        v.view(1)[0].str_ = str_;
        v.view(1)[0].conversion = conversion;
        v.view(1)[0].format_spec = format_spec;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_JoinedStr(
        values: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = JoinedStr_kind;
        v = ptr[_expr_JoinedStr](node_union(ptr(p)));
        v.view(1)[0].values = values;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_TemplateStr(
        values: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = TemplateStr_kind;
        v = ptr[_expr_TemplateStr](node_union(ptr(p)));
        v.view(1)[0].values = values;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Constant(
        value: ptr[PyObject],
        kind: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for Constant")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Constant_kind;
        v = ptr[_expr_Constant](node_union(ptr(p)));
        v.view(1)[0].value = value;
        v.view(1)[0].kind = kind;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Attribute(
        value: ptr[_expr],
        attr: ptr[PyObject],
        ctx: i32,
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for Attribute")
            );
            return ptr[_expr]();
        }
        if not attr {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'attr' is required for Attribute")
            );
            return ptr[_expr]();
        }
        if ctx == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'ctx' is required for Attribute")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Attribute_kind;
        v = ptr[_expr_Attribute](node_union(ptr(p)));
        v.view(1)[0].value = value;
        v.view(1)[0].attr = attr;
        v.view(1)[0].ctx = ctx;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Subscript(
        value: ptr[_expr],
        slice: ptr[_expr],
        ctx: i32,
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for Subscript")
            );
            return ptr[_expr]();
        }
        if not slice {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'slice' is required for Subscript")
            );
            return ptr[_expr]();
        }
        if ctx == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'ctx' is required for Subscript")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Subscript_kind;
        v = ptr[_expr_Subscript](node_union(ptr(p)));
        v.view(1)[0].value = value;
        v.view(1)[0].slice = slice;
        v.view(1)[0].ctx = ctx;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Starred(
        value: ptr[_expr],
        ctx: i32,
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for Starred")
            );
            return ptr[_expr]();
        }
        if ctx == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'ctx' is required for Starred")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Starred_kind;
        v = ptr[_expr_Starred](node_union(ptr(p)));
        v.view(1)[0].value = value;
        v.view(1)[0].ctx = ctx;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Name(
        id: ptr[PyObject],
        ctx: i32,
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if not id {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'id' is required for Name")
            );
            return ptr[_expr]();
        }
        if ctx == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'ctx' is required for Name")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Name_kind;
        v = ptr[_expr_Name](node_union(ptr(p)));
        v.view(1)[0].id = id;
        v.view(1)[0].ctx = ctx;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_List(
        elts: ptr[asdl_seq],
        ctx: i32,
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if ctx == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'ctx' is required for List")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = List_kind;
        v = ptr[_expr_List](node_union(ptr(p)));
        v.view(1)[0].elts = elts;
        v.view(1)[0].ctx = ctx;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Tuple(
        elts: ptr[asdl_seq],
        ctx: i32,
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        if ctx == 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'ctx' is required for Tuple")
            );
            return ptr[_expr]();
        }
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Tuple_kind;
        v = ptr[_expr_Tuple](node_union(ptr(p)));
        v.view(1)[0].elts = elts;
        v.view(1)[0].ctx = ctx;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_Slice(
        lower: ptr[_expr],
        upper: ptr[_expr],
        step: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_expr] {
        p = ptr[_expr](_PyArena_Malloc(arena, _expr_SIZE));
        if not p {
            return ptr[_expr]();
        }
        p.view(1)[0].kind = Slice_kind;
        v = ptr[_expr_Slice](node_union(ptr(p)));
        v.view(1)[0].lower = lower;
        v.view(1)[0].upper = upper;
        v.view(1)[0].step = step;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_comprehension(
        target: ptr[_expr],
        iter: ptr[_expr],
        ifs: ptr[asdl_seq],
        is_async: i32,
        arena: ptr
    ) -> ptr[_comprehension] {
        if not target {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("field 'target' is required for comprehension")
            );
            return ptr[_comprehension]();
        }
        if not iter {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'iter' is required for comprehension")
            );
            return ptr[_comprehension]();
        }
        p = ptr[_comprehension](_PyArena_Malloc(arena, _comprehension_SIZE));
        if not p {
            return ptr[_comprehension]();
        }
        p.view(1)[0].target = target;
        p.view(1)[0].iter = iter;
        p.view(1)[0].ifs = ifs;
        p.view(1)[0].is_async = is_async;
        return p;
    }  def _PyAST_ExceptHandler(
        type: ptr[_expr],
        name: ptr[PyObject],
        body: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_excepthandler] {
        p = ptr[_excepthandler](_PyArena_Malloc(arena, _excepthandler_SIZE));
        if not p {
            return ptr[_excepthandler]();
        }
        p.view(1)[0].kind = ExceptHandler_kind;
        v = ptr[_excepthandler_ExceptHandler](node_union(ptr(p)));
        v.view(1)[0].type = type;
        v.view(1)[0].name = name;
        v.view(1)[0].body = body;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_arguments(
        posonlyargs: ptr[asdl_seq],
        args: ptr[asdl_seq],
        vararg: ptr[_arg],
        kwonlyargs: ptr[asdl_seq],
        kw_defaults: ptr[asdl_seq],
        kwarg: ptr[_arg],
        defaults: ptr[asdl_seq],
        arena: ptr
    ) -> ptr[_arguments] {
        p = ptr[_arguments](_PyArena_Malloc(arena, _arguments_SIZE));
        if not p {
            return ptr[_arguments]();
        }
        p.view(1)[0].posonlyargs = posonlyargs;
        p.view(1)[0].args = args;
        p.view(1)[0].vararg = vararg;
        p.view(1)[0].kwonlyargs = kwonlyargs;
        p.view(1)[0].kw_defaults = kw_defaults;
        p.view(1)[0].kwarg = kwarg;
        p.view(1)[0].defaults = defaults;
        return p;
    }  def _PyAST_arg(
        arg: ptr[PyObject],
        annotation: ptr[_expr],
        type_comment: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_arg] {
        if not arg {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'arg' is required for arg")
            );
            return ptr[_arg]();
        }
        p = ptr[_arg](_PyArena_Malloc(arena, _arg_SIZE));
        if not p {
            return ptr[_arg]();
        }
        p.view(1)[0].arg = arg;
        p.view(1)[0].annotation = annotation;
        p.view(1)[0].type_comment = type_comment;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_keyword(
        arg: ptr[PyObject],
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_keyword] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for keyword")
            );
            return ptr[_keyword]();
        }
        p = ptr[_keyword](_PyArena_Malloc(arena, _keyword_SIZE));
        if not p {
            return ptr[_keyword]();
        }
        p.view(1)[0].arg = arg;
        p.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_alias(
        name: ptr[PyObject],
        asname: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_alias] {
        if not name {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'name' is required for alias")
            );
            return ptr[_alias]();
        }
        p = ptr[_alias](_PyArena_Malloc(arena, _alias_SIZE));
        if not p {
            return ptr[_alias]();
        }
        p.view(1)[0].name = name;
        p.view(1)[0].asname = asname;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_withitem(
        context_expr: ptr[_expr], optional_vars: ptr[_expr], arena: ptr
    ) -> ptr[_withitem] {
        if not context_expr {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("field 'context_expr' is required for withitem")
            );
            return ptr[_withitem]();
        }
        p = ptr[_withitem](_PyArena_Malloc(arena, _withitem_SIZE));
        if not p {
            return ptr[_withitem]();
        }
        p.view(1)[0].context_expr = context_expr;
        p.view(1)[0].optional_vars = optional_vars;
        return p;
    }  def _PyAST_match_case(
        pattern: ptr[_pattern], guard: ptr[_expr], body: ptr[asdl_seq], arena: ptr
    ) -> ptr[_match_case] {
        if not pattern {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'pattern' is required for match_case")
            );
            return ptr[_match_case]();
        }
        p = ptr[_match_case](_PyArena_Malloc(arena, _match_case_SIZE));
        if not p {
            return ptr[_match_case]();
        }
        p.view(1)[0].pattern = pattern;
        p.view(1)[0].guard = guard;
        p.view(1)[0].body = body;
        return p;
    }  def _PyAST_MatchValue(
        value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_pattern] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'value' is required for MatchValue")
            );
            return ptr[_pattern]();
        }
        p = ptr[_pattern](_PyArena_Malloc(arena, _pattern_SIZE));
        if not p {
            return ptr[_pattern]();
        }
        p.view(1)[0].kind = MatchValue_kind;
        v = ptr[_pattern_MatchValue](node_union(ptr(p)));
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_MatchSingleton(
        value: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_pattern] {
        if not value {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("field 'value' is required for MatchSingleton")
            );
            return ptr[_pattern]();
        }
        p = ptr[_pattern](_PyArena_Malloc(arena, _pattern_SIZE));
        if not p {
            return ptr[_pattern]();
        }
        p.view(1)[0].kind = MatchSingleton_kind;
        v = ptr[_pattern_MatchSingleton](node_union(ptr(p)));
        v.view(1)[0].value = value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_MatchSequence(
        patterns: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_pattern] {
        p = ptr[_pattern](_PyArena_Malloc(arena, _pattern_SIZE));
        if not p {
            return ptr[_pattern]();
        }
        p.view(1)[0].kind = MatchSequence_kind;
        v = ptr[_pattern_MatchSequence](node_union(ptr(p)));
        v.view(1)[0].patterns = patterns;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_MatchMapping(
        keys: ptr[asdl_seq],
        patterns: ptr[asdl_seq],
        rest: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_pattern] {
        p = ptr[_pattern](_PyArena_Malloc(arena, _pattern_SIZE));
        if not p {
            return ptr[_pattern]();
        }
        p.view(1)[0].kind = MatchMapping_kind;
        v = ptr[_pattern_MatchMapping](node_union(ptr(p)));
        v.view(1)[0].keys = keys;
        v.view(1)[0].patterns = patterns;
        v.view(1)[0].rest = rest;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_MatchClass(
        cls: ptr[_expr],
        patterns: ptr[asdl_seq],
        kwd_attrs: ptr[asdl_seq],
        kwd_patterns: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_pattern] {
        if not cls {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'cls' is required for MatchClass")
            );
            return ptr[_pattern]();
        }
        p = ptr[_pattern](_PyArena_Malloc(arena, _pattern_SIZE));
        if not p {
            return ptr[_pattern]();
        }
        p.view(1)[0].kind = MatchClass_kind;
        v = ptr[_pattern_MatchClass](node_union(ptr(p)));
        v.view(1)[0].cls = cls;
        v.view(1)[0].patterns = patterns;
        v.view(1)[0].kwd_attrs = kwd_attrs;
        v.view(1)[0].kwd_patterns = kwd_patterns;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_MatchStar(
        name: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_pattern] {
        p = ptr[_pattern](_PyArena_Malloc(arena, _pattern_SIZE));
        if not p {
            return ptr[_pattern]();
        }
        p.view(1)[0].kind = MatchStar_kind;
        v = ptr[_pattern_MatchStar](node_union(ptr(p)));
        v.view(1)[0].name = name;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_MatchAs(
        pattern: ptr[_pattern],
        name: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_pattern] {
        p = ptr[_pattern](_PyArena_Malloc(arena, _pattern_SIZE));
        if not p {
            return ptr[_pattern]();
        }
        p.view(1)[0].kind = MatchAs_kind;
        v = ptr[_pattern_MatchAs](node_union(ptr(p)));
        v.view(1)[0].pattern = pattern;
        v.view(1)[0].name = name;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_MatchOr(
        patterns: ptr[asdl_seq],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_pattern] {
        p = ptr[_pattern](_PyArena_Malloc(arena, _pattern_SIZE));
        if not p {
            return ptr[_pattern]();
        }
        p.view(1)[0].kind = MatchOr_kind;
        v = ptr[_pattern_MatchOr](node_union(ptr(p)));
        v.view(1)[0].patterns = patterns;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_TypeIgnore(
        lineno: i32, tag: ptr[PyObject], arena: ptr
    ) -> ptr[_type_ignore] {
        if not tag {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'tag' is required for TypeIgnore")
            );
            return ptr[_type_ignore]();
        }
        p = ptr[_type_ignore](_PyArena_Malloc(arena, _type_ignore_SIZE));
        if not p {
            return ptr[_type_ignore]();
        }
        p.view(1)[0].kind = TypeIgnore_kind;
        v = ptr[_type_ignore_TypeIgnore](node_union(ptr(p)));
        v.view(1)[0].lineno = lineno;
        v.view(1)[0].tag = tag;
        return p;
    }  def _PyAST_TypeVar(
        name: ptr[PyObject],
        bound: ptr[_expr],
        default_value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_type_param] {
        if not name {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'name' is required for TypeVar")
            );
            return ptr[_type_param]();
        }
        p = ptr[_type_param](_PyArena_Malloc(arena, _type_param_SIZE));
        if not p {
            return ptr[_type_param]();
        }
        p.view(1)[0].kind = TypeVar_kind;
        v = ptr[_type_param_TypeVar](node_union(ptr(p)));
        v.view(1)[0].name = name;
        v.view(1)[0].bound = bound;
        v.view(1)[0].default_value = default_value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_ParamSpec(
        name: ptr[PyObject],
        default_value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_type_param] {
        if not name {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'name' is required for ParamSpec")
            );
            return ptr[_type_param]();
        }
        p = ptr[_type_param](_PyArena_Malloc(arena, _type_param_SIZE));
        if not p {
            return ptr[_type_param]();
        }
        p.view(1)[0].kind = ParamSpec_kind;
        v = ptr[_type_param_ParamSpec](node_union(ptr(p)));
        v.view(1)[0].name = name;
        v.view(1)[0].default_value = default_value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }  def _PyAST_TypeVarTuple(
        name: ptr[PyObject],
        default_value: ptr[_expr],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32,
        arena: ptr
    ) -> ptr[_type_param] {
        if not name {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("field 'name' is required for TypeVarTuple")
            );
            return ptr[_type_param]();
        }
        p = ptr[_type_param](_PyArena_Malloc(arena, _type_param_SIZE));
        if not p {
            return ptr[_type_param]();
        }
        p.view(1)[0].kind = TypeVarTuple_kind;
        v = ptr[_type_param_TypeVarTuple](node_union(ptr(p)));
        v.view(1)[0].name = name;
        v.view(1)[0].default_value = default_value;
        p.view(1)[0].lineno = lineno;
        p.view(1)[0].col_offset = col_offset;
        p.view(1)[0].end_lineno = end_lineno;
        p.view(1)[0].end_col_offset = end_col_offset;
        return p;
    }
}

def ast2obj_list_stmt(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject];

def ast2obj_list_type_ignore(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject];

def ast2obj_list_expr(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject];

def ast2obj_list_type_param(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject];

def ast2obj_list_keyword(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject];

def ast2obj_list_withitem(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject];

def ast2obj_list_match_case(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject];

def ast2obj_list_excepthandler(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject];

def ast2obj_list_alias(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject];

def ast2obj_list_object(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject];

def ast2obj_list_comprehension(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject];

def ast2obj_list_arg(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject];

def ast2obj_list_pattern(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject];

def ast2obj_mod(state: ptr[ast_state], o: ptr[_mod]) -> ptr[PyObject];

def ast2obj_stmt(state: ptr[ast_state], o: ptr[_stmt]) -> ptr[PyObject];

def ast2obj_expr(state: ptr[ast_state], o: ptr[_expr]) -> ptr[PyObject];

def ast2obj_expr_context(state: ptr[ast_state], o: i32) -> ptr[PyObject];

def ast2obj_boolop(state: ptr[ast_state], o: i32) -> ptr[PyObject];

def ast2obj_operator(state: ptr[ast_state], o: i32) -> ptr[PyObject];

def ast2obj_unaryop(state: ptr[ast_state], o: i32) -> ptr[PyObject];

def ast2obj_cmpop(state: ptr[ast_state], o: i32) -> ptr[PyObject];

def ast2obj_comprehension(
    state: ptr[ast_state], o: ptr[_comprehension]
) -> ptr[PyObject];

def ast2obj_excepthandler(
    state: ptr[ast_state], o: ptr[_excepthandler]
) -> ptr[PyObject];

def ast2obj_arguments(state: ptr[ast_state], o: ptr[_arguments]) -> ptr[PyObject];

def ast2obj_arg(state: ptr[ast_state], o: ptr[_arg]) -> ptr[PyObject];

def ast2obj_keyword(state: ptr[ast_state], o: ptr[_keyword]) -> ptr[PyObject];

def ast2obj_alias(state: ptr[ast_state], o: ptr[_alias]) -> ptr[PyObject];

def ast2obj_withitem(state: ptr[ast_state], o: ptr[_withitem]) -> ptr[PyObject];

def ast2obj_match_case(state: ptr[ast_state], o: ptr[_match_case]) -> ptr[PyObject];

def ast2obj_pattern(state: ptr[ast_state], o: ptr[_pattern]) -> ptr[PyObject];

def ast2obj_type_ignore(state: ptr[ast_state], o: ptr[_type_ignore]) -> ptr[PyObject];

def ast2obj_type_param(state: ptr[ast_state], o: ptr[_type_param]) -> ptr[PyObject];

def obj2ast_mod_Module(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]];

def obj2ast_mod_Interactive(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]];

def obj2ast_mod_Expression(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]];

def obj2ast_mod_FunctionType(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]];

def obj2ast_mod(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]];

def obj2ast_stmt_FunctionDef(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_AsyncFunctionDef(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_ClassDef(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Return(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Delete(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Assign(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_TypeAlias(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_AugAssign(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_AnnAssign(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_For(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_AsyncFor(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_While(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_If(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_With(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_AsyncWith(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Match(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Raise(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Try(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_TryStar(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Assert(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Import(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_ImportFrom(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Global(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Nonlocal(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Expr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Pass(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Break(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt_Continue(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]];

def obj2ast_stmt(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_stmt]];

def obj2ast_expr_BoolOp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_NamedExpr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_BinOp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_UnaryOp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Lambda(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_IfExp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Dict(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Set(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_ListComp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_SetComp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_DictComp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_GeneratorExp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Await(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Yield(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_YieldFrom(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Compare(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Call(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_FormattedValue(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Interpolation(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_JoinedStr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_TemplateStr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Constant(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Attribute(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Subscript(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Starred(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Name(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_List(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Tuple(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_Slice(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_expr]];

def obj2ast_expr_context(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32];

def obj2ast_boolop(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32];

def obj2ast_operator(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32];

def obj2ast_unaryop(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32];

def obj2ast_cmpop(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32];

def obj2ast_comprehension(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_comprehension]];

def obj2ast_excepthandler_ExceptHandler(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_excepthandler]];

def obj2ast_excepthandler(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_excepthandler]];

def obj2ast_arguments(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_arguments]];

def obj2ast_arg(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_arg]];

def obj2ast_keyword(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_keyword]];

def obj2ast_alias(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_alias]];

def obj2ast_withitem(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_withitem]];

def obj2ast_match_case(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_match_case]];

def obj2ast_pattern_MatchValue(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]];

def obj2ast_pattern_MatchSingleton(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]];

def obj2ast_pattern_MatchSequence(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]];

def obj2ast_pattern_MatchMapping(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]];

def obj2ast_pattern_MatchClass(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]];

def obj2ast_pattern_MatchStar(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]];

def obj2ast_pattern_MatchAs(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]];

def obj2ast_pattern_MatchOr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]];

def obj2ast_pattern(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_pattern]];

def obj2ast_type_ignore_TypeIgnore(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_type_ignore]];

def obj2ast_type_ignore(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_type_ignore]];

def obj2ast_type_param_TypeVar(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_type_param]];

def obj2ast_type_param_ParamSpec(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_type_param]];

def obj2ast_type_param_TypeVarTuple(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_type_param]];

def obj2ast_type_param(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_type_param]];

def astmodule_exec(m: ptr[PyObject]) -> i32;

impl get_ast_state -> ptr[ast_state] {
    state = ptr[ast_state](current_interp() + PyInterpreterState_AST);
    flag = ptr[u8](state);
    if u8.wrap(__atomic_load_i8(int(flag), 5)) == _Py_ONCE_INITIALIZED {
        return state;
    }
    if _PyOnceFlag_CallOnceSlow(flag, ptr(init_types), ptr(state)) < 0 {
        return ptr[ast_state]();
    }
    return state;
}

impl long_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl tuple_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl list_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LIST_SUBCLASS);
}

impl unicode_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyUnicode_Type)));
}

impl bytes_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyBytes_Type)));
}

impl list_get_item(lst: ptr[PyObject], index: i64) -> ptr[PyObject] {
    return (ptr[PyListObject](lst).view(1)[0].ob_item + index).view(1)[0];
}

impl list_set_item(lst: ptr[PyObject], index: i64, value: ptr[PyObject]) {
    (ptr[PyListObject](lst).view(1)[0].ob_item + index).view(1)[0] = value;
}

impl asdl_seq_len(seq: ptr[asdl_seq]) -> i64 {
    if not seq {
        return 0;
    }
    return seq.view(1)[0].size;
}

impl asdl_seq_get_untyped(seq: ptr[asdl_seq], index: i64) -> ptr {
    return (seq.view(1)[0].elements + index).view(1)[0];
}

impl asdl_seq_set(seq: ptr[asdl_seq], index: i64, value: ptr) {
    (ptr[ptr](ptr[u8](seq) + asdl_generic_seq_TYPED_ELEMENTS) + index).view(1)[0] = value;
}

impl asdl_int_seq_get(seq: ptr[asdl_seq], index: i64) -> i32 {
    return (ptr[i32](ptr[u8](seq) + asdl_int_seq_TYPED_ELEMENTS) + index).view(1)[0];
}

impl asdl_int_seq_set(seq: ptr[asdl_seq], index: i64, value: i32) {
    (ptr[i32](ptr[u8](seq) + asdl_int_seq_TYPED_ELEMENTS) + index).view(1)[0] = value;
}

impl node_union(node_ptr: ptr) -> ptr[u8] {
    return ptr[u8](node_ptr) + AST_UNION_OFFSET;
}

impl ast_dealloc(op: ptr[PyObject]) {
    self_ = ptr[AST_object](op);
    tp = object_type(op);
    PyObject_GC_UnTrack(ptr(op));
    old = self_.view(1)[0].dct;
    self_.view(1)[0].dct = NULL;
    object_xdecref(old);
    calls = ptr[AstCall](
        __thread_local_block("jac_object_model_python_ast_call_slot", 8)
    );
    calls.view(1)[0].free = int(PyType_GetSlot(ptr[PyObject](tp), Py_tp_free));
    calls.view(1)[0].free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl ast_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = ptr[AST_object](op);
    vret = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(self_.view(1)[0].dct, visitor, arg);
    if vret != 0 {
        return vret;
    }
    return 0;
}

impl ast_clear(op: ptr[PyObject]) -> i32 {
    self_ = ptr[AST_object](op);
    old = self_.view(1)[0].dct;
    self_.view(1)[0].dct = NULL;
    object_xdecref(old);
    return 0;
}

impl init_cleanup(
    res: i32, attributes: ptr[PyObject], fields: ptr[PyObject], remaining: ptr[PyObject]
) -> i32 {
    object_xdecref(attributes);
    object_xdecref(fields);
    object_xdecref(remaining);
    return res;
}

impl ast_type_init(
    self_: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> i32 {
    state = get_ast_state();
    if not state {
        return -1;
    }
    numfields: i64 = 0;
    res: i32 = -1;
    attributes = NULL;
    remaining_fields = NULL;
    tp = object_type(self_);
    fields = PyObject_GetAttr(ptr[PyObject](tp), state.view(1)[0]._fields);
    if not fields {
        return init_cleanup(res, attributes, fields, remaining_fields);
    }
    numfields = PySequence_Size(fields);
    if numfields == -1 {
        return init_cleanup(res, attributes, fields, remaining_fields);
    }
    remaining_fields = PySet_New(fields);
    if not remaining_fields {
        return init_cleanup(res, attributes, fields, remaining_fields);
    }
    res = 0;
    nargs = object_size(args);
    if numfields < nargs {
        plural: ptr[u8] = ptr[u8]("s");
        if numfields == 1 {
            plural = ptr[u8]("");
        }
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%.400s constructor takes at most %zd positional argument%s"),
            _PyType_Name(ptr[PyObject](tp)),
            numfields,
            plural
        );
        return init_cleanup(-1, attributes, fields, remaining_fields);
    }
    i: i64 = 0;
    while i < nargs {
        name = PySequence_GetItem(fields, i);
        if not name {
            return init_cleanup(-1, attributes, fields, remaining_fields);
        }
        res = PyObject_SetAttr(self_, name, tuple_get_item(args, i));
        if PySet_Discard(remaining_fields, name) < 0 {
            object_decref(name);
            return init_cleanup(-1, attributes, fields, remaining_fields);
        }
        object_decref(name);
        if res < 0 {
            return init_cleanup(res, attributes, fields, remaining_fields);
        }
        i += 1;
    }
    if kw {
        pos: i64 = 0;
        key = NULL;
        value = NULL;
        while PyDict_Next(kw, &mut pos, &mut key, &mut value) != 0 {
            contains = PySequence_Contains(fields, key);
            if contains == -1 {
                return init_cleanup(-1, attributes, fields, remaining_fields);
            } elif contains == 1 {
                discarded = PySet_Discard(remaining_fields, key);
                if discarded == -1 {
                    return init_cleanup(-1, attributes, fields, remaining_fields);
                }
                if discarded == 0 {
                    PyErr_Format(
                        PyExc_TypeError,
                        ptr[u8]("%.400s got multiple values for argument %R"),
                        tp.view(1)[0].tp_name,
                        key
                    );
                    return init_cleanup(-1, attributes, fields, remaining_fields);
                }
            } else {
                if not attributes {
                    attributes = PyObject_GetAttr(
                        ptr[PyObject](tp), state.view(1)[0]._attributes
                    );
                    if not attributes {
                        return init_cleanup(-1, attributes, fields, remaining_fields);
                    }
                }
                in_attributes = PySequence_Contains(attributes, key);
                if in_attributes == -1 {
                    return init_cleanup(-1, attributes, fields, remaining_fields);
                } elif in_attributes == 0 {
                    if PyErr_WarnFormat(
                        PyExc_DeprecationWarning,
                        1,
                        ptr[u8](
                            "%.400s.__init__ got an unexpected keyword argument %R. Support for arbitrary keyword arguments is deprecated and will be removed in Python 3.15."
                        ),
                        tp.view(1)[0].tp_name,
                        key
                    )
                        < 0 {
                        return init_cleanup(-1, attributes, fields, remaining_fields);
                    }
                }
            }
            res = PyObject_SetAttr(self_, key, value);
            if res < 0 {
                return init_cleanup(res, attributes, fields, remaining_fields);
            }
        }
    }
    size = PySet_Size(remaining_fields);
    field_types = NULL;
    remaining_list = NULL;
    if size > 0 {
        if PyObject_GetOptionalAttr(
            ptr[PyObject](tp), py_id(_Py_ID__field_types), &mut field_types
        )
            < 0 {
            return init_cleanup(-1, attributes, fields, remaining_fields);
        }
        if not field_types {
            return init_cleanup(res, attributes, fields, remaining_fields);
        }
        remaining_list = PySequence_List(remaining_fields);
        if not remaining_list {
            object_xdecref(remaining_list);
            object_xdecref(field_types);
            return init_cleanup(-1, attributes, fields, remaining_fields);
        }
        j: i64 = 0;
        while j < size {
            field_name = list_get_item(remaining_list, j);
            field_type = PyDict_GetItemWithError(field_types, field_name);
            if not field_type {
                if PyErr_Occurred() {
                    object_xdecref(remaining_list);
                    object_xdecref(field_types);
                    return init_cleanup(-1, attributes, fields, remaining_fields);
                } elif PyErr_WarnFormat(
                    PyExc_DeprecationWarning,
                    1,
                    ptr[u8](
                        "Field %R is missing from %.400s._field_types. This will become an error in Python 3.15."
                    ),
                    field_name,
                    tp.view(1)[0].tp_name
                )
                    < 0 {
                    object_xdecref(remaining_list);
                    object_xdecref(field_types);
                    return init_cleanup(-1, attributes, fields, remaining_fields);
                }
            } elif object_is_type(
                field_type, ptr[PyTypeObject](addressof(_PyUnion_Type))
            ) {
                j += 1;
                continue;
            } elif object_is_type(
                field_type, ptr[PyTypeObject](addressof(Py_GenericAliasType))
            ) {
                empty = PyList_New(0);
                if not empty {
                    object_xdecref(remaining_list);
                    object_xdecref(field_types);
                    return init_cleanup(-1, attributes, fields, remaining_fields);
                }
                res = PyObject_SetAttr(self_, field_name, empty);
                object_decref(empty);
                if res < 0 {
                    object_xdecref(remaining_list);
                    object_xdecref(field_types);
                    return init_cleanup(-1, attributes, fields, remaining_fields);
                }
            } elif field_type == state.view(1)[0].expr_context_type {
                res = PyObject_SetAttr(
                    self_, field_name, state.view(1)[0].Load_singleton
                );
                if res < 0 {
                    object_xdecref(remaining_list);
                    object_xdecref(field_types);
                    return init_cleanup(-1, attributes, fields, remaining_fields);
                }
            } elif PyErr_WarnFormat(
                PyExc_DeprecationWarning,
                1,
                ptr[u8](
                    "%.400s.__init__ missing 1 required positional argument: %R. This will become an error in Python 3.15."
                ),
                tp.view(1)[0].tp_name,
                field_name
            )
                < 0 {
                object_xdecref(remaining_list);
                object_xdecref(field_types);
                return init_cleanup(-1, attributes, fields, remaining_fields);
            }
            j += 1;
        }
        object_decref(remaining_list);
        object_decref(field_types);
    }
    return init_cleanup(res, attributes, fields, remaining_fields);
}

impl reduce_cleanup(
    result: ptr[PyObject], fields: ptr[PyObject], positional_args: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(fields);
    object_xdecref(positional_args);
    return result;
}

impl ast_type_reduce(self_: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = get_ast_state();
    if not state {
        return NULL;
    }
    dct = NULL;
    fields = NULL;
    positional_args = NULL;
    if PyObject_GetOptionalAttr(self_, state.view(1)[0].__dict__, &mut dct) < 0 {
        return NULL;
    }
    result = NULL;
    tp = ptr[PyObject](object_type(self_));
    if not dct {
        result = Py_BuildValue(ptr[u8]("O()"), tp);
        return reduce_cleanup(result, fields, positional_args);
    }
    if PyObject_GetOptionalAttr(tp, state.view(1)[0]._fields, &mut fields) < 0 {
        return reduce_cleanup(result, fields, positional_args);
    }
    if not fields {
        result = Py_BuildValue(ptr[u8]("O()N"), tp, dct);
        return reduce_cleanup(result, fields, positional_args);
    }
    numfields = PySequence_Size(fields);
    if numfields == -1 {
        object_decref(dct);
        return reduce_cleanup(result, fields, positional_args);
    }
    positional_args = PyList_New(0);
    if not positional_args {
        return reduce_cleanup(result, fields, positional_args);
    }
    i: i64 = 0;
    while i < numfields {
        name = PySequence_GetItem(fields, i);
        if not name {
            return reduce_cleanup(result, fields, positional_args);
        }
        value = NULL;
        rc = PyDict_GetItemRef(dct, name, &mut value);
        object_decref(name);
        if rc < 0 {
            return reduce_cleanup(result, fields, positional_args);
        }
        if not value {
            break;
        }
        rc = PyList_Append(positional_args, Py_None);
        object_decref(value);
        if rc < 0 {
            return reduce_cleanup(result, fields, positional_args);
        }
        i += 1;
    }
    args_tuple = PyList_AsTuple(positional_args);
    if not args_tuple {
        return reduce_cleanup(result, fields, positional_args);
    }
    result = Py_BuildValue(ptr[u8]("ONN"), tp, args_tuple, dct);
    return reduce_cleanup(result, fields, positional_args);
}

impl ast_type_replace_check(
    self_: ptr[PyObject],
    dct: ptr[PyObject],
    fields: ptr[PyObject],
    attributes: ptr[PyObject],
    kwargs: ptr[PyObject]
) -> i32 {
    expecting = PySet_New(fields);
    if not expecting {
        return -1;
    }
    if attributes {
        if _PySet_Update(expecting, attributes) < 0 {
            object_decref(expecting);
            return -1;
        }
    }
    if kwargs {
        pos: i64 = 0;
        key = NULL;
        value = NULL;
        while PyDict_Next(kwargs, &mut pos, &mut key, &mut value) != 0 {
            rc = PySet_Discard(expecting, key);
            if rc < 0 {
                object_decref(expecting);
                return -1;
            }
            if rc == 0 {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8](
                        "%.400s.__replace__ got an unexpected keyword argument %R."
                    ),
                    object_type(self_).view(1)[0].tp_name,
                    key
                );
                object_decref(expecting);
                return -1;
            }
        }
    }
    if dct {
        dpos: i64 = 0;
        dkey = NULL;
        dvalue = NULL;
        while PyDict_Next(dct, &mut dpos, &mut dkey, &mut dvalue) != 0 {
            if PySet_Discard(expecting, dkey) < 0 {
                object_decref(expecting);
                return -1;
            }
        }
        if attributes {
            slots: own AstStack = AstStack();
            stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
            stack.view(2)[0] = expecting;
            stack.view(2)[1] = attributes;
            unused = PyObject_VectorcallMethod(
                py_id(_Py_ID_difference_update),
                stack,
                u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET,
                NULL
            );
            if not unused {
                object_decref(expecting);
                return -1;
            }
            object_decref(unused);
        }
    }
    field_types = NULL;
    if PyObject_GetOptionalAttr(
        ptr[PyObject](object_type(self_)), py_id(_Py_ID__field_types), &mut field_types
    )
        < 0 {
        object_decref(expecting);
        return -1;
    }
    if field_types {
        fpos: i64 = 0;
        field_name = NULL;
        field_type = NULL;
        while PyDict_Next(field_types, &mut fpos, &mut field_name, &mut field_type)
            != 0 {
            if object_is_type(
                field_type, ptr[PyTypeObject](addressof(_PyUnion_Type))
            ) {
                if PySet_Discard(expecting, field_name) < 0 {
                    object_decref(expecting);
                    object_decref(field_types);
                    return -1;
                }
            }
        }
        object_decref(field_types);
    }
    m = PySet_Size(expecting);
    if m > 0 {
        names = PyList_New(m);
        if not names {
            object_decref(expecting);
            return -1;
        }
        i: i64 = 0;
        spos: i64 = 0;
        item = NULL;
        hash: i64 = 0;
        while _PySet_NextEntry(expecting, &mut spos, &mut item, &mut hash) != 0 {
            name = PyObject_Repr(item);
            if not name {
                object_decref(expecting);
                object_decref(names);
                return -1;
            }
            list_set_item(names, i, name);
            i += 1;
        }
        object_decref(expecting);
        if PyList_Sort(names) < 0 {
            object_decref(names);
            return -1;
        }
        sep = PyUnicode_FromString(ptr[u8](", "));
        if not sep {
            object_decref(names);
            return -1;
        }
        str_names = PyUnicode_Join(sep, names);
        object_decref(sep);
        object_decref(names);
        if not str_names {
            return -1;
        }
        plural: ptr[u8] = ptr[u8]("s");
        if m == 1 {
            plural = ptr[u8]("");
        }
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%.400s.__replace__ missing %ld keyword argument%s: %U."),
            object_type(self_).view(1)[0].tp_name,
            m,
            plural,
            str_names
        );
        object_decref(str_names);
        return -1;
    }
    object_decref(expecting);
    return 1;
}

impl ast_type_replace_update_payload(
    payload: ptr[PyObject], keys: ptr[PyObject], dct: ptr[PyObject]
) -> i32 {
    if not keys {
        return 0;
    }
    n = PySequence_Size(keys);
    if n == -1 {
        return -1;
    }
    i: i64 = 0;
    while i < n {
        key = PySequence_GetItem(keys, i);
        if not key {
            return -1;
        }
        value = NULL;
        if PyDict_GetItemRef(dct, key, &mut value) < 0 {
            object_decref(key);
            return -1;
        }
        if not value {
            object_decref(key);
            i += 1;
            continue;
        }
        rc = PyDict_SetItem(payload, key, value);
        object_decref(key);
        object_decref(value);
        if rc < 0 {
            return -1;
        }
        i += 1;
    }
    return 0;
}

impl replace_cleanup(
    result: ptr[PyObject],
    payload: ptr[PyObject],
    empty_tuple: ptr[PyObject],
    dct: ptr[PyObject],
    attributes: ptr[PyObject],
    fields: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(payload);
    object_xdecref(empty_tuple);
    object_xdecref(dct);
    object_xdecref(attributes);
    object_xdecref(fields);
    return result;
}

impl ast_type_replace(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if _PyArg_NoPositional(ptr[u8]("__replace__"), args) == 0 {
        return NULL;
    }
    state = get_ast_state();
    if not state {
        return NULL;
    }
    result = NULL;
    fields = NULL;
    attributes = NULL;
    dct = NULL;
    empty_tuple = NULL;
    payload = NULL;
    tp = ptr[PyObject](object_type(self_));
    if PyObject_GetOptionalAttr(tp, state.view(1)[0]._fields, &mut fields) < 0 {
        return replace_cleanup(result, payload, empty_tuple, dct, attributes, fields);
    }
    if PyObject_GetOptionalAttr(tp, state.view(1)[0]._attributes, &mut attributes)
        < 0 {
        return replace_cleanup(result, payload, empty_tuple, dct, attributes, fields);
    }
    if PyObject_GetOptionalAttr(self_, state.view(1)[0].__dict__, &mut dct) < 0 {
        return replace_cleanup(result, payload, empty_tuple, dct, attributes, fields);
    }
    if ast_type_replace_check(self_, dct, fields, attributes, kwargs) < 0 {
        return replace_cleanup(result, payload, empty_tuple, dct, attributes, fields);
    }
    empty_tuple = PyTuple_New(0);
    if not empty_tuple {
        return replace_cleanup(result, payload, empty_tuple, dct, attributes, fields);
    }
    payload = PyDict_New();
    if not payload {
        return replace_cleanup(result, payload, empty_tuple, dct, attributes, fields);
    }
    if dct {
        if ast_type_replace_update_payload(payload, fields, dct) < 0 {
            return replace_cleanup(
                result, payload, empty_tuple, dct, attributes, fields
            );
        }
        if ast_type_replace_update_payload(payload, attributes, dct) < 0 {
            return replace_cleanup(
                result, payload, empty_tuple, dct, attributes, fields
            );
        }
    }
    if kwargs {
        if PyDict_Update(payload, kwargs) < 0 {
            return replace_cleanup(
                result, payload, empty_tuple, dct, attributes, fields
            );
        }
    }
    result = PyObject_Call(tp, empty_tuple, payload);
    return replace_cleanup(result, payload, empty_tuple, dct, attributes, fields);
}

impl repr_list_error(
    item0: ptr[PyObject], item1: ptr[PyObject], writer: ptr[PyUnicodeWriter]
) -> ptr[PyObject] {
    object_xdecref(item0);
    object_xdecref(item1);
    PyUnicodeWriter_Discard(writer);
    return NULL;
}

impl ast_repr_list(lst: ptr[PyObject], depth: i32) -> ptr[PyObject] {
    state = get_ast_state();
    if not state {
        return NULL;
    }
    length = PySequence_Size(lst);
    if length < 0 {
        return NULL;
    } elif length == 0 {
        return PyObject_Repr(lst);
    }
    item0 = NULL;
    item1 = NULL;
    writer = PyUnicodeWriter_Create(0);
    if not writer {
        return repr_list_error(item0, item1, writer);
    }
    item0 = PySequence_GetItem(lst, 0);
    if not item0 {
        return repr_list_error(item0, item1, writer);
    }
    if length > 1 {
        item1 = PySequence_GetItem(lst, length - 1);
        if not item1 {
            return repr_list_error(item0, item1, writer);
        }
    }
    is_list = list_check(lst);
    open_char: u32 = 40;
    close_char: u32 = 41;
    if is_list {
        open_char = 91;
        close_char = 93;
    }
    if PyUnicodeWriter_WriteChar(writer, open_char) < 0 {
        return repr_list_error(item0, item1, writer);
    }
    shown: i64 = 2;
    if length < 2 {
        shown = length;
    }
    i: i64 = 0;
    while i < shown {
        if i > 0 {
            if PyUnicodeWriter_WriteASCII(writer, ptr[u8](", "), 2) < 0 {
                return repr_list_error(item0, item1, writer);
            }
        }
        item = item0;
        if i == 1 {
            item = item1;
        }
        if PyType_IsSubtype(ptr[PyObject](object_type(item)), state.view(1)[0].AST_type)
            != 0 {
            item_repr = ast_repr_max_depth(item, depth - 1);
            if not item_repr {
                return repr_list_error(item0, item1, writer);
            }
            if PyUnicodeWriter_WriteStr(writer, item_repr) < 0 {
                object_decref(item_repr);
                return repr_list_error(item0, item1, writer);
            }
            object_decref(item_repr);
        } elif PyUnicodeWriter_WriteRepr(writer, item) < 0 {
            return repr_list_error(item0, item1, writer);
        }
        if i == 0 and length > 2 {
            if PyUnicodeWriter_WriteASCII(writer, ptr[u8](", ..."), 5) < 0 {
                return repr_list_error(item0, item1, writer);
            }
        }
        i += 1;
    }
    if PyUnicodeWriter_WriteChar(writer, close_char) < 0 {
        return repr_list_error(item0, item1, writer);
    }
    object_xdecref(item0);
    object_xdecref(item1);
    return PyUnicodeWriter_Finish(writer);
}

impl repr_error(
    self_: ptr[PyObject], fields: ptr[PyObject], writer: ptr[PyUnicodeWriter]
) -> ptr[PyObject] {
    Py_ReprLeave(self_);
    object_decref(fields);
    PyUnicodeWriter_Discard(writer);
    return NULL;
}

impl ast_repr_max_depth(self_: ptr[PyObject], depth: i32) -> ptr[PyObject] {
    state = get_ast_state();
    if not state {
        return NULL;
    }
    tp_name = object_type(self_).view(1)[0].tp_name;
    if depth <= 0 {
        return PyUnicode_FromFormat("%s(...)", tp_name);
    }
    status = Py_ReprEnter(self_);
    if status != 0 {
        if status < 0 {
            return NULL;
        }
        return PyUnicode_FromFormat("%s(...)", tp_name);
    }
    fields = NULL;
    if PyObject_GetOptionalAttr(
        ptr[PyObject](object_type(self_)), state.view(1)[0]._fields, &mut fields
    )
        < 0 {
        Py_ReprLeave(self_);
        return NULL;
    }
    numfields = PySequence_Size(fields);
    if numfields < 0 {
        Py_ReprLeave(self_);
        object_decref(fields);
        return NULL;
    }
    if numfields == 0 {
        Py_ReprLeave(self_);
        object_decref(fields);
        return PyUnicode_FromFormat("%s()", tp_name);
    }
    writer = PyUnicodeWriter_Create(0);
    if not writer {
        return repr_error(self_, fields, writer);
    }
    if PyUnicodeWriter_WriteUTF8(writer, tp_name, -1) < 0 {
        return repr_error(self_, fields, writer);
    }
    if PyUnicodeWriter_WriteChar(writer, u32(40)) < 0 {
        return repr_error(self_, fields, writer);
    }
    i: i64 = 0;
    while i < numfields {
        name = PySequence_GetItem(fields, i);
        if not name {
            return repr_error(self_, fields, writer);
        }
        value = PyObject_GetAttr(self_, name);
        if not value {
            object_decref(name);
            return repr_error(self_, fields, writer);
        }
        value_repr = NULL;
        if list_check(value) or tuple_check(value) {
            value_repr = ast_repr_list(value, depth);
        } elif PyType_IsSubtype(
            ptr[PyObject](object_type(value)), state.view(1)[0].AST_type
        )
            != 0 {
            value_repr = ast_repr_max_depth(value, depth - 1);
        } else {
            value_repr = PyObject_Repr(value);
        }
        object_decref(value);
        if not value_repr {
            object_decref(name);
            return repr_error(self_, fields, writer);
        }
        if i > 0 {
            if PyUnicodeWriter_WriteASCII(writer, ptr[u8](", "), 2) < 0 {
                object_decref(name);
                object_decref(value_repr);
                return repr_error(self_, fields, writer);
            }
        }
        if PyUnicodeWriter_WriteStr(writer, name) < 0 {
            object_decref(name);
            object_decref(value_repr);
            return repr_error(self_, fields, writer);
        }
        object_decref(name);
        if PyUnicodeWriter_WriteChar(writer, u32(61)) < 0 {
            object_decref(value_repr);
            return repr_error(self_, fields, writer);
        }
        if PyUnicodeWriter_WriteStr(writer, value_repr) < 0 {
            object_decref(value_repr);
            return repr_error(self_, fields, writer);
        }
        object_decref(value_repr);
        i += 1;
    }
    if PyUnicodeWriter_WriteChar(writer, u32(41)) < 0 {
        return repr_error(self_, fields, writer);
    }
    Py_ReprLeave(self_);
    object_decref(fields);
    return PyUnicodeWriter_Finish(writer);
}

impl ast_repr(self_: ptr[PyObject]) -> ptr[PyObject] {
    return ast_repr_max_depth(self_, 3);
}

impl make_type(
    state: ptr[ast_state],
    type_name: ptr[u8],
    base: ptr[PyObject],
    fields: ptr[ptr[u8]],
    num_fields: i32,
    doc: ptr[u8]
) -> ptr[PyObject] {
    fnames = PyTuple_New(i64(num_fields));
    if not fnames {
        return NULL;
    }
    i: i64 = 0;
    while i < i64(num_fields) {
        field = PyUnicode_InternFromString((fields + i).view(1)[0]);
        if not field {
            object_decref(fnames);
            return NULL;
        }
        tuple_set_item(fnames, i, field);
        i += 1;
    }
    result = PyObject_CallFunction(
        ptr[PyObject](addressof(PyType_Type)),
        "s(O){OOOOOOOs}",
        type_name,
        base,
        state.view(1)[0]._fields,
        fnames,
        state.view(1)[0].__match_args__,
        fnames,
        state.view(1)[0].__module__,
        state.view(1)[0].ast,
        state.view(1)[0].__doc__,
        doc
    );
    object_decref(fnames);
    return result;
}

impl add_attributes(
    state: ptr[ast_state], type: ptr[PyObject], attrs: ptr[ptr[u8]], num_fields: i32
) -> i32 {
    l = PyTuple_New(i64(num_fields));
    if not l {
        return -1;
    }
    i: i64 = 0;
    while i < i64(num_fields) {
        s = PyUnicode_InternFromString((attrs + i).view(1)[0]);
        if not s {
            object_decref(l);
            return -1;
        }
        tuple_set_item(l, i, s);
        i += 1;
    }
    result = PyObject_SetAttr(type, state.view(1)[0]._attributes, l);
    object_decref(l);
    return result;
}

impl add_field_annotation(
    annotations: ptr[PyObject],
    name: ptr[u8],
    field_type: ptr[PyObject],
    quantifier: i32
) -> bool {
    type = field_type;
    if quantifier == 1 {
        type = _Py_union_type_or(type, Py_None);
        if not type {
            return False;
        }
    } elif quantifier == 2 {
        type = Py_GenericAlias(ptr[PyObject](addressof(PyList_Type)), type);
        if not type {
            return False;
        }
    } else {
        object_incref(type);
    }
    cond = PyDict_SetItemString(annotations, name, type) == 0;
    object_decref(type);
    return cond;
}

impl set_field_annotations(type: ptr[PyObject], annotations: ptr[PyObject]) -> bool {
    if PyObject_SetAttrString(type, ptr[u8]("_field_types"), annotations) != 0 {
        object_decref(annotations);
        return False;
    }
    if PyObject_SetAttrString(type, ptr[u8]("__annotations__"), annotations) != 0 {
        object_decref(annotations);
        return False;
    }
    object_decref(annotations);
    return True;
}

impl ast2obj_failed(result: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    Py_LeaveRecursiveCall();
    object_xdecref(value);
    object_xdecref(result);
    return NULL;
}

impl ast2obj_object(state: ptr[ast_state], o: ptr[PyObject]) -> ptr[PyObject] {
    op = o;
    if not op {
        op = Py_None;
    }
    return object_new_ref(op);
}

impl ast2obj_int(state: ptr[ast_state], b: i64) -> ptr[PyObject] {
    return PyLong_FromLong(b);
}

impl obj2ast_object(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[PyObject]] {
    op = obj_;
    if op == Py_None {
        op = NULL;
    }
    if op {
        if _PyArena_AddPyObject(arena, op) < 0 {
            return (i32(-1), NULL);
        }
        return (i32(0), object_new_ref(op));
    }
    return (i32(0), NULL);
}

impl obj2ast_constant(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[PyObject]] {
    if _PyArena_AddPyObject(arena, obj_) < 0 {
        return (i32(-1), NULL);
    }
    return (i32(0), object_new_ref(obj_));
}

impl obj2ast_identifier(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[PyObject]] {
    if not unicode_check_exact(obj_) and obj_ != Py_None {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("AST identifier must be of type str"));
        return (i32(-1), NULL);
    }
    return obj2ast_object(state, obj_, arena);
}

impl obj2ast_string(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[PyObject]] {
    if not unicode_check_exact(obj_) and not bytes_check_exact(obj_) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("AST string must be of type str"));
        return (i32(-1), NULL);
    }
    return obj2ast_object(state, obj_, arena);
}

impl obj2ast_int(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32] {
    if not long_check(obj_) {
        PyErr_Format(PyExc_ValueError, ptr[u8]("invalid integer value: %R"), obj_);
        return (i32(-1), i32(0));
    }
    i = PyLong_AsInt(obj_);
    if i == -1 {
        if PyErr_Occurred() {
            return (i32(-1), i32(0));
        }
    }
    return (i32(0), i);
}

impl add_ast_fields(state: ptr[ast_state]) -> i32 {
    empty_tuple = PyTuple_New(0);
    if not empty_tuple
        or PyObject_SetAttrString(
            state.view(1)[0].AST_type, ptr[u8]("_fields"), empty_tuple
        )
            < 0
        or PyObject_SetAttrString(
            state.view(1)[0].AST_type, ptr[u8]("__match_args__"), empty_tuple
        )
            < 0
        or PyObject_SetAttrString(
            state.view(1)[0].AST_type, ptr[u8]("_attributes"), empty_tuple
        )
            < 0 {
        object_xdecref(empty_tuple);
        return -1;
    }
    object_decref(empty_tuple);
    return 0;
}

impl init_identifiers(state: ptr[ast_state]) -> i32 {
    state.view(1)[0].__dict__ = PyUnicode_InternFromString(ptr[u8]("__dict__"));
    if not state.view(1)[0].__dict__ {
        return -1;
    }
    state.view(1)[0].__doc__ = PyUnicode_InternFromString(ptr[u8]("__doc__"));
    if not state.view(1)[0].__doc__ {
        return -1;
    }
    state.view(1)[0].__match_args__ = PyUnicode_InternFromString(
        ptr[u8]("__match_args__")
    );
    if not state.view(1)[0].__match_args__ {
        return -1;
    }
    state.view(1)[0].__module__ = PyUnicode_InternFromString(ptr[u8]("__module__"));
    if not state.view(1)[0].__module__ {
        return -1;
    }
    state.view(1)[0]._attributes = PyUnicode_InternFromString(ptr[u8]("_attributes"));
    if not state.view(1)[0]._attributes {
        return -1;
    }
    state.view(1)[0]._fields = PyUnicode_InternFromString(ptr[u8]("_fields"));
    if not state.view(1)[0]._fields {
        return -1;
    }
    state.view(1)[0].annotation = PyUnicode_InternFromString(ptr[u8]("annotation"));
    if not state.view(1)[0].annotation {
        return -1;
    }
    state.view(1)[0].arg = PyUnicode_InternFromString(ptr[u8]("arg"));
    if not state.view(1)[0].arg {
        return -1;
    }
    state.view(1)[0].args = PyUnicode_InternFromString(ptr[u8]("args"));
    if not state.view(1)[0].args {
        return -1;
    }
    state.view(1)[0].argtypes = PyUnicode_InternFromString(ptr[u8]("argtypes"));
    if not state.view(1)[0].argtypes {
        return -1;
    }
    state.view(1)[0].asname = PyUnicode_InternFromString(ptr[u8]("asname"));
    if not state.view(1)[0].asname {
        return -1;
    }
    state.view(1)[0].ast = PyUnicode_InternFromString(ptr[u8]("ast"));
    if not state.view(1)[0].ast {
        return -1;
    }
    state.view(1)[0].attr = PyUnicode_InternFromString(ptr[u8]("attr"));
    if not state.view(1)[0].attr {
        return -1;
    }
    state.view(1)[0].bases = PyUnicode_InternFromString(ptr[u8]("bases"));
    if not state.view(1)[0].bases {
        return -1;
    }
    state.view(1)[0].body = PyUnicode_InternFromString(ptr[u8]("body"));
    if not state.view(1)[0].body {
        return -1;
    }
    state.view(1)[0].bound = PyUnicode_InternFromString(ptr[u8]("bound"));
    if not state.view(1)[0].bound {
        return -1;
    }
    state.view(1)[0].cases = PyUnicode_InternFromString(ptr[u8]("cases"));
    if not state.view(1)[0].cases {
        return -1;
    }
    state.view(1)[0].cause = PyUnicode_InternFromString(ptr[u8]("cause"));
    if not state.view(1)[0].cause {
        return -1;
    }
    state.view(1)[0].cls = PyUnicode_InternFromString(ptr[u8]("cls"));
    if not state.view(1)[0].cls {
        return -1;
    }
    state.view(1)[0].col_offset = PyUnicode_InternFromString(ptr[u8]("col_offset"));
    if not state.view(1)[0].col_offset {
        return -1;
    }
    state.view(1)[0].comparators = PyUnicode_InternFromString(ptr[u8]("comparators"));
    if not state.view(1)[0].comparators {
        return -1;
    }
    state.view(1)[0].context_expr = PyUnicode_InternFromString(ptr[u8]("context_expr"));
    if not state.view(1)[0].context_expr {
        return -1;
    }
    state.view(1)[0].conversion = PyUnicode_InternFromString(ptr[u8]("conversion"));
    if not state.view(1)[0].conversion {
        return -1;
    }
    state.view(1)[0].ctx = PyUnicode_InternFromString(ptr[u8]("ctx"));
    if not state.view(1)[0].ctx {
        return -1;
    }
    state.view(1)[0].decorator_list = PyUnicode_InternFromString(
        ptr[u8]("decorator_list")
    );
    if not state.view(1)[0].decorator_list {
        return -1;
    }
    state.view(1)[0].default_value = PyUnicode_InternFromString(
        ptr[u8]("default_value")
    );
    if not state.view(1)[0].default_value {
        return -1;
    }
    state.view(1)[0].defaults = PyUnicode_InternFromString(ptr[u8]("defaults"));
    if not state.view(1)[0].defaults {
        return -1;
    }
    state.view(1)[0].elt = PyUnicode_InternFromString(ptr[u8]("elt"));
    if not state.view(1)[0].elt {
        return -1;
    }
    state.view(1)[0].elts = PyUnicode_InternFromString(ptr[u8]("elts"));
    if not state.view(1)[0].elts {
        return -1;
    }
    state.view(1)[0].end_col_offset = PyUnicode_InternFromString(
        ptr[u8]("end_col_offset")
    );
    if not state.view(1)[0].end_col_offset {
        return -1;
    }
    state.view(1)[0].end_lineno = PyUnicode_InternFromString(ptr[u8]("end_lineno"));
    if not state.view(1)[0].end_lineno {
        return -1;
    }
    state.view(1)[0].exc = PyUnicode_InternFromString(ptr[u8]("exc"));
    if not state.view(1)[0].exc {
        return -1;
    }
    state.view(1)[0].finalbody = PyUnicode_InternFromString(ptr[u8]("finalbody"));
    if not state.view(1)[0].finalbody {
        return -1;
    }
    state.view(1)[0].format_spec = PyUnicode_InternFromString(ptr[u8]("format_spec"));
    if not state.view(1)[0].format_spec {
        return -1;
    }
    state.view(1)[0].func = PyUnicode_InternFromString(ptr[u8]("func"));
    if not state.view(1)[0].func {
        return -1;
    }
    state.view(1)[0].generators = PyUnicode_InternFromString(ptr[u8]("generators"));
    if not state.view(1)[0].generators {
        return -1;
    }
    state.view(1)[0].guard = PyUnicode_InternFromString(ptr[u8]("guard"));
    if not state.view(1)[0].guard {
        return -1;
    }
    state.view(1)[0].handlers = PyUnicode_InternFromString(ptr[u8]("handlers"));
    if not state.view(1)[0].handlers {
        return -1;
    }
    state.view(1)[0].id = PyUnicode_InternFromString(ptr[u8]("id"));
    if not state.view(1)[0].id {
        return -1;
    }
    state.view(1)[0].ifs = PyUnicode_InternFromString(ptr[u8]("ifs"));
    if not state.view(1)[0].ifs {
        return -1;
    }
    state.view(1)[0].is_async = PyUnicode_InternFromString(ptr[u8]("is_async"));
    if not state.view(1)[0].is_async {
        return -1;
    }
    state.view(1)[0].items = PyUnicode_InternFromString(ptr[u8]("items"));
    if not state.view(1)[0].items {
        return -1;
    }
    state.view(1)[0].iter = PyUnicode_InternFromString(ptr[u8]("iter"));
    if not state.view(1)[0].iter {
        return -1;
    }
    state.view(1)[0].key = PyUnicode_InternFromString(ptr[u8]("key"));
    if not state.view(1)[0].key {
        return -1;
    }
    state.view(1)[0].keys = PyUnicode_InternFromString(ptr[u8]("keys"));
    if not state.view(1)[0].keys {
        return -1;
    }
    state.view(1)[0].keywords = PyUnicode_InternFromString(ptr[u8]("keywords"));
    if not state.view(1)[0].keywords {
        return -1;
    }
    state.view(1)[0].kind = PyUnicode_InternFromString(ptr[u8]("kind"));
    if not state.view(1)[0].kind {
        return -1;
    }
    state.view(1)[0].kw_defaults = PyUnicode_InternFromString(ptr[u8]("kw_defaults"));
    if not state.view(1)[0].kw_defaults {
        return -1;
    }
    state.view(1)[0].kwarg = PyUnicode_InternFromString(ptr[u8]("kwarg"));
    if not state.view(1)[0].kwarg {
        return -1;
    }
    state.view(1)[0].kwd_attrs = PyUnicode_InternFromString(ptr[u8]("kwd_attrs"));
    if not state.view(1)[0].kwd_attrs {
        return -1;
    }
    state.view(1)[0].kwd_patterns = PyUnicode_InternFromString(ptr[u8]("kwd_patterns"));
    if not state.view(1)[0].kwd_patterns {
        return -1;
    }
    state.view(1)[0].kwonlyargs = PyUnicode_InternFromString(ptr[u8]("kwonlyargs"));
    if not state.view(1)[0].kwonlyargs {
        return -1;
    }
    state.view(1)[0].left = PyUnicode_InternFromString(ptr[u8]("left"));
    if not state.view(1)[0].left {
        return -1;
    }
    state.view(1)[0].level = PyUnicode_InternFromString(ptr[u8]("level"));
    if not state.view(1)[0].level {
        return -1;
    }
    state.view(1)[0].lineno = PyUnicode_InternFromString(ptr[u8]("lineno"));
    if not state.view(1)[0].lineno {
        return -1;
    }
    state.view(1)[0].lower = PyUnicode_InternFromString(ptr[u8]("lower"));
    if not state.view(1)[0].lower {
        return -1;
    }
    state.view(1)[0].module = PyUnicode_InternFromString(ptr[u8]("module"));
    if not state.view(1)[0].module {
        return -1;
    }
    state.view(1)[0].msg = PyUnicode_InternFromString(ptr[u8]("msg"));
    if not state.view(1)[0].msg {
        return -1;
    }
    state.view(1)[0].name = PyUnicode_InternFromString(ptr[u8]("name"));
    if not state.view(1)[0].name {
        return -1;
    }
    state.view(1)[0].names = PyUnicode_InternFromString(ptr[u8]("names"));
    if not state.view(1)[0].names {
        return -1;
    }
    state.view(1)[0].op = PyUnicode_InternFromString(ptr[u8]("op"));
    if not state.view(1)[0].op {
        return -1;
    }
    state.view(1)[0].operand = PyUnicode_InternFromString(ptr[u8]("operand"));
    if not state.view(1)[0].operand {
        return -1;
    }
    state.view(1)[0].ops = PyUnicode_InternFromString(ptr[u8]("ops"));
    if not state.view(1)[0].ops {
        return -1;
    }
    state.view(1)[0].optional_vars = PyUnicode_InternFromString(
        ptr[u8]("optional_vars")
    );
    if not state.view(1)[0].optional_vars {
        return -1;
    }
    state.view(1)[0].orelse = PyUnicode_InternFromString(ptr[u8]("orelse"));
    if not state.view(1)[0].orelse {
        return -1;
    }
    state.view(1)[0].pattern = PyUnicode_InternFromString(ptr[u8]("pattern"));
    if not state.view(1)[0].pattern {
        return -1;
    }
    state.view(1)[0].patterns = PyUnicode_InternFromString(ptr[u8]("patterns"));
    if not state.view(1)[0].patterns {
        return -1;
    }
    state.view(1)[0].posonlyargs = PyUnicode_InternFromString(ptr[u8]("posonlyargs"));
    if not state.view(1)[0].posonlyargs {
        return -1;
    }
    state.view(1)[0].rest = PyUnicode_InternFromString(ptr[u8]("rest"));
    if not state.view(1)[0].rest {
        return -1;
    }
    state.view(1)[0].returns = PyUnicode_InternFromString(ptr[u8]("returns"));
    if not state.view(1)[0].returns {
        return -1;
    }
    state.view(1)[0].right = PyUnicode_InternFromString(ptr[u8]("right"));
    if not state.view(1)[0].right {
        return -1;
    }
    state.view(1)[0].simple = PyUnicode_InternFromString(ptr[u8]("simple"));
    if not state.view(1)[0].simple {
        return -1;
    }
    state.view(1)[0].slice = PyUnicode_InternFromString(ptr[u8]("slice"));
    if not state.view(1)[0].slice {
        return -1;
    }
    state.view(1)[0].step = PyUnicode_InternFromString(ptr[u8]("step"));
    if not state.view(1)[0].step {
        return -1;
    }
    state.view(1)[0].str = PyUnicode_InternFromString(ptr[u8]("str"));
    if not state.view(1)[0].str {
        return -1;
    }
    state.view(1)[0].subject = PyUnicode_InternFromString(ptr[u8]("subject"));
    if not state.view(1)[0].subject {
        return -1;
    }
    state.view(1)[0].tag = PyUnicode_InternFromString(ptr[u8]("tag"));
    if not state.view(1)[0].tag {
        return -1;
    }
    state.view(1)[0].target = PyUnicode_InternFromString(ptr[u8]("target"));
    if not state.view(1)[0].target {
        return -1;
    }
    state.view(1)[0].targets = PyUnicode_InternFromString(ptr[u8]("targets"));
    if not state.view(1)[0].targets {
        return -1;
    }
    state.view(1)[0].test_ = PyUnicode_InternFromString(ptr[u8]("test"));
    if not state.view(1)[0].test_ {
        return -1;
    }
    state.view(1)[0].type = PyUnicode_InternFromString(ptr[u8]("type"));
    if not state.view(1)[0].type {
        return -1;
    }
    state.view(1)[0].type_comment = PyUnicode_InternFromString(ptr[u8]("type_comment"));
    if not state.view(1)[0].type_comment {
        return -1;
    }
    state.view(1)[0].type_ignores = PyUnicode_InternFromString(ptr[u8]("type_ignores"));
    if not state.view(1)[0].type_ignores {
        return -1;
    }
    state.view(1)[0].type_params = PyUnicode_InternFromString(ptr[u8]("type_params"));
    if not state.view(1)[0].type_params {
        return -1;
    }
    state.view(1)[0].upper = PyUnicode_InternFromString(ptr[u8]("upper"));
    if not state.view(1)[0].upper {
        return -1;
    }
    state.view(1)[0].value = PyUnicode_InternFromString(ptr[u8]("value"));
    if not state.view(1)[0].value {
        return -1;
    }
    state.view(1)[0].values = PyUnicode_InternFromString(ptr[u8]("values"));
    if not state.view(1)[0].values {
        return -1;
    }
    state.view(1)[0].vararg = PyUnicode_InternFromString(ptr[u8]("vararg"));
    if not state.view(1)[0].vararg {
        return -1;
    }
    return 0;
}

impl add_ast_annotations(state: ptr[ast_state]) -> i32 {
    annotations = NULL;
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("type_ignores"), state.view(1)[0].type_ignore_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Module_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Interactive_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Expression_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("argtypes"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("returns"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].FunctionType_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("args"), state.view(1)[0].arguments_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("decorator_list"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("returns"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations,
        ptr[u8]("type_comment"),
        ptr[PyObject](addressof(PyUnicode_Type)),
        1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("type_params"), state.view(1)[0].type_param_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].FunctionDef_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("args"), state.view(1)[0].arguments_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("decorator_list"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("returns"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations,
        ptr[u8]("type_comment"),
        ptr[PyObject](addressof(PyUnicode_Type)),
        1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("type_params"), state.view(1)[0].type_param_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].AsyncFunctionDef_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("bases"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("keywords"), state.view(1)[0].keyword_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("decorator_list"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("type_params"), state.view(1)[0].type_param_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].ClassDef_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Return_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("targets"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Delete_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("targets"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations,
        ptr[u8]("type_comment"),
        ptr[PyObject](addressof(PyUnicode_Type)),
        1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Assign_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("type_params"), state.view(1)[0].type_param_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].TypeAlias_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("target"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("op"), state.view(1)[0].operator_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].AugAssign_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("target"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("annotation"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("simple"), ptr[PyObject](addressof(PyLong_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].AnnAssign_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("target"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("iter"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("orelse"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations,
        ptr[u8]("type_comment"),
        ptr[PyObject](addressof(PyUnicode_Type)),
        1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].For_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("target"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("iter"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("orelse"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations,
        ptr[u8]("type_comment"),
        ptr[PyObject](addressof(PyUnicode_Type)),
        1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].AsyncFor_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("test"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("orelse"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].While_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("test"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("orelse"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].If_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("items"), state.view(1)[0].withitem_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations,
        ptr[u8]("type_comment"),
        ptr[PyObject](addressof(PyUnicode_Type)),
        1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].With_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("items"), state.view(1)[0].withitem_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations,
        ptr[u8]("type_comment"),
        ptr[PyObject](addressof(PyUnicode_Type)),
        1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].AsyncWith_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("subject"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("cases"), state.view(1)[0].match_case_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Match_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("exc"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("cause"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Raise_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("handlers"), state.view(1)[0].excepthandler_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("orelse"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("finalbody"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Try_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("handlers"), state.view(1)[0].excepthandler_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("orelse"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("finalbody"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].TryStar_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("test"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("msg"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Assert_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("names"), state.view(1)[0].alias_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Import_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("module"), ptr[PyObject](addressof(PyUnicode_Type)), 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("names"), state.view(1)[0].alias_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("level"), ptr[PyObject](addressof(PyLong_Type)), 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].ImportFrom_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("names"), ptr[PyObject](addressof(PyUnicode_Type)), 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Global_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("names"), ptr[PyObject](addressof(PyUnicode_Type)), 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Nonlocal_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Expr_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Pass_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Break_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Continue_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("op"), state.view(1)[0].boolop_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("values"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].BoolOp_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("target"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].NamedExpr_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("left"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("op"), state.view(1)[0].operator_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("right"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].BinOp_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("op"), state.view(1)[0].unaryop_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("operand"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].UnaryOp_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("args"), state.view(1)[0].arguments_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Lambda_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("test"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("orelse"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].IfExp_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("keys"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("values"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Dict_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("elts"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Set_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("elt"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("generators"), state.view(1)[0].comprehension_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].ListComp_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("elt"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("generators"), state.view(1)[0].comprehension_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].SetComp_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("key"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("generators"), state.view(1)[0].comprehension_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].DictComp_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("elt"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("generators"), state.view(1)[0].comprehension_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].GeneratorExp_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Await_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Yield_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].YieldFrom_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("left"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("ops"), state.view(1)[0].cmpop_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("comparators"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Compare_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("func"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("args"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("keywords"), state.view(1)[0].keyword_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Call_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("conversion"), ptr[PyObject](addressof(PyLong_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("format_spec"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].FormattedValue_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("str"), ptr[PyObject](addressof(PyBaseObject_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("conversion"), ptr[PyObject](addressof(PyLong_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("format_spec"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Interpolation_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("values"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].JoinedStr_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("values"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].TemplateStr_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), ptr[PyObject](addressof(PyBaseObject_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("kind"), ptr[PyObject](addressof(PyUnicode_Type)), 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Constant_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("attr"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("ctx"), state.view(1)[0].expr_context_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Attribute_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("slice"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("ctx"), state.view(1)[0].expr_context_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Subscript_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("ctx"), state.view(1)[0].expr_context_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Starred_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("id"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("ctx"), state.view(1)[0].expr_context_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Name_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("elts"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("ctx"), state.view(1)[0].expr_context_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].List_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("elts"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("ctx"), state.view(1)[0].expr_context_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Tuple_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("lower"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("upper"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("step"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Slice_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Load_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Store_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Del_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].And_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Or_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Add_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Sub_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Mult_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].MatMult_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Div_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Mod_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Pow_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].LShift_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].RShift_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].BitOr_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].BitXor_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].BitAnd_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].FloorDiv_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Invert_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Not_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].UAdd_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].USub_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Eq_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].NotEq_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Lt_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].LtE_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Gt_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].GtE_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].Is_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].IsNot_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].In_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].NotIn_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("target"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("iter"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("ifs"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("is_async"), ptr[PyObject](addressof(PyLong_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].comprehension_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("type"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].ExceptHandler_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("posonlyargs"), state.view(1)[0].arg_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("args"), state.view(1)[0].arg_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("vararg"), state.view(1)[0].arg_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("kwonlyargs"), state.view(1)[0].arg_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("kw_defaults"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("kwarg"), state.view(1)[0].arg_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("defaults"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].arguments_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("arg"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("annotation"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations,
        ptr[u8]("type_comment"),
        ptr[PyObject](addressof(PyUnicode_Type)),
        1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].arg_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("arg"), ptr[PyObject](addressof(PyUnicode_Type)), 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].keyword_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("asname"), ptr[PyObject](addressof(PyUnicode_Type)), 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].alias_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("context_expr"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("optional_vars"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].withitem_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("pattern"), state.view(1)[0].pattern_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("guard"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("body"), state.view(1)[0].stmt_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].match_case_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].MatchValue_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("value"), ptr[PyObject](addressof(PyBaseObject_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].MatchSingleton_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("patterns"), state.view(1)[0].pattern_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].MatchSequence_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("keys"), state.view(1)[0].expr_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("patterns"), state.view(1)[0].pattern_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("rest"), ptr[PyObject](addressof(PyUnicode_Type)), 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].MatchMapping_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("cls"), state.view(1)[0].expr_type, 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("patterns"), state.view(1)[0].pattern_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("kwd_attrs"), ptr[PyObject](addressof(PyUnicode_Type)), 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("kwd_patterns"), state.view(1)[0].pattern_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].MatchClass_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].MatchStar_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("pattern"), state.view(1)[0].pattern_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].MatchAs_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("patterns"), state.view(1)[0].pattern_type, 2
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].MatchOr_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("lineno"), ptr[PyObject](addressof(PyLong_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("tag"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].TypeIgnore_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("bound"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("default_value"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].TypeVar_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("default_value"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].ParamSpec_type, annotations) {
        return 0;
    }
    annotations = PyDict_New();
    if not annotations {
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("name"), ptr[PyObject](addressof(PyUnicode_Type)), 0
    ) {
        object_decref(annotations);
        return 0;
    }
    if not add_field_annotation(
        annotations, ptr[u8]("default_value"), state.view(1)[0].expr_type, 1
    ) {
        object_decref(annotations);
        return 0;
    }
    if not set_field_annotations(state.view(1)[0].TypeVarTuple_type, annotations) {
        return 0;
    }
    return 1;
}

impl init_types(arg: ptr) -> i32 {
    state = ptr[ast_state](arg);
    if init_identifiers(state) < 0 {
        return -1;
    }
    state.view(1)[0].AST_type = PyType_FromSpec(addressof(AST_type_spec));
    if not state.view(1)[0].AST_type {
        return -1;
    }
    if add_ast_fields(state) < 0 {
        return -1;
    }
    state.view(1)[0].mod_type = make_type(
        state,
        ptr[u8]("mod"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8](
            "mod = Module(stmt* body, type_ignore* type_ignores)\n    | Interactive(stmt* body)\n    | Expression(expr body)\n    | FunctionType(expr* argtypes, expr returns)"
        )
    );
    if not state.view(1)[0].mod_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].mod_type, ptr[ptr[u8]](), 0) < 0 {
        return -1;
    }
    state.view(1)[0].Module_type = make_type(
        state,
        ptr[u8]("Module"),
        state.view(1)[0].mod_type,
        addressof(Module_fields),
        2,
        ptr[u8]("Module(stmt* body, type_ignore* type_ignores)")
    );
    if not state.view(1)[0].Module_type {
        return -1;
    }
    state.view(1)[0].Interactive_type = make_type(
        state,
        ptr[u8]("Interactive"),
        state.view(1)[0].mod_type,
        addressof(Interactive_fields),
        1,
        ptr[u8]("Interactive(stmt* body)")
    );
    if not state.view(1)[0].Interactive_type {
        return -1;
    }
    state.view(1)[0].Expression_type = make_type(
        state,
        ptr[u8]("Expression"),
        state.view(1)[0].mod_type,
        addressof(Expression_fields),
        1,
        ptr[u8]("Expression(expr body)")
    );
    if not state.view(1)[0].Expression_type {
        return -1;
    }
    state.view(1)[0].FunctionType_type = make_type(
        state,
        ptr[u8]("FunctionType"),
        state.view(1)[0].mod_type,
        addressof(FunctionType_fields),
        2,
        ptr[u8]("FunctionType(expr* argtypes, expr returns)")
    );
    if not state.view(1)[0].FunctionType_type {
        return -1;
    }
    state.view(1)[0].stmt_type = make_type(
        state,
        ptr[u8]("stmt"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8](
            "stmt = FunctionDef(identifier name, arguments args, stmt* body, expr* decorator_list, expr? returns, string? type_comment, type_param* type_params)\n     | AsyncFunctionDef(identifier name, arguments args, stmt* body, expr* decorator_list, expr? returns, string? type_comment, type_param* type_params)\n     | ClassDef(identifier name, expr* bases, keyword* keywords, stmt* body, expr* decorator_list, type_param* type_params)\n     | Return(expr? value)\n     | Delete(expr* targets)\n     | Assign(expr* targets, expr value, string? type_comment)\n     | TypeAlias(expr name, type_param* type_params, expr value)\n     | AugAssign(expr target, operator op, expr value)\n     | AnnAssign(expr target, expr annotation, expr? value, int simple)\n     | For(expr target, expr iter, stmt* body, stmt* orelse, string? type_comment)\n     | AsyncFor(expr target, expr iter, stmt* body, stmt* orelse, string? type_comment)\n     | While(expr test, stmt* body, stmt* orelse)\n     | If(expr test, stmt* body, stmt* orelse)\n     | With(withitem* items, stmt* body, string? type_comment)\n     | AsyncWith(withitem* items, stmt* body, string? type_comment)\n     | Match(expr subject, match_case* cases)\n     | Raise(expr? exc, expr? cause)\n     | Try(stmt* body, excepthandler* handlers, stmt* orelse, stmt* finalbody)\n     | TryStar(stmt* body, excepthandler* handlers, stmt* orelse, stmt* finalbody)\n     | Assert(expr test, expr? msg)\n     | Import(alias* names)\n     | ImportFrom(identifier? module, alias* names, int? level)\n     | Global(identifier* names)\n     | Nonlocal(identifier* names)\n     | Expr(expr value)\n     | Pass\n     | Break\n     | Continue"
        )
    );
    if not state.view(1)[0].stmt_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].stmt_type, addressof(stmt_attributes), 4)
        < 0 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].stmt_type, state.view(1)[0].end_lineno, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].stmt_type, state.view(1)[0].end_col_offset, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].FunctionDef_type = make_type(
        state,
        ptr[u8]("FunctionDef"),
        state.view(1)[0].stmt_type,
        addressof(FunctionDef_fields),
        7,
        ptr[u8](
            "FunctionDef(identifier name, arguments args, stmt* body, expr* decorator_list, expr? returns, string? type_comment, type_param* type_params)"
        )
    );
    if not state.view(1)[0].FunctionDef_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].FunctionDef_type, state.view(1)[0].returns, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].FunctionDef_type, state.view(1)[0].type_comment, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].AsyncFunctionDef_type = make_type(
        state,
        ptr[u8]("AsyncFunctionDef"),
        state.view(1)[0].stmt_type,
        addressof(AsyncFunctionDef_fields),
        7,
        ptr[u8](
            "AsyncFunctionDef(identifier name, arguments args, stmt* body, expr* decorator_list, expr? returns, string? type_comment, type_param* type_params)"
        )
    );
    if not state.view(1)[0].AsyncFunctionDef_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].AsyncFunctionDef_type, state.view(1)[0].returns, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].AsyncFunctionDef_type, state.view(1)[0].type_comment, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].ClassDef_type = make_type(
        state,
        ptr[u8]("ClassDef"),
        state.view(1)[0].stmt_type,
        addressof(ClassDef_fields),
        6,
        ptr[u8](
            "ClassDef(identifier name, expr* bases, keyword* keywords, stmt* body, expr* decorator_list, type_param* type_params)"
        )
    );
    if not state.view(1)[0].ClassDef_type {
        return -1;
    }
    state.view(1)[0].Return_type = make_type(
        state,
        ptr[u8]("Return"),
        state.view(1)[0].stmt_type,
        addressof(Return_fields),
        1,
        ptr[u8]("Return(expr? value)")
    );
    if not state.view(1)[0].Return_type {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].Return_type, state.view(1)[0].value, Py_None)
        == -1 {
        return -1;
    }
    state.view(1)[0].Delete_type = make_type(
        state,
        ptr[u8]("Delete"),
        state.view(1)[0].stmt_type,
        addressof(Delete_fields),
        1,
        ptr[u8]("Delete(expr* targets)")
    );
    if not state.view(1)[0].Delete_type {
        return -1;
    }
    state.view(1)[0].Assign_type = make_type(
        state,
        ptr[u8]("Assign"),
        state.view(1)[0].stmt_type,
        addressof(Assign_fields),
        3,
        ptr[u8]("Assign(expr* targets, expr value, string? type_comment)")
    );
    if not state.view(1)[0].Assign_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].Assign_type, state.view(1)[0].type_comment, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].TypeAlias_type = make_type(
        state,
        ptr[u8]("TypeAlias"),
        state.view(1)[0].stmt_type,
        addressof(TypeAlias_fields),
        3,
        ptr[u8]("TypeAlias(expr name, type_param* type_params, expr value)")
    );
    if not state.view(1)[0].TypeAlias_type {
        return -1;
    }
    state.view(1)[0].AugAssign_type = make_type(
        state,
        ptr[u8]("AugAssign"),
        state.view(1)[0].stmt_type,
        addressof(AugAssign_fields),
        3,
        ptr[u8]("AugAssign(expr target, operator op, expr value)")
    );
    if not state.view(1)[0].AugAssign_type {
        return -1;
    }
    state.view(1)[0].AnnAssign_type = make_type(
        state,
        ptr[u8]("AnnAssign"),
        state.view(1)[0].stmt_type,
        addressof(AnnAssign_fields),
        4,
        ptr[u8]("AnnAssign(expr target, expr annotation, expr? value, int simple)")
    );
    if not state.view(1)[0].AnnAssign_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].AnnAssign_type, state.view(1)[0].value, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].For_type = make_type(
        state,
        ptr[u8]("For"),
        state.view(1)[0].stmt_type,
        addressof(For_fields),
        5,
        ptr[u8](
            "For(expr target, expr iter, stmt* body, stmt* orelse, string? type_comment)"
        )
    );
    if not state.view(1)[0].For_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].For_type, state.view(1)[0].type_comment, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].AsyncFor_type = make_type(
        state,
        ptr[u8]("AsyncFor"),
        state.view(1)[0].stmt_type,
        addressof(AsyncFor_fields),
        5,
        ptr[u8](
            "AsyncFor(expr target, expr iter, stmt* body, stmt* orelse, string? type_comment)"
        )
    );
    if not state.view(1)[0].AsyncFor_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].AsyncFor_type, state.view(1)[0].type_comment, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].While_type = make_type(
        state,
        ptr[u8]("While"),
        state.view(1)[0].stmt_type,
        addressof(While_fields),
        3,
        ptr[u8]("While(expr test, stmt* body, stmt* orelse)")
    );
    if not state.view(1)[0].While_type {
        return -1;
    }
    state.view(1)[0].If_type = make_type(
        state,
        ptr[u8]("If"),
        state.view(1)[0].stmt_type,
        addressof(If_fields),
        3,
        ptr[u8]("If(expr test, stmt* body, stmt* orelse)")
    );
    if not state.view(1)[0].If_type {
        return -1;
    }
    state.view(1)[0].With_type = make_type(
        state,
        ptr[u8]("With"),
        state.view(1)[0].stmt_type,
        addressof(With_fields),
        3,
        ptr[u8]("With(withitem* items, stmt* body, string? type_comment)")
    );
    if not state.view(1)[0].With_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].With_type, state.view(1)[0].type_comment, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].AsyncWith_type = make_type(
        state,
        ptr[u8]("AsyncWith"),
        state.view(1)[0].stmt_type,
        addressof(AsyncWith_fields),
        3,
        ptr[u8]("AsyncWith(withitem* items, stmt* body, string? type_comment)")
    );
    if not state.view(1)[0].AsyncWith_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].AsyncWith_type, state.view(1)[0].type_comment, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].Match_type = make_type(
        state,
        ptr[u8]("Match"),
        state.view(1)[0].stmt_type,
        addressof(Match_fields),
        2,
        ptr[u8]("Match(expr subject, match_case* cases)")
    );
    if not state.view(1)[0].Match_type {
        return -1;
    }
    state.view(1)[0].Raise_type = make_type(
        state,
        ptr[u8]("Raise"),
        state.view(1)[0].stmt_type,
        addressof(Raise_fields),
        2,
        ptr[u8]("Raise(expr? exc, expr? cause)")
    );
    if not state.view(1)[0].Raise_type {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].Raise_type, state.view(1)[0].exc, Py_None)
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].Raise_type, state.view(1)[0].cause, Py_None)
        == -1 {
        return -1;
    }
    state.view(1)[0].Try_type = make_type(
        state,
        ptr[u8]("Try"),
        state.view(1)[0].stmt_type,
        addressof(Try_fields),
        4,
        ptr[u8](
            "Try(stmt* body, excepthandler* handlers, stmt* orelse, stmt* finalbody)"
        )
    );
    if not state.view(1)[0].Try_type {
        return -1;
    }
    state.view(1)[0].TryStar_type = make_type(
        state,
        ptr[u8]("TryStar"),
        state.view(1)[0].stmt_type,
        addressof(TryStar_fields),
        4,
        ptr[u8](
            "TryStar(stmt* body, excepthandler* handlers, stmt* orelse, stmt* finalbody)"
        )
    );
    if not state.view(1)[0].TryStar_type {
        return -1;
    }
    state.view(1)[0].Assert_type = make_type(
        state,
        ptr[u8]("Assert"),
        state.view(1)[0].stmt_type,
        addressof(Assert_fields),
        2,
        ptr[u8]("Assert(expr test, expr? msg)")
    );
    if not state.view(1)[0].Assert_type {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].Assert_type, state.view(1)[0].msg, Py_None)
        == -1 {
        return -1;
    }
    state.view(1)[0].Import_type = make_type(
        state,
        ptr[u8]("Import"),
        state.view(1)[0].stmt_type,
        addressof(Import_fields),
        1,
        ptr[u8]("Import(alias* names)")
    );
    if not state.view(1)[0].Import_type {
        return -1;
    }
    state.view(1)[0].ImportFrom_type = make_type(
        state,
        ptr[u8]("ImportFrom"),
        state.view(1)[0].stmt_type,
        addressof(ImportFrom_fields),
        3,
        ptr[u8]("ImportFrom(identifier? module, alias* names, int? level)")
    );
    if not state.view(1)[0].ImportFrom_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].ImportFrom_type, state.view(1)[0].module, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].ImportFrom_type, state.view(1)[0].level, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].Global_type = make_type(
        state,
        ptr[u8]("Global"),
        state.view(1)[0].stmt_type,
        addressof(Global_fields),
        1,
        ptr[u8]("Global(identifier* names)")
    );
    if not state.view(1)[0].Global_type {
        return -1;
    }
    state.view(1)[0].Nonlocal_type = make_type(
        state,
        ptr[u8]("Nonlocal"),
        state.view(1)[0].stmt_type,
        addressof(Nonlocal_fields),
        1,
        ptr[u8]("Nonlocal(identifier* names)")
    );
    if not state.view(1)[0].Nonlocal_type {
        return -1;
    }
    state.view(1)[0].Expr_type = make_type(
        state,
        ptr[u8]("Expr"),
        state.view(1)[0].stmt_type,
        addressof(Expr_fields),
        1,
        ptr[u8]("Expr(expr value)")
    );
    if not state.view(1)[0].Expr_type {
        return -1;
    }
    state.view(1)[0].Pass_type = make_type(
        state,
        ptr[u8]("Pass"),
        state.view(1)[0].stmt_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Pass")
    );
    if not state.view(1)[0].Pass_type {
        return -1;
    }
    state.view(1)[0].Break_type = make_type(
        state,
        ptr[u8]("Break"),
        state.view(1)[0].stmt_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Break")
    );
    if not state.view(1)[0].Break_type {
        return -1;
    }
    state.view(1)[0].Continue_type = make_type(
        state,
        ptr[u8]("Continue"),
        state.view(1)[0].stmt_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Continue")
    );
    if not state.view(1)[0].Continue_type {
        return -1;
    }
    state.view(1)[0].expr_type = make_type(
        state,
        ptr[u8]("expr"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8](
            "expr = BoolOp(boolop op, expr* values)\n     | NamedExpr(expr target, expr value)\n     | BinOp(expr left, operator op, expr right)\n     | UnaryOp(unaryop op, expr operand)\n     | Lambda(arguments args, expr body)\n     | IfExp(expr test, expr body, expr orelse)\n     | Dict(expr?* keys, expr* values)\n     | Set(expr* elts)\n     | ListComp(expr elt, comprehension* generators)\n     | SetComp(expr elt, comprehension* generators)\n     | DictComp(expr key, expr value, comprehension* generators)\n     | GeneratorExp(expr elt, comprehension* generators)\n     | Await(expr value)\n     | Yield(expr? value)\n     | YieldFrom(expr value)\n     | Compare(expr left, cmpop* ops, expr* comparators)\n     | Call(expr func, expr* args, keyword* keywords)\n     | FormattedValue(expr value, int conversion, expr? format_spec)\n     | Interpolation(expr value, constant str, int conversion, expr? format_spec)\n     | JoinedStr(expr* values)\n     | TemplateStr(expr* values)\n     | Constant(constant value, string? kind)\n     | Attribute(expr value, identifier attr, expr_context ctx)\n     | Subscript(expr value, expr slice, expr_context ctx)\n     | Starred(expr value, expr_context ctx)\n     | Name(identifier id, expr_context ctx)\n     | List(expr* elts, expr_context ctx)\n     | Tuple(expr* elts, expr_context ctx)\n     | Slice(expr? lower, expr? upper, expr? step)"
        )
    );
    if not state.view(1)[0].expr_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].expr_type, addressof(expr_attributes), 4)
        < 0 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].expr_type, state.view(1)[0].end_lineno, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].expr_type, state.view(1)[0].end_col_offset, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].BoolOp_type = make_type(
        state,
        ptr[u8]("BoolOp"),
        state.view(1)[0].expr_type,
        addressof(BoolOp_fields),
        2,
        ptr[u8]("BoolOp(boolop op, expr* values)")
    );
    if not state.view(1)[0].BoolOp_type {
        return -1;
    }
    state.view(1)[0].NamedExpr_type = make_type(
        state,
        ptr[u8]("NamedExpr"),
        state.view(1)[0].expr_type,
        addressof(NamedExpr_fields),
        2,
        ptr[u8]("NamedExpr(expr target, expr value)")
    );
    if not state.view(1)[0].NamedExpr_type {
        return -1;
    }
    state.view(1)[0].BinOp_type = make_type(
        state,
        ptr[u8]("BinOp"),
        state.view(1)[0].expr_type,
        addressof(BinOp_fields),
        3,
        ptr[u8]("BinOp(expr left, operator op, expr right)")
    );
    if not state.view(1)[0].BinOp_type {
        return -1;
    }
    state.view(1)[0].UnaryOp_type = make_type(
        state,
        ptr[u8]("UnaryOp"),
        state.view(1)[0].expr_type,
        addressof(UnaryOp_fields),
        2,
        ptr[u8]("UnaryOp(unaryop op, expr operand)")
    );
    if not state.view(1)[0].UnaryOp_type {
        return -1;
    }
    state.view(1)[0].Lambda_type = make_type(
        state,
        ptr[u8]("Lambda"),
        state.view(1)[0].expr_type,
        addressof(Lambda_fields),
        2,
        ptr[u8]("Lambda(arguments args, expr body)")
    );
    if not state.view(1)[0].Lambda_type {
        return -1;
    }
    state.view(1)[0].IfExp_type = make_type(
        state,
        ptr[u8]("IfExp"),
        state.view(1)[0].expr_type,
        addressof(IfExp_fields),
        3,
        ptr[u8]("IfExp(expr test, expr body, expr orelse)")
    );
    if not state.view(1)[0].IfExp_type {
        return -1;
    }
    state.view(1)[0].Dict_type = make_type(
        state,
        ptr[u8]("Dict"),
        state.view(1)[0].expr_type,
        addressof(Dict_fields),
        2,
        ptr[u8]("Dict(expr?* keys, expr* values)")
    );
    if not state.view(1)[0].Dict_type {
        return -1;
    }
    state.view(1)[0].Set_type = make_type(
        state,
        ptr[u8]("Set"),
        state.view(1)[0].expr_type,
        addressof(Set_fields),
        1,
        ptr[u8]("Set(expr* elts)")
    );
    if not state.view(1)[0].Set_type {
        return -1;
    }
    state.view(1)[0].ListComp_type = make_type(
        state,
        ptr[u8]("ListComp"),
        state.view(1)[0].expr_type,
        addressof(ListComp_fields),
        2,
        ptr[u8]("ListComp(expr elt, comprehension* generators)")
    );
    if not state.view(1)[0].ListComp_type {
        return -1;
    }
    state.view(1)[0].SetComp_type = make_type(
        state,
        ptr[u8]("SetComp"),
        state.view(1)[0].expr_type,
        addressof(SetComp_fields),
        2,
        ptr[u8]("SetComp(expr elt, comprehension* generators)")
    );
    if not state.view(1)[0].SetComp_type {
        return -1;
    }
    state.view(1)[0].DictComp_type = make_type(
        state,
        ptr[u8]("DictComp"),
        state.view(1)[0].expr_type,
        addressof(DictComp_fields),
        3,
        ptr[u8]("DictComp(expr key, expr value, comprehension* generators)")
    );
    if not state.view(1)[0].DictComp_type {
        return -1;
    }
    state.view(1)[0].GeneratorExp_type = make_type(
        state,
        ptr[u8]("GeneratorExp"),
        state.view(1)[0].expr_type,
        addressof(GeneratorExp_fields),
        2,
        ptr[u8]("GeneratorExp(expr elt, comprehension* generators)")
    );
    if not state.view(1)[0].GeneratorExp_type {
        return -1;
    }
    state.view(1)[0].Await_type = make_type(
        state,
        ptr[u8]("Await"),
        state.view(1)[0].expr_type,
        addressof(Await_fields),
        1,
        ptr[u8]("Await(expr value)")
    );
    if not state.view(1)[0].Await_type {
        return -1;
    }
    state.view(1)[0].Yield_type = make_type(
        state,
        ptr[u8]("Yield"),
        state.view(1)[0].expr_type,
        addressof(Yield_fields),
        1,
        ptr[u8]("Yield(expr? value)")
    );
    if not state.view(1)[0].Yield_type {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].Yield_type, state.view(1)[0].value, Py_None)
        == -1 {
        return -1;
    }
    state.view(1)[0].YieldFrom_type = make_type(
        state,
        ptr[u8]("YieldFrom"),
        state.view(1)[0].expr_type,
        addressof(YieldFrom_fields),
        1,
        ptr[u8]("YieldFrom(expr value)")
    );
    if not state.view(1)[0].YieldFrom_type {
        return -1;
    }
    state.view(1)[0].Compare_type = make_type(
        state,
        ptr[u8]("Compare"),
        state.view(1)[0].expr_type,
        addressof(Compare_fields),
        3,
        ptr[u8]("Compare(expr left, cmpop* ops, expr* comparators)")
    );
    if not state.view(1)[0].Compare_type {
        return -1;
    }
    state.view(1)[0].Call_type = make_type(
        state,
        ptr[u8]("Call"),
        state.view(1)[0].expr_type,
        addressof(Call_fields),
        3,
        ptr[u8]("Call(expr func, expr* args, keyword* keywords)")
    );
    if not state.view(1)[0].Call_type {
        return -1;
    }
    state.view(1)[0].FormattedValue_type = make_type(
        state,
        ptr[u8]("FormattedValue"),
        state.view(1)[0].expr_type,
        addressof(FormattedValue_fields),
        3,
        ptr[u8]("FormattedValue(expr value, int conversion, expr? format_spec)")
    );
    if not state.view(1)[0].FormattedValue_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].FormattedValue_type, state.view(1)[0].format_spec, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].Interpolation_type = make_type(
        state,
        ptr[u8]("Interpolation"),
        state.view(1)[0].expr_type,
        addressof(Interpolation_fields),
        4,
        ptr[u8](
            "Interpolation(expr value, constant str, int conversion, expr? format_spec)"
        )
    );
    if not state.view(1)[0].Interpolation_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].Interpolation_type, state.view(1)[0].format_spec, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].JoinedStr_type = make_type(
        state,
        ptr[u8]("JoinedStr"),
        state.view(1)[0].expr_type,
        addressof(JoinedStr_fields),
        1,
        ptr[u8]("JoinedStr(expr* values)")
    );
    if not state.view(1)[0].JoinedStr_type {
        return -1;
    }
    state.view(1)[0].TemplateStr_type = make_type(
        state,
        ptr[u8]("TemplateStr"),
        state.view(1)[0].expr_type,
        addressof(TemplateStr_fields),
        1,
        ptr[u8]("TemplateStr(expr* values)")
    );
    if not state.view(1)[0].TemplateStr_type {
        return -1;
    }
    state.view(1)[0].Constant_type = make_type(
        state,
        ptr[u8]("Constant"),
        state.view(1)[0].expr_type,
        addressof(Constant_fields),
        2,
        ptr[u8]("Constant(constant value, string? kind)")
    );
    if not state.view(1)[0].Constant_type {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].Constant_type, state.view(1)[0].kind, Py_None)
        == -1 {
        return -1;
    }
    state.view(1)[0].Attribute_type = make_type(
        state,
        ptr[u8]("Attribute"),
        state.view(1)[0].expr_type,
        addressof(Attribute_fields),
        3,
        ptr[u8]("Attribute(expr value, identifier attr, expr_context ctx)")
    );
    if not state.view(1)[0].Attribute_type {
        return -1;
    }
    state.view(1)[0].Subscript_type = make_type(
        state,
        ptr[u8]("Subscript"),
        state.view(1)[0].expr_type,
        addressof(Subscript_fields),
        3,
        ptr[u8]("Subscript(expr value, expr slice, expr_context ctx)")
    );
    if not state.view(1)[0].Subscript_type {
        return -1;
    }
    state.view(1)[0].Starred_type = make_type(
        state,
        ptr[u8]("Starred"),
        state.view(1)[0].expr_type,
        addressof(Starred_fields),
        2,
        ptr[u8]("Starred(expr value, expr_context ctx)")
    );
    if not state.view(1)[0].Starred_type {
        return -1;
    }
    state.view(1)[0].Name_type = make_type(
        state,
        ptr[u8]("Name"),
        state.view(1)[0].expr_type,
        addressof(Name_fields),
        2,
        ptr[u8]("Name(identifier id, expr_context ctx)")
    );
    if not state.view(1)[0].Name_type {
        return -1;
    }
    state.view(1)[0].List_type = make_type(
        state,
        ptr[u8]("List"),
        state.view(1)[0].expr_type,
        addressof(List_fields),
        2,
        ptr[u8]("List(expr* elts, expr_context ctx)")
    );
    if not state.view(1)[0].List_type {
        return -1;
    }
    state.view(1)[0].Tuple_type = make_type(
        state,
        ptr[u8]("Tuple"),
        state.view(1)[0].expr_type,
        addressof(Tuple_fields),
        2,
        ptr[u8]("Tuple(expr* elts, expr_context ctx)")
    );
    if not state.view(1)[0].Tuple_type {
        return -1;
    }
    state.view(1)[0].Slice_type = make_type(
        state,
        ptr[u8]("Slice"),
        state.view(1)[0].expr_type,
        addressof(Slice_fields),
        3,
        ptr[u8]("Slice(expr? lower, expr? upper, expr? step)")
    );
    if not state.view(1)[0].Slice_type {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].Slice_type, state.view(1)[0].lower, Py_None)
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].Slice_type, state.view(1)[0].upper, Py_None)
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].Slice_type, state.view(1)[0].step, Py_None)
        == -1 {
        return -1;
    }
    state.view(1)[0].expr_context_type = make_type(
        state,
        ptr[u8]("expr_context"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("expr_context = Load | Store | Del")
    );
    if not state.view(1)[0].expr_context_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].expr_context_type, ptr[ptr[u8]](), 0)
        < 0 {
        return -1;
    }
    state.view(1)[0].Load_type = make_type(
        state,
        ptr[u8]("Load"),
        state.view(1)[0].expr_context_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Load")
    );
    if not state.view(1)[0].Load_type {
        return -1;
    }
    state.view(1)[0].Load_singleton = PyType_GenericNew(
        state.view(1)[0].Load_type, NULL, NULL
    );
    if not state.view(1)[0].Load_singleton {
        return -1;
    }
    state.view(1)[0].Store_type = make_type(
        state,
        ptr[u8]("Store"),
        state.view(1)[0].expr_context_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Store")
    );
    if not state.view(1)[0].Store_type {
        return -1;
    }
    state.view(1)[0].Store_singleton = PyType_GenericNew(
        state.view(1)[0].Store_type, NULL, NULL
    );
    if not state.view(1)[0].Store_singleton {
        return -1;
    }
    state.view(1)[0].Del_type = make_type(
        state,
        ptr[u8]("Del"),
        state.view(1)[0].expr_context_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Del")
    );
    if not state.view(1)[0].Del_type {
        return -1;
    }
    state.view(1)[0].Del_singleton = PyType_GenericNew(
        state.view(1)[0].Del_type, NULL, NULL
    );
    if not state.view(1)[0].Del_singleton {
        return -1;
    }
    state.view(1)[0].boolop_type = make_type(
        state,
        ptr[u8]("boolop"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("boolop = And | Or")
    );
    if not state.view(1)[0].boolop_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].boolop_type, ptr[ptr[u8]](), 0) < 0 {
        return -1;
    }
    state.view(1)[0].And_type = make_type(
        state,
        ptr[u8]("And"),
        state.view(1)[0].boolop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("And")
    );
    if not state.view(1)[0].And_type {
        return -1;
    }
    state.view(1)[0].And_singleton = PyType_GenericNew(
        state.view(1)[0].And_type, NULL, NULL
    );
    if not state.view(1)[0].And_singleton {
        return -1;
    }
    state.view(1)[0].Or_type = make_type(
        state,
        ptr[u8]("Or"),
        state.view(1)[0].boolop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Or")
    );
    if not state.view(1)[0].Or_type {
        return -1;
    }
    state.view(1)[0].Or_singleton = PyType_GenericNew(
        state.view(1)[0].Or_type, NULL, NULL
    );
    if not state.view(1)[0].Or_singleton {
        return -1;
    }
    state.view(1)[0].operator_type = make_type(
        state,
        ptr[u8]("operator"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8](
            "operator = Add | Sub | Mult | MatMult | Div | Mod | Pow | LShift | RShift | BitOr | BitXor | BitAnd | FloorDiv"
        )
    );
    if not state.view(1)[0].operator_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].operator_type, ptr[ptr[u8]](), 0) < 0 {
        return -1;
    }
    state.view(1)[0].Add_type = make_type(
        state,
        ptr[u8]("Add"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Add")
    );
    if not state.view(1)[0].Add_type {
        return -1;
    }
    state.view(1)[0].Add_singleton = PyType_GenericNew(
        state.view(1)[0].Add_type, NULL, NULL
    );
    if not state.view(1)[0].Add_singleton {
        return -1;
    }
    state.view(1)[0].Sub_type = make_type(
        state,
        ptr[u8]("Sub"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Sub")
    );
    if not state.view(1)[0].Sub_type {
        return -1;
    }
    state.view(1)[0].Sub_singleton = PyType_GenericNew(
        state.view(1)[0].Sub_type, NULL, NULL
    );
    if not state.view(1)[0].Sub_singleton {
        return -1;
    }
    state.view(1)[0].Mult_type = make_type(
        state,
        ptr[u8]("Mult"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Mult")
    );
    if not state.view(1)[0].Mult_type {
        return -1;
    }
    state.view(1)[0].Mult_singleton = PyType_GenericNew(
        state.view(1)[0].Mult_type, NULL, NULL
    );
    if not state.view(1)[0].Mult_singleton {
        return -1;
    }
    state.view(1)[0].MatMult_type = make_type(
        state,
        ptr[u8]("MatMult"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("MatMult")
    );
    if not state.view(1)[0].MatMult_type {
        return -1;
    }
    state.view(1)[0].MatMult_singleton = PyType_GenericNew(
        state.view(1)[0].MatMult_type, NULL, NULL
    );
    if not state.view(1)[0].MatMult_singleton {
        return -1;
    }
    state.view(1)[0].Div_type = make_type(
        state,
        ptr[u8]("Div"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Div")
    );
    if not state.view(1)[0].Div_type {
        return -1;
    }
    state.view(1)[0].Div_singleton = PyType_GenericNew(
        state.view(1)[0].Div_type, NULL, NULL
    );
    if not state.view(1)[0].Div_singleton {
        return -1;
    }
    state.view(1)[0].Mod_type = make_type(
        state,
        ptr[u8]("Mod"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Mod")
    );
    if not state.view(1)[0].Mod_type {
        return -1;
    }
    state.view(1)[0].Mod_singleton = PyType_GenericNew(
        state.view(1)[0].Mod_type, NULL, NULL
    );
    if not state.view(1)[0].Mod_singleton {
        return -1;
    }
    state.view(1)[0].Pow_type = make_type(
        state,
        ptr[u8]("Pow"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Pow")
    );
    if not state.view(1)[0].Pow_type {
        return -1;
    }
    state.view(1)[0].Pow_singleton = PyType_GenericNew(
        state.view(1)[0].Pow_type, NULL, NULL
    );
    if not state.view(1)[0].Pow_singleton {
        return -1;
    }
    state.view(1)[0].LShift_type = make_type(
        state,
        ptr[u8]("LShift"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("LShift")
    );
    if not state.view(1)[0].LShift_type {
        return -1;
    }
    state.view(1)[0].LShift_singleton = PyType_GenericNew(
        state.view(1)[0].LShift_type, NULL, NULL
    );
    if not state.view(1)[0].LShift_singleton {
        return -1;
    }
    state.view(1)[0].RShift_type = make_type(
        state,
        ptr[u8]("RShift"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("RShift")
    );
    if not state.view(1)[0].RShift_type {
        return -1;
    }
    state.view(1)[0].RShift_singleton = PyType_GenericNew(
        state.view(1)[0].RShift_type, NULL, NULL
    );
    if not state.view(1)[0].RShift_singleton {
        return -1;
    }
    state.view(1)[0].BitOr_type = make_type(
        state,
        ptr[u8]("BitOr"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("BitOr")
    );
    if not state.view(1)[0].BitOr_type {
        return -1;
    }
    state.view(1)[0].BitOr_singleton = PyType_GenericNew(
        state.view(1)[0].BitOr_type, NULL, NULL
    );
    if not state.view(1)[0].BitOr_singleton {
        return -1;
    }
    state.view(1)[0].BitXor_type = make_type(
        state,
        ptr[u8]("BitXor"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("BitXor")
    );
    if not state.view(1)[0].BitXor_type {
        return -1;
    }
    state.view(1)[0].BitXor_singleton = PyType_GenericNew(
        state.view(1)[0].BitXor_type, NULL, NULL
    );
    if not state.view(1)[0].BitXor_singleton {
        return -1;
    }
    state.view(1)[0].BitAnd_type = make_type(
        state,
        ptr[u8]("BitAnd"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("BitAnd")
    );
    if not state.view(1)[0].BitAnd_type {
        return -1;
    }
    state.view(1)[0].BitAnd_singleton = PyType_GenericNew(
        state.view(1)[0].BitAnd_type, NULL, NULL
    );
    if not state.view(1)[0].BitAnd_singleton {
        return -1;
    }
    state.view(1)[0].FloorDiv_type = make_type(
        state,
        ptr[u8]("FloorDiv"),
        state.view(1)[0].operator_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("FloorDiv")
    );
    if not state.view(1)[0].FloorDiv_type {
        return -1;
    }
    state.view(1)[0].FloorDiv_singleton = PyType_GenericNew(
        state.view(1)[0].FloorDiv_type, NULL, NULL
    );
    if not state.view(1)[0].FloorDiv_singleton {
        return -1;
    }
    state.view(1)[0].unaryop_type = make_type(
        state,
        ptr[u8]("unaryop"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("unaryop = Invert | Not | UAdd | USub")
    );
    if not state.view(1)[0].unaryop_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].unaryop_type, ptr[ptr[u8]](), 0) < 0 {
        return -1;
    }
    state.view(1)[0].Invert_type = make_type(
        state,
        ptr[u8]("Invert"),
        state.view(1)[0].unaryop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Invert")
    );
    if not state.view(1)[0].Invert_type {
        return -1;
    }
    state.view(1)[0].Invert_singleton = PyType_GenericNew(
        state.view(1)[0].Invert_type, NULL, NULL
    );
    if not state.view(1)[0].Invert_singleton {
        return -1;
    }
    state.view(1)[0].Not_type = make_type(
        state,
        ptr[u8]("Not"),
        state.view(1)[0].unaryop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Not")
    );
    if not state.view(1)[0].Not_type {
        return -1;
    }
    state.view(1)[0].Not_singleton = PyType_GenericNew(
        state.view(1)[0].Not_type, NULL, NULL
    );
    if not state.view(1)[0].Not_singleton {
        return -1;
    }
    state.view(1)[0].UAdd_type = make_type(
        state,
        ptr[u8]("UAdd"),
        state.view(1)[0].unaryop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("UAdd")
    );
    if not state.view(1)[0].UAdd_type {
        return -1;
    }
    state.view(1)[0].UAdd_singleton = PyType_GenericNew(
        state.view(1)[0].UAdd_type, NULL, NULL
    );
    if not state.view(1)[0].UAdd_singleton {
        return -1;
    }
    state.view(1)[0].USub_type = make_type(
        state,
        ptr[u8]("USub"),
        state.view(1)[0].unaryop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("USub")
    );
    if not state.view(1)[0].USub_type {
        return -1;
    }
    state.view(1)[0].USub_singleton = PyType_GenericNew(
        state.view(1)[0].USub_type, NULL, NULL
    );
    if not state.view(1)[0].USub_singleton {
        return -1;
    }
    state.view(1)[0].cmpop_type = make_type(
        state,
        ptr[u8]("cmpop"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("cmpop = Eq | NotEq | Lt | LtE | Gt | GtE | Is | IsNot | In | NotIn")
    );
    if not state.view(1)[0].cmpop_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].cmpop_type, ptr[ptr[u8]](), 0) < 0 {
        return -1;
    }
    state.view(1)[0].Eq_type = make_type(
        state,
        ptr[u8]("Eq"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Eq")
    );
    if not state.view(1)[0].Eq_type {
        return -1;
    }
    state.view(1)[0].Eq_singleton = PyType_GenericNew(
        state.view(1)[0].Eq_type, NULL, NULL
    );
    if not state.view(1)[0].Eq_singleton {
        return -1;
    }
    state.view(1)[0].NotEq_type = make_type(
        state,
        ptr[u8]("NotEq"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("NotEq")
    );
    if not state.view(1)[0].NotEq_type {
        return -1;
    }
    state.view(1)[0].NotEq_singleton = PyType_GenericNew(
        state.view(1)[0].NotEq_type, NULL, NULL
    );
    if not state.view(1)[0].NotEq_singleton {
        return -1;
    }
    state.view(1)[0].Lt_type = make_type(
        state,
        ptr[u8]("Lt"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Lt")
    );
    if not state.view(1)[0].Lt_type {
        return -1;
    }
    state.view(1)[0].Lt_singleton = PyType_GenericNew(
        state.view(1)[0].Lt_type, NULL, NULL
    );
    if not state.view(1)[0].Lt_singleton {
        return -1;
    }
    state.view(1)[0].LtE_type = make_type(
        state,
        ptr[u8]("LtE"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("LtE")
    );
    if not state.view(1)[0].LtE_type {
        return -1;
    }
    state.view(1)[0].LtE_singleton = PyType_GenericNew(
        state.view(1)[0].LtE_type, NULL, NULL
    );
    if not state.view(1)[0].LtE_singleton {
        return -1;
    }
    state.view(1)[0].Gt_type = make_type(
        state,
        ptr[u8]("Gt"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Gt")
    );
    if not state.view(1)[0].Gt_type {
        return -1;
    }
    state.view(1)[0].Gt_singleton = PyType_GenericNew(
        state.view(1)[0].Gt_type, NULL, NULL
    );
    if not state.view(1)[0].Gt_singleton {
        return -1;
    }
    state.view(1)[0].GtE_type = make_type(
        state,
        ptr[u8]("GtE"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("GtE")
    );
    if not state.view(1)[0].GtE_type {
        return -1;
    }
    state.view(1)[0].GtE_singleton = PyType_GenericNew(
        state.view(1)[0].GtE_type, NULL, NULL
    );
    if not state.view(1)[0].GtE_singleton {
        return -1;
    }
    state.view(1)[0].Is_type = make_type(
        state,
        ptr[u8]("Is"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("Is")
    );
    if not state.view(1)[0].Is_type {
        return -1;
    }
    state.view(1)[0].Is_singleton = PyType_GenericNew(
        state.view(1)[0].Is_type, NULL, NULL
    );
    if not state.view(1)[0].Is_singleton {
        return -1;
    }
    state.view(1)[0].IsNot_type = make_type(
        state,
        ptr[u8]("IsNot"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("IsNot")
    );
    if not state.view(1)[0].IsNot_type {
        return -1;
    }
    state.view(1)[0].IsNot_singleton = PyType_GenericNew(
        state.view(1)[0].IsNot_type, NULL, NULL
    );
    if not state.view(1)[0].IsNot_singleton {
        return -1;
    }
    state.view(1)[0].In_type = make_type(
        state,
        ptr[u8]("In"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("In")
    );
    if not state.view(1)[0].In_type {
        return -1;
    }
    state.view(1)[0].In_singleton = PyType_GenericNew(
        state.view(1)[0].In_type, NULL, NULL
    );
    if not state.view(1)[0].In_singleton {
        return -1;
    }
    state.view(1)[0].NotIn_type = make_type(
        state,
        ptr[u8]("NotIn"),
        state.view(1)[0].cmpop_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("NotIn")
    );
    if not state.view(1)[0].NotIn_type {
        return -1;
    }
    state.view(1)[0].NotIn_singleton = PyType_GenericNew(
        state.view(1)[0].NotIn_type, NULL, NULL
    );
    if not state.view(1)[0].NotIn_singleton {
        return -1;
    }
    state.view(1)[0].comprehension_type = make_type(
        state,
        ptr[u8]("comprehension"),
        state.view(1)[0].AST_type,
        addressof(comprehension_fields),
        4,
        ptr[u8]("comprehension(expr target, expr iter, expr* ifs, int is_async)")
    );
    if not state.view(1)[0].comprehension_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].comprehension_type, ptr[ptr[u8]](), 0)
        < 0 {
        return -1;
    }
    state.view(1)[0].excepthandler_type = make_type(
        state,
        ptr[u8]("excepthandler"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8](
            "excepthandler = ExceptHandler(expr? type, identifier? name, stmt* body)"
        )
    );
    if not state.view(1)[0].excepthandler_type {
        return -1;
    }
    if add_attributes(
        state,
        state.view(1)[0].excepthandler_type,
        addressof(excepthandler_attributes),
        4
    )
        < 0 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].excepthandler_type, state.view(1)[0].end_lineno, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].excepthandler_type, state.view(1)[0].end_col_offset, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].ExceptHandler_type = make_type(
        state,
        ptr[u8]("ExceptHandler"),
        state.view(1)[0].excepthandler_type,
        addressof(ExceptHandler_fields),
        3,
        ptr[u8]("ExceptHandler(expr? type, identifier? name, stmt* body)")
    );
    if not state.view(1)[0].ExceptHandler_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].ExceptHandler_type, state.view(1)[0].type, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].ExceptHandler_type, state.view(1)[0].name, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].arguments_type = make_type(
        state,
        ptr[u8]("arguments"),
        state.view(1)[0].AST_type,
        addressof(arguments_fields),
        7,
        ptr[u8](
            "arguments(arg* posonlyargs, arg* args, arg? vararg, arg* kwonlyargs, expr?* kw_defaults, arg? kwarg, expr* defaults)"
        )
    );
    if not state.view(1)[0].arguments_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].arguments_type, ptr[ptr[u8]](), 0) < 0 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].arguments_type, state.view(1)[0].vararg, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].arguments_type, state.view(1)[0].kwarg, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].arg_type = make_type(
        state,
        ptr[u8]("arg"),
        state.view(1)[0].AST_type,
        addressof(arg_fields),
        3,
        ptr[u8]("arg(identifier arg, expr? annotation, string? type_comment)")
    );
    if not state.view(1)[0].arg_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].arg_type, addressof(arg_attributes), 4)
        < 0 {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].arg_type, state.view(1)[0].annotation, Py_None)
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].arg_type, state.view(1)[0].type_comment, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].arg_type, state.view(1)[0].end_lineno, Py_None)
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].arg_type, state.view(1)[0].end_col_offset, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].keyword_type = make_type(
        state,
        ptr[u8]("keyword"),
        state.view(1)[0].AST_type,
        addressof(keyword_fields),
        2,
        ptr[u8]("keyword(identifier? arg, expr value)")
    );
    if not state.view(1)[0].keyword_type {
        return -1;
    }
    if add_attributes(
        state, state.view(1)[0].keyword_type, addressof(keyword_attributes), 4
    )
        < 0 {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].keyword_type, state.view(1)[0].arg, Py_None)
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].keyword_type, state.view(1)[0].end_lineno, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].keyword_type, state.view(1)[0].end_col_offset, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].alias_type = make_type(
        state,
        ptr[u8]("alias"),
        state.view(1)[0].AST_type,
        addressof(alias_fields),
        2,
        ptr[u8]("alias(identifier name, identifier? asname)")
    );
    if not state.view(1)[0].alias_type {
        return -1;
    }
    if add_attributes(
        state, state.view(1)[0].alias_type, addressof(alias_attributes), 4
    )
        < 0 {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].alias_type, state.view(1)[0].asname, Py_None)
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].alias_type, state.view(1)[0].end_lineno, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].alias_type, state.view(1)[0].end_col_offset, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].withitem_type = make_type(
        state,
        ptr[u8]("withitem"),
        state.view(1)[0].AST_type,
        addressof(withitem_fields),
        2,
        ptr[u8]("withitem(expr context_expr, expr? optional_vars)")
    );
    if not state.view(1)[0].withitem_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].withitem_type, ptr[ptr[u8]](), 0) < 0 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].withitem_type, state.view(1)[0].optional_vars, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].match_case_type = make_type(
        state,
        ptr[u8]("match_case"),
        state.view(1)[0].AST_type,
        addressof(match_case_fields),
        3,
        ptr[u8]("match_case(pattern pattern, expr? guard, stmt* body)")
    );
    if not state.view(1)[0].match_case_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].match_case_type, ptr[ptr[u8]](), 0) < 0 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].match_case_type, state.view(1)[0].guard, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].pattern_type = make_type(
        state,
        ptr[u8]("pattern"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8](
            "pattern = MatchValue(expr value)\n        | MatchSingleton(constant value)\n        | MatchSequence(pattern* patterns)\n        | MatchMapping(expr* keys, pattern* patterns, identifier? rest)\n        | MatchClass(expr cls, pattern* patterns, identifier* kwd_attrs, pattern* kwd_patterns)\n        | MatchStar(identifier? name)\n        | MatchAs(pattern? pattern, identifier? name)\n        | MatchOr(pattern* patterns)"
        )
    );
    if not state.view(1)[0].pattern_type {
        return -1;
    }
    if add_attributes(
        state, state.view(1)[0].pattern_type, addressof(pattern_attributes), 4
    )
        < 0 {
        return -1;
    }
    state.view(1)[0].MatchValue_type = make_type(
        state,
        ptr[u8]("MatchValue"),
        state.view(1)[0].pattern_type,
        addressof(MatchValue_fields),
        1,
        ptr[u8]("MatchValue(expr value)")
    );
    if not state.view(1)[0].MatchValue_type {
        return -1;
    }
    state.view(1)[0].MatchSingleton_type = make_type(
        state,
        ptr[u8]("MatchSingleton"),
        state.view(1)[0].pattern_type,
        addressof(MatchSingleton_fields),
        1,
        ptr[u8]("MatchSingleton(constant value)")
    );
    if not state.view(1)[0].MatchSingleton_type {
        return -1;
    }
    state.view(1)[0].MatchSequence_type = make_type(
        state,
        ptr[u8]("MatchSequence"),
        state.view(1)[0].pattern_type,
        addressof(MatchSequence_fields),
        1,
        ptr[u8]("MatchSequence(pattern* patterns)")
    );
    if not state.view(1)[0].MatchSequence_type {
        return -1;
    }
    state.view(1)[0].MatchMapping_type = make_type(
        state,
        ptr[u8]("MatchMapping"),
        state.view(1)[0].pattern_type,
        addressof(MatchMapping_fields),
        3,
        ptr[u8]("MatchMapping(expr* keys, pattern* patterns, identifier? rest)")
    );
    if not state.view(1)[0].MatchMapping_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].MatchMapping_type, state.view(1)[0].rest, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].MatchClass_type = make_type(
        state,
        ptr[u8]("MatchClass"),
        state.view(1)[0].pattern_type,
        addressof(MatchClass_fields),
        4,
        ptr[u8](
            "MatchClass(expr cls, pattern* patterns, identifier* kwd_attrs, pattern* kwd_patterns)"
        )
    );
    if not state.view(1)[0].MatchClass_type {
        return -1;
    }
    state.view(1)[0].MatchStar_type = make_type(
        state,
        ptr[u8]("MatchStar"),
        state.view(1)[0].pattern_type,
        addressof(MatchStar_fields),
        1,
        ptr[u8]("MatchStar(identifier? name)")
    );
    if not state.view(1)[0].MatchStar_type {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].MatchStar_type, state.view(1)[0].name, Py_None)
        == -1 {
        return -1;
    }
    state.view(1)[0].MatchAs_type = make_type(
        state,
        ptr[u8]("MatchAs"),
        state.view(1)[0].pattern_type,
        addressof(MatchAs_fields),
        2,
        ptr[u8]("MatchAs(pattern? pattern, identifier? name)")
    );
    if not state.view(1)[0].MatchAs_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].MatchAs_type, state.view(1)[0].pattern, Py_None
    )
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].MatchAs_type, state.view(1)[0].name, Py_None)
        == -1 {
        return -1;
    }
    state.view(1)[0].MatchOr_type = make_type(
        state,
        ptr[u8]("MatchOr"),
        state.view(1)[0].pattern_type,
        addressof(MatchOr_fields),
        1,
        ptr[u8]("MatchOr(pattern* patterns)")
    );
    if not state.view(1)[0].MatchOr_type {
        return -1;
    }
    state.view(1)[0].type_ignore_type = make_type(
        state,
        ptr[u8]("type_ignore"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8]("type_ignore = TypeIgnore(int lineno, string tag)")
    );
    if not state.view(1)[0].type_ignore_type {
        return -1;
    }
    if add_attributes(state, state.view(1)[0].type_ignore_type, ptr[ptr[u8]](), 0)
        < 0 {
        return -1;
    }
    state.view(1)[0].TypeIgnore_type = make_type(
        state,
        ptr[u8]("TypeIgnore"),
        state.view(1)[0].type_ignore_type,
        addressof(TypeIgnore_fields),
        2,
        ptr[u8]("TypeIgnore(int lineno, string tag)")
    );
    if not state.view(1)[0].TypeIgnore_type {
        return -1;
    }
    state.view(1)[0].type_param_type = make_type(
        state,
        ptr[u8]("type_param"),
        state.view(1)[0].AST_type,
        ptr[ptr[u8]](),
        0,
        ptr[u8](
            "type_param = TypeVar(identifier name, expr? bound, expr? default_value)\n           | ParamSpec(identifier name, expr? default_value)\n           | TypeVarTuple(identifier name, expr? default_value)"
        )
    );
    if not state.view(1)[0].type_param_type {
        return -1;
    }
    if add_attributes(
        state, state.view(1)[0].type_param_type, addressof(type_param_attributes), 4
    )
        < 0 {
        return -1;
    }
    state.view(1)[0].TypeVar_type = make_type(
        state,
        ptr[u8]("TypeVar"),
        state.view(1)[0].type_param_type,
        addressof(TypeVar_fields),
        3,
        ptr[u8]("TypeVar(identifier name, expr? bound, expr? default_value)")
    );
    if not state.view(1)[0].TypeVar_type {
        return -1;
    }
    if PyObject_SetAttr(state.view(1)[0].TypeVar_type, state.view(1)[0].bound, Py_None)
        == -1 {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].TypeVar_type, state.view(1)[0].default_value, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].ParamSpec_type = make_type(
        state,
        ptr[u8]("ParamSpec"),
        state.view(1)[0].type_param_type,
        addressof(ParamSpec_fields),
        2,
        ptr[u8]("ParamSpec(identifier name, expr? default_value)")
    );
    if not state.view(1)[0].ParamSpec_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].ParamSpec_type, state.view(1)[0].default_value, Py_None
    )
        == -1 {
        return -1;
    }
    state.view(1)[0].TypeVarTuple_type = make_type(
        state,
        ptr[u8]("TypeVarTuple"),
        state.view(1)[0].type_param_type,
        addressof(TypeVarTuple_fields),
        2,
        ptr[u8]("TypeVarTuple(identifier name, expr? default_value)")
    );
    if not state.view(1)[0].TypeVarTuple_type {
        return -1;
    }
    if PyObject_SetAttr(
        state.view(1)[0].TypeVarTuple_type, state.view(1)[0].default_value, Py_None
    )
        == -1 {
        return -1;
    }
    if add_ast_annotations(state) == 0 {
        return -1;
    }
    return 0;
}

impl ast2obj_list_stmt(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_stmt(state, ptr[_stmt](asdl_seq_get_untyped(seq, i)));
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_type_ignore(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_type_ignore(
            state, ptr[_type_ignore](asdl_seq_get_untyped(seq, i))
        );
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_expr(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_expr(state, ptr[_expr](asdl_seq_get_untyped(seq, i)));
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_type_param(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_type_param(
            state, ptr[_type_param](asdl_seq_get_untyped(seq, i))
        );
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_keyword(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_keyword(state, ptr[_keyword](asdl_seq_get_untyped(seq, i)));
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_withitem(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_withitem(state, ptr[_withitem](asdl_seq_get_untyped(seq, i)));
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_match_case(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_match_case(
            state, ptr[_match_case](asdl_seq_get_untyped(seq, i))
        );
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_excepthandler(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_excepthandler(
            state, ptr[_excepthandler](asdl_seq_get_untyped(seq, i))
        );
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_alias(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_alias(state, ptr[_alias](asdl_seq_get_untyped(seq, i)));
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_object(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_object(state, ptr[PyObject](asdl_seq_get_untyped(seq, i)));
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_comprehension(
    state: ptr[ast_state], seq: ptr[asdl_seq]
) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_comprehension(
            state, ptr[_comprehension](asdl_seq_get_untyped(seq, i))
        );
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_arg(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_arg(state, ptr[_arg](asdl_seq_get_untyped(seq, i)));
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_list_pattern(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject] {
    n = asdl_seq_len(seq);
    result = PyList_New(n);
    if not result {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        value = ast2obj_pattern(state, ptr[_pattern](asdl_seq_get_untyped(seq, i)));
        if not value {
            object_decref(result);
            return NULL;
        }
        list_set_item(result, i, value);
        i += 1;
    }
    return result;
}

impl ast2obj_mod(state: ptr[ast_state], o: ptr[_mod]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    kind = o.view(1)[0].kind;
    if kind == Module_kind {
        result = PyType_GenericNew(state.view(1)[0].Module_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Module = ptr[_mod_Module](node_union(ptr(o)));
        value = ast2obj_list_stmt(state, v_Module.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_type_ignore(state, v_Module.view(1)[0].type_ignores);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_ignores, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Interactive_kind {
        result = PyType_GenericNew(state.view(1)[0].Interactive_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Interactive = ptr[_mod_Interactive](node_union(ptr(o)));
        value = ast2obj_list_stmt(state, v_Interactive.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Expression_kind {
        result = PyType_GenericNew(state.view(1)[0].Expression_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Expression = ptr[_mod_Expression](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Expression.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == FunctionType_kind {
        result = PyType_GenericNew(state.view(1)[0].FunctionType_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_FunctionType = ptr[_mod_FunctionType](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_FunctionType.view(1)[0].argtypes);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].argtypes, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_FunctionType.view(1)[0].returns);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].returns, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    }
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_stmt(state: ptr[ast_state], o: ptr[_stmt]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    kind = o.view(1)[0].kind;
    if kind == FunctionDef_kind {
        result = PyType_GenericNew(state.view(1)[0].FunctionDef_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_FunctionDef = ptr[_stmt_FunctionDef](node_union(ptr(o)));
        value = ast2obj_object(state, v_FunctionDef.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_arguments(state, v_FunctionDef.view(1)[0].args);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].args, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_FunctionDef.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_expr(state, v_FunctionDef.view(1)[0].decorator_list);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].decorator_list, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_FunctionDef.view(1)[0].returns);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].returns, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_FunctionDef.view(1)[0].type_comment);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_comment, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_type_param(state, v_FunctionDef.view(1)[0].type_params);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_params, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == AsyncFunctionDef_kind {
        result = PyType_GenericNew(state.view(1)[0].AsyncFunctionDef_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_AsyncFunctionDef = ptr[_stmt_AsyncFunctionDef](node_union(ptr(o)));
        value = ast2obj_object(state, v_AsyncFunctionDef.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_arguments(state, v_AsyncFunctionDef.view(1)[0].args);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].args, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_AsyncFunctionDef.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_expr(state, v_AsyncFunctionDef.view(1)[0].decorator_list);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].decorator_list, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_AsyncFunctionDef.view(1)[0].returns);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].returns, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_AsyncFunctionDef.view(1)[0].type_comment);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_comment, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_type_param(
            state, v_AsyncFunctionDef.view(1)[0].type_params
        );
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_params, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == ClassDef_kind {
        result = PyType_GenericNew(state.view(1)[0].ClassDef_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_ClassDef = ptr[_stmt_ClassDef](node_union(ptr(o)));
        value = ast2obj_object(state, v_ClassDef.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_expr(state, v_ClassDef.view(1)[0].bases);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].bases, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_keyword(state, v_ClassDef.view(1)[0].keywords);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].keywords, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_ClassDef.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_expr(state, v_ClassDef.view(1)[0].decorator_list);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].decorator_list, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_type_param(state, v_ClassDef.view(1)[0].type_params);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_params, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Return_kind {
        result = PyType_GenericNew(state.view(1)[0].Return_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Return = ptr[_stmt_Return](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Return.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Delete_kind {
        result = PyType_GenericNew(state.view(1)[0].Delete_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Delete = ptr[_stmt_Delete](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_Delete.view(1)[0].targets);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].targets, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Assign_kind {
        result = PyType_GenericNew(state.view(1)[0].Assign_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Assign = ptr[_stmt_Assign](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_Assign.view(1)[0].targets);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].targets, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_Assign.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_Assign.view(1)[0].type_comment);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_comment, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == TypeAlias_kind {
        result = PyType_GenericNew(state.view(1)[0].TypeAlias_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_TypeAlias = ptr[_stmt_TypeAlias](node_union(ptr(o)));
        value = ast2obj_expr(state, v_TypeAlias.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_type_param(state, v_TypeAlias.view(1)[0].type_params);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_params, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_TypeAlias.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == AugAssign_kind {
        result = PyType_GenericNew(state.view(1)[0].AugAssign_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_AugAssign = ptr[_stmt_AugAssign](node_union(ptr(o)));
        value = ast2obj_expr(state, v_AugAssign.view(1)[0].target);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].target, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_operator(state, v_AugAssign.view(1)[0].op);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].op, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_AugAssign.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == AnnAssign_kind {
        result = PyType_GenericNew(state.view(1)[0].AnnAssign_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_AnnAssign = ptr[_stmt_AnnAssign](node_union(ptr(o)));
        value = ast2obj_expr(state, v_AnnAssign.view(1)[0].target);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].target, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_AnnAssign.view(1)[0].annotation);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].annotation, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_AnnAssign.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_int(state, i64(v_AnnAssign.view(1)[0].simple));
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].simple, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == For_kind {
        result = PyType_GenericNew(state.view(1)[0].For_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_For = ptr[_stmt_For](node_union(ptr(o)));
        value = ast2obj_expr(state, v_For.view(1)[0].target);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].target, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_For.view(1)[0].iter);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].iter, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_For.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_For.view(1)[0].orelse);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].orelse, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_For.view(1)[0].type_comment);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_comment, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == AsyncFor_kind {
        result = PyType_GenericNew(state.view(1)[0].AsyncFor_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_AsyncFor = ptr[_stmt_AsyncFor](node_union(ptr(o)));
        value = ast2obj_expr(state, v_AsyncFor.view(1)[0].target);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].target, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_AsyncFor.view(1)[0].iter);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].iter, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_AsyncFor.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_AsyncFor.view(1)[0].orelse);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].orelse, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_AsyncFor.view(1)[0].type_comment);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_comment, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == While_kind {
        result = PyType_GenericNew(state.view(1)[0].While_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_While = ptr[_stmt_While](node_union(ptr(o)));
        value = ast2obj_expr(state, v_While.view(1)[0].test_);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].test_, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_While.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_While.view(1)[0].orelse);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].orelse, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == If_kind {
        result = PyType_GenericNew(state.view(1)[0].If_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_If = ptr[_stmt_If](node_union(ptr(o)));
        value = ast2obj_expr(state, v_If.view(1)[0].test_);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].test_, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_If.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_If.view(1)[0].orelse);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].orelse, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == With_kind {
        result = PyType_GenericNew(state.view(1)[0].With_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_With = ptr[_stmt_With](node_union(ptr(o)));
        value = ast2obj_list_withitem(state, v_With.view(1)[0].items);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].items, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_With.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_With.view(1)[0].type_comment);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_comment, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == AsyncWith_kind {
        result = PyType_GenericNew(state.view(1)[0].AsyncWith_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_AsyncWith = ptr[_stmt_AsyncWith](node_union(ptr(o)));
        value = ast2obj_list_withitem(state, v_AsyncWith.view(1)[0].items);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].items, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_AsyncWith.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_AsyncWith.view(1)[0].type_comment);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type_comment, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Match_kind {
        result = PyType_GenericNew(state.view(1)[0].Match_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Match = ptr[_stmt_Match](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Match.view(1)[0].subject);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].subject, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_match_case(state, v_Match.view(1)[0].cases);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].cases, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Raise_kind {
        result = PyType_GenericNew(state.view(1)[0].Raise_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Raise = ptr[_stmt_Raise](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Raise.view(1)[0].exc);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].exc, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_Raise.view(1)[0].cause);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].cause, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Try_kind {
        result = PyType_GenericNew(state.view(1)[0].Try_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Try = ptr[_stmt_Try](node_union(ptr(o)));
        value = ast2obj_list_stmt(state, v_Try.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_excepthandler(state, v_Try.view(1)[0].handlers);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].handlers, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_Try.view(1)[0].orelse);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].orelse, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_Try.view(1)[0].finalbody);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].finalbody, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == TryStar_kind {
        result = PyType_GenericNew(state.view(1)[0].TryStar_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_TryStar = ptr[_stmt_TryStar](node_union(ptr(o)));
        value = ast2obj_list_stmt(state, v_TryStar.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_excepthandler(state, v_TryStar.view(1)[0].handlers);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].handlers, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_TryStar.view(1)[0].orelse);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].orelse, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_TryStar.view(1)[0].finalbody);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].finalbody, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Assert_kind {
        result = PyType_GenericNew(state.view(1)[0].Assert_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Assert = ptr[_stmt_Assert](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Assert.view(1)[0].test_);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].test_, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_Assert.view(1)[0].msg);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].msg, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Import_kind {
        result = PyType_GenericNew(state.view(1)[0].Import_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Import = ptr[_stmt_Import](node_union(ptr(o)));
        value = ast2obj_list_alias(state, v_Import.view(1)[0].names);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].names, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == ImportFrom_kind {
        result = PyType_GenericNew(state.view(1)[0].ImportFrom_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_ImportFrom = ptr[_stmt_ImportFrom](node_union(ptr(o)));
        value = ast2obj_object(state, v_ImportFrom.view(1)[0].module);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].module, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_alias(state, v_ImportFrom.view(1)[0].names);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].names, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_int(state, i64(v_ImportFrom.view(1)[0].level));
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].level, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Global_kind {
        result = PyType_GenericNew(state.view(1)[0].Global_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Global = ptr[_stmt_Global](node_union(ptr(o)));
        value = ast2obj_list_object(state, v_Global.view(1)[0].names);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].names, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Nonlocal_kind {
        result = PyType_GenericNew(state.view(1)[0].Nonlocal_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Nonlocal = ptr[_stmt_Nonlocal](node_union(ptr(o)));
        value = ast2obj_list_object(state, v_Nonlocal.view(1)[0].names);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].names, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Expr_kind {
        result = PyType_GenericNew(state.view(1)[0].Expr_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Expr = ptr[_stmt_Expr](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Expr.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Pass_kind {
        result = PyType_GenericNew(state.view(1)[0].Pass_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
    } elif kind == Break_kind {
        result = PyType_GenericNew(state.view(1)[0].Break_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
    } elif kind == Continue_kind {
        result = PyType_GenericNew(state.view(1)[0].Continue_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
    }
    value = ast2obj_int(state, i64(o.view(1)[0].lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_expr(state: ptr[ast_state], o: ptr[_expr]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    kind = o.view(1)[0].kind;
    if kind == BoolOp_kind {
        result = PyType_GenericNew(state.view(1)[0].BoolOp_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_BoolOp = ptr[_expr_BoolOp](node_union(ptr(o)));
        value = ast2obj_boolop(state, v_BoolOp.view(1)[0].op);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].op, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_expr(state, v_BoolOp.view(1)[0].values);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].values, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == NamedExpr_kind {
        result = PyType_GenericNew(state.view(1)[0].NamedExpr_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_NamedExpr = ptr[_expr_NamedExpr](node_union(ptr(o)));
        value = ast2obj_expr(state, v_NamedExpr.view(1)[0].target);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].target, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_NamedExpr.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == BinOp_kind {
        result = PyType_GenericNew(state.view(1)[0].BinOp_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_BinOp = ptr[_expr_BinOp](node_union(ptr(o)));
        value = ast2obj_expr(state, v_BinOp.view(1)[0].left);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].left, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_operator(state, v_BinOp.view(1)[0].op);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].op, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_BinOp.view(1)[0].right);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].right, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == UnaryOp_kind {
        result = PyType_GenericNew(state.view(1)[0].UnaryOp_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_UnaryOp = ptr[_expr_UnaryOp](node_union(ptr(o)));
        value = ast2obj_unaryop(state, v_UnaryOp.view(1)[0].op);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].op, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_UnaryOp.view(1)[0].operand);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].operand, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Lambda_kind {
        result = PyType_GenericNew(state.view(1)[0].Lambda_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Lambda = ptr[_expr_Lambda](node_union(ptr(o)));
        value = ast2obj_arguments(state, v_Lambda.view(1)[0].args);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].args, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_Lambda.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == IfExp_kind {
        result = PyType_GenericNew(state.view(1)[0].IfExp_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_IfExp = ptr[_expr_IfExp](node_union(ptr(o)));
        value = ast2obj_expr(state, v_IfExp.view(1)[0].test_);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].test_, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_IfExp.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_IfExp.view(1)[0].orelse);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].orelse, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Dict_kind {
        result = PyType_GenericNew(state.view(1)[0].Dict_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Dict = ptr[_expr_Dict](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_Dict.view(1)[0].keys);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].keys, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_expr(state, v_Dict.view(1)[0].values);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].values, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Set_kind {
        result = PyType_GenericNew(state.view(1)[0].Set_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Set = ptr[_expr_Set](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_Set.view(1)[0].elts);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].elts, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == ListComp_kind {
        result = PyType_GenericNew(state.view(1)[0].ListComp_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_ListComp = ptr[_expr_ListComp](node_union(ptr(o)));
        value = ast2obj_expr(state, v_ListComp.view(1)[0].elt);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].elt, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_comprehension(state, v_ListComp.view(1)[0].generators);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].generators, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == SetComp_kind {
        result = PyType_GenericNew(state.view(1)[0].SetComp_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_SetComp = ptr[_expr_SetComp](node_union(ptr(o)));
        value = ast2obj_expr(state, v_SetComp.view(1)[0].elt);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].elt, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_comprehension(state, v_SetComp.view(1)[0].generators);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].generators, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == DictComp_kind {
        result = PyType_GenericNew(state.view(1)[0].DictComp_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_DictComp = ptr[_expr_DictComp](node_union(ptr(o)));
        value = ast2obj_expr(state, v_DictComp.view(1)[0].key);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].key, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_DictComp.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_comprehension(state, v_DictComp.view(1)[0].generators);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].generators, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == GeneratorExp_kind {
        result = PyType_GenericNew(state.view(1)[0].GeneratorExp_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_GeneratorExp = ptr[_expr_GeneratorExp](node_union(ptr(o)));
        value = ast2obj_expr(state, v_GeneratorExp.view(1)[0].elt);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].elt, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_comprehension(state, v_GeneratorExp.view(1)[0].generators);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].generators, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Await_kind {
        result = PyType_GenericNew(state.view(1)[0].Await_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Await = ptr[_expr_Await](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Await.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Yield_kind {
        result = PyType_GenericNew(state.view(1)[0].Yield_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Yield = ptr[_expr_Yield](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Yield.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == YieldFrom_kind {
        result = PyType_GenericNew(state.view(1)[0].YieldFrom_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_YieldFrom = ptr[_expr_YieldFrom](node_union(ptr(o)));
        value = ast2obj_expr(state, v_YieldFrom.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Compare_kind {
        result = PyType_GenericNew(state.view(1)[0].Compare_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Compare = ptr[_expr_Compare](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Compare.view(1)[0].left);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].left, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        n_ops = asdl_seq_len(v_Compare.view(1)[0].ops);
        value = PyList_New(n_ops);
        if not value {
            return ast2obj_failed(result, value);
        }
        i_ops: i64 = 0;
        while i_ops < n_ops {
            list_set_item(
                value,
                i_ops,
                ast2obj_cmpop(state, asdl_int_seq_get(v_Compare.view(1)[0].ops, i_ops))
            );
            i_ops += 1;
        }
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].ops, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_expr(state, v_Compare.view(1)[0].comparators);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].comparators, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Call_kind {
        result = PyType_GenericNew(state.view(1)[0].Call_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Call = ptr[_expr_Call](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Call.view(1)[0].func);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].func, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_expr(state, v_Call.view(1)[0].args);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].args, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_keyword(state, v_Call.view(1)[0].keywords);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].keywords, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == FormattedValue_kind {
        result = PyType_GenericNew(state.view(1)[0].FormattedValue_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_FormattedValue = ptr[_expr_FormattedValue](node_union(ptr(o)));
        value = ast2obj_expr(state, v_FormattedValue.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_int(state, i64(v_FormattedValue.view(1)[0].conversion));
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].conversion, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_FormattedValue.view(1)[0].format_spec);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].format_spec, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Interpolation_kind {
        result = PyType_GenericNew(state.view(1)[0].Interpolation_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Interpolation = ptr[_expr_Interpolation](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Interpolation.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_Interpolation.view(1)[0].str_);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].str, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_int(state, i64(v_Interpolation.view(1)[0].conversion));
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].conversion, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_Interpolation.view(1)[0].format_spec);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].format_spec, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == JoinedStr_kind {
        result = PyType_GenericNew(state.view(1)[0].JoinedStr_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_JoinedStr = ptr[_expr_JoinedStr](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_JoinedStr.view(1)[0].values);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].values, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == TemplateStr_kind {
        result = PyType_GenericNew(state.view(1)[0].TemplateStr_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_TemplateStr = ptr[_expr_TemplateStr](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_TemplateStr.view(1)[0].values);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].values, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Constant_kind {
        result = PyType_GenericNew(state.view(1)[0].Constant_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Constant = ptr[_expr_Constant](node_union(ptr(o)));
        value = ast2obj_object(state, v_Constant.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_Constant.view(1)[0].kind);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].kind, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Attribute_kind {
        result = PyType_GenericNew(state.view(1)[0].Attribute_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Attribute = ptr[_expr_Attribute](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Attribute.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_Attribute.view(1)[0].attr);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].attr, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr_context(state, v_Attribute.view(1)[0].ctx);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].ctx, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Subscript_kind {
        result = PyType_GenericNew(state.view(1)[0].Subscript_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Subscript = ptr[_expr_Subscript](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Subscript.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_Subscript.view(1)[0].slice);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].slice, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr_context(state, v_Subscript.view(1)[0].ctx);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].ctx, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Starred_kind {
        result = PyType_GenericNew(state.view(1)[0].Starred_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Starred = ptr[_expr_Starred](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Starred.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr_context(state, v_Starred.view(1)[0].ctx);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].ctx, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Name_kind {
        result = PyType_GenericNew(state.view(1)[0].Name_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Name = ptr[_expr_Name](node_union(ptr(o)));
        value = ast2obj_object(state, v_Name.view(1)[0].id);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].id, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr_context(state, v_Name.view(1)[0].ctx);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].ctx, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == List_kind {
        result = PyType_GenericNew(state.view(1)[0].List_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_List = ptr[_expr_List](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_List.view(1)[0].elts);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].elts, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr_context(state, v_List.view(1)[0].ctx);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].ctx, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Tuple_kind {
        result = PyType_GenericNew(state.view(1)[0].Tuple_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Tuple = ptr[_expr_Tuple](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_Tuple.view(1)[0].elts);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].elts, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr_context(state, v_Tuple.view(1)[0].ctx);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].ctx, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == Slice_kind {
        result = PyType_GenericNew(state.view(1)[0].Slice_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_Slice = ptr[_expr_Slice](node_union(ptr(o)));
        value = ast2obj_expr(state, v_Slice.view(1)[0].lower);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].lower, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_Slice.view(1)[0].upper);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].upper, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_Slice.view(1)[0].step);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].step, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    }
    value = ast2obj_int(state, i64(o.view(1)[0].lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_expr_context(state: ptr[ast_state], o: i32) -> ptr[PyObject] {
    if o == Load {
        return object_new_ref(state.view(1)[0].Load_singleton);
    }
    if o == Store {
        return object_new_ref(state.view(1)[0].Store_singleton);
    }
    if o == Del {
        return object_new_ref(state.view(1)[0].Del_singleton);
    }
    _Py_FatalErrorFunc(
        ptr[u8]("ast2obj_expr_context"), ptr[u8]("Unreachable C code path reached")
    );
    return NULL;
}

impl ast2obj_boolop(state: ptr[ast_state], o: i32) -> ptr[PyObject] {
    if o == And {
        return object_new_ref(state.view(1)[0].And_singleton);
    }
    if o == Or {
        return object_new_ref(state.view(1)[0].Or_singleton);
    }
    _Py_FatalErrorFunc(
        ptr[u8]("ast2obj_boolop"), ptr[u8]("Unreachable C code path reached")
    );
    return NULL;
}

impl ast2obj_operator(state: ptr[ast_state], o: i32) -> ptr[PyObject] {
    if o == Add {
        return object_new_ref(state.view(1)[0].Add_singleton);
    }
    if o == Sub {
        return object_new_ref(state.view(1)[0].Sub_singleton);
    }
    if o == Mult {
        return object_new_ref(state.view(1)[0].Mult_singleton);
    }
    if o == MatMult {
        return object_new_ref(state.view(1)[0].MatMult_singleton);
    }
    if o == Div {
        return object_new_ref(state.view(1)[0].Div_singleton);
    }
    if o == Mod {
        return object_new_ref(state.view(1)[0].Mod_singleton);
    }
    if o == Pow {
        return object_new_ref(state.view(1)[0].Pow_singleton);
    }
    if o == LShift {
        return object_new_ref(state.view(1)[0].LShift_singleton);
    }
    if o == RShift {
        return object_new_ref(state.view(1)[0].RShift_singleton);
    }
    if o == BitOr {
        return object_new_ref(state.view(1)[0].BitOr_singleton);
    }
    if o == BitXor {
        return object_new_ref(state.view(1)[0].BitXor_singleton);
    }
    if o == BitAnd {
        return object_new_ref(state.view(1)[0].BitAnd_singleton);
    }
    if o == FloorDiv {
        return object_new_ref(state.view(1)[0].FloorDiv_singleton);
    }
    _Py_FatalErrorFunc(
        ptr[u8]("ast2obj_operator"), ptr[u8]("Unreachable C code path reached")
    );
    return NULL;
}

impl ast2obj_unaryop(state: ptr[ast_state], o: i32) -> ptr[PyObject] {
    if o == Invert {
        return object_new_ref(state.view(1)[0].Invert_singleton);
    }
    if o == Not {
        return object_new_ref(state.view(1)[0].Not_singleton);
    }
    if o == UAdd {
        return object_new_ref(state.view(1)[0].UAdd_singleton);
    }
    if o == USub {
        return object_new_ref(state.view(1)[0].USub_singleton);
    }
    _Py_FatalErrorFunc(
        ptr[u8]("ast2obj_unaryop"), ptr[u8]("Unreachable C code path reached")
    );
    return NULL;
}

impl ast2obj_cmpop(state: ptr[ast_state], o: i32) -> ptr[PyObject] {
    if o == Eq {
        return object_new_ref(state.view(1)[0].Eq_singleton);
    }
    if o == NotEq {
        return object_new_ref(state.view(1)[0].NotEq_singleton);
    }
    if o == Lt {
        return object_new_ref(state.view(1)[0].Lt_singleton);
    }
    if o == LtE {
        return object_new_ref(state.view(1)[0].LtE_singleton);
    }
    if o == Gt {
        return object_new_ref(state.view(1)[0].Gt_singleton);
    }
    if o == GtE {
        return object_new_ref(state.view(1)[0].GtE_singleton);
    }
    if o == Is {
        return object_new_ref(state.view(1)[0].Is_singleton);
    }
    if o == IsNot {
        return object_new_ref(state.view(1)[0].IsNot_singleton);
    }
    if o == In {
        return object_new_ref(state.view(1)[0].In_singleton);
    }
    if o == NotIn {
        return object_new_ref(state.view(1)[0].NotIn_singleton);
    }
    _Py_FatalErrorFunc(
        ptr[u8]("ast2obj_cmpop"), ptr[u8]("Unreachable C code path reached")
    );
    return NULL;
}

impl ast2obj_comprehension(
    state: ptr[ast_state], o: ptr[_comprehension]
) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    result = PyType_GenericNew(state.view(1)[0].comprehension_type, NULL, NULL);
    if not result {
        return NULL;
    }
    value = ast2obj_expr(state, o.view(1)[0].target);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].target, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_expr(state, o.view(1)[0].iter);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].iter, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_list_expr(state, o.view(1)[0].ifs);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].ifs, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].is_async));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].is_async, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_excepthandler(
    state: ptr[ast_state], o: ptr[_excepthandler]
) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    kind = o.view(1)[0].kind;
    if kind == ExceptHandler_kind {
        result = PyType_GenericNew(state.view(1)[0].ExceptHandler_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_ExceptHandler = ptr[_excepthandler_ExceptHandler](node_union(ptr(o)));
        value = ast2obj_expr(state, v_ExceptHandler.view(1)[0].type);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].type, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_ExceptHandler.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_stmt(state, v_ExceptHandler.view(1)[0].body);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    }
    value = ast2obj_int(state, i64(o.view(1)[0].lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_arguments(state: ptr[ast_state], o: ptr[_arguments]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    result = PyType_GenericNew(state.view(1)[0].arguments_type, NULL, NULL);
    if not result {
        return NULL;
    }
    value = ast2obj_list_arg(state, o.view(1)[0].posonlyargs);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].posonlyargs, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_list_arg(state, o.view(1)[0].args);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].args, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_arg(state, o.view(1)[0].vararg);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].vararg, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_list_arg(state, o.view(1)[0].kwonlyargs);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].kwonlyargs, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_list_expr(state, o.view(1)[0].kw_defaults);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].kw_defaults, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_arg(state, o.view(1)[0].kwarg);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].kwarg, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_list_expr(state, o.view(1)[0].defaults);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].defaults, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_arg(state: ptr[ast_state], o: ptr[_arg]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    result = PyType_GenericNew(state.view(1)[0].arg_type, NULL, NULL);
    if not result {
        return NULL;
    }
    value = ast2obj_object(state, o.view(1)[0].arg);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].arg, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_expr(state, o.view(1)[0].annotation);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].annotation, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_object(state, o.view(1)[0].type_comment);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].type_comment, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_keyword(state: ptr[ast_state], o: ptr[_keyword]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    result = PyType_GenericNew(state.view(1)[0].keyword_type, NULL, NULL);
    if not result {
        return NULL;
    }
    value = ast2obj_object(state, o.view(1)[0].arg);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].arg, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_expr(state, o.view(1)[0].value);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_alias(state: ptr[ast_state], o: ptr[_alias]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    result = PyType_GenericNew(state.view(1)[0].alias_type, NULL, NULL);
    if not result {
        return NULL;
    }
    value = ast2obj_object(state, o.view(1)[0].name);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_object(state, o.view(1)[0].asname);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].asname, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_withitem(state: ptr[ast_state], o: ptr[_withitem]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    result = PyType_GenericNew(state.view(1)[0].withitem_type, NULL, NULL);
    if not result {
        return NULL;
    }
    value = ast2obj_expr(state, o.view(1)[0].context_expr);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].context_expr, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_expr(state, o.view(1)[0].optional_vars);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].optional_vars, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_match_case(state: ptr[ast_state], o: ptr[_match_case]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    result = PyType_GenericNew(state.view(1)[0].match_case_type, NULL, NULL);
    if not result {
        return NULL;
    }
    value = ast2obj_pattern(state, o.view(1)[0].pattern);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].pattern, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_expr(state, o.view(1)[0].guard);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].guard, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_list_stmt(state, o.view(1)[0].body);
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].body, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_pattern(state: ptr[ast_state], o: ptr[_pattern]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    kind = o.view(1)[0].kind;
    if kind == MatchValue_kind {
        result = PyType_GenericNew(state.view(1)[0].MatchValue_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_MatchValue = ptr[_pattern_MatchValue](node_union(ptr(o)));
        value = ast2obj_expr(state, v_MatchValue.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == MatchSingleton_kind {
        result = PyType_GenericNew(state.view(1)[0].MatchSingleton_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_MatchSingleton = ptr[_pattern_MatchSingleton](node_union(ptr(o)));
        value = ast2obj_object(state, v_MatchSingleton.view(1)[0].value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == MatchSequence_kind {
        result = PyType_GenericNew(state.view(1)[0].MatchSequence_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_MatchSequence = ptr[_pattern_MatchSequence](node_union(ptr(o)));
        value = ast2obj_list_pattern(state, v_MatchSequence.view(1)[0].patterns);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].patterns, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == MatchMapping_kind {
        result = PyType_GenericNew(state.view(1)[0].MatchMapping_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_MatchMapping = ptr[_pattern_MatchMapping](node_union(ptr(o)));
        value = ast2obj_list_expr(state, v_MatchMapping.view(1)[0].keys);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].keys, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_pattern(state, v_MatchMapping.view(1)[0].patterns);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].patterns, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_MatchMapping.view(1)[0].rest);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].rest, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == MatchClass_kind {
        result = PyType_GenericNew(state.view(1)[0].MatchClass_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_MatchClass = ptr[_pattern_MatchClass](node_union(ptr(o)));
        value = ast2obj_expr(state, v_MatchClass.view(1)[0].cls);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].cls, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_pattern(state, v_MatchClass.view(1)[0].patterns);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].patterns, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_object(state, v_MatchClass.view(1)[0].kwd_attrs);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].kwd_attrs, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_list_pattern(state, v_MatchClass.view(1)[0].kwd_patterns);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].kwd_patterns, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == MatchStar_kind {
        result = PyType_GenericNew(state.view(1)[0].MatchStar_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_MatchStar = ptr[_pattern_MatchStar](node_union(ptr(o)));
        value = ast2obj_object(state, v_MatchStar.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == MatchAs_kind {
        result = PyType_GenericNew(state.view(1)[0].MatchAs_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_MatchAs = ptr[_pattern_MatchAs](node_union(ptr(o)));
        value = ast2obj_pattern(state, v_MatchAs.view(1)[0].pattern);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].pattern, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_MatchAs.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == MatchOr_kind {
        result = PyType_GenericNew(state.view(1)[0].MatchOr_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_MatchOr = ptr[_pattern_MatchOr](node_union(ptr(o)));
        value = ast2obj_list_pattern(state, v_MatchOr.view(1)[0].patterns);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].patterns, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    }
    value = ast2obj_int(state, i64(o.view(1)[0].lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_type_ignore(state: ptr[ast_state], o: ptr[_type_ignore]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    kind = o.view(1)[0].kind;
    if kind == TypeIgnore_kind {
        result = PyType_GenericNew(state.view(1)[0].TypeIgnore_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_TypeIgnore = ptr[_type_ignore_TypeIgnore](node_union(ptr(o)));
        value = ast2obj_int(state, i64(v_TypeIgnore.view(1)[0].lineno));
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].lineno, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_object(state, v_TypeIgnore.view(1)[0].tag);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].tag, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    }
    Py_LeaveRecursiveCall();
    return result;
}

impl ast2obj_type_param(state: ptr[ast_state], o: ptr[_type_param]) -> ptr[PyObject] {
    result = NULL;
    value = NULL;
    if not o {
        return object_new_ref(Py_None);
    }
    if Py_EnterRecursiveCall(ptr[u8]("during  ast construction")) != 0 {
        return NULL;
    }
    kind = o.view(1)[0].kind;
    if kind == TypeVar_kind {
        result = PyType_GenericNew(state.view(1)[0].TypeVar_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_TypeVar = ptr[_type_param_TypeVar](node_union(ptr(o)));
        value = ast2obj_object(state, v_TypeVar.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_TypeVar.view(1)[0].bound);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].bound, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_TypeVar.view(1)[0].default_value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].default_value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == ParamSpec_kind {
        result = PyType_GenericNew(state.view(1)[0].ParamSpec_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_ParamSpec = ptr[_type_param_ParamSpec](node_union(ptr(o)));
        value = ast2obj_object(state, v_ParamSpec.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_ParamSpec.view(1)[0].default_value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].default_value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    } elif kind == TypeVarTuple_kind {
        result = PyType_GenericNew(state.view(1)[0].TypeVarTuple_type, NULL, NULL);
        if not result {
            return ast2obj_failed(result, value);
        }
        v_TypeVarTuple = ptr[_type_param_TypeVarTuple](node_union(ptr(o)));
        value = ast2obj_object(state, v_TypeVarTuple.view(1)[0].name);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].name, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
        value = ast2obj_expr(state, v_TypeVarTuple.view(1)[0].default_value);
        if not value {
            return ast2obj_failed(result, value);
        }
        if PyObject_SetAttr(result, state.view(1)[0].default_value, value) == -1 {
            return ast2obj_failed(result, value);
        }
        object_decref(value);
    }
    value = ast2obj_int(state, i64(o.view(1)[0].lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_lineno));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_lineno, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    value = ast2obj_int(state, i64(o.view(1)[0].end_col_offset));
    if not value {
        return ast2obj_failed(result, value);
    }
    if PyObject_SetAttr(result, state.view(1)[0].end_col_offset, value) == -1 {
        return ast2obj_failed(result, value);
    }
    object_decref(value);
    Py_LeaveRecursiveCall();
    return result;
}

impl obj2ast_mod_Module(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]] {
    tmp = NULL;
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    type_ignores: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_mod]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_mod]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Module field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Module' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Module field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_ignores, &mut tmp) < 0 {
        return (i32(-1), ptr[_mod]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_mod]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Module field \"type_ignores\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    len_type_ignores = object_size(tmp);
    type_ignores = ptr[asdl_seq](_Py_asdl_type_ignore_seq_new(len_type_ignores, arena));
    if not type_ignores {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    i_type_ignores: i64 = 0;
    while i_type_ignores < len_type_ignores {
        tmp2 = object_new_ref(list_get_item(tmp, i_type_ignores));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Module' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        (res_type_ignores, item_type_ignores) = obj2ast_type_ignore(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_type_ignores != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        if len_type_ignores != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Module field \"type_ignores\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        asdl_seq_set(type_ignores, i_type_ignores, ptr(item_type_ignores));
        i_type_ignores += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Module(body, type_ignores, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    return (i32(0), out);
}

impl obj2ast_mod_Interactive(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]] {
    tmp = NULL;
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_mod]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_mod]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Interactive field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Interactive' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Interactive field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Interactive(body, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    return (i32(0), out);
}

impl obj2ast_mod_Expression(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]] {
    tmp = NULL;
    body: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_mod]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"body\" missing from Expression")
        );
        return (i32(-1), ptr[_mod]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Expression' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    (res_body, val_body) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_body != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    body = val_body;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Expression(body, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    return (i32(0), out);
}

impl obj2ast_mod_FunctionType(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]] {
    tmp = NULL;
    argtypes: ptr[asdl_seq] = ptr[asdl_seq]();
    returns: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].argtypes, &mut tmp) < 0 {
        return (i32(-1), ptr[_mod]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_mod]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("FunctionType field \"argtypes\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    len_argtypes = object_size(tmp);
    argtypes = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_argtypes, arena));
    if not argtypes {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    i_argtypes: i64 = 0;
    while i_argtypes < len_argtypes {
        tmp2 = object_new_ref(list_get_item(tmp, i_argtypes));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FunctionType' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        (res_argtypes, item_argtypes) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_argtypes != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        if len_argtypes != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("FunctionType field \"argtypes\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_mod]());
        }
        asdl_seq_set(argtypes, i_argtypes, ptr(item_argtypes));
        i_argtypes += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].returns, &mut tmp) < 0 {
        return (i32(-1), ptr[_mod]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"returns\" missing from FunctionType")
        );
        return (i32(-1), ptr[_mod]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FunctionType' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    (res_returns, val_returns) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_returns != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    returns = val_returns;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_FunctionType(argtypes, returns, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_mod]());
    }
    return (i32(0), out);
}

impl obj2ast_mod(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_mod]] {
    tmp = NULL;
    if obj_ == Py_None {
        return (i32(0), ptr[_mod]());
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Module_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_mod]());
    }
    if isinstance_ != 0 {
        return obj2ast_mod_Module(state, obj_, arena);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Interactive_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_mod]());
    }
    if isinstance_ != 0 {
        return obj2ast_mod_Interactive(state, obj_, arena);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Expression_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_mod]());
    }
    if isinstance_ != 0 {
        return obj2ast_mod_Expression(state, obj_, arena);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].FunctionType_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_mod]());
    }
    if isinstance_ != 0 {
        return obj2ast_mod_FunctionType(state, obj_, arena);
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of mod, but got %R"), obj_
    );
    object_xdecref(tmp);
    return (i32(-1), ptr[_mod]());
}

impl obj2ast_stmt_FunctionDef(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    name: ptr[PyObject] = NULL;
    args: ptr[_arguments] = ptr[_arguments]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    decorator_list: ptr[asdl_seq] = ptr[asdl_seq]();
    returns: ptr[_expr] = ptr[_expr]();
    type_comment: ptr[PyObject] = NULL;
    type_params: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"name\" missing from FunctionDef")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FunctionDef' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_name != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    name = val_name;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].args, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"args\" missing from FunctionDef")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FunctionDef' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_args, val_args) = obj2ast_arguments(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_args != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    args = val_args;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("FunctionDef field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("FunctionDef field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].decorator_list, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "FunctionDef field \"decorator_list\" must be a list, not a %.200s"
            ),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_decorator_list = object_size(tmp);
    decorator_list = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_decorator_list, arena));
    if not decorator_list {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_decorator_list: i64 = 0;
    while i_decorator_list < len_decorator_list {
        tmp2 = object_new_ref(list_get_item(tmp, i_decorator_list));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_decorator_list, item_decorator_list) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_decorator_list != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_decorator_list != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8](
                    "FunctionDef field \"decorator_list\" changed size during iteration"
                )
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(decorator_list, i_decorator_list, ptr(item_decorator_list));
        i_decorator_list += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].returns, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        returns = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_returns, val_returns) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_returns != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        returns = val_returns;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_comment, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        type_comment = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_comment, val_type_comment) = obj2ast_string(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_type_comment != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        type_comment = val_type_comment;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_params, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("FunctionDef field \"type_params\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_type_params = object_size(tmp);
    type_params = ptr[asdl_seq](_Py_asdl_type_param_seq_new(len_type_params, arena));
    if not type_params {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_type_params: i64 = 0;
    while i_type_params < len_type_params {
        tmp2 = object_new_ref(list_get_item(tmp, i_type_params));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_params, item_type_params) = obj2ast_type_param(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_type_params != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_type_params != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8](
                    "FunctionDef field \"type_params\" changed size during iteration"
                )
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(type_params, i_type_params, ptr(item_type_params));
        i_type_params += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_FunctionDef(
        name,
        args,
        body,
        decorator_list,
        returns,
        type_comment,
        type_params,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_AsyncFunctionDef(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    name: ptr[PyObject] = NULL;
    args: ptr[_arguments] = ptr[_arguments]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    decorator_list: ptr[asdl_seq] = ptr[asdl_seq]();
    returns: ptr[_expr] = ptr[_expr]();
    type_comment: ptr[PyObject] = NULL;
    type_params: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"name\" missing from AsyncFunctionDef")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFunctionDef' node"))
        != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_name != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    name = val_name;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].args, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"args\" missing from AsyncFunctionDef")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFunctionDef' node"))
        != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_args, val_args) = obj2ast_arguments(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_args != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    args = val_args;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("AsyncFunctionDef field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("AsyncFunctionDef field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].decorator_list, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "AsyncFunctionDef field \"decorator_list\" must be a list, not a %.200s"
            ),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_decorator_list = object_size(tmp);
    decorator_list = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_decorator_list, arena));
    if not decorator_list {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_decorator_list: i64 = 0;
    while i_decorator_list < len_decorator_list {
        tmp2 = object_new_ref(list_get_item(tmp, i_decorator_list));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_decorator_list, item_decorator_list) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_decorator_list != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_decorator_list != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8](
                    "AsyncFunctionDef field \"decorator_list\" changed size during iteration"
                )
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(decorator_list, i_decorator_list, ptr(item_decorator_list));
        i_decorator_list += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].returns, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        returns = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_returns, val_returns) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_returns != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        returns = val_returns;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_comment, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        type_comment = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_comment, val_type_comment) = obj2ast_string(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_type_comment != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        type_comment = val_type_comment;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_params, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "AsyncFunctionDef field \"type_params\" must be a list, not a %.200s"
            ),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_type_params = object_size(tmp);
    type_params = ptr[asdl_seq](_Py_asdl_type_param_seq_new(len_type_params, arena));
    if not type_params {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_type_params: i64 = 0;
    while i_type_params < len_type_params {
        tmp2 = object_new_ref(list_get_item(tmp, i_type_params));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFunctionDef' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_params, item_type_params) = obj2ast_type_param(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_type_params != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_type_params != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8](
                    "AsyncFunctionDef field \"type_params\" changed size during iteration"
                )
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(type_params, i_type_params, ptr(item_type_params));
        i_type_params += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_AsyncFunctionDef(
        name,
        args,
        body,
        decorator_list,
        returns,
        type_comment,
        type_params,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_ClassDef(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    name: ptr[PyObject] = NULL;
    bases: ptr[asdl_seq] = ptr[asdl_seq]();
    keywords: ptr[asdl_seq] = ptr[asdl_seq]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    decorator_list: ptr[asdl_seq] = ptr[asdl_seq]();
    type_params: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"name\" missing from ClassDef")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ClassDef' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_name != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    name = val_name;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].bases, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("ClassDef field \"bases\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_bases = object_size(tmp);
    bases = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_bases, arena));
    if not bases {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_bases: i64 = 0;
    while i_bases < len_bases {
        tmp2 = object_new_ref(list_get_item(tmp, i_bases));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ClassDef' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_bases, item_bases) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_bases != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_bases != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("ClassDef field \"bases\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(bases, i_bases, ptr(item_bases));
        i_bases += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].keywords, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("ClassDef field \"keywords\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_keywords = object_size(tmp);
    keywords = ptr[asdl_seq](_Py_asdl_keyword_seq_new(len_keywords, arena));
    if not keywords {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_keywords: i64 = 0;
    while i_keywords < len_keywords {
        tmp2 = object_new_ref(list_get_item(tmp, i_keywords));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ClassDef' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_keywords, item_keywords) = obj2ast_keyword(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_keywords != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_keywords != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("ClassDef field \"keywords\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(keywords, i_keywords, ptr(item_keywords));
        i_keywords += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("ClassDef field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ClassDef' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("ClassDef field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].decorator_list, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("ClassDef field \"decorator_list\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_decorator_list = object_size(tmp);
    decorator_list = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_decorator_list, arena));
    if not decorator_list {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_decorator_list: i64 = 0;
    while i_decorator_list < len_decorator_list {
        tmp2 = object_new_ref(list_get_item(tmp, i_decorator_list));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ClassDef' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_decorator_list, item_decorator_list) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_decorator_list != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_decorator_list != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8](
                    "ClassDef field \"decorator_list\" changed size during iteration"
                )
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(decorator_list, i_decorator_list, ptr(item_decorator_list));
        i_decorator_list += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_params, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("ClassDef field \"type_params\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_type_params = object_size(tmp);
    type_params = ptr[asdl_seq](_Py_asdl_type_param_seq_new(len_type_params, arena));
    if not type_params {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_type_params: i64 = 0;
    while i_type_params < len_type_params {
        tmp2 = object_new_ref(list_get_item(tmp, i_type_params));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ClassDef' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_params, item_type_params) = obj2ast_type_param(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_type_params != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_type_params != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("ClassDef field \"type_params\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(type_params, i_type_params, ptr(item_type_params));
        i_type_params += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_ClassDef(
        name,
        bases,
        keywords,
        body,
        decorator_list,
        type_params,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Return(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        value = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Return' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_value, val_value) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_value != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        value = val_value;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_Return(value, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Delete(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    targets: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].targets, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Delete field \"targets\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_targets = object_size(tmp);
    targets = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_targets, arena));
    if not targets {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_targets: i64 = 0;
    while i_targets < len_targets {
        tmp2 = object_new_ref(list_get_item(tmp, i_targets));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Delete' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_targets, item_targets) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_targets != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_targets != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Delete field \"targets\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(targets, i_targets, ptr(item_targets));
        i_targets += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Delete(targets, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Assign(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    targets: ptr[asdl_seq] = ptr[asdl_seq]();
    value: ptr[_expr] = ptr[_expr]();
    type_comment: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].targets, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Assign field \"targets\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_targets = object_size(tmp);
    targets = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_targets, arena));
    if not targets {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_targets: i64 = 0;
    while i_targets < len_targets {
        tmp2 = object_new_ref(list_get_item(tmp, i_targets));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Assign' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_targets, item_targets) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_targets != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_targets != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Assign field \"targets\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(targets, i_targets, ptr(item_targets));
        i_targets += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from Assign")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Assign' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_comment, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        type_comment = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Assign' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_comment, val_type_comment) = obj2ast_string(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_type_comment != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        type_comment = val_type_comment;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_Assign(
        targets,
        value,
        type_comment,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_TypeAlias(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    name: ptr[_expr] = ptr[_expr]();
    type_params: ptr[asdl_seq] = ptr[asdl_seq]();
    value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"name\" missing from TypeAlias")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeAlias' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_name, val_name) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_name != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    name = val_name;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_params, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("TypeAlias field \"type_params\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_type_params = object_size(tmp);
    type_params = ptr[asdl_seq](_Py_asdl_type_param_seq_new(len_type_params, arena));
    if not type_params {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_type_params: i64 = 0;
    while i_type_params < len_type_params {
        tmp2 = object_new_ref(list_get_item(tmp, i_type_params));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeAlias' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_params, item_type_params) = obj2ast_type_param(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_type_params != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_type_params != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("TypeAlias field \"type_params\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(type_params, i_type_params, ptr(item_type_params));
        i_type_params += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from TypeAlias")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeAlias' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_TypeAlias(
        name, type_params, value, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_AugAssign(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    target: ptr[_expr] = ptr[_expr]();
    op: i32 = 0;
    value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].target, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"target\" missing from AugAssign")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AugAssign' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_target, val_target) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_target != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    target = val_target;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].op, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"op\" missing from AugAssign")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AugAssign' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_op, val_op) = obj2ast_operator(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_op != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    op = val_op;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from AugAssign")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AugAssign' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_AugAssign(
        target, op, value, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_AnnAssign(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    target: ptr[_expr] = ptr[_expr]();
    annotation: ptr[_expr] = ptr[_expr]();
    value: ptr[_expr] = ptr[_expr]();
    simple: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].target, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"target\" missing from AnnAssign")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AnnAssign' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_target, val_target) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_target != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    target = val_target;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].annotation, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"annotation\" missing from AnnAssign")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AnnAssign' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_annotation, val_annotation) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_annotation != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    annotation = val_annotation;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        value = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AnnAssign' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_value, val_value) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_value != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        value = val_value;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].simple, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"simple\" missing from AnnAssign")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AnnAssign' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_simple, val_simple) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_simple != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    simple = val_simple;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_AnnAssign(
        target,
        annotation,
        value,
        simple,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_For(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    target: ptr[_expr] = ptr[_expr]();
    iter: ptr[_expr] = ptr[_expr]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    orelse: ptr[asdl_seq] = ptr[asdl_seq]();
    type_comment: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].target, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"target\" missing from For")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'For' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_target, val_target) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_target != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    target = val_target;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].iter, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"iter\" missing from For")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'For' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_iter, val_iter) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_iter != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    iter = val_iter;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("For field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'For' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("For field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].orelse, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("For field \"orelse\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_orelse = object_size(tmp);
    orelse = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_orelse, arena));
    if not orelse {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_orelse: i64 = 0;
    while i_orelse < len_orelse {
        tmp2 = object_new_ref(list_get_item(tmp, i_orelse));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'For' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_orelse, item_orelse) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_orelse != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_orelse != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("For field \"orelse\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(orelse, i_orelse, ptr(item_orelse));
        i_orelse += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_comment, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        type_comment = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'For' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_comment, val_type_comment) = obj2ast_string(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_type_comment != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        type_comment = val_type_comment;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_For(
        target,
        iter,
        body,
        orelse,
        type_comment,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_AsyncFor(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    target: ptr[_expr] = ptr[_expr]();
    iter: ptr[_expr] = ptr[_expr]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    orelse: ptr[asdl_seq] = ptr[asdl_seq]();
    type_comment: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].target, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"target\" missing from AsyncFor")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFor' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_target, val_target) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_target != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    target = val_target;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].iter, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"iter\" missing from AsyncFor")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFor' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_iter, val_iter) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_iter != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    iter = val_iter;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("AsyncFor field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFor' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("AsyncFor field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].orelse, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("AsyncFor field \"orelse\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_orelse = object_size(tmp);
    orelse = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_orelse, arena));
    if not orelse {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_orelse: i64 = 0;
    while i_orelse < len_orelse {
        tmp2 = object_new_ref(list_get_item(tmp, i_orelse));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFor' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_orelse, item_orelse) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_orelse != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_orelse != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("AsyncFor field \"orelse\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(orelse, i_orelse, ptr(item_orelse));
        i_orelse += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_comment, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        type_comment = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncFor' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_comment, val_type_comment) = obj2ast_string(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_type_comment != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        type_comment = val_type_comment;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_AsyncFor(
        target,
        iter,
        body,
        orelse,
        type_comment,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_While(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    test_: ptr[_expr] = ptr[_expr]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    orelse: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].test_, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"test\" missing from While")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'While' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_test, val_test) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_test != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    test_ = val_test;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("While field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'While' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("While field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].orelse, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("While field \"orelse\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_orelse = object_size(tmp);
    orelse = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_orelse, arena));
    if not orelse {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_orelse: i64 = 0;
    while i_orelse < len_orelse {
        tmp2 = object_new_ref(list_get_item(tmp, i_orelse));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'While' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_orelse, item_orelse) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_orelse != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_orelse != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("While field \"orelse\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(orelse, i_orelse, ptr(item_orelse));
        i_orelse += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_While(
        test_, body, orelse, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_If(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    test_: ptr[_expr] = ptr[_expr]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    orelse: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].test_, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"test\" missing from If")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'If' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_test, val_test) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_test != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    test_ = val_test;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("If field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'If' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("If field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].orelse, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("If field \"orelse\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_orelse = object_size(tmp);
    orelse = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_orelse, arena));
    if not orelse {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_orelse: i64 = 0;
    while i_orelse < len_orelse {
        tmp2 = object_new_ref(list_get_item(tmp, i_orelse));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'If' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_orelse, item_orelse) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_orelse != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_orelse != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("If field \"orelse\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(orelse, i_orelse, ptr(item_orelse));
        i_orelse += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_If(
        test_, body, orelse, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_With(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    items: ptr[asdl_seq] = ptr[asdl_seq]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    type_comment: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].items, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("With field \"items\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_items = object_size(tmp);
    items = ptr[asdl_seq](_Py_asdl_withitem_seq_new(len_items, arena));
    if not items {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_items: i64 = 0;
    while i_items < len_items {
        tmp2 = object_new_ref(list_get_item(tmp, i_items));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'With' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_items, item_items) = obj2ast_withitem(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_items != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_items != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("With field \"items\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(items, i_items, ptr(item_items));
        i_items += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("With field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'With' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("With field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_comment, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        type_comment = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'With' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_comment, val_type_comment) = obj2ast_string(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_type_comment != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        type_comment = val_type_comment;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_With(
        items, body, type_comment, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_AsyncWith(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    items: ptr[asdl_seq] = ptr[asdl_seq]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    type_comment: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].items, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("AsyncWith field \"items\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_items = object_size(tmp);
    items = ptr[asdl_seq](_Py_asdl_withitem_seq_new(len_items, arena));
    if not items {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_items: i64 = 0;
    while i_items < len_items {
        tmp2 = object_new_ref(list_get_item(tmp, i_items));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncWith' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_items, item_items) = obj2ast_withitem(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_items != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_items != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("AsyncWith field \"items\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(items, i_items, ptr(item_items));
        i_items += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("AsyncWith field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncWith' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("AsyncWith field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_comment, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        type_comment = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'AsyncWith' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_type_comment, val_type_comment) = obj2ast_string(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_type_comment != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        type_comment = val_type_comment;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_AsyncWith(
        items, body, type_comment, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Match(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    subject: ptr[_expr] = ptr[_expr]();
    cases: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].subject, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"subject\" missing from Match")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Match' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_subject, val_subject) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_subject != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    subject = val_subject;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].cases, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Match field \"cases\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_cases = object_size(tmp);
    cases = ptr[asdl_seq](_Py_asdl_match_case_seq_new(len_cases, arena));
    if not cases {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_cases: i64 = 0;
    while i_cases < len_cases {
        tmp2 = object_new_ref(list_get_item(tmp, i_cases));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Match' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_cases, item_cases) = obj2ast_match_case(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_cases != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_cases != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Match field \"cases\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(cases, i_cases, ptr(item_cases));
        i_cases += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Match(
        subject, cases, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Raise(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    exc: ptr[_expr] = ptr[_expr]();
    cause: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].exc, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        exc = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Raise' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_exc, val_exc) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_exc != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        exc = val_exc;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].cause, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        cause = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Raise' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_cause, val_cause) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_cause != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        cause = val_cause;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_Raise(
        exc, cause, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Try(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    handlers: ptr[asdl_seq] = ptr[asdl_seq]();
    orelse: ptr[asdl_seq] = ptr[asdl_seq]();
    finalbody: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Try field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Try' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Try field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].handlers, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Try field \"handlers\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_handlers = object_size(tmp);
    handlers = ptr[asdl_seq](_Py_asdl_excepthandler_seq_new(len_handlers, arena));
    if not handlers {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_handlers: i64 = 0;
    while i_handlers < len_handlers {
        tmp2 = object_new_ref(list_get_item(tmp, i_handlers));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Try' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_handlers, item_handlers) = obj2ast_excepthandler(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_handlers != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_handlers != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Try field \"handlers\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(handlers, i_handlers, ptr(item_handlers));
        i_handlers += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].orelse, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Try field \"orelse\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_orelse = object_size(tmp);
    orelse = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_orelse, arena));
    if not orelse {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_orelse: i64 = 0;
    while i_orelse < len_orelse {
        tmp2 = object_new_ref(list_get_item(tmp, i_orelse));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Try' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_orelse, item_orelse) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_orelse != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_orelse != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Try field \"orelse\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(orelse, i_orelse, ptr(item_orelse));
        i_orelse += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].finalbody, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Try field \"finalbody\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_finalbody = object_size(tmp);
    finalbody = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_finalbody, arena));
    if not finalbody {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_finalbody: i64 = 0;
    while i_finalbody < len_finalbody {
        tmp2 = object_new_ref(list_get_item(tmp, i_finalbody));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Try' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_finalbody, item_finalbody) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_finalbody != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_finalbody != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Try field \"finalbody\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(finalbody, i_finalbody, ptr(item_finalbody));
        i_finalbody += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Try(
        body,
        handlers,
        orelse,
        finalbody,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_TryStar(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    handlers: ptr[asdl_seq] = ptr[asdl_seq]();
    orelse: ptr[asdl_seq] = ptr[asdl_seq]();
    finalbody: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("TryStar field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TryStar' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("TryStar field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].handlers, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("TryStar field \"handlers\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_handlers = object_size(tmp);
    handlers = ptr[asdl_seq](_Py_asdl_excepthandler_seq_new(len_handlers, arena));
    if not handlers {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_handlers: i64 = 0;
    while i_handlers < len_handlers {
        tmp2 = object_new_ref(list_get_item(tmp, i_handlers));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TryStar' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_handlers, item_handlers) = obj2ast_excepthandler(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_handlers != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_handlers != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("TryStar field \"handlers\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(handlers, i_handlers, ptr(item_handlers));
        i_handlers += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].orelse, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("TryStar field \"orelse\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_orelse = object_size(tmp);
    orelse = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_orelse, arena));
    if not orelse {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_orelse: i64 = 0;
    while i_orelse < len_orelse {
        tmp2 = object_new_ref(list_get_item(tmp, i_orelse));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TryStar' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_orelse, item_orelse) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_orelse != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_orelse != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("TryStar field \"orelse\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(orelse, i_orelse, ptr(item_orelse));
        i_orelse += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].finalbody, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("TryStar field \"finalbody\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_finalbody = object_size(tmp);
    finalbody = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_finalbody, arena));
    if not finalbody {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_finalbody: i64 = 0;
    while i_finalbody < len_finalbody {
        tmp2 = object_new_ref(list_get_item(tmp, i_finalbody));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TryStar' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_finalbody, item_finalbody) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_finalbody != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_finalbody != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("TryStar field \"finalbody\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(finalbody, i_finalbody, ptr(item_finalbody));
        i_finalbody += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_TryStar(
        body,
        handlers,
        orelse,
        finalbody,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Assert(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    test_: ptr[_expr] = ptr[_expr]();
    msg: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].test_, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"test\" missing from Assert")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Assert' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_test, val_test) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_test != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    test_ = val_test;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].msg, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        msg = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Assert' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_msg, val_msg) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_msg != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        msg = val_msg;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_Assert(
        test_, msg, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Import(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    names: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].names, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Import field \"names\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_names = object_size(tmp);
    names = ptr[asdl_seq](_Py_asdl_alias_seq_new(len_names, arena));
    if not names {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_names: i64 = 0;
    while i_names < len_names {
        tmp2 = object_new_ref(list_get_item(tmp, i_names));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Import' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_names, item_names) = obj2ast_alias(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_names != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_names != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Import field \"names\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(names, i_names, ptr(item_names));
        i_names += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Import(names, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_ImportFrom(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    module: ptr[PyObject] = NULL;
    names: ptr[asdl_seq] = ptr[asdl_seq]();
    level: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].module, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        module = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ImportFrom' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_module, val_module) = obj2ast_identifier(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_module != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        module = val_module;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].names, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("ImportFrom field \"names\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_names = object_size(tmp);
    names = ptr[asdl_seq](_Py_asdl_alias_seq_new(len_names, arena));
    if not names {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_names: i64 = 0;
    while i_names < len_names {
        tmp2 = object_new_ref(list_get_item(tmp, i_names));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ImportFrom' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_names, item_names) = obj2ast_alias(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_names != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_names != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("ImportFrom field \"names\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(names, i_names, ptr(item_names));
        i_names += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].level, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        level = 0;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ImportFrom' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_level, val_level) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_level != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        level = val_level;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_ImportFrom(
        module, names, level, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Global(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    names: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].names, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Global field \"names\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_names = object_size(tmp);
    names = ptr[asdl_seq](_Py_asdl_identifier_seq_new(len_names, arena));
    if not names {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_names: i64 = 0;
    while i_names < len_names {
        tmp2 = object_new_ref(list_get_item(tmp, i_names));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Global' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_names, item_names) = obj2ast_identifier(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_names != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_names != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Global field \"names\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(names, i_names, ptr(item_names));
        i_names += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Global(names, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Nonlocal(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    names: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].names, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_stmt]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Nonlocal field \"names\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    len_names = object_size(tmp);
    names = ptr[asdl_seq](_Py_asdl_identifier_seq_new(len_names, arena));
    if not names {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    i_names: i64 = 0;
    while i_names < len_names {
        tmp2 = object_new_ref(list_get_item(tmp, i_names));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Nonlocal' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_names, item_names) = obj2ast_identifier(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_names != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        if len_names != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Nonlocal field \"names\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        asdl_seq_set(names, i_names, ptr(item_names));
        i_names += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Nonlocal(names, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Expr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from Expr")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Expr' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Expr(value, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Pass(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    out = _PyAST_Pass(lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Break(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    out = _PyAST_Break(lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt_Continue(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    out = _PyAST_Continue(lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    return (i32(0), out);
}

impl obj2ast_stmt(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_stmt]] {
    tmp = NULL;
    lineno: i32 = 0;
    col_offset: i32 = 0;
    end_lineno: i32 = 0;
    end_col_offset: i32 = 0;
    if obj_ == Py_None {
        return (i32(0), ptr[_stmt]());
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"lineno\" missing from stmt")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'stmt' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_lineno, val_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    lineno = val_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"col_offset\" missing from stmt")
        );
        return (i32(-1), ptr[_stmt]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'stmt' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    (res_col_offset, val_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_stmt]());
    }
    col_offset = val_col_offset;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_lineno = lineno;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'stmt' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_end_lineno, val_end_lineno) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_lineno != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        end_lineno = val_end_lineno;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_stmt]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_col_offset = col_offset;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'stmt' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        (res_end_col_offset, val_end_col_offset) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_col_offset != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_stmt]());
        }
        end_col_offset = val_end_col_offset;
        object_decref(tmp);
        tmp = NULL;
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].FunctionDef_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_FunctionDef(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].AsyncFunctionDef_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_AsyncFunctionDef(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].ClassDef_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_ClassDef(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Return_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Return(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Delete_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Delete(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Assign_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Assign(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].TypeAlias_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_TypeAlias(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].AugAssign_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_AugAssign(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].AnnAssign_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_AnnAssign(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].For_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_For(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].AsyncFor_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_AsyncFor(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].While_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_While(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].If_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_If(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].With_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_With(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].AsyncWith_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_AsyncWith(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Match_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Match(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Raise_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Raise(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Try_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Try(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].TryStar_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_TryStar(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Assert_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Assert(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Import_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Import(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].ImportFrom_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_ImportFrom(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Global_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Global(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Nonlocal_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Nonlocal(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Expr_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Expr(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Pass_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Pass(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Break_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Break(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Continue_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_stmt]());
    }
    if isinstance_ != 0 {
        return obj2ast_stmt_Continue(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of stmt, but got %R"), obj_
    );
    object_xdecref(tmp);
    return (i32(-1), ptr[_stmt]());
}

impl obj2ast_expr_BoolOp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    op: i32 = 0;
    values: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].op, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"op\" missing from BoolOp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'BoolOp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_op, val_op) = obj2ast_boolop(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_op != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    op = val_op;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].values, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("BoolOp field \"values\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_values = object_size(tmp);
    values = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_values, arena));
    if not values {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_values: i64 = 0;
    while i_values < len_values {
        tmp2 = object_new_ref(list_get_item(tmp, i_values));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'BoolOp' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_values, item_values) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_values != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_values != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("BoolOp field \"values\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(values, i_values, ptr(item_values));
        i_values += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_BoolOp(
        op, values, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_NamedExpr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    target: ptr[_expr] = ptr[_expr]();
    value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].target, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"target\" missing from NamedExpr")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'NamedExpr' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_target, val_target) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_target != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    target = val_target;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from NamedExpr")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'NamedExpr' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_NamedExpr(
        target, value, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_BinOp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    left: ptr[_expr] = ptr[_expr]();
    op: i32 = 0;
    right: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].left, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"left\" missing from BinOp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'BinOp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_left, val_left) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_left != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    left = val_left;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].op, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"op\" missing from BinOp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'BinOp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_op, val_op) = obj2ast_operator(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_op != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    op = val_op;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].right, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"right\" missing from BinOp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'BinOp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_right, val_right) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_right != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    right = val_right;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_BinOp(
        left, op, right, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_UnaryOp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    op: i32 = 0;
    operand: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].op, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"op\" missing from UnaryOp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'UnaryOp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_op, val_op) = obj2ast_unaryop(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_op != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    op = val_op;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].operand, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"operand\" missing from UnaryOp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'UnaryOp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_operand, val_operand) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_operand != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    operand = val_operand;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_UnaryOp(
        op, operand, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Lambda(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    args: ptr[_arguments] = ptr[_arguments]();
    body: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].args, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"args\" missing from Lambda")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Lambda' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_args, val_args) = obj2ast_arguments(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_args != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    args = val_args;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"body\" missing from Lambda")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Lambda' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_body, val_body) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_body != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    body = val_body;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Lambda(
        args, body, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_IfExp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    test_: ptr[_expr] = ptr[_expr]();
    body: ptr[_expr] = ptr[_expr]();
    orelse: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].test_, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"test\" missing from IfExp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'IfExp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_test, val_test) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_test != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    test_ = val_test;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"body\" missing from IfExp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'IfExp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_body, val_body) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_body != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    body = val_body;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].orelse, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"orelse\" missing from IfExp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'IfExp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_orelse, val_orelse) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_orelse != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    orelse = val_orelse;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_IfExp(
        test_, body, orelse, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Dict(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    keys: ptr[asdl_seq] = ptr[asdl_seq]();
    values: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].keys, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Dict field \"keys\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_keys = object_size(tmp);
    keys = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_keys, arena));
    if not keys {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_keys: i64 = 0;
    while i_keys < len_keys {
        tmp2 = object_new_ref(list_get_item(tmp, i_keys));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Dict' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_keys, item_keys) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_keys != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_keys != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Dict field \"keys\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(keys, i_keys, ptr(item_keys));
        i_keys += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].values, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Dict field \"values\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_values = object_size(tmp);
    values = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_values, arena));
    if not values {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_values: i64 = 0;
    while i_values < len_values {
        tmp2 = object_new_ref(list_get_item(tmp, i_values));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Dict' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_values, item_values) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_values != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_values != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Dict field \"values\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(values, i_values, ptr(item_values));
        i_values += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Dict(
        keys, values, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Set(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    elts: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].elts, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Set field \"elts\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_elts = object_size(tmp);
    elts = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_elts, arena));
    if not elts {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_elts: i64 = 0;
    while i_elts < len_elts {
        tmp2 = object_new_ref(list_get_item(tmp, i_elts));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Set' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_elts, item_elts) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_elts != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_elts != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Set field \"elts\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(elts, i_elts, ptr(item_elts));
        i_elts += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Set(elts, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_ListComp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    elt: ptr[_expr] = ptr[_expr]();
    generators: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].elt, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"elt\" missing from ListComp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ListComp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_elt, val_elt) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_elt != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    elt = val_elt;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].generators, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("ListComp field \"generators\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_generators = object_size(tmp);
    generators = ptr[asdl_seq](_Py_asdl_comprehension_seq_new(len_generators, arena));
    if not generators {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_generators: i64 = 0;
    while i_generators < len_generators {
        tmp2 = object_new_ref(list_get_item(tmp, i_generators));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ListComp' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_generators, item_generators) = obj2ast_comprehension(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_generators != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_generators != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("ListComp field \"generators\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(generators, i_generators, ptr(item_generators));
        i_generators += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_ListComp(
        elt, generators, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_SetComp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    elt: ptr[_expr] = ptr[_expr]();
    generators: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].elt, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"elt\" missing from SetComp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'SetComp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_elt, val_elt) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_elt != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    elt = val_elt;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].generators, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("SetComp field \"generators\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_generators = object_size(tmp);
    generators = ptr[asdl_seq](_Py_asdl_comprehension_seq_new(len_generators, arena));
    if not generators {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_generators: i64 = 0;
    while i_generators < len_generators {
        tmp2 = object_new_ref(list_get_item(tmp, i_generators));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'SetComp' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_generators, item_generators) = obj2ast_comprehension(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_generators != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_generators != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("SetComp field \"generators\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(generators, i_generators, ptr(item_generators));
        i_generators += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_SetComp(
        elt, generators, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_DictComp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    key: ptr[_expr] = ptr[_expr]();
    value: ptr[_expr] = ptr[_expr]();
    generators: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].key, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"key\" missing from DictComp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'DictComp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_key, val_key) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_key != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    key = val_key;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from DictComp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'DictComp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].generators, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("DictComp field \"generators\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_generators = object_size(tmp);
    generators = ptr[asdl_seq](_Py_asdl_comprehension_seq_new(len_generators, arena));
    if not generators {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_generators: i64 = 0;
    while i_generators < len_generators {
        tmp2 = object_new_ref(list_get_item(tmp, i_generators));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'DictComp' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_generators, item_generators) = obj2ast_comprehension(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_generators != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_generators != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("DictComp field \"generators\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(generators, i_generators, ptr(item_generators));
        i_generators += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_DictComp(
        key, value, generators, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_GeneratorExp(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    elt: ptr[_expr] = ptr[_expr]();
    generators: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].elt, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"elt\" missing from GeneratorExp")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'GeneratorExp' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_elt, val_elt) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_elt != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    elt = val_elt;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].generators, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("GeneratorExp field \"generators\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_generators = object_size(tmp);
    generators = ptr[asdl_seq](_Py_asdl_comprehension_seq_new(len_generators, arena));
    if not generators {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_generators: i64 = 0;
    while i_generators < len_generators {
        tmp2 = object_new_ref(list_get_item(tmp, i_generators));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'GeneratorExp' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_generators, item_generators) = obj2ast_comprehension(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_generators != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_generators != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8](
                    "GeneratorExp field \"generators\" changed size during iteration"
                )
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(generators, i_generators, ptr(item_generators));
        i_generators += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_GeneratorExp(
        elt, generators, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Await(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from Await")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Await' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Await(value, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Yield(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        value = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Yield' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_value, val_value) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_value != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        value = val_value;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_Yield(value, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_YieldFrom(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from YieldFrom")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'YieldFrom' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_YieldFrom(
        value, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Compare(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    left: ptr[_expr] = ptr[_expr]();
    ops: ptr[asdl_seq] = ptr[asdl_seq]();
    comparators: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].left, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"left\" missing from Compare")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Compare' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_left, val_left) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_left != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    left = val_left;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].ops, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Compare field \"ops\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_ops = object_size(tmp);
    ops = ptr[asdl_seq](_Py_asdl_int_seq_new(len_ops, arena));
    if not ops {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_ops: i64 = 0;
    while i_ops < len_ops {
        tmp2 = object_new_ref(list_get_item(tmp, i_ops));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Compare' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_ops, item_ops) = obj2ast_cmpop(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_ops != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_ops != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Compare field \"ops\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_int_seq_set(ops, i_ops, item_ops);
        i_ops += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].comparators, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Compare field \"comparators\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_comparators = object_size(tmp);
    comparators = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_comparators, arena));
    if not comparators {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_comparators: i64 = 0;
    while i_comparators < len_comparators {
        tmp2 = object_new_ref(list_get_item(tmp, i_comparators));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Compare' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_comparators, item_comparators) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_comparators != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_comparators != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Compare field \"comparators\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(comparators, i_comparators, ptr(item_comparators));
        i_comparators += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Compare(
        left, ops, comparators, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Call(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    func: ptr[_expr] = ptr[_expr]();
    args: ptr[asdl_seq] = ptr[asdl_seq]();
    keywords: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].func, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"func\" missing from Call")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Call' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_func, val_func) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_func != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    func = val_func;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].args, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Call field \"args\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_args = object_size(tmp);
    args = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_args, arena));
    if not args {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_args: i64 = 0;
    while i_args < len_args {
        tmp2 = object_new_ref(list_get_item(tmp, i_args));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Call' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_args, item_args) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_args != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_args != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Call field \"args\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(args, i_args, ptr(item_args));
        i_args += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].keywords, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Call field \"keywords\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_keywords = object_size(tmp);
    keywords = ptr[asdl_seq](_Py_asdl_keyword_seq_new(len_keywords, arena));
    if not keywords {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_keywords: i64 = 0;
    while i_keywords < len_keywords {
        tmp2 = object_new_ref(list_get_item(tmp, i_keywords));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Call' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_keywords, item_keywords) = obj2ast_keyword(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_keywords != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_keywords != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Call field \"keywords\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(keywords, i_keywords, ptr(item_keywords));
        i_keywords += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Call(
        func, args, keywords, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_FormattedValue(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    conversion: i32 = 0;
    format_spec: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"value\" missing from FormattedValue")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FormattedValue' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].conversion, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"conversion\" missing from FormattedValue")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FormattedValue' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_conversion, val_conversion) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_conversion != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    conversion = val_conversion;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].format_spec, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        format_spec = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'FormattedValue' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_format_spec, val_format_spec) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_format_spec != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        format_spec = val_format_spec;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_FormattedValue(
        value,
        conversion,
        format_spec,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Interpolation(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    str_: ptr[PyObject] = NULL;
    conversion: i32 = 0;
    format_spec: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"value\" missing from Interpolation")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Interpolation' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].str, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"str\" missing from Interpolation")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Interpolation' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_str, val_str) = obj2ast_constant(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_str != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    str_ = val_str;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].conversion, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"conversion\" missing from Interpolation")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Interpolation' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_conversion, val_conversion) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_conversion != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    conversion = val_conversion;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].format_spec, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        format_spec = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Interpolation' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_format_spec, val_format_spec) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_format_spec != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        format_spec = val_format_spec;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_Interpolation(
        value,
        str_,
        conversion,
        format_spec,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_JoinedStr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    values: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].values, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("JoinedStr field \"values\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_values = object_size(tmp);
    values = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_values, arena));
    if not values {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_values: i64 = 0;
    while i_values < len_values {
        tmp2 = object_new_ref(list_get_item(tmp, i_values));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'JoinedStr' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_values, item_values) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_values != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_values != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("JoinedStr field \"values\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(values, i_values, ptr(item_values));
        i_values += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_JoinedStr(
        values, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_TemplateStr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    values: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].values, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("TemplateStr field \"values\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_values = object_size(tmp);
    values = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_values, arena));
    if not values {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_values: i64 = 0;
    while i_values < len_values {
        tmp2 = object_new_ref(list_get_item(tmp, i_values));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TemplateStr' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_values, item_values) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_values != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_values != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("TemplateStr field \"values\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(values, i_values, ptr(item_values));
        i_values += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_TemplateStr(
        values, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Constant(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    value: ptr[PyObject] = NULL;
    kind: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from Constant")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Constant' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_constant(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].kind, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        kind = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Constant' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_kind, val_kind) = obj2ast_string(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_kind != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        kind = val_kind;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_Constant(
        value, kind, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Attribute(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    attr: ptr[PyObject] = NULL;
    ctx: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from Attribute")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Attribute' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].attr, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"attr\" missing from Attribute")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Attribute' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_attr, val_attr) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_attr != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    attr = val_attr;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].ctx, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"ctx\" missing from Attribute")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Attribute' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_ctx, val_ctx) = obj2ast_expr_context(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_ctx != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    ctx = val_ctx;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Attribute(
        value, attr, ctx, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Subscript(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    slice: ptr[_expr] = ptr[_expr]();
    ctx: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from Subscript")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Subscript' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].slice, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"slice\" missing from Subscript")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Subscript' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_slice, val_slice) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_slice != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    slice = val_slice;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].ctx, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"ctx\" missing from Subscript")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Subscript' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_ctx, val_ctx) = obj2ast_expr_context(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_ctx != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    ctx = val_ctx;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Subscript(
        value, slice, ctx, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Starred(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    ctx: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from Starred")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Starred' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].ctx, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"ctx\" missing from Starred")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Starred' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_ctx, val_ctx) = obj2ast_expr_context(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_ctx != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    ctx = val_ctx;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Starred(
        value, ctx, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Name(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    id: ptr[PyObject] = NULL;
    ctx: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].id, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"id\" missing from Name")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Name' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_id, val_id) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_id != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    id = val_id;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].ctx, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"ctx\" missing from Name")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Name' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_ctx, val_ctx) = obj2ast_expr_context(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_ctx != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    ctx = val_ctx;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Name(id, ctx, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_List(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    elts: ptr[asdl_seq] = ptr[asdl_seq]();
    ctx: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].elts, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("List field \"elts\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_elts = object_size(tmp);
    elts = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_elts, arena));
    if not elts {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_elts: i64 = 0;
    while i_elts < len_elts {
        tmp2 = object_new_ref(list_get_item(tmp, i_elts));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'List' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_elts, item_elts) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_elts != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_elts != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("List field \"elts\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(elts, i_elts, ptr(item_elts));
        i_elts += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].ctx, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"ctx\" missing from List")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'List' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_ctx, val_ctx) = obj2ast_expr_context(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_ctx != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    ctx = val_ctx;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_List(elts, ctx, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Tuple(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    elts: ptr[asdl_seq] = ptr[asdl_seq]();
    ctx: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].elts, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_expr]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Tuple field \"elts\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    len_elts = object_size(tmp);
    elts = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_elts, arena));
    if not elts {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    i_elts: i64 = 0;
    while i_elts < len_elts {
        tmp2 = object_new_ref(list_get_item(tmp, i_elts));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Tuple' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_elts, item_elts) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_elts != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        if len_elts != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("Tuple field \"elts\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        asdl_seq_set(elts, i_elts, ptr(item_elts));
        i_elts += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].ctx, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"ctx\" missing from Tuple")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Tuple' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_ctx, val_ctx) = obj2ast_expr_context(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_ctx != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    ctx = val_ctx;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_Tuple(
        elts, ctx, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr_Slice(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    lower: ptr[_expr] = ptr[_expr]();
    upper: ptr[_expr] = ptr[_expr]();
    step: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lower, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        lower = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Slice' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_lower, val_lower) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_lower != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        lower = val_lower;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].upper, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        upper = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Slice' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_upper, val_upper) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_upper != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        upper = val_upper;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].step, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        step = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'Slice' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_step, val_step) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_step != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        step = val_step;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_Slice(
        lower, upper, step, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    return (i32(0), out);
}

impl obj2ast_expr(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_expr]] {
    tmp = NULL;
    lineno: i32 = 0;
    col_offset: i32 = 0;
    end_lineno: i32 = 0;
    end_col_offset: i32 = 0;
    if obj_ == Py_None {
        return (i32(0), ptr[_expr]());
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"lineno\" missing from expr")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'expr' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_lineno, val_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    lineno = val_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"col_offset\" missing from expr")
        );
        return (i32(-1), ptr[_expr]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'expr' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    (res_col_offset, val_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_expr]());
    }
    col_offset = val_col_offset;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_lineno = lineno;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'expr' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_end_lineno, val_end_lineno) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_lineno != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        end_lineno = val_end_lineno;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_expr]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_col_offset = col_offset;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'expr' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        (res_end_col_offset, val_end_col_offset) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_col_offset != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_expr]());
        }
        end_col_offset = val_end_col_offset;
        object_decref(tmp);
        tmp = NULL;
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].BoolOp_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_BoolOp(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].NamedExpr_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_NamedExpr(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].BinOp_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_BinOp(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].UnaryOp_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_UnaryOp(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Lambda_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Lambda(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].IfExp_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_IfExp(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Dict_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Dict(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Set_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Set(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].ListComp_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_ListComp(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].SetComp_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_SetComp(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].DictComp_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_DictComp(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].GeneratorExp_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_GeneratorExp(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Await_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Await(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Yield_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Yield(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].YieldFrom_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_YieldFrom(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Compare_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Compare(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Call_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Call(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].FormattedValue_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_FormattedValue(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Interpolation_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Interpolation(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].JoinedStr_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_JoinedStr(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].TemplateStr_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_TemplateStr(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Constant_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Constant(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Attribute_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Attribute(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Subscript_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Subscript(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Starred_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Starred(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Name_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Name(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].List_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_List(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Tuple_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Tuple(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Slice_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_expr]());
    }
    if isinstance_ != 0 {
        return obj2ast_expr_Slice(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of expr, but got %R"), obj_
    );
    object_xdecref(tmp);
    return (i32(-1), ptr[_expr]());
}

impl obj2ast_expr_context(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32] {
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Load_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Load);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Store_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Store);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Del_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Del);
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of expr_context, but got %R"), obj_
    );
    return (i32(-1), i32(0));
}

impl obj2ast_boolop(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32] {
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].And_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), And);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Or_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Or);
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of boolop, but got %R"), obj_
    );
    return (i32(-1), i32(0));
}

impl obj2ast_operator(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32] {
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Add_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Add);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Sub_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Sub);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Mult_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Mult);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].MatMult_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), MatMult);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Div_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Div);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Mod_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Mod);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Pow_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Pow);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].LShift_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), LShift);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].RShift_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), RShift);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].BitOr_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), BitOr);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].BitXor_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), BitXor);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].BitAnd_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), BitAnd);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].FloorDiv_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), FloorDiv);
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of operator, but got %R"), obj_
    );
    return (i32(-1), i32(0));
}

impl obj2ast_unaryop(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32] {
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Invert_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Invert);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Not_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Not);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].UAdd_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), UAdd);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].USub_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), USub);
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of unaryop, but got %R"), obj_
    );
    return (i32(-1), i32(0));
}

impl obj2ast_cmpop(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, i32] {
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Eq_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Eq);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].NotEq_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), NotEq);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Lt_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Lt);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].LtE_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), LtE);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Gt_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Gt);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].GtE_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), GtE);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].Is_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), Is);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].IsNot_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), IsNot);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].In_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), In);
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].NotIn_type);
    if isinstance_ == -1 {
        return (i32(-1), i32(0));
    }
    if isinstance_ != 0 {
        return (i32(0), NotIn);
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of cmpop, but got %R"), obj_
    );
    return (i32(-1), i32(0));
}

impl obj2ast_comprehension(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_comprehension]] {
    tmp = NULL;
    target: ptr[_expr] = ptr[_expr]();
    iter: ptr[_expr] = ptr[_expr]();
    ifs: ptr[asdl_seq] = ptr[asdl_seq]();
    is_async: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].target, &mut tmp) < 0 {
        return (i32(-1), ptr[_comprehension]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"target\" missing from comprehension")
        );
        return (i32(-1), ptr[_comprehension]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'comprehension' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_comprehension]());
    }
    (res_target, val_target) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_target != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_comprehension]());
    }
    target = val_target;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].iter, &mut tmp) < 0 {
        return (i32(-1), ptr[_comprehension]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"iter\" missing from comprehension")
        );
        return (i32(-1), ptr[_comprehension]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'comprehension' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_comprehension]());
    }
    (res_iter, val_iter) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_iter != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_comprehension]());
    }
    iter = val_iter;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].ifs, &mut tmp) < 0 {
        return (i32(-1), ptr[_comprehension]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_comprehension]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("comprehension field \"ifs\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_comprehension]());
    }
    len_ifs = object_size(tmp);
    ifs = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_ifs, arena));
    if not ifs {
        object_xdecref(tmp);
        return (i32(-1), ptr[_comprehension]());
    }
    i_ifs: i64 = 0;
    while i_ifs < len_ifs {
        tmp2 = object_new_ref(list_get_item(tmp, i_ifs));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'comprehension' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_comprehension]());
        }
        (res_ifs, item_ifs) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_ifs != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_comprehension]());
        }
        if len_ifs != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("comprehension field \"ifs\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_comprehension]());
        }
        asdl_seq_set(ifs, i_ifs, ptr(item_ifs));
        i_ifs += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].is_async, &mut tmp) < 0 {
        return (i32(-1), ptr[_comprehension]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"is_async\" missing from comprehension")
        );
        return (i32(-1), ptr[_comprehension]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'comprehension' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_comprehension]());
    }
    (res_is_async, val_is_async) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_is_async != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_comprehension]());
    }
    is_async = val_is_async;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_comprehension(target, iter, ifs, is_async, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_comprehension]());
    }
    return (i32(0), out);
}

impl obj2ast_excepthandler_ExceptHandler(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_excepthandler]] {
    tmp = NULL;
    type: ptr[_expr] = ptr[_expr]();
    name: ptr[PyObject] = NULL;
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type, &mut tmp) < 0 {
        return (i32(-1), ptr[_excepthandler]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        type = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ExceptHandler' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        (res_type, val_type) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_type != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        type = val_type;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_excepthandler]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        name = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ExceptHandler' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_name != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        name = val_name;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_excepthandler]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_excepthandler]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("ExceptHandler field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_excepthandler]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_excepthandler]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ExceptHandler' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("ExceptHandler field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_ExceptHandler(
        type, name, body, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_excepthandler]());
    }
    return (i32(0), out);
}

impl obj2ast_excepthandler(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_excepthandler]] {
    tmp = NULL;
    lineno: i32 = 0;
    col_offset: i32 = 0;
    end_lineno: i32 = 0;
    end_col_offset: i32 = 0;
    if obj_ == Py_None {
        return (i32(0), ptr[_excepthandler]());
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_excepthandler]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"lineno\" missing from excepthandler")
        );
        return (i32(-1), ptr[_excepthandler]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'excepthandler' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_excepthandler]());
    }
    (res_lineno, val_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_excepthandler]());
    }
    lineno = val_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_excepthandler]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"col_offset\" missing from excepthandler")
        );
        return (i32(-1), ptr[_excepthandler]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'excepthandler' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_excepthandler]());
    }
    (res_col_offset, val_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_excepthandler]());
    }
    col_offset = val_col_offset;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_excepthandler]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_lineno = lineno;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'excepthandler' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        (res_end_lineno, val_end_lineno) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_lineno != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        end_lineno = val_end_lineno;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_excepthandler]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_col_offset = col_offset;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'excepthandler' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        (res_end_col_offset, val_end_col_offset) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_col_offset != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_excepthandler]());
        }
        end_col_offset = val_end_col_offset;
        object_decref(tmp);
        tmp = NULL;
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].ExceptHandler_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_excepthandler]());
    }
    if isinstance_ != 0 {
        return obj2ast_excepthandler_ExceptHandler(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("expected some sort of excepthandler, but got %R"),
        obj_
    );
    object_xdecref(tmp);
    return (i32(-1), ptr[_excepthandler]());
}

impl obj2ast_arguments(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_arguments]] {
    tmp = NULL;
    posonlyargs: ptr[asdl_seq] = ptr[asdl_seq]();
    args: ptr[asdl_seq] = ptr[asdl_seq]();
    vararg: ptr[_arg] = ptr[_arg]();
    kwonlyargs: ptr[asdl_seq] = ptr[asdl_seq]();
    kw_defaults: ptr[asdl_seq] = ptr[asdl_seq]();
    kwarg: ptr[_arg] = ptr[_arg]();
    defaults: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].posonlyargs, &mut tmp) < 0 {
        return (i32(-1), ptr[_arguments]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_arguments]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("arguments field \"posonlyargs\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    len_posonlyargs = object_size(tmp);
    posonlyargs = ptr[asdl_seq](_Py_asdl_arg_seq_new(len_posonlyargs, arena));
    if not posonlyargs {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    i_posonlyargs: i64 = 0;
    while i_posonlyargs < len_posonlyargs {
        tmp2 = object_new_ref(list_get_item(tmp, i_posonlyargs));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arguments' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        (res_posonlyargs, item_posonlyargs) = obj2ast_arg(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_posonlyargs != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        if len_posonlyargs != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("arguments field \"posonlyargs\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        asdl_seq_set(posonlyargs, i_posonlyargs, ptr(item_posonlyargs));
        i_posonlyargs += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].args, &mut tmp) < 0 {
        return (i32(-1), ptr[_arguments]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_arguments]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("arguments field \"args\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    len_args = object_size(tmp);
    args = ptr[asdl_seq](_Py_asdl_arg_seq_new(len_args, arena));
    if not args {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    i_args: i64 = 0;
    while i_args < len_args {
        tmp2 = object_new_ref(list_get_item(tmp, i_args));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arguments' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        (res_args, item_args) = obj2ast_arg(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_args != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        if len_args != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("arguments field \"args\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        asdl_seq_set(args, i_args, ptr(item_args));
        i_args += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].vararg, &mut tmp) < 0 {
        return (i32(-1), ptr[_arguments]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        vararg = ptr[_arg]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arguments' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        (res_vararg, val_vararg) = obj2ast_arg(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_vararg != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        vararg = val_vararg;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].kwonlyargs, &mut tmp) < 0 {
        return (i32(-1), ptr[_arguments]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_arguments]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("arguments field \"kwonlyargs\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    len_kwonlyargs = object_size(tmp);
    kwonlyargs = ptr[asdl_seq](_Py_asdl_arg_seq_new(len_kwonlyargs, arena));
    if not kwonlyargs {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    i_kwonlyargs: i64 = 0;
    while i_kwonlyargs < len_kwonlyargs {
        tmp2 = object_new_ref(list_get_item(tmp, i_kwonlyargs));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arguments' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        (res_kwonlyargs, item_kwonlyargs) = obj2ast_arg(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_kwonlyargs != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        if len_kwonlyargs != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("arguments field \"kwonlyargs\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        asdl_seq_set(kwonlyargs, i_kwonlyargs, ptr(item_kwonlyargs));
        i_kwonlyargs += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].kw_defaults, &mut tmp) < 0 {
        return (i32(-1), ptr[_arguments]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_arguments]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("arguments field \"kw_defaults\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    len_kw_defaults = object_size(tmp);
    kw_defaults = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_kw_defaults, arena));
    if not kw_defaults {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    i_kw_defaults: i64 = 0;
    while i_kw_defaults < len_kw_defaults {
        tmp2 = object_new_ref(list_get_item(tmp, i_kw_defaults));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arguments' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        (res_kw_defaults, item_kw_defaults) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_kw_defaults != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        if len_kw_defaults != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("arguments field \"kw_defaults\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        asdl_seq_set(kw_defaults, i_kw_defaults, ptr(item_kw_defaults));
        i_kw_defaults += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].kwarg, &mut tmp) < 0 {
        return (i32(-1), ptr[_arguments]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        kwarg = ptr[_arg]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arguments' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        (res_kwarg, val_kwarg) = obj2ast_arg(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_kwarg != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        kwarg = val_kwarg;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].defaults, &mut tmp) < 0 {
        return (i32(-1), ptr[_arguments]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_arguments]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("arguments field \"defaults\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    len_defaults = object_size(tmp);
    defaults = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_defaults, arena));
    if not defaults {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    i_defaults: i64 = 0;
    while i_defaults < len_defaults {
        tmp2 = object_new_ref(list_get_item(tmp, i_defaults));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arguments' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        (res_defaults, item_defaults) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_defaults != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        if len_defaults != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("arguments field \"defaults\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_arguments]());
        }
        asdl_seq_set(defaults, i_defaults, ptr(item_defaults));
        i_defaults += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_arguments(
        posonlyargs, args, vararg, kwonlyargs, kw_defaults, kwarg, defaults, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arguments]());
    }
    return (i32(0), out);
}

impl obj2ast_arg(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_arg]] {
    tmp = NULL;
    arg: ptr[PyObject] = NULL;
    annotation: ptr[_expr] = ptr[_expr]();
    type_comment: ptr[PyObject] = NULL;
    lineno: i32 = 0;
    col_offset: i32 = 0;
    end_lineno: i32 = 0;
    end_col_offset: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].arg, &mut tmp) < 0 {
        return (i32(-1), ptr[_arg]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"arg\" missing from arg")
        );
        return (i32(-1), ptr[_arg]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arg' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arg]());
    }
    (res_arg, val_arg) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_arg != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arg]());
    }
    arg = val_arg;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].annotation, &mut tmp) < 0 {
        return (i32(-1), ptr[_arg]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        annotation = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arg' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arg]());
        }
        (res_annotation, val_annotation) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_annotation != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arg]());
        }
        annotation = val_annotation;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].type_comment, &mut tmp) < 0 {
        return (i32(-1), ptr[_arg]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        type_comment = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arg' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arg]());
        }
        (res_type_comment, val_type_comment) = obj2ast_string(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_type_comment != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arg]());
        }
        type_comment = val_type_comment;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_arg]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"lineno\" missing from arg")
        );
        return (i32(-1), ptr[_arg]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arg' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arg]());
    }
    (res_lineno, val_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arg]());
    }
    lineno = val_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_arg]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"col_offset\" missing from arg")
        );
        return (i32(-1), ptr[_arg]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arg' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arg]());
    }
    (res_col_offset, val_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arg]());
    }
    col_offset = val_col_offset;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_arg]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_lineno = lineno;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arg' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arg]());
        }
        (res_end_lineno, val_end_lineno) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_lineno != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arg]());
        }
        end_lineno = val_end_lineno;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_arg]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_col_offset = col_offset;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'arg' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arg]());
        }
        (res_end_col_offset, val_end_col_offset) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_col_offset != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_arg]());
        }
        end_col_offset = val_end_col_offset;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_arg(
        arg,
        annotation,
        type_comment,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_arg]());
    }
    return (i32(0), out);
}

impl obj2ast_keyword(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_keyword]] {
    tmp = NULL;
    arg: ptr[PyObject] = NULL;
    value: ptr[_expr] = ptr[_expr]();
    lineno: i32 = 0;
    col_offset: i32 = 0;
    end_lineno: i32 = 0;
    end_col_offset: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].arg, &mut tmp) < 0 {
        return (i32(-1), ptr[_keyword]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        arg = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'keyword' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_keyword]());
        }
        (res_arg, val_arg) = obj2ast_identifier(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_arg != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_keyword]());
        }
        arg = val_arg;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_keyword]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from keyword")
        );
        return (i32(-1), ptr[_keyword]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'keyword' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_keyword]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_keyword]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_keyword]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"lineno\" missing from keyword")
        );
        return (i32(-1), ptr[_keyword]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'keyword' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_keyword]());
    }
    (res_lineno, val_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_keyword]());
    }
    lineno = val_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_keyword]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"col_offset\" missing from keyword")
        );
        return (i32(-1), ptr[_keyword]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'keyword' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_keyword]());
    }
    (res_col_offset, val_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_keyword]());
    }
    col_offset = val_col_offset;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_keyword]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_lineno = lineno;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'keyword' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_keyword]());
        }
        (res_end_lineno, val_end_lineno) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_lineno != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_keyword]());
        }
        end_lineno = val_end_lineno;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_keyword]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_col_offset = col_offset;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'keyword' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_keyword]());
        }
        (res_end_col_offset, val_end_col_offset) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_col_offset != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_keyword]());
        }
        end_col_offset = val_end_col_offset;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_keyword(
        arg, value, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_keyword]());
    }
    return (i32(0), out);
}

impl obj2ast_alias(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_alias]] {
    tmp = NULL;
    name: ptr[PyObject] = NULL;
    asname: ptr[PyObject] = NULL;
    lineno: i32 = 0;
    col_offset: i32 = 0;
    end_lineno: i32 = 0;
    end_col_offset: i32 = 0;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_alias]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"name\" missing from alias")
        );
        return (i32(-1), ptr[_alias]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'alias' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_alias]());
    }
    (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_name != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_alias]());
    }
    name = val_name;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].asname, &mut tmp) < 0 {
        return (i32(-1), ptr[_alias]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        asname = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'alias' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_alias]());
        }
        (res_asname, val_asname) = obj2ast_identifier(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_asname != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_alias]());
        }
        asname = val_asname;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_alias]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"lineno\" missing from alias")
        );
        return (i32(-1), ptr[_alias]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'alias' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_alias]());
    }
    (res_lineno, val_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_alias]());
    }
    lineno = val_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_alias]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"col_offset\" missing from alias")
        );
        return (i32(-1), ptr[_alias]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'alias' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_alias]());
    }
    (res_col_offset, val_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_alias]());
    }
    col_offset = val_col_offset;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_alias]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_lineno = lineno;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'alias' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_alias]());
        }
        (res_end_lineno, val_end_lineno) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_lineno != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_alias]());
        }
        end_lineno = val_end_lineno;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_alias]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        end_col_offset = col_offset;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'alias' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_alias]());
        }
        (res_end_col_offset, val_end_col_offset) = obj2ast_int(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_end_col_offset != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_alias]());
        }
        end_col_offset = val_end_col_offset;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_alias(
        name, asname, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_alias]());
    }
    return (i32(0), out);
}

impl obj2ast_withitem(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_withitem]] {
    tmp = NULL;
    context_expr: ptr[_expr] = ptr[_expr]();
    optional_vars: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].context_expr, &mut tmp) < 0 {
        return (i32(-1), ptr[_withitem]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"context_expr\" missing from withitem")
        );
        return (i32(-1), ptr[_withitem]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'withitem' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_withitem]());
    }
    (res_context_expr, val_context_expr) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_context_expr != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_withitem]());
    }
    context_expr = val_context_expr;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].optional_vars, &mut tmp) < 0 {
        return (i32(-1), ptr[_withitem]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        optional_vars = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'withitem' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_withitem]());
        }
        (res_optional_vars, val_optional_vars) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_optional_vars != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_withitem]());
        }
        optional_vars = val_optional_vars;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_withitem(context_expr, optional_vars, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_withitem]());
    }
    return (i32(0), out);
}

impl obj2ast_match_case(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_match_case]] {
    tmp = NULL;
    pattern: ptr[_pattern] = ptr[_pattern]();
    guard: ptr[_expr] = ptr[_expr]();
    body: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].pattern, &mut tmp) < 0 {
        return (i32(-1), ptr[_match_case]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"pattern\" missing from match_case")
        );
        return (i32(-1), ptr[_match_case]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'match_case' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_match_case]());
    }
    (res_pattern, val_pattern) = obj2ast_pattern(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_pattern != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_match_case]());
    }
    pattern = val_pattern;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].guard, &mut tmp) < 0 {
        return (i32(-1), ptr[_match_case]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        guard = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'match_case' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_match_case]());
        }
        (res_guard, val_guard) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_guard != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_match_case]());
        }
        guard = val_guard;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].body, &mut tmp) < 0 {
        return (i32(-1), ptr[_match_case]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_match_case]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("match_case field \"body\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_match_case]());
    }
    len_body = object_size(tmp);
    body = ptr[asdl_seq](_Py_asdl_stmt_seq_new(len_body, arena));
    if not body {
        object_xdecref(tmp);
        return (i32(-1), ptr[_match_case]());
    }
    i_body: i64 = 0;
    while i_body < len_body {
        tmp2 = object_new_ref(list_get_item(tmp, i_body));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'match_case' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_match_case]());
        }
        (res_body, item_body) = obj2ast_stmt(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_body != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_match_case]());
        }
        if len_body != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("match_case field \"body\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_match_case]());
        }
        asdl_seq_set(body, i_body, ptr(item_body));
        i_body += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_match_case(pattern, guard, body, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_match_case]());
    }
    return (i32(0), out);
}

impl obj2ast_pattern_MatchValue(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]] {
    tmp = NULL;
    value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"value\" missing from MatchValue")
        );
        return (i32(-1), ptr[_pattern]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchValue' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    (res_value, val_value) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_MatchValue(
        value, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    return (i32(0), out);
}

impl obj2ast_pattern_MatchSingleton(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]] {
    tmp = NULL;
    value: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].value, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"value\" missing from MatchSingleton")
        );
        return (i32(-1), ptr[_pattern]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchSingleton' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    (res_value, val_value) = obj2ast_constant(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_value != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    value = val_value;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_MatchSingleton(
        value, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    return (i32(0), out);
}

impl obj2ast_pattern_MatchSequence(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]] {
    tmp = NULL;
    patterns: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].patterns, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_pattern]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("MatchSequence field \"patterns\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    len_patterns = object_size(tmp);
    patterns = ptr[asdl_seq](_Py_asdl_pattern_seq_new(len_patterns, arena));
    if not patterns {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    i_patterns: i64 = 0;
    while i_patterns < len_patterns {
        tmp2 = object_new_ref(list_get_item(tmp, i_patterns));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchSequence' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_patterns, item_patterns) = obj2ast_pattern(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_patterns != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        if len_patterns != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8](
                    "MatchSequence field \"patterns\" changed size during iteration"
                )
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        asdl_seq_set(patterns, i_patterns, ptr(item_patterns));
        i_patterns += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_MatchSequence(
        patterns, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    return (i32(0), out);
}

impl obj2ast_pattern_MatchMapping(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]] {
    tmp = NULL;
    keys: ptr[asdl_seq] = ptr[asdl_seq]();
    patterns: ptr[asdl_seq] = ptr[asdl_seq]();
    rest: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].keys, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_pattern]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("MatchMapping field \"keys\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    len_keys = object_size(tmp);
    keys = ptr[asdl_seq](_Py_asdl_expr_seq_new(len_keys, arena));
    if not keys {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    i_keys: i64 = 0;
    while i_keys < len_keys {
        tmp2 = object_new_ref(list_get_item(tmp, i_keys));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchMapping' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_keys, item_keys) = obj2ast_expr(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_keys != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        if len_keys != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("MatchMapping field \"keys\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        asdl_seq_set(keys, i_keys, ptr(item_keys));
        i_keys += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].patterns, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_pattern]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("MatchMapping field \"patterns\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    len_patterns = object_size(tmp);
    patterns = ptr[asdl_seq](_Py_asdl_pattern_seq_new(len_patterns, arena));
    if not patterns {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    i_patterns: i64 = 0;
    while i_patterns < len_patterns {
        tmp2 = object_new_ref(list_get_item(tmp, i_patterns));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchMapping' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_patterns, item_patterns) = obj2ast_pattern(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_patterns != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        if len_patterns != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("MatchMapping field \"patterns\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        asdl_seq_set(patterns, i_patterns, ptr(item_patterns));
        i_patterns += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].rest, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        rest = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchMapping' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_rest, val_rest) = obj2ast_identifier(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_rest != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        rest = val_rest;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_MatchMapping(
        keys, patterns, rest, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    return (i32(0), out);
}

impl obj2ast_pattern_MatchClass(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]] {
    tmp = NULL;
    cls: ptr[_expr] = ptr[_expr]();
    patterns: ptr[asdl_seq] = ptr[asdl_seq]();
    kwd_attrs: ptr[asdl_seq] = ptr[asdl_seq]();
    kwd_patterns: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].cls, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"cls\" missing from MatchClass")
        );
        return (i32(-1), ptr[_pattern]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchClass' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    (res_cls, val_cls) = obj2ast_expr(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_cls != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    cls = val_cls;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].patterns, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_pattern]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("MatchClass field \"patterns\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    len_patterns = object_size(tmp);
    patterns = ptr[asdl_seq](_Py_asdl_pattern_seq_new(len_patterns, arena));
    if not patterns {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    i_patterns: i64 = 0;
    while i_patterns < len_patterns {
        tmp2 = object_new_ref(list_get_item(tmp, i_patterns));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchClass' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_patterns, item_patterns) = obj2ast_pattern(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_patterns != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        if len_patterns != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("MatchClass field \"patterns\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        asdl_seq_set(patterns, i_patterns, ptr(item_patterns));
        i_patterns += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].kwd_attrs, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_pattern]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("MatchClass field \"kwd_attrs\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    len_kwd_attrs = object_size(tmp);
    kwd_attrs = ptr[asdl_seq](_Py_asdl_identifier_seq_new(len_kwd_attrs, arena));
    if not kwd_attrs {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    i_kwd_attrs: i64 = 0;
    while i_kwd_attrs < len_kwd_attrs {
        tmp2 = object_new_ref(list_get_item(tmp, i_kwd_attrs));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchClass' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_kwd_attrs, item_kwd_attrs) = obj2ast_identifier(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_kwd_attrs != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        if len_kwd_attrs != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("MatchClass field \"kwd_attrs\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        asdl_seq_set(kwd_attrs, i_kwd_attrs, ptr(item_kwd_attrs));
        i_kwd_attrs += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].kwd_patterns, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_pattern]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("MatchClass field \"kwd_patterns\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    len_kwd_patterns = object_size(tmp);
    kwd_patterns = ptr[asdl_seq](_Py_asdl_pattern_seq_new(len_kwd_patterns, arena));
    if not kwd_patterns {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    i_kwd_patterns: i64 = 0;
    while i_kwd_patterns < len_kwd_patterns {
        tmp2 = object_new_ref(list_get_item(tmp, i_kwd_patterns));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchClass' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_kwd_patterns, item_kwd_patterns) = obj2ast_pattern(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_kwd_patterns != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        if len_kwd_patterns != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8](
                    "MatchClass field \"kwd_patterns\" changed size during iteration"
                )
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        asdl_seq_set(kwd_patterns, i_kwd_patterns, ptr(item_kwd_patterns));
        i_kwd_patterns += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_MatchClass(
        cls,
        patterns,
        kwd_attrs,
        kwd_patterns,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    return (i32(0), out);
}

impl obj2ast_pattern_MatchStar(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]] {
    tmp = NULL;
    name: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        name = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchStar' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_name != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        name = val_name;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_MatchStar(name, lineno, col_offset, end_lineno, end_col_offset, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    return (i32(0), out);
}

impl obj2ast_pattern_MatchAs(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]] {
    tmp = NULL;
    pattern: ptr[_pattern] = ptr[_pattern]();
    name: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].pattern, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        pattern = ptr[_pattern]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchAs' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_pattern, val_pattern) = obj2ast_pattern(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_pattern != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        pattern = val_pattern;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        name = NULL;
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchAs' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_name != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        name = val_name;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_MatchAs(
        pattern, name, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    return (i32(0), out);
}

impl obj2ast_pattern_MatchOr(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_pattern]] {
    tmp = NULL;
    patterns: ptr[asdl_seq] = ptr[asdl_seq]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].patterns, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        tmp = PyList_New(0);
        if not tmp {
            return (i32(-1), ptr[_pattern]());
        }
    }
    if not list_check(tmp) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("MatchOr field \"patterns\" must be a list, not a %.200s"),
            _PyType_Name(ptr[PyObject](object_type(tmp)))
        );
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    len_patterns = object_size(tmp);
    patterns = ptr[asdl_seq](_Py_asdl_pattern_seq_new(len_patterns, arena));
    if not patterns {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    i_patterns: i64 = 0;
    while i_patterns < len_patterns {
        tmp2 = object_new_ref(list_get_item(tmp, i_patterns));
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'MatchOr' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        (res_patterns, item_patterns) = obj2ast_pattern(state, tmp2, arena);
        Py_LeaveRecursiveCall();
        object_decref(tmp2);
        if res_patterns != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        if len_patterns != object_size(tmp) {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("MatchOr field \"patterns\" changed size during iteration")
            );
            object_xdecref(tmp);
            return (i32(-1), ptr[_pattern]());
        }
        asdl_seq_set(patterns, i_patterns, ptr(item_patterns));
        i_patterns += 1;
    }
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_MatchOr(
        patterns, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    return (i32(0), out);
}

impl obj2ast_pattern(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_pattern]] {
    tmp = NULL;
    lineno: i32 = 0;
    col_offset: i32 = 0;
    end_lineno: i32 = 0;
    end_col_offset: i32 = 0;
    if obj_ == Py_None {
        return (i32(0), ptr[_pattern]());
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"lineno\" missing from pattern")
        );
        return (i32(-1), ptr[_pattern]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'pattern' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    (res_lineno, val_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    lineno = val_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"col_offset\" missing from pattern")
        );
        return (i32(-1), ptr[_pattern]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'pattern' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    (res_col_offset, val_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    col_offset = val_col_offset;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"end_lineno\" missing from pattern")
        );
        return (i32(-1), ptr[_pattern]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'pattern' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    (res_end_lineno, val_end_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_end_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    end_lineno = val_end_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_pattern]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"end_col_offset\" missing from pattern")
        );
        return (i32(-1), ptr[_pattern]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'pattern' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    (res_end_col_offset, val_end_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_end_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_pattern]());
    }
    end_col_offset = val_end_col_offset;
    object_decref(tmp);
    tmp = NULL;
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].MatchValue_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_pattern]());
    }
    if isinstance_ != 0 {
        return obj2ast_pattern_MatchValue(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].MatchSingleton_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_pattern]());
    }
    if isinstance_ != 0 {
        return obj2ast_pattern_MatchSingleton(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].MatchSequence_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_pattern]());
    }
    if isinstance_ != 0 {
        return obj2ast_pattern_MatchSequence(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].MatchMapping_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_pattern]());
    }
    if isinstance_ != 0 {
        return obj2ast_pattern_MatchMapping(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].MatchClass_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_pattern]());
    }
    if isinstance_ != 0 {
        return obj2ast_pattern_MatchClass(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].MatchStar_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_pattern]());
    }
    if isinstance_ != 0 {
        return obj2ast_pattern_MatchStar(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].MatchAs_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_pattern]());
    }
    if isinstance_ != 0 {
        return obj2ast_pattern_MatchAs(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].MatchOr_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_pattern]());
    }
    if isinstance_ != 0 {
        return obj2ast_pattern_MatchOr(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of pattern, but got %R"), obj_
    );
    object_xdecref(tmp);
    return (i32(-1), ptr[_pattern]());
}

impl obj2ast_type_ignore_TypeIgnore(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_type_ignore]] {
    tmp = NULL;
    lineno: i32 = 0;
    tag: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_ignore]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"lineno\" missing from TypeIgnore")
        );
        return (i32(-1), ptr[_type_ignore]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeIgnore' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_ignore]());
    }
    (res_lineno, val_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_ignore]());
    }
    lineno = val_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].tag, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_ignore]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"tag\" missing from TypeIgnore")
        );
        return (i32(-1), ptr[_type_ignore]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeIgnore' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_ignore]());
    }
    (res_tag, val_tag) = obj2ast_string(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_tag != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_ignore]());
    }
    tag = val_tag;
    object_decref(tmp);
    tmp = NULL;
    out = _PyAST_TypeIgnore(lineno, tag, arena);
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_ignore]());
    }
    return (i32(0), out);
}

impl obj2ast_type_ignore(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_type_ignore]] {
    tmp = NULL;
    if obj_ == Py_None {
        return (i32(0), ptr[_type_ignore]());
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].TypeIgnore_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_type_ignore]());
    }
    if isinstance_ != 0 {
        return obj2ast_type_ignore_TypeIgnore(state, obj_, arena);
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of type_ignore, but got %R"), obj_
    );
    object_xdecref(tmp);
    return (i32(-1), ptr[_type_ignore]());
}

impl obj2ast_type_param_TypeVar(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_type_param]] {
    tmp = NULL;
    name: ptr[PyObject] = NULL;
    bound: ptr[_expr] = ptr[_expr]();
    default_value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"name\" missing from TypeVar")
        );
        return (i32(-1), ptr[_type_param]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeVar' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_name != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    name = val_name;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].bound, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        bound = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeVar' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_type_param]());
        }
        (res_bound, val_bound) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_bound != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_type_param]());
        }
        bound = val_bound;
        object_decref(tmp);
        tmp = NULL;
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].default_value, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        default_value = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeVar' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_type_param]());
        }
        (res_default_value, val_default_value) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_default_value != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_type_param]());
        }
        default_value = val_default_value;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_TypeVar(
        name,
        bound,
        default_value,
        lineno,
        col_offset,
        end_lineno,
        end_col_offset,
        arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    return (i32(0), out);
}

impl obj2ast_type_param_ParamSpec(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_type_param]] {
    tmp = NULL;
    name: ptr[PyObject] = NULL;
    default_value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("required field \"name\" missing from ParamSpec")
        );
        return (i32(-1), ptr[_type_param]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ParamSpec' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_name != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    name = val_name;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].default_value, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        default_value = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'ParamSpec' node")) != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_type_param]());
        }
        (res_default_value, val_default_value) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_default_value != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_type_param]());
        }
        default_value = val_default_value;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_ParamSpec(
        name, default_value, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    return (i32(0), out);
}

impl obj2ast_type_param_TypeVarTuple(
    state: ptr[ast_state],
    obj_: ptr[PyObject],
    arena: ptr,
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) -> tuple[i32, ptr[_type_param]] {
    tmp = NULL;
    name: ptr[PyObject] = NULL;
    default_value: ptr[_expr] = ptr[_expr]();
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].name, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"name\" missing from TypeVarTuple")
        );
        return (i32(-1), ptr[_type_param]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeVarTuple' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    (res_name, val_name) = obj2ast_identifier(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_name != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    name = val_name;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].default_value, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp or tmp == Py_None {
        object_xdecref(tmp);
        tmp = NULL;
        default_value = ptr[_expr]();
    } else {
        if Py_EnterRecursiveCall(ptr[u8](" while traversing 'TypeVarTuple' node"))
            != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_type_param]());
        }
        (res_default_value, val_default_value) = obj2ast_expr(state, tmp, arena);
        Py_LeaveRecursiveCall();
        if res_default_value != 0 {
            object_xdecref(tmp);
            return (i32(-1), ptr[_type_param]());
        }
        default_value = val_default_value;
        object_decref(tmp);
        tmp = NULL;
    }
    out = _PyAST_TypeVarTuple(
        name, default_value, lineno, col_offset, end_lineno, end_col_offset, arena
    );
    if not out {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    return (i32(0), out);
}

impl obj2ast_type_param(
    state: ptr[ast_state], obj_: ptr[PyObject], arena: ptr
) -> tuple[i32, ptr[_type_param]] {
    tmp = NULL;
    lineno: i32 = 0;
    col_offset: i32 = 0;
    end_lineno: i32 = 0;
    end_col_offset: i32 = 0;
    if obj_ == Py_None {
        return (i32(0), ptr[_type_param]());
    }
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"lineno\" missing from type_param")
        );
        return (i32(-1), ptr[_type_param]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'type_param' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    (res_lineno, val_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    lineno = val_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"col_offset\" missing from type_param")
        );
        return (i32(-1), ptr[_type_param]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'type_param' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    (res_col_offset, val_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    col_offset = val_col_offset;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_lineno, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"end_lineno\" missing from type_param")
        );
        return (i32(-1), ptr[_type_param]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'type_param' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    (res_end_lineno, val_end_lineno) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_end_lineno != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    end_lineno = val_end_lineno;
    object_decref(tmp);
    tmp = NULL;
    if PyObject_GetOptionalAttr(obj_, state.view(1)[0].end_col_offset, &mut tmp) < 0 {
        return (i32(-1), ptr[_type_param]());
    }
    if not tmp {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("required field \"end_col_offset\" missing from type_param")
        );
        return (i32(-1), ptr[_type_param]());
    }
    if Py_EnterRecursiveCall(ptr[u8](" while traversing 'type_param' node")) != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    (res_end_col_offset, val_end_col_offset) = obj2ast_int(state, tmp, arena);
    Py_LeaveRecursiveCall();
    if res_end_col_offset != 0 {
        object_xdecref(tmp);
        return (i32(-1), ptr[_type_param]());
    }
    end_col_offset = val_end_col_offset;
    object_decref(tmp);
    tmp = NULL;
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].TypeVar_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_type_param]());
    }
    if isinstance_ != 0 {
        return obj2ast_type_param_TypeVar(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].ParamSpec_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_type_param]());
    }
    if isinstance_ != 0 {
        return obj2ast_type_param_ParamSpec(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    isinstance_ = PyObject_IsInstance(obj_, state.view(1)[0].TypeVarTuple_type);
    if isinstance_ == -1 {
        return (i32(-1), ptr[_type_param]());
    }
    if isinstance_ != 0 {
        return obj2ast_type_param_TypeVarTuple(
            state, obj_, arena, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    PyErr_Format(
        PyExc_TypeError, ptr[u8]("expected some sort of type_param, but got %R"), obj_
    );
    object_xdecref(tmp);
    return (i32(-1), ptr[_type_param]());
}

impl astmodule_exec(m: ptr[PyObject]) -> i32 {
    state = get_ast_state();
    if not state {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("AST"), state.view(1)[0].AST_type) < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(
        m, ptr[u8]("PyCF_ALLOW_TOP_LEVEL_AWAIT"), i64(PyCF_ALLOW_TOP_LEVEL_AWAIT)
    )
        < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(m, ptr[u8]("PyCF_ONLY_AST"), i64(PyCF_ONLY_AST)) < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(
        m, ptr[u8]("PyCF_TYPE_COMMENTS"), i64(PyCF_TYPE_COMMENTS)
    )
        < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(
        m, ptr[u8]("PyCF_OPTIMIZED_AST"), i64(PyCF_OPTIMIZED_AST)
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("mod"), state.view(1)[0].mod_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Module"), state.view(1)[0].Module_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("Interactive"), state.view(1)[0].Interactive_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Expression"), state.view(1)[0].Expression_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("FunctionType"), state.view(1)[0].FunctionType_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("stmt"), state.view(1)[0].stmt_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("FunctionDef"), state.view(1)[0].FunctionDef_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("AsyncFunctionDef"), state.view(1)[0].AsyncFunctionDef_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("ClassDef"), state.view(1)[0].ClassDef_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Return"), state.view(1)[0].Return_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Delete"), state.view(1)[0].Delete_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Assign"), state.view(1)[0].Assign_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("TypeAlias"), state.view(1)[0].TypeAlias_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("AugAssign"), state.view(1)[0].AugAssign_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("AnnAssign"), state.view(1)[0].AnnAssign_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("For"), state.view(1)[0].For_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("AsyncFor"), state.view(1)[0].AsyncFor_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("While"), state.view(1)[0].While_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("If"), state.view(1)[0].If_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("With"), state.view(1)[0].With_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("AsyncWith"), state.view(1)[0].AsyncWith_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Match"), state.view(1)[0].Match_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Raise"), state.view(1)[0].Raise_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Try"), state.view(1)[0].Try_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("TryStar"), state.view(1)[0].TryStar_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Assert"), state.view(1)[0].Assert_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Import"), state.view(1)[0].Import_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("ImportFrom"), state.view(1)[0].ImportFrom_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Global"), state.view(1)[0].Global_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Nonlocal"), state.view(1)[0].Nonlocal_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Expr"), state.view(1)[0].Expr_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Pass"), state.view(1)[0].Pass_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Break"), state.view(1)[0].Break_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Continue"), state.view(1)[0].Continue_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("expr"), state.view(1)[0].expr_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("BoolOp"), state.view(1)[0].BoolOp_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("NamedExpr"), state.view(1)[0].NamedExpr_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("BinOp"), state.view(1)[0].BinOp_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("UnaryOp"), state.view(1)[0].UnaryOp_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Lambda"), state.view(1)[0].Lambda_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("IfExp"), state.view(1)[0].IfExp_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Dict"), state.view(1)[0].Dict_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Set"), state.view(1)[0].Set_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("ListComp"), state.view(1)[0].ListComp_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("SetComp"), state.view(1)[0].SetComp_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("DictComp"), state.view(1)[0].DictComp_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("GeneratorExp"), state.view(1)[0].GeneratorExp_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Await"), state.view(1)[0].Await_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Yield"), state.view(1)[0].Yield_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("YieldFrom"), state.view(1)[0].YieldFrom_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Compare"), state.view(1)[0].Compare_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Call"), state.view(1)[0].Call_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("FormattedValue"), state.view(1)[0].FormattedValue_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("Interpolation"), state.view(1)[0].Interpolation_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("JoinedStr"), state.view(1)[0].JoinedStr_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("TemplateStr"), state.view(1)[0].TemplateStr_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Constant"), state.view(1)[0].Constant_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Attribute"), state.view(1)[0].Attribute_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Subscript"), state.view(1)[0].Subscript_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Starred"), state.view(1)[0].Starred_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Name"), state.view(1)[0].Name_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("List"), state.view(1)[0].List_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Tuple"), state.view(1)[0].Tuple_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Slice"), state.view(1)[0].Slice_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("expr_context"), state.view(1)[0].expr_context_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Load"), state.view(1)[0].Load_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Store"), state.view(1)[0].Store_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Del"), state.view(1)[0].Del_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("boolop"), state.view(1)[0].boolop_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("And"), state.view(1)[0].And_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Or"), state.view(1)[0].Or_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("operator"), state.view(1)[0].operator_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Add"), state.view(1)[0].Add_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Sub"), state.view(1)[0].Sub_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Mult"), state.view(1)[0].Mult_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("MatMult"), state.view(1)[0].MatMult_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Div"), state.view(1)[0].Div_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Mod"), state.view(1)[0].Mod_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Pow"), state.view(1)[0].Pow_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("LShift"), state.view(1)[0].LShift_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("RShift"), state.view(1)[0].RShift_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("BitOr"), state.view(1)[0].BitOr_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("BitXor"), state.view(1)[0].BitXor_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("BitAnd"), state.view(1)[0].BitAnd_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("FloorDiv"), state.view(1)[0].FloorDiv_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("unaryop"), state.view(1)[0].unaryop_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Invert"), state.view(1)[0].Invert_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Not"), state.view(1)[0].Not_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("UAdd"), state.view(1)[0].UAdd_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("USub"), state.view(1)[0].USub_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("cmpop"), state.view(1)[0].cmpop_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Eq"), state.view(1)[0].Eq_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("NotEq"), state.view(1)[0].NotEq_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Lt"), state.view(1)[0].Lt_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("LtE"), state.view(1)[0].LtE_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Gt"), state.view(1)[0].Gt_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("GtE"), state.view(1)[0].GtE_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("Is"), state.view(1)[0].Is_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("IsNot"), state.view(1)[0].IsNot_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("In"), state.view(1)[0].In_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("NotIn"), state.view(1)[0].NotIn_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("comprehension"), state.view(1)[0].comprehension_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("excepthandler"), state.view(1)[0].excepthandler_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("ExceptHandler"), state.view(1)[0].ExceptHandler_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("arguments"), state.view(1)[0].arguments_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("arg"), state.view(1)[0].arg_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("keyword"), state.view(1)[0].keyword_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("alias"), state.view(1)[0].alias_type) < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("withitem"), state.view(1)[0].withitem_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("match_case"), state.view(1)[0].match_case_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("pattern"), state.view(1)[0].pattern_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("MatchValue"), state.view(1)[0].MatchValue_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("MatchSingleton"), state.view(1)[0].MatchSingleton_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("MatchSequence"), state.view(1)[0].MatchSequence_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("MatchMapping"), state.view(1)[0].MatchMapping_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("MatchClass"), state.view(1)[0].MatchClass_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("MatchStar"), state.view(1)[0].MatchStar_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("MatchAs"), state.view(1)[0].MatchAs_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("MatchOr"), state.view(1)[0].MatchOr_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("type_ignore"), state.view(1)[0].type_ignore_type
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("TypeIgnore"), state.view(1)[0].TypeIgnore_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("type_param"), state.view(1)[0].type_param_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("TypeVar"), state.view(1)[0].TypeVar_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(m, ptr[u8]("ParamSpec"), state.view(1)[0].ParamSpec_type)
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("TypeVarTuple"), state.view(1)[0].TypeVarTuple_type
    )
        < 0 {
        return -1;
    }
    return 0;
}
