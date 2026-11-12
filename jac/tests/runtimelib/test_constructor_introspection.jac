"""Serving binds request values to declared types and constructor arguments,
independently of generated receiver names."""

import from jaclang.server.serving.coerce { coerce_value }
import from jaclang.server.serving.openapi { _object_schema }
import from jaclang.server.server { ModuleIntrospector }

glob REFUSED: object = object();

obj Payload {
    has args: int,
        kwargs: str = "default";
}

obj Nested {
    has inner: Payload | None = None,
        items: list[Payload] = [];
}

walker Greeting {
    has name: str = "world";
}

test "coercion and schemas follow the declared type and the public constructor" {
    # JSON values carry types, so they are checked. Text from a query, path, header
    # or form is parsed. `want` also pins the type: 3 is not 3.0 and 1 is not True.
    for (text, rows) in [
        (
            False,
            [
                (12, int, 12),
                (3.0, int, 3),
                (19.99, int, REFUSED),
                (True, int, REFUSED),
                ("12", int, REFUSED),
                (1, float, 1.0),
                (True, float, REFUSED),
                ("1.5", float, REFUSED),
                ("", str, ""),
                ({"a": 1}, str, REFUSED),
                (False, bool, False),
                ("", bool, REFUSED),
                (1, bool, REFUSED),
                ("x", bytes, b"x"),
                ({"a": 1}, bytes, REFUSED),
                (["a"], list[str], ["a"]),
                ("urgent", list[str], REFUSED),
                ([1.5], list[int], REFUSED),
                ([1, 2], set[int], {1, 2}),
                ("x", dict[str, int], REFUSED),
                ({"a": 1.9}, dict[str, int], REFUSED),
                (3.9, int | float, 3.9),
                (3.0, int | str, 3),
                (None, int | None, None),
                (None, int | str, REFUSED),
                (3.9, "int", REFUSED),
                ({"a": 1}, "any", {"a": 1}),
                ({"inner": {"args": "1"}}, Nested, REFUSED),
                ({"items": [{"args": True}]}, Nested, REFUSED)
            ]
        ),
        (
            True,
            [
                ("12", int, 12),
                ("-12", int, -12),
                ("3.9", int, REFUSED),
                ("1.5", float, 1.5),
                ("YES", bool, True),
                ("", bool, False),
                ("maybe", bool, REFUSED),
                ("hi", str, "hi"),
                (["a", "b"], str, REFUSED),
                ("one", list[str], ["one"]),
                (["1", "2"], list[int], [1, 2]),
                ("5", set[int], {5}),
                ("12", int | str, 12),
                ("12", str | int, "12"),
                ("3", "integer", 3),
                ("x", Payload, REFUSED)
            ]
        )
    ] {
        for (value, target, want) in rows {
            try {
                got = coerce_value(value, target, text);
            } except (ValueError, TypeError, OverflowError) {
                got = REFUSED;
            }
            assert got == want and type(got) is type(want) , (
                f"text={text} {value!r} for {target}: {got!r}"
            );
        }
    }

    value = coerce_value({"args": 7}, Payload);
    assert value.args == 7;
    assert value.kwargs == "default";
    assert coerce_value({"inner": {"args": 2.0}}, Nested).inner.args == 2;
    schemas: dict[str, any] = {};
    _object_schema(Payload, schemas);
    schema = schemas["Payload"];
    assert set(schema["properties"]) == {"args", "kwargs"};
    assert schema["required"] == ["args"];
}

test "walker introspection excludes the generated receiver" {
    introspector = ModuleIntrospector("constructor_contract", None);
    fields = introspector.introspect_walker(Greeting)["fields"];
    assert set(fields) == {"name", "_jac_spawn_node"};
    assert not fields["name"]["required"];
}
