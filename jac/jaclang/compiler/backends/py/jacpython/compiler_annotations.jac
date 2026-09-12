# CPython 3.14 deferred module/class annotations share a lexical __annotate__
# scope. Conditional entries register their indices as the body executes;
# the annotation function evaluates only those entries when called later.
# Function-local and non-simple annotations never evaluate their expressions.
#
# Module setup reserves the __annotate__ function's code/name operands;
# scope finalization fills them after emitting the body. Class finalization
# creates a closure containing the class namespace and any enclosing cells.

import from jaclang.runtime.python.objects { PyStr, PyInt, py_none, hashkey_equal }
import from jaclang.runtime.python.opcode_meta {
    OP_SETUP_ANNOTATIONS,
    OP_SWAP,
    OP_RESUME,
    OP_LOAD_FAST,
    OP_LOAD_SMALL_INT,
    OP_LOAD_CONST,
    OP_COMPARE_OP,
    OP_POP_JUMP_IF_FALSE,
    OP_LOAD_COMMON_CONSTANT,
    OP_RAISE_VARARGS,
    OP_BUILD_MAP,
    OP_LOAD_GLOBAL,
    OP_CONTAINS_OP,
    OP_COPY,
    OP_STORE_SUBSCR,
    OP_RETURN_VALUE,
    OP_MAKE_FUNCTION,
    OP_STORE_NAME,
    OP_BUILD_SET,
    OP_SET_ADD,
    OP_POP_TOP,
    OP_LOAD_NAME,
    OP_STORE_FAST,
    OP_STORE_ATTR,
    OP_LOAD_DEREF,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FROM_DICT_OR_GLOBALS,
    OP_BUILD_TUPLE,
    OP_COPY_FREE_VARS,
    OP_MAKE_CELL,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_STORE_DEREF,
    CMP_GT,
    CO_OPTIMIZED,
    CO_NEWLOCALS,
    CO_NESTED,
    compare_oparg,
}
import from jaclang.compiler.frontend.python.ast_nodes {
    ast_node,
    arg,
    stmt,
    expr,
    AnnAssign,
    AugAssign,
    ClassDef,
    Name,
    Attribute,
    Subscript,
    Slice,
    Tuple,
    List,
    Set,
    Dict,
    BinOp,
    UnaryOp,
    BoolOp,
    Compare,
    Call,
    IfExp,
    Starred,
    Constant,
    FormattedValue,
    JoinedStr,
    TemplateStr,
    Interpolation,
    If,
    While,
    For,
    AsyncFor,
    Try,
    TryStar,
    With,
    AsyncWith,
    Match,
    ExceptHandler,
    match_case,
    Assign,
    Expr,
    Return,
    Delete,
    Raise,
    Assert,
    Global,
    Nonlocal,
    Import,
    ImportFrom,
    Pass,
    Break,
    Continue,
    FunctionDef,
    AsyncFunctionDef,
    Lambda,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    Yield,
    YieldFrom,
    Await,
    NamedExpr,
}
import from jaclang.compiler.backends.py.jacpython.compiler_ir {
    cloc,
    cinstr,
    cfg_builder,
    basicblock,
    unverified_cfg,
    loc,
    new_cfg_builder,
    stmt_cont,
}
import from jaclang.compiler.backends.py.jacpython.codegen_util {
    expr_loc,
    stmt_loc,
    nloc,
    no_loc
}
import from jaclang.compiler.frontend.python.compiler_symtable {
    sym_block,
    sym_dict_get,
    SCOPE_GLOBAL_IMPLICIT,
    SYM_USE,
    sym_set_scope,
    sym_block_tuple_names,
    SCOPE_CELL,
}
import from jaclang.compiler.backends.py.jacpython.flowgraph { verify_cfg }
import from jaclang.compiler.backends.py.jacpython.assembler { assemble }
import from jaclang.compiler.backends.py.jacpython.compiler_emit {
    visit_expr,
    visit_subscript_index,
    codegen_mangle,
    fast_local_index,
    localsplus_index,
    localsplus_index_u,
    codegen_fail,
    codegen_busy,
    fast_varnames_from_sym,
    freevars_from_sym,
    cellvars_from_sym,
}

import from jaclang.compiler.backends.py.jacpython.compiler_context {
    current_compile_flags
}
import from _ast_unparse { Unparser, _Precedence }

# The stdlib unparser inserts optional parentheses for readability. Annotation
# strings use the compiler's canonical spelling for Boolean operators and a
# sole generator argument instead.
obj annotation_unparser(Unparser) {
    def postinit {
        Unparser.__init__(self);
    }

    def visit_BoolOp(`node: any) {
        operator = self.boolops[`node.op.__class__.__name__];
        precedence = self.boolop_precedence[operator] as int;
        parens = (self.get_precedence(`node) as int) > precedence;
        if parens {
            self.write("(");
        }
        for (index, value) in enumerate(`node.values) {
            if index {
                self.write(" " + operator + " ");
            }
            self.set_precedence(precedence + 1, value);
            self.traverse(value);
        }
        if parens {
            self.write(")");
        }
    }

    def visit_Call(`node: any) {
        import ast;
        if len(`node.args) == 1
            and not `node.keywords
            and isinstance(`node.args[0], ast.GeneratorExp) {
            self.set_precedence(_Precedence.ATOM, `node.func);
            self.traverse(`node.func);
            self.traverse(`node.args[0]);
        } else {
            Unparser.visit_Call(self, `node);
        }
    }
}

