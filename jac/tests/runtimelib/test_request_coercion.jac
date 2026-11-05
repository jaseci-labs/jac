"""The request binder checks JSON values and parses text values.

JSON already carries types, so a value of the wrong type is refused rather than
reshaped. Query, path, header and form values are always strings, so those are
parsed. `text` says which of the two a value is.
"""

import from datetime { date, datetime, time, timezone }
import from decimal { Decimal }
import from pathlib { Path }
import from uuid { UUID }
import from jaclang.server.serving.coerce { coerce_value }
import from jaclang.server.serving.openapi { _schema_for_type }

enum Color { RED = "red", BLUE = "blue" }

obj Inner {
    has count: int = 0;
}

obj Outer {
    has inner: Inner | None = None,
        items: list[Inner] = [];
}

def refused(value: any, target: any, text: bool = False) -> bool {
    try {
        coerce_value(value, target, text);
    } except (ValueError, TypeError, OverflowError) {
        return True;
    }
    return False;
}

test "a JSON value that is the wrong type is refused, never reshaped" {
    for (value, target) in [
        (19.99, int),
        (True, int),
        ("12", int),
        ("", int),
        ([1], int),
        (True, float),
        ("1.5", float),
        (float("nan"), float),
        (float("inf"), float),
        ({"a": 1}, str),
        ([1, 2], str),
        (1.0, str),
        (True, str),
        ("", bool),
        ("true", bool),
        (1, bool),
        (0, bool),
        ({"a": 1}, bytes),
        ("urgent", list[str]),
        ({"a": 1}, list[str]),
        ("5", list[int]),
        ([1.5], list[int]),
        (5, set[int]),
        ("x", list),
        ("x", dict),
        ("x", dict[str, int]),
        ({"a": 1.9}, dict[str, int]),
        ({"a": 1}, dict[int, str]),
        ("x", tuple[int, int]),
        ([1], tuple[int, int]),
        ([1, 2, 3], tuple[int, int]),
        ([1, "x"], tuple[int, ...]),
        ("zzz", Literal["a", "b"]),
        (1, Literal["a", "b"]),
        (300, u8),
        (-1, u8),
        (3.9, u8),
        ("abc", u8),
        ("7", u8),
        (True, f32),
        ({"count": 1.5}, Inner),
        ({"inner": {"count": "1"}}, Outer),
        ({"items": [{"count": True}]}, Outer),
        ("x", Inner)
    ] {
        assert refused(value, target) , f"{value!r} for {target} should be refused";
    }
}

test "a JSON value of the right type arrives unchanged" {
    assert coerce_value(12, int) == 12;
    assert coerce_value("hi", str) == "hi";
    assert coerce_value(False, bool) is False;
    assert coerce_value(["a"], list[str]) == ["a"];
    assert coerce_value({"a": 1}, dict[str, int]) == {"a": 1};
    assert coerce_value("a", Literal["a", "b"]) == "a";
    assert coerce_value(7, u8) == 7;
    assert coerce_value({"anything": 1}, dict) == {"anything": 1};
    assert coerce_value(["x", 1], list) == ["x", 1];
}

test "a JSON number converts when nothing is lost" {
    three = coerce_value(3.0, int);
    assert three == 3 and type(three) is int;
    one = coerce_value(1, float);
    assert one == 1.0 and type(one) is float;
    assert coerce_value({"count": 2.0}, Inner).count == 2;
}

test "JSON object keys are always strings, so they parse as text" {
    assert coerce_value({"1": "x"}, dict[int, str]) == {1: "x"};
}

test "JSON arrays become the declared collection" {
    assert coerce_value([1, 2], set[int]) == {1, 2};
    assert coerce_value([1, 2], tuple[int, int]) == (1, 2);
    assert coerce_value([1, "x"], tuple[int, str]) == (1, "x");
    assert coerce_value([1, 2, 3], tuple[int, ...]) == (1, 2, 3);
    assert coerce_value([], tuple[int, ...]) == ();
}

test "a union keeps a JSON value that already is one of its members" {
    for (value, target) in [
        (3.9, int | float),
        (3.0, int | float),
        (3, float | int),
        ("12", int | str),
        (12, str | int),
        ("yes", bool | str),
        (True, str | bool),
        ("2026-10-07", datetime | str)
    ] {
        got = coerce_value(value, target);
        assert got == value and type(got) is type(value) , f"{value!r} for {target}";
    }
}

test "a union tries its other members, and refuses when none fits" {
    assert coerce_value(1, float | str) == 1.0;
    assert coerce_value(3.0, int | str) == 3;
    assert coerce_value(None, int | None) is None;
    assert coerce_value("2026-10-07T10:00:00Z", datetime | None).year == 2026;
    assert refused("x", int | None);
    assert refused("x", list[str] | None);
    assert refused(3.5, int | str);
    assert refused(None, int | str);
}

