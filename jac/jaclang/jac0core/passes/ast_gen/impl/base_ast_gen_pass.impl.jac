"""Implementation for base_ast_gen_pass constructs."""

"""Return the list of body statements regardless of ImplDef wrapping."""
impl BaseAstGenPass._get_body_inner(
    self: BaseAstGenPass, nd: uni.Archetype | uni.Enum | uni.Ability
) -> (Sequence | None) {
    body = nd.body;
    if (isinstance(body, uni.ImplDef) and isinstance(body.body, `list)) {
        return body.body;
    }
    if isinstance(body, `list) {
        return body;
    }
    return None;
}

"""Concatenate impl/test/variant bodies with the main module body."""
impl BaseAstGenPass._merge_module_bodies(self: BaseAstGenPass, nd: uni.Module) -> list {
    clean_body = [
        item
        for item in nd.body
        if not isinstance(item, uni.ImplDef)
    ];
    merged: list = [];
    for mod in nd.impl_mod {
        merged.extend(mod.body);
    }
    merged.extend(clean_body);
    for variant in nd.variant_mod {
        for vimpl in variant.impl_mod {
            merged.extend(vimpl.body);
        }
        merged.extend(
            [
                item
                for item in variant.body
                if not isinstance(item, uni.ImplDef)
            ]
        );
    }
    for mod in nd.test_mod {
        merged.extend(mod.body);
    }
    return merged;
}

"""Instantiate child passes for impl, test, and variant modules."""
impl BaseAstGenPass._init_child_passes(
    self: BaseAstGenPass, pass_class: type[ChildPassT]
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
impl BaseAstGenPass._flatten_ast_list(
    self: BaseAstGenPass, items: list[T | list[T] | None]
) -> list[T] {
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
