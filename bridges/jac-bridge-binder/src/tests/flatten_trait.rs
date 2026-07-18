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
    // `Clone`/`PartialEq`/`Hash`/`Debug`/`PartialOrd` are NOISE — their methods
    // (`clone`, `eq`, `ne`, `hash`, `fmt`, `partial_cmp`) must never appear as
    // bridged surface. (`cmp` is NOT here: it is not a *flattened* Ord method but a
    // deliberately SYNTHESIZED reader from the Ord lane — `impl Ord -> cmp -> i8` —
    // so it is legitimate bridged surface, distinct from noise flattening.)
    for bt in &spec.types {
        for m in &bt.methods {
            assert!(
                !matches!(
                    m.name.as_str(),
                    "clone" | "eq" | "ne" | "hash" | "fmt" | "partial_cmp"
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
    // constructor slot; `from_str` is admitted by the dedicated FromStr lane as a
    // separate `#[jac(assoc)]` static (NOT the ctor), calling the trait's associated
    // fn fully-qualified so no (unresolvable) std-trait `use` is emitted.
    let spec = classify(&load("regex-1.12.4"));
    let re = spec
        .types
        .iter()
        .find(|t| t.name == "Regex")
        .expect("Regex is bridged");
    let ctor = re.ctor.as_ref().expect("Regex has a constructor");
    assert_eq!(
        ctor.name, "new",
        "inherent `new` wins over the FromStr static"
    );
    assert!(
        ctor.via_trait.is_none(),
        "the winning ctor is the inherent one"
    );
    // `from_str` bridges as a std-FromStr static, never as the ctor.
    let from_str = re
        .methods
        .iter()
        .find(|m| m.name == "from_str")
        .expect("from_str is a bridged FromStr static");
    assert!(
        from_str.is_static && from_str.std_from_str && from_str.via_trait.is_none(),
        "from_str is a std-FromStr static with no trait `use`"
    );
    // No bogus std-trait `use` leaked (the call is fully-qualified instead).
    let src = emit(&spec);
    assert!(
        !src.contains("use regex::core::") && !src.contains("use regex::std::"),
        "no unresolved std-trait use should be emitted\n{src}"
    );
}

#[test]
fn flattening_lifts_chrono_coverage_without_regressing_regex() {
    // regex is inherent-heavy. 1.2.5 (tuple-struct admission) put its bridged count
    // at 39 (`SetMatches`/`CaptureLocations` opaque handles + the `RegexSet::matches
    // -> SetMatches` ref-lane handle). The regex-parity lanes (builder chain +
    // cross-type fallible build, Option<int>, iterator-of-strings params,
    // replacer-&str, splitn drain, inline find_at/captures_at, get_match,
    // SetMatches::iter collect) lifted 39 -> 77, and the Display/Ord/FromStr synth
    // lanes then add the `from_str` statics (`Regex`/`RegexSet` impl FromStr) and
    // any Display readers, for the unified-rule-set count asserted here.
    let regex = coverage(&classify(&load("regex-1.12.4")));
    assert_eq!(regex.bridged, 79, "regex bridged on the unified lanes");

    // chrono is trait-heavy (Datelike/Timelike): flattening lifts it well past the
    // pre-Track-A floor of 33.
    let chrono = coverage(&classify(&load("chrono-0.4.45")));
    assert!(
        chrono.bridged >= 50,
        "flattening lifts chrono bridged (got {})",
        chrono.bridged
    );
}
