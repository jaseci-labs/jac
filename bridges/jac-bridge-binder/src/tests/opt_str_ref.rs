//! Borrowed nullable-string returns (`BridgeReturn::OptStrRef`).
//!
//! A `-> Option<&str>` method (`url::Url::host_str`) borrows from `&self`; the
//! wrapper owns the borrow with `.map(|s| s.to_string())` and rides the same
//! `TAG_OPT_BIT | TAG_STR` lane as `Option<String>`. Pinned on real `url`.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::types::BridgeReturn;
use crate::{classify, emit};

fn load(fixture: &str) -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join(format!("tests/fixtures/{fixture}.json"));
    let data = std::fs::read_to_string(&p).unwrap_or_else(|_| panic!("read {fixture}"));
    serde_json::from_str(&data).unwrap_or_else(|e| panic!("parse {fixture}: {e}"))
}

fn method<'a>(spec: &'a crate::types::BridgeSpec, ty: &str, m: &str) -> &'a crate::types::BridgeFn {
    spec.types
        .iter()
        .find(|t| t.name == ty)
        .unwrap_or_else(|| panic!("{ty} not bridged"))
        .methods
        .iter()
        .find(|f| f.exposed() == m)
        .unwrap_or_else(|| panic!("{ty}::{m} not bridged"))
}

#[test]
fn borrowed_option_str_classifies_and_owns() {
    let spec = classify(&load("url-2.5.8"));

    for m in ["host_str", "domain", "fragment", "password", "query"] {
        assert_eq!(
            method(&spec, "Url", m).ret,
            BridgeReturn::OptStrRef,
            "Url::{m} must classify as OptStrRef"
        );
    }

    let src = emit(&spec);
    // Owns the borrow before returning, on an `-> Option<String>` signature.
    assert!(
        src.contains("pub fn host_str(&self) -> Option<String>"),
        "host_str must emit `-> Option<String>`"
    );
    assert!(
        src.contains("self.0.host_str().map(|s| s.to_string())"),
        "host_str body must own the borrowed &str with .map(|s| s.to_string())"
    );
}
