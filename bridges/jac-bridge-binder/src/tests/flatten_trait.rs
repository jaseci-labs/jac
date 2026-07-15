//! Trait flattening (Track A, 1.1.1/1.1.3/1.1.4/1.1.5): a SEMANTIC trait impl
//! (`impl Datelike for NaiveDate`) has its concretely-provided methods flattened
//! onto the type as inherent methods; NOISE traits (Debug/Clone/…) stay ignored;
//! an inherent ctor beats a trait-flattened one; codegen brings each flattened
//! trait into scope with a `use`.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, coverage, emit, types::BridgeReturn};

fn load(fixture: &str) -> Crate {
    let p =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(format!("tests/fixtures/{fixture}.json"));
    let data = std::fs::read_to_string(&p).unwrap_or_else(|_| panic!("read {fixture}"));
    serde_json::from_str(&data).unwrap_or_else(|e| panic!("parse {fixture}: {e}"))
}

#[test]
fn datelike_methods_are_flattened_onto_naivedate_with_via_trait() {
    let spec = classify(&load("chrono-0.4.45"));
    let nd = spec
        .types
        .iter()
        .find(|t| t.name == "NaiveDate")
        .expect("NaiveDate is bridged");

    // `Datelike::year(&self) -> i32` is a semantic trait accessor: flattened as an
    // inherent method, carrying its trait provenance for the `use`.
    let year = nd
        .methods
        .iter()
        .find(|m| m.name == "year")
        .expect("Datelike::year flattened onto NaiveDate");
    assert!(matches!(year.ret, BridgeReturn::Int(_)), "year returns i32");
    assert_eq!(
        year.via_trait.as_deref(),
        Some("chrono::Datelike"),
        "flattened method records its trait via the module's re-export path"
    );

    // Codegen brings the trait into scope so `self.0.year()` resolves.
    let src = emit(&spec);
    assert!(
        src.contains("use chrono::Datelike;"),
        "emitted source must `use` the flattened trait\n{src}"
    );
}

#[test]
fn noise_trait_methods_are_not_flattened() {
    let spec = classify(&load("chrono-0.4.45"));
    // `Clone`/`PartialEq`/`Hash` etc. are NOISE — their methods (`clone`, `eq`,
    // `cmp`, `hash`) must never appear as bridged surface.
    for bt in &spec.types {
        for m in &bt.methods {
            assert!(
                !matches!(
                    m.name.as_str(),
                    "clone" | "eq" | "ne" | "cmp" | "hash" | "fmt"
                ),
                "{}::{} is a NOISE-trait method and must not be flattened",
                bt.name,
                m.name
            );
        }
    }
}

#[test]
fn inherent_ctor_beats_a_flattened_trait_ctor() {
    // regex's `Regex` has an inherent `new(&str) -> Result<Self>` AND implements
    // `FromStr` (`from_str(&str) -> Result<Self>`). The inherent `new` must win THE
    // constructor slot; `from_str` is demoted to a visible "additional constructor"
    // skip — never a second emitted ctor, and never a method needing `use FromStr`.
    let spec = classify(&load("regex-1.12.4"));
    let re = spec
        .types
        .iter()
        .find(|t| t.name == "Regex")
        .expect("Regex is bridged");
    let ctor = re.ctor.as_ref().expect("Regex has a constructor");
    assert_eq!(
        ctor.name, "new",
        "inherent `new` wins over flattened `from_str`"
    );
    assert!(
        ctor.via_trait.is_none(),
        "the winning ctor is the inherent one"
    );
    // `from_str` neither bridges as a method nor as the ctor.
    assert!(
        !re.methods.iter().any(|m| m.name == "from_str"),
        "from_str must not be a bridged method"
    );
    assert!(
        spec.skips.iter().any(|s| s.item == "Regex::from_str"),
        "from_str is a visible skip"
    );
    // No `use` for a std trait leaked (from_str never emits).
    assert!(
        !emit(&spec).contains("FromStr"),
        "no FromStr use should be emitted"
    );
}

#[test]
fn flattening_lifts_chrono_coverage_without_regressing_regex() {
    // regex is inherent-heavy: flattening leaves its bridged count byte-identical
    // (the sole semantic trait on a bridged type, FromStr, demotes to a skip).
    // 1.2.5 (tuple-struct admission) lifted the count 31 -> 39: `SetMatches` and
    // `CaptureLocations` are single-field private tuple structs now bridged as
    // opaque handles, and `RegexSet::matches -> SetMatches` crosses as a ref-lane
    // handle rather than a skip.
    let regex = coverage(&classify(&load("regex-1.12.4")));
    assert_eq!(regex.bridged, 39, "regex bridged unchanged by flattening");

    // chrono is trait-heavy (Datelike/Timelike): flattening lifts it well past the
    // pre-Track-A floor of 33.
    let chrono = coverage(&classify(&load("chrono-0.4.45")));
    assert!(
        chrono.bridged >= 50,
        "flattening lifts chrono bridged (got {})",
        chrono.bridged
    );
}
