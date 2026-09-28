import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.module_facts { ModuleFacts }

def merge_module_bodies(nd: uni.Module) -> list[uni.UniNode] {
    merged: list[uni.UniNode] = [];
    for (body, strip_impl_defs) in ModuleFacts.iter_woven_segments(nd) {
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

def flatten_ast_list[T](items: list[(T | list[T] | None)]) -> list[T] {
    flattened: list[T] = [];
    for item in items {
        if isinstance(item, list) {
            flattened.extend(item);
        } elif item is not None {
            flattened.append(item);
        }
    }
    return flattened;
}
