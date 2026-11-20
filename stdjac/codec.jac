"""stdjac.codec: values to JSON-shaped values and back, by their types.

Written once with compile-time reflection: the checker unrolls `encode` and
`decode` for each type they are used with into straight-line code, which
every host compiles as it compiles any code. Nothing is reflected on as a
program runs. A JSON-shaped value is None, a bool, an int, a float, a str, a
list of JSON-shaped values or a dict of str to them.

It is strict, so that nothing crosses untyped or is dropped:
- `decode` raises CodecError for a missing field or a value of the wrong
  JSON type. It never coerces (`"12"` is not an int) and never fills in a
  default for a field without one. A JSON number decodes as a float.
- `encode` raises CodecError for an object whose class isn't exactly its
  field's type (a `Dog` in a field typed `Animal`), which decoding would make
  something else of.
- A tuple crosses as a JSON list: `tuple[A, B]` exactly as many items, each
  its position's type; `tuple[E, ...]` any number of E.
- What is not sendable (the crossing ladder: an `any`, a function value, a
  Shared object, a C record, a Python object, ...) is refused where the
  codec is used, at compile time, and so is a union of several types
  besides None, which a JSON value can't say which of. A call between
  spaces refuses first what is not sendable (E1308).
- bytes and a bytearray cross as a JSON string of their bytes in hex; a
  dict whose keys aren't str as a JSON list of its [key, value] pairs.
- An object type takes None, since an object type is nullable. A
  struct, a value, is never None: it crosses as its fields, exactly its
  type.
- A 128-bit int (`i128`, `u128`) crosses as a JSON string of its decimal
  digits, which no JSON reader rounds; a complex as the JSON list of its real
  and imaginary parts; an array or a vector as the JSON list of its
  elements, exactly as many.
- An enum crosses by its member's name.
- An object is restored, not constructed: its `init` and `postinit` don't
  run, and a field it leaves out that has a default takes it.
- A node or an edge crosses as a copy that is the same one to `jid`: its
  fields, and its id as the member `__jid` (a read-only
  detached copy). A store, which keeps a row's id itself, takes the fields
  alone (`encode_object`, `decode_object`).
"""

import from jaclang.comptime {
    fields,
    kind,
    type_args,
    members,
    get_field,
    set_field,
    restore,
    sendable,
    Kind,
}

"""What the codec raises: `value` isn't the type wanted (`decode`), or isn't
exactly its type (`encode`). `path` says where in the whole value it is
(`.author.name`, `[2]`), "" for the whole."""
obj CodecError(Exception) {
    has detail: str,
        path: str = "";

    def __str__ -> str {
        return f"{self.path}: {self.detail}" if self.path != "" else self.detail;
    }
}

"""The JSON-shaped value of `v`, a T."""
def encode[T](v: T) -> any {
    comptime if sendable(T) {
        return encode_sent[T](v);
    } else {
        comptime assert False, "the codec sends only what is sendable: no `any`, function value, Shared object or other type whose values are not their own";
        raise CodecError(detail="not sendable");
    }
}

"""The JSON-shaped value of `v`, a T, which is sendable: by what T is."""
def encode_sent[T](v: T) -> any {
    comptime k = kind(T);
    comptime if k == Kind.INT and (T == i128 or T == u128) {
        return str(v);
    } elif k == Kind.BYTES or k == Kind.BYTEARRAY {
        return v.hex();
    } elif k == Kind.INT or k == Kind.FLOAT or k == Kind.STR or k == Kind.BOOL {
        return v;
    } elif k == Kind.NONE {
        return None;
    } elif k == Kind.ENUM {
        return v.name;
    } elif k == Kind.LIST or k == Kind.SET {
        return encode_items[T](v);
    } elif k == Kind.TUPLE {
        return encode_tuple[T](v);
    } elif k == Kind.DICT {
        return encode_dict[T](v);
    } elif k == Kind.UNION {
        comptime args = type_args(T);
        comptime assert len(args) == 2
            and (
                kind(args[0]) == Kind.NONE or kind(args[1]) == Kind.NONE
            ), "the codec takes a union of one type and None";
        if v is None {
            return None;
        }
        comptime for a in args {
            comptime if kind(a) != Kind.NONE {
                return encode[a](v);
            }
        }
    } elif k == Kind.NODE or k == Kind.EDGE {
        return encode_kept[T](v);
    } elif k == Kind.OBJ or k == Kind.WALKER {
        return encode_object[T](v);
    } elif k == Kind.STRUCT {
        return encode_struct[T](v);
    } elif k == Kind.COMPLEX {
        return [v.real, v.imag];
    } elif k == Kind.ARRAY {
        return encode_array[T](v);
    } else {
        comptime assert False, "the codec has no JSON form for this type";
        raise CodecError(detail="no JSON form");
    }
}

