# Definition and import codegen (class/function defs, import statements)
# extracted from compiler_codegen.jac. Pure mechanical move; see
# compiler_codegen.jac for the module-initialization ordering contract.

import from jaclang.runtime.python.objects {
    PyCode,
    PyInt,
    PyObj,
    PyStr,
    PyTuple,
    py_none,
}
import from jaclang.runtime.python.opcode_meta {
    CO_ASYNC_GENERATOR,
    CO_COROUTINE,
    CO_GENERATOR,
    CO_HAS_DOCSTRING,
    CO_NESTED,
    CO_NEWLOCALS,
    CO_OPTIMIZED,
    CMP_GT,
    OP_CALL,
    OP_CALL_INTRINSIC_1,
    OP_CALL_INTRINSIC_2,
    OP_UNPACK_SEQUENCE,
    OP_CALL_KW,
    OP_COMPARE_OP,
    OP_BUILD_TUPLE,
    OP_COPY,
    OP_COPY_FREE_VARS,
    OP_IMPORT_FROM,
    OP_IMPORT_NAME,
    OP_LOAD_BUILD_CLASS,
    OP_LOAD_COMMON_CONSTANT,
    OP_LOAD_CONST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_LOCALS,
    OP_LOAD_NAME,
    OP_MAKE_CELL,
    OP_MAKE_FUNCTION,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_TOP,
    OP_PUSH_NULL,
    OP_RAISE_VARARGS,
    OP_RESUME,
    OP_RETURN_VALUE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_LOAD_SMALL_INT,
    OP_STORE_DEREF,
    OP_STORE_FAST,
    OP_STORE_NAME,
    OP_SWAP,
    compare_oparg,
}
import from jaclang.compiler.frontend.python.ast_nodes {
    AsyncFunctionDef,
    ClassDef,
    Call,
    Dict,
    Constant,
    Load,
    FunctionDef,
    Import,
    ImportFrom,
    Name,
    TypeAlias,
    TypeVar,
    Tuple,
    Starred,
    expr,
    TypeVarTuple,
    ParamSpec,
    type_param,
    arguments,
    keyword,
    stmt,
}
import from jaclang.compiler.backends.py.jacpython.compiler_ir {
    cfg_builder,
    cloc,
    loc,
    new_cfg_builder,
    no_loc,
    stmt_cont,
    unverified_cfg,
}
import from jaclang.compiler.frontend.python.compiler_symtable { sym_block }
import from jaclang.compiler.backends.py.jacpython.flowgraph { verify_cfg }
import from jaclang.compiler.backends.py.jacpython.assembler { assemble }
import from jaclang.compiler.backends.py.jacpython.compiler_emit {
    cellvars_from_sym,
    call_has_unpacking,
    emit_call_ex_positional,
    emit_call_keyword_values,
    emit_call_instruction,
    emit_function_defaults,
    emit_function_kwdefaults,
    emit_name_load,
    codegen_busy,
    flush_pending_await_footers,
    codegen_fail,
    emit_folded_int,
    emit_function_prologue,
    emit_local_or_cell_store,
    emit_make_function_with_closure,
    codegen_mangle,
    fast_local_index,
    fast_varnames_from_sym,
    inline_storage_names,
    freevars_from_sym,
    localsplus_index,
    localsplus_index_u,
    sym_function_child_at,
    visit_expr,
}
import from jaclang.compiler.backends.py.jacpython.codegen_util {
    body_docstring,
    stmt_loc,
    async_function_def_loc,
    class_effective_bases,
    class_effective_keywords,
    exec_tail_emits_code,
    expr_loc,
    function_argcounts,
    function_code_flags,
    function_def_loc,
    import_bind_name,
    nested_code_qualname,
    nloc,
}
import from jaclang.compiler.backends.py.jacpython.compiler_codegen {
    emit_name_store,
    visit_stmt
}
import from jaclang.compiler.backends.py.jacpython.compiler_dispatch { stmt_handlers }
import from jaclang.compiler.backends.py.jacpython.compiler_exc {
    emit_generator_except_handler,
    emit_deferred_comp_handlers
}
import from jaclang.compiler.backends.py.jacpython.compiler_annotations {
    collect_ann_plan_class,
    emit_class_annotation_setup,
    emit_future_function_annotations,
    finish_class_annotations
}

