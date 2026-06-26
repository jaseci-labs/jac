"""c2jac orchestrator: parse → prepass → map → PyastBuildPass → splice → unparse → format.

Entry point: transpile_c_str(c_src, filename) -> (jac_str, TagTable)

Input must be *preprocessed* C (a translation unit with no surviving
preprocessor directives). pycparser does not run the C preprocessor, so
#include/#define/#pragma/#if must be expanded first (e.g. `gcc -E -P`).
"""

import ast as ast3;
import from pycparser { c_parser }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.c2jac.tags { Tier, Mechanism, Idiom, NodeTag, TagTable }
import from jaclang.compiler.c2jac.boundary { default_tier, default_mechanism }
import from jaclang.compiler.c2jac.mapper { CMapper, _SLOT_SENTINEL }
import from jaclang.compiler.c2jac.enum_prepass { build_enum_map }
import from jaclang.compiler.c2jac.uni_builder { CUniBuilder }
import from jaclang.compiler.c2jac.comments { inject_tier_b_comments }
import from jaclang.compiler.c2jac.preprocess { preprocess_c }

def transpile_c_file(
    filename: str,
    include_dirs: (list[str] | None) = None,
    defines: (list[str] | None) = None,
    undefines: (list[str] | None) = None,
    force_includes: (list[str] | None) = None,
    nostdinc: bool = False
) -> tuple[str, TagTable] {
    # File-level entry: read `filename`, preprocess if it's a `.c` (pcpp, §8.1),
    # pass an already-preprocessed `.i` straight through, then transpile. The
    # CLI uses this; tests that already hold preprocessed C call transpile_c_str.
    with open(filename) as f {
        c_src = f.read();
    }
    if filename.endswith(".i") {
        # Already preprocessed — running the preprocessor again is wrong (its
        # output may carry #line markers / be re-tokenized). Parse as-is.
        return transpile_c_str(c_src, filename);
    }
    pre = preprocess_c(
        c_src,
        filename,
        include_dirs=include_dirs,
        defines=defines,
        undefines=undefines,
        force_includes=force_includes,
        nostdinc=nostdinc,
    );
    return transpile_c_str(pre, filename);
}

def transpile_c_str(c_src: str, filename: str) -> tuple[str, TagTable] {
    # pycparser does NOT run the C preprocessor: it expects an already-
    # preprocessed translation unit. #include / #define / #pragma / #if reach
    # the parser verbatim and fail with a cryptic "Directives not supported
    # yet". Detect that case up front and raise actionable guidance instead.
    parser = c_parser.CParser();
    try {
        file_ast = parser.parse(c_src, filename);
    } except Exception as e {
        if "Directive" in str(e) {
            raise ValueError(
                f"{filename}: c2jac expects preprocessed C — the C preprocessor "
                f"is not run, so #include/#define/#pragma/#if are unsupported. "
                f"Preprocess first (e.g. `gcc -E -P {filename} > out.i`) and run "
                f"c2jac on the resulting .i file."
            ) from e;
        }
        raise;
    }
    return _transpile_ast(file_ast, c_src, filename);
}

def _transpile_ast(
    file_ast: object, c_src: str, filename: str
) -> tuple[str, TagTable] {
    # --- Step 1: build default tag table ---
    tags = TagTable();
    _populate_default_tags(file_ast, tags);

    # --- Step 2: enum pre-pass (also stamps enum verdicts into the tag table) ---
    enum_verdicts = build_enum_map(file_ast, tags);

    # --- Step 3: map C-AST → CPython ast (with DIRECT_IR placeholders) ---
    mapper = CMapper(tags=tags);
    py_mod = mapper.conv(file_ast);
    ast3.fix_missing_locations(py_mod);

    # --- Step 4: PyastBuildPass → uni IR ---
    orig_src = uni.Source(c_src, filename);
    uni_mod = PyastBuildPass(
        ir_in=uni.PythonModuleAst(py_mod, orig_src=orig_src), prog=JacProgram(),
    ).ir_out;

    # --- Step 5: splice DIRECT_IR nodes in place of sentinels ---
    builder = CUniBuilder(src=orig_src, tags=tags, enum_verdicts=enum_verdicts);
    _splice_directir(uni_mod, mapper.slot_map, builder);

    # --- Step 5b: give synthesized zero-line tokens a real source line ---
    # NormalizePass synthesizes structural tokens (braces, parens, operators)
    # with line=0. Body *classification* no longer depends on this — the formatter
    # keys body membership off node identity (DocIRGenPass.is_body_member), and
    # break/continue carry real lines now (PyastBuildPass.proc_break/continue) —
    # but the formatter's blank-line *spacing* (DocIRGenPass.has_gap) is still
    # line-based, so a zero-line `}` would mis-compute a block's last line and
    # emit a spurious blank line. Propagating the nearest real line to those
    # tokens keeps spacing faithful. This is the lone remaining coordinate fix-up;
    # the prior _fix_ctrl_locs pass and the c2jac-specific is_within bypass in
    # DocIRGenPass.exit_else_stmt were both retired by the identity/root-line work
    # above. The eventual upstream fix is for NormalizePass to stamp real lines on
    # the structural tokens it synthesizes, retiring this step too.
    _propagate_source_lines(uni_mod);

    # --- Step 6: unparse + format ---
    # requires_format=True runs NormalizePass → DocIRGenPass → JacFormatPass which
    # correctly emits "to" and "by" keywords for IterForStmt (the False path uses
    # UnparsePass which omits those structural keywords, breaking the formatter).
    jac_str = uni_mod.unparse(requires_format=True);

    # --- Step 7: post-format Tier-B comment injection (§7, §9.2a) ---
    # The single authoritative Tier-B record: a header summary of every Tier-B
    # site plus inline notes on surrogate-marker lines. No-op for Tier-A-only
    # output.
    jac_str = inject_tier_b_comments(jac_str, tags);
    return (jac_str, tags);
}