# One deferred annotation: an annotated name plus its expression, in
# construction order (the index baked into the SET_ADD registration).
obj ann_entry {
    has target: str,
        annotation: expr,
        owner_lineno: int,
        owner_col: int,
        index: int,
        # Full span of the owning AnnAssign (CPython's location for the
        # registration and __annotate__ entry instructions).
        owner_loc: cloc | None = None,
        # True when the AnnAssign sits under control flow (If/While/For/Try/
        # With/Match). Class scopes only membership-check conditional entries
        # inside __annotate__; module scopes check every entry.
        conditional: bool = False;
}

# Per-scope plan shared by the setup emitter, the per-statement visitor, and
# the end-of-unit nested-code builder. load_const_ins / store_name_ins are
# the placeholder instructions whose opargs are patched once the synthesized
# __annotate__ PyCode exists.
obj ann_scope_plan {
    has entries: list[ann_entry] = [],
        function_annotation: bool = False,
        any_annotation: bool = False,
        body_first_lineno: int = 1,
        # Full span of the scope's first statement: CPython attributes the
        # annotation setup bytes and the __annotate__ guard/epilogue to it.
        # For class scopes this is the `class` statement's own full span.
        head_loc: cloc | None = None,
        load_const_ins: cinstr | None = None,
        store_name_ins: cinstr | None = None,
        # --- class-scope extension ---------------------------------------
        is_class: bool = False,
        # Qualname of the owning class; the nested fn becomes
        # `<owner>.__annotate__`.
        owner_qualname: str = "",
        # The class itself is nested (defined inside a function): its
        # __annotate__ inherits CO_NESTED.
        nested_class: bool = False,
        # True when at least one entry sits under control flow: only then does
        # the class gain the __conditional_annotations__ cellvar, the closure
        # tuple grows to two cells, and conditional entries get membership
        # checks inside __annotate__.
        any_conditional: bool = False;
}

# --- planning -------------------------------------------------------------

# Deep-collect the module scope's annotated assignments in source order.
# Descends into same-scope control flow (If/While/For/Try/With/Match);
# never enters function/class bodies (they own their scopes).
def collect_ann_plan(body: list[stmt]) -> ann_scope_plan {
    plan = ann_scope_plan();
    if len(body) > 0 {
        plan.body_first_lineno = ann_stmt_span(body[0]).lineno;
        plan.head_loc = ann_stmt_span(body[0]);
    }
    ann_collect_stmts(plan, body);
    return plan;
}

# Same collection for a CLASS body: head/firstlineno derive from the class
# statement itself, and control-flow depth marks per-entry conditionality.
def collect_ann_plan_class(
    cd: ClassDef, class_qname: str, nested: bool
) -> ann_scope_plan {
    plan = ann_scope_plan();
    plan.is_class = True;
    plan.owner_qualname = class_qname;
    plan.nested_class = nested;
    plan.body_first_lineno = cd.lineno;
    plan.head_loc = nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset);
    ann_collect_stmts(plan, cd.body);
    return plan;
}

def ann_stmt_span(s: stmt) -> cloc {
    # Full source span of a statement. Every concrete stmt subclass carries
    # the four position fields; the shared base does not, so dispatch per type.
    if isinstance(s, Assign) {
        a = s as Assign;
        return nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        return nloc(aa.lineno, aa.end_lineno, aa.col_offset, aa.end_col_offset);
    }
    if isinstance(s, AnnAssign) {
        an2 = s as AnnAssign;
        return nloc(an2.lineno, an2.end_lineno, an2.col_offset, an2.end_col_offset);
    }
    if isinstance(s, Return) {
        r = s as Return;
        return nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        return nloc(d.lineno, d.end_lineno, d.col_offset, d.end_col_offset);
    }
    if isinstance(s, Expr) {
        x = s as Expr;
        return nloc(x.lineno, x.end_lineno, x.col_offset, x.end_col_offset);
    }
    if isinstance(s, Raise) {
        rr = s as Raise;
        return nloc(rr.lineno, rr.end_lineno, rr.col_offset, rr.end_col_offset);
    }
    if isinstance(s, Assert) {
        asrt = s as Assert;
        return nloc(asrt.lineno, asrt.end_lineno, asrt.col_offset, asrt.end_col_offset);
    }
    if isinstance(s, Import) {
        im = s as Import;
        return nloc(im.lineno, im.end_lineno, im.col_offset, im.end_col_offset);
    }
    if isinstance(s, ImportFrom) {
        imf = s as ImportFrom;
        return nloc(imf.lineno, imf.end_lineno, imf.col_offset, imf.end_col_offset);
    }
    if isinstance(s, Global) {
        gl = s as Global;
        return nloc(gl.lineno, gl.end_lineno, gl.col_offset, gl.end_col_offset);
    }
    if isinstance(s, Nonlocal) {
        nl = s as Nonlocal;
        return nloc(nl.lineno, nl.end_lineno, nl.col_offset, nl.end_col_offset);
    }
    if isinstance(s, Pass) {
        ps = s as Pass;
        return nloc(ps.lineno, ps.end_lineno, ps.col_offset, ps.end_col_offset);
    }
    if isinstance(s, Break) {
        br = s as Break;
        return nloc(br.lineno, br.end_lineno, br.col_offset, br.end_col_offset);
    }
    if isinstance(s, Continue) {
        cn = s as Continue;
        return nloc(cn.lineno, cn.end_lineno, cn.col_offset, cn.end_col_offset);
    }
    if isinstance(s, FunctionDef) {
        fd = s as FunctionDef;
        return nloc(fd.lineno, fd.end_lineno, fd.col_offset, fd.end_col_offset);
    }
    if isinstance(s, AsyncFunctionDef) {
        afd = s as AsyncFunctionDef;
        return nloc(afd.lineno, afd.end_lineno, afd.col_offset, afd.end_col_offset);
    }
    if isinstance(s, ClassDef) {
        cd = s as ClassDef;
        return nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset);
    }
    if isinstance(s, If) {
        ii = s as If;
        return nloc(ii.lineno, ii.end_lineno, ii.col_offset, ii.end_col_offset);
    }
    if isinstance(s, While) {
        ww = s as While;
        return nloc(ww.lineno, ww.end_lineno, ww.col_offset, ww.end_col_offset);
    }
    if isinstance(s, For) {
        ff = s as For;
        return nloc(ff.lineno, ff.end_lineno, ff.col_offset, ff.end_col_offset);
    }
    if isinstance(s, AsyncFor) {
        af2 = s as AsyncFor;
        return nloc(af2.lineno, af2.end_lineno, af2.col_offset, af2.end_col_offset);
    }
    if isinstance(s, (Try, TryStar)) {
        tt = s as Try | TryStar;
        return nloc(tt.lineno, tt.end_lineno, tt.col_offset, tt.end_col_offset);
    }
    if isinstance(s, With) {
        wwi = s as With;
        return nloc(wwi.lineno, wwi.end_lineno, wwi.col_offset, wwi.end_col_offset);
    }
    if isinstance(s, AsyncWith) {
        awi = s as AsyncWith;
        return nloc(awi.lineno, awi.end_lineno, awi.col_offset, awi.end_col_offset);
    }
    if isinstance(s, Match) {
        mm = s as Match;
        return nloc(mm.lineno, mm.end_lineno, mm.col_offset, mm.end_col_offset);
    }
    return loc(1, 1, 0, 0);
}