"""The T the JSON-shaped value `v` holds: exactly one, nothing coerced."""
def decode[T](v: any) -> T {
    comptime if sendable(T) {
        return decode_sent[T](v);
    } else {
        comptime assert False, "the codec sends only what is sendable: no `any`, function value, Shared object or other type whose values are not their own";
        raise CodecError(detail="not sendable");
    }
}

"""The T the JSON-shaped value `v` holds, T sendable: by what T is."""
def decode_sent[T](v: any) -> T {
    comptime k = kind(T);
    comptime if k == Kind.INT and (T == i128 or T == u128) {
        return decode_wide[T](v);
    } elif k == Kind.BYTES or k == Kind.BYTEARRAY {
        return decode_bytes[T](v);
    } elif k == Kind.INT {
        if isinstance(v, int) and not isinstance(v, bool) {
            return v;
        }
        raise CodecError(detail=f"expected an int, got {v!r}");
    } elif k == Kind.FLOAT {
        if isinstance(v, float) {
            return v;
        }
        if isinstance(v, int) and not isinstance(v, bool) {
            # (JSON has one kind of number: 1 is 1.0, as the float type T
            # holds it.)
            return T(float(v));
        }
        raise CodecError(detail=f"expected a float, got {v!r}");
    } elif k == Kind.STR {
        if isinstance(v, str) {
            return v;
        }
        raise CodecError(detail=f"expected a str, got {v!r}");
    } elif k == Kind.BOOL {
        if isinstance(v, bool) {
            return v;
        }
        raise CodecError(detail=f"expected a bool, got {v!r}");
    } elif k == Kind.NONE {
        if v is None {
            return None;
        }
        raise CodecError(detail=f"expected None, got {v!r}");
    } elif k == Kind.ENUM {
        if isinstance(v, str) {
            comptime for m in members(T) {
                if v == m.name {
                    return m;
                }
            }
        }
        raise CodecError(detail=f"expected a member's name, got {v!r}");
    } elif k == Kind.LIST or k == Kind.SET {
        return decode_items[T](v);
    } elif k == Kind.TUPLE {
        return decode_tuple[T](v);
    } elif k == Kind.DICT {
        return decode_dict[T](v);
    } elif k == Kind.UNION {
        comptime args = type_args(T);
        comptime assert len(args) == 2
            and (
                kind(args[0]) == Kind.NONE or kind(args[1]) == Kind.NONE
            ), "the codec takes a union of one type and None";
        if v is None {
            return None;
        }
        comptime for a in args {
            comptime if kind(a) != Kind.NONE {
                return decode[a](v);
            }
        }
    } elif k == Kind.NODE or k == Kind.EDGE {
        return decode_kept[T](v);
    } elif k == Kind.OBJ or k == Kind.WALKER {
        return decode_object[T](v);
    } elif k == Kind.STRUCT {
        return decode_struct[T](v);
    } elif k == Kind.COMPLEX {
        return decode_complex(v);
    } elif k == Kind.ARRAY {
        return decode_array[T](v);
    } else {
        comptime assert False, "the codec has no JSON form for this type";
        raise CodecError(detail="no JSON form");
    }
}

# Each kind of type's encoding and decoding, in a function of its own, so
# that the copy check makes of encode and decode for a type holds only what
# that type needs.

