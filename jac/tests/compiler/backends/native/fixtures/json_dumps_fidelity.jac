"""json.dumps output natively, compared line for line with Python's."""
import json;

def record -> dict[str, any] {
    edges: list[list[str]] = [["web", "api"], ["api", "db"]];
    return {
        "name": "café ☃ \U0001F600",
        "edges": edges,
        "nested": {"flag": True, "none": None, "ratio": 0.25, "big": 12345678901},
        "empty": [],
        "control": "tab\there\x7f"
    };
}

with entry {
    data = record();
    print(json.dumps(data));
    print(json.dumps(data, sort_keys=True));
    print(json.dumps(data, separators=(",", ":")));
    print(json.dumps(data, sort_keys=True, ensure_ascii=False));
    print(json.dumps([float("nan"), float("inf"), float("-inf"), 1.0, -0.5]));
    print(json.dumps(json.loads(json.dumps(data, separators=(",", ":")))));
    print(json.dumps(data, indent=2));
    print(json.dumps([1, 2], indent=0));
    print(json.dumps(data, indent="--", sort_keys=True));
    print(json.dumps(json.loads("[NaN, Infinity, -Infinity]")));
    dec = json.JSONDecoder();
    (v, end) = dec.raw_decode(" [1, 2] x", 2);
    print(json.dumps(v), end);
    enc = json.JSONEncoder(sort_keys=True);
    print(enc.encode({"b": 1, "a": 2}));
    print("".join(enc.iterencode({"z": 0})));
    try {
        json.loads("1 2");
    } except json.JSONDecodeError as e {
        print(e.lineno, e.colno, e.pos, "-", e.msg);
    }
}
