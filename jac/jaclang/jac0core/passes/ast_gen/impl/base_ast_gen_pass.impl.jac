"""Implementation for base_ast_gen_pass constructs."""

"""Concatenate impl/test/variant bodies with the main module body.

Derives the weave order and per-segment `ImplDef` stripping from the shared
`ModuleCodegenPass.iter_woven_segments` so @sv/ecmascript and native agree on
exactly which statements an annexed module contributes (issue #6754)."""
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

"""Instantiate child passes for impl, test, and variant modules."""
impl BaseAstGenPass._init_child_passes(
    pass_class: type[ChildPassT]
) -> list[ChildPassT] {
    sub_modules: list[uni.Module] = [];
    sub_modules.extend(self.ir_in.impl_mod);
    sub_modules.extend(self.ir_in.test_mod);
    for variant in self.ir_in.variant_mod {
        sub_modules.append(variant);
        sub_modules.extend(variant.impl_mod);
        sub_modules.extend(variant.test_mod);
    }
    return [pass_class(ir_in=sub_module, prog=self.prog) for sub_module in sub_modules];
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