def _populate_default_tags(nd: object, tags: TagTable) {
    tier = default_tier(nd);
    mech = default_mechanism(nd);
    coord = nd?.coord;
    line = coord.line if coord and coord.line else 0;
    nt = NodeTag(
        tier=tier, mechanism=mech, idiom=Idiom.NONE, reason="", c_line=line, snippet=""
    );
    tags.tag(nd, nt);
    for (_, child) in nd.children() {
        _populate_default_tags(child, tags);
    }
}

def _is_sentinel_expr_stmt(nd: uni.UniNode) -> bool {
    if not isinstance(nd, uni.ExprStmt) {
        return False;
    }
    expr = nd.expr;
    if not isinstance(expr, uni.FuncCall) {
        return False;
    }
    target = expr.target;
    if not isinstance(target, uni.Name) {
        return False;
    }
    return target.value == _SLOT_SENTINEL;
}

def _get_slot_id(sentinel: uni.ExprStmt) -> int | None {
    params = sentinel.expr.params;
    if params and len(params) == 1 and isinstance(params[0], uni.Int) {
        try {
            return int(params[0].value);
        } except ValueError {
        # skip
        }
    }
    return None;
}

def _splice_directir(
    mod_root: uni.Module, slot_map: dict[int, object], builder: CUniBuilder
) {
    sentinels = mod_root.get_all_sub_nodes(uni.ExprStmt);
    to_replace: list[tuple[uni.ExprStmt, int]] = [];
    for s in sentinels {
        if _is_sentinel_expr_stmt(s) {
            slot_id = _get_slot_id(s);
            if slot_id is not None {
                to_replace.append((s, slot_id));
            }
        }
    }
    for (sentinel, slot_id) in to_replace {
        c_node = slot_map.get(slot_id);
        if c_node is None {
            continue;
        }
        replacements = builder.build(c_node);
        _do_splice(sentinel, replacements);
    }
}

def _do_splice(sentinel: uni.ExprStmt, replacements: list[uni.UniNode]) -> None {
    parent = sentinel.parent;
    if parent is None {
        return;
    }
    # Find and replace in parent.kid.
    try {
        kid_idx = parent.kid.index(sentinel);
        new_kid = [*parent.kid[:kid_idx], *replacements, *parent.kid[kid_idx + 1:]];
        for r in replacements {
            r.parent = parent;
        }
        parent.kid = new_kid;
        parent._invalidate_sub_node_tab();
    } except ValueError {
    # skip
    }
    # Also replace in parent's semantic 'body' attribute if it exists.
    body = parent?.body;
    if body is not None and isinstance(body, list) {
        try {
            body_idx = body.index(sentinel);
            body[body_idx:body_idx + 1] = replacements;
        } except ValueError {
        # skip
        }
    }
    # For GlobalVars replacements (from ENUM_AS_CONSTS), they need to go
    # to the Module-level body, not a code block body. The parent of a
    # sentinel inside a ModuleCode's body IS the ModuleCode; we need to
    # move GlobalVars up to Module.body. Handled by checking the replacement type.
    if any(
        isinstance(r, uni.GlobalVars) or isinstance(r, uni.Enum) for r in replacements
    ) {
        _hoist_to_module_body(sentinel, parent, replacements);
    }
}

