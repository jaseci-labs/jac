"""Implementation for base_ast_gen_pass constructs."""

"""Return the module's standalone statement stream for codegen.

Derives the woven statements and per-segment `ImplDef` stripping from the shared
`ModuleCodegenPass.iter_woven_segments` so @sv/ecmascript and native agree on
exactly which statements a module contributes (issue #6754). Annex bodies are
merged into the head module by JacAnnexPass, so this is effectively the head
body with its decl-reached `ImplDef`s stripped."""
impl BaseAstGenPass._merge_module_bodies(nd: uni.Module) -> list {
    merged: list = [];
    for (body, strip_impl_defs) in ModuleCodegenPass.iter_woven_segments(nd) {
        if strip_impl_defs {
            merged.extend(
                [
                    item
                    for item in body
                    if not isinstance(item, uni.ImplDef)
                ]
            );
        } else {
            merged.extend(body);
        }
    }
    return merged;
}

"""Instantiate child passes for sub-modules.

    Annex/test/variant bodies are merged into the head module, so there are no
    separate sub-modules to codegen.
"""
impl BaseAstGenPass._init_child_passes(
    pass_class: type[ChildPassT]
) -> list[ChildPassT] {
    return [];
}

"""Flatten nested AST lists while skipping ``None`` entries."""
impl BaseAstGenPass._flatten_ast_list(items: list[T | list[T] | None]) -> list[T] {
    flattened: list[T] = [];
    for item in items {
        if isinstance(item, `list) {
            flattened.extend(item);
        } elif (item is not None) {
            flattened.append(item);
        }
    }
    return flattened;
}
