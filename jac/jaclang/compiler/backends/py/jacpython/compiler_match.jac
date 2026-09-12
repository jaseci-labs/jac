# Match-statement codegen extracted from compiler_codegen.jac.
# Pure mechanical move; see compiler_codegen.jac for the module-initialization
# ordering contract.

import from jaclang.runtime.python.objects {
    PyInt,
    PyObj,
    PyStr,
    PyTuple,
    hashkey_equal,
}
import from jaclang.runtime.python.opcode_meta {
    CMP_EQ,
    CMP_GE,
    NB_SUBSCR,
    NB_SUBTRACT,
    OP_BINARY_OP,
    OP_BUILD_MAP,
    OP_BUILD_TUPLE,
    OP_COMPARE_OP,
    OP_COPY,
    OP_DELETE_SUBSCR,
    OP_DICT_UPDATE,
    OP_GET_LEN,
    OP_IS_OP,
    OP_JUMP_FORWARD,
    OP_LOAD_CONST,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_MATCH_CLASS,
    OP_MATCH_KEYS,
    OP_MATCH_MAPPING,
    OP_MATCH_SEQUENCE,
    OP_NOP,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_TOP,
    OP_STORE_FAST_STORE_FAST,
    OP_SWAP,
    OP_UNPACK_EX,
    OP_UNPACK_SEQUENCE,
    compare_filter_oparg,
    compare_oparg,
}
import from jaclang.compiler.frontend.python.ast_nodes {
    Attribute,
    Constant,
    Match,
    MatchAs,
    MatchClass,
    MatchMapping,
    MatchOr,
    MatchSequence,
    MatchSingleton,
    MatchStar,
    MatchValue,
    Name,
    expr,
    pattern,
    stmt,
}
import from jaclang.compiler.backends.py.jacpython.compiler_ir {
    basicblock,
    cfg_builder,
    cloc,
    loc,
    stmt_cont,
}
import from jaclang.compiler.backends.py.jacpython.flowgraph { optimize_swap_range }
import from jaclang.compiler.backends.py.jacpython.compiler_emit {
    codegen_busy,
    codegen_fail,
    codegen_mangle,
    emit_branch_if_test_false,
    fast_local_index,
    visit_expr,
    visit_test_expr,
}
import from jaclang.compiler.backends.py.jacpython.codegen_util {
    exec_tail_emits_code,
    expr_loc,
    match_pattern_loc,
    match_pattern_unwrap_or,
    match_pattern_wildcard,
    nloc,
    stmt_loc,
}
import from jaclang.compiler.backends.py.jacpython.compiler_annotations {
    ann_scope_plan
}
import from jaclang.compiler.backends.py.jacpython.compiler_codegen {
    emit_module_return,
    emit_name_store,
    visit_stmt_tail,
    visit_stmts
}
import from jaclang.compiler.backends.py.jacpython.compiler_dispatch { stmt_handlers }
obj match_pat_ctx {
    has stores: list[str],
        on_top: int,
        cleanup_blocks: list[basicblock],
        max_cleanup: int,
        allow_irrefutable: bool;
}


def match_subject_use_load_fast(g: cfg_builder, m: Match) -> bool {
    has_default = 0;
    if len(m.cases) > 1 {
        if match_pattern_wildcard(m.cases[len(m.cases) - 1].pattern) {
            has_default = 1;
        }
    }
    if len(m.cases) - has_default > 1 {
        return True;
    }
    ci = 0;
    while ci < len(m.cases) {
        raw = m.cases[ci].pattern;
        if isinstance(raw, MatchOr) and len((raw as MatchOr).patterns) > 1 {
            # Multi-alternative OR copies the subject per alternative, so it must
            # be owned (LOAD_FAST), not borrowed.
            return True;
        }
        p = match_pattern_unwrap_or(raw);
        if isinstance(p, MatchSequence) or isinstance(p, MatchMapping) {
            return True;
        }
        ci = ci + 1;
    }
    return False;
}


