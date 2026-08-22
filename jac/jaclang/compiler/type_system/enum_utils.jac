import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    Assignment,
    Enum,
    Int,
    Name,
    NameAtom,
    String
}
import from .types { ClassType, EnumMemberInfo, TypeBase }
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
    assignment: Assignment, evaluator: TypeEvaluator
) -> (EnumMemberInfo | None);

def validate_enum_member_annotation(
    assignment: Assignment, member_info: EnumMemberInfo, evaluator: TypeEvaluator
) -> None;

def build_enum_members(
    enum_node: Enum | Archetype,
    evaluator: TypeEvaluator,
    enum_value_type: TypeBase | None = None
) -> dict[str, EnumMemberInfo];

def get_special_enum_value_type_from_bases(
    base_classes: list[TypeBase], prefetch: PrefetchedTypes
) -> (TypeBase | None);