def sym_class_child_at(
    parent: sym_block, class_name: str, lineno: int, col_offset: int
) -> sym_block | None {
    ci = 0;
    while ci < len(parent.children) {
        ch = parent.children[ci];
        if ch.block_type == "class"
            and ch.name == class_name
            and ch.lineno == lineno
            and ch.col_offset == col_offset {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}

def sym_class_child(parent: sym_block, class_name: str) -> sym_block | None {
    ci = 0;
    while ci < len(parent.children) {
        ch = parent.children[ci];
        if ch.block_type == "class" and ch.name == class_name {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}


def sym_function_child(parent: sym_block, fn_name: str) -> sym_block | None {
    ci = 0;
    while ci < len(parent.children) {
        ch = parent.children[ci];
        if ch.block_type == "function"
            and ch.annotation_kind != "an annotation"
            and ch.name == fn_name {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}


# CPython's import prefix keeps int 0 in co_consts even though level uses
# LOAD_SMALL_INT (same dead-small-int slot as literal folding).
def ensure_import_prefix_consts(g: cfg_builder) {
    # Same dead-small-int rule: 0 is kept only at const index 0 (pool empty).
    if len(g.u.consts) == 0 {
        g.u.add_const(PyInt(t="int", val=0));
        g.u.dead_small_int_const = True;
    }
}


# LOAD_SMALL_INT level, LOAD_CONST fromlist, IMPORT_NAME modname (CPython import).
def emit_import_name_call(
    g: cfg_builder, modname: str, level: int, fromlist: PyObj | None, iloc: cloc
) {
    ensure_import_prefix_consts(g);
    emit_folded_int(g, level, iloc);
    if fromlist is None {
        none_idx = g.u.add_const(py_none());
        g.emit_op(OP_LOAD_CONST, none_idx, iloc);
    } else {
        fl_idx = g.u.add_const(fromlist);
        g.emit_op(OP_LOAD_CONST, fl_idx, iloc);
    }
    midx = g.u.add_name(modname);
    g.emit_op(OP_IMPORT_NAME, midx, iloc);
}


def visit_import(g: cfg_builder, imp: Import) -> stmt_cont {
    iloc = nloc(imp.lineno, imp.end_lineno, imp.col_offset, imp.end_col_offset);
    ni = 0;
    while ni < len(imp.names) {
        a = imp.names[ni];
        emit_import_name_call(g, a.name, 0, None, iloc);
        parts = a.name.split(".");
        if a.asname is not None and len(parts) > 1 {
            for (index, part) in enumerate(parts[1:]) {
                g.emit_op(OP_IMPORT_FROM, g.u.add_name(part), iloc);
                if index < len(parts) - 2 {
                    g.emit_op(OP_SWAP, 2, iloc);
                    g.emit_op(OP_POP_TOP, 0, iloc);
                }
            }
        }
        emit_name_store(g, import_bind_name(a), iloc);
        if a.asname is not None and len(parts) > 1 {
            g.emit_op(OP_POP_TOP, 0, iloc);
        }
        ni = ni + 1;
    }
    return stmt_cont(loc=iloc);
}


def visit_import_from(g: cfg_builder, imp: ImportFrom) -> stmt_cont {
    iloc = nloc(imp.lineno, imp.end_lineno, imp.col_offset, imp.end_col_offset);
    level = 0;
    if imp.level is not None {
        level = imp.level;
    }
    modname = "";
    if imp.module is not None {
        modname = imp.module;
    }
    names: list[PyObj] = [];
    ni = 0;
    while ni < len(imp.names) {
        names.append(PyStr(t="str", val=imp.names[ni].name));
        ni = ni + 1;
    }
    fromlist = PyTuple(t="tuple", items=names);
    emit_import_name_call(g, modname, level, fromlist, iloc);
    if len(imp.names) == 1 and imp.names[0].name == "*" {
        # `from M import *` lowers to CALL_INTRINSIC_1 INTRINSIC_IMPORT_STAR
        # (oparg 2) + POP_TOP in CPython 3.14 -- IMPORT_FROM is never emitted
        # with name '*'. The intrinsic pops the module and pushes None.
        g.emit_op(OP_CALL_INTRINSIC_1, 2, iloc);
        g.emit_op(OP_POP_TOP, 0, iloc);
        return stmt_cont(loc=iloc);
    }
    ni = 0;
    while ni < len(imp.names) {
        a = imp.names[ni];
        fidx = g.u.add_name(a.name);
        g.emit_op(OP_IMPORT_FROM, fidx, iloc);
        emit_name_store(g, import_bind_name(a), iloc);
        ni = ni + 1;
    }
    g.emit_op(OP_POP_TOP, 0, iloc);
    return stmt_cont(loc=iloc);
}


def sym_class_qualname(
    cd: ClassDef, sym_cls: sym_block, enclosing_private: str | None
) -> str {
    if sym_cls.nested and enclosing_private is not None {
        return enclosing_private + "." + cd.name;
    }
    return cd.name;
}


# The body function and class name are already on the stack. Reuse ordinary
# call lowering, including ordered *bases and **keywords merging.
def emit_class_build_call(
    g: cfg_builder, cd: ClassDef, cloc: cloc, generic: bool = False
) {
    call = Call(
        func=Name(
            id=cd.name,
            ctx=Load(),
            lineno=cd.lineno,
            col_offset=cd.col_offset,
            end_lineno=cd.end_lineno,
            end_col_offset=cd.end_col_offset
        ),
        args=list(class_effective_bases(cd)),
        keywords=class_effective_keywords(cd),
        lineno=cd.lineno,
        col_offset=cd.col_offset,
        end_lineno=cd.end_lineno,
        end_col_offset=cd.end_col_offset
    );
    if generic {
        call.args.append(
            Name(
                id=".generic_base",
                ctx=Load(),
                lineno=cd.lineno,
                col_offset=cd.col_offset,
                end_lineno=cd.end_lineno,
                end_col_offset=cd.end_col_offset
            )
        );
    }
    if call_has_unpacking(call) {
        emit_call_ex_positional(g, call, cloc, False, 2);
    } else {
        for base in call.args {
            visit_expr(g, base, False, False);
            if codegen_busy(g) {
                return;
            }
        }
    }
    if codegen_busy(g) {
        return;
    }
    emit_call_keyword_values(g, call, cloc, False, False);
    if not codegen_busy(g) {
        emit_call_instruction(g, call, cloc, 2);
    }
}

# A direct type alias in the body closes over __classdict__, forcing the
# classdict cell even with no functions/annotations present.
def class_body_has_typealias(cd: ClassDef) -> bool {
    bi = 0;
    while bi < len(cd.body) {
        if isinstance(cd.body[bi], TypeAlias) {
            return True;
        }
        bi = bi + 1;
    }
    return False;
}


# Class body boilerplate through __firstlineno__ (CPython compile_class).
def class_body_has_function(cd: ClassDef) -> bool {
    bi = 0;
    while bi < len(cd.body) {
        s = cd.body[bi];
        if isinstance(s, FunctionDef) or isinstance(s, AsyncFunctionDef) {
            return True;
        }
        bi = bi + 1;
    }
    return False;
}


# Class-body prologue locations (CPython 3.14): MAKE_CELL carries NO_LOCATION;
# RESUME points at the class statement line (def-line form, like nested scopes).
# Use the class node's span. A supplied AST can have body statements from an
# implementation file whose line numbers precede the class declaration.
def class_def_loc(cd: ClassDef) -> cloc {
    return nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset);
}


def emit_class_body_prologue(g: cfg_builder, class_qname: str, body_firstlineno: int) {
    # CPython 3.14 locations: MAKE_CELL carries NO_LOCATION; RESUME and the
    # __name__/__module__/__qualname__ boilerplate all sit on the scope's
    # first line (the first decorator's line for a decorated class) with
    # zero-width columns. CPython spans for `class` statements run through
    # the last body statement (same parser-end_tok overshoot as
    # function_def_loc, see codegen_util).
    cloc = loc(body_firstlineno, body_firstlineno, 0, 0);
    noloc = no_loc();
    # CPython order: COPY_FREE_VARS (class-body free vars) precedes MAKE_CELLs.
    if len(g.u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(g.u.freevars), noloc);
    }
    if len(g.u.cellvars) > 0 {
        ci = 0;
        while ci < len(g.u.cellvars) {
            lp = localsplus_index_u(g.u, g.u.cellvars[ci]);
            g.emit_op(OP_MAKE_CELL, lp, noloc);
            ci = ci + 1;
        }
    }
    g.emit_op(OP_RESUME, 0, cloc);
    nidx = g.u.add_name("__name__");
    g.emit_op(OP_LOAD_NAME, nidx, cloc);
    midx = g.u.add_name("__module__");
    g.emit_op(OP_STORE_NAME, midx, cloc);
    qidx = g.u.add_const(PyStr(t="str", val=class_qname));
    g.emit_op(OP_LOAD_CONST, qidx, cloc);
    qnidx = g.u.add_name("__qualname__");
    g.emit_op(OP_STORE_NAME, qnidx, cloc);
    emit_folded_int(g, body_firstlineno, cloc);
    flidx = g.u.add_name("__firstlineno__");
    g.emit_op(OP_STORE_NAME, flidx, cloc);
    if "__classdict__" in g.u.cellvars {
        g.emit_op(OP_LOAD_LOCALS, 0, cloc);
        cd_lp = localsplus_index_u(g.u, "__classdict__");
        g.emit_op(OP_STORE_DEREF, cd_lp, cloc);
    }
}


# __static_attributes__, optional __classdictcell__, and implicit RETURN_VALUE None.
def emit_class_body_epilogue(g: cfg_builder, last: cloc) {
    tup = PyTuple(t="tuple", items=[]);
    tidx = g.u.add_const(tup);
    g.emit_op(OP_LOAD_CONST, tidx, last);
    saidx = g.u.add_name("__static_attributes__");
    g.emit_op(OP_STORE_NAME, saidx, last);
    if "__classdict__" in g.u.cellvars {
        cd_lp = localsplus_index_u(g.u, "__classdict__");
        g.emit_op(OP_LOAD_FAST_BORROW, cd_lp, last);
        cdidx = g.u.add_name("__classdictcell__");
        g.emit_op(OP_STORE_NAME, cdidx, last);
    }
    if "__class__" in g.u.cellvars {
        # Return __classcell__ to __build_class__ (CPython codegen.c): the live
        # cell goes back so py_build_class can seed it with the finished class.
        cc_lp = localsplus_index_u(g.u, "__class__");
        g.emit_op(OP_LOAD_FAST_BORROW, cc_lp, last);
        g.emit_op(OP_COPY, 1, last);
        ccidx = g.u.add_name("__classcell__");
        g.emit_op(OP_STORE_NAME, ccidx, last);
    } else {
        none_idx = g.u.add_const(py_none());
        g.emit_op(OP_LOAD_CONST, none_idx, last);
    }
    g.emit_op(OP_RETURN_VALUE, 0, last);
}


# Lower `class name: ...` at module/class scope into nested PyCode + LOAD_BUILD_CLASS.
def visit_class_def(g: cfg_builder, cd: ClassDef) -> stmt_cont {
    cloc = class_def_loc(cd);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "class definition without symtable");
        return stmt_cont(loc=cloc);
    }
    decorators = cd.decorator_list or [];
    for decorator in decorators {
        visit_expr(g, decorator);
    }
    firstlineno = decorators[0].lineno if decorators else cd.lineno;
    qualname = nested_code_qualname(g.sym_top.block_type, g.u.qualname, cd.name);
    generic = bool(cd.type_params);
    scope: sym_block | None = g.sym_top;
    if generic {
        scope = sym_function_child_at(
            scope, "<generic parameters of " + cd.name + ">", cd.lineno, cd.col_offset
        );
    }
    sym_cls = sym_class_child_at(scope, cd.name, cd.lineno, cd.col_offset)
        if scope is not None
        else None;
    if sym_cls is None or scope is None {
        codegen_fail(g, "SystemError", "missing symtable for class " + cd.name);
        return stmt_cont(loc=cloc);
    }
    if generic {
        wrapper = generic_definition_builder(g, scope, firstlineno, cd.name);
        emit_type_parameters(
            wrapper,
            cd.type_params or [],
            wrapper.u.qualname,
            scope.can_see_class_scope,
            cloc
        );
        emit_name_store(wrapper, ".type_params", cloc);
        emit_class_value(wrapper, cd, sym_cls, firstlineno, qualname, True);
        finish_generic_definition(g, wrapper, cloc, 0);
    } else {
        emit_class_value(g, cd, sym_cls, firstlineno, qualname, False);
    }
    if codegen_busy(g) {
        return stmt_cont(loc=cloc);
    }
    for decorator in reversed(decorators) {
        g.emit_op(OP_CALL, 0, expr_loc(decorator));
    }
    emit_name_store(g, cd.name, cloc);
    return stmt_cont(loc=cloc);
}

# Leave the constructed class on the enclosing scope's operand stack.
def emit_class_value(
    g: cfg_builder,
    cd: ClassDef,
    sym_cls: sym_block,
    firstlineno: int,
    qualname: str,
    generic: bool
) {
    cloc = class_def_loc(cd);
    u_cls = compile_class_cfg(
        cd, g.u.filename, sym_cls, g.private, firstlineno, qualname
    );
    if u_cls.diag is not None {
        g.u.diag = u_cls.diag;
        return;
    }
    cfg_cls = verify_cfg(u_cls);
    if cfg_cls.diag is not None {
        g.u.diag = cfg_cls.diag;
        return;
    }
    co = assemble(cfg_cls);
    g.u.nested_code_emitted = True;
    g.emit_op(OP_LOAD_BUILD_CLASS, 0, cloc);
    g.emit_op(OP_PUSH_NULL, 0, cloc);
    # Class body free vars: push the enclosing scope's cells as the closure
    # tuple (LOAD_FAST_BORROW on a cell slot yields the cell itself), then
    # attach it with SET_FUNCTION_ATTRIBUTE(closure).
    cls_free = freevars_from_sym(sym_cls);
    if len(cls_free) > 0 {
        fi = 0;
        while fi < len(cls_free) {
            lp = localsplus_index(g, cls_free[fi]);
            g.emit_op(OP_LOAD_FAST_BORROW, lp, cloc);
            fi = fi + 1;
        }
        g.emit_op(OP_BUILD_TUPLE, len(cls_free), cloc);
    }
    cidx = g.u.add_const(co);
    g.emit_op(OP_LOAD_CONST, cidx, cloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, cloc);
    if len(cls_free) > 0 {
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, cloc);
    }
    name_idx = g.u.add_const(PyStr(t="str", val=cd.name));
    g.emit_op(OP_LOAD_CONST, name_idx, cloc);
    if generic {
        emit_name_load(g, ".type_params", cloc);
        g.emit_op(OP_CALL_INTRINSIC_1, 10, cloc);
        emit_name_store(g, ".generic_base", cloc);
    }
    emit_class_build_call(g, cd, cloc, generic);
    if codegen_busy(g) {
        return;
    }
}

# Build unverified_cfg for a class body (nested code object before assembly).
def compile_class_cfg(
    cd: ClassDef,
    filename: str,
    sym_cls: sym_block,
    enclosing_private: str | None = None,
    body_firstlineno: int | None = None,
    qualname: str | None = None
) -> unverified_cfg {
    # CPython codegen_class scopes the class body at the first decorator's
    # line when decorated (drives co_firstlineno, RESUME/boilerplate rows,
    # and __firstlineno__); otherwise the `class` line.
    if body_firstlineno is None {
        body_firstlineno = cd.lineno;
    }
    class_qname = qualname
        if qualname is not None
        else sym_class_qualname(cd, sym_cls, enclosing_private);
    u = unverified_cfg(
        filename=filename,
        name=cd.name,
        qualname=class_qname,
        firstlineno=body_firstlineno
    );
    if sym_cls.nested {
        u.flags = CO_NESTED;
    }
    ann_plan = collect_ann_plan_class(cd, class_qname, sym_cls.nested);
    # Class bodies are transparent closure scopes: free vars captured by
    # methods (or direct body references to enclosing function cells) must
    # survive into the class-body code object so method creation inside the
    # body can close over those cells.
    u.freevars = freevars_from_sym(sym_cls);
    u.varnames = inline_storage_names(sym_cls);
    u.cellvars.extend(inline_storage_names(sym_cls, True));
    # Implicit __class__ cell first (CPython compiler_unit appends it before
    # __classdict__; observed oracle order ('__class__', '__classdict__')).
    if sym_cls.needs_class_closure {
        u.cellvars.append("__class__");
    }
    if sym_cls.needs_classdict_closure
        or class_body_has_function(cd)
        or ann_plan.any_annotation
        or class_body_has_typealias(cd) {
        u.cellvars.append("__classdict__");
        if ann_plan.any_conditional {
            u.cellvars.append("__conditional_annotations__");
        }
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_cls, cd.name);
    emit_class_body_prologue(g, class_qname, body_firstlineno);
    if cd.type_params {
        emit_name_load(g, ".type_params", stmt_loc(cd));
        emit_name_store(g, "__type_params__", stmt_loc(cd));
    }
    emit_class_annotation_setup(
        g, ann_plan, nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset)
    );
    last = loc(0, cd.lineno, 0, 0);
    bi = 0;
    doc = body_docstring(cd.body);
    if doc is not None {
        import from jaclang.compiler.backends.py.jacpython.compiler_context {
            current_optimization_level
        }
        if current_optimization_level() < 2 {
            last = stmt_loc(cd.body[0]);
            g.emit_op(OP_LOAD_CONST, u.add_const(doc), last);
            emit_name_store(g, "__doc__", last);
        }
        bi = 1;
    }
    while bi < len(cd.body) {
        s = cd.body[bi];
        cont = visit_stmt(
            g, s, exec_tail_emits_code(cd.body, bi + 1), cd.body, bi + 1, None, ann_plan
        );
        last = cont.loc;
        if codegen_busy(g) {
            u.flush_late_consts();
            return u;
        }
        if cont.next_si >= 0 {
            bi = cont.next_si;
        } else {
            bi = bi + 1;
        }
    }
    finish_class_annotations(g, ann_plan);
    if codegen_busy(g) {
        u.flush_late_consts();
        return u;
    }
    emit_class_body_epilogue(g, last);
    u.flush_late_consts();
    return u;
}


