# Code generation for the JacPython compiler: a port of CPython 3.14's
# Python/codegen.c (AST to pseudo-instruction sequence) and the
# _PyAST_Compile driver of Python/compile.c. Bodies live in the annexes
# impl/cpy_codegen.{stmt,expr,defs,comp,match}.impl.jac.

glob CG_LOAD: int = 1,
     CG_STORE: int = 2,
     CG_DEL: int = 3;

glob CG_NAMES: int = 0,
     CG_VARNAMES: int = 1,
     CG_CELLVARS: int = 2,
     CG_FREEVARS: int = 3;

glob CG_LOAD_METHOD: int = -1,
     CG_LOAD_SUPER_METHOD: int = -2,
     CG_LOAD_ZERO_SUPER_ATTR: int = -3,
     CG_LOAD_ZERO_SUPER_METHOD: int = -4;

glob COMP_GENEXP: int = 0,
     COMP_LISTCOMP: int = 1,
     COMP_SETCOMP: int = 2,
     COMP_DICTCOMP: int = 3;

glob STACK_USE_GUIDELINE: int = 30,
     ANNOTATE_FORMAT_VALUE_WITH_FAKE_GLOBALS: int = 2;

glob INTRINSIC_PRINT: int = 1,
     INTRINSIC_IMPORT_STAR: int = 2,
     INTRINSIC_STOPITERATION_ERROR: int = 3,
     INTRINSIC_ASYNC_GEN_WRAP: int = 4,
     INTRINSIC_UNARY_POSITIVE: int = 5,
     INTRINSIC_LIST_TO_TUPLE: int = 6,
     INTRINSIC_TYPEVAR: int = 7,
     INTRINSIC_PARAMSPEC: int = 8,
     INTRINSIC_TYPEVARTUPLE: int = 9,
     INTRINSIC_SUBSCRIPT_GENERIC: int = 10,
     INTRINSIC_TYPEALIAS: int = 11,
     INTRINSIC_PREP_RERAISE_STAR: int = 1,
     INTRINSIC_TYPEVAR_WITH_BOUND: int = 2,
     INTRINSIC_TYPEVAR_WITH_CONSTRAINTS: int = 3,
     INTRINSIC_SET_FUNCTION_TYPE_PARAMS: int = 4,
     INTRINSIC_SET_TYPEPARAM_DEFAULT: int = 5;

glob CONSTANT_ASSERTIONERROR: int = 0,
     CONSTANT_NOTIMPLEMENTEDERROR: int = 1,
     CONSTANT_BUILTIN_TUPLE: int = 2,
     CONSTANT_BUILTIN_ALL: int = 3,
     CONSTANT_BUILTIN_ANY: int = 4;

glob SPECIAL___ENTER__: int = 0,
     SPECIAL___EXIT__: int = 1,
     SPECIAL___AENTER__: int = 2,
     SPECIAL___AEXIT__: int = 3;

glob MAKE_FUNCTION_DEFAULTS: int = 1,
     MAKE_FUNCTION_KWDEFAULTS: int = 2,
     MAKE_FUNCTION_ANNOTATIONS: int = 4,
     MAKE_FUNCTION_CLOSURE: int = 8,
     MAKE_FUNCTION_ANNOTATE: int = 16;

glob FVC_STR: int = 1,
     FVC_REPR: int = 2,
     FVC_ASCII: int = 3;

glob RESUME_AT_FUNC_START: int = 0,
     RESUME_AFTER_YIELD: int = 1,
     RESUME_AFTER_YIELD_FROM: int = 2,
     RESUME_AFTER_AWAIT: int = 3;

obj cpy_pattern_context {
    has stores: list[str],
        fail_pop: list[int],
        allow_irrefutable: bool = False,
        on_top: int = 0;
}

def cpy_ast_compile(m: mod, filename: str, flags: int, optimize: int) -> PyCode;

