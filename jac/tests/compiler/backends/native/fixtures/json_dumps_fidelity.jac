"""json.dumps output natively, compared line for line with Python's."""
import json;
import os;

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

def show_error(doc: str) {
    try {
        json.loads(doc);
        print("no error", doc);
    } except json.JSONDecodeError as e {
        print(doc, e.lineno, e.colno, e.pos, "-", e.msg);
    }
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
    (unicode_v, unicode_end) = dec.raw_decode("\"é\" 1", 0);
    (number_v, number_end) = dec.raw_decode("\"é\" 1", 4);
    print("raw-unicode:", unicode_v, unicode_end, number_v, number_end);
    enc = json.JSONEncoder(sort_keys=True);
    print(enc.encode({"b": 1, "a": 2}));
    print("".join(enc.iterencode({"z": 0})));
}

glob skipkeys_input: dict[str, any] = {"keep": 1};

with entry {
    print(json.dumps(skipkeys_input, skipkeys=True));
}

with entry {
    nonce = 0;
    while True {
        temp_dir = os.path.join(
            "/tmp", "jac_json_dump_fidelity_" + str(os.getpid()) + "_" + str(nonce)
        );
        try {
            os.mkdir(temp_dir, 0o700);
            break;
        } except FileExistsError {
            nonce += 1;
        }
    }
    path = os.path.join(temp_dir, "dump.txt");
    with open(path, "w") as output {
        json.dump({"written": [1, 2]}, output, separators=(",", ":"));
    }
    with open(path, "r") as input {
        print("dump:", input.read());
    }
    os.remove(path);
    os.rmdir(temp_dir);
    show_error("1 2");
    show_error("\"é\" x");
    show_error("");
    show_error("-");
    show_error("01");
    show_error("1.");
    show_error("1e");
    show_error("1e+");
    show_error("[1,]");
    show_error("[1, ]");
    show_error("{\"a\": 1,}");
    show_error("\"abc");
    show_error("\"a\\qb\"");
    show_error("\"\\u12zz\"");
    show_error("\"\\");
    try {
        json.dumps(float("inf"), allow_nan=False);
    } except ValueError as e {
        print("allow_nan:", e);
    }
}
