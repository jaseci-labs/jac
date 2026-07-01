import jaclang.jac0core.unitree as uni;
import from . { types }
import type from .type_evaluator { TypeEvaluator, PrefetchedTypes }

glob ENUM_RESERVED_NAMES: set[str] = {
         'name',
         'value',
         '_name_',
         '_value_',
         '_ignore_',
         '_order_',
         '__order__',
         '_missing_',
         '_generate_next_value_'
     };

def is_excluded_enum_member_name(name: str) -> bool;

def create_enum_member_info(
    assignment: uni.Assignment, evaluator: "TypeEvaluator"
) -> (types.EnumMemberInfo | None);

def validate_enum_member_annotation(
    assignment: uni.Assignment,
    member_info: types.EnumMemberInfo,
    evaluator: "TypeEvaluator"
) -> None;

def build_enum_members(
    enum_node: uni.Enum | uni.Archetype,
    evaluator: "TypeEvaluator",
    enum_value_type: types.TypeBase | None = None
) -> dict[str, types.EnumMemberInfo];

def get_special_enum_value_type_from_bases(
    base_classes: list[types.TypeBase], prefetch: "PrefetchedTypes"
) -> (types.TypeBase | None);