def cg_addop(c: cpy_compiler, opcode: int, loc: srcloc);
def cg_addop_i(c: cpy_compiler, opcode: int, oparg: int, loc: srcloc);
def cg_addop_j(c: cpy_compiler, opcode: int, target: int, loc: srcloc);
def cg_new_label(c: cpy_compiler) -> int;
def cg_use_label(c: cpy_compiler, lbl: int);
def cg_load_const(c: cpy_compiler, o: PyObj, loc: srcloc);
def cg_load_none(c: cpy_compiler, loc: srcloc);
def cg_load_int(c: cpy_compiler, value: int, loc: srcloc);
def cg_load_str(c: cpy_compiler, value: str, loc: srcloc);
def cg_dict_add(c: cpy_compiler, kind: int, name: str) -> int;
def cg_addop_n(c: cpy_compiler, loc: srcloc, opcode: int, kind: int, name: str);
def cg_addop_name(c: cpy_compiler, loc: srcloc, opcode: int, kind: int, name: str);
def cg_call_exit_with_nones(c: cpy_compiler, loc: srcloc);
def cg_add_yield_from(c: cpy_compiler, loc: srcloc, await_: bool);
def cg_pop_except_and_reraise(c: cpy_compiler, loc: srcloc);
def cg_unwind_fblock(
    c: cpy_compiler, loc: srcloc, info: cpy_fblock, preserve_tos: bool
) -> srcloc;

def cg_unwind_fblock_stack(
    c: cpy_compiler, loc: srcloc, preserve_tos: bool, want_loop: bool
) -> tuple[srcloc, cpy_fblock | None];

def cg_enter_scope(
    c: cpy_compiler,
    name: str,
    scope_type: int,
    key: int,
    lineno: int,
    private: str | None,
    argcount: int,
    posonlyargcount: int,
    kwonlyargcount: int
);

def cg_setup_annotations_scope(c: cpy_compiler, loc: srcloc, key: int, name: str);
def cg_leave_annotations_scope(c: cpy_compiler, loc: srcloc);
def cg_deferred_annotations_body(
    c: cpy_compiler,
    loc: srcloc,
    deferred: list[AnnAssign],
    indices: list[int],
    scope_type: int
);

