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
    types::{BridgeReturn, ScalarType, SkipReason, TypeKind},
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
fn lifetime_borrow_methods_are_skipped() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    // Regex::find returns Option<Match<'h>> — lifetime borrow, must be skipped.
    let find_skip = spec.skips.iter().find(|s| s.item == "Regex::find");
    assert!(find_skip.is_some(), "Regex::find should be a skip");
    assert_eq!(find_skip.unwrap().reason, SkipReason::LifetimeBorrow);

    // Regex::captures_iter returns CaptureMatches<'r,'h> — cursor, must be skipped.
    let iter_skip = spec.skips.iter().find(|s| s.item == "Regex::captures_iter");
    assert!(iter_skip.is_some(), "Regex::captures_iter should be a skip");
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
