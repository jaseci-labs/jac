"""Serving binds request values to declared types and constructor arguments,
independently of generated receiver names."""

import from datetime { date, datetime, time, timezone }
import from uuid { UUID }
import from jaclang.server.serving.coerce { coerce_value }
import from jaclang.server.serving.datatypes { UploadFile }
import from jaclang.server.serving.openapi {
    _object_schema,
    _schema_default,
    _schema_for_type
}
import from jaclang.server.server { ModuleIntrospector }

glob REFUSED: object = object(),
     UID: str = "12345678-1234-5678-1234-567812345678";

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
                (1.0, str, REFUSED),
                (False, bool, False),
                ("", bool, REFUSED),
                (1, bool, REFUSED),
                ("x", bytes, b"x"),
                ({"a": 1}, bytes, REFUSED),
                (7, u8, 7),
                (300, u8, REFUSED),
                (3.9, u8, REFUSED),
                (True, f32, REFUSED),
                (["a"], list[str], ["a"]),
                ("urgent", list[str], REFUSED),
                ([1.5], list[int], REFUSED),
                ("x", list, REFUSED),
                ([1, 2], set[int], {1, 2}),
                (5, set[int], REFUSED),
                ({"a": 1}, dict[str, int], {"a": 1}),
                ("x", dict[str, int], REFUSED),
                ({"a": 1.9}, dict[str, int], REFUSED),
                ("x", dict, REFUSED),
                ({"1": "x"}, dict[int, str], {1: "x"}),
                ({"a": 1}, dict[int, str], REFUSED),
                ({"1": "a", "01": "b"}, dict[int, str], REFUSED),
                ([1, "x"], tuple[int, str], (1, "x")),
                ([1], tuple[int, str], REFUSED),
                ([1, 2, 3], tuple[int, ...], (1, 2, 3)),
                ([1, "x"], tuple[int, ...], REFUSED),
                ([], tuple[()], ()),
                ([1], tuple[()], REFUSED),
                ("a", Literal["a", "b"], "a"),
                ("zzz", Literal["a", "b"], REFUSED),
                (1, Literal["a", "b"], REFUSED),
                (None, Literal["a", None], None),
                (None, Literal["a", "b"], REFUSED),
                (3.9, int | float, 3.9),
                (3.0, int | float, 3.0),
                (3, float | int, 3),
                ("12", int | str, "12"),
                ("2026-10-07", datetime | str, "2026-10-07"),
                (1, float | str, 1.0),
                (3.0, int | str, 3),
                (None, int | None, None),
                (float("inf"), float | None, REFUSED),
                (float("nan"), int | float, REFUSED),
                ("x", int | None, REFUSED),
                (None, int | str, REFUSED),
                (3.9, "int", REFUSED),
                ("x", "list", REFUSED),
                ({"a": 1}, "any", {"a": 1}),
                (5, datetime, REFUSED),
                (True, UUID, REFUSED),
                (str(datetime(2026, 1, 2)), datetime, datetime(2026, 1, 2)),
                (5, UploadFile | str, REFUSED),
                ("x", UploadFile, REFUSED),
                (["x"], list[UploadFile], REFUSED)
            ]
        ),
        (
            True,
            [
                ("12", int, 12),
                ("-12", int, -12),
                ("abc", int, REFUSED),
                ("3.9", int, REFUSED),
                ("", int, REFUSED),
                (" 12 ", int, REFUSED),
                ("1_000", int, REFUSED),
                ("١٢", int, REFUSED),
                (["1", "2"], int, REFUSED),
                ("1.5", float, 1.5),
                ("3", float, 3.0),
                ("1e3", float, 1000.0),
                ("nan", float, REFUSED),
                ("inf", float, REFUSED),
                ("1e999", float, REFUSED),
                ("1_000.5", float, REFUSED),
                ("true", bool, True),
                ("", bool, False),
                ("maybe", bool, REFUSED),
                ("hi", str, "hi"),
                (["a", "b"], str, REFUSED),
                ("7", u8, 7),
                ("300", u8, REFUSED),
                ("1.5", f32, 1.5),
                ("one", list[str], ["one"]),
                (["1", "2"], list[int], [1, 2]),
                (["1", "x"], list[int], REFUSED),
                ("one", list[str] | None, ["one"]),
                ("5", set[int], {5}),
                (["1", "2"], tuple[int, int], (1, 2)),
                ("1", tuple[int, int], REFUSED),
                ("12", int | str, 12),
                ("12", str | int, "12"),
                ("abc", int | str, "abc"),
                ("2", Literal[1, 2], 2),
                ("3", Literal[1, 2], REFUSED),
                ("3", "integer", 3),
                ("x", "array", ["x"]),
                ("x", Payload, REFUSED),
                ("x", UploadFile | str, "x")
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

    # A string-spelled type reads the same from JSON and from text.
    aware = datetime(2026, 10, 7, 10, 0, tzinfo=timezone.utc);
    for text in [False, True] {
        for (value, target, want) in [
            ("2026-10-07T10:00:00Z", datetime, aware),
            ("2026-10-07", date, date(2026, 10, 7)),
            ("10:30:00", time, time(10, 30)),
            (UID, UUID, UUID(UID)),
            ("red", Color, Color.RED),
            ("not-a-date", datetime, REFUSED),
            ("25:99", time, REFUSED),
            ("not-a-uuid", UUID, REFUSED),
            ("nope", Color, REFUSED)
        ] {
            try {
                got = coerce_value(value, target, text);
            } except ValueError {
                got = REFUSED;
            }
            assert got == want , f"text={text} {value!r} for {target}: {got!r}";
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
    for body in [{"inner": {"args": "1"}}, {"items": [{"args": True}]}] {
        try {
            coerce_value(body, Nested);
            assert False , f"{body!r} should be refused";
        } except ValueError {}
    }

    for (target, want) in [
        (datetime, {"type": "string", "format": "date-time"}),
        (date, {"type": "string", "format": "date"}),
        (time, {"type": "string", "format": "time"}),
        (UUID, {"type": "string", "format": "uuid"}),
        (bytes, {"type": "string"}),
        (u8, {"type": "integer"}),
        (f32, {"type": "number"}),
        (Literal["a", "b"], {"enum": ["a", "b"]}),
        (Color, {"enum": ["red", "blue"]}),
        (tuple[()], {"type": "array", "maxItems": 0}),
        (
            set[int],
            {"type": "array", "items": {"type": "integer"}, "uniqueItems": True}
        ),
        (tuple[int, ...], {"type": "array", "items": {"type": "integer"}}),
        (
            tuple[int, str],
            {
                "type": "array",
                "prefixItems": [{"type": "integer"}, {"type": "string"}],
                "minItems": 2,
                "maxItems": 2
            }
        )
    ] {
        got = _schema_for_type(target);
        assert got == want , f"{target}: {got}";
    }
    for (declared, want) in [
        (Color.RED, "red"),
        (datetime(2026, 1, 2), "2026-01-02T00:00:00"),
        ({2, 1}, [1, 2]),
        (5, 5)
    ] {
        assert _schema_default(declared) == want , f"{declared!r}";
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