# Lower `def name(...): ...` at module/class scope into nested PyCode + MAKE_FUNCTION.
def visit_function_def(
    g: cfg_builder, fd: FunctionDef | AsyncFunctionDef
) -> stmt_cont {
    floc = stmt_loc(fd);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "function definition without symtable");
        return stmt_cont(loc=floc);
    }
    decorators = fd.decorator_list or [];
    firstlineno = decorators[0].lineno if decorators else fd.lineno;
    qualname = nested_code_qualname(g.sym_top.block_type, g.u.qualname, fd.name);
    generic = bool(fd.type_params);
    scope: sym_block | None = g.sym_top;
    if generic {
        scope = sym_function_child_at(
            scope, "<generic parameters of " + fd.name + ">", fd.lineno, fd.col_offset
        );
    }
    sym_fn = sym_function_child_at(scope, fd.name, fd.lineno, fd.col_offset)
        if scope is not None
        else None;
    if sym_fn is None or scope is None {
        codegen_fail(g, "SystemError", "missing symtable for function " + fd.name);
        return stmt_cont(loc=floc);
    }
    unit = compile_fn_cfg(
        fd.name,
        fd.args,
        fd.body,
        fd.lineno,
        g.u.filename,
        sym_fn,
        g.private,
        firstlineno,
        g.sym_top.block_type == "class",
        qualname
    );
    cfg = verify_cfg(unit);
    if cfg.diag is not None {
        g.u.diag = cfg.diag;
        return stmt_cont(loc=floc);
    }
    co = assemble(cfg);
    g.u.nested_code_emitted = True;
    for decorator in decorators {
        visit_expr(g, decorator);
    }
    if generic {
        # Preserve the outer evaluation order and pass defaults into the factory.
        if not emit_function_defaults(g, fd.args.defaults, floc)
            or not emit_function_kwdefaults(g, fd.args, floc) {
            return stmt_cont(loc=floc);
        }
        wrapper = generic_definition_builder(g, scope, firstlineno, g.private);
        emit_type_parameters(
            wrapper,
            fd.type_params or [],
            wrapper.u.qualname,
            scope.can_see_class_scope,
            floc
        );
        for name in scope.varnames {
            emit_name_load(wrapper, name, floc);
        }
        emit_make_function_with_closure(wrapper, sym_fn, co, floc);
        if ".kwdefaults" in scope.varnames {
            wrapper.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 2, floc);
        }
        if ".defaults" in scope.varnames {
            wrapper.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 1, floc);
        }
        emit_definition_annotations(wrapper, fd, qualname);
        wrapper.emit_op(OP_SWAP, 2, floc);
        wrapper.emit_op(OP_CALL_INTRINSIC_2, 4, floc);
        finish_generic_definition(g, wrapper, floc, len(scope.varnames));
    } else {
        emit_make_function_with_closure(g, sym_fn, co, floc, fd.args);
        emit_definition_annotations(g, fd, qualname);
    }
    if codegen_busy(g) {
        return stmt_cont(loc=floc);
    }
    for decorator in reversed(decorators) {
        g.emit_op(OP_CALL, 0, expr_loc(decorator));
    }
    emit_name_store(g, fd.name, floc);
    return stmt_cont(loc=floc);
}

