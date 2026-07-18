# wide-lane fuzz corpus generator

Regenerates `../wide_fuzz_corpus.jsonl`, the differential corpus for
`test_rust_wide_fuzz.jac` (FFI-LANES-PLAN 2.7). Each line is one random
MessagePack value tree as `{"tree": <json>, "msgpack": "<rmp_serde hex>"}`,
where `msgpack` is `rmp_serde::to_vec_named` of that exact value. The Jac test
asserts its own decoder reproduces `tree` from `msgpack` (differential vs real
rmp_serde) and that its encoder/decoder round-trip is a fixed point.

Deterministic (a hand-rolled LCG seed, no `rand`/`Date::now`), so the corpus is
reproducible byte-for-byte. Run offline:

    cargo run --release -q -- 800 > ../wide_fuzz_corpus.jsonl

Args: `[count] [seed]` (defaults: 800, 0x9E3779B97F4A7C15). JSON cannot carry
NaN/+-Inf, so float specials are fuzzed separately in the test's pure-Python
round-trip half, not here.