def ann_collect_stmts(plan: ann_scope_plan, stmts: list[stmt], cond_depth: int = 0) {
    # Try.orelse/finalbody (and other optional blocks) arrive as None when the
    # source omits them; nothing to collect.
    if stmts is None {
        return;
    }
    si = 0;
    while si < len(stmts) {
        ann_collect_stmt(plan, stmts[si], cond_depth);
        si = si + 1;
    }
}

def ann_collect_stmt(plan: ann_scope_plan, s: stmt, cond_depth: int) {
    if isinstance(s, AnnAssign) {
        an = s as AnnAssign;
        plan.any_annotation = True;
        if an.simple and isinstance(an.target, Name) {
            n = an.target as Name;
            cond = cond_depth > 0;
            if cond {
                plan.any_conditional = True;
            }
            plan.entries.append(
                ann_entry(
                    target=n.id,
                    annotation=an.annotation,
                    owner_lineno=an.lineno,
                    owner_col=an.col_offset,
                    index=len(plan.entries),
                    owner_loc=nloc(
                        an.lineno, an.end_lineno, an.col_offset, an.end_col_offset
                    ),
                    conditional=cond
                )
            );
        }
        return;
    }
    if isinstance(s, If) {
        i = s as If;
        ann_collect_stmts(plan, i.body, cond_depth + 1);
        ann_collect_stmts(plan, i.orelse, cond_depth + 1);
        return;
    }
    if isinstance(s, While) {
        w = s as While;
        ann_collect_stmts(plan, w.body, cond_depth + 1);
        ann_collect_stmts(plan, w.orelse, cond_depth + 1);
        return;
    }
    if isinstance(s, For) {
        f = s as For;
        ann_collect_stmts(plan, f.body, cond_depth + 1);
        ann_collect_stmts(plan, f.orelse, cond_depth + 1);
        return;
    }
    if isinstance(s, AsyncFor) {
        af = s as AsyncFor;
        ann_collect_stmts(plan, af.body, cond_depth + 1);
        ann_collect_stmts(plan, af.orelse, cond_depth + 1);
        return;
    }
    if isinstance(s, (Try, TryStar)) {
        # Finally-only Try arrives with handlers=None from the generated
        # parser (host CPython AST would carry []); treat it as no handlers,
        # same tolerance as the visit_try dispatch in compiler_exc.jac.
        t = s as Try | TryStar;
        ann_collect_stmts(plan, t.body, cond_depth + 1);
        if t.handlers is not None {
            hi = 0;
            while hi < len(t.handlers) {
                h = t.handlers[hi] as ExceptHandler;
                ann_collect_stmts(plan, h.body, cond_depth + 1);
                hi = hi + 1;
            }
        }
        ann_collect_stmts(plan, t.orelse, cond_depth + 1);
        ann_collect_stmts(plan, t.finalbody, cond_depth + 1);
        return;
    }
    if isinstance(s, With) {
        wi = s as With;
        ann_collect_stmts(plan, wi.body, cond_depth + 1);
        return;
    }
    if isinstance(s, AsyncWith) {
        awi = s as AsyncWith;
        ann_collect_stmts(plan, awi.body, cond_depth + 1);
        return;
    }
    if isinstance(s, Match) {
        m = s as Match;
        ci = 0;
        while ci < len(m.cases) {
            mc = m.cases[ci] as match_case;
            ann_collect_stmts(plan, mc.body, cond_depth + 1);
            ci = ci + 1;
        }
        return;
    }
}

