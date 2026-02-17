"""
Implementations for enum type checking utilities.
"""
import from typing { TYPE_CHECKING, Sequence }
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
        not assignment.is_enum_stmt
        or not assignment.target
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

"""Build enum members map for an enum class."""
impl build_enum_members(
    enum_node: uni.Enum, evaluator: "TypeEvaluator"
) -> dict[str, types.EnumMemberInfo] {
    members: dict[str, types.EnumMemberInfo] = {};
    if not enum_node.body {
        return members;
    }
    # Case 1: enum Color { RED=1 }  (body is direct)
    # Case 2: enum Color; impl Color { RED=1 }  (body wrapped in ImplDef)
    body = enum_node.body.body
    if isinstance(enum_node.body, uni.ImplDef)
    else enum_node.body;
    if not isinstance(body, Sequence) {
        return members;
    }
    # If member has no value, assign next auto-increment number
    int_type = evaluator.prefetch.int_class if evaluator.prefetch else None;
    auto_value = 1;
    for stmt in body {
        # Case 1: Assignment with explicit value (RED = 1)
        if isinstance(stmt, uni.Assignment) and stmt.is_enum_stmt {
            if member_info := create_enum_member_info(stmt, evaluator) {
                # No value? Use auto-increment
                if member_info.value_type is None {
                    member_info.value_type = int_type;
                    member_info.literal_value = auto_value;
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
            and stmt.is_enum_stmt
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

"""Get value type from base classes (IntEnum→int, StrEnum→str, IntFlag→int).

Limitation: Uses name-based detection - may yield false positives for user
classes with same names (e.g., class IntEnum) or miss aliased imports (e.g., a = StrEnum).

TODO: Check if class comes from Python's enum module instead of just matching names.
"""
impl get_special_enum_value_type_from_bases(
    base_classes: list[types.TypeBase], prefetch: "PrefetchedTypes"
) -> (types.TypeBase | None) {
    if not prefetch {
        return None;
    }
    # Map special enum types to their required value types
    enum_type_map = {
        "IntEnum": prefetch.int_class,
        "IntFlag": prefetch.int_class,
        "StrEnum": prefetch.str_class
    };
    # Walk MRO chain to find if any base is IntEnum, StrEnum, or IntFlag
    # Example: enum Foo(IntEnum) → finds IntEnum in MRO → returns int type
    return next(
        (
            enum_type_map[mro_cls.shared.class_name]
            for base in base_classes
            if isinstance(base, types.ClassType)
            for mro_cls in base.shared.mro
            if mro_cls.shared.class_name in enum_type_map
        ),
        None
    );
}
