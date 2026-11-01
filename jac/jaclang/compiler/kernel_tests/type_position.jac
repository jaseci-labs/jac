"""`in_type_position` is the one authority on whether a name is a type or a
value; these cases pin the shape of the language it reads."""

def names_in(src: str, value: str) -> list[Name] {
    return [
        nm
        for nm in parse_text(src, "type_position_probe.jac").get_all_sub_nodes(typ=Name)
        if nm.value == value
    ];
}

def all_type_position(src: str, value: str, count: int) {
    found = names_in(src, value);
    assert len(found) == count , (
        f"expected {count} mentions of {value!r}, found {len(found)} in {src!r}"
    );
    for nm in found {
        assert in_type_position(nm) , (
            f"{value!r} at line {nm.loc.first_line} col {nm.loc.col_start} is a "
            f"type position, but the predicate called it a value: {src!r}"
        );
    }
}

def all_value_position(src: str, value: str, count: int) {
    found = names_in(src, value);
    assert len(found) == count , (
        f"expected {count} mentions of {value!r}, found {len(found)} in {src!r}"
    );
    for nm in found {
        assert not in_type_position(nm) , (
            f"{value!r} at line {nm.loc.first_line} col {nm.loc.col_start} is a "
            f"run-time use, but the predicate called it a type: {src!r}"
        );
    }
}

def annotations_are_types {
    all_type_position(
        "obj Box {\n    has held: Pt;\n}\ndef take(p: Pt) -> int {\n    q: Pt = p;\n    return 0;\n}\n",
        "Pt",
        3
    );
}

def return_type_is_type {
    all_type_position("def make -> Pt {\n    return ret();\n}\n", "Pt", 1);
}

def cast_names_type {
    all_type_position(
        "def widen(p: any) -> int {\n    q = p as Pt;\n    return 0;\n}\n", "Pt", 1
    );
}

def alias_right_side_is_type {
    all_type_position("type Alias = Pt;\n", "Pt", 1);
    all_type_position("type Brand := Pt;\n", "Pt", 1);
}

def generic_bound_and_default_are_types {
    all_type_position("def pick[T: Pt = Pt](v: T) -> T {\n    return v;\n}\n", "Pt", 2);
}

def edge_endpoints_are_types {
    all_type_position("edge Link: Pt --> Pt {}\n", "Pt", 2);
    all_type_position("edge Held: Box --> Box {\n    has via: Pt;\n}\n", "Box", 2);
}

def generic_argument_is_type {
    all_type_position(
        "def take(xs: list[Pt]) -> dict[str, Pt] {\n    return {};\n}\n", "Pt", 2
    );
}

def nested_annotation_is_type {
    all_type_position(
        "def take(xs: dict[str, dict[str, dict[str, list[Pt]]]]) -> int {\n    return 0;\n}\n",
        "Pt",
        1
    );
}

def impl_signature_is_type {
    all_type_position(
        "obj Box {\n    def held -> Pt;\n}\nimpl Box.held -> Pt {\n    return make();\n}\n",
        "Pt",
        2
    );
}

def calls_attributes_and_defaults_are_values {
    all_value_position("with entry {\n    v = Pt();\n}\n", "Pt", 1);
    all_value_position("with entry {\n    v = Pt.origin;\n}\n", "Pt", 1);
    all_value_position("def take(p: any = Pt) -> int {\n    return 0;\n}\n", "Pt", 1);
}

def connect_edge_type_is_value {
    all_value_position(
        "def link(a: any, b: any) -> None {\n    a +>:Pt:+> b;\n}\n", "Pt", 1
    );
}

def subscript_index_is_value_when_excluded {
    nm = names_in("def take(xs: any) -> int {\n    return xs[Idx];\n}\n", "Idx")[0];
    assert in_type_position(nm) , "a subscript argument reads as a type by default";
    assert not in_type_position(nm, include_subscripts=False) , (
        "`xs[Idx]` reads `Idx` at run time once subscripts are excluded"
    );
}

def annotation_survives_excluding_subscripts {
    for src in [
        "def take(xs: dict[str, list[Pt]]) -> int {\n    return 0;\n}\n",
        "def make -> list[Pt] {\n    return [];\n}\n",
        "def widen(raw: any) -> int {\n    v = raw as list[Pt];\n    return 0;\n}\n",
        "type Alias = dict[str, Pt];\n"
    ] {
        nm = names_in(src, "Pt")[0];
        assert in_type_position(nm, include_subscripts=False) , (
            f"the annotation, return type, cast or alias above the subscript makes {src!r} a type position"
        );
    }
}

def type_position_cases -> list[KernelCase] {
    return [
        KernelCase(
            "a parameter, local, and field annotation are type positions",
            annotations_are_types
        ),
        KernelCase("a return type is a type position", return_type_is_type),
        KernelCase("an `as` cast names a type, not a value", cast_names_type),
        KernelCase(
            "a `type` alias right-hand side is a type position",
            alias_right_side_is_type
        ),
        KernelCase(
            "a generic parameter bound and its default are type positions",
            generic_bound_and_default_are_types
        ),
        KernelCase(
            "an edge declaration's endpoints are type positions",
            edge_endpoints_are_types
        ),
        KernelCase(
            "a generic argument inside an annotation is a type position",
            generic_argument_is_type
        ),
        KernelCase(
            "a deeply nested annotation is a type position at any depth",
            nested_annotation_is_type
        ),
        KernelCase(
            "an ability signature inside an impl is a type position",
            impl_signature_is_type
        ),
        KernelCase(
            "a call, an attribute base, and a parameter default are run-time uses",
            calls_attributes_and_defaults_are_values
        ),
        KernelCase(
            "a connect operator's edge type is a run-time use",
            connect_edge_type_is_value
        ),
        KernelCase(
            "a subscript index is a run-time use when subscripts are excluded",
            subscript_index_is_value_when_excluded
        ),
        KernelCase(
            "a generic argument inside an annotation survives excluding subscripts",
            annotation_survives_excluding_subscripts
        )
    ];
}
