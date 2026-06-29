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

impl BaseAstGenPass._init_child_passes(
    pass_class: type[ChildPassT]
) -> list[ChildPassT] {
    return [];
}

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