def visit_async_function_def(g: cfg_builder, fd: AsyncFunctionDef) -> stmt_cont {
    return visit_function_def(g, fd);
}

# Hidden annotation scopes are transparent to public qualnames.
def generic_definition_builder(
    enclosing: cfg_builder, scope: sym_block, firstlineno: int, private: str | None
) -> cfg_builder {
    assert enclosing.sym_top is not None;
    qname = nested_code_qualname(
        enclosing.sym_top.block_type, enclosing.u.qualname, scope.name
    );
    u = unverified_cfg(
        filename=enclosing.u.filename,
        name=scope.name,
        qualname=qname,
        firstlineno=firstlineno
    );
    u.flags = CO_OPTIMIZED | CO_NEWLOCALS | (CO_NESTED if scope.nested else 0);
    u.varnames = fast_varnames_from_sym(scope);
    u.argcount = len(scope.varnames);
    u.param_count = u.argcount;
    u.classdict_names = scope.can_see_class_scope;
    entry_blk = u.add_block();
    builder = new_cfg_builder(u, entry_blk, scope, private);
    emit_function_prologue(builder, scope, firstlineno, False);
    return builder;
}

# The factory's result is the undecorated function or class.
def finish_generic_definition(
    enclosing: cfg_builder, wrapper: cfg_builder, location: cloc, nargs: int
) {
    wrapper.emit_op(OP_RETURN_VALUE, 0, location);
    wrapper.u.flush_late_consts();
    cfg = verify_cfg(wrapper.u);
    if cfg.diag is not None {
        enclosing.u.diag = cfg.diag;
        return;
    }
    emit_typealias_closure(enclosing, assemble(cfg), location);
    if nargs {
        # Defaults already occupy the stack in their evaluation order. Rotate
        # the factory beneath them; CALL's implicit first argument consumes
        # the first defaults object without needing another stack slot.
        for depth in range(nargs + 1, 1, -1) {
            enclosing.emit_op(OP_SWAP, depth, location);
        }
        enclosing.emit_op(OP_CALL, nargs - 1, location);
    } else {
        enclosing.emit_op(OP_PUSH_NULL, 0, location);
        enclosing.emit_op(OP_CALL, 0, location);
    }
}

