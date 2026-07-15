//! Blanket-generic self-alias substitution (Track A, 1.1.2).
//!
//! sha2's hashers get their public constructor from a blanket
//! `impl<D: …> Digest for D`, which rustdoc materializes onto each concrete type
//! (`Sha256`, `Sha512`, …). Inside that impl the method SIGNATURES keep the
//! blanket's generic param `D` where `Self` is meant — `Digest::new() -> D`,
//! `finalize(self) -> Array<u8, OutputSize<D>>`. Without treating `D` as a
//! self-alias the classifier reads `-> D` as an unbridgeable free generic and the
//! hasher ends up with NO constructor at all.
//!
//! These tests pin the two shapes named in the plan: `new() -> D` must become the
//! `-> Self` constructor, and `finalize(self) -> Array<u8, OutputSize<D>>` must
//! stay an honest bytes-lane skip (proving the `D` inside `OutputSize<D>` is not
//! mis-substituted into a phantom Self return that would emit an unsound
//! `self.0.finalize()` off a shared handle).

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, emit, types::BridgeReturn};

fn load(fixture: &str) -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join(format!("tests/fixtures/{fixture}.json"));
    let data = std::fs::read_to_string(&p).unwrap_or_else(|_| panic!("read {fixture}"));
    serde_json::from_str(&data).unwrap_or_else(|e| panic!("parse {fixture}: {e}"))
}

const HASHERS: [&str; 6] = [
    "Sha224", "Sha256", "Sha384", "Sha512", "Sha512_224", "Sha512_256",
];

/// `Digest::new() -> D` is recognised as a `-> Self` constructor on every hasher.
#[test]
fn blanket_new_becomes_self_constructor() {
    let spec = classify(&load("sha2-0.11.0"));

    for name in HASHERS {
        let ty = spec
            .types
            .iter()
            .find(|t| t.name == name)
            .unwrap_or_else(|| panic!("{name} type missing from spec"));
        let ctor = ty.ctor.as_ref().unwrap_or_else(|| {
            panic!("{name} has no constructor — blanket self-alias `D` not substituted")
        });
        assert_eq!(ctor.name, "new", "{name} constructor should be `new`");
        assert!(
            matches!(ctor.ret, BridgeReturn::OwnSelf),
            "{name}::new must classify as a `-> Self` owner return, got {:?}",
            ctor.ret
        );
        // The ctor was flattened off the Digest blanket, so codegen must bring the
        // trait into scope for the `sha2::{name}::new()` call. Digest is EXTERNAL to
        // sha2 (defined in `digest`), so its use-path routes through sha2's
        // re-export of that crate: `sha2::digest::Digest`.
        assert_eq!(
            ctor.via_trait.as_deref(),
            Some("sha2::digest::Digest"),
            "{name}::new must carry its `via_trait` so `use sha2::digest::Digest;` is emitted"
        );
    }

    // Regression guard: a hasher `new` must NOT also appear as a skip (before 1.1.2
    // it was recorded as `Sha256::new (generic)`). The `*VarCore::new` items stay
    // skipped for an unrelated reason (a `Result<(Self, …)>` tuple return), so scope
    // the guard to the six public hashers.
    let new_skips: Vec<&str> = spec
        .skips
        .iter()
        .filter(|s| HASHERS.iter().any(|h| s.item == format!("{h}::new")))
        .map(|s| s.item.as_str())
        .collect();
    assert!(
        new_skips.is_empty(),
        "no hasher `new` should be skipped once `D` is a self-alias: {new_skips:?}"
    );
}

/// `finalize(self) -> Array<u8, OutputSize<D>>` must stay a recorded skip — the
/// consuming `self` + digest-output bytes return belong to later lanes (1.1.5 /
/// 1.2.2). The `D` buried in `OutputSize<D>` must NOT be mis-read as a Self return.
#[test]
fn finalize_stays_an_honest_skip() {
    let spec = classify(&load("sha2-0.11.0"));

    // Never emitted as a method on any hasher (an emitted `self.0.finalize()` would
    // move out of a shared borrow and fail to compile).
    for ty in &spec.types {
        assert!(
            !ty.methods.iter().any(|m| m.exposed() == "finalize"),
            "{}::finalize must not be emitted (consuming self / bytes lane)",
            ty.name
        );
        assert!(
            ty.ctor.as_ref().map(|c| c.name.as_str()) != Some("finalize"),
            "{}::finalize must not be mistaken for a constructor",
            ty.name
        );
    }

    // Recorded as a visible skip, not silently dropped.
    assert!(
        spec.skips.iter().any(|s| s.item == "Sha256::finalize"),
        "Sha256::finalize should be a recorded skip"
    );
}

/// End-to-end through codegen: the emitted module has the trait `use` and a real
/// `pub fn new() -> Self` body for `Sha256`.
#[test]
fn emitted_source_has_new_and_trait_use() {
    let spec = classify(&load("sha2-0.11.0"));
    let src = emit(&spec);

    assert!(
        src.contains("use sha2::digest::Digest;"),
        "generated module must bring Digest into scope via sha2's digest re-export:\n{src}"
    );
    assert!(
        src.contains("Self(sha2::Sha256::new())"),
        "Sha256 constructor body missing:\n{src}"
    );
}
