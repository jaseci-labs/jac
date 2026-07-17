//! Deterministic corpus generator for the wide-lane fuzz differential (2.7).
//!
//! Emits `COUNT` random MessagePack value trees over the exact domain the Jac
//! codecs support (null / bool / i64 / u64 / f64 / utf-8 str / array / str-keyed
//! map), each as one JSONL record:
//!
//!   {"tree": <the value as JSON>, "msgpack": "<rmp_serde hex>"}
//!
//! `tree` is the canonical value; `msgpack` is `rmp_serde::to_vec_named` of that
//! exact `serde_json::Value`, so the Jac side can assert its own decoder matches
//! real rmp_serde. A hand-rolled LCG PRNG keeps this reproducible with no `rand`
//! dep and no `Date::now`. Run offline; check the output in as a fixture.
//!
//! NOTE: JSON cannot carry NaN / +-Inf, so float specials are NOT in this corpus
//! -- they are fuzzed separately in the pure-Python round-trip half of the test.

use serde_json::{json, Map, Value};

struct Lcg(u64);
impl Lcg {
    fn next(&mut self) -> u64 {
        // Numerical Recipes LCG constants.
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.0
    }
    fn below(&mut self, n: u64) -> u64 {
        self.next() % n
    }
    fn f64(&mut self) -> f64 {
        // A finite double from 53 random bits scaled into a wide-ish range.
        let bits = self.next() >> 11; // 53 bits
        let unit = bits as f64 / (1u64 << 53) as f64; // [0,1)
        (unit - 0.5) * 2.0e6
    }
}

fn rand_string(rng: &mut Lcg) -> String {
    // Pull from a set that includes ASCII, multi-byte utf-8, and an embedded NUL,
    // so the codec's length-delimited (not C-string) handling is exercised.
    const ALPHABET: &[&str] = &[
        "a", "Z", "0", " ", "_", "\u{03c0}", "\u{00e9}", "\u{1f600}", "\0", "\n", "\"", "\\",
    ];
    let len = rng.below(6) as usize; // 0..=5 chars, includes empty string
    let mut s = String::new();
    for _ in 0..len {
        s.push_str(ALPHABET[rng.below(ALPHABET.len() as u64) as usize]);
    }
    s
}

fn rand_value(rng: &mut Lcg, depth: u32) -> Value {
    // At max depth, only leaves.
    let choice = if depth == 0 { rng.below(6) } else { rng.below(8) };
    match choice {
        0 => Value::Null,
        1 => Value::Bool(rng.below(2) == 1),
        2 => {
            // signed i64 across the full range including negatives
            let v = rng.next() as i64;
            json!(v)
        }
        3 => {
            // unsigned u64, biased to include high-bit-set values (> i64::MAX)
            let v = rng.next();
            json!(v)
        }
        4 => json!(rng.f64()),
        5 => Value::String(rand_string(rng)),
        6 => {
            let n = rng.below(6) as usize; // 0..=5 elements
            let items: Vec<Value> = (0..n).map(|_| rand_value(rng, depth - 1)).collect();
            Value::Array(items)
        }
        _ => {
            let n = rng.below(6) as usize;
            let mut m = Map::new();
            for _ in 0..n {
                // Keys must be unique str; derive a short deterministic key.
                let k = rand_string(rng);
                m.insert(k, rand_value(rng, depth - 1));
            }
            Value::Object(m)
        }
    }
}

fn main() {
    let count: usize = std::env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(800);
    let seed: u64 = std::env::args().nth(2).and_then(|s| s.parse().ok()).unwrap_or(0x9E3779B97F4A7C15);
    let mut rng = Lcg(seed);
    for _ in 0..count {
        let tree = rand_value(&mut rng, 4);
        let bytes = rmp_serde::to_vec_named(&tree).expect("rmp encode");
        // Self-check: rmp round-trips its own output back to the same value.
        let back: Value = rmp_serde::from_slice(&bytes).expect("rmp decode");
        assert_eq!(back, tree, "rmp self-roundtrip mismatch");
        let hex: String = bytes.iter().map(|b| format!("{b:02x}")).collect();
        let rec = json!({ "tree": tree, "msgpack": hex });
        println!("{}", serde_json::to_string(&rec).unwrap());
    }
}