def ann_entry_for(plan: ann_scope_plan, an: AnnAssign) -> ann_entry | None {
    ei = 0;
    while ei < len(plan.entries) {
        e = plan.entries[ei];
        if e.owner_lineno == an.lineno and e.owner_col == an.col_offset {
            return e;
        }
        ei = ei + 1;
    }
    return None;
}

# --- statement lowering ---------------------------------------------------

# Lower one AnnAssign. Scope dispatch:
#  - function locals: assignment side only (PEP 649 drops local annotations);
#  - class bodies: value store plus, for conditional entries only, a SET_ADD
#    registration into the __conditional_annotations__ cellvar. Bare Name
#    targets at the top level emit nothing -- their annotation lives solely
#    in the synthesized __annotate__ (built by finish_class_annotations).
#  - module scope: inline value store, then SET_ADD registration of the
#    annotation index into __conditional_annotations__. Attribute/subscript
#    targets never join the annotation dict -- they keep plain assignment
#    semantics (bare forms evaluate the target object and discard it).
def visit_ann_assign(
    g: cfg_builder, an: AnnAssign, plan: ann_scope_plan | None = None
) -> stmt_cont {
    aloc = stmt_loc(an as stmt);
    # Even an unevaluated annotation evaluates a bare attribute/subscript
    # target's component expressions, without loading the actual item.
    if an.value is None and not isinstance(an.target, Name) {
        ann_discard_target(g, an.target);
        return stmt_cont(loc=aloc);
    }
    if g.sym_top is not None and g.sym_top.block_type == "function" {
        if an.value is None {
            return stmt_cont(loc=aloc);
        }
        visit_expr(g, an.value);
        if codegen_busy(g) {
            return stmt_cont(loc=aloc);
        }
        tloc = ann_store_target_tos(g, an.target);
        return stmt_cont(loc=tloc);
    }
    if current_compile_flags() & 0x1000000 {
        if an.value is not None {
            visit_expr(g, an.value);
            if codegen_busy(g) {
                return stmt_cont(loc=aloc);
            }
            ann_store_target_tos(g, an.target);
        }
        if an.simple and isinstance(an.target, Name) {
            visit_expr(g, an.annotation);
            g.emit_op(OP_LOAD_NAME, g.u.add_name("__annotations__"), aloc);
            key = PyStr(t="str", val=codegen_mangle(g, an.target.id));
            g.emit_op(OP_LOAD_CONST, g.u.add_const(key), aloc);
            g.emit_op(OP_STORE_SUBSCR, 0, aloc);
        }
        return stmt_cont(loc=aloc);
    }
    if g.sym_top is not None and g.sym_top.block_type == "class" {
        if plan is None or not plan.is_class {
            codegen_fail(
                g,
                "SystemError",
                "class-scope annotation without a class annotation plan"
            );
            return stmt_cont(loc=aloc);
        }
        last = aloc;
        if an.value is not None {
            visit_expr(g, an.value);
            if codegen_busy(g) {
                return stmt_cont(loc=aloc);
            }
            last = ann_store_target_tos(g, an.target);
        }
        ent = ann_entry_for(plan, an);
        if ent is not None and ent.conditional {
            rloc = aloc;
            if ent.owner_loc is not None {
                rloc = ent.owner_loc;
            }
            cond_idx = localsplus_index(g, "__conditional_annotations__");
            g.emit_op(OP_LOAD_DEREF, cond_idx, rloc);
            ann_emit_index_int(g, ent.index, rloc);
            g.emit_op(OP_SET_ADD, 1, rloc);
            g.emit_op(OP_POP_TOP, 0, rloc);
            last = rloc;
        }
        return stmt_cont(loc=last);
    }
    if plan is None {
        codegen_fail(
            g, "SystemError", "module-scope annotation without an annotation plan"
        );
        return stmt_cont(loc=aloc);
    }
    ent = ann_entry_for(plan, an);
    if ent is None {
        if an.value is None {
            return stmt_cont(loc=aloc);
        }
        visit_expr(g, an.value);
        if codegen_busy(g) {
            return stmt_cont(loc=aloc);
        }
        tloc = ann_store_target_tos(g, an.target);
        return stmt_cont(loc=tloc);
    }
    last = aloc;
    if an.value is not None {
        visit_expr(g, an.value);
        if codegen_busy(g) {
            return stmt_cont(loc=aloc);
        }
        last = ann_store_target_tos(g, an.target);
    }
    rloc = aloc;
    if ent.owner_loc is not None {
        rloc = ent.owner_loc;
    }
    cond_idx = g.u.add_name("__conditional_annotations__");
    g.emit_op(OP_LOAD_NAME, cond_idx, rloc);
    ann_emit_index_int(g, ent.index, rloc);
    g.emit_op(OP_SET_ADD, 1, rloc);
    g.emit_op(OP_POP_TOP, 0, rloc);
    last = rloc;
    return stmt_cont(loc=last);
}

def ann_store_target_tos(g: cfg_builder, t: expr) -> cloc {
    import from jaclang.compiler.backends.py.jacpython.compiler_codegen {
        visit_store_target_tos
    }
    return visit_store_target_tos(g, t).loc;
}

def ann_discard_expression(g: cfg_builder, value: expr) {
    visit_expr(g, value);
    g.emit_op(OP_POP_TOP, 0, expr_loc(value));
}

def ann_discard_subscript(g: cfg_builder, value: expr) {
    if isinstance(value, Slice) {
        for part in [value.lower, value.upper, value.step] {
            if part is not None {
                ann_discard_expression(g, part);
            }
        }
    } elif isinstance(value, Tuple) {
        for part in value.elts {
            ann_discard_subscript(g, part);
        }
    } else {
        ann_discard_expression(g, value);
    }
}

