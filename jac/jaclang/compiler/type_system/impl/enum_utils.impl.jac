import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.type_system { types }
import from jaclang.jac0core.diagnostics { E1001 }
import type from jaclang.compiler.type_system.type_evaluator {
    TypeEvaluator,
    PrefetchedTypes
}

impl is_excluded_enum_member_name(name: str) -> bool {
    return name.startswith('__') or name in ENUM_RESERVED_NAMES;
}

impl create_enum_member_info(
    assignment: uni.Assignment, evaluator: "TypeEvaluator"
) -> (types.EnumMemberInfo | None) {
    if (
        not assignment.target
        or len(assignment.target) == 0
        or not isinstance(target := assignment.target[0], (uni.NameAtom, uni.Name))
        or is_excluded_enum_member_name(member_name := target.value)
    ) {
        return None;
    }

    value_type: types.TypeBase | None = None;
    literal_value: int | str | None = None;
    if val := assignment.value {
        if isinstance(val, uni.Int) {
            value_type = evaluator.prefetch.int_class if evaluator.prefetch else None;
            literal_value = val.lit_value;
        } elif isinstance(val, uni.String) {
            value_type = evaluator.prefetch.str_class if evaluator.prefetch else None;
            literal_value = val.value;
        } else {
            value_type = evaluator.get_type_of_expression(val);
        }
    }

    return types.EnumMemberInfo(
        member_name=member_name, value_type=value_type, literal_value=literal_value
    );
}

impl validate_enum_member_annotation(
    assignment: uni.Assignment,
    member_info: types.EnumMemberInfo,
    evaluator: "TypeEvaluator"
) -> None {
    if assignment.type_tag is None or member_info.value_type is None {
        return;
    }
    annotation_type = evaluator.get_type_of_expression(assignment.type_tag.tag);
    if (
        isinstance(annotation_type, types.ClassType)
        and isinstance(member_info.value_type, types.ClassType)
        and annotation_type.shared != member_info.value_type.shared
    ) {
        evaluator.emit_diag(
            E1001,
            assignment,
            actual=str(member_info.value_type),
            expected=str(annotation_type)
        );
    }
}

impl build_enum_members(
    enum_node: uni.Enum | uni.Archetype,
    evaluator: "TypeEvaluator",
    enum_value_type: types.TypeBase | None = None
) -> dict[str, types.EnumMemberInfo] {
    members: dict[str, types.EnumMemberInfo] = {};
    if not enum_node.body {
        return members;
    }

    int_type = evaluator.prefetch.int_class if evaluator.prefetch else None;
    auto_value = 1;

    all_stmts: list = [
        sym.decl.parent if isinstance(sym.decl.parent, uni.Assignment) else sym.decl
        for (name, sym) in enum_node.names_in_scope.items()
        if not is_excluded_enum_member_name(name)
        and not isinstance(sym.decl.name_of, uni.Ability)
    ];
    for stmt in all_stmts {
        if isinstance(stmt, uni.Assignment) {
            if member_info := create_enum_member_info(stmt, evaluator) {
                if member_info.value_type is None {
                    member_info.value_type = int_type;
                    member_info.literal_value = auto_value;
                }

                if enum_value_type
                and isinstance(member_info.value_type, types.ClassType)
                and member_info.value_type.shared != enum_value_type.shared {
                    evaluator.emit_diag(
                        E1001,
                        stmt,
                        actual=str(member_info.value_type),
                        expected=str(enum_value_type)
                    );
                }

                validate_enum_member_annotation(stmt, member_info, evaluator);
                members[member_info.member_name] = member_info;

                auto_value = member_info.literal_value + 1
                    if isinstance(member_info.literal_value, int)
                    else auto_value;
            }
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

impl get_special_enum_value_type_from_bases(
    base_classes: list[types.TypeBase], prefetch: "PrefetchedTypes"
) -> (types.TypeBase | None) {
    if not prefetch
    or not prefetch.enum_class
    or not prefetch.int_class
    or not prefetch.str_class {
        return None;
    }

    mro_shared_set: set = set();
    for base in base_classes {
        if isinstance(base, types.ClassType) {
            for mro_cls in base.shared.mro {
                mro_shared_set.add(mro_cls.shared);
            }
        }
    }

    has_enum = prefetch.enum_class.shared in mro_shared_set;
    has_int = prefetch.int_class.shared in mro_shared_set;
    has_str = prefetch.str_class.shared in mro_shared_set;

    if has_enum {
        if has_str {
            return prefetch.str_class;
        } elif has_int {
            return prefetch.int_class;
        }
    }
    return None;
}
