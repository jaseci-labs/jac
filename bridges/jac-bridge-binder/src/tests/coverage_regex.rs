//! Coverage-metric tests over the regex fixture.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, coverage, report};

fn load_regex_doc() -> Crate {
    let candidates = [
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/regex-1.12.4.json"),
        PathBuf::from(env!("HOME")).join(
            ".cargo/registry/src/index.crates.io-1949cf8c6b5b557f/regex-1.12.4/target/doc/regex.json",
        ),
    ];
    for p in &candidates {
        if p.exists() {
            let data = std::fs::read_to_string(p).expect("read rustdoc json");
            return serde_json::from_str(&data).expect("parse rustdoc json");
        }
    }
    panic!("regex rustdoc JSON not found");
}

#[test]
fn integer_param_method_now_bridges() {
    // is_match_at(&self, &str, usize) -> bool now crosses the boundary: the usize
    // param carries in a u64 slot (TAG_UINT). It must be BRIDGED, not skipped.
    let spec = classify(&load_regex_doc());
    assert!(
        !spec.skips.iter().any(|s| s.item == "Regex::is_match_at"),
        "is_match_at should no longer be a skip: {:?}",
        spec.skips.iter().map(|s| &s.item).collect::<Vec<_>>()
    );
    let regex = spec
        .types
        .iter()
        .find(|t| t.name == "Regex")
        .expect("Regex type");
    assert!(
        regex.methods.iter().any(|m| m.exposed() == "is_match_at"),
        "is_match_at should be emitted as a method"
    );
}

#[test]
fn coverage_ratio_is_honest() {
    let spec = classify(&load_regex_doc());
    let cov = coverage(&spec);

    assert_eq!(cov.module, "regex");
    assert_eq!(cov.version, "1.12.4");
    // Regex::new + is_match at minimum are bridged.
    assert!(cov.bridged >= 2, "expected the ctor + is_match to bridge");
    assert!(
        cov.skipped > 0,
        "regex has lifetime/cursor methods that must skip"
    );
    // Total counts every considered unit: bridged fns + per-method skips + whole
    // types dropped before method classification (lifetime/const/unpinned generics).
    assert_eq!(cov.total(), cov.bridged + cov.skipped + cov.dropped);
    assert!(
        cov.dropped > 0,
        "regex has lifetime-bearing types dropped wholesale"
    );
    assert!(cov.pct() <= 100);
    // bridged count must equal what codegen actually emits (no phantom coverage).
    let emitted: usize = spec
        .types
        .iter()
        .map(|t| t.ctor.is_some() as usize + t.methods.len())
        .sum();
    assert_eq!(cov.bridged, emitted);
}

#[test]
fn report_names_crate_and_lists_skips() {
    let spec = classify(&load_regex_doc());
    let r = report(&spec);
    assert!(r.starts_with("regex v1.12.4:"), "report line: {r}");
    assert!(r.contains("% of public API bridged"), "report line: {r}");
    assert!(r.contains("skipped:"), "report should list skips: {r}");
    // A precise, human-readable reason must be visible for a still-skipped item.
    // (Lifetime-borrow returns that no owning-wrapper rescues remain skipped.)
    assert!(
        r.contains("(lifetime")
            || r.contains("(unsupported type:")
            || r.contains("(cursor")
            || r.contains("(generic"),
        "report should carry at least one precise skip reason: {r}"
    );
}

#[test]
fn empty_surface_is_full_coverage() {
    use crate::types::BridgeSpec;
    let spec = BridgeSpec {
        module_name: "empty".into(),
        crate_version: "0.1.0".into(),
        crate_features: vec![],
        types: vec![],
        skips: vec![],
        dropped: vec![],
        inherited_excluded: 0,
    };
    assert_eq!(coverage(&spec).pct(), 100);
}