"""The bytes or bytearray T a JSON string of hex digits holds, two a byte."""
def decode_bytes[T](v: any) -> T {
    if isinstance(v, str) {
        text: str = v;
        if len(text) % 2 == 0 and all([c in "0123456789abcdefABCDEF" for c in text]) {
            return T(bytes.fromhex(text));
        }
    }
    raise CodecError(detail=f"expected bytes in hex, got {v!r}");
}

"""The 128-bit int T a JSON string of decimal digits holds (a `-` before them
for a negative one); one T does not hold is an error, as converting it is."""
def decode_wide[T](v: any) -> T {
    if not isinstance(v, str) {
        raise CodecError(detail=f"expected a 128-bit int's digits, got {v!r}");
    }
    text: str = v;
    neg = text.startswith("-");
    digits = text[1:] if neg else text;
    if digits == "" or not digits.isdigit() or not digits.isascii() {
        raise CodecError(detail=f"expected a 128-bit int's digits, got {v!r}");
    }
    w = T(0);
    try {
        for ch in digits {
            w = w * T(10) + T(ord(ch) - 48) if not neg else w * T(10) - T(ord(ch) - 48);
        }
    } except OverflowError {
        raise CodecError(detail=f"expected a 128-bit int's digits, got {v!r}");
    }
    return w;
}

"""A list's or a set's JSON list."""
def encode_items[T](v: T) -> list[any] {
    comptime E = type_args(T)[0];
    out: list[any] = [];
    for x in v {
        out.append(encode[E](x));
    }
    return out;
}

"""A tuple's JSON list: each item as its position's type, or for
`tuple[E, ...]`, as E."""
def encode_tuple[T](v: T) -> list[any] {
    out: list[any] = [];
    comptime if variadic(T) {
        comptime E = type_args(T)[0];
        for x in v {
            out.append(encode[E](x));
        }
    } else {
        comptime for i in range(len(type_args(T))) {
            out.append(encode[type_args(T)[i]](v[i]));
        }
    }
    return out;
}

"""A dict's JSON object, its keys str; or, for keys of another type, the JSON
list of its [key, value] pairs."""
def encode_dict[T](v: T) -> any {
    comptime K = type_args(T)[0];
    comptime V = type_args(T)[1];
    comptime if kind(K) == Kind.STR {
        d: dict[str, any] = {};
        for (key, x) in v.items() {
            d[key] = encode[V](x);
        }
        return d;
    } else {
        pairs: list[any] = [];
        for (key, x) in v.items() {
            pairs.append([encode[K](key), encode[V](x)]);
        }
        return pairs;
    }
}

"""What a T is written as, as text: its kind, and for what is made of other
types, theirs. A class or a struct a field holds is named by its kind
alone, so a change within one is not in the text of what holds it."""
def written_as[T] -> str {
    comptime k = kind(T);
    comptime if k == Kind.LIST
        or k == Kind.SET
        or k == Kind.DICT
        or k == Kind.TUPLE
        or k == Kind.UNION
        or k == Kind.ARRAY
    {
        parts: list[str] = [];
        comptime for a in type_args(T) {
            parts.append(written_as[a]());
        }
        return k.name + "[" + ",".join(parts) + "]";
    } else {
        return k.name;
    }
}

"""The shape of class T, as text: each field's name, whether it may be left
out (`?`), and what it is written as. What was written of a T in one shape
decodes as a T of that shape (stdjac.graph, which reads no row of a type
whose shape is the one its rows were written in)."""
def shape_of[T] -> str {
    parts: list[str] = [];
    comptime for f in fields(T) {
        comptime if f.has_default {
            parts.append(f.name + "?:" + written_as[f.type]());
        } else {
            parts.append(f.name + ":" + written_as[f.type]());
        }
    }
    return ";".join(parts);
}

"""Give object `into`, a T, the fields the JSON object `v` holds: what
decode_object would make of `v`, in the object that is there."""
def fill_object[T](into: T, v: any) {
    now = decode_object[T](v);
    comptime for f in fields(T) {
        set_field(into, f.name, get_field(now, f.name));
    }
}

