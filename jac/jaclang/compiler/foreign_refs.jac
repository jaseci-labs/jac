"""Semantic foreign-resource contracts, independent of the foreign runtime."""

import from jaclang.compiler.types.types { ClassType, TypeBase, UnionType, FunctionType }
import from jaclang.compiler.frontend.unitree { Ability, Import }
import from jaclang.compiler.frontend.constant { OwnershipKind }

def cpython_error_call(decl: Ability | None) -> bool {
    if decl is None { return False; }
    fn = decl.name_spec.type;
    imported = decl.find_parent_of_type(Import);
    return isinstance(fn, FunctionType)
        and fn.foreign_errors in ("python", "none")
        and imported is not None
        and decl in (imported.clib_decls or []);
}

def cpython_ref_name(typ: TypeBase | None) -> str | None {
    if isinstance(typ, ClassType) and typ.shared.foreign_resource is not None {
        return typ.shared.class_name;
    }
    return None;
}

def contains_cpython_ref(typ: TypeBase | None) -> bool {
    pending = [typ];
    seen: set[int] = set();
    while pending {
        current = pending.pop();
        if current is None or id(current) in seen {
            continue;
        }
        seen.add(id(current));
        if cpython_ref_name(current) is not None {
            return True;
        }
        if isinstance(current, ClassType) {
            pending.extend(current.private.type_args or []);
        } elif isinstance(current, UnionType) {
            pending.extend(current.types or []);
        }
    }
    return False;
}

def cpython_borrow_source(decl: Ability | None) -> int | None {
    if decl is not None {
        fn = decl.name_spec.type;
        if isinstance(fn, FunctionType) and fn.return_sources
            and fn.return_ownership == OwnershipKind.BORROW {
            return fn.return_sources[0];
        }
    }
    return None;
}