def cg_process_deferred_annotations(c: cpy_compiler, loc: srcloc);
def cg_module(c: cpy_compiler, loc: srcloc, stmts: list[stmt], is_interactive: bool);
def cg_body(c: cpy_compiler, loc: srcloc, stmts: list[stmt], is_interactive: bool);
def cg_make_closure(c: cpy_compiler, loc: srcloc, co: PyCode, flags: int);
def cg_decorators(c: cpy_compiler, decos: list[expr]);
def cg_apply_decorators(c: cpy_compiler, decos: list[expr]);
def cg_visit_stmts(c: cpy_compiler, stmts: list[stmt]);
def cg_if(c: cpy_compiler, s: If);
def cg_for(c: cpy_compiler, s: For);
def cg_async_for(c: cpy_compiler, s: AsyncFor);
def cg_while(c: cpy_compiler, s: While);
def cg_return(c: cpy_compiler, s: Return);
def cg_break(c: cpy_compiler, loc: srcloc);
def cg_continue(c: cpy_compiler, loc: srcloc);
def cg_try_finally(c: cpy_compiler, s: Try);
def cg_try_star_finally(c: cpy_compiler, s: TryStar);
def cg_try_except(c: cpy_compiler, s: Try);
def cg_try_star_except(c: cpy_compiler, s: TryStar);
def cg_try(c: cpy_compiler, s: Try);
def cg_try_star(c: cpy_compiler, s: TryStar);
def cg_import_as(c: cpy_compiler, loc: srcloc, name: str, asname: str);
def cg_import(c: cpy_compiler, s: Import);
def cg_from_import(c: cpy_compiler, s: ImportFrom);
def cg_assert(c: cpy_compiler, s: Assert);
def cg_stmt_expr(c: cpy_compiler, loc: srcloc, value: expr);
def cg_visit_stmt(c: cpy_compiler, s: stmt);
def cg_with_except_finish(c: cpy_compiler, cleanup: int);
def cg_async_with_inner(c: cpy_compiler, s: AsyncWith, pos: int);
def cg_with_inner(c: cpy_compiler, s: With, pos: int);
def cg_unit_conditional(c: cpy_compiler, delta: int);
def cg_start_location(stmts: list[stmt]) -> srcloc;
def cg_compiler_codegen(c: cpy_compiler, m: mod);
def cg_ctx(ctx: expr_context) -> int;
def cg_is_const_tuple(elts: list[expr]) -> bool;
def cg_check_is_arg(e: expr) -> bool;
def cg_const_type_name(value: PyObj) -> str;
def cg_infer_type(e: expr) -> str | None;
def cg_check_compare(c: cpy_compiler, e: Compare);
def cg_addcompare(c: cpy_compiler, loc: srcloc, op: cmpop);
def cg_jump_if(c: cpy_compiler, loc: srcloc, e: expr, next: int, cond: bool);
def cg_ifexp(c: cpy_compiler, e: IfExp);
def cg_addop_yield(c: cpy_compiler, loc: srcloc);
def cg_load_classdict_freevar(c: cpy_compiler, loc: srcloc);
def cg_nameop(c: cpy_compiler, loc: srcloc, name: str, ctx: int);
def cg_boolop(c: cpy_compiler, e: BoolOp);
def cg_starunpack_helper(
    c: cpy_compiler,
    loc: srcloc,
    elts: list[expr],
    injected_arg: str | None,
    pushed: int,
    build: int,
    add: int,
    extend: int,
    tuple_: bool
);

def cg_unpack_helper(c: cpy_compiler, loc: srcloc, elts: list[expr]);
def cg_assignment_helper(c: cpy_compiler, loc: srcloc, elts: list[expr]);
def cg_list(c: cpy_compiler, e: List);
def cg_tuple(c: cpy_compiler, e: Tuple);
def cg_set(c: cpy_compiler, e: Set);
def cg_subdict(c: cpy_compiler, e: Dict, begin: int, end: int);
def cg_dict(c: cpy_compiler, e: Dict);
def cg_compare(c: cpy_compiler, e: Compare);
def cg_check_caller(c: cpy_compiler, e: expr);
def cg_check_subscripter(c: cpy_compiler, e: expr);
def cg_check_index(c: cpy_compiler, e: expr, s: expr);
def cg_is_import_originated(c: cpy_compiler, e: expr) -> bool;
def cg_can_optimize_super_call(c: cpy_compiler, attr: Attribute) -> bool;
def cg_load_args_for_super(c: cpy_compiler, e: Call);
def cg_update_start_location_to_match_attr(
    c: cpy_compiler, loc: srcloc, attr: Attribute
) -> srcloc;

def cg_maybe_optimize_function_call(c: cpy_compiler, e: Call, end: int) -> bool;
def cg_maybe_optimize_method_call(c: cpy_compiler, e: Call) -> bool;
def cg_validate_keywords(c: cpy_compiler, keywords: list[keyword]);
def cg_call(c: cpy_compiler, e: Call);
def cg_template_str(c: cpy_compiler, e: TemplateStr);
def cg_joined_str(c: cpy_compiler, e: JoinedStr);
def cg_conversion_oparg(conversion: int) -> int;
def cg_interpolation(c: cpy_compiler, e: Interpolation);
def cg_formatted_value(c: cpy_compiler, e: FormattedValue);
def cg_subkwargs(
    c: cpy_compiler, loc: srcloc, keywords: list[keyword], begin: int, end: int
);

def cg_call_simple_kw_helper(
    c: cpy_compiler, loc: srcloc, keywords: list[keyword], nkwelts: int
);

