"""Regenerate the visitor double-dispatch surface for UniPass.

The keystone blocker for native self-hosting (#6942, Workstream A.1) was the
reflective dispatch in `uni_pass.impl.jac`: `enter_node`/`exit_node` picked the
visitor method off the runtime class name via
`hasattr`/`getattr(self, f"enter_{snake(type(nd))}")` -- string-keyed reflection
the native backend cannot lower.

It is replaced with classic visitor double-dispatch:

- `UniPass.enter_node`/`exit_node` call `nd.accept_enter(self)` /
  `nd.accept_exit(self)`.
- Each node kind handled by some pass gets a generated `accept_<verb>` override
  (`impl Module.accept_enter(v) { v.enter_module(self); }`) -- a direct,
  exact-type, O(1) double-vtable call. Unhandled kinds inherit `UniNode`'s base
  accept, which routes to the pass's `default_<verb>` hook.
- `UniPass` carries a generated base surface (`enter_<kind>`/`exit_<kind>`) that
  routes to `default_<verb>`; a pass's own ability simply overrides its slot.

This generator (re)writes the two impl annexes from the passes' own abilities:
  - `unitree.impl/dispatch.impl.jac`        -- the per-node accept overrides
  - `passes/uni_pass.impl/surface.impl.jac` -- the UniPass base surface
and refreshes the surface-decl block inside `uni_pass.jac` (between markers).

The matching `accept_<verb>` *declarations* on each handled node class in
`unitree.jac` are hand-maintained boilerplate (Jac requires a decl per override);
`verify_all` flags any that are missing. Regenerate with `jac gen-uni-dispatch`.
"""

# Passes whose enter_*/exit_* abilities define the handled node-kind set.
# Subclasses that add no abilities of their own (TypeInferencePass,
# JacLintCheckPass, CoalesceBBPass) inherit dispatch via the vtable and are
# intentionally absent.
glob DISPATCH_PASSES: list = [
         ("jaclang.jac0core.passes.ast_validation_pass", "ASTValidationPass"),
         ("jaclang.jac0core.passes.boundary_analysis_pass", "BoundaryAnalysisPass"),
         ("jaclang.jac0core.passes.semantic_analysis_pass", "SemanticAnalysisPass"),
         ("jaclang.jac0core.passes.sym_tab_build_pass", "SymTabBuildPass"),
         ("jaclang.jac0core.passes.pyast_gen_pass", "PyastGenPass"),
         ("jaclang.compiler.passes.main.cfg_build_pass", "CFGBuildPass"),
         ("jaclang.compiler.passes.main.type_checker_pass", "TypeCheckPass"),
         ("jaclang.compiler.passes.main.pyjac_ast_link_pass", "PyJacAstLinkPass"),
         ("jaclang.compiler.passes.ecmascript.esast_gen_pass", "EsastGenPass"),
         ("jaclang.compiler.passes.tool.doc_ir_gen_pass", "DocIRGenPass"),
         ("jaclang.compiler.passes.tool.jac_auto_lint_pass", "JacAutoLintPass"),
         ("jaclang.compiler.passes.tool.normalize_pass", "NormalizePass"),
         ("jaclang.compiler.passes.tool.unparse_pass", "UnparsePass"),
         ("jaclang.compiler.passes.tool.grammar_extract_pass", "GrammarExtractPass"),

     ],
     ACCEPT_ANNEX: str = "jac0core/unitree.impl/dispatch.impl.jac",
     SURFACE_ANNEX: str = "jac0core/passes/uni_pass.impl/surface.impl.jac",
     UNI_PASS_SRC: str = "jac0core/passes/uni_pass.jac",
     UNITREE_SRC: str = "jac0core/unitree.jac",
     SURFACE_BEGIN: str = "    # >>> generated visitor surface (jac gen-uni-dispatch) >>>",
     SURFACE_END: str = "    # <<< generated visitor surface <<<";

