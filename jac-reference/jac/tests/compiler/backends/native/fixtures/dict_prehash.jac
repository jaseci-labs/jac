"""Static-key container access: compile-time hashes must agree with runtime.

Every function cross-checks the two hashing paths against each other: keys
inserted through compile-time-known string literals are looked up through
runtime-concatenated strings (which cannot be prehashed), and vice versa.
If the compile-time FNV-1a ever diverged from the emitted hash function,
these lookups would miss and the digit encodings below would show 9s.
"""

def make_key(prefix: str, suffix: str) -> str {
    return prefix + suffix;
}

def static_insert_runtime_lookup -> int {
    d: dict[str, int] = {
        "alpha": 1,
        "": 2,
        "日本語キー": 3,
        "a-very-long-key-that-spans-well-beyond-one-hash-block": 4
    };
    total = 0;
    k1 = make_key("al", "pha");
    total = total * 10 + ((d[k1] if k1 in d else 9));
    k2 = make_key("", "");
    total = total * 10 + ((d[k2] if k2 in d else 9));
    k3 = make_key("日本", "語キー");
    total = total * 10 + ((d[k3] if k3 in d else 9));
    k4 = make_key("a-very-long-key-", "that-spans-well-beyond-one-hash-block");
    total = total * 10 + ((d[k4] if k4 in d else 9));
    return total;
}

def runtime_insert_static_lookup -> int {
    d: dict[str, int] = {};
    d[make_key("al", "pha")] = 5;
    d[make_key("", "")] = 6;
    d[make_key("日本", "語キー")] = 7;
    total = 0;
    total = total * 10 + ((d["alpha"] if "alpha" in d else 9));
    total = total * 10 + ((d[""] if "" in d else 9));
    total = total * 10 + ((d["日本語キー"] if "日本語キー" in d else 9));
    return total;
}

def static_store_runtime_lookup -> int {
    d: dict[str, int] = {};
    d["alpha"] = 5;
    d["beta"] = 6;
    k1 = make_key("al", "pha");
    k2 = make_key("be", "ta");
    total = 0;
    total = total * 10 + ((d[k1] if k1 in d else 9));
    total = total * 10 + ((d[k2] if k2 in d else 9));
    return total;
}

def set_static_runtime_membership -> int {
    s: set[str] = {"px", "", "ünïcode"};
    total = 0;
    total += 1 if make_key("p", "x") in s else 0;
    total += 10 if make_key("", "") in s else 0;
    total += 100 if make_key("ünï", "code") in s else 0;
    return total;
}

def overwrite_across_paths -> int {
    d: dict[str, int] = {"alpha": 1};
    d[make_key("al", "pha")] = 2;
    d["alpha"] = 3;
    return d["alpha"] * 10 + len(d);
}

def embedded_nul_key -> int {
    d: dict[str, int] = {"a\0b": 1};
    k = make_key("a", "\0b");
    return d[k] if k in d else 9;
}