def ann_discard_target(g: cfg_builder, target: expr) {
    if isinstance(target, (Attribute, Subscript)) {
        ann_discard_expression(g, target.value);
    }
    if isinstance(target, Subscript) {
        ann_discard_subscript(g, target.slice);
    }
}

# Small-int operand emission with CPython's dead-const rule: the FIRST
# 0..255 literal seen while the const pool is empty keeps a dead pool slot;
# later small ints are pure LOAD_SMALL_INT with no pool entry.
def ann_emit_index_int(g: cfg_builder, v: int, lc: cloc) {
    if v >= 0 and v <= 255 {
        if len(g.u.consts) == 0 {
            g.u.add_const(PyInt(t="int", val=v));
            g.u.dead_small_int_const = True;
        }
        g.emit_op(OP_LOAD_SMALL_INT, v, lc);
        return;
    }
    idx = g.u.add_const(PyInt(t="int", val=v));
    g.emit_op(OP_LOAD_CONST, idx, lc);
}

# --- scope-entry setup and end-of-unit finish ------------------------------

# Emit the scope-entry annotation machinery into the module unit (caller has
# already set u.cellvars and emitted MAKE_CELL + RESUME). The __annotate__
# LOAD_CONST/STORE_NAME placeholders carry oparg 0 until
# finish_module_annotations patches them post-body, mirroring the host's
# deferred const/name slot allocation.
def emit_module_annotation_setup(g: cfg_builder, plan: ann_scope_plan, lc: cloc) {
    if current_compile_flags() & 0x1000000 {
        if plan.any_annotation {
            g.emit_op(OP_BUILD_SET, 0, lc);
            g.emit_op(OP_STORE_NAME, g.u.add_name("__conditional_annotations__"), lc);
            g.emit_op(OP_SETUP_ANNOTATIONS, 0, lc);
        }
        return;
    }
    if len(plan.entries) > 0 {
        g.emit_op(OP_LOAD_CONST, 0, lc);
        plan.load_const_ins = g.cur.instrs[len(g.cur.instrs) - 1];
        g.emit_op(OP_MAKE_FUNCTION, 0, lc);
        g.emit_op(OP_STORE_NAME, 0, lc);
        plan.store_name_ins = g.cur.instrs[len(g.cur.instrs) - 1];
    }
    if plan.any_annotation {
        g.emit_op(OP_BUILD_SET, 0, lc);
        cond_idx = g.u.add_name("__conditional_annotations__");
        g.emit_op(OP_STORE_NAME, cond_idx, lc);
    }
}

# Build the synthetic __annotate__ code object now that the whole body (and
# its const/name pools) is emitted, then patch the two placeholder opargs.
def finish_module_annotations(g: cfg_builder, plan: ann_scope_plan) {
    if current_compile_flags() & 0x1000000 {
        return;
    }
    lci = plan.load_const_ins;
    if len(plan.entries) == 0 or lci is None {
        return;
    }
    sym = g.sym_top.annotation_scope if g.sym_top is not None else None;
    if sym is None {
        codegen_fail(g, "SystemError", "missing module annotation scope");
        return;
    }
    u_fn = build_annotate_fn_cfg(sym, plan, g.u.filename);
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return;
    }
    co = assemble(cfg_fn);
    co.varnames[0] = "format";
    g.u.nested_code_emitted = True;
    # Insert the code object after all statement-produced consts but before
    # any None the control-flow duplication enqueued mid-loop (host defers
    # the shared return-None to scope finalization, we cannot). Literal-None
    # predecessors remain a documented divergence.
    ci = len(g.u.consts);
    none_key = py_none().tp_hashkey();
    ni2 = 0;
    while ni2 < len(g.u.consts) {
        if hashkey_equal(g.u.consts[ni2].tp_hashkey(), none_key) {
            ci = ni2;
            break;
        }
        ni2 = ni2 + 1;
    }
    bi = 0;
    while bi < len(g.u.blocks) {
        ii2 = 0;
        blk = g.u.blocks[bi];
        while ii2 < len(blk.instrs) {
            ins = blk.instrs[ii2];
            if ins.opcode == OP_LOAD_CONST
                and ins.oparg >= ci
                and ins != plan.load_const_ins {
                ins.oparg = ins.oparg + 1;
            }
            ii2 = ii2 + 1;
        }
        bi = bi + 1;
    }
    g.u.consts.append(co);
    ri = len(g.u.consts) - 1;
    while ri > ci {
        g.u.consts[ri] = g.u.consts[ri - 1];
        ri = ri - 1;
    }
    g.u.consts[ci] = co;
    ni = g.u.add_name("__annotate__");
    lci.oparg = ci;
    sni = plan.store_name_ins;
    if sni is not None {
        sni.oparg = ni;
    }
}

# Class-scope entry setup: the conditional-annotation set cell (present only
# when at least one entry sits under control flow) is seeded right after the
# prologue's LOAD_LOCALS/STORE_DEREF __classdict__. The caller has already
# appended "__conditional_annotations__" to u.cellvars so MAKE_CELL ran for it.
def emit_class_annotation_setup(g: cfg_builder, plan: ann_scope_plan, lc: cloc) {
    if current_compile_flags() & 0x1000000 {
        if plan.any_annotation {
            g.emit_op(OP_SETUP_ANNOTATIONS, 0, lc);
        }
        return;
    }
    if not plan.any_conditional {
        return;
    }
    g.emit_op(OP_BUILD_SET, 0, lc);
    clp = localsplus_index(g, "__conditional_annotations__");
    g.emit_op(OP_STORE_DEREF, clp, lc);
}

