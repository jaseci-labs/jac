"""Randomized differential fuzz for the serde wide-lane codec (FFI-LANES 2.7).

The deterministic conformance (WIDE-LANE-CONFORMANCE.md 3-4) proved the Jac
MessagePack codec is wire-compatible with real `rmp_serde` on a handful of fixed
documents. This adds the *randomized* half the plan called for:

  * DIFFERENTIAL vs real rmp_serde -- `fixtures/wide_fuzz_corpus.jsonl` is 800
    random value trees, each paired with `rmp_serde::to_vec_named` of that exact
    value (generated offline by `fixtures/wide_fuzz/gen.rs`, deterministic). The
    ctypes decoder must reproduce every tree from the real rmp bytes.
  * ENCODER<->DECODER FIXED POINT -- for every corpus tree AND for a seeded
    pure-Python generator that adds float specials (NaN / +-Inf / -0.0) and edge
    integers that JSON cannot carry, `_mp_decode(_mp_encode(t))` must equal `t`.

Only the CPython (ctypes) codec is exercised here: the na `_msgpack.jac` decoder
reads raw memory through native-only intrinsics (`__jac_bytes_from_raw`), so it
cannot run in a CPython harness -- it is validated natively (AOT e2e, doc 6b) and
shares this identical wire contract. All values stay inside the codec's supported
domain: null / bool / i64 / u64 / f64 / utf-8 str (incl. NUL) / list / str-keyed
dict.
"""

import json;
import os;
import math;
import from jaclang.compiler.rust_bridge._ctypes_codegen { _mp_encode, _mp_decode }


"""Strict structural equality: a bool is never equal to an int (0/1), an int is
never equal to a float (2 vs 2.0), and two NaNs compare equal (so a round-tripped
NaN is accepted). Everything else is by-value, recursing into list / dict."""
def _eq(a: object, b: object) -> bool {
    if isinstance(a, bool) or isinstance(b, bool) {
        return isinstance(a, bool) and isinstance(b, bool) and a == b;
    }
    if isinstance(a, int) and isinstance(b, int) {
        return a == b;
    }
    if isinstance(a, float) and isinstance(b, float) {
        if math.isnan(a) or math.isnan(b) {
            return math.isnan(a) and math.isnan(b);
        }
        return a == b;
    }
    if isinstance(a, int)
    or isinstance(a, float)
    or isinstance(b, int)
    or isinstance(b, float) {
        # one is numeric and the other isn't the same numeric kind -> unequal
        return False;
    }
    if a is None or b is None {
        return a is None and b is None;
    }
    if isinstance(a, str) and isinstance(b, str) {
        return a == b;
    }
    if isinstance(a, list) and isinstance(b, list) {
        if len(a) != len(b) {
            return False;
        }
        for i in range(len(a)) {
            if not _eq(a[i], b[i]) {
                return False;
            }
        }
        return True;
    }
    if isinstance(a, dict) and isinstance(b, dict) {
        if set(a.keys()) != set(b.keys()) {
            return False;
        }
        for k in a.keys() {
            if not _eq(a[k], b[k]) {
                return False;
            }
        }
        return True;
    }
    return False;
}


test "differential: the ctypes decoder reproduces every rmp_serde corpus tree" {
    path = os.path.join(
        os.path.dirname(__file__), "fixtures", "wide_fuzz_corpus.jsonl"
    );
    f = open(path);
    lines = f.read().splitlines();
    f.close();
    assert len(lines) >= 800 , len(lines);
    n = 0;
    for line in lines {
        if not line {
            continue;
        }
        rec = json.loads(line);
        tree = rec["tree"];
        raw = bytes.fromhex(rec["msgpack"]);
        # our decoder vs real rmp_serde's encoding of the same value
        got = _mp_decode(raw);
        assert _eq(got, tree) , f"decode mismatch on record {n}: {got!r} != {tree!r}";
        # and the encoder<->decoder round-trip is a fixed point
        rt = _mp_decode(_mp_encode(tree));
        assert _eq(rt, tree) , f"roundtrip mismatch on record {n}: {rt!r} != {tree!r}";
        n += 1;
    }
    assert n >= 800 , n;
}


# ── seeded pure-Python generator (adds what JSON cannot carry) ──────────────────

glob _I64_MIN: int = -0x8000000000000000,
     _U64_MAX: int = 0xFFFFFFFFFFFFFFFF;


def _rand_str(rng: object) -> str {
    alphabet = ["a", "Z", "0", " ", "π", "é", "\U0001f600", "\x00", "\n", "\""];
    out = "";
    for _ in range(rng.randint(0, 5)) {
        out += alphabet[rng.randint(0, len(alphabet) - 1)];
    }
    return out;
}


def _rand_value(rng: object, depth: int) -> object {
    # Leaves only at depth 0; specials biased in so they are actually hit.
    hi = 6 if depth == 0 else 8;
    choice = rng.randint(0, hi);
    if choice == 0 {
        return None;
    }
    if choice == 1 {
        return rng.randint(0, 1) == 1;
    }
    if choice == 2 {
        # full i64/u64 range including the extremes and high-bit-set u64
        return rng.randint(_I64_MIN, _U64_MAX);
    }
    if choice == 3 {
        # float specials + ordinary doubles
        return rng.choice(
            [
                float("nan"),
                float("inf"),
                float("-inf"),
                -0.0,
                0.0,
                rng.uniform(-1.0e9, 1.0e9),
                3.25,
                1.0
            ]
        );
    }
    if choice == 4 {
        return _rand_str(rng);
    }
    if choice == 5 {
        # small integers around the fixint boundaries
        return rng.randint(-40, 300);
    }
    if choice == 6 {
        return [_rand_value(rng, depth - 1) for _ in range(rng.randint(0, 5))];
    }
    out = {};
    for _ in range(rng.randint(0, 5)) {
        out[_rand_str(rng)] = _rand_value(rng, depth - 1);
    }
    return out;
}


test "fuzz: encoder<->decoder is a fixed point over 5000 random trees" {
    import random;
    rng = random.Random(0x5DEECE66D);
    for i in range(5000) {
        t = _rand_value(rng, 4);
        rt = _mp_decode(_mp_encode(t));
        assert _eq(rt, t) , f"roundtrip mismatch on tree {i}: {rt!r} != {t!r}";
    }
}


test "fuzz: float specials survive the wide codec exactly" {
    for v in [
        float("nan"),
        float("inf"),
        float("-inf"),
        -0.0,
        0.0,
        3.141592653589793
    ] {
        got = _mp_decode(_mp_encode(v));
        assert _eq(got, v) , v;
    }
    # a -0.0 keeps its sign bit through the f64 payload (not folded to +0.0)
    neg = _mp_decode(_mp_encode(-0.0));
    assert math.copysign(1.0, neg) == -1.0;
}
