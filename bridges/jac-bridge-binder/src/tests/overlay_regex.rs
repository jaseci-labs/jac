//! Overlay tests — D6 table syntax over the regex fixture.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{apply_overlay, classify, emit, parse_overlay};

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

// ── parse tests ───────────────────────────────────────────────────────────────

#[test]
fn empty_overlay_parses() {
    let o = parse_overlay("").unwrap();
    assert!(o.fns.is_empty());
    assert!(o.types.is_empty());
    assert!(o.modules.is_empty());
}

#[test]
fn full_overlay_parses() {
    let src = r#"
[type."SetMatchesIntoIter"]
skip = true

[type."Regex"]
inject = """
        pub fn find_str(&self, haystack: &str) -> String {
            self.0.find(haystack).map(|m| m.as_str().to_string()).unwrap_or_default()
        }
"""

[fn."RegexBuilder::new"]
skip = true

[fn."Regex::shortest_match"]
rename = "find_end"
"#;
    let o = parse_overlay(src).unwrap();
    assert!(o.types["SetMatchesIntoIter"].skip);
    assert!(o.types["Regex"].inject.as_ref().unwrap().contains("find_str"));
    assert!(o.fns["RegexBuilder::new"].skip);
    assert_eq!(o.fns["Regex::shortest_match"].rename.as_deref(), Some("find_end"));
}

#[test]
fn unknown_field_is_rejected() {
    // deny_unknown_fields guards against silent typos in an overlay.
    let err = parse_overlay("[fn.\"Regex::x\"]\nrenam = \"y\"\n");
    assert!(err.is_err(), "typo'd key must fail to parse");
}

// ── apply tests ───────────────────────────────────────────────────────────────

#[test]
fn skip_type_removes_from_spec_and_codegen() {
    let mut spec = classify(&load_regex_doc());
    assert!(spec.types.iter().any(|t| t.name == "Regex"), "precondition");

    let overlay = parse_overlay("[type.\"RegexSet\"]\nskip = true\n").unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();

    assert!(!spec.types.iter().any(|t| t.name == "RegexSet"));
    assert!(spec.types.iter().any(|t| t.name == "Regex"));
    // Its method-skips are dropped too — they'd be noise in the coverage report.
    assert!(!spec.skips.iter().any(|s| s.item.starts_with("RegexSet::")));

    let src = emit(&spec);
    assert!(!src.contains("pub struct RegexSet("), "skipped type leaked\n{src}");
    assert!(src.contains("pub struct Regex("), "Regex must survive\n{src}");
}

#[test]
fn skip_method_removes_method() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[fn.\"Regex::is_match\"]\nskip = true\n").unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();

    let regex_bt = spec.types.iter().find(|t| t.name == "Regex").unwrap();
    assert!(!regex_bt.methods.iter().any(|m| m.name == "is_match"));
}

#[test]
fn rename_changes_exposed_name_not_call_target() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[fn.\"Regex::is_match\"]\nrename = \"matches\"\n").unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();

    let src = emit(&spec);
    // Exposed name is renamed…
    assert!(src.contains("pub fn matches(&self,"), "renamed fn missing\n{src}");
    // …but the Rust call target is still the real method.
    assert!(src.contains("self.0.is_match("), "call target changed\n{src}");
    // Regex no longer exposes the old name (RegexSet::is_match is untouched, so
    // check the renamed method's body sits next to the new signature).
    let matches_line = src.find("pub fn matches(&self,").unwrap();
    let body = &src[matches_line..matches_line + 120];
    assert!(body.contains("self.0.is_match("), "renamed body must call is_match\n{body}");
}

#[test]
fn inject_source_appears_in_codegen() {
    let mut spec = classify(&load_regex_doc());
    let snippet = "        pub fn sentinel_method(&self) -> bool { true }\n";
    let overlay_src = format!("[type.\"Regex\"]\ninject = '''\n{snippet}'''\n");
    let overlay = parse_overlay(&overlay_src).unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();

    let src = emit(&spec);
    assert!(src.contains("sentinel_method"), "injected method missing\n{src}");
}

// ── reserved directives fail loud, not silently ────────────────────────────────

#[test]
fn treat_as_is_rejected_until_phase_b() {
    let mut spec = classify(&load_regex_doc());
    let overlay =
        parse_overlay("[fn.\"Regex::captures_iter\"]\ntreat_as = \"cursor\"\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("treat_as"), "err should name the directive: {err}");
}

#[test]
fn monomorphize_is_rejected_until_phase_b() {
    let mut spec = classify(&load_regex_doc());
    let overlay =
        parse_overlay("[type.\"RegexSet\"]\nmonomorphize = [\"str\"]\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("monomorphize"), "err should name the directive: {err}");
}

#[test]
fn module_skip_is_rejected_until_phase_b() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[module.\"bytes\"]\nskip = true\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("module"), "err should name the directive: {err}");
}

#[test]
fn typo_in_type_name_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[type.\"Regexx\"]\ninject = \"x\"\n").unwrap();
    assert!(apply_overlay(&mut spec, &overlay).is_err(), "unknown type must error");
}
