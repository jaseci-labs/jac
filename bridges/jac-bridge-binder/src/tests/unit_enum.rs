//! The unit-enum value lane (`BridgeReturn::EnumName` reused for by-value enum
//! returns).
//!
//! A method returning a public FIELDLESS enum (`Date::month -> time::Month`,
//! `weekday -> time::Weekday`) crosses as its variant NAME string, exactly like a
//! fieldless-enum FIELD reader (`Comparator.op`). Codegen reuses the `EnumName`
//! arm — a `match` mapping each variant to its `&str`, `-> String` on the same
//! JacBuf lane — so no ABI/macro/loader change is needed; the binder classify
//! (one arm before the wide fallback in `classify_return`) was the only gap.
//! Pinned on real `time`.

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

/// `Date::month(&self) -> time::Month` classifies as a variant-name string return
/// carrying all twelve month names in declaration order.
#[test]
fn month_return_classifies_as_variant_name() {
    let spec = classify(&load("time-0.3.53"));
    let month = method(&spec, "Date", "month");
    match &month.ret {
        BridgeReturn::EnumName(path, variants, non_exhaustive) => {
            assert!(
                path.ends_with("Month"),
                "enum path should name Month, got {path}"
            );
            assert_eq!(
                variants.first().map(String::as_str),
                Some("January"),
                "variants must be in declaration order"
            );
            assert_eq!(variants.len(), 12, "Month has twelve variants");
            assert!(variants.contains(&"December".to_string()));
            assert!(
                !non_exhaustive,
                "time::Month is exhaustive — no wildcard arm, or -D warnings trips \
                 unreachable_patterns"
            );
        }
        other => panic!("Date::month must be an EnumName return, got {other:?}"),
    }
}

/// `Date::weekday(&self) -> time::Weekday` — the discriminant-free enum (its
/// variants carry no explicit `= N`) still crosses by NAME, so no fragile
/// positional-discriminant assumption leaks to the Jac side.
#[test]
fn weekday_return_classifies_as_variant_name() {
    let spec = classify(&load("time-0.3.53"));
    let weekday = method(&spec, "Date", "weekday");
    match &weekday.ret {
        BridgeReturn::EnumName(path, variants, _) => {
            assert!(path.ends_with("Weekday"), "got {path}");
            assert_eq!(variants.len(), 7);
            assert_eq!(variants.first().map(String::as_str), Some("Monday"));
        }
        other => panic!("Date::weekday must be an EnumName return, got {other:?}"),
    }
}

/// The emitted wrapper maps the returned enum value through a `match` to a
/// `-> String`. `time::Month` is EXHAUSTIVE, so the twelve arms are total and NO
/// `_ => "unknown"` wildcard is emitted — a wildcard there would trip
/// `unreachable_patterns` under the roundtrip crate's `-D warnings` gate.
#[test]
fn month_return_emits_variant_match_without_wildcard() {
    let spec = classify(&load("time-0.3.53"));
    let src = emit(&spec);
    assert!(
        src.contains("pub fn month(&self) -> String"),
        "month reader must emit an `-> String` signature"
    );
    assert!(
        src.contains("time::Month::January => \"January\""),
        "body must map each variant to its name string"
    );
    // The month/weekday matches are exhaustive; the only `_ => "unknown"` arm in a
    // clean `time` bridge would be an accidental wildcard on one of them.
    assert!(
        !src.contains("time::Month::December => \"December\", _ => \"unknown\""),
        "an exhaustive enum match must not carry an unreachable wildcard arm"
    );
}