"""Build {snake_name: PascalNodeName} for every UniNode subclass."""
def node_snake_map -> dict[str, str] {
    import from jaclang.jac0core { unitree as ut_mod }
    import from jaclang.jac0core.unitree { UniNode }
    import from jaclang.jac0core.helpers { pascal_to_snake }
    out: dict[str, str] = {};
    for name in dir(ut_mod) {
        attr = getattr(ut_mod, name);
        if isinstance(attr, type)
        and issubclass(attr, UniNode)
        and attr is not UniNode {
            out[pascal_to_snake(name)] = name;
        }
    }
    return out;
}

"""(handled_enter, handled_exit): sorted Pascal node names handled by some pass.

Mirrors the reflective key: a pass handles kind X for `verb` iff it defines
`verb_<snake(X)>`. Includes inherited abilities (dir walks the MRO). Helper
methods sharing the prefix but not naming a node kind are ignored, exactly as
reflection ignored them.
"""
def handled_kinds -> tuple[list[str], list[str]] {
    import importlib;
    snake_map = node_snake_map();
    sets: dict[str, set] = {"enter": set(), "exit": set()};
    for entry in DISPATCH_PASSES {
        cls = getattr(importlib.import_module(entry[0]), entry[1]);
        for attr in dir(cls) {
            for verb in ["enter", "exit"] {
                pre = f"{verb}_";
                if attr.startswith(pre) and attr != f"{verb}_node" {
                    snake = attr[len(pre):];
                    if snake in snake_map {
                        sets[verb].add(snake_map[snake]);
                    }
                }
            }
        }
    }
    return (sorted(sets["enter"]), sorted(sets["exit"]));
}

"""Render the per-node accept-override annex (unitree.impl/dispatch.impl.jac)."""
def accept_annex_src(
    enter: list[str], exits: list[str], snake_map: dict[str, str]
) -> str {
    n2s = {v: k for (k, v) in snake_map.items()};
    lines: list = [];
    lines.append('"""Auto-generated visitor accept overrides (#6942 A.1).');
    lines.append('');
    lines.append('DO NOT EDIT MANUALLY - regenerate with `jac gen-uni-dispatch`.');
    lines.append('"""');
    lines.append('');
    for entry in [("enter", enter), ("exit", exits)] {
        (verb, kinds) = entry;
        for node in kinds {
            lines.append(f'impl {node}.accept_{verb}(v: UniPass) -> None {{');
            lines.append(f'    v.{verb}_{n2s[node]}(self);');
            lines.append('}');
        }
    }
    return "\n".join(lines) + "\n";
}

"""Render the UniPass base-surface annex (uni_pass.impl/surface.impl.jac)."""
def surface_annex_src(
    enter: list[str], exits: list[str], snake_map: dict[str, str]
) -> str {
    n2s = {v: k for (k, v) in snake_map.items()};
    lines: list = [];
    lines.append('"""Auto-generated UniPass visitor base surface (#6942 A.1).');
    lines.append('');
    lines.append('DO NOT EDIT MANUALLY - regenerate with `jac gen-uni-dispatch`.');
    lines.append('"""');
    lines.append('');
    for entry in [("enter", enter), ("exit", exits)] {
        (verb, kinds) = entry;
        for node in kinds {
            lines.append(f'impl UniPass.{verb}_{n2s[node]}(nd: uni.{node}) -> None {{');
            lines.append(f'    self.default_{verb}(nd);');
            lines.append('}');
        }
    }
    return "\n".join(lines) + "\n";
}

"""Render the surface-decl block injected into uni_pass.jac."""
def surface_decls_block(
    enter: list[str], exits: list[str], snake_map: dict[str, str]
) -> str {
    n2s = {v: k for (k, v) in snake_map.items()};
    lines: list = [SURFACE_BEGIN];
    for entry in [("enter", enter), ("exit", exits)] {
        (verb, kinds) = entry;
        for node in kinds {
            lines.append(f'    def {verb}_{n2s[node]}(nd: uni.{node}) -> None;');
        }
    }
    lines.append(SURFACE_END);
    return "\n".join(lines);
}

