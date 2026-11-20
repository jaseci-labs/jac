---
description: The native json module, as CPython's json, with how decoded values are typed and where it differs.
keywords: json, json.decoder, json.encoder, json.scanner, json.dumps, json.dump, json.loads, json.load, json.detect_encoding, JSONDecodeError, JSONEncoder, JSONDecoder
---
# json

`json` reads and writes JSON as CPython's `json` does: the same functions, options, output text,
exceptions and messages. It is native: `import json` compiles jac's own module into the
program, with no Python in it (see [The library](index.md), `jac docs library`).

```jac
import json;

with entry {
    doc = {"name": "grid", "size": [3, 4], "ok": True, "scale": 0.5, "tag": None};
    text = json.dumps(doc);
    print(text);
    print(json.dumps({"b": 1, "a": [1, 2]}, indent=2, sort_keys=True));
    data: dict[str, any] = json.loads(text);
    size: list[int] = data["size"];
    print(data["name"], size[0] * size[1], type(data["scale"]).__name__);
}
```

```output
{"name": "grid", "size": [3, 4], "ok": true, "scale": 0.5, "tag": null}
{
  "a": [
    1,
    2
  ],
  "b": 1
}
grid 12 float
```

## What is there

| Name | What it is |
|---|---|
| `dumps(obj, *, skipkeys, ensure_ascii, check_circular, allow_nan, cls, indent, separators, default, sort_keys)` | `obj` as JSON text |
| `dump(obj, fp, ...)` | The same, written to any object with a `write(str)` method |
| `loads(s, *, cls, object_hook, parse_float, parse_int, parse_constant, object_pairs_hook, array_hook)` | A value from JSON text (`str`, `bytes` or `bytearray`) |
| `load(fp, ...)` | The same, read from any object with a `read()` method |
| `detect_encoding(b)` | The encoding of a JSON document given as bytes |
| `JSONEncoder`, `JSONDecoder` | The classes the functions work through; a program may subclass them |
| `JSONDecodeError` | A `ValueError` with `msg`, `doc`, `pos`, `lineno`, `colno` |
| `json.decoder`, `json.encoder`, `json.scanner` | The submodules, with CPython's names (`make_scanner`, `NUMBER_RE`, `encode_basestring`, `encode_basestring_ascii`, `py_encode_basestring`, `py_encode_basestring_ascii`, `ESCAPE_DCT`) |

`array_hook` is Python 3.15's: it receives each decoded array's list.

## Decoded values are `any`

`loads` returns `any`. The values inside are `dict`, `list`, `str`, `int`, `float`, `bool` and
`None`, as in Python. Give a value its type by assigning it to an annotated name
(`data: dict[str, any] = json.loads(text);`); a value of another type raises `TypeError` there.

## Encoding objects

An `obj` is not serializable by default (`TypeError: Object of type Point is not JSON
serializable`). Pass `default=`, or subclass `JSONEncoder` and override its `default` method.
`default` is a Jac keyword, so the declaration writes it with a backtick; a call through
`super` does not need one:

```jac
import json;

obj Point {
    has x: int,
        y: int;
}

obj PointEncoder(json.JSONEncoder) {
    override def `default(o: any) -> any {
        if isinstance(o, Point) {
            return {"x": o.x, "y": o.y};
        }
        return super.default(o);
    }
}

def as_point(d: dict[str, any]) -> any {
    if "x" in d and "y" in d {
        return Point(x=d["x"], y=d["y"]);
    }
    return d;
}

with entry {
    print(json.dumps([Point(x=1, y=2)], cls=PointEncoder));
    print(json.dumps(Point(x=3, y=4), default=lambda (o: any) -> any { return [o.x, o.y]; }));
    print(json.loads('{"x": 5, "y": 6}', object_hook=as_point));
    try {
        json.loads('{"a": 1,}');
    } except json.JSONDecodeError as e {
        print(e, "|", e.pos, e.lineno, e.colno);
    }
}
```

```output
[{"x": 1, "y": 2}]
[3, 4]
Point(x=5, y=6)
Illegal trailing comma before end of object: line 1 column 8 (char 7) | 7 1 8
```

## Behavior worth knowing

All as CPython's:

- Floats are written in their shortest round-trip form; `inf` and `nan` as `Infinity`,
  `-Infinity` and `NaN`, or `ValueError` under `allow_nan=False`.
- Keys that are not `str` are written as strings: `1` as `"1"`, `2.5` as `"2.5"`, `None` as
  `"null"`. Another key type raises `TypeError: keys must be str, int, float, bool or None, not
  tuple`, unless `skipkeys=True` leaves it out.
- Tuples are written as arrays.
- A container that contains itself raises `ValueError: Circular reference detected`. With
  `check_circular=False`, and for nesting deeper than the stack allows, `RecursionError` is
  raised (the program does not crash).
- `loads` gives an `int` for an integer literal and a `float` otherwise (`1E2` is `100.0`), keeps
  the last of duplicate keys and accepts `NaN`, `Infinity` and `-Infinity`. `object_pairs_hook`
  takes precedence over `object_hook`; `strict=False` allows control characters in strings.
  `parse_float`, `parse_int` and `parse_constant` receive the literal's text.
- `loads` decodes a lone surrogate escape (`"\ud800"`) to that code point and joins a valid
  pair into one character. Deep nesting (20000 arrays) is read without `RecursionError`. A str
  starting with U+FEFF raises `JSONDecodeError: Unexpected UTF-8 BOM (decode using utf-8-sig)`.
- A `JSONDecodeError`'s message ends with where it was found:
  `Expecting ',' delimiter: line 1 column 4 (char 3)`.
- `dumps` writes a list or dict that occurs twice (but does not contain itself) each time it
  occurs. A float key is written as its JSON form: `inf` as `"Infinity"`.
- `detect_encoding` names `utf-8`, `utf-8-sig`, `utf-16`, `utf-16-le`, `utf-16-be`,
  `utf-32`, `utf-32-le` or `utf-32-be`, from a byte-order mark or the pattern of zero bytes.
- `dump` writes as it goes: when a value cannot be serialized, what came before it has already
  been written to `fp`.

## Differences from CPython

- **Integers are 64-bit.** An integer literal past the range raises
  `OverflowError: int too large to fit in 64 bits` as it is read; CPython returns a larger int.
- **Bytes input must be UTF-8.** `detect_encoding` recognizes UTF-16 and UTF-32, but `loads` of
  such bytes raises `LookupError: unknown encoding: utf-16`. Decode the text first.
- **`cls` is typed `any`**: the class is checked when it is called, not when the program
  compiles.
- An argument of the wrong static type is a compile error, not a `TypeError` (see
  [The library](index.md)).

## What is not there

`json.encoder.ESCAPE`, `ESCAPE_ASCII` and `HAS_UTF8` are left out on purpose (they are compiled
regular expressions, which would link `re` into every program that uses `json`). Naming one is
E5142:

```jac
# expect: E5142
import from json.encoder { ESCAPE }

with entry {
    print(ESCAPE);
}
```

`json.tool`, the command-line tool, has no native module: `import json.tool` is E5143 (see
[The library](index.md)). Any other name the module lacks is E1145.
