# PEP 649 (CPython 3.14) deferred annotations for MODULE scope.
#
# A module-scope annotated assignment never evaluates the annotation inline.
# The scope gains a cellvar __conditional_annotations__ (a set of annotation
# indices), a synthetic __annotate__(format) code object that builds the
# {name: value} dict on demand, and per-statement SET_ADD registration bytes.
# Function-local AnnAssign stays assignment-only (annotations vanish), and
# class bodies still trap until the __classdict__ closure plumbing lands.
#
# Byte-shape notes pinned against the host oracle (b11_annotations goldens):
#   - Setup bytes sit at scope entry (right after RESUME): optional
#     LOAD_CONST <code>/MAKE_FUNCTION/STORE_NAME __annotate__, then
#     BUILD_SET 0/STORE_NAME __conditional_annotations__. But the __annotate__
#     const/name table slots are only allocated AFTER the whole body has been
#     visited -- the oracle's consts/names order proves CPython defers the
#     resolution, so we patch the two placeholder instructions at end of unit.
#   - The nested __annotate__ code object: flags OPTIMIZED|NEWLOCALS,
#     varnames ['format'] positional-only, consts ['2' dead slot, target
#     names...]; body is a format>2 guard raising NotImplementedError, then
#     BUILD_MAP 0 plus one guarded COPY/STORE_SUBSCR entry per annotation.

