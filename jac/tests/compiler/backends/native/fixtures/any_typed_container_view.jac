"""A typed container read back through `any` as a container of `any`."""
import json;

def list_text(value: any) -> str {
    if isinstance(value, list) {
        arr: list[any] = value;
        out: list[str] = [];
        for x in arr {
            out.append(str(x));
        }
        return ",".join(out);
    }
    return "not a list";
}

def dict_text(value: any) -> str {
    if isinstance(value, dict) {
        d: dict[str, any] = value;
        out: list[str] = [];
        for k in d.keys() {
            out.append(k + "=" + str(d[k]));
        }
        return ",".join(out);
    }
    return "not a dict";
}

def nested_shape(value: any) -> int {
    if isinstance(value, dict) {
        d: dict[str, any] = value;
        inner = d["c"];
        if isinstance(inner, list) {
            l: list[any] = inner;
            return len(l) * 100 + len(d);
        }
    }
    return -1;
}

def total(xs: list[any]) -> float {
    t = 0.0;
    for x in xs {
        if isinstance(x, int) {
            i: int = x;
            t += i;
        } elif isinstance(x, float) {
            f: float = x;
            t += f;
        }
    }
    return t;
}

def total_of(value: any) -> float {
    return total(value);
}

def views_in_loop(value: any, n: int) -> int {
    acc = 0;
    for _ in range(n) {
        if isinstance(value, list) {
            l: list[any] = value;
            acc += len(l);
        }
    }
    return acc;
}

obj Holder {
    has payload: any = None;
}

def member_text(h: Holder) -> str {
    if isinstance(h.payload, list) {
        return json.dumps(h.payload);
    }
    if isinstance(h.payload, dict) {
        return json.dumps(h.payload);
    }
    return "?";
}

with entry {
    print(list_text([1, 2, 3]));
    print(list_text([1.5, 2.5]));
    print(list_text(["a", "b"]));
    print(dict_text({"b": 1, "a": 2}));
    print(dict_text({"x": 1.25}));
    print(dict_text({"s": "t"}));
}

glob mixed: dict[str, any] = {"b": 1, "a": "x", "c": [1, 2]};
with entry {
    print(nested_shape(mixed));
    print(total_of([1, 2, 3]));
    print(total_of([0.5, 0.25]));
    print(views_in_loop([1, 2, 3], 500));
    print(member_text(Holder(payload=[7, 8])));
    print(member_text(Holder(payload={"q": 9})));
}

glob flags: dict[str, bool] = {"on": True, "off": False};
with entry {
    print(json.dumps(flags));
    print(json.dumps({"b": 1, "a": 2}));
    print(json.dumps(mixed));
    print(json.dumps([1.5, -2.0]));
    print(json.dumps(["p", "q"]));
    print(json.dumps({"k": [[1, 2], [3]], "m": {"n": 7}}));
    print(json.dumps([{"a": 1}, {"b": [2.5, 3.5]}]));
    print(json.dumps({"t": True, "n": None, "l": [None, 1]}));
    print(json.dumps([]));
    print(json.dumps({}));
    print(json.dumps({"z": 3, "y": [4.5]}, sort_keys=True));
    back = json.loads(json.dumps(mixed));
    print(json.dumps(back));
    print(json.dumps(back) == json.dumps(mixed));
}

# The reverse view: a `dict[K, any]` narrowed out of `any` to a typed
# `dict[K, V]` holds JacVals, not raw `V` slots, so it is copied with each
# value unboxed. A typed dict that went through `any` and comes back to its
# own type is the same dict, so writes through either name are shared.
glob raw_i: dict[str, int] = {"x": 41, "y": 42};
glob raw_s: dict[str, str] = {"greet": "hi", "name": "yo"};
glob boxed_s: dict[str, any] = {"greet": "hi", "name": "yo"};
with entry {
    a: any = raw_i;
    print(a["y"]);
    b: dict[str, int] = a;
    print(b["x"] + b["y"]);
    s: any = raw_s;
    greet: str = s["greet"];
    name: str = s["name"];
    print(greet + name);
    t: dict[str, str] = s;
    t["name"] = "yo!";
    print(raw_s["name"]);
    u_any: any = boxed_s;
    u: dict[str, str] = u_any;
    print(u["greet"] + u["name"]);
    print(json.dumps(b) == json.dumps({"x": 41, "y": 42}));
}

def map_text(value: object) -> dict[str, str] {
    out: dict[str, str] = {};
    if isinstance(value, dict) {
        for (k, v) in value.items() {
            out[str(k)] = str(v);
        }
    }
    return out;
}
with entry {
    text = map_text({"a": "1", "b": "2"});
    print(text["b"]);
}
