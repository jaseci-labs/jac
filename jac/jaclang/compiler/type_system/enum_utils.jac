"""
Utilities for enum type checking.

PyrightReference: packages/pyright-internal/src/analyzer/enums.ts
"""
import jaclang.jac0core.unitree as uni;
import from . { types }
import type from .type_evaluator { TypeEvaluator, PrefetchedTypes }

# Names that are excluded from enum membership
glob ENUM_RESERVED_NAMES: set[str] = {'name','value','_name_','_value_','_ignore_','_order_','__order__','_missing_','_generate_next_value_'};

"""Check if a name should be excluded from enum membership."""
def is_excluded_enum_member_name(name: str) -> bool;

"""Create enum member info from an assignment statement."""
def create_enum_member_info(
    assignment: uni.Assignment, evaluator: "TypeEvaluator"
) -> (types.EnumMemberInfo | None);

"""Validate a per-member type annotation against the member's value type.

Enum member declarations may carry explicit type annotations (e.g.
`PENDING: int = "wrong"`). The declaration site's symbol type is
EnumMemberType, so the generic `exit_assignment` compatibility check
cannot validate the annotation — we do it here, where the member's
value-type context is known.
"""
def validate_enum_member_annotation(
    assignment: uni.Assignment,
    member_info: types.EnumMemberInfo,
    evaluator: "TypeEvaluator"
) -> None;

"""Build enum members map for an enum or class-based enum."""
def build_enum_members(
    enum_node: uni.Enum | uni.Archetype,
    evaluator: "TypeEvaluator",
    enum_value_type: types.TypeBase | None = None
) -> dict[str, types.EnumMemberInfo];

"""Get the value type for special enum subclasses from base classes."""
def get_special_enum_value_type_from_bases(
    base_classes: list[types.TypeBase], prefetch: "PrefetchedTypes"
) -> (types.TypeBase | None);
# Base class names that indicate an enum type (from Python's enum module)