"""An object's JSON object, a member for each field; None for None (an
object type is nullable)."""
def encode_object[T](v: T) -> any {
    if v is None {
        return None;
    }
    if type(v) is not T {
        raise CodecError(
            detail=f"expected exactly the class its type names, got a {type(v).__name__}"
        );
    }
    d: dict[str, any] = {};
    comptime for f in fields(T) {
        d[f.name] = encode[f.type](get_field(v, f.name));
    }
    return d;
}

"""A struct's JSON object, a member for each field."""
def encode_struct[T](v: T) -> dict[str, any] {
    d: dict[str, any] = {};
    comptime for f in fields(T) {
        d[f.name] = encode[f.type](get_field(v, f.name));
    }
    return d;
}

"""An array's or a vector's JSON list: its elements in order."""
def encode_array[T](v: T) -> list[any] {
    comptime E = type_args(T)[0];
    out: list[any] = [];
    for i in range(len(v)) {
        out.append(encode[E](v[i]));
    }
    return out;
}

"""The complex a JSON list of its real and imaginary parts holds."""
def decode_complex(v: any) -> complex {
    if not isinstance(v, list) {
        raise CodecError(detail=f"expected a list, got {v!r}");
    }
    items: list[any] = v;
    if len(items) != 2 {
        raise CodecError(detail=f"expected 2 items, got {len(items)}");
    }
    parts: list[float] = [];
    for (i, x) in enumerate(items) {
        try {
            parts.append(decode[float](x));
        } except CodecError as e {
            raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
        }
    }
    return complex(parts[0], parts[1]);
}

"""The array or vector T a JSON list of exactly its length holds."""
def decode_array[T](v: any) -> T {
    comptime E = type_args(T)[0];
    out = restore(T);
    if not isinstance(v, list) {
        raise CodecError(detail=f"expected a list, got {v!r}");
    }
    items: list[any] = v;
    if len(items) != len(out) {
        raise CodecError(detail=f"expected {len(out)} items, got {len(items)}");
    }
    for (i, x) in enumerate(items) {
        try {
            out[i] = decode[E](x);
        } except CodecError as e {
            raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
        }
    }
    return out;
}