test "text parses into the declared type" {
    for (value, target, want) in [
        ("12", int, 12),
        ("-12", int, -12),
        ("+12", int, 12),
        ("1.5", float, 1.5),
        ("3", float, 3.0),
        ("1e3", float, 1000.0),
        (".5", float, 0.5),
        ("true", bool, True),
        ("YES", bool, True),
        ("0", bool, False),
        ("", bool, False),
        ("hi", str, "hi"),
        ("", str, ""),
        ("7", u8, 7),
        ("1.5", f32, 1.5)
    ] {
        got = coerce_value(value, target, text=True);
        assert got == want and type(got) is type(want) , f"{value!r} for {target}";
    }
}

test "text that does not spell the declared type is refused" {
    for (value, target) in [
        ("abc", int),
        ("3.9", int),
        ("", int),
        (" 12 ", int),
        ("1_000", int),
        ("١٢", int),
        ("abc", float),
        ("nan", float),
        ("inf", float),
        ("1e999", float),
        ("1_000.5", float),
        ("maybe", bool),
        ("300", u8),
        ("zzz", Literal["a", "b"]),
        (["a", "b"], str),
        (["1", "2"], int),
        (["1", "2"], bool),
        ("x", dict[str, int]),
        ("x", Inner)
    ] {
        assert refused(value, target, text=True) , f"{value!r} for {target}";
    }
}

test "text wraps a lone value for a collection and parses each item" {
    assert coerce_value("one", list[str], text=True) == ["one"];
    assert coerce_value("5", list[int], text=True) == [5];
    assert coerce_value(["1", "2"], list[int], text=True) == [1, 2];
    assert coerce_value("5", set[int], text=True) == {5};
    assert coerce_value(["1", "2"], tuple[int, int], text=True) == (1, 2);
    assert coerce_value("one", list[str] | None, text=True) == ["one"];
    assert refused(["1", "x"], list[int], text=True);
    assert refused("1", tuple[int, int], text=True);
}

test "text follows a union's declared order" {
    assert coerce_value("12", int | str, text=True) == 12;
    assert coerce_value("12", str | int, text=True) == "12";
    assert coerce_value("abc", int | str, text=True) == "abc";
}

test "text matches a Literal through the type of each option" {
    assert coerce_value("2", Literal[1, 2], text=True) == 2;
    assert coerce_value("b", Literal["a", "b"], text=True) == "b";
    assert refused("3", Literal[1, 2], text=True);
    assert coerce_value(None, Literal["a", None]) is None;
    assert refused(None, Literal["a", "b"]);
}

test "types spelled as strings parse from both JSON and text" {
    aware = datetime(2026, 10, 7, 10, 0, tzinfo=timezone.utc);
    for text in [False, True] {
        assert coerce_value("2026-10-07T10:00:00Z", datetime, text) == aware;
        assert coerce_value("2026-10-07", date, text) == date(2026, 10, 7);
        assert coerce_value("10:30:00", time, text) == time(10, 30);
        assert coerce_value("1.50", Decimal, text) == Decimal("1.50");
        assert coerce_value("/tmp/x", Path, text) == Path("/tmp/x");
        uid = "12345678-1234-5678-1234-567812345678";
        assert coerce_value(uid, UUID, text) == UUID(uid);
        for (bad, target) in [
            ("not-a-date", datetime),
            ("not-a-date", date),
            ("25:99", time),
            ("not-a-uuid", UUID),
            ("abc", Decimal),
            ("NaN", Decimal),
            ("Infinity", Decimal)
        ] {
            assert refused(bad, target, text) , f"{bad!r} for {target}";
        }
    }
    for (value, target) in [
        (5, datetime),
        ({"year": 2026, "month": 1, "day": 2}, datetime),
        (True, UUID),
        (5, Path),
        (True, Decimal),
        ([1], Decimal)
    ] {
        assert refused(value, target) , f"{value!r} for {target}";
    }
}

test "a datetime answers the form a response renders it in" {
    moment = datetime(2026, 1, 2, 3, 4, 5);
    assert coerce_value(str(moment), datetime) == moment;
}

test "a JSON number is a Decimal, spelled as it was sent" {
    assert coerce_value(19.99, Decimal) == Decimal("19.99");
    assert coerce_value(5, Decimal) == Decimal(5);
}

test "an enum still answers by value" {
    assert coerce_value("red", Color) == Color.RED;
    assert coerce_value("red", Color, text=True) == Color.RED;
    assert refused("nope", Color);
}

test "a name spelled in a parameter declaration follows the same rules" {
    assert refused(3.9, "int");
    assert refused("x", "list");
    assert coerce_value("3", "integer", text=True) == 3;
    assert coerce_value("x", "array", text=True) == ["x"];
    assert coerce_value({"a": 1}, "any") == {"a": 1};
}

test "the schema advertises what the binder accepts" {
    for (target, want) in [
        (datetime, {"type": "string", "format": "date-time"}),
        (date, {"type": "string", "format": "date"}),
        (time, {"type": "string", "format": "time"}),
        (UUID, {"type": "string", "format": "uuid"}),
        (Decimal, {"type": ["string", "number"]}),
        (Path, {"type": "string"}),
        (bytes, {"type": "string"}),
        (u8, {"type": "integer"}),
        (f32, {"type": "number"}),
        (Literal["a", "b"], {"enum": ["a", "b"]}),
        (Color, {"enum": ["red", "blue"]}),
        (list, {"type": "array", "items": {}}),
        (dict, {"type": "object"}),
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
}
