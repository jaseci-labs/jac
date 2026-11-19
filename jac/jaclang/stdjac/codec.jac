"""Values to JSON's values, by their types, as a crossing sends them: neojac's stdjac.codec.

`encode(v)` gives what `json.dumps` takes: an object of its fields for an `obj`, a node
or a walker (a node's id under `__jid`), a list for a list, set or tuple, an object for a
dict with str keys and a list of pairs for any other dict, an enum member's name, a
`bytes` as hex digits, a `complex` as `[real, imag]`.
"""
import enum;

def encode(value: any) -> any {
    if value is None or isinstance(value, (bool, int, float, str)) {
        return value;
    }
    if isinstance(value, enum.Enum) {
        return value.name;
    }
    if isinstance(value, (bytes, bytearray)) {
        return bytes(value).hex();
    }
    if isinstance(value, complex) {
        return [value.real, value.imag];
    }
    if isinstance(value, dict) {
        if all([isinstance(k, str) for k in value.keys()]) {
            return {k: encode(v) for (k, v) in value.items()};
        }
        return [[encode(k), encode(v)] for (k, v) in value.items()];
    }
    if isinstance(value, (list, tuple, set, frozenset)) {
        return [encode(v) for v in value];
    }
    fields = _fields_of(value);
    if fields is not None {
        out = {name: encode(v) for (name, v) in fields};
        if isinstance(value, Node) or isinstance(value, Edge) {
            out["__jid"] = str(jid(value));
        }
        return out;
    }
    return str(value);
}

def _fields_of(value: any) -> list[tuple[str, any]] | None {
    names: list[str] = [];
    annotations = getattr(type(value), "__annotations__", None);
    if isinstance(annotations, dict) {
        names = [n for n in annotations.keys() if not n.startswith("_")];
    }
    if not names {
        held = getattr(value, "__dict__", None);
        if not isinstance(held, dict) {
            return None;
        }
        names = [n for n in held.keys() if not n.startswith("_")];
    }
    return [(n, getattr(value, n, None)) for n in names if hasattr(value, n)];
}