def cg_call_helper(
    c: cpy_compiler,
    loc: srcloc,
    n: int,
    args: list[expr],
    injected_arg: str | None,
    keywords: list[keyword]
);

def cg_binop_oparg(op: operator, inplace: bool) -> int;
def cg_visit_expr(c: cpy_compiler, e: expr);
def cg_attribute(c: cpy_compiler, e: Attribute, loc: srcloc);
def cg_is_constant_slice(s: expr) -> bool;
def cg_should_apply_two_element_slice_optimization(s: expr) -> bool;
def cg_augassign(c: cpy_compiler, s: AugAssign);
def cg_check_ann_expr(c: cpy_compiler, e: expr);
def cg_check_annotation(c: cpy_compiler, s: AnnAssign);
def cg_check_ann_subscr(c: cpy_compiler, e: expr);
def cg_annassign(c: cpy_compiler, s: AnnAssign);
def cg_subscript(c: cpy_compiler, e: Subscript);
def cg_slice_two_parts(c: cpy_compiler, s: Slice);
def cg_slice_part(part: expr | None) -> PyObj;
def cg_slice(c: cpy_compiler, s: Slice);
def cg_kwonlydefaults(
    c: cpy_compiler, loc: srcloc, kwonlyargs: list[arg], kw_defaults: list[expr | None]
) -> bool;

def cg_argannotation(
    c: cpy_compiler, name: str, annotation: expr | None, loc: srcloc
) -> int;

def cg_argannotations(c: cpy_compiler, args: list[arg], loc: srcloc) -> int;
def cg_annotations_in_scope(
    c: cpy_compiler, loc: srcloc, args: arguments, returns: expr | None
) -> int;

def cg_function_annotations(
    c: cpy_compiler, loc: srcloc, args: arguments, returns: expr | None
) -> int;

def cg_default_arguments(c: cpy_compiler, loc: srcloc, args: arguments) -> int;
def cg_wrap_in_stopiteration_handler(c: cpy_compiler);
def cg_type_param_bound_or_default(
    c: cpy_compiler, e: expr, name: str, key: int, allow_starred: bool
);

def cg_type_params(c: cpy_compiler, type_params: list[type_param]);
def cg_function_body(
    c: cpy_compiler,
    s: stmt,
    is_async: bool,
    name: str,
    args: arguments,
    body: list[stmt],
    funcflags: int,
    firstlineno: int
);

def cg_function(c: cpy_compiler, s: FunctionDef);
def cg_async_function(c: cpy_compiler, s: AsyncFunctionDef);
def cg_function_impl(
    c: cpy_compiler,
    s: stmt,
    is_async: bool,
    args: arguments,
    returns: expr | None,
    decos: list[expr],
    name: str,
    type_params: list[type_param],
    body: list[stmt]
);

def cg_set_type_params_in_class(c: cpy_compiler, loc: srcloc);
def cg_class_body(c: cpy_compiler, s: ClassDef, firstlineno: int);
def cg_class(c: cpy_compiler, s: ClassDef);
def cg_typealias_body(c: cpy_compiler, s: TypeAlias);
def cg_typealias(c: cpy_compiler, s: TypeAlias);
def cg_lambda(c: cpy_compiler, e: Lambda);
def cg_comprehension_generator(
    c: cpy_compiler,
    loc: srcloc,
    generators: list[comprehension],
    gen_index: int,
    depth: int,
    elt: expr,
    val: expr | None,
    comp_type: int,
    iter_on_stack: bool
);

def cg_comprehension_element(
    c: cpy_compiler, elt: expr, val: expr | None, comp_type: int, depth: int
) -> srcloc;

def cg_sync_comprehension_generator(
    c: cpy_compiler,
    loc: srcloc,
    generators: list[comprehension],
    gen_index: int,
    depth: int,
    elt: expr,
    val: expr | None,
    comp_type: int,
    iter_on_stack: bool
);

