//! FN_STATIC lane (1.3): no-receiver associated fns admitted as statics.
//!
//! Before this lane, a no-receiver fn that wasn't THE constructor was a skip
//! ("associated fn (no receiver, not a constructor)" for a non-`Self` static like
//! `Sha256::digest`; "additional constructor" for an extra `-> Self` factory like
//! `Uuid::parse_str`). 1.3 admits both as STATICS: `is_static` methods that
//! codegen emits with NO `&self` receiver, calling through the associated form
//! `Type::fn(args)`, and stamps `#[jac(assoc)]` so the macro tags them FN_STATIC
//! (no handle in, dispatched by name). The na loader gates them; CPython exposes
//! them as static methods (proven end-to-end by the scalar loader suite).

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::types::{BridgeReturn, BridgeType};
use crate::{classify, emit};

fn load(name: &str) -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(format!("{name}.json"));
    let data = std::fs::read_to_string(&p).unwrap_or_else(|_| panic!("read {name} fixture"));
    serde_json::from_str(&data).unwrap_or_else(|_| panic!("parse {name} fixture"))
}

fn ty<'a>(spec: &'a crate::types::BridgeSpec, name: &str) -> &'a BridgeType {
    spec.types
        .iter()
        .find(|t| t.name == name)
        .unwrap_or_else(|| panic!("type {name}"))
}

fn static_fn<'a>(bt: &'a BridgeType, name: &str) -> &'a crate::types::BridgeFn {
    let f = bt
        .methods
        .iter()
        .find(|m| m.name == name)
        .unwrap_or_else(|| panic!("{}::{name} must be a bridged static", bt.name));
    assert!(f.is_static, "{}::{name} must be marked is_static", bt.name);
    f
}

/// sha2's one-shot `Sha256::digest(data) -> Output` — a non-`Self` associated fn
/// — is admitted as a static returning bytes (the gap that blocked na sha2).
#[test]
fn non_self_associated_fn_is_a_bytes_static() {
    let spec = classify(&load("sha2-0.11.0"));
    let sha = ty(&spec, "Sha256");
    let digest = static_fn(sha, "digest");
    assert_eq!(digest.ret, BridgeReturn::Bytes, "digest returns bytes");
    // `output_size() -> usize` is likewise a static (a scalar one).
    let osize = static_fn(sha, "output_size");
    assert!(
        matches!(osize.ret, BridgeReturn::Uint(_)),
        "output_size returns a uint, got {:?}",
        osize.ret
    );
}

/// An extra `-> Self` factory the ctor slot couldn't hold becomes a static, not a
/// skip: `Uuid::parse_str`/`try_parse` (all fallible `-> Result<Self, _>` here —
/// uuid's infallible `nil`/`max` are separately dropped as const-generic).
#[test]
fn extra_self_factories_are_statics() {
    let spec = classify(&load("uuid-1.23.4"));
    let uuid = ty(&spec, "Uuid");
    for name in ["parse_str", "try_parse", "from_slice_le"] {
        assert_eq!(
            static_fn(uuid, name).ret,
            BridgeReturn::OwnSelfResult,
            "{name} is a fallible -> Self static"
        );
    }
    // THE ctor slot still holds exactly one winner, distinct from the statics.
    let ctor = uuid.ctor.as_ref().expect("uuid keeps a ctor");
    assert!(!ctor.is_static, "the ctor winner is not a static");
    assert!(
        uuid.methods.iter().filter(|m| m.is_static).count() >= 3,
        "uuid must expose several -> Self static factories"
    );
}

/// Codegen emits a static with NO `&self`, the associated call form, and the
/// `#[jac(assoc)]` marker; a non-`Self` bytes static rides the proven Bytes arm.
#[test]
fn static_emits_assoc_form_and_marker() {
    let spec = classify(&load("sha2-0.11.0"));
    let src = emit(&spec);
    let block = &src[src.find("impl Sha256 {").expect("impl Sha256 block")..];

    // digest: assoc marker, no receiver, `<Inner as Trait>::digest` (flattened off
    // Digest), Bytes arm's `.to_vec()`.
    assert!(
        block.contains("#[jac(assoc)]\n        pub fn digest(data: &[u8]) -> Vec<u8> {"),
        "digest must emit an assoc, no-receiver, Vec<u8> signature\n{block}"
    );
    assert!(
        block.contains("<sha2::Sha256 as Digest>::digest(data).to_vec()"),
        "digest body must use the trait-qualified associated call + .to_vec()\n{block}"
    );
    // No static accidentally grew a `&self`.
    assert!(
        !block.contains("pub fn digest(&self"),
        "a static must not take a receiver\n{block}"
    );
}

/// A fallible `-> Self` static maps the associated call through `Result` into the
/// newtype and carries the assoc marker (uuid `parse_str`).
#[test]
fn self_factory_static_wraps_newtype() {
    let spec = classify(&load("uuid-1.23.4"));
    let src = emit(&spec);
    let block = &src[src.find("impl Uuid {").expect("impl Uuid block")..];
    assert!(
        block.contains(
            "#[jac(assoc)]\n        pub fn parse_str(input: &str) -> Result<Self, String> {"
        ),
        "parse_str must be an assoc, no-receiver, fallible -> Self static\n{block}"
    );
    assert!(
        block.contains("uuid::Uuid::parse_str(input).map(Self).map_err(|e| e.to_string())"),
        "parse_str body must map the associated call into Self via Result\n{block}"
    );
}

/// A static flattened off a std/core trait (`Regex::from_str` via `FromStr`) is
/// NOT admitted: `trait_use_path` can't form a compiling `use` for a std trait,
/// so it stays a skip-with-reason rather than an unresolved-import in the crate.
#[test]
fn std_trait_static_is_skipped_not_emitted() {
    let spec = classify(&load("regex-1.12.4"));
    let regex = ty(&spec, "Regex");
    assert!(
        !regex.methods.iter().any(|m| m.name == "from_str"),
        "from_str (via std FromStr) must not be emitted as a static"
    );
    assert!(
        spec.skips.iter().any(|s| {
            s.item == "Regex::from_str"
                && format!("{:?}", s.reason).contains("std/core trait")
        }),
        "Regex::from_str must be a skip-with-reason naming the std-trait hazard"
    );
    // And the generated source never references a bogus std-trait `use`.
    let src = emit(&spec);
    assert!(
        !src.contains("use regex::core::"),
        "no unresolved std-trait use must be emitted\n{src}"
    );
}
