def collect_foreign_structs(
    modules: list[uni.Module]
) -> dict[str, list[tuple[str, str | None]]];

def declared_type_name(type_expr: (uni.UniNode | None)) -> (str | None);

def collect_foreign_fns(modules: list[uni.Module]) -> dict[str, dict[str, any]];

def foreign_struct_layout(
    structs: dict[str, list[tuple[str, str | None]]], name: str
) -> tuple[int, int, list[tuple[int, bool, int]]];
