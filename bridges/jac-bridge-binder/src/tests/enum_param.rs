//! The unit-enum PARAM lane (`ScalarType::Enum` — the inbound mirror of the
//! `BridgeReturn::EnumName` value return).
//!
//! A by-value public FIELDLESS enum param (`Date::from_calendar_date(month:
//! Month)`, `Date::next_occurrence(weekday: Weekday)`) crosses as its variant NAME
//! string on the same `&str`/`TAG_STR` lane as an ordinary string param; the
//! wrapper decodes it back to the enum via a `match`. An unknown name has no valid
//! enum value, so the decode does an early `return Err(..)` — which forces the
//! method into a `Result<_, String>`: an already-fallible method just gains the
//! decode preamble, an infallible one is lifted to `Result` with its value wrapped
//! in `Ok(..)`. Pinned on real `time`.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::types::ScalarType;
use crate::{classify, emit};

fn load(fixture: &str) -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join(format!("tests/fixtures/{fixture}.json"));
    let data = std::fs::read_to_string(&p).unwrap_or_else(|_| panic!("read {fixture}"));
    serde_json::from_str(&data).unwrap_or_else(|e| panic!("parse {fixture}: {e}"))
}

fn method<'a>(spec: &'a crate::types::BridgeSpec, ty: &str, m: &str) -> &'a crate::types::BridgeFn {
    let bt = spec
        .types
        .iter()
        .find(|t| t.name == ty)
        .unwrap_or_else(|| panic!("{ty} not bridged"));
    bt.ctor
        .iter()
        .chain(bt.methods.iter())
        .find(|f| f.exposed() == m)
        .unwrap_or_else(|| panic!("{ty}::{m} not bridged"))
}

/// `Date::next_occurrence(&self, weekday: Weekday) -> Date` classifies the enum
/// param as a variant-name string carrying all seven weekday names.
#[test]
fn weekday_param_classifies_as_enum() {
    let spec = classify(&load("time-0.3.53"));
    let f = method(&spec, "Date", "next_occurrence");
    let p = f
        .params
        .iter()
        .find(|p| p.name == "weekday")
        .expect("weekday param");
    match &p.ty {
        ScalarType::Enum(path, variants) => {
            assert!(path.ends_with("Weekday"), "got {path}");
            assert_eq!(variants.len(), 7);
            assert!(variants.contains(&"Monday".to_string()));
        }
        other => panic!("weekday must be an Enum param, got {other:?}"),
    }
}

/// An INFALLIBLE source method (`next_occurrence -> Date`) is lifted to
/// `Result<Date, String>`: the wrapper takes `weekday: &str`, decodes it with an
/// error-yielding wildcard, and wraps the produced value in `Ok(..)`.
#[test]
fn infallible_enum_param_method_is_lifted_to_result() {
    let spec = classify(&load("time-0.3.53"));
    let src = emit(&spec);
    // `-> Self` source, so the lifted return is `Result<Self, String>`; the method
    // consumes `self` by value, so the inner call goes through `self.0.clone()`.
    assert!(
        src.contains("pub fn next_occurrence(&self, weekday: &str) -> Result<Self, String>"),
        "next_occurrence must take `&str` and be lifted to Result\n\
         (searched generated `time` bridge source)"
    );
    assert!(
        src.contains(r#"let weekday = match weekday { "Monday" => time::Weekday::Monday,"#),
        "the enum param must be decoded from its variant name"
    );
    assert!(
        src.contains(r#"_ => return Err(format!("unknown Weekday variant: {weekday}")),"#),
        "an unknown name must early-return an Err"
    );
    assert!(
        src.contains("Ok(Self(self.0.clone().next_occurrence(weekday)))"),
        "the infallible value must be wrapped in Ok(..)"
    );
}

/// An ALREADY-fallible source method (`from_calendar_date -> Result<Date, _>`)
/// keeps its `Result` return and just GAINS the decode preamble ahead of the
/// existing `.map(..).map_err(..)` chain — the value is NOT double-wrapped in Ok.
#[test]
fn already_fallible_enum_param_method_only_gains_preamble() {
    let spec = classify(&load("time-0.3.53"));
    let f = method(&spec, "Date", "from_calendar_date");
    let p = f.params.iter().find(|p| p.name == "month").expect("month param");
    assert!(matches!(&p.ty, ScalarType::Enum(path, _) if path.ends_with("Month")));

    let src = emit(&spec);
    assert!(
        src.contains(r#"let month = match month { "January" => time::Month::January,"#),
        "the month param must be decoded from its variant name"
    );
    // Its return stays a single `Result` (from the source `Result`), so the decoded
    // value flows into the existing map/map_err chain — never a second `Ok(..)`.
    assert!(
        src.contains("time::Date::from_calendar_date(year, month, day).map(Self).map_err(|e| e.to_string())"),
        "the decoded value must flow into the existing Result map/map_err chain"
    );
    assert!(
        !src.contains("Ok(time::Date::from_calendar_date"),
        "an already-fallible method must not be wrapped in a second Ok(..)"
    );
}