import from objects { PyStr, PyInt }
import from opcode_meta {
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
    CMP_GT,
    CO_OPTIMIZED,
    CO_NEWLOCALS,
    compare_oparg,
}
import from ast_nodes {
    stmt,
    expr,
    AnnAssign,
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
    With,
    AsyncWith,
    Match,
    ExceptHandler,
    match_case,
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
import from compiler_ir {
    cloc,
    cinstr,
    cfg_builder,
    unverified_cfg,
    loc,
    new_cfg_builder,
}
import from codegen_util { expr_loc, stmt_loc }
import from compiler_symtable {
    sym_block,
    sym_dict_get,
    SCOPE_GLOBAL_IMPLICIT,
    SYM_USE,
    sym_set_scope,
}
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from compiler_emit {
    visit_expr,
    visit_subscript_index,
    codegen_mangle,
    fast_local_index,
    codegen_fail,
    codegen_busy,
}

# One deferred annotation: an annotated name plus its expression, in
# construction order (the index baked into the SET_ADD registration).
obj ann_entry {
    has target: str,
        annotation: expr,
        owner_lineno: int,
        owner_col: int,
        index: int;
}

# Per-scope plan shared by the setup emitter, the per-statement visitor, and
# the end-of-unit nested-code builder. load_const_ins / store_name_ins are
# the placeholder instructions whose opargs are patched once the synthesized
# __annotate__ PyCode exists.
obj ann_scope_plan {
    has entries: list[ann_entry] = [],
        any_annotation: bool = False,
        body_first_lineno: int = 1,
        load_const_ins: cinstr | None = None,
        store_name_ins: cinstr | None = None;
}

# --- planning -------------------------------------------------------------

# Deep-collect the module scope's annotated assignments in source order.
# Descends into same-scope control flow (If/While/For/Try/With/Match);
# never enters function/class bodies (they own their scopes).
def collect_ann_plan(body: list[stmt]) -> ann_scope_plan {
    plan = ann_scope_plan();
    if len(body) > 0 {
        plan.body_first_lineno = stmt_loc(body[0]).lineno;
    }
    ann_collect_stmts(plan, body);
    return plan;
}

def ann_collect_stmts(plan: ann_scope_plan, stmts: list[stmt]) {
    si = 0;
    while si < len(stmts) {
        ann_collect_stmt(plan, stmts[si]);
        si = si + 1;
    }
}

def ann_collect_stmt(plan: ann_scope_plan, s: stmt) {
    if isinstance(s, AnnAssign) {
        an = s as AnnAssign;
        plan.any_annotation = True;
        if isinstance(an.target, Name) {
            n = an.target as Name;
            plan.entries.append(
                ann_entry(
                    target=n.id,
                    annotation=an.annotation,
                    owner_lineno=an.lineno,
                    owner_col=an.col_offset,
                    index=len(plan.entries)
                )
            );
        }
        return;
    }
    if isinstance(s, If) {
        i = s as If;
        ann_collect_stmts(plan, i.body);
        ann_collect_stmts(plan, i.orelse);
        return;
    }
    if isinstance(s, While) {
        w = s as While;
        ann_collect_stmts(plan, w.body);
        ann_collect_stmts(plan, w.orelse);
        return;
    }
    if isinstance(s, For) {
        f = s as For;
        ann_collect_stmts(plan, f.body);
        ann_collect_stmts(plan, f.orelse);
        return;
    }
    if isinstance(s, AsyncFor) {
        af = s as AsyncFor;
        ann_collect_stmts(plan, af.body);
        ann_collect_stmts(plan, af.orelse);
        return;
    }
    if isinstance(s, Try) {
        t = s as Try;
        ann_collect_stmts(plan, t.body);
        hi = 0;
        while hi < len(t.handlers) {
            h = t.handlers[hi] as ExceptHandler;
            ann_collect_stmts(plan, h.body);
            hi = hi + 1;
        }
        ann_collect_stmts(plan, t.orelse);
        ann_collect_stmts(plan, t.finalbody);
        return;
    }
    if isinstance(s, With) {
        wi = s as With;
        ann_collect_stmts(plan, wi.body);
        return;
    }
    if isinstance(s, AsyncWith) {
        awi = s as AsyncWith;
        ann_collect_stmts(plan, awi.body);
        return;
    }
    if isinstance(s, Match) {
        m = s as Match;
        ci = 0;
        while ci < len(m.cases) {
            mc = m.cases[ci] as match_case;
            ann_collect_stmts(plan, mc.body);
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
#  - class bodies: loud trap until the __classdict__/__annotate_func__
#    closure plumbing lands;
#  - module scope: inline value store, then SET_ADD registration of the
#    annotation index into __conditional_annotations__. Attribute/subscript
#    targets never join the annotation dict -- they keep plain assignment
#    semantics (bare forms evaluate the target object and discard it).
def visit_ann_assign(
    g: cfg_builder, an: AnnAssign, plan: ann_scope_plan | None = None
) -> stmt_cont {
    aloc = stmt_loc(an as stmt);
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
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        codegen_fail(
            g,
            "NotImplementedError",
            "class-scope annotation (__annotate__) not yet supported"
        );
        return stmt_cont(loc=aloc);
    }
    if plan is None {
        codegen_fail(
            g,
            "SystemError",
            "module-scope annotation without an annotation plan"
        );
        return stmt_cont(loc=aloc);
    }
    ent = ann_entry_for(plan, an);
    if ent is None {
        if an.value is None {
            tvloc = ann_target_value_loc(an);
            visit_expr(g, ann_target_value(an));
            g.emit_op(OP_POP_TOP, 0, tvloc);
            return stmt_cont(loc=tvloc);
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
    cond_idx = g.u.add_name("__conditional_annotations__");
    g.emit_op(OP_LOAD_NAME, cond_idx, rloc);
    ann_emit_index_int(g, ent.index, rloc);
    g.emit_op(OP_SET_ADD, 1, rloc);
    g.emit_op(OP_POP_TOP, 0, rloc);
    return stmt_cont(loc=last);
}

def ann_store_target_tos(g: cfg_builder, t: expr) -> cloc {
    if isinstance(t, Name) {
        n = t as Name;
        tloc = expr_loc(n);
        name = codegen_mangle(g, n.id);
        fi = fast_local_index(g, name);
        if fi >= 0 {
            g.emit_op(OP_STORE_FAST, fi, tloc);
            return tloc;
        }
        idx = g.u.add_name(name);
        g.emit_op(OP_STORE_NAME, idx, tloc);
        return tloc;
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        visit_expr(g, a.value);
        idx = g.u.add_name(codegen_mangle(g, a.attr));
        tloc = expr_loc(a);
        g.emit_op(OP_STORE_ATTR, idx, tloc);
        return tloc;
    }
    if isinstance(t, Subscript) {
        su = t as Subscript;
        if isinstance(su.slice, Slice) {
            codegen_fail(
                g,
                "NotImplementedError",
                "slice-subscript annotated-assignment target not supported"
            );
            return expr_loc(su);
        }
        sloc = expr_loc(su);
        visit_expr(g, su.value);
        visit_subscript_index(g, su.slice, sloc);
        g.emit_op(OP_STORE_SUBSCR, 0, sloc);
        return sloc;
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported annotated-assignment target kind"
    );
    return expr_loc(t);
}

def ann_target_value(an: AnnAssign) -> expr {
    if isinstance(an.target, Attribute) {
        return (an.target as Attribute).value;
    }
    return (an.target as Subscript).value;
}

def ann_target_value_loc(an: AnnAssign) -> cloc {
    return expr_loc(ann_target_value(an));
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
    lci = plan.load_const_ins;
    if len(plan.entries) == 0 or lci is None {
        return;
    }
    sym = ann_synthetic_sym(plan);
    if sym is None {
        codegen_fail(
            g,
            "NotImplementedError",
            "unsupported construct inside deferred annotation"
        );
        return;
    }
    u_fn = build_annotate_fn_cfg(sym, plan, g.u.filename);
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return;
    }
    co = assemble(cfg_fn);
    g.u.nested_code_emitted = True;
    ci = g.u.add_const(co);
    ni = g.u.add_name("__annotate__");
    lci.oparg = ci;
    sni = plan.store_name_ins;
    if sni is not None {
        sni.oparg = ni;
    }
}

# --- nested __annotate__ code object ---------------------------------------

# Synthetic function scope for __annotate__: sole parameter `format`, every
# other name global-implicit (the host looks up annotation names and
# __conditional_annotations__ with LOAD_GLOBAL at module scope).
def build_annotate_fn_cfg(
    sym: sym_block, plan: ann_scope_plan, filename: str
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename,
        name="__annotate__",
        qualname="__annotate__",
        firstlineno=plan.body_first_lineno
    );
    u.argcount = 1;
    u.posonlyargcount = 1;
    u.flags = CO_OPTIMIZED | CO_NEWLOCALS;
    u.varnames = ["format"];
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym);
    ploc = loc(0, plan.body_first_lineno, 0, 0);
    g.emit_op(OP_RESUME, 0, ploc);
    # format guard: raise NotImplementedError when format > 2 (formats 0 and
    # 1 are the only ones PEP 749 defines today).
    g.emit_op(OP_LOAD_FAST, 0, ploc);
    ann_emit_index_int(g, 2, ploc);
    g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GT), ploc);
    after = g.new_block();
    g.emit_jump(OP_POP_JUMP_IF_FALSE, after.id, ploc);
    g.emit_op(OP_LOAD_COMMON_CONSTANT, 1, ploc);
    g.emit_op(OP_RAISE_VARARGS, 1, ploc);
    g.use(after);
    g.emit_op(OP_BUILD_MAP, 0, ploc);
    ei = 0;
    last_loc = ploc;
    while ei < len(plan.entries) {
        e = plan.entries[ei];
        eloc = expr_loc(e.annotation);
        g.emit_op(OP_LOAD_SMALL_INT, e.index, eloc);
        cond_idx = u.add_name("__conditional_annotations__");
        g.emit_op(OP_LOAD_GLOBAL, cond_idx << 1, eloc);
        g.emit_op(OP_CONTAINS_OP, 0, eloc);
        nb = g.new_block();
        g.emit_jump(OP_POP_JUMP_IF_FALSE, nb.id, eloc);
        visit_expr(g, e.annotation);
        if codegen_busy(g) {
            return u;
        }
        g.emit_op(OP_COPY, 2, eloc);
        tidx = u.add_const(PyStr(t="str", val=e.target));
        g.emit_op(OP_LOAD_CONST, tidx, eloc);
        g.emit_op(OP_STORE_SUBSCR, 0, eloc);
        last_loc = eloc;
        g.use(nb);
        ei = ei + 1;
    }
    g.emit_op(OP_RETURN_VALUE, 0, last_loc);
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
        col_offset=0
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
