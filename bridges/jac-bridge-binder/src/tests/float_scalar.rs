//! Float scalar params and returns (`ScalarType::Float` / `BridgeReturn::Float`).
//!
//! An `f32`/`f64` param or return crosses as an IEEE-754 bit pattern in a u64 slot
//! (`TAG_F64`) — a lane the macro and loader synth already supported end-to-end;
//! the binder classify was the only gap. Pinned on real `rust_decimal`.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::types::{BridgeReturn, ScalarType};
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

/// `Decimal::as_f64(&self) -> f64` classifies as a float return.
#[test]
fn float_return_classifies() {
    let spec = classify(&load("rust_decimal-1.42.1"));
    let as_f64 = method(&spec, "Decimal", "as_f64");
    assert_eq!(
        as_f64.ret,
        BridgeReturn::Float("f64".into()),
        "Decimal::as_f64 must return a float, got {:?}",
        as_f64.ret
    );
    assert!(
        emit(&spec).contains("pub fn as_f64(&self) -> f64"),
        "float return must emit an `-> f64` signature"
    );
}

/// `Decimal::from_f64(f64) -> Option<Decimal>` classifies its param as a float.
#[test]
fn float_param_classifies() {
    let spec = classify(&load("rust_decimal-1.42.1"));
    // `from_f64` is a static (no `self`), so it lives in `methods` stamped
    // `is_static` — same list `method()` searches.
    let from_f64 = method(&spec, "Decimal", "from_f64");
    assert!(
        from_f64
            .params
            .iter()
            .any(|p| matches!(&p.ty, ScalarType::Float(t) if t == "f64")),
        "Decimal::from_f64 must carry an f64 param, got {:?}",
        from_f64.params
    );
}
