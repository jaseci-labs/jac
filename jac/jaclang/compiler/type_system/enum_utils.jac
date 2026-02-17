"""
Utilities for enum type checking.

PyrightReference: packages/pyright-internal/src/analyzer/enums.ts
"""
import from typing { TYPE_CHECKING }
import jaclang.jac0core.unitree as uni;
import from . { types }

with entry {
    if TYPE_CHECKING {
        import from .type_evaluator { TypeEvaluator, PrefetchedTypes }
    }
}

# Names that are excluded from enum membership
glob ENUM_RESERVED_NAMES: set[str] = {'name','value','_name_','_value_','_ignore_','_order_','__order__','_missing_','_generate_next_value_'};

"""Check if a name should be excluded from enum membership."""
def is_excluded_enum_member_name(name: str) -> bool;

"""Create enum member info from an assignment statement."""
def create_enum_member_info(
    assignment: uni.Assignment, evaluator: "TypeEvaluator"
) -> (types.EnumMemberInfo | None);

"""Build enum members map for an enum class."""
def build_enum_members(
    enum_node: uni.Enum, evaluator: "TypeEvaluator"
) -> dict[str, types.EnumMemberInfo];

"""Get the value type for special enum subclasses from base classes."""
def get_special_enum_value_type_from_bases(
    base_classes: list[types.TypeBase], prefetch: "PrefetchedTypes"
) -> (types.TypeBase | None);
