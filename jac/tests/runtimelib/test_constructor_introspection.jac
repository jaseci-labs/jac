"""Serving binds request values to declared types and constructor arguments,
independently of generated receiver names."""

import from datetime { date, datetime, time }
import from uuid { UUID }
import from jaclang.runtime.convert { ConvertMode }
import from jaclang.runtime.sized { SIZED_TYPES }
import from jaclang.server.serving.coerce { coerce_value }
import from jaclang.server.serving.openapi { _object_schema, _schema_for_type }
import from jaclang.server.server { ModuleIntrospector }

glob REFUSED: object = object(),
     U8: type = SIZED_TYPES["u8"],
     F32: type = SIZED_TYPES["f32"],
     ID: str = "12345678-1234-5678-1234-567812345678";

enum Color { RED = "red", BLUE = "blue" }

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
    # or form is parsed. Stored data is repaired leniently, keeping what already has
    # the type. `want` also pins the type: 3 is not 3.0 and 1 is not True.
    for (mode, rows) in [
        (
            ConvertMode.STRICT,
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
                ({"items": [{"args": True}]}, Nested, REFUSED),
                ("2026-01-02T03:04:05", datetime, datetime(2026, 1, 2, 3, 4, 5)),
                ("2026-01-02", date, date(2026, 1, 2)),
                (ID, UUID, UUID(ID)),
                (1767323045, datetime, REFUSED),
                ("red", Color, Color.RED),
                ("RED", Color, REFUSED),
                (3.0, U8, 3),
                (255, U8, 255),
                (256, U8, REFUSED),
                (3.5, U8, REFUSED),
                ("3", U8, REFUSED),
                (1, F32, 1.0)
            ]
        ),
        (
            ConvertMode.TEXT,
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
                ("x", Payload, REFUSED),
                ("10:30:00", time, time(10, 30)),
                ("7", U8, 7),
                ("-1", U8, REFUSED),
                ("1.5", F32, 1.5)
            ]
        ),
        (
            ConvertMode.LENIENT,
            [
                (19.99, int, 19),
                ("42", int, 42),
                (True, int, True),
                (5, str, "5"),
                (1, bool, True),
                ("maybe", bool, REFUSED),
                ("x", bytes, b"x"),
                (["1"], list[int], ["1"]),
                ([1, 2], tuple[int, ...], (1, 2)),
                ("x", list[int], REFUSED),
                (None, int, REFUSED),
                (None, int | str, None),
                ("7", int | str, 7),
                ("BLUE", Color, Color.BLUE),
                ({"args": 1}, Payload, REFUSED),
                ("2026-01-02", date, date(2026, 1, 2)),
                (3.9, U8, 3),
                (256, U8, REFUSED)
            ]
        )
    ] {
        for (value, target, want) in rows {
            try {
                got = coerce_value(value, target, mode);
            } except (ValueError, TypeError, OverflowError) {
                got = REFUSED;
            }
            assert got == want and type(got) is type(want) , (
                f"{mode} {value!r} for {target}: {got!r}"
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
    for (target, want) in [
        (datetime, {"type": "string", "format": "date-time"}),
        (date, {"type": "string", "format": "date"}),
        (time, {"type": "string", "format": "time"}),
        (UUID, {"type": "string", "format": "uuid"}),
        (U8, {"type": "integer"}),
        (F32, {"type": "number"}),
        (
            list[UUID] | None,
            {"type": "array", "items": {"type": "string", "format": "uuid"}}
        )
    ] {
        assert _schema_for_type(target) == want , f"{target}: {_schema_for_type(
            target
        )}";
    }
}

test "walker introspection excludes the generated receiver" {
    introspector = ModuleIntrospector("constructor_contract", None);
    fields = introspector.introspect_walker(Greeting)["fields"];
    assert set(fields) == {"name", "_jac_spawn_node"};
    assert not fields["name"]["required"];
}