"""The list or set T a JSON list holds."""
def decode_items[T](v: any) -> T {
    comptime E = type_args(T)[0];
    if not isinstance(v, list) {
        raise CodecError(detail=f"expected a list, got {v!r}");
    }
    items: list[any] = v;
    comptime if kind(T) == Kind.LIST {
        out: T = [];
        for (i, x) in enumerate(items) {
            try {
                out.append(decode[E](x));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
        return out;
    } else {
        made: T = set();
        for (i, x) in enumerate(items) {
            try {
                made.add(decode[E](x));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
        return made;
    }
}

"""The tuple T a JSON list holds: exactly as many items as T has, each
decoded as its position's type; for `tuple[E, ...]`, any number of E."""
def decode_tuple[T](v: any) -> T {
    if not isinstance(v, list) {
        raise CodecError(detail=f"expected a list, got {v!r}");
    }
    items: list[any] = v;
    parts: list[any] = [];
    comptime if variadic(T) {
        comptime E = type_args(T)[0];
        for (i, x) in enumerate(items) {
            try {
                parts.append(decode[E](x));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
    } else {
        comptime n = len(type_args(T));
        if len(items) != n {
            raise CodecError(detail=f"expected {n} items, got {len(items)}");
        }
        comptime for i in range(n) {
            try {
                parts.append(decode[type_args(T)[i]](items[i]));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
    }
    # The items, each its position's type already: the tuple T is.
    made: any = tuple(parts);
    return made;
}

"""Whether tuple type `t` is `tuple[E, ...]`, of any length."""
comptime def variadic(t: any) -> bool {
    args = type_args(t);
    if len(args) != 1 {
        return False;
    }
    e = args[0];
    return t == tuple[e, ...];
}

"""The dict T a JSON object holds, its keys str; or, for keys of another
type, the JSON list of its [key, value] pairs."""
def decode_dict[T](v: any) -> T {
    comptime K = type_args(T)[0];
    comptime V = type_args(T)[1];
    d: T = {};
    comptime if kind(K) == Kind.STR {
        if not isinstance(v, dict) {
            raise CodecError(detail=f"expected an object, got {v!r}");
        }
        src: dict[any, any] = v;
        for (key, x) in src.items() {
            if not isinstance(key, str) {
                raise CodecError(detail=f"expected a str key, got {key!r}");
            }
            try {
                d[key] = decode[V](x);
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f".{key}{e.path}");
            }
        }
    } else {
        if not isinstance(v, list) {
            raise CodecError(detail=f"expected a list of [key, value] pairs, got {v!r}");
        }
        items: list[any] = v;
        for (i, p) in enumerate(items) {
            if not isinstance(p, list) {
                raise CodecError(detail=f"expected a [key, value] pair, got {p!r}", path=f"[{i}]");
            }
            pair: list[any] = p;
            if len(pair) != 2 {
                raise CodecError(detail=f"expected a [key, value] pair, got {p!r}", path=f"[{i}]");
            }
            try {
                d[decode[K](pair[0])] = decode[V](pair[1]);
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
    }
    return d;
}

"""The object T a JSON object holds, restored, not constructed: its init and
postinit don't run, and check proves every field without a default is set
before it is returned. None for None (an object type is nullable)."""
def decode_object[T](v: any) -> T {
    if v is None {
        return None;
    }
    if not isinstance(v, dict) {
        raise CodecError(detail=f"expected an object, got {v!r}");
    }
    src: dict[str, any] = v;
    o = restore(T);
    comptime for f in fields(T) {
        comptime if f.has_default {
            if f.name in src {
                try {
                    set_field(o, f.name, decode[f.type](src[f.name]));
                } except CodecError as e {
                    raise CodecError(detail=e.detail, path=f".{f.name}{e.path}");
                }
            }
        } else {
            if f.name not in src {
                raise CodecError(detail=f"missing field '{f.name}'");
            }
            try {
                set_field(o, f.name, decode[f.type](src[f.name]));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f".{f.name}{e.path}");
            }
        }
    }
    return o;
}

"""The struct T a JSON object holds: each field, a field it leaves out
taking its default."""
def decode_struct[T](v: any) -> T {
    if not isinstance(v, dict) {
        raise CodecError(detail=f"expected an object, got {v!r}");
    }
    src: dict[str, any] = v;
    o = restore(T);
    comptime for f in fields(T) {
        comptime if f.has_default {
            if f.name in src {
                try {
                    set_field(o, f.name, decode[f.type](src[f.name]));
                } except CodecError as e {
                    raise CodecError(detail=e.detail, path=f".{f.name}{e.path}");
                }
            }
        } else {
            if f.name not in src {
                raise CodecError(detail=f"missing field '{f.name}'");
            }
            try {
                set_field(o, f.name, decode[f.type](src[f.name]));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f".{f.name}{e.path}");
            }
        }
    }
    return o;
}

"""A node's or an edge's JSON object: its fields, and its id as `__jid`."""
def encode_kept[T](v: T) -> any {
    if v is None {
        return None;
    }
    d: dict[str, any] = encode_object[T](v);
    d["__jid"] = jid(v);
    return d;
}

"""The node or edge T a JSON object holds: a copy of the one whose id it
carries, in no graph. One with no `__jid` is a new one's fields, its id its
own."""
def decode_kept[T](v: any) -> T {
    o = decode_object[T](v);
    if o is None {
        return None;
    }
    src: dict[str, any] = v;
    if "__jid" in src {
        given = src["__jid"];
        if not isinstance(given, str) or not rt_jid_restore(o, given) {
            raise CodecError(detail=f"expected a jid, got {given!r}", path=".__jid");
        }
    }
    return o;
}

"""Whether walker type W declares its reports (`has reports: list[T]`). They
then cross among its fields, by their type; the reports of one that doesn't
are JSON's own values and nothing else."""
def declares_reports[W] -> bool {
    comptime for f in fields(W) {
        comptime if f.name == "reports" {
            return True;
        }
    }
    return False;
}
