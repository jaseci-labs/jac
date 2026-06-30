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

def apply_surface_block(src: str, block: str) -> str {
    import re;
    if SURFACE_BEGIN in src {
        pat = re.escape(SURFACE_BEGIN) + r"[\s\S]*?" + re.escape(SURFACE_END);
        return re.sub(pat, lambda m: any : block , src);
    }
    idx = src.rfind("\n}");
    return src[:idx] + "\n\n" + block + src[idx:];
}

def abs_path(rel: str) -> str {
    import jaclang;
    import from pathlib { Path }
    return str(Path(jaclang.__file__).parent / rel);
}

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
