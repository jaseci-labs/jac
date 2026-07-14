//! 0.3.1 — deterministic single-constructor selection.
//!
//! A type may expose several `-> Self` associated fns. Exactly one becomes the
//! wrapper's constructor; the rest must be recorded as honest "additional
//! constructor" skips (never silently clobbered by walk order). The chrono
//! fixture is the testbed: `TimeDelta` has eleven `-> Self` fns
//! (`days`/`hours`/`weeks`/`zero`/…) and `NaiveDate` has three
//! (`from_num_days_from_ce`/`from_ymd`/`from_yo`).

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, types::SkipReason};

fn load_chrono_doc() -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/chrono-0.4.45.json");
    let data = std::fs::read_to_string(&p).expect("read chrono fixture");
    serde_json::from_str(&data).expect("parse chrono fixture")
}

/// Collect the item paths recorded as "additional constructor" skips.
fn additional_ctor_skips(spec: &crate::types::BridgeSpec) -> Vec<String> {
    spec.skips
        .iter()
        .filter(|s| {
            matches!(&s.reason, SkipReason::UnsupportedType(m) if m.starts_with("additional constructor"))
        })
        .map(|s| s.item.clone())
        .collect()
}

#[test]
fn timedelta_keeps_one_ctor_and_skips_the_rest() {
    let spec = classify(&load_chrono_doc());
    let td = spec
        .types
        .iter()
        .find(|t| t.name == "TimeDelta")
        .expect("TimeDelta type");

    // The winner is the alphabetically-first `-> Self` fn: `days`.
    let ctor = td.ctor.as_ref().expect("TimeDelta must keep one ctor");
    assert_eq!(ctor.name, "days");

    // None of the losing ctors leaked into the method list.
    for m in &td.methods {
        assert_ne!(m.name, "hours", "extra ctor `hours` must not be a method");
        assert_ne!(m.name, "days", "the winning ctor must not also be a method");
    }

    // Every other `-> Self` fn is an honest skip. `hours`/`weeks`/`zero` are
    // present; `days` (the winner) is absent from the skip list.
    let skips = additional_ctor_skips(&spec);
    for expected in ["TimeDelta::hours", "TimeDelta::weeks", "TimeDelta::zero"] {
        assert!(
            skips.iter().any(|s| s == expected),
            "expected `{expected}` recorded as additional-constructor skip; got {skips:?}"
        );
    }
    assert!(
        !skips.iter().any(|s| s == "TimeDelta::days"),
        "the winning ctor must NOT be skipped"
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

    let skips = additional_ctor_skips(&spec);
    assert!(skips.iter().any(|s| s == "NaiveDate::from_ymd"));
    assert!(skips.iter().any(|s| s == "NaiveDate::from_yo"));
}

#[test]
fn constructor_selection_is_byte_identical_across_runs() {
    // Determinism: classifying the same doc twice yields the same ctor winners
    // and the same additional-constructor skip set (in the same order), so the
    // choice never rides on rustdoc index / HashMap iteration order.
    let a = classify(&load_chrono_doc());
    let b = classify(&load_chrono_doc());

    let ctors = |spec: &crate::types::BridgeSpec| -> Vec<(String, String)> {
        spec.types
            .iter()
            .filter_map(|t| t.ctor.as_ref().map(|c| (t.name.clone(), c.name.clone())))
            .collect()
    };
    assert_eq!(ctors(&a), ctors(&b), "ctor winners must be deterministic");
    assert_eq!(
        additional_ctor_skips(&a),
        additional_ctor_skips(&b),
        "additional-constructor skips must be deterministic"
    );
}
