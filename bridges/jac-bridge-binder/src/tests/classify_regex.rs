//! Acceptance test: classify regex 1.12.4's public API.
//!
//! The expected items mirror what `jac-bridge-regex-v2` exposes manually.
//! This test is the north-star for binder correctness: if it passes, the
//! classify pass understands the regex crate well enough to generate a
//! correct `#[bridge(...)]` input.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{
    classify,
    types::{BridgeReturn, Recv, ScalarType, SkipReason, TypeKind},
};

fn load_regex_doc() -> Crate {
    // The JSON is generated during `cargo +nightly rustdoc` on regex 1.12.4.
    // In CI this would be a fixture; locally we use the cargo registry copy.
    let candidates = [
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/regex-1.12.4.json"),
        PathBuf::from(env!("HOME"))
            .join(".cargo/registry/src/index.crates.io-1949cf8c6b5b557f/regex-1.12.4/target/doc/regex.json"),
    ];
    for p in &candidates {
        if p.exists() {
            let data = std::fs::read_to_string(p).expect("read rustdoc json");
            return serde_json::from_str(&data).expect("parse rustdoc json");
        }
    }
    panic!("regex rustdoc JSON not found — run: cargo +nightly rustdoc -Z unstable-options --output-format json --manifest-path ~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/regex-1.12.4/Cargo.toml");
}

#[test]
fn module_name_and_version() {
    let doc = load_regex_doc();
    let spec = classify(&doc);
    assert_eq!(spec.module_name, "regex");
    assert_eq!(spec.crate_version, "1.12.4");
}

#[test]
fn regex_is_opaque_with_ctor_and_is_match() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    let regex_type = spec.types.iter().find(|t| t.name == "Regex").expect("Regex type");
    assert_eq!(regex_type.kind, TypeKind::Opaque);

    // Constructor: new(&str) -> Result<Regex, Error>
    let ctor = regex_type.ctor.as_ref().expect("Regex::new ctor");
    assert_eq!(ctor.name, "new");
    assert_eq!(ctor.params.len(), 1);
    assert_eq!(ctor.params[0].ty, ScalarType::Str);
    assert_eq!(ctor.ret, BridgeReturn::OwnSelfResult);

    // Method: is_match(&self, &str) -> bool
    let is_match = regex_type.methods.iter().find(|m| m.name == "is_match").expect("is_match");
    assert_eq!(is_match.params.len(), 1);
    assert_eq!(is_match.params[0].ty, ScalarType::Str);
    assert_eq!(is_match.ret, BridgeReturn::Bool);
}

#[test]
fn error_type_classified() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    let err_type = spec.types.iter().find(|t| t.name == "Error").expect("Error type");
    assert_eq!(err_type.kind, TypeKind::Error);
}

#[test]
fn no_duplicate_types() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    let mut names: Vec<&str> = spec.types.iter().map(|t| t.name.as_str()).collect();
    names.sort_unstable();
    let deduped: Vec<&str> = {
        let mut d = names.clone();
        d.dedup();
        d
    };
    assert_eq!(names, deduped, "duplicate types in classify output");
}

#[test]
fn cursor_and_unreadable_borrows_are_skipped() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    // Regex::captures_iter returns CaptureMatches<'r,'h> — cursor, must be skipped.
    let iter_skip = spec.skips.iter().find(|s| s.item == "Regex::captures_iter");
    assert!(iter_skip.is_some(), "Regex::captures_iter should be a skip");

    // Regex::captures returns Option<Captures<'h>>, but Captures has no int-free
    // reader (get/name return Option<Match>, len is usize), so the owning-wrapper
    // rule declines it and it stays a precise lifetime-borrow skip.
    let cap_skip = spec.skips.iter().find(|s| s.item == "Regex::captures");
    assert!(cap_skip.is_some(), "Regex::captures should stay a skip (no reader)");
    assert_eq!(cap_skip.unwrap().reason, SkipReason::LifetimeBorrow);
    // And no OwnedCaptures wrapper should have been synthesized.
    assert!(
        spec.types.iter().all(|t| t.name != "OwnedCaptures"),
        "OwnedCaptures must not be synthesized — Captures has no reader"
    );
}

#[test]
fn find_is_rescued_by_owning_wrapper() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    // Regex::find (returns Option<Match<'h>>) is no longer a skip — it becomes a
    // producer method whose return is the synthesized OwnedMatch wrapper.
    assert!(
        spec.skips.iter().all(|s| s.item != "Regex::find"),
        "Regex::find should be rescued, not skipped"
    );
    let regex_type = spec.types.iter().find(|t| t.name == "Regex").expect("Regex type");
    let find = regex_type.methods.iter().find(|m| m.name == "find").expect("find producer");
    assert_eq!(find.ret, BridgeReturn::OptWrapper("OwnedMatch".into()));
    assert_eq!(find.params.len(), 1);
    assert_eq!(find.params[0].ty, ScalarType::Str);

    // The OwnedMatch wrapper exists, is opaque, and carries the ouroboros metadata.
    let owned = spec.types.iter().find(|t| t.name == "OwnedMatch").expect("OwnedMatch type");
    assert_eq!(owned.kind, TypeKind::Opaque);
    let w = owned.wrapper.as_ref().expect("wrapper metadata");
    assert_eq!(w.borrowed_path, "regex::Match");
    assert_eq!(w.lifetimes, 1);
    assert_eq!(w.owner_inner_path, "regex::Regex");
    assert_eq!(w.producer_call, "find");

    // Its readers are Match's int-free methods, delegating through self.inner.
    let mut reader_names: Vec<&str> = owned.methods.iter().map(|m| m.name.as_str()).collect();
    reader_names.sort_unstable();
    assert_eq!(reader_names, vec!["as_str", "is_empty"]);
    assert!(owned.methods.iter().all(|m| m.recv == Recv::Inner));
    let as_str = owned.methods.iter().find(|m| m.name == "as_str").unwrap();
    assert_eq!(as_str.ret, BridgeReturn::Str); // &'h str, copied to owned String
    let is_empty = owned.methods.iter().find(|m| m.name == "is_empty").unwrap();
    assert_eq!(is_empty.ret, BridgeReturn::Bool);

    // Match's integer-returning methods are honestly recorded as skips.
    for m in ["Match::start", "Match::end", "Match::len", "Match::range"] {
        assert!(spec.skips.iter().any(|s| s.item == m), "{m} should be a recorded skip");
    }
}

#[test]
fn closure_methods_are_skipped() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    // replace_all(&self, &'h str, impl Replacer) -> Cow<'h, str>
    // The named lifetime on the &str param triggers LifetimeBorrow before
    // we even reach the impl Replacer parameter.
    let skip = spec.skips.iter().find(|s| s.item == "Regex::replace_all");
    assert!(skip.is_some(), "Regex::replace_all should be a skip");
    assert!(
        matches!(skip.unwrap().reason, SkipReason::LifetimeBorrow | SkipReason::Closure | SkipReason::Generic),
        "replace_all should be skipped for lifetime, closure, or generic reason"
    );
}

#[test]
fn types_are_ordered_opaque_then_error() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    let mut saw_error = false;
    for t in &spec.types {
        if t.kind == TypeKind::Error {
            saw_error = true;
        }
        if saw_error {
            assert_eq!(t.kind, TypeKind::Error, "opaque type after error type");
        }
    }
}
