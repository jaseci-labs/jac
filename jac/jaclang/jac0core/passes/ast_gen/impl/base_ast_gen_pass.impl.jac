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

"""Concatenate impl/test bodies with the main module body."""
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
    for mod in nd.test_mod {
        merged.extend(mod.body);
    }
    return merged;
}

"""Instantiate child passes for impl and test modules."""
impl BaseAstGenPass._init_child_passes(
    self: BaseAstGenPass, pass_class: type[ChildPassT]
) -> list[ChildPassT] {
    return [
        pass_class(ir_in=sub_module, prog=self.prog)
        for sub_module in (self.ir_in.impl_mod + self.ir_in.test_mod)
    ];
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