# Function annotations use the same lazy format guard and closure machinery
# as alias values and type-parameter bounds.
def emit_definition_annotations(
    g: cfg_builder, fd: FunctionDef | AsyncFunctionDef, qualname: str
) {
    import from jaclang.compiler.backends.py.jacpython.compiler_context {
        current_compile_flags
    }
    if current_compile_flags() & 0x1000000 {
        emit_future_function_annotations(g, fd);
        return;
    }
    scope: sym_block | None = None;
    if g.sym_top is not None {
        for child in g.sym_top.children {
            if child.function_annotation_key == id(fd) {
                scope = child;
                break;
            }
        }
    }
    if scope is None {
        return;
    }
    parameters = fd.args.posonlyargs + fd.args.args;
    if fd.args.vararg is not None {
        parameters.append(fd.args.vararg);
    }
    parameters.extend(fd.args.kwonlyargs);
    if fd.args.kwarg is not None {
        parameters.append(fd.args.kwarg);
    }
    keys: list[expr | None] = [];
    values: list[expr] = [];
    pairs: list[tuple[str, expr]] = [];
    for parameter in parameters {
        if parameter.annotation is not None {
            pairs.append((codegen_mangle(g, parameter.arg), parameter.annotation));
        }
    }
    if fd.returns is not None {
        pairs.append(("return", fd.returns));
    }
    if not pairs {
        return;
    }
    for (name, annotation) in pairs {
        keys.append(
            Constant(
                value=PyStr(t="str", val=name),
                kind=None,
                lineno=annotation.lineno,
                col_offset=annotation.col_offset,
                end_lineno=annotation.end_lineno,
                end_col_offset=annotation.end_col_offset
            )
        );
        values.append(annotation);
    }
    value = Dict(
        keys=keys,
        values=values,
        lineno=fd.lineno,
        col_offset=fd.col_offset,
        end_lineno=fd.end_lineno,
        end_col_offset=fd.end_col_offset
    );
    prefix = qualname.rsplit(".", 1)[0] + "." if "." in qualname else "";
    unit = type_expression_cfg(
        value,
        "__annotate__",
        prefix + "__annotate__",
        g.u.filename,
        scope,
        g.private,
        scope.can_see_class_scope,
        stmt_loc(fd)
    );
    cfg = verify_cfg(unit);
    if cfg.diag is not None {
        g.u.diag = cfg.diag;
        return;
    }
    code = assemble(cfg);
    # Keep the internal .format binding distinct from annotation references
    # to the user's name `format`, but expose the public positional parameter.
    code.varnames[0] = "format";
    emit_typealias_closure(g, code, stmt_loc(fd));
    g.emit_op(OP_SWAP, 2, stmt_loc(fd));
    g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 16, stmt_loc(fd));
}

