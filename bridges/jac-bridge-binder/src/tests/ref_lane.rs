//! Cross-type owned-handle returns (1.2.4).
//!
//! A method may return a fresh owned instance of ANOTHER bridged type
//! (`NaiveDateTime::date -> NaiveDate`) or an `Option` of one
//! (`NaiveDate::with_year -> Option<Self>`, `with_month -> Option<NaiveDate>`).
//! The macro already tags any bridged return `TAG_REF|idx` and both loaders
//! instantiate the wrapper at that index; the binder's job (pinned here) is to
//! CLASSIFY such returns and emit the newtype wrap. The pattern compiles against
//! real chrono (a standalone check); chrono's whole-crate roundtrip is blocked by
//! an unrelated multi-`#[jac_error]` limitation, so these are source-shape asserts.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, coverage, emit, types::BridgeReturn};

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

/// A bare cross-type return (`NaiveDateTime::date -> NaiveDate`) classifies as
/// `Ref(target)` and emits `Target(self.0.f())`.
#[test]
fn cross_type_return_is_ref() {
    let spec = classify(&load("chrono-0.4.45"));

    let date = method(&spec, "NaiveDateTime", "date");
    assert_eq!(
        date.ret,
        BridgeReturn::Ref("NaiveDate".into()),
        "NaiveDateTime::date must return a NaiveDate handle, got {:?}",
        date.ret
    );

    let src = emit(&spec);
    assert!(
        src.contains("pub fn date(&self) -> NaiveDate {"),
        "date must emit a cross-type return signature\n"
    );
    assert!(
        src.contains("NaiveDate(self.0.date())"),
        "date body must wrap the call in the NaiveDate newtype"
    );
}

/// `Option<Self>` / `Option<BridgedType>` (`NaiveDate::with_month -> Option<...>`)
/// classifies as `OptRef(target)` and emits `-> Option<Target>` + `.map(Target)`.
#[test]
fn optional_handle_return_is_optref() {
    let spec = classify(&load("chrono-0.4.45"));

    let with_month = method(&spec, "NaiveDate", "with_month");
    assert!(
        matches!(with_month.ret, BridgeReturn::OptRef(ref t) if t == "NaiveDate"),
        "NaiveDate::with_month must return Option<NaiveDate>, got {:?}",
        with_month.ret
    );

    let src = emit(&spec);
    assert!(
        src.contains("pub fn with_month(&self, month: u32) -> Option<NaiveDate> {"),
        "with_month must emit an optional-handle signature"
    );
    assert!(
        src.contains(".map(NaiveDate)"),
        "with_month body must map the present case into the NaiveDate newtype"
    );
}

/// The ref lane lifts chrono well past the pre-1.2.4 floor (date<->time<->datetime
/// navigation + all the `with_*`/`succ_opt`/`and_hms_opt` optional constructors).
#[test]
fn ref_lane_lifts_chrono_coverage() {
    let chrono = coverage(&classify(&load("chrono-0.4.45")));
    assert!(
        chrono.bridged >= 100,
        "cross-type + optional handle returns lift chrono past 100 (got {})",
        chrono.bridged
    );
}

/// A cross-type ref must never target a MONO type (its return path reads as the
/// generic origin, which would miswrap the instantiation) — those stay skips.
#[test]
fn mono_cross_type_returns_do_not_bridge_as_ref() {
    let spec = classify(&load("chrono-0.4.45"));
    for t in &spec.types {
        for f in &t.methods {
            if let BridgeReturn::Ref(name) | BridgeReturn::OptRef(name) = &f.ret {
                let target = spec.types.iter().find(|x| &x.name == name);
                assert!(
                    target.map(|x| x.mono.is_none()).unwrap_or(false),
                    "{}::{} refs {name}, which must be a real non-mono bridged type",
                    t.name,
                    f.exposed()
                );
            }
        }
    }
}
