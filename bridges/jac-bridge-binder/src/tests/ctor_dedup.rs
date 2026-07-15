//! 0.3.1 + 1.3 — deterministic single-constructor selection, extras as statics.
//!
//! A type may expose several `-> Self` associated fns. Exactly one becomes the
//! wrapper's constructor (`init`); the rest are admitted as STATIC factories
//! (1.3 FN_STATIC) — `is_static` methods exposed on the type — chosen so the
//! winner never rides on walk order. The chrono fixture is the testbed:
//! `TimeDelta` has eleven `-> Self` fns (`days`/`hours`/`weeks`/`zero`/…) and
//! `NaiveDate` has three (`from_num_days_from_ce`/`from_ymd`/`from_yo`).

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::classify;

fn load_chrono_doc() -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/chrono-0.4.45.json");
    let data = std::fs::read_to_string(&p).expect("read chrono fixture");
    serde_json::from_str(&data).expect("parse chrono fixture")
}

/// The names of a type's STATIC (1.3 `is_static`) methods — the extra `-> Self`
/// factories the ctor slot couldn't hold.
fn static_method_names(bt: &crate::types::BridgeType) -> Vec<String> {
    bt.methods
        .iter()
        .filter(|m| m.is_static)
        .map(|m| m.name.clone())
        .collect()
}

#[test]
fn timedelta_keeps_one_ctor_and_extras_become_statics() {
    let spec = classify(&load_chrono_doc());
    let td = spec
        .types
        .iter()
        .find(|t| t.name == "TimeDelta")
        .expect("TimeDelta type");

    // The winner is the alphabetically-first `-> Self` fn: `days`.
    let ctor = td.ctor.as_ref().expect("TimeDelta must keep one ctor");
    assert_eq!(ctor.name, "days");

    // Every OTHER `-> Self` fn is admitted as a STATIC factory (1.3), not a skip.
    // `hours`/`weeks`/`zero` are present as `is_static` methods; `days` (the
    // winner) is NOT a method (it is the ctor).
    let statics = static_method_names(td);
    for expected in ["hours", "weeks", "zero"] {
        assert!(
            statics.iter().any(|s| s == expected),
            "expected `{expected}` admitted as a static factory; got {statics:?}"
        );
    }
    assert!(
        !td.methods.iter().any(|m| m.name == "days"),
        "the winning ctor must not also be a method"
    );
}

#[test]
fn naivedate_ctor_is_deterministic_winner() {
    let spec = classify(&load_chrono_doc());
    let nd = spec
        .types
        .iter()
        .find(|t| t.name == "NaiveDate")
        .expect("NaiveDate type");
    // Candidates: from_num_days_from_ce / from_ymd / from_yo — sorted, the first wins.
    assert_eq!(nd.ctor.as_ref().expect("NaiveDate ctor").name, "from_num_days_from_ce");

    // The losers are now static factories on NaiveDate.
    let statics = static_method_names(nd);
    assert!(statics.iter().any(|s| s == "from_ymd"), "got {statics:?}");
    assert!(statics.iter().any(|s| s == "from_yo"), "got {statics:?}");
}

#[test]
fn constructor_selection_is_byte_identical_across_runs() {
    // Determinism: classifying the same doc twice yields the same ctor winners
    // and the same per-type static-factory set (in the same order), so the
    // choice never rides on rustdoc index / HashMap iteration order.
    let a = classify(&load_chrono_doc());
    let b = classify(&load_chrono_doc());

    let ctors = |spec: &crate::types::BridgeSpec| -> Vec<(String, String)> {
        spec.types
            .iter()
            .filter_map(|t| t.ctor.as_ref().map(|c| (t.name.clone(), c.name.clone())))
            .collect()
    };
    let statics = |spec: &crate::types::BridgeSpec| -> Vec<(String, Vec<String>)> {
        spec.types
            .iter()
            .map(|t| (t.name.clone(), static_method_names(t)))
            .collect()
    };
    assert_eq!(ctors(&a), ctors(&b), "ctor winners must be deterministic");
    assert_eq!(
        statics(&a),
        statics(&b),
        "static-factory sets must be deterministic"
    );
}