# Build unverified_cfg for a function/async body (nested code object before assembly).
def compile_fn_cfg(
    name: str,
    args: arguments,
    body: list[stmt],
    lineno: int,
    filename: str,
    sym_fn: sym_block,
    private: str | None = None,
    body_firstlineno: int | None = None,
    in_class: bool = False,
    qualname: str | None = None
) -> unverified_cfg {
    # CPython codegen_function scopes the body at the first decorator's line
    # when decorated (drives co_firstlineno and the prologue rows).
    if body_firstlineno is None {
        body_firstlineno = lineno;
    }
    (argcount, posonly, kwonly) = function_argcounts(args);
    u = unverified_cfg(
        filename=filename,
        name=name,
        qualname=qualname if qualname is not None else name,
        firstlineno=body_firstlineno
    );
    u.argcount = argcount;
    u.flags = function_code_flags(args, in_class);
    if sym_fn.nested {
        u.flags = u.flags | CO_NESTED;
    }
    u.posonlyargcount = posonly;
    u.kwonlyargcount = kwonly;
    u.param_count = len(sym_fn.varnames);
    is_suspendable = sym_fn.generator or sym_fn.coroutine;
    if sym_fn.generator and sym_fn.coroutine {
        u.flags = u.flags | CO_ASYNC_GENERATOR;
    } elif sym_fn.generator {
        u.flags = u.flags | CO_GENERATOR;
    } elif sym_fn.coroutine {
        u.flags = u.flags | CO_COROUTINE;
    }
    u.varnames = fast_varnames_from_sym(sym_fn);
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_fn, private);
    protect_start = emit_function_prologue(g, sym_fn, body_firstlineno, is_suspendable);
    last = loc(0, body_firstlineno, 0, 0);
    terminated = False;
    bi = 0;
    doc = body_docstring(body);
    if doc is not None {
        import from jaclang.compiler.backends.py.jacpython.compiler_context {
            current_optimization_level
        }
        if current_optimization_level() < 2 {
            u.add_const(doc);
            u.flags = u.flags | CO_HAS_DOCSTRING;
        }
        bi = 1;
    }
    while bi < len(body) {
        s = body[bi];
        cont = visit_stmt(g, s, exec_tail_emits_code(body, bi + 1), body, bi + 1);
        last = cont.loc;
        if cont.terminated {
            # CPython compiles the remaining statements and then drops them as
            # unreachable blocks (flowgraph remove_unreachable). Visiting them
            # here would append live bytes after a terminator, so stop now.
            # The implicit-return None const is still interned by CPython's
            # (dead) epilogue emission; remove_unused_consts keeps it only at
            # index 0, exactly like the host. Deferred comp cleanup handlers
            # are emitted here too -- CPython lays them out after the (dead)
            # epilogue regardless of how the body ended.
            u.add_const(py_none());
            flush_pending_await_footers(g);
            emit_deferred_comp_handlers(g);
            if is_suspendable {
                emit_generator_except_handler(g, protect_start);
            }
            u.flush_late_consts();
            return u;
        }
        if codegen_busy(g) {
            u.flush_late_consts();
            return u;
        }
        if cont.next_si >= 0 {
            bi = cont.next_si;
        } else {
            bi = bi + 1;
        }
    }
    if not terminated {
        none_idx = u.add_const(py_none());
        g.emit_op(OP_LOAD_CONST, none_idx, last);
        g.emit_op(OP_RETURN_VALUE, 0, last);
    }
    flush_pending_await_footers(g);
    emit_deferred_comp_handlers(g);
    if is_suspendable {
        emit_generator_except_handler(g, protect_start);
    }
    u.flush_late_consts();
    return u;
}


# Build unverified_cfg for a `def` body (nested code object before assembly).
def compile_function_cfg(
    fd: FunctionDef, filename: str, sym_fn: sym_block, private: str | None = None
) -> unverified_cfg {
    return compile_fn_cfg(
        fd.name, fd.args, fd.body, fd.lineno, filename, sym_fn, private
    );
}


# ---------------- PEP 695 `type X = v` / `type X[T, ...] = v` ----------------
#
# CPython lowers a type alias into a lazily-evaluated value function whose only
# parameter is `.format` (guarded: formats above 2 raise NotImplementedError)
# plus a 3-tuple (name, type_params_or_None, function) handed to
# CALL_INTRINSIC_1(INTRINSIC_TYPEALIAS). With type parameters the tuple build
# moves into a hidden `<generic parameters of X>` scope that constructs one
# TypeVar per parameter and closes the value function over those cells.

def typealias_target_name(ta: TypeAlias) -> str | None {
    if isinstance(ta.name, Name) {
        return ((ta.name as Name).id);
    }
    return None;
}


