"""c2jac orchestrator: preprocess → parse → prepass → map → PyastBuildPass → splice → unparse → format.

Entry points:
  transpile_c_file(filename, ...) -> (jac_str, TagTable)
      File-level driver used by the CLI. Reads `filename`, preprocesses a `.c`
      with pcpp (§8.1) — expanding #include/#define/#pragma/#if — passes an
      already-preprocessed `.i` straight through, then transpiles. This is the
      path callers should normally use; preprocessing is automatic.
  transpile_c_str(c_src, filename) -> (jac_str, TagTable)
      Lower-level entry for callers that already hold *preprocessed* C (a
      translation unit with no surviving preprocessor directives). pycparser does
      not run the C preprocessor, so directives reaching this path are an error.

Dependency separation: only transpile_c_file's raw-`.c` branch needs pcpp, so it
imports `preprocess_c` lazily. transpile_c_str / _transpile_ast (and the `.i`
branch) run with pycparser alone — pcpp need not be installed to use them.
"""

import ast as ast3;
import from pycparser { c_parser }
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
# NOTE: `preprocess_c` (pcpp) is imported lazily inside transpile_c_file — the
# only path that preprocesses. transpile_c_str and _transpile_ast stay usable
# with pycparser alone, so callers holding already-preprocessed C (and tests)
# don't pull in the pcpp dependency. See the module docstring.
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
        # output may carry #line markers / be re-tokenized). Parse as-is. No pcpp
        # import on this path either.
        return transpile_c_str(c_src, filename);
    }
    # Lazy import: pcpp is only needed to preprocess a raw `.c`. Keeping it here
    # (not at module load) lets the pycparser-only entry points run without it.
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
    # pycparser does NOT run the C preprocessor: it expects an already-
    # preprocessed translation unit. #include / #define / #pragma / #if reach
    # the parser verbatim and fail with a cryptic "Directives not supported
    # yet". transpile_c_file/the `jac c2jac` CLI preprocess .c with pcpp before
    # getting here, so directives at this point mean a raw .c reached the
    # low-level entry directly — surface actionable guidance instead.
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

    # --- Step 6: unparse + format ---
    # requires_format=True runs NormalizePass → DocIRGenPass → JacFormatPass which
    # correctly emits "to" and "by" keywords for IterForStmt (the False path uses
    # UnparsePass which omits those structural keywords, breaking the formatter).
    # NormalizePass.after_pass stamps real source lines on the zero-line structural
    # tokens it synthesizes for the spliced DIRECT_IR nodes, so no coordinate
    # fix-up is needed here (this retired the former Step 5b _propagate_source_lines).
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

def _splice_directir(
    mod_root: uni.Module, slot_map: dict[int, object], builder: CUniBuilder
) {
    # Replace every direct-IR placeholder (see c2jac.directir) with the real uni
    # nodes for its slot. Recognition and slot-decode live in `directir` — the one
    # owner of the placeholder shape; this driver only walks, resolves, splices.
    #
    # Every failure mode is a hard error, never a silent skip: a leaked
    # `__c2jac_directir__(N)` call reaching emitted Jac is far worse than a crash.
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
        replacements = builder.build(c_node);
        _do_splice(sentinel, replacements);
    }
    # Post-condition: no placeholder may survive into the tree we are about to
    # unparse. If one does, the splice silently failed to find it (e.g. it sat in
    # a parent collection _do_splice does not patch) and would leak into output —
    # surface it now instead. The `directir_no_leak` test locks this end to end.
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