def match_emit_subject(g: cfg_builder, m: Match) {
    subj = m.subject;
    if isinstance(subj, Name) {
        n = subj as Name;
        tloc = nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset);
        name = codegen_mangle(g, n.id);
        fi = fast_local_index(g, name);
        if fi >= 0 {
            if match_subject_use_load_fast(g, m) {
                g.emit_op(OP_LOAD_FAST, fi, tloc);
            } else {
                g.emit_op(OP_LOAD_FAST_BORROW, fi, tloc);
            }
            return;
        }
    }
    visit_expr(g, subj);
}


obj match_case_start {
    has ctx: match_pat_ctx,
        next_arm: basicblock;
}


# Failure cleanup blocks are allocated on demand and placed after the arm.
# Each block pops one item, then falls through to the next smaller cleanup.
def match_begin_case(g: cfg_builder) -> match_case_start {
    # Deferred blocks: laid out at use() (CPython USE_LABEL) so the fail-pop chain
    # and next_arm land after the arm body, and after any deferred blocks a MatchOr
    # alternative emits. Placement order (not allocation order) is authoritative.
    cleanup: list[basicblock] = [];
    next_arm = g.new_deferred_block();
    next_arm.exit_inline_ok = True;
    ctx = match_pat_ctx(
        stores=[],
        on_top=0,
        cleanup_blocks=cleanup,
        max_cleanup=0,
        allow_irrefutable=False
    );
    return match_case_start(ctx=ctx, next_arm=next_arm);
}


def match_ensure_cleanup_blocks(g: cfg_builder, ctx: match_pat_ctx, n: int) {
    while len(ctx.cleanup_blocks) < n {
        blk = g.new_deferred_block();
        blk.exit_inline_ok = True;
        ctx.cleanup_blocks.append(blk);
    }
}


def match_jump_to_fail(
    g: cfg_builder, ctx: match_pat_ctx, next_arm: basicblock, jump_op: int, loc: cloc
) {
    pops = ctx.on_top + len(ctx.stores);
    if pops > ctx.max_cleanup {
        ctx.max_cleanup = pops;
    }
    if pops == 0 {
        g.emit_jump(jump_op, next_arm.id, loc);
        return;
    }
    match_ensure_cleanup_blocks(g, ctx, pops);
    g.emit_jump(jump_op, ctx.cleanup_blocks[pops - 1].id, loc);
}


def match_emit_reset_fail_pop(
    g: cfg_builder, ctx: match_pat_ctx, next_arm: basicblock, loc: cloc
) {
    idx = ctx.max_cleanup - 1;
    while idx >= 0 {
        g.use(ctx.cleanup_blocks[idx]);
        g.emit_op(OP_POP_TOP, 0, loc);
        idx = idx - 1;
    }
    g.use(next_arm);
    ctx.max_cleanup = 0;
}


def match_pattern_rotate(g: cfg_builder, loc: cloc, count: int) {
    while count > 1 {
        g.emit_op(OP_SWAP, count, loc);
        count = count - 1;
    }
}


def match_pattern_helper_store_name(
    g: cfg_builder, name: str | None, ctx: match_pat_ctx, loc: cloc
) -> bool {
    if name is None {
        g.emit_op(OP_POP_TOP, 0, loc);
        return True;
    }
    si = 0;
    while si < len(ctx.stores) {
        if ctx.stores[si] == name {
            codegen_fail(g, "SyntaxError", "multiple assignments to name in pattern");
            return False;
        }
        si = si + 1;
    }
    rot = ctx.on_top + len(ctx.stores) + 1;
    match_pattern_rotate(g, loc, rot);
    ctx.stores.append(name);
    return True;
}


def match_emit_case_stores(g: cfg_builder, ctx: match_pat_ctx, loc: cloc) {
    # Emit separate stores in capture order; optimize_swap_range folds adjacent
    # STORE_FAST pairs into STORE_FAST_STORE_FAST (and reorders via static swaps)
    # to match CPython's post-optimizer shape.
    n = len(ctx.stores);
    si = 0;
    while si < n {
        emit_name_store(g, ctx.stores[si], loc);
        si = si + 1;
    }
}


def emit_match_pattern_sub(
    g: cfg_builder, p: pattern, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    allow = ctx.allow_irrefutable;
    ctx.allow_irrefutable = True;
    ok = emit_match_pattern(g, p, ctx, next_arm, ploc);
    ctx.allow_irrefutable = allow;
    return ok;
}