# The lazy value scope: argcount 1 (.format), format guard, then the alias
# value expression. Generic aliases additionally take the type params as
# free vars (COPY_FREE_VARS in the prologue via their symtable cells).
def type_expression_cfg(
    value: expr,
    name: str,
    qualname: str,
    filename: str,
    sym_v: sym_block,
    private: str | None,
    in_class: bool,
    hloc: cloc,
    unpack: bool = False
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename, name=name, qualname=qualname, firstlineno=hloc.lineno
    );
    u.argcount = 1;
    u.posonlyargcount = 1;
    u.param_count = 1;
    u.flags = CO_OPTIMIZED | CO_NEWLOCALS;
    if sym_v.nested {
        u.flags = u.flags | CO_NESTED;
    }
    u.varnames = fast_varnames_from_sym(sym_v);
    u.freevars = freevars_from_sym(sym_v);
    if in_class {
        # Directly inside a class body the lazy scope closes over the class
        # dict cell and resolves bare names through it (PEP 649 hook).
        if "__classdict__" not in u.freevars {
            u.freevars.append("__classdict__");
        }
        u.classdict_names = True;
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_v, private);
    # Prologue: COPY_FREE_VARS, MAKE_CELL(s), RESUME (CPython flowgraph order).
    # Nested-scope locations: NO_LOCATION for cell plumbing, def-line RESUME.
    u.cellvars = cellvars_from_sym(sym_v);
    noloc = no_loc();
    if len(u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), noloc);
    }
    ci = 0;
    while ci < len(u.cellvars) {
        g.emit_op(OP_MAKE_CELL, localsplus_index_u(u, u.cellvars[ci]), noloc);
        ci = ci + 1;
    }
    g.emit_op(OP_RESUME, 0, loc(hloc.lineno, hloc.lineno, 0, 0));
    # Guard: if .format > 2: raise NotImplementedError (formats 0/1 only).
    g.emit_op(OP_LOAD_FAST_BORROW, localsplus_index_u(u, ".format"), hloc);
    # Dead small-int slot: the guard literal keeps const pool slot 0.
    u.add_const(PyInt(t="int", val=2));
    u.dead_small_int_const = True;
    g.emit_op(OP_LOAD_SMALL_INT, 2, hloc);
    g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GT), hloc);
    after = g.new_block();
    g.emit_jump(OP_POP_JUMP_IF_FALSE, after.id, hloc);
    g.emit_op(OP_LOAD_COMMON_CONSTANT, 1, hloc);
    g.emit_op(OP_RAISE_VARARGS, 1, hloc);
    g.use(after);
    visit_expr(g, value);
    if unpack {
        g.emit_op(OP_UNPACK_SEQUENCE, 1, hloc);
    }
    if codegen_busy(g) {
        u.flush_late_consts();
        return u;
    }
    g.emit_op(OP_RETURN_VALUE, 0, hloc);
    u.flush_late_consts();
    return u;
}


# The hidden <generic parameters of X> scope: builds one TypeVar per param
# into cells, then assembles (name, (typevar, ...), closure-wrapped value fn).
def typealias_genparams_cfg(
    ta: TypeAlias,
    tps: list[type_param],
    name: str,
    filename: str,
    sym_gp: sym_block,
    co_value: PyCode,
    private: str | None,
    in_class: bool,
    qualname: str
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename,
        name="<generic parameters of " + name + ">",
        qualname=qualname,
        firstlineno=ta.lineno
    );
    u.flags = CO_OPTIMIZED | CO_NEWLOCALS;
    if sym_gp.nested {
        u.flags = u.flags | CO_NESTED;
    }
    u.varnames = fast_varnames_from_sym(sym_gp);
    u.freevars = freevars_from_sym(sym_gp);
    if in_class and "__classdict__" not in u.freevars {
        u.freevars.append("__classdict__");
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_gp, private);
    u.cellvars = cellvars_from_sym(sym_gp);
    noloc = no_loc();
    if len(u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), noloc);
    }
    ci = 0;
    while ci < len(u.cellvars) {
        g.emit_op(OP_MAKE_CELL, localsplus_index_u(u, u.cellvars[ci]), noloc);
        ci = ci + 1;
    }
    g.emit_op(OP_RESUME, 0, loc(ta.lineno, ta.lineno, 0, 0));
    tloc = nloc(ta.lineno, ta.end_lineno, ta.col_offset, ta.end_col_offset);
    nidx = g.u.add_const(PyStr(t="str", val=name));
    g.emit_op(OP_LOAD_CONST, nidx, tloc);
    emit_type_parameters(g, tps, qualname, in_class, tloc);
    if codegen_busy(g) {
        return u;
    }
    def_tup = PyTuple(t="tuple", items=[PyInt(t="int", val=1)]);
    didx = g.u.add_const(def_tup);
    g.emit_op(OP_LOAD_CONST, didx, tloc);
    emit_typealias_closure(g, co_value, tloc);
    g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 1, tloc);
    g.emit_op(OP_BUILD_TUPLE, 3, tloc);
    g.emit_op(OP_CALL_INTRINSIC_1, 11, tloc);
    g.emit_op(OP_RETURN_VALUE, 0, tloc);
    u.flush_late_consts();
    return u;
}


def emit_type_parameters(
    g: cfg_builder, tps: list[type_param], qualname: str, in_class: bool, tloc: cloc
) {
    np = len(tps);
    pi = 0;
    while pi < np {
        tp = tps[pi];
        tv_name: str = getattr(tp, "name");
        pidx = g.u.add_const(PyStr(t="str", val=tv_name));
        g.emit_op(OP_LOAD_CONST, pidx, tloc);
        bound = tp.bound if isinstance(tp, TypeVar) else None;
        if bound is not None {
            if not emit_type_parameter_expr(g, tp, bound, False, qualname, in_class) {
                return;
            }
            g.emit_op(OP_CALL_INTRINSIC_2, 3 if isinstance(bound, Tuple) else 2, tloc);
        } else {
            intrinsic = 9
                if isinstance(tp, TypeVarTuple)
                else 8 if isinstance(tp, ParamSpec) else 7;
            g.emit_op(OP_CALL_INTRINSIC_1, intrinsic, tloc);
        }
        default_value: expr | None = getattr(tp, "default_value");
        if default_value is not None {
            if not emit_type_parameter_expr(
                g, tp, default_value, True, qualname, in_class
            ) {
                return;
            }
            g.emit_op(OP_CALL_INTRINSIC_2, 5, tloc);
        }
        g.emit_op(OP_COPY, 1, tloc);
        emit_name_store(g, tv_name, tloc);
        pi = pi + 1;
    }
    g.emit_op(OP_BUILD_TUPLE, np, tloc);
}

def emit_type_parameter_expr(
    g: cfg_builder,
    tp: type_param,
    value: expr,
    is_default: bool,
    qualname: str,
    in_class: bool
) -> bool {
    key = id(tp) * 2 + int(is_default);
    scope: sym_block | None = None;
    if g.sym_top is not None {
        for child in g.sym_top.children {
            if child.type_parameter_key == key {
                scope = child;
                break;
            }
        }
    }
    if scope is None {
        codegen_fail(g, "SystemError", "missing type parameter annotation scope");
        return False;
    }
    name: str = getattr(tp, "name");
    prefix = qualname.rsplit(".", 1)[0] + "." if "." in qualname else "";
    tloc = expr_loc(value);
    unpack = is_default and isinstance(tp, TypeVarTuple) and isinstance(value, Starred);
    body = value.value if unpack and isinstance(value, Starred) else value;
    unit = type_expression_cfg(
        body,
        name,
        prefix + name,
        g.u.filename,
        scope,
        g.private,
        in_class,
        tloc,
        unpack
    );
    cfg = verify_cfg(unit);
    if cfg.diag is not None {
        g.u.diag = cfg.diag;
        return False;
    }
    co = assemble(cfg);
    g.emit_op(
        OP_LOAD_CONST,
        g.u.add_const(PyTuple(t="tuple", items=[PyInt(t="int", val=1)])),
        tloc
    );
    emit_typealias_closure(g, co, tloc);
    g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 1, tloc);
    return True;
}

