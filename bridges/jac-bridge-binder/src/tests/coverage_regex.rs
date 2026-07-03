//! Coverage-metric tests over the regex fixture.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{
    classify, coverage, report,
    types::SkipReason,
};

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
fn integer_param_method_is_a_recorded_skip() {
    // is_match_at(&self, &str, usize) can't cross the v1 boundary. It must be a
    // *reasoned skip*, not a silent drop — otherwise coverage over-reports.
    let spec = classify(&load_regex_doc());
    let skip = spec
        .skips
        .iter()
        .find(|s| s.item == "Regex::is_match_at")
        .expect("is_match_at should be a recorded skip");
    assert_eq!(
        skip.reason,
        SkipReason::UnsupportedType("usize param".into()),
        "int-param skip should name the offending type precisely"
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
    assert!(cov.skipped > 0, "regex has lifetime/cursor methods that must skip");
    assert_eq!(cov.total(), cov.bridged + cov.skipped);
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
    // A precise int-param reason must be visible to humans.
    assert!(
        r.contains("Regex::is_match_at (unsupported type: usize param)"),
        "report should carry the int-param skip reason: {r}"
    );
}

#[test]
fn empty_surface_is_full_coverage() {
    use crate::types::BridgeSpec;
    let spec = BridgeSpec {
        module_name: "empty".into(),
        crate_version: "0.1.0".into(),
        types: vec![],
        skips: vec![],
    };
    assert_eq!(coverage(&spec).pct(), 100);
}