def emit_match_pattern_value(
    g: cfg_builder, mv: MatchValue, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    if not isinstance(mv.value, (Constant, Attribute)) {
        codegen_fail(
            g, "SyntaxError", "patterns may only match literals and attribute lookups"
        );
        return False;
    }
    visit_expr(g, mv.value);
    if codegen_busy(g) {
        return False;
    }
    oparg = compare_filter_oparg(CMP_EQ);
    g.emit_op(OP_COMPARE_OP, oparg, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    return True;
}


def emit_match_pattern_singleton(
    g: cfg_builder,
    ms: MatchSingleton,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    if ms.value is None {
        match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_NOT_NONE, ploc);
        return True;
    }
    idx = g.u.add_const(ms.value);
    g.emit_op(OP_LOAD_CONST, idx, ploc);
    g.emit_op(OP_IS_OP, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    return True;
}


def emit_match_pattern_as(
    g: cfg_builder, ma: MatchAs, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    if ma.pattern is None {
        if not ctx.allow_irrefutable {
            if ma.name is not None {
                codegen_fail(
                    g,
                    "SyntaxError",
                    "name capture makes remaining patterns unreachable"
                );
                return False;
            }
            codegen_fail(
                g, "SyntaxError", "wildcard makes remaining patterns unreachable"
            );
            return False;
        }
        return match_pattern_helper_store_name(g, ma.name, ctx, ploc);
    }
    ctx.on_top = ctx.on_top + 1;
    g.emit_op(OP_COPY, 1, ploc);
    if not emit_match_pattern(g, ma.pattern, ctx, next_arm, ploc) {
        return False;
    }
    ctx.on_top = ctx.on_top - 1;
    return match_pattern_helper_store_name(g, ma.name, ctx, ploc);
}


# CPython pattern_helper_sequence_subscr: used when the star element is a bare
# wildcard (`*_`). The tail is dropped, so the fixed elements are read off the
# subject by index (nonnegative before the star, len-relative after it) rather
# than unpacked. The subject stays on the stack and is popped at the end.
def emit_match_sequence_subscr(
    g: cfg_builder,
    patterns: list[pattern],
    star_idx: int,
    next_arm: basicblock,
    ctx: match_pat_ctx,
    ploc: cloc
) -> bool {
    size = len(patterns);
    pi = 0;
    while pi < size {
        if pi == star_idx {
            pi = pi + 1;
            continue;
        }
        pat = patterns[pi];
        if match_pattern_wildcard(pat) {
            pi = pi + 1;
            continue;
        }
        g.emit_op(OP_COPY, 1, ploc);
        if pi < star_idx {
            idx_const = g.u.add_const(PyInt(t="int", val=pi));
            g.emit_op(OP_LOAD_CONST, idx_const, ploc);
        } else {
            g.emit_op(OP_GET_LEN, 0, ploc);
            neg_const = g.u.add_const(PyInt(t="int", val=size - pi));
            g.emit_op(OP_LOAD_CONST, neg_const, ploc);
            g.emit_op(OP_BINARY_OP, NB_SUBTRACT, ploc);
        }
        g.emit_op(OP_BINARY_OP, NB_SUBSCR, ploc);
        # The element value sits on top with the subject preserved below. A plain
        # capture stores it immediately (CPython emits a bare STORE_FAST here, no
        # rotate); nested sub-patterns fall back to the general on-stack path.
        up = match_pattern_unwrap_or(pat);
        if isinstance(up, MatchAs) and (up as MatchAs).pattern is None {
            emit_name_store(g, (up as MatchAs).name as str, ploc);
        } else {
            ctx.on_top = ctx.on_top + 1;
            if not emit_match_pattern_sub(g, pat, ctx, next_arm, ploc) {
                return False;
            }
            ctx.on_top = ctx.on_top - 1;
        }
        pi = pi + 1;
    }
    ctx.on_top = ctx.on_top - 1;
    g.emit_op(OP_POP_TOP, 0, ploc);
    return True;
}


def emit_match_pattern_sequence(
    g: cfg_builder,
    ms: MatchSequence,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    patterns = ms.patterns;
    size = len(patterns);
    star = -1;
    star_wild = 0;
    only_wildcard = 1;
    pi = 0;
    while pi < size {
        pat = patterns[pi];
        if isinstance(pat, MatchStar) {
            if star >= 0 {
                codegen_fail(
                    g, "SyntaxError", "multiple starred names in sequence pattern"
                );
                return False;
            }
            star = pi;
            mst = pat as MatchStar;
            if mst.name is None {
                star_wild = 1;
                only_wildcard = only_wildcard and 1;
            } else {
                only_wildcard = 0;
            }
            pi = pi + 1;
            continue;
        }
        if match_pattern_wildcard(pat) {
            only_wildcard = only_wildcard and 1;
        } else {
            only_wildcard = 0;
        }
        pi = pi + 1;
    }
    if star >= 0 {
        n_before = star;
        n_after = size - star - 1;
        n_fixed = n_before + n_after;
        ctx.on_top = ctx.on_top + 1;
        g.emit_op(OP_MATCH_SEQUENCE, 0, ploc);
        match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
        # CPython only checks the length when there is at least one fixed
        # element around the star; `[*rest]` skips the length guard entirely.
        if n_fixed > 0 {
            g.emit_op(OP_GET_LEN, 0, ploc);
            nfx_idx = g.u.add_const(PyInt(t="int", val=n_fixed));
            g.emit_op(OP_LOAD_CONST, nfx_idx, ploc);
            g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GE), ploc);
            match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
        }
        if only_wildcard {
            ctx.on_top = ctx.on_top - 1;
            g.emit_op(OP_POP_TOP, 0, ploc);
            return True;
        }
        if star_wild {
            # `[a, *_]`: the star swallows the tail without binding, so CPython
            # subscripts the fixed elements off the subject instead of unpacking.
            return emit_match_sequence_subscr(g, patterns, star, next_arm, ctx, ploc);
        }
        # Capture star: split the subject with UNPACK_EX (n_before | n_after<<8).
        ctx.on_top = ctx.on_top - 1;
        g.emit_op(OP_UNPACK_EX, n_before + n_after * 256, ploc);
        ctx.on_top = ctx.on_top + size;
        pi = 0;
        while pi < size {
            ctx.on_top = ctx.on_top - 1;
            if pi == star {
                mst2 = patterns[pi] as MatchStar;
                if not match_pattern_helper_store_name(g, mst2.name, ctx, ploc) {
                    return False;
                }
            } else {
                if not emit_match_pattern_sub(g, patterns[pi], ctx, next_arm, ploc) {
                    return False;
                }
            }
            pi = pi + 1;
        }
        return True;
    }
    ctx.on_top = ctx.on_top + 1;
    g.emit_op(OP_MATCH_SEQUENCE, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    g.emit_op(OP_GET_LEN, 0, ploc);
    # CPython interns the length const (ADDOP_LOAD_CONST_NEW) and the optimizer
    # folds it to LOAD_SMALL_INT while keeping it in the pool, so later consts
    # (e.g. a following class pattern's attr-name tuple) keep CPython's indices.
    seq_sz_idx = g.u.add_const(PyInt(t="int", val=size));
    g.emit_op(OP_LOAD_CONST, seq_sz_idx, ploc);
    oparg = compare_oparg(CMP_EQ);
    g.emit_op(OP_COMPARE_OP, oparg, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    ctx.on_top = ctx.on_top - 1;
    if only_wildcard {
        g.emit_op(OP_POP_TOP, 0, ploc);
        return True;
    }
    g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
    ctx.on_top = ctx.on_top + size;
    pi = 0;
    while pi < size {
        ctx.on_top = ctx.on_top - 1;
        if not emit_match_pattern_sub(g, patterns[pi], ctx, next_arm, ploc) {
            return False;
        }
        pi = pi + 1;
    }
    return True;
}


# CPython codegen_pattern_class. Emits the class-check, then unpacks the
# attribute tuple and matches sub-patterns. Positional patterns first, then
# keyword patterns (attr names carried in a const tuple for MATCH_CLASS).
def emit_match_pattern_class(
    g: cfg_builder, mc: MatchClass, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    cls_patterns: list[pattern] = mc.patterns if mc.patterns is not None else [];
    kwd_attrs: list[str] = mc.kwd_attrs if mc.kwd_attrs is not None else [];
    kwd_patterns: list[pattern] = mc.kwd_patterns
        if mc.kwd_patterns is not None
        else [];
    nargs = len(cls_patterns);
    nattrs = len(kwd_attrs);
    if nattrs != len(kwd_patterns) {
        codegen_fail(
            g,
            "SyntaxError",
            "kwd_attrs / kwd_patterns length mismatch in class pattern"
        );
        return False;
    }
    ai = 0;
    while ai < nattrs {
        aj = ai + 1;
        while aj < nattrs {
            if kwd_attrs[ai] == kwd_attrs[aj] {
                codegen_fail(
                    g,
                    "SyntaxError",
                    "attribute name repeated in class pattern: " + kwd_attrs[ai]
                );
                return False;
            }
            aj = aj + 1;
        }
        ai = ai + 1;
    }
    visit_expr(g, mc.cls);
    if codegen_busy(g) {
        return False;
    }
    attr_items: list[PyObj] = [];
    ki = 0;
    while ki < nattrs {
        attr_items.append(PyStr(t="str", val=kwd_attrs[ki]));
        ki = ki + 1;
    }
    names_idx = g.u.add_const(PyTuple(t="tuple", items=attr_items));
    g.emit_op(OP_LOAD_CONST, names_idx, ploc);
    g.emit_op(OP_MATCH_CLASS, nargs, ploc);
    g.emit_op(OP_COPY, 1, ploc);
    ctx.on_top = ctx.on_top + 1;
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_NONE, ploc);
    total = nargs + nattrs;
    g.emit_op(OP_UNPACK_SEQUENCE, total, ploc);
    ctx.on_top = ctx.on_top + total - 1;
    i = 0;
    while i < total {
        ctx.on_top = ctx.on_top - 1;
        sp: pattern = cls_patterns[i] if i < nargs else kwd_patterns[i - nargs];
        if match_pattern_wildcard(sp) {
            g.emit_op(OP_POP_TOP, 0, ploc);
        } elif not emit_match_pattern_sub(g, sp, ctx, next_arm, ploc) {
            return False;
        }
        i = i + 1;
    }
    return True;
}