# A lazy alias may capture enclosing locals in addition to its own type
# parameters. The assembled function's free-variable order is authoritative.
def emit_typealias_closure(g: cfg_builder, co: PyCode, tloc: cloc) {
    for name in co.freevars {
        g.emit_op(OP_LOAD_FAST_BORROW, localsplus_index(g, name), tloc);
    }
    if co.freevars {
        g.emit_op(OP_BUILD_TUPLE, len(co.freevars), tloc);
    }
    g.emit_op(OP_LOAD_CONST, g.u.add_const(co), tloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, tloc);
    if co.freevars {
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, tloc);
    }
}

# Lower `type name[params] = value` at module/class/function scope.
def visit_type_alias(g: cfg_builder, ta: TypeAlias) -> stmt_cont {
    tloc = nloc(ta.lineno, ta.end_lineno, ta.col_offset, ta.end_col_offset);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "type alias without symtable");
        return stmt_cont(loc=tloc);
    }
    name = typealias_target_name(ta);
    if name is None {
        codegen_fail(g, "SyntaxError", "invalid type alias target");
        return stmt_cont(loc=tloc);
    }
    tps: list[type_param] = [];
    if ta.type_params is not None {
        tps = ta.type_params;
    }
    generic = len(tps) > 0;
    gp_name = "<generic parameters of " + name + ">";
    sym_v = None;
    if generic {
        sym_gp = sym_function_child_at(g.sym_top, gp_name, ta.lineno, ta.col_offset);
        if sym_gp is None {
            codegen_fail(g, "SystemError", "missing symtable for " + gp_name);
            return stmt_cont(loc=tloc);
        }
        sym_params = sym_gp;
        sym_v = sym_function_child_at(sym_gp, name, ta.lineno, ta.col_offset);
    } else {
        sym_v = sym_function_child_at(g.sym_top, name, ta.lineno, ta.col_offset);
    }
    if sym_v is None {
        codegen_fail(g, "SystemError", "missing symtable for type alias " + name);
        return stmt_cont(loc=tloc);
    }
    sym_value = sym_v;
    # CPython qualname rules: plain name at module scope, <Class>.Name in a
    # class body, and <parent>.<locals>.Name under a function scope.
    vqname = name;
    gpqname = "<generic parameters of " + name + ">";
    if g.sym_top.block_type == "class" {
        vqname = g.u.qualname + "." + name;
        gpqname = g.u.qualname + "." + gpqname;
    } elif g.sym_top.block_type != "module" {
        vqname = g.u.qualname + ".<locals>." + name;
        gpqname = g.u.qualname + ".<locals>." + gpqname;
    }
    in_class = g.sym_top.block_type == "class";
    u_v = type_expression_cfg(
        ta.value, name, vqname, g.u.filename, sym_value, g.private, in_class, tloc
    );
    if u_v.diag is not None {
        g.u.diag = u_v.diag;
        return stmt_cont(loc=tloc);
    }
    if generic {
        cfg_v = verify_cfg(u_v);
        if cfg_v.diag is not None {
            g.u.diag = cfg_v.diag;
            return stmt_cont(loc=tloc);
        }
        co_v = assemble(cfg_v);
        u_gp = typealias_genparams_cfg(
            ta, tps, name, g.u.filename, sym_params, co_v, g.private, in_class, gpqname
        );
        if u_gp.diag is not None {
            g.u.diag = u_gp.diag;
            return stmt_cont(loc=tloc);
        }
        cfg_gp = verify_cfg(u_gp);
        if cfg_gp.diag is not None {
            g.u.diag = cfg_gp.diag;
            return stmt_cont(loc=tloc);
        }
        co_gp = assemble(cfg_gp);
        g.u.nested_code_emitted = True;
        emit_typealias_closure(g, co_gp, tloc);
        g.emit_op(OP_PUSH_NULL, 0, tloc);
        g.emit_op(OP_CALL, 0, tloc);
    } else {
        cfg_v = verify_cfg(u_v);
        if cfg_v.diag is not None {
            g.u.diag = cfg_v.diag;
            return stmt_cont(loc=tloc);
        }
        co_v = assemble(cfg_v);
        g.u.nested_code_emitted = True;
        nidx = g.u.add_const(PyStr(t="str", val=name));
        none_idx = g.u.add_const(py_none());
        def_tup = PyTuple(t="tuple", items=[PyInt(t="int", val=1)]);
        didx = g.u.add_const(def_tup);
        g.emit_op(OP_LOAD_CONST, nidx, tloc);
        g.emit_op(OP_LOAD_CONST, none_idx, tloc);
        g.emit_op(OP_LOAD_CONST, didx, tloc);
        emit_typealias_closure(g, co_v, tloc);
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 1, tloc);
        g.emit_op(OP_BUILD_TUPLE, 3, tloc);
        g.emit_op(OP_CALL_INTRINSIC_1, 11, tloc);
    }
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    emit_name_store(g, name, tloc);
    return stmt_cont(loc=tloc);
}

# Wire statement-dispatch handlers into the leaf registry (see
# compiler_dispatch.jac). Runs at module load via `with entry`; entry
# drivers (product_compile, compiler_slice) import this module so the
# registration always precedes the first compile. Dict item assignment
# mutates the holder in place (scalar-glob rebinding would be local).
with entry {
    stmt_handlers["visit_import"] = visit_import;
    stmt_handlers["visit_import_from"] = visit_import_from;
    stmt_handlers["visit_class_def"] = visit_class_def;
    stmt_handlers["visit_function_def"] = visit_function_def;
    stmt_handlers["visit_async_function_def"] = visit_async_function_def;
    stmt_handlers["visit_type_alias"] = visit_type_alias;
}
