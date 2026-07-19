//! By-value handle params (`ScalarType::HandleValue`).
//!
//! A method whose inner takes an OWNED bridged handle
//! (`Date::checked_add(self, rhs: Duration) -> Option<Date>`) bridges: the ABI is
//! identical to the by-value-ref `&Version` handle lane (the caller passes the
//! other object's handle, the macro reconstructs `&Target`), but the wrapper hands
//! the inner call an owned value via `{name}.0.clone()`. Sound because the target
//! is `Clone` (every `Copy` datetime/duration type qualifies). Pinned on real
//! `time`; the whole-crate roundtrip is blocked by an unrelated multi-`#[jac_error]`
//! limitation, so these are classify + source-shape asserts.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, emit, types::ScalarType};

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

/// `Date::checked_add(self, rhs: Duration)` classifies its `Duration` param as a
/// by-value handle to the bridged `Duration` newtype.
#[test]
fn by_value_handle_param_classifies() {
    let spec = classify(&load("time-0.3.53"));

    let checked_add = method(&spec, "Date", "checked_add");
    let p = checked_add
        .params
        .iter()
        .find(|p| matches!(p.ty, ScalarType::HandleValue(_)))
        .expect("Date::checked_add must carry a by-value handle param");
    assert!(
        matches!(&p.ty, ScalarType::HandleValue(t) if t == "Duration"),
        "the by-value handle param must target the Duration newtype, got {:?}",
        p.ty
    );
}

/// The wrapper re-declares the param as `&Duration` (matching what the macro
/// reconstructs) and clones an owned value out for the inner call.
#[test]
fn by_value_handle_param_emits_clone() {
    let spec = classify(&load("time-0.3.53"));
    let src = emit(&spec);

    // Signature takes the newtype by reference (the shim hands us `&Target`)…
    assert!(
        src.contains("pub fn checked_add(&self, duration: &Duration) -> Option<Date>"),
        "by-value handle param must re-declare as &Duration\n"
    );
    // …and the inner call clones an owned Duration out of the shared handle
    // (`checked_add` consumes `self`, so the receiver is `self.0.clone()`).
    assert!(
        src.contains("self.0.clone().checked_add(duration.0.clone()).map(Date)"),
        "by-value handle param must pass an owned {{name}}.0.clone() to the inner call"
    );
}