# CPython codegen_pattern_mapping. MATCH_MAPPING + length check, MATCH_KEYS
# against a key tuple, then sub-patterns on the values; **rest binds remaining
# items via the CPython dict-copy/delete idiom.
def emit_match_pattern_mapping(
    g: cfg_builder,
    mm: MatchMapping,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    keys: list[expr] = mm.keys if mm.keys is not None else [];
    patterns: list[pattern] = mm.patterns if mm.patterns is not None else [];
    size = len(keys);
    if size != len(patterns) {
        codegen_fail(
            g, "SyntaxError", "keys / patterns length mismatch in mapping pattern"
        );
        return False;
    }
    ctx.on_top = ctx.on_top + 1;
    g.emit_op(OP_MATCH_MAPPING, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    if size == 0 and mm.rest is None {
        ctx.on_top = ctx.on_top - 1;
        g.emit_op(OP_POP_TOP, 0, ploc);
        return True;
    }
    if size > 0 {
        g.emit_op(OP_GET_LEN, 0, ploc);
        # CPython emits LOAD_CONST(size) (ADDOP_LOAD_CONST_NEW); rewrite_small_ints
        # folds it to LOAD_SMALL_INT but keeps the const in the pool, so later
        # consts (the key tuple) keep CPython's indices.
        sz_idx = g.u.add_const(PyInt(t="int", val=size));
        g.emit_op(OP_LOAD_CONST, sz_idx, ploc);
        g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GE), ploc);
        match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    }
    all_const = True;
    seen: list[PyObj] = [];
    ki = 0;
    while ki < size {
        key = keys[ki];
        if isinstance(key, Constant) {
            kv = (key as Constant).value;
            hk = kv.tp_hashkey();
            si = 0;
            while si < len(seen) {
                if hashkey_equal(seen[si].tp_hashkey(), hk) {
                    codegen_fail(
                        g, "SyntaxError", "mapping pattern checks duplicate key"
                    );
                    return False;
                }
                si = si + 1;
            }
            seen.append(kv);
        } elif isinstance(key, Attribute) {
            all_const = False;
        } else {
            codegen_fail(
                g,
                "SyntaxError",
                "mapping pattern keys may only match literals and attribute lookups"
            );
            return False;
        }
        ki = ki + 1;
    }
    if all_const {
        key_items: list[PyObj] = [];
        ki = 0;
        while ki < size {
            key_items.append((keys[ki] as Constant).value);
            ki = ki + 1;
        }
        keys_idx = g.u.add_const(PyTuple(t="tuple", items=key_items));
        g.emit_op(OP_LOAD_CONST, keys_idx, ploc);
    } else {
        ki = 0;
        while ki < size {
            visit_expr(g, keys[ki]);
            if codegen_busy(g) {
                return False;
            }
            ki = ki + 1;
        }
        g.emit_op(OP_BUILD_TUPLE, size, ploc);
    }
    g.emit_op(OP_MATCH_KEYS, 0, ploc);
    ctx.on_top = ctx.on_top + 2;
    g.emit_op(OP_COPY, 1, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_NONE, ploc);
    g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
    ctx.on_top = ctx.on_top + size - 1;
    pi = 0;
    while pi < size {
        ctx.on_top = ctx.on_top - 1;
        if not emit_match_pattern_sub(g, patterns[pi], ctx, next_arm, ploc) {
            return False;
        }
        pi = pi + 1;
    }
    ctx.on_top = ctx.on_top - 2;
    if mm.rest is not None {
        g.emit_op(OP_BUILD_MAP, 0, ploc);
        g.emit_op(OP_SWAP, 3, ploc);
        g.emit_op(OP_DICT_UPDATE, 2, ploc);
        g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
        sz = size;
        while sz > 0 {
            g.emit_op(OP_COPY, 1 + sz, ploc);
            g.emit_op(OP_SWAP, 2, ploc);
            g.emit_op(OP_DELETE_SUBSCR, 0, ploc);
            sz = sz - 1;
        }
        return match_pattern_helper_store_name(g, mm.rest, ctx, ploc);
    }
    g.emit_op(OP_POP_TOP, 0, ploc);
    g.emit_op(OP_POP_TOP, 0, ploc);
    return True;
}


