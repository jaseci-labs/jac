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
//! These tests pin the shapes named in the plan: `new() -> D` must become the
//! `-> Self` constructor, and — since 1.2.2 landed the byte lane —
//! `finalize(self) -> Array<u8, OutputSize<D>>` must bridge as a consuming-`self`
//! bytes method (`self.0.clone().finalize().to_vec()`), proving the `D` buried in
//! `OutputSize<D>` is read as a byte digest, not mis-substituted into a phantom
//! Self return.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, emit, types::{BridgeReturn, ScalarType}};

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
        // sha2 (defined in `digest`) but sha2 re-exports it at its ROOT (`pub use
        // digest::Digest;`), so the shortest valid use-path is `sha2::Digest` — the
        // re-export-path lookup prefers it over the deeper `sha2::digest::Digest`.
        assert_eq!(
            ctor.via_trait.as_deref(),
            Some("sha2::Digest"),
            "{name}::new must carry its `via_trait` so `use sha2::Digest;` is emitted"
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

/// `finalize(self) -> Array<u8, OutputSize<D>>` bridges (1.2.2): a consuming-`self`
/// method returning a byte digest. The `D` buried in `OutputSize<D>` is read as a
/// byte return, and the by-value `self` is cloned out of the shared handle.
#[test]
fn finalize_bridges_as_consuming_bytes() {
    let spec = classify(&load("sha2-0.11.0"));

    for ty in &spec.types {
        if !HASHERS.contains(&ty.name.as_str()) {
            continue;
        }
        let finalize = ty
            .methods
            .iter()
            .find(|m| m.exposed() == "finalize")
            .unwrap_or_else(|| panic!("{}::finalize must bridge under 1.2.2", ty.name));
        assert!(
            matches!(finalize.ret, BridgeReturn::Bytes),
            "{}::finalize must return bytes, got {:?}",
            ty.name,
            finalize.ret
        );
        assert!(
            finalize.consumes_self && !finalize.self_mut,
            "{}::finalize consumes self by value (clone-out lowering)",
            ty.name
        );
    }

    // The old 1.1.2 "consumes self by value" skip is gone. A `Sha256::finalize`
    // skip DOES remain — but for the unrelated `DynDigest::finalize(self: Box<D>)
    // -> Box<[u8]>` variant (reason "Box"), deduped behind the bridged
    // `Digest::finalize`; never for consuming self.
    let bad = spec
        .skips
        .iter()
        .filter(|s| s.item == "Sha256::finalize")
        .find(|s| format!("{:?}", s.reason).contains("consumes self"));
    assert!(
        bad.is_none(),
        "Sha256::finalize must not be skipped for consuming self under 1.2.2: {bad:?}"
    );
}

/// The sha2 acceptance surface (1.2.2): `update(&mut self, impl AsRef<[u8]>)`
/// bridges as a `&mut self` method taking a `&[u8]` bytes param and returning void.
#[test]
fn update_bridges_as_mut_self_bytes_sink() {
    let spec = classify(&load("sha2-0.11.0"));

    for ty in &spec.types {
        if !HASHERS.contains(&ty.name.as_str()) {
            continue;
        }
        let update = ty
            .methods
            .iter()
            .find(|m| m.exposed() == "update")
            .unwrap_or_else(|| panic!("{}::update must bridge under 1.2.2", ty.name));
        assert!(
            update.self_mut && !update.consumes_self,
            "{}::update is a &mut self method",
            ty.name
        );
        assert!(
            matches!(update.ret, BridgeReturn::Void),
            "{}::update returns void, got {:?}",
            ty.name,
            update.ret
        );
        assert!(
            update.params.iter().any(|p| p.ty == ScalarType::Bytes),
            "{}::update must take a bytes param",
            ty.name
        );
    }
}

/// End-to-end through codegen: the emitted module has the trait `use` and a real
/// `pub fn new() -> Self` body for `Sha256`.
#[test]
fn emitted_source_has_new_and_trait_use() {
    let spec = classify(&load("sha2-0.11.0"));
    let src = emit(&spec);

    assert!(
        src.contains("use sha2::Digest;"),
        "generated module must bring Digest into scope via sha2's digest re-export:\n{src}"
    );
    assert!(
        src.contains("Self(sha2::Sha256::new())"),
        "Sha256 constructor body missing:\n{src}"
    );
    // 1.2.2 byte lane: `update` is `&mut self` with a `&[u8]` sink; `finalize`
    // clones the value out of the shared handle and returns owned `Vec<u8>`.
    assert!(
        src.contains("pub fn update(&mut self, data: &[u8])"),
        "Sha256::update must emit a &mut self / &[u8] signature:\n{src}"
    );
    // Flattened off `Digest`, so the call is UFCS (disambiguating `Digest` from the
    // also-in-scope `DynDigest`): the consuming receiver is cloned out by value.
    assert!(
        src.contains("Digest::finalize(self.0.clone()).to_vec()"),
        "Sha256::finalize must clone out of the handle and return Vec<u8>:\n{src}"
    );
    assert!(
        src.contains("Digest::update(&mut self.0, data)"),
        "Sha256::update must call through UFCS with a &mut receiver:\n{src}"
    );
}