# Build the class's synthetic __annotate__ code object and emit the closure
# block that stores it as __annotate_func__ (LOAD_FAST_BORROW cells,
# BUILD_TUPLE, LOAD_CONST <code>, MAKE_FUNCTION, SET_FUNCTION_ATTRIBUTE 8,
# STORE_NAME). Runs AFTER the body loop but BEFORE the epilogue, so the code
# object's const lands after all statement consts yet before the epilogue's
# ()/None -- matching CPython, which compiles the annotate fn during class
# finalization. Unlike the module path, no placeholder patching is needed:
# appending to the const pool here is already in host order (class bodies
# cannot contain return statements, so no duplicated return-None joins exist).
def finish_class_annotations(g: cfg_builder, plan: ann_scope_plan) {
    if current_compile_flags() & 0x1000000 {
        return;
    }
    if len(plan.entries) == 0 {
        return;
    }
    sym = g.sym_top.annotation_scope if g.sym_top is not None else None;
    if sym is None {
        codegen_fail(g, "SystemError", "missing class annotation scope");
        return;
    }
    u_fn = build_annotate_fn_cfg(sym, plan, g.u.filename, True, g.private);
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return;
    }
    co = assemble(cfg_fn);
    co.varnames[0] = "format";
    g.u.nested_code_emitted = True;
    bloc = plan.head_loc;
    if bloc is None {
        bloc = no_loc();
    }
    for name in co.freevars {
        g.emit_op(OP_LOAD_FAST_BORROW, localsplus_index(g, name), bloc);
    }
    g.emit_op(OP_BUILD_TUPLE, len(co.freevars), bloc);
    ci = g.u.add_const(co);
    g.emit_op(OP_LOAD_CONST, ci, bloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, bloc);
    g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, bloc);
    aidx = g.u.add_name("__annotate_func__");
    g.emit_op(OP_STORE_NAME, aidx, bloc);
}

# --- nested __annotate__ code object ---------------------------------------

# Build __annotate__(format) using the analyzed annotation scope, including
# comprehension storage and captured locals. Module entries consult the
# conditional set; class entries do so only when they are conditional.
def build_annotate_fn_cfg(
    sym: sym_block,
    plan: ann_scope_plan,
    filename: str,
    class_mode: bool = False,
    private: str | None = None
) -> unverified_cfg {
    qualname = "__annotate__";
    if class_mode {
        qualname = plan.owner_qualname + ".__annotate__";
    }
    u = unverified_cfg(
        filename=filename,
        name="__annotate__",
        qualname=qualname,
        firstlineno=plan.body_first_lineno
    );
    u.argcount = 1;
    u.posonlyargcount = 1;
    u.param_count = 1;
    u.flags = CO_OPTIMIZED | CO_NEWLOCALS;
    u.freevars = freevars_from_sym(sym);
    u.cellvars = cellvars_from_sym(sym);
    if sym.nested {
        u.flags |= CO_NESTED;
    }
    if class_mode {
        if plan.nested_class {
            u.flags = u.flags | CO_NESTED;
        }
        if "__classdict__" not in u.freevars {
            u.freevars.append("__classdict__");
        }
        if plan.any_conditional {
            u.freevars.append("__conditional_annotations__");
        }
        u.classdict_names = True;
    }
    u.varnames = fast_varnames_from_sym(sym);
    hloc = plan.head_loc;
    if hloc is None {
        hloc = no_loc();
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym, private);
    ploc = loc(plan.body_first_lineno, plan.body_first_lineno, 0, 0);
    if u.freevars {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), no_loc());
    }
    for name in sym_block_tuple_names(sym.symbols, SCOPE_CELL) {
        g.emit_op(OP_MAKE_CELL, localsplus_index_u(u, name), no_loc());
    }
    g.emit_op(OP_RESUME, 0, ploc);
    # Higher annotation formats are delegated back to annotationlib by
    # raising NotImplementedError when format > 2. Guard, BUILD_MAP,
    # STORE_SUBSCR and RETURN_VALUE all carry the scope-head location; only
    # the annotation expression's own instructions carry their spans.
    g.emit_op(OP_LOAD_FAST, 0, hloc);
    ann_emit_index_int(g, 2, hloc);
    g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GT), hloc);
    after = g.new_block();
    g.emit_jump(OP_POP_JUMP_IF_FALSE, after.id, hloc);
    g.emit_op(OP_LOAD_COMMON_CONSTANT, 1, hloc);
    g.emit_op(OP_RAISE_VARARGS, 1, hloc);
    g.use(after);
    g.emit_op(OP_BUILD_MAP, 0, hloc);
    ei = 0;
    while ei < len(plan.entries) {
        e = plan.entries[ei];
        eloc = e.owner_loc;
        if eloc is None {
            eloc = expr_loc(e.annotation);
        }
        checked = (not class_mode and not plan.function_annotation) or e.conditional;
        nb: basicblock | None = None;
        if checked {
            ann_emit_index_int(g, e.index, eloc);
            if class_mode {
                clp2 = localsplus_index_u(u, "__conditional_annotations__");
                g.emit_op(OP_LOAD_DEREF, clp2, eloc);
            } else {
                cond_idx = u.add_name("__conditional_annotations__");
                g.emit_op(OP_LOAD_GLOBAL, cond_idx << 1, eloc);
            }
            g.emit_op(OP_CONTAINS_OP, 0, eloc);
            nb = g.new_deferred_block();
            g.emit_jump(OP_POP_JUMP_IF_FALSE, nb.id, eloc);
        }
        visit_expr(g, e.annotation);
        if codegen_busy(g) {
            return u;
        }
        g.emit_op(OP_COPY, 2, eloc);
        tidx = u.add_const(PyStr(t="str", val=codegen_mangle(g, e.target)));
        g.emit_op(OP_LOAD_CONST, tidx, eloc);
        g.emit_op(OP_STORE_SUBSCR, 0, hloc);
        if nb is not None {
            g.use(nb);
        }
        ei = ei + 1;
    }
    g.emit_op(OP_RETURN_VALUE, 0, hloc);
    return u;
}