"""Inject/replace the surface-decl block inside uni_pass.jac source text."""
def apply_surface_block(src: str, block: str) -> str {
    import re;
    if SURFACE_BEGIN in src {
        pat = re.escape(SURFACE_BEGIN) + r"[\s\S]*?" + re.escape(SURFACE_END);
        return re.sub(pat, lambda m: any : block , src);
    }
    idx = src.rfind("\n}");
    return src[:idx] + "\n\n" + block + src[idx:];
}

"""Absolute path under the jaclang package for a package-relative path."""
def abs_path(rel: str) -> str {
    import jaclang;
    import from pathlib { Path }
    return str(Path(jaclang.__file__).parent / rel);
}

"""Node classes whose accept_<verb> decl is missing in unitree.jac."""
def missing_accept_decls(enter: list[str], exits: list[str]) -> list {
    import re;
    src = open(abs_path(UNITREE_SRC), encoding="utf-8").read();
    missing: list = [];
    for entry in [("enter", enter), ("exit", exits)] {
        (verb, kinds) = entry;
        for node in kinds {
            m = re.search(
                "obj " + re.escape(node) + r"(?:\[[^\]]*\])?\([^\n]*\{([\s\S]*?)\n\}",
                src
            );
            body = m.group(1) if m else "";
            if f"def accept_{verb}(" not in body {
                missing.append(f"{node}.accept_{verb}");
            }
        }
    }
    return missing;
}

"""(Re)write the visitor annexes + surface decls; return one status line each."""
def write_all -> list {
    import os;
    snake_map = node_snake_map();
    (enter, exits) = handled_kinds();
    msgs: list = [];

    for entry in [
        (ACCEPT_ANNEX, accept_annex_src(enter, exits, snake_map)),
        (SURFACE_ANNEX, surface_annex_src(enter, exits, snake_map)),

    ] {
        (rel, content) = entry;
        out = abs_path(rel);
        os.makedirs(os.path.dirname(out), exist_ok=True);
        with open(out, "w", encoding="utf-8") as f {
            f.write(content);
        }
        msgs.append(f"Generated {out} ({len(content)} bytes)");
    }

    up = abs_path(UNI_PASS_SRC);
    src = open(up, encoding="utf-8").read();
    new_src = apply_surface_block(src, surface_decls_block(enter, exits, snake_map));
    if new_src != src {
        with open(up, "w", encoding="utf-8") as f {
            f.write(new_src);
        }
        msgs.append(f"Updated surface decls in {up}");
    }

    missing = missing_accept_decls(enter, exits);
    if missing {
        msgs.append(
            "WARNING: add these accept decls to unitree.jac: " + ", ".join(missing)
        );
    }
    return msgs;
}

"""Relative paths / descriptions of anything stale or missing (empty = clean)."""
def verify_all -> list {
    snake_map = node_snake_map();
    (enter, exits) = handled_kinds();
    stale: list = [];
    for entry in [
        (ACCEPT_ANNEX, accept_annex_src(enter, exits, snake_map)),
        (SURFACE_ANNEX, surface_annex_src(enter, exits, snake_map)),

    ] {
        (rel, content) = entry;
        current = "";
        try {
            current = open(abs_path(rel), encoding="utf-8").read();
        } except Exception {
            ;
        }
        if current != content {
            stale.append(rel);
        }
    }
    up_src = open(abs_path(UNI_PASS_SRC), encoding="utf-8").read();
    if apply_surface_block(
        up_src, surface_decls_block(enter, exits, snake_map)
    ) != up_src {
        stale.append(UNI_PASS_SRC + " (surface decls)");
    }
    for d in missing_accept_decls(enter, exits) {
        stale.append(f"{UNITREE_SRC} (missing {d})");
    }
    return stale;
}
