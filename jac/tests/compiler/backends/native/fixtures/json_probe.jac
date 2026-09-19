# json.dumps over containers the caller built with typed elements (#9290).
# A dict or list reaches the shim's `value: any` parameter; its elements must be
# boxed on the way in, or the shim reads raw ints as boxed values.
import json;

def ident(v: any) -> any {
    return v;
}

def local_dump -> str {
    import json;
    d = {"k": 3};
    return json.dumps(d);
}

with entry {
    n = 1;
    print(json.dumps({"a": 1}));
    print(json.dumps({"a": "x"}));
    print(json.dumps({"a": 1.5}));
    print(json.dumps({"a": True}));
    print(json.dumps({"a": n}));
    print(json.dumps({"a": int("1")}));
    print(json.dumps([1, 2, 3]));
    print(json.dumps(["x", "y"]));
    print(json.dumps(7));
    print(json.dumps({"a": [1, 2]}));
    print(json.dumps({"a": {"b": 1}}));
    print(local_dump());
    print(json.dumps(json.loads("{\"a\": [1, 2]}")));
    # typed containers keep their contents through an `any` and back
    xs: list[int] = json.loads("[1, 2]");
    print(xs[0] + xs[1]);
    ys: list[int] = ident([4, 5]);
    print(ys[1]);
    d: dict[str, int] = ident({"q": 9});
    print(d["q"]);
    # the same through an optional target, and None through one
    zs: list[int] | None = ident([7, 8]);
    if zs is not None {
        print(zs[1]);
    }
    od: dict[str, int] | None = ident({"r": 6});
    if od is not None {
        print(od["r"]);
    }
    nl: list[int] | None = ident(None);
    print("none" if nl is None else "some");
}
