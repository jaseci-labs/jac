"""Serving binds request values to declared types and constructor arguments,
independently of generated receiver names."""

import typing;

import from datetime { date, datetime, time, timezone }
import from enum { IntFlag }
import from uuid { UUID }
import from jaclang.server.serving.coerce { coerce_value }
import from jaclang.server.serving.datatypes { UploadFile }
import from jaclang.server.serving.openapi { _object_schema, _schema_for_type }
import from jaclang.server.server { ModuleIntrospector }

glob REFUSED: object = object(),
     UID: str = "12345678-1234-5678-1234-567812345678";

enum Color { RED = "red", BLUE = "blue" }

enum Priority { LOW = 1, HIGH = 2 }

enum Perm(IntFlag) { READ = 1, WRITE = 2 }

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
                (1e300, int, REFUSED),
                (1, float, 1.0),
                (True, float, REFUSED),
                ("1.5", float, REFUSED),
                (float("inf"), float, REFUSED),
                ("", str, ""),
                ({"a": 1}, str, REFUSED),
                (False, bool, False),
                ("", bool, REFUSED),
                (1, bool, REFUSED),
                ("x", bytes, b"x"),
                ({"a": 1}, bytes, REFUSED),
                (7, u8, 7),
                (300, u8, REFUSED),
                (["a"], list[str], ["a"]),
                ("urgent", list[str], REFUSED),
                ([1.5], list[int], REFUSED),
                ([1, 2], set[int], {1, 2}),
                ("x", dict[str, int], REFUSED),
                ({"a": 1.9}, dict[str, int], REFUSED),
                ({"1": "x"}, dict[int, str], {1: "x"}),
                ({"1": "a", "01": "b"}, dict[int, str], REFUSED),
                ([1, "x"], tuple[int, str], (1, "x")),
                ([1], tuple[int, str], REFUSED),
                ([1, 2, 3], tuple[int, ...], (1, 2, 3)),
                ([1, "x"], tuple[int, ...], REFUSED),
                ([1], tuple[()], REFUSED),
                ([1, "x"], typing.Tuple, (1, "x")),
                ([1, 2], tuple, (1, 2)),
                ("a", Literal["a", "b"], "a"),
                ("zzz", Literal["a", "b"], REFUSED),
                (None, Literal["a", None], None),
                (3.9, int | float, 3.9),
                (3.0, int | float, 3.0),
                (3, float | int, 3),
                ("2026-10-07", datetime | str, "2026-10-07"),
                (3.0, int | str, 3),
                (None, int | None, None),
                (float("inf"), float | None, REFUSED),
                (None, int | str, REFUSED),
                (3.9, "int", REFUSED),
                ({"a": 1}, "any", {"a": 1}),
                ({"a": 1}, typing.Any, {"a": 1}),
                (
                    "2026-10-07T10:00:00Z",
                    datetime,
                    datetime(2026, 10, 7, 10, 0, tzinfo=timezone.utc)
                ),
                ("not-a-date", datetime, REFUSED),
                (5, datetime, REFUSED),
                (str(datetime(2026, 1, 2)), datetime, datetime(2026, 1, 2)),
                ("2026-10-07", date, date(2026, 10, 7)),
                ("10:30:00", time, time(10, 30)),
                (UID, UUID, UUID(UID)),
                ("not-a-uuid", UUID, REFUSED),
                ("red", Color, Color.RED),
                ("nope", Color, REFUSED),
                (2, Priority, Priority.HIGH),
                (True, Priority, REFUSED),
                (3, Perm, Perm.READ | Perm.WRITE),
                (0, Perm, Perm(0)),
                (5, UploadFile | str, REFUSED),
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
                (" 12 ", int, REFUSED),
                ("1_000", int, REFUSED),
                ("١٢", int, REFUSED),
                ("1.5", float, 1.5),
                ("1e3", float, 1000.0),
                (".5", float, 0.5),
                ("nan", float, REFUSED),
                ("1e999", float, REFUSED),
                ("1_000.5", float, REFUSED),
                ("YES", bool, True),
                ("", bool, False),
                ("maybe", bool, REFUSED),
                ("hi", str, "hi"),
                (["a", "b"], str, REFUSED),
                ("7", u8, 7),
                ("1.5", f32, 1.5),
                ("one", list[str], ["one"]),
                (["1", "2"], list[int], [1, 2]),
                ("one", list[str] | None, ["one"]),
                ("5", set[int], {5}),
                (["1", "2"], tuple[int, int], (1, 2)),
                (["1", "2"], tuple[int, ...], (1, 2)),
                ("12", int | str, 12),
                ("12", str | int, "12"),
                ("2", Literal[1, 2], 2),
                ("2", Priority, Priority.HIGH),
                ("3", Perm, Perm.READ | Perm.WRITE),
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

    # An error names the problem without repeating what was sent.
    for (target, text) in [(Color, False), (bool, True), (datetime, False)] {
        try {
            coerce_value("secret-value", target, text);
            assert False , f"{target} accepted it";
        } except ValueError as e {
            assert "secret-value" not in str(e) , str(e);
        }
    }

    value = coerce_value({"args": 7}, Payload);
    assert value.args == 7;
    assert value.kwargs == "default";
    assert coerce_value({"inner": {"args": 2.0}}, Nested).inner.args == 2;

    for (target, want) in [
        (datetime, {"type": "string", "format": "date-time"}),
        (UUID, {"type": "string", "format": "uuid"}),
        (bytes, {"type": "string"}),
        (u8, {"type": "integer"}),
        (f32, {"type": "number"}),

    ] {
        got = _schema_for_type(target);
        assert got == want , f"{target}: {got}";
    }
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