def cg_async_comprehension_generator(
    c: cpy_compiler,
    loc: srcloc,
    generators: list[comprehension],
    gen_index: int,
    depth: int,
    elt: expr,
    val: expr | None,
    comp_type: int,
    iter_on_stack: bool
);

def cg_push_inlined_comprehension_locals(
    c: cpy_compiler, loc: srcloc, comp: cpy_ste, state: cpy_inline_state
);

def cg_restore_inlined_comprehension_locals(
    c: cpy_compiler, loc: srcloc, state: cpy_inline_state
);

def cg_pop_inlined_comprehension_locals(
    c: cpy_compiler, loc: srcloc, state: cpy_inline_state
);

def cg_comprehension_iter(c: cpy_compiler, comp: comprehension);
def cg_comprehension(
    c: cpy_compiler,
    e: expr,
    comp_type: int,
    name: str,
    generators: list[comprehension],
    elt: expr,
    val: expr | None
);

def cg_wildcard_check(p: pattern) -> bool;
def cg_wildcard_star_check(p: pattern) -> bool;
def cg_ensure_fail_pop(c: cpy_compiler, pc: cpy_pattern_context, n: int);
def cg_jump_to_fail_pop(
    c: cpy_compiler, loc: srcloc, pc: cpy_pattern_context, op: int
);

def cg_emit_and_reset_fail_pop(c: cpy_compiler, loc: srcloc, pc: cpy_pattern_context);
def cg_error_duplicate_store(c: cpy_compiler, loc: srcloc, n: str);
def cg_pattern_helper_rotate(c: cpy_compiler, loc: srcloc, count: int);
def cg_pattern_helper_store_name(
    c: cpy_compiler, loc: srcloc, n: str | None, pc: cpy_pattern_context
);

def cg_pattern_unpack_helper(c: cpy_compiler, loc: srcloc, elts: list[pattern]);
def cg_pattern_helper_sequence_unpack(
    c: cpy_compiler,
    loc: srcloc,
    patterns: list[pattern],
    star: int,
    pc: cpy_pattern_context
);

def cg_pattern_helper_sequence_subscr(
    c: cpy_compiler,
    loc: srcloc,
    patterns: list[pattern],
    star: int,
    pc: cpy_pattern_context
);

def cg_pattern_subpattern(c: cpy_compiler, p: pattern, pc: cpy_pattern_context);
def cg_pattern_as(c: cpy_compiler, p: MatchAs, pc: cpy_pattern_context);
def cg_pattern_star(c: cpy_compiler, p: MatchStar, pc: cpy_pattern_context);
def cg_validate_kwd_attrs(c: cpy_compiler, attrs: list[str], patterns: list[pattern]);
def cg_pattern_class(c: cpy_compiler, p: MatchClass, pc: cpy_pattern_context);
def cg_mapping_key_identity(value: PyObj) -> str;
def cg_const_repr(value: PyObj) -> str;
def cg_float_repr_short(v: float) -> str;
def cg_pattern_mapping_key(c: cpy_compiler, seen: set[str], p: MatchMapping, i: int);
def cg_pattern_mapping(c: cpy_compiler, p: MatchMapping, pc: cpy_pattern_context);
def cg_pattern_or(c: cpy_compiler, p: MatchOr, pc: cpy_pattern_context);
def cg_pattern_sequence(c: cpy_compiler, p: MatchSequence, pc: cpy_pattern_context);
def cg_pattern_value(c: cpy_compiler, p: MatchValue, pc: cpy_pattern_context);
def cg_pattern_singleton(c: cpy_compiler, p: MatchSingleton, pc: cpy_pattern_context);
def cg_pattern(c: cpy_compiler, p: pattern, pc: cpy_pattern_context);
def cg_match(c: cpy_compiler, s: Match);