# Lower a multi-alternative MatchOr (CPython codegen_pattern_or). Each alternative
# copies the subject, tests it, and on success jumps to a shared `end`. On failure
# it falls to the next alternative (subject preserved underneath); the last
# alternative's failure pops the surviving subject and jumps to next_arm. `end`
# and the per-alternative entries are deferred blocks so they lay out after the
# preceding alternative bodies (allocation order != layout order). Captures are
# checked and permuted into a common order before joining the surrounding pattern.
def emit_match_pattern_or(
    g: cfg_builder, mo: MatchOr, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    end = g.new_deferred_block();
    end.exit_inline_ok = True;
    size = len(mo.patterns);
    outer_allow = ctx.allow_irrefutable;
    control: list[str] = [];
    i = 0;
    while i < size {
        alt = mo.patterns[i];
        is_last = i == size - 1;
        alt_fail = g.new_deferred_block();
        g.emit_op(OP_COPY, 1, ploc);
        alt_ctx = match_pat_ctx(
            stores=[],
            on_top=0,
            cleanup_blocks=[],
            max_cleanup=0,
            allow_irrefutable=is_last and outer_allow
        );
        if not emit_match_pattern(g, alt, alt_ctx, alt_fail, ploc) {
            return False;
        }
        if codegen_busy(g) {
            return False;
        }
        if i == 0 {
            control = alt_ctx.stores.copy();
        } else {
            if set(alt_ctx.stores) != set(control) {
                codegen_fail(
                    g, "SyntaxError", "alternative patterns bind different names"
                );
                return False;
            }
            # Every successful alternative must leave captures in the first
            # alternative's order, even when the pattern spells them differently.
            ci = len(control) - 1;
            while ci >= 0 {
                si = alt_ctx.stores.index(control[ci]);
                if ci != si {
                    rotations = si + 1;
                    rotated = alt_ctx.stores[:rotations];
                    alt_ctx.stores = alt_ctx.stores[rotations:];
                    alt_ctx.stores[ci - si:ci - si] = rotated;
                    for unused in range(rotations) {
                        match_pattern_rotate(g, ploc, ci + 1);
                    }
                }
                ci = ci - 1;
            }
        }
        g.emit_jump(OP_JUMP_FORWARD, end.id, ploc);
        match_emit_reset_fail_pop(g, alt_ctx, alt_fail, ploc);
        i = i + 1;
    }
    # Total failure must also discard captures and subjects belonging to the
    # surrounding pattern, not just the copy used to try the alternatives.
    g.emit_op(OP_POP_TOP, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_JUMP_FORWARD, ploc);
    g.use(end);
    rotations = len(control) + 1 + ctx.on_top + len(ctx.stores);
    for name in control {
        match_pattern_rotate(g, ploc, rotations);
        if name in ctx.stores {
            codegen_fail(
                g,
                "SyntaxError",
                "multiple assignments to name '" + name + "' in pattern"
            );
            return False;
        }
        ctx.stores.append(name);
    }
    g.emit_op(OP_POP_TOP, 0, ploc);
    return True;
}