# Every free name in an annotation expression resolves global-implicit inside
# __annotate__. Binding forms (walrus/lambda/comprehensions/yield) would need
# their own scopes or locals -- report them so the unit fails loudly instead
# of emitting silently-wrong bytes.
def ann_synthetic_sym(plan: ann_scope_plan) -> sym_block | None {
    sym = sym_block(
        block_type="function",
        name="__annotate__",
        lineno=plan.body_first_lineno,
        col_offset=0,
        varnames=["format"]
    );
    ei = 0;
    while ei < len(plan.entries) {
        err = ann_mark_names(sym, plan.entries[ei].annotation);
        if err is not None {
            return None;
        }
        ei = ei + 1;
    }
    return sym;
}

def ann_mark_global(sym: sym_block, name: str) {
    if sym_dict_get(sym.symbols, name, -1) == -1 {
        sym.symbols[name] = sym_set_scope(0, SCOPE_GLOBAL_IMPLICIT) | SYM_USE;
    }
}

# Returns None on success or a trap message for unsupported constructs.
def ann_mark_names(sym: sym_block, e: expr) -> str | None {
    if isinstance(e, Name) {
        ann_mark_global(sym, (e as Name).id);
        return None;
    }
    if isinstance(e, Constant) {
        return None;
    }
    if isinstance(e, Slice) {
        sl = e as Slice;
        if sl.lower is not None {
            return ann_mark_names(sym, sl.lower);
        }
        if sl.upper is not None {
            return ann_mark_names(sym, sl.upper);
        }
        if sl.step is not None {
            return ann_mark_names(sym, sl.step);
        }
        return None;
    }
    if isinstance(e, Attribute) {
        return ann_mark_names(sym, (e as Attribute).value);
    }
    if isinstance(e, Subscript) {
        su = e as Subscript;
        err = ann_mark_names(sym, su.value);
        if err is not None {
            return err;
        }
        return ann_mark_names(sym, su.slice);
    }
    if isinstance(e, Tuple) {
        return ann_mark_elts(sym, (e as Tuple).elts);
    }
    if isinstance(e, List) {
        return ann_mark_elts(sym, (e as List).elts);
    }
    if isinstance(e, Set) {
        se = e as Set;
        return ann_mark_elts(sym, se.elts);
    }
    if isinstance(e, Dict) {
        d = e as Dict;
        err = ann_mark_elts(sym, d.keys);
        if err is not None {
            return err;
        }
        return ann_mark_elts(sym, d.values);
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        err = ann_mark_names(sym, b.left);
        if err is not None {
            return err;
        }
        return ann_mark_names(sym, b.right);
    }
    if isinstance(e, UnaryOp) {
        return ann_mark_names(sym, (e as UnaryOp).operand);
    }
    if isinstance(e, BoolOp) {
        return ann_mark_elts(sym, (e as BoolOp).values);
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        err = ann_mark_names(sym, c.left);
        if err is not None {
            return err;
        }
        return ann_mark_elts(sym, c.comparators);
    }
    if isinstance(e, Call) {
        ca = e as Call;
        err = ann_mark_names(sym, ca.func);
        if err is not None {
            return err;
        }
        err = ann_mark_elts(sym, ca.args);
        if err is not None {
            return err;
        }
        ki = 0;
        while ki < len(ca.keywords) {
            err = ann_mark_names(sym, ca.keywords[ki].value);
            if err is not None {
                return err;
            }
            ki = ki + 1;
        }
        return None;
    }
    if isinstance(e, IfExp) {
        ie = e as IfExp;
        err = ann_mark_names(sym, ie.`test);
        if err is not None {
            return err;
        }
        err = ann_mark_names(sym, ie.body);
        if err is not None {
            return err;
        }
        return ann_mark_names(sym, ie.orelse);
    }
    if isinstance(e, Starred) {
        return ann_mark_names(sym, (e as Starred).value);
    }
    if isinstance(e, TemplateStr) {
        ts = e as TemplateStr;
        vi = 0;
        while vi < len(ts.values) {
            err = ann_mark_names(sym, ts.values[vi]);
            if err is not None {
                return err;
            }
            vi = vi + 1;
        }
        return None;
    }
    if isinstance(e, JoinedStr) {
        js = e as JoinedStr;
        vi = 0;
        while vi < len(js.values) {
            err = ann_mark_names(sym, js.values[vi]);
            if err is not None {
                return err;
            }
            vi = vi + 1;
        }
        return None;
    }
    if isinstance(e, Interpolation) {
        ip = e as Interpolation;
        err = ann_mark_names(sym, ip.value);
        if err is not None {
            return err;
        }
        if ip.format_spec is not None {
            return ann_mark_names(sym, ip.format_spec);
        }
        return None;
    }
    if isinstance(e, FormattedValue) {
        fv = e as FormattedValue;
        err = ann_mark_names(sym, fv.value);
        if err is not None {
            return err;
        }
        if fv.format_spec is not None {
            return ann_mark_names(sym, fv.format_spec as expr);
        }
        return None;
    }
    return ann_unsupported_in_annotation(e);
}

def ann_mark_elts(sym: sym_block, elts: list[expr | None]) -> str | None {
    ei = 0;
    while ei < len(elts) {
        elt = elts[ei];
        if elt is not None {
            err = ann_mark_names(sym, elt as expr);
            if err is not None {
                return err;
            }
        }
        ei = ei + 1;
    }
    return None;
}

def ann_unsupported_in_annotation(e: expr) -> str {
    kind = "construct";
    if isinstance(e, Lambda) {
        kind = "lambda";
    } elif isinstance(e, ListComp) {
        kind = "list comprehension";
    } elif isinstance(e, SetComp) {
        kind = "set comprehension";
    } elif isinstance(e, DictComp) {
        kind = "dict comprehension";
    } elif isinstance(e, GeneratorExp) {
        kind = "generator expression";
    } elif isinstance(e, NamedExpr) {
        kind = "named expression";
    } elif isinstance(e, Yield) or isinstance(e, YieldFrom) {
        kind = "yield";
    } elif isinstance(e, Await) {
        kind = "await";
    }
    return "unsupported " + kind + " inside deferred annotation";
}

# PEP 563 annotations use the retained stdlib AST unparser. The compiler still
# owns parsing and validation; no call to Python compile/eval is involved.
def stringify_future_annotations(tree: ast_node, filename: str) {
    import from jaclang.compiler.frontend.python.ast_bridge { to_python_ast }
    import from jaclang.compiler.backends.py.jacpython.code_object { constant_value }
    pending: list[ast_node] = [tree];
    while pending {
        item = pending.pop();
        fields: list[str] = [];
        if isinstance(item, (arg, AnnAssign)) {
            fields.append("annotation");
        } elif isinstance(item, (FunctionDef, AsyncFunctionDef)) {
            fields.append("returns");
        }
        for field in fields {
            value = vars(item).get(field);
            if isinstance(value, expr) {
                rendered = annotation_unparser().visit(
                    to_python_ast(value, constant_value)
                ) as str;
                replacement = Constant(
                    value=PyStr(t="str", val=rendered),
                    kind=None,
                    lineno=value.lineno,
                    col_offset=value.col_offset,
                    end_lineno=value.end_lineno,
                    end_col_offset=value.end_col_offset
                );
                setattr(item, field, replacement);
            }
        }
        for value in vars(item).values() {
            if isinstance(value, ast_node) {
                pending.append(value);
            } elif isinstance(value, list) {
                pending.extend(
                    child
                    for child in value
                    if isinstance(child, ast_node)
                );
            }
        }
    }
}

# Function annotations remain lazy even with the future enabled in 3.14:
# __annotate__ returns the strings for formats VALUE and FORWARDREF.
def emit_future_function_annotations(
    g: cfg_builder, fd: FunctionDef | AsyncFunctionDef
) {
    if not (current_compile_flags() & 0x1000000) {
        return;
    }
    plan = ann_scope_plan(
        function_annotation=True, body_first_lineno=fd.lineno, head_loc=stmt_loc(fd)
    );
    parameters = fd.args.posonlyargs + fd.args.args;
    if fd.args.vararg is not None {
        parameters.append(fd.args.vararg);
    }
    parameters.extend(fd.args.kwonlyargs);
    if fd.args.kwarg is not None {
        parameters.append(fd.args.kwarg);
    }
    pairs: list[tuple[str, expr]] = [];
    for parameter in parameters {
        if parameter.annotation is not None {
            pairs.append((codegen_mangle(g, parameter.arg), parameter.annotation));
        }
    }
    if fd.returns is not None {
        pairs.append(("return", fd.returns));
    }
    for (name, annotation) in pairs {
        plan.entries.append(
            ann_entry(
                target=name,
                annotation=annotation,
                owner_lineno=fd.lineno,
                owner_col=fd.col_offset,
                index=len(plan.entries)
            )
        );
    }
    if not plan.entries {
        return;
    }
    sym = ann_synthetic_sym(plan);
    if sym is None {
        codegen_fail(g, "SystemError", "invalid stringized annotation");
        return;
    }
    unit = build_annotate_fn_cfg(sym, plan, g.u.filename);
    if g.sym_top is not None {
        if g.sym_top.block_type == "function" {
            unit.qualname = g.u.qualname + ".<locals>.__annotate__";
        } elif g.sym_top.block_type == "class" {
            unit.qualname = g.u.qualname + ".__annotate__";
        }
        if g.sym_top.block_type == "function" or g.sym_top.nested {
            unit.flags |= CO_NESTED;
        }
    }
    cfg = verify_cfg(unit);
    if cfg.diag is not None {
        g.u.diag = cfg.diag;
        return;
    }
    code = assemble(cfg);
    lc = stmt_loc(fd);
    g.emit_op(OP_LOAD_CONST, g.u.add_const(code), lc);
    g.emit_op(OP_MAKE_FUNCTION, 0, lc);
    g.emit_op(OP_SWAP, 2, lc);
    g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 16, lc);
}
