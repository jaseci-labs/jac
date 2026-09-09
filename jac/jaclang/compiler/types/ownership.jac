import from jaclang.compiler.expr_keys { type_tag_borrows }
import from jaclang.compiler.frontend.unitree { Archetype, HasVar }
import from jaclang.compiler.types.types { ClassType, TypeBase, UnionType }
import from jaclang.compiler.types.type_utils {
    apply_solved_type_vars,
    build_type_var_solution
}

def contains_borrow(ty: TypeBase | None) -> bool {
    return _contains_borrow(ty, set());
}

def _contains_borrow(ty: TypeBase | None, visiting: set[int]) -> bool {
    if isinstance(ty, UnionType) {
        return any([_contains_borrow(t, visiting) for t in (ty.types or [])]);
    }
    if not isinstance(ty, ClassType) or ty._shared is None {
        return False;
    }
    if any([_contains_borrow(arg, visiting) for arg in (ty.private.type_args or [])]) {
        return True;
    }
    key = id(ty.shared);
    if key in visiting {
        return False;
    }
    visiting.add(key);
    solution = build_type_var_solution(ty);
    for base in (ty.shared.base_classes or []) {
        if _contains_borrow(apply_solved_type_vars(base, solution), visiting) {
            return True;
        }
    }
    arch = ty.shared.symbol_table;
    if not isinstance(arch, Archetype) {
        return False;
    }
    for field in arch.get_all_sub_nodes(HasVar) {
        if field.find_parent_of_type(Archetype) is not arch or field.type_tag is None {
            continue;
        }
        if type_tag_borrows(field.type_tag) {
            return True;
        }
        field_type = field.type_tag.tag.type;
        if field_type is not None
            and _contains_borrow(
                apply_solved_type_vars(field_type, solution), visiting
            ) {
            return True;
        }
    }
    return False;
}