def _collect_non_zero_lines(nd: object, result: list) -> None {
    if isinstance(nd, uni.Token) {
        if nd.line_no > 0 {
            result.append(nd.line_no);
        }
        return;
    }
    kids = nd?.kid;
    if kids {
        for kid in kids {
            _collect_non_zero_lines(kid, result);
        }
    }
}

def _propagate_source_lines(mod: uni.Module) {
    _fix_zero_toks_in_subtree(mod);
}

def _fix_zero_toks_in_subtree(nd: object) -> None {
    if isinstance(nd, uni.Token) {
        return;
    }
    kids = nd?.kid;
    if not kids {
        return;
    }
    # Post-order: fix children first so descendant lines are already correct.
    for kid in kids {
        _fix_zero_toks_in_subtree(kid);
    }
    # If any direct-child token still has line_no=0, give it a real line based on
    # its POSITION among the kids, not a single blanket value. A leading/opening
    # token (e.g. `{`) takes the first line that follows it; a trailing/closing
    # token (e.g. `}`) takes the last line that precedes it. Stamping every zero
    # token with min(desc_lines) instead compressed a block's apparent span — the
    # formatter's blank-line gap logic keys off a node's last_line, so a closing
    # `}` carrying the block's FIRST line mis-computed spacing to the next sibling.
    has_zero = any(isinstance(k, uni.Token) and k.line_no == 0 for k in kids);
    if not has_zero {
        return;
    }
    # Per-kid first/last real descendant line (None when the kid has no real line).
    kid_first: list[int | None] = [];
    kid_last: list[int | None] = [];
    for kid in kids {
        sub: list[int] = [];
        _collect_non_zero_lines(kid, sub);
        kid_first.append(min(sub) if sub else None);
        kid_last.append(max(sub) if sub else None);
    }
    n = len(kids);
    for i in range(n) {
        k = kids[i];
        if not (isinstance(k, uni.Token) and k.line_no == 0) {
            continue;
        }
        # Nearest real line AFTER this token (opening tokens), else BEFORE it.
        chosen: int | None = None;
        for j in range(i + 1, n) {
            if kid_first[j] is not None {
                chosen = kid_first[j];
                break;
            }
        }
        if chosen is None {
            for j in range(i - 1, -1, -1) {
                if kid_last[j] is not None {
                    chosen = kid_last[j];
                    break;
                }
            }
        }
        if chosen is not None {
            k.line_no = chosen;
            k.end_line = chosen;
        }
    }
}

def _hoist_to_module_body(
    sentinel: uni.ExprStmt,
    immediate_parent: uni.UniNode,
    replacements: list[uni.UniNode]
) -> None {
    # Find the Module ancestor.
    nd: uni.UniNode | None = immediate_parent;
    while nd is not None and not isinstance(nd, uni.Module) {
        nd = nd.parent;
    }
    if nd is None or not isinstance(nd, uni.Module) {
        return;
    }
    mod = nd;
    # If immediate_parent IS the module, _do_splice already put replacements
    # in Module.body — nothing more to do.
    if immediate_parent is mod {
        return;
    }
    # Find the direct module-level child that is an ancestor of immediate_parent.
    cur: uni.UniNode = immediate_parent;
    while cur.parent is not None and cur.parent is not mod {
        cur = cur.parent;
    }
    if cur.parent is not mod {
        return;
    }
    containing_child = cur;
    # _do_splice already inserted replacements into immediate_parent.body and .kid.
    # Remove them from there so they only appear at module level.
    for r in replacements {
        try {
            immediate_parent.kid.remove(r);
        } except ValueError {
            pass;
        }
    }
    local_body = immediate_parent?.body;
    if local_body is not None and isinstance(local_body, list) {
        for r in replacements {
            try {
                local_body.remove(r);
            } except ValueError {
                pass;
            }
        }
    }
    immediate_parent._invalidate_sub_node_tab();
    # Insert replacements just before the containing_child in Module.body and .kid.
    try {
        mc_idx = mod.body.index(containing_child);
        try {
            kid_idx = mod.kid.index(containing_child);
        } except ValueError {
            kid_idx = mc_idx;
        }
        for (i, r) in enumerate(replacements) {
            mod.body.insert(mc_idx + i, r);
            mod.kid.insert(kid_idx + i, r);
            r.parent = mod;
        }
        mod._invalidate_sub_node_tab();
    } except ValueError {
    # skip
    }
}
