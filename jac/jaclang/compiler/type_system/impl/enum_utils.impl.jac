"""
Implementations for enum type checking utilities.
"""
import from typing { TYPE_CHECKING }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.type_system { types }

with entry {
    if TYPE_CHECKING {
        import from jaclang.compiler.type_system.type_evaluator {
            TypeEvaluator,
            PrefetchedTypes
        }
    }
}

"""Check if a name should be excluded from enum membership."""
impl is_excluded_enum_member_name(name: str) -> bool {
    # Exclude dunder methods (__init__, __str__) and reserved names (name, value)
    return name.startswith('__') or name in ENUM_RESERVED_NAMES;
}

"""Create enum member info from an assignment statement."""
impl create_enum_member_info(
    assignment: uni.Assignment, evaluator: "TypeEvaluator"
) -> (types.EnumMemberInfo | None) {
    # Check if assignment is valid enum member:
    # Valid: RED = 1, BLUE = 2
    # Invalid: __init__ (dunder), name/value (reserved), empty target
    if (
        not assignment.target
        or len(assignment.target) == 0
        or not isinstance(target := assignment.target[0], (uni.NameAtom, uni.Name))
        or is_excluded_enum_member_name(member_name := target.value)
    ) {
        return None;
    }
    # Extract value type and literal from assignment (e.g., RED = 1, PENDING = "pending")
    value_type: types.TypeBase | None = None;
    literal_value: int | str | None = None;
    if val := assignment.value {
        if isinstance(val, uni.Int) {
            value_type = evaluator.prefetch.int_class if evaluator.prefetch else None;
            literal_value = int(val.value);
        } elif isinstance(val, uni.String) {
            value_type = evaluator.prefetch.str_class if evaluator.prefetch else None;
            literal_value = val.value;
            # Complex expression: evaluate type
        } else {
            value_type = evaluator.get_type_of_expression(val);
        }
    }
    # Create member info with extracted name, type, and value
    return types.EnumMemberInfo(
        member_name=member_name, value_type=value_type, literal_value=literal_value
    );
}

"""Build enum members map for an enum or class-based enum."""
impl build_enum_members(
    enum_node: uni.Enum | uni.Archetype,
    evaluator: "TypeEvaluator",
    enum_value_type: types.TypeBase | None = None
) -> dict[str, types.EnumMemberInfo] {
    members: dict[str, types.EnumMemberInfo] = {};
    if not enum_node.body {
        return members;
    }
    # If member has no value, assign next auto-increment number
    int_type = evaluator.prefetch.int_class if evaluator.prefetch else None;
    auto_value = 1;
    # Use symbol table to collect member declarations
    # Handles native enums, impl-based enums (enum Color; impl Color { RED=1 }), and class-based enums (e.g., StrEnum with `with entry {}`)
    all_stmts: list = [
        sym.decl.parent if isinstance(sym.decl.parent, uni.Assignment) else sym.decl
        for (name, sym) in enum_node.names_in_scope.items()
        if not is_excluded_enum_member_name(name)
    ];
    for stmt in all_stmts {
        # Case 1: Assignment with explicit value (RED = 1)
        if isinstance(stmt, uni.Assignment) {
            if member_info := create_enum_member_info(stmt, evaluator) {
                # No value? Use auto-increment
                if member_info.value_type is None {
                    member_info.value_type = int_type;
                    member_info.literal_value = auto_value;
                }
                # Validate value type matches required type (e.g., IntEnum members must be int)
                if enum_value_type
                and isinstance(member_info.value_type, types.ClassType)
                and member_info.value_type.shared != enum_value_type.shared {
                    evaluator.add_diagnostic(
                        stmt,
                        f"Cannot assign {member_info.value_type} to enum member '{member_info.member_name}' of type {enum_value_type}"
                    );
                }
                members[member_info.member_name] = member_info;
                # Next member should get current value + 1
                # Example: FIRST=1, SECOND=2, THIRD=10, FOURTH → FOURTH gets 11 (not 3)
                auto_value = member_info.literal_value + 1
                if isinstance(member_info.literal_value, int)
                else auto_value;
            }
            # Case 2: Name-only member (RED, GREEN) - gets auto-incremented int value
        } elif (
            isinstance(stmt, uni.NameAtom)
            and not is_excluded_enum_member_name(member_name := stmt.value)
        ) {
            members[member_name] = types.EnumMemberInfo(
                member_name=member_name, value_type=int_type, literal_value=auto_value
            );
            auto_value += 1;
        }
    }
    return members;
}

"""Get value type from base classes (IntEnum→int, StrEnum→str).

Uses MRO-based type detection by checking for prefetched base types:
- StrEnum: MRO contains both `str` and `Enum`
- IntEnum: MRO contains both `int` and `Enum`

TODO: Handle IntFlag (int + Flag in MRO → int value type). Requires prefetching Flag class.
"""
impl get_special_enum_value_type_from_bases(
    base_classes: list[types.TypeBase], prefetch: "PrefetchedTypes"
) -> (types.TypeBase | None) {
    if not prefetch
    or not prefetch.enum_class
    or not prefetch.int_class
    or not prefetch.str_class {
        return None;
    }
    # Collect all unique classes from MRO of all base classes
    mro_shared_set: set = set();
    for base in base_classes {
        if isinstance(base, types.ClassType) {
            for mro_cls in base.shared.mro {
                mro_shared_set.add(mro_cls.shared);
            }
        }
    }
    # Check for special enum patterns using prefetched type identity
    has_enum = prefetch.enum_class.shared in mro_shared_set;
    has_int = prefetch.int_class.shared in mro_shared_set;
    has_str = prefetch.str_class.shared in mro_shared_set;
    # StrEnum: str + Enum in MRO → str value type
    if has_enum {
        if has_str {
            return prefetch.str_class;
        } elif has_int {
            return prefetch.int_class;
        }
    }
    return None;
}