def emit_match_pattern(
    g: cfg_builder, p: pattern, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    if isinstance(p, MatchOr) {
        mo = p as MatchOr;
        if len(mo.patterns) > 1 {
            return emit_match_pattern_or(g, mo, ctx, next_arm, ploc);
        }
    }
    p = match_pattern_unwrap_or(p);
    if isinstance(p, MatchValue) {
        return emit_match_pattern_value(g, p as MatchValue, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchSingleton) {
        return emit_match_pattern_singleton(
            g, p as MatchSingleton, ctx, next_arm, ploc
        );
    }
    if isinstance(p, MatchAs) {
        return emit_match_pattern_as(g, p as MatchAs, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchSequence) {
        return emit_match_pattern_sequence(g, p as MatchSequence, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchClass) {
        return emit_match_pattern_class(g, p as MatchClass, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchMapping) {
        return emit_match_pattern_mapping(g, p as MatchMapping, ctx, next_arm, ploc);
    }
    codegen_fail(g, "NotImplementedError", "unsupported match pattern");
    return False;
}


# Lower match (CPython codegen_match_inner shape; slice 1–3 patterns + guards).
def match_is_irrefutable(pat: pattern) -> bool {
    if isinstance(pat, MatchAs) {
        return pat.pattern is None or match_is_irrefutable(pat.pattern);
    }
    if isinstance(pat, MatchOr) {
        return any(match_is_irrefutable(item) for item in pat.patterns);
    }
    return False;
}

def visit_match(
    g: cfg_builder,
    m: Match,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    mloc = nloc(m.lineno, m.end_lineno, m.col_offset, m.end_col_offset);
    # Class bodies still need their annotation and __classcell__ epilogue.
    if g.sym_top is not None and g.sym_top.block_type == "class" {
        more_code_follows = True;
    }
    if len(m.cases) == 0 {
        return stmt_cont(loc=mloc);
    }
    match_emit_subject(g, m);
    if codegen_busy(g) {
        return stmt_cont(loc=mloc);
    }
    has_default = 0;
    if len(m.cases) > 1 {
        last_pat = m.cases[len(m.cases) - 1].pattern;
        if match_pattern_wildcard(last_pat) {
            has_default = 1;
        }
    }
    join_blk = tail_join;
    owns_join = False;
    if more_code_follows {
        if join_blk is None {
            join_blk = g.new_deferred_block();
            join_blk.exit_inline_ok = True;
            owns_join = True;
        }
    }
    match_end = join_blk;
    owns_match_end = False;
    if match_end is None {
        match_end = g.new_deferred_block();
        match_end.exit_inline_ok = True;
        owns_match_end = True;
    }
    body_follows = more_code_follows;
    if not body_follows and tail is not None and tail_idx < len(tail) {
        body_follows = True;
    }
    loop_end = len(m.cases) - has_default;
    last_arm = m.cases[-1];
    terminated = last_arm.guard is None and match_is_irrefutable(last_arm.pattern);
    ci = 0;
    while ci < loop_end {
        arm = m.cases[ci];
        ploc = match_pattern_loc(arm.pattern);
        start = match_begin_case(g);
        ctx = start.ctx;
        next_arm = start.next_arm;
        if ci != loop_end - 1 {
            g.emit_op(OP_COPY, 1, ploc);
        }
        ctx.allow_irrefutable = arm.guard is not None or ci == len(m.cases) - 1;
        opt_lo = len(g.cur.instrs);
        if not emit_match_pattern(g, arm.pattern, ctx, next_arm, ploc) {
            return stmt_cont(loc=mloc);
        }
        if codegen_busy(g) {
            return stmt_cont(loc=mloc);
        }
        match_emit_case_stores(g, ctx, ploc);
        # Fold the arm's naive rotate (SWAP) + separate stores into CPython's
        # optimized shape (swaptimize + static swaps + STORE_FAST_STORE_FAST).
        optimize_swap_range(g.cur, opt_lo);
        if arm.guard is not None {
            gloc = expr_loc(arm.guard);
            guard_kind = visit_test_expr(g, arm.guard, gloc);
            if codegen_busy(g) {
                return stmt_cont(loc=mloc);
            }
            emit_branch_if_test_false(g, guard_kind, next_arm.id, gloc);
        }
        if ci != loop_end - 1 {
            g.emit_op(OP_POP_TOP, 0, ploc);
        }
        body_cont = visit_stmts(
            g, arm.body, 0, body_follows, tail, tail_idx, join_blk, ann_ctx
        );
        if codegen_busy(g) {
            return stmt_cont(loc=mloc);
        }
        terminated = terminated and body_cont.terminated;
        if not body_cont.terminated {
            if owns_match_end and not body_follows {
                emit_module_return(g, body_cont.loc);
            } else {
                g.emit_jump(OP_JUMP_FORWARD, match_end.id, ploc);
            }
        }
        match_emit_reset_fail_pop(g, ctx, next_arm, ploc);
        ci = ci + 1;
    }
    if has_default {
        arm = m.cases[len(m.cases) - 1];
        ploc = match_pattern_loc(arm.pattern);
        if len(m.cases) == 1 {
            g.emit_op(OP_POP_TOP, 0, ploc);
        } else {
            g.emit_op(OP_NOP, 0, ploc);
        }
        if arm.guard is not None {
            gloc = expr_loc(arm.guard);
            guard_kind = visit_test_expr(g, arm.guard, gloc);
            if codegen_busy(g) {
                return stmt_cont(loc=mloc);
            }
            emit_branch_if_test_false(g, guard_kind, match_end.id, gloc);
        }
        body_cont = visit_stmts(
            g, arm.body, 0, body_follows, tail, tail_idx, join_blk, ann_ctx
        );
        if codegen_busy(g) {
            return stmt_cont(loc=mloc);
        }
        terminated = terminated and body_cont.terminated;
        if not body_cont.terminated and owns_match_end and not body_follows {
            emit_module_return(g, body_cont.loc);
        }
    }
    if owns_match_end {
        g.use(match_end);
        if not more_code_follows and not terminated {
            # The unmatched path remains on the last pattern/guard line. Each
            # successful arm has its own location for its implicit return.
            exit_loc = expr_loc(last_arm.guard)
                if last_arm.guard is not None
                else match_pattern_loc(last_arm.pattern);
            emit_module_return(g, exit_loc);
            terminated = True;
        }
    }
    if owns_join and join_blk is not None {
        g.use(join_blk);
        if tail is not None and tail_idx < len(tail) {
            tail_cont = visit_stmt_tail(
                g, tail, tail_idx, exec_tail_emits_code(tail, tail_idx + 1), ann_ctx
            );
            return stmt_cont(
                loc=tail_cont.loc,
                next_si=len(tail as list[stmt]),
                terminated=terminated or tail_cont.terminated
            );
        }
    }
    return stmt_cont(loc=mloc, terminated=terminated);
}

# Wire statement-dispatch handlers into the leaf registry (see
# compiler_dispatch.jac). Runs at module load via `with entry`; entry
# drivers (product_compile, compiler_slice) import this module so the
# registration always precedes the first compile. Dict item assignment
# mutates the holder in place (scalar-glob rebinding would be local).
with entry {
    stmt_handlers["visit_match"] = visit_match;
}
