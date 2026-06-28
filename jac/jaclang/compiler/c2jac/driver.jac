"""c2jac orchestrator: preprocess → parse → prepass → map → PyastBuildPass → splice → unparse → format.

transpile_c_file — CLI entry; preprocesses .c via pcpp (§8.1), passes .i straight through.
transpile_c_str  — lower-level entry for already-preprocessed C; pcpp not required.
"""

import ast as ast3;
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.c2jac.tags { Tier, Mechanism, Idiom, NodeTag, TagTable }
import from jaclang.compiler.c2jac.boundary { default_tier, default_mechanism }
import from jaclang.compiler.c2jac.mapper { CMapper }
import from jaclang.compiler.c2jac.directir {
    SLOT_SENTINEL,
    is_slot_placeholder,
    slot_id_of
}
import from jaclang.compiler.c2jac.enum_prepass { build_enum_map }
import from jaclang.compiler.c2jac.uni_builder { CUniBuilder }
import from jaclang.compiler.c2jac.comments { inject_tier_b_comments }

def transpile_c_file(
    filename: str,
    include_dirs: (list[str] | None) = None,
    defines: (list[str] | None) = None,
    undefines: (list[str] | None) = None,
    force_includes: (list[str] | None) = None,
    nostdinc: bool = False
) -> tuple[str, TagTable] {
    with open(filename) as f {
        c_src = f.read();
    }
    if filename.endswith(".i") {
        return transpile_c_str(c_src, filename);
    }
    # pcpp imported lazily so pycparser-only paths work without it installed.
    import from jaclang.compiler.c2jac.preprocess { preprocess_c }
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
    # pycparser is vendored in-tree (jaclang.vendor.pycparser) — no third-party dep.
    import from jaclang.vendor.pycparser { c_parser }
    parser = c_parser.CParser();
    try {
        file_ast = parser.parse(c_src, filename);
    } except Exception as e {
        if "Directive" in str(e) {
            raise ValueError(
                f"{filename}: transpile_c_str expects already-preprocessed C, but "
                f"the input still has #include/#define/#pragma/#if directives. "
                f"Use transpile_c_file (or the `jac c2jac` CLI), which preprocesses "
                f".c with pcpp automatically."
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
    uni_mod.has_synthesized_tokens = True;

    # --- Step 6: unparse + format ---
    # requires_format=True: UnparsePass omits "to"/"by" keywords for IterForStmt.
    jac_str = uni_mod.unparse(requires_format=True);

    # --- Step 7: post-format Tier-B comment injection (§7, §9.2a) ---
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

def _splice_directir(
    mod_root: uni.Module, slot_map: dict[int, object], builder: CUniBuilder
) {
    sentinels = mod_root.get_all_sub_nodes(uni.ExprStmt);
    to_replace: list[tuple[uni.ExprStmt, int]] = [];
    for s in sentinels {
        if is_slot_placeholder(s) {
            slot_id = slot_id_of(s);
            if slot_id is None {
                raise ValueError(
                    f"c2jac: malformed direct-IR placeholder (no int slot id) — "
                    f"the {SLOT_SENTINEL} protocol is broken"
                );
            }
            to_replace.append((s, slot_id));
        }
    }
    for (sentinel, slot_id) in to_replace {
        c_node = slot_map.get(slot_id);
        if c_node is None {
            raise ValueError(
                f"c2jac: direct-IR placeholder references unregistered slot "
                f"{slot_id} — mapper.slot_map and the emitted placeholders are "
                f"out of sync"
            );
        }
        # A promotable C-for is emitted by the mapper as `iter; while cond {
        # sentinel; body; step }`; rewrite that spliced WhileStmt in place into a
        # native IterForStmt. Everything else (enums) is built by CUniBuilder and
        # replaces its sentinel directly.
        if type(c_node).__name__ == "For" {
            _promote_for(sentinel);
        } else {
            replacements = builder.build(c_node);
            _do_splice(sentinel, replacements);
        }
    }
    # Post-condition: surviving placeholders leak into emitted Jac (`directir_no_leak` test).
    leaked = [
        s
        for s in mod_root.get_all_sub_nodes(uni.ExprStmt)
        if is_slot_placeholder(s)
    ];
    if leaked {
        raise ValueError(
            f"c2jac: {len(leaked)} direct-IR placeholder(s) survived the splice — "
            f"would leak {SLOT_SENTINEL} into emitted Jac"
        );
    }
}

def _promote_for(sentinel: uni.ExprStmt) {
    # Rewrite a promotable C-for's spliced desugar into a native IterForStmt.
    # The mapper emitted `iter; while cond { sentinel; body...; step }`, so:
    #   • the sentinel's parent IS the while to promote,
    #   • the while's preceding sibling is the `iter` (init) assignment,
    #   • the while-body's last statement is the `count_by` step,
    #   • everything between the sentinel and the step is the loop body.
    # This keeps loop-body lowering single-sourced in the mapper (the spliced
    # children are reused verbatim) — only the loop *shape* is rebuilt here,
    # where no CPython `ast` analog for IterForStmt exists.
    while_stmt = sentinel.parent;
    if while_stmt is None or not isinstance(while_stmt, uni.WhileStmt) {
        raise ValueError(
            f"c2jac: for-promotion sentinel is not inside a WhileStmt — the "
            f"desugar/splice protocol is broken"
        );
    }
    wbody = while_stmt.body;
    if sentinel not in wbody {
        raise ValueError(
            f"c2jac: for-promotion sentinel is not in its while-body — cannot "
            f"locate the loop body to promote"
        );
    }
    m_idx = wbody.index(sentinel);
    if (len(wbody) - m_idx) < 2 {
        raise ValueError(
            f"c2jac: promotable C-for while-body has no count_by step after the "
            f"sentinel — the IterForStmt would be malformed"
        );
    }
    count_by = wbody[-1];
    body_mid = wbody[m_idx + 1:len(wbody) - 1];
    gp = while_stmt.parent;
    gbody = gp?.body;
    if gp is None
    or gbody is None
    or not isinstance(gbody, list)
    or while_stmt not in gbody {
        raise ValueError(
            f"c2jac: promotable C-for while is not in its parent's body list — "
            f"cannot locate the iter (preceding sibling) to promote"
        );
    }
    g_idx = gbody.index(while_stmt);
    if g_idx < 1 {
        raise ValueError(
            f"c2jac: promotable C-for has no iter statement before the while — "
            f"the desugar must emit `iter; while ...`"
        );
    }
    iter_old = gbody[g_idx - 1];
    if not isinstance(iter_old, uni.Assignment) {
        raise ValueError(
            f"c2jac: promotable C-for iter is not an Assignment — cannot build "
            f"the IterForStmt `iter=` clause"
        );
    }
    # Rebuild the iter without its type annotation: IterForStmt renders `for i =
    # 0 ...`, never `for i: int = 0 ...`. The target/value uni nodes are reused.
    tgt = iter_old.target[0];
    val = iter_old.value;
    new_iter = uni.Assignment(
        kid=[tgt, val],
        target=[tgt],
        value=val,
        type_tag=None,
        mutable=True,
        aug_op=None,
        is_enum_stmt=False,
    );
    cond = while_stmt.condition;
    # The py-ast path wraps a comparison/bool condition in a parenthesizing
    # AtomUnit (proc_compare → `(i < n)`); IterForStmt's `to` clause reads cleaner
    # unparenthesized (`for i = 0 to i < n …`) and the unwrap is semantics-neutral
    # for a single wrapped expression. (The while-desugar keeps its parens, the
    # established py-ast style for if/while conditions.)
    if isinstance(cond, uni.AtomUnit) {
        cond = cond.value;
    }
    iterfor = uni.IterForStmt(
        kid=[new_iter, cond, count_by, *body_mid],
        iter=new_iter,
        condition=cond,
        count_by=count_by,
        body=body_mid,
        else_body=None,
        is_async=False,
    );
    for child in [new_iter, cond, count_by, *body_mid] {
        child.parent = iterfor;
    }
    iterfor.parent = gp;
    # Replace [iter_old, while_stmt] with [iterfor] in both body and kid, robust
    # to ordering: drop both wherever they appear, inserting iterfor once.
    new_body: list[uni.UniNode] = [];
    inserted_b = False;
    for b in gbody {
        if b is iter_old or b is while_stmt {
            if not inserted_b {
                new_body.append(iterfor);
                inserted_b = True;
            }
        } else {
            new_body.append(b);
        }
    }
    gp.body = new_body;
    new_kid: list[uni.UniNode] = [];
    inserted_k = False;
    for k in gp.kid {
        if k is iter_old or k is while_stmt {
            if not inserted_k {
                new_kid.append(iterfor);
                inserted_k = True;
            }
        } else {
            new_kid.append(k);
        }
    }
    # Manual rewire (not set_kids): token ranges are stamped later by NormalizePass
    # — see the note in _do_splice for why resolve_tok_range can't run here.
    gp.kid = new_kid;
    gp._invalidate_sub_node_tab();
}

def _do_splice(sentinel: uni.ExprStmt, replacements: list[uni.UniNode]) -> None {
    parent = sentinel.parent;
    if parent is None {
        return;
    }
    if sentinel not in parent.kid {
        raise ValueError(
            f"c2jac: direct-IR sentinel is not in its parent's kid list — the uni "
            f"tree's parent/kid pointers disagree; splice cannot proceed"
        );
    }
    kid_idx = parent.kid.index(sentinel);
    new_kid = [*parent.kid[:kid_idx], *replacements, *parent.kid[kid_idx + 1:]];
    # NB: deliberately not unitree's set_kids/insert_kids_at_pos here. Those
    # refresh the token range via resolve_tok_range, which (a) raises on an empty
    # kid list — `replacements` is [] for a Tier-B enum, leaving the parent empty
    # — and (b) reads child token ranges that don't exist yet: this splice runs
    # BEFORE NormalizePass stamps the synthesized tokens (driver step 5 vs 6). So
    # the kid pointers are rewired by hand and token resolution is left to step 6.
    for r in replacements {
        r.parent = parent;
    }
    parent.kid = new_kid;
    parent._invalidate_sub_node_tab();
    body = parent?.body;
    if body is not None and isinstance(body, list) and sentinel in body {
        body_idx = body.index(sentinel);
        body[body_idx:body_idx + 1] = replacements;
    }
    if any(
        isinstance(r, uni.GlobalVars) or isinstance(r, uni.Enum) for r in replacements
    ) {
        _hoist_to_module_body(sentinel, parent, replacements);
    }
}

def _hoist_to_module_body(
    sentinel: uni.ExprStmt,
    immediate_parent: uni.UniNode,
    replacements: list[uni.UniNode]
) -> None {
    nd: uni.UniNode | None = immediate_parent;
    while nd is not None and not isinstance(nd, uni.Module) {
        nd = nd.parent;
    }
    if nd is None or not isinstance(nd, uni.Module) {
        return;
    }
    mod = nd;
    if immediate_parent is mod {
        return;
    }
    cur: uni.UniNode = immediate_parent;
    while cur.parent is not None and cur.parent is not mod {
        cur = cur.parent;
    }
    if cur.parent is not mod {
        return;
    }
    containing_child = cur;
    for r in replacements {
        if r in immediate_parent.kid {
            immediate_parent.kid.remove(r);
        }
    }
    local_body = immediate_parent?.body;
    if local_body is not None and isinstance(local_body, list) {
        for r in replacements {
            if r in local_body {
                local_body.remove(r);
            }
        }
    }
    immediate_parent._invalidate_sub_node_tab();
    # raise: containing_child must be in Module.body; a miss silently drops constants.
    if containing_child not in mod.body {
        raise ValueError(
            f"c2jac: ENUM_AS_CONSTS hoist target is not in Module.body — enum "
            f"constants would be silently dropped from the emitted Jac"
        );
    }
    mc_idx = mod.body.index(containing_child);
    kid_idx = mod.kid.index(containing_child)
        if containing_child in mod.kid
        else mc_idx;
    for (i, r) in enumerate(replacements) {
        mod.body.insert(mc_idx + i, r);
        mod.kid.insert(kid_idx + i, r);
        r.parent = mod;
    }
    mod._invalidate_sub_node_tab();
}
