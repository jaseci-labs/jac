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
    # Exclude dunder names (e.g., __init__, __str__)
    if name.startswith('__') and name.endswith('__') {
        return True;
    }
    # Exclude private names (mangled names starting with __)
    if name.startswith('__') and not name.endswith('__') {
        return True;
    }
    # Exclude reserved names
    if name in ENUM_RESERVED_NAMES {
        return True;
    }
    return False;
}

"""Create enum member info from an assignment statement."""
impl create_enum_member_info(
    assignment: uni.Assignment, evaluator: "TypeEvaluator"
) -> (types.EnumMemberInfo | None) {
    if not assignment.is_enum_stmt {
        return None;
    }
    if not assignment.target or len(assignment.target) == 0 {
        return None;
    }
    target = assignment.target[0];
    if not isinstance(target, (uni.NameAtom, uni.Name)) {
        return None;
    }
    member_name = target.value;
    # Check for excluded names
    if is_excluded_enum_member_name(member_name) {
        return None;
    }
    # Determine value type and literal value
    value_type: types.TypeBase | None = None;
    literal_value: int | str | None = None;
    if assignment.value {
        if isinstance(assignment.value, uni.Int) {
            if evaluator.prefetch and evaluator.prefetch.int_class {
                value_type = evaluator.prefetch.int_class;
            }
            literal_value = int(assignment.value.value);
        } elif isinstance(assignment.value, uni.String) {
            if evaluator.prefetch and evaluator.prefetch.str_class {
                value_type = evaluator.prefetch.str_class;
            }
            literal_value = assignment.value.value;
        } elif isinstance(assignment.value, uni.Float) {
            if evaluator.prefetch and evaluator.prefetch.float_class {
                value_type = evaluator.prefetch.float_class;
            }
        } else {
            # For complex expressions, evaluate the type
            value_type = evaluator.get_type_of_expression(assignment.value);
        }
    }
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
    # Handle ImplDef body (when enum has methods)
    if isinstance(enum_node.body, uni.ImplDef) {
        # ImplDef doesn't contain enum members directly
        return members;
    }
    # Handle Sequence of EnumBlockStmt
    if isinstance(enum_node.body, Sequence) {
        auto_value = 1;  # For auto-incrementing values
        for stmt in enum_node.body {
            if isinstance(stmt, uni.Assignment) and stmt.is_enum_stmt {
                if member_info := create_enum_member_info(stmt, evaluator) {
                    members[member_info.member_name] = member_info;
                    auto_value += 1;
                }
            } elif isinstance(stmt, uni.NameAtom) and stmt.is_enum_stmt {
                member_name = stmt.value;
                # Check for excluded names
                if not is_excluded_enum_member_name(member_name) {
                    # Auto-generate value for simple name enum members
                    value_type: types.TypeBase | None = None;
                    if evaluator.prefetch and evaluator.prefetch.int_class {
                        value_type = evaluator.prefetch.int_class;
                    }
                    member_info = types.EnumMemberInfo(
                        member_name=member_name,
                        value_type=value_type,
                        literal_value=auto_value
                    );
                    members[member_name] = member_info;
                    auto_value += 1;
                }
            }
        }
    }
    return members;
}

"""Get the value type for special enum subclasses from base classes.

Uses name-based checking to detect IntEnum/StrEnum/IntFlag base classes.

LIMITATION: This uses simple name matching, which means:
- User-defined classes named "IntEnum" or "StrEnum" will be incorrectly
  detected as stdlib enum types (false positive)
- Aliased imports like `a = StrEnum; class C(a):` won't be detected (false negative)

TODO: Implement proper stdlib module detection by checking if the class
comes from Python's enum module (e.g., via module path or a stdlib flag).
Pyright handles this with a BuiltIn flag + name check.
"""
impl get_special_enum_value_type_from_bases(
    base_classes: list[types.TypeBase], prefetch: "PrefetchedTypes"
) -> (types.TypeBase | None) {
    if not prefetch {
        return None;
    }
    # Names of stdlib enum base classes that imply specific value types
    int_enum_names: set[str] = {"IntEnum","IntFlag"};
    str_enum_names: set[str] = {"StrEnum"};
    for base in base_classes {
        if not isinstance(base, types.ClassType) {
            continue;
        }

        # Check base class name directly
        base_name = base.shared.class_name;
        if base_name in int_enum_names {
            return prefetch.int_class;
        }
        if base_name in str_enum_names {
            return prefetch.str_class;
        }

        # Check MRO for IntEnum/StrEnum (for deep inheritance)
        for mro_cls in base.shared.mro {
            mro_name = mro_cls.shared.class_name;
            if mro_name in int_enum_names {
                return prefetch.int_class;
            }
            if mro_name in str_enum_names {
                return prefetch.str_class;
            }
        }
    }
    return None;
}
