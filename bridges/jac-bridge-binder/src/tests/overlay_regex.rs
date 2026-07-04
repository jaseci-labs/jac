//! Overlay tests — D6 table syntax over the regex fixture.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{apply_overlay, classify, classify_with_overlay, emit, parse_overlay};

fn sig_contains(src: &str, pat: &str) -> bool {
    let a: String = src.chars().filter(|c| !c.is_whitespace()).collect();
    let b: String = pat.chars().filter(|c| !c.is_whitespace()).collect();
    a.contains(&b)
}

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
    assert!(!sig_contains(&src, "pub struct RegexSet("), "skipped type leaked\n{src}");
    assert!(sig_contains(&src, "pub struct Regex("), "Regex must survive\n{src}");
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
    assert!(sig_contains(&src, "pub fn matches(&self,"), "renamed fn missing\n{src}");
    // …but the Rust call target is still the real method.
    assert!(sig_contains(&src, "self.0.is_match("), "call target changed\n{src}");
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
    assert!(sig_contains(&src, "sentinel_method"), "injected method missing\n{src}");
}

// ── reserved directives fail loud, not silently ────────────────────────────────

#[test]
fn treat_as_skip_forces_a_bridged_method_off() {
    // Regex::is_match auto-classifies as a bridged bool method; treat_as="skip"
    // forces it off the bridge and records it as an honest skip.
    let overlay =
        parse_overlay("[fn.\"Regex::is_match\"]\ntreat_as = \"skip\"\n").unwrap();
    let spec = classify_with_overlay(&load_regex_doc(), Some(&overlay));

    let regex = spec.types.iter().find(|t| t.name == "Regex").unwrap();
    assert!(
        !regex.methods.iter().any(|m| m.name == "is_match"),
        "treat_as=skip should remove the method"
    );
    assert!(
        spec.skips.iter().any(|s| s.item == "Regex::is_match"),
        "forced-off method must be recorded as a skip, not silently dropped"
    );
}

#[test]
fn treat_as_pins_a_rule_and_matches_auto_detection() {
    // Regex::find auto-detects as an owning wrapper. Pinning treat_as="owning"
    // yields the SAME result via the forced path — a confirmation, not a change.
    let overlay = parse_overlay("[fn.\"Regex::find\"]\ntreat_as = \"owning\"\n").unwrap();
    let spec = classify_with_overlay(&load_regex_doc(), Some(&overlay));
    let regex = spec.types.iter().find(|t| t.name == "Regex").unwrap();
    let find = regex.methods.iter().find(|m| m.name == "find").expect("find still a producer");
    assert!(
        matches!(&find.ret, crate::types::BridgeReturn::OptWrapper(w) if w == "OwnedMatch"),
        "pinned owning rule should still produce OwnedMatch, got {:?}",
        find.ret
    );
}

#[test]
fn treat_as_pinning_an_inapplicable_rule_is_an_honest_skip() {
    // Regex::find is an owning-wrapper shape, NOT a Vec/slice return, so pinning
    // treat_as="drain" can't apply — it becomes a recorded skip, never a silent
    // drop or an invalid emission.
    let overlay = parse_overlay("[fn.\"Regex::find\"]\ntreat_as = \"drain\"\n").unwrap();
    let spec = classify_with_overlay(&load_regex_doc(), Some(&overlay));
    let regex = spec.types.iter().find(|t| t.name == "Regex").unwrap();
    assert!(
        !regex.methods.iter().any(|m| m.name == "find"),
        "find should not be bridged when pinned to an inapplicable rule"
    );
    assert!(
        spec.skips.iter().any(|s| s.item == "Regex::find"),
        "an inapplicable pinned rule must record a skip"
    );
}

#[test]
fn treat_as_unknown_value_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[fn.\"Regex::find\"]\ntreat_as = \"teleport\"\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("treat_as"), "err should name the directive: {err}");
    assert!(err.contains("teleport"), "err should quote the bad value: {err}");
}

#[test]
fn monomorphize_empty_set_is_rejected() {
    // A monomorphize directive that pins nothing is a mistake, not a no-op.
    // (The positive path — pinning a real generic struct — is covered against the
    // chrono fixture in `monomorphize_chrono`, since regex has no generic types.)
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[type.\"RegexSet\"]\nmonomorphize = []\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("monomorphize"), "empty pin set must be rejected: {err}");
}

#[test]
fn module_skip_drops_submodule_types() {
    let mut spec = classify(&load_regex_doc());
    // regex's `Error` enum is declared under the `error` submodule; Regex and
    // RegexSet live under `regex::string` / `regexset::string`.
    assert!(spec.types.iter().any(|t| t.name == "Error"), "precondition: Error present");
    let error_module = spec
        .types
        .iter()
        .find(|t| t.name == "Error")
        .map(|t| t.module_path.clone())
        .unwrap();
    assert_eq!(error_module, vec!["error".to_string()], "Error provenance");

    let overlay = parse_overlay("[module.\"error\"]\nskip = true\n").unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();

    // The whole `error` submodule surface is gone…
    assert!(
        !spec.types.iter().any(|t| t.name == "Error"),
        "the error submodule's type should be dropped"
    );
    // …but types under other submodules survive.
    assert!(spec.types.iter().any(|t| t.name == "Regex"), "Regex must survive");
    assert!(spec.types.iter().any(|t| t.name == "RegexSet"), "RegexSet must survive");

    let src = emit(&spec);
    assert!(!sig_contains(&src, "pub struct RegexError;"), "skipped error type leaked\n{src}");
    assert!(sig_contains(&src, "pub struct Regex("), "Regex must remain in codegen\n{src}");
}

#[test]
fn module_skip_of_absent_module_is_a_noop() {
    // Skipping a module that groups no classifiable type is harmless, not an error.
    let mut spec = classify(&load_regex_doc());
    let before = spec.types.len();
    let overlay = parse_overlay("[module.\"nonexistent\"]\nskip = true\n").unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();
    assert_eq!(spec.types.len(), before, "no type should be removed");
}

#[test]
fn typo_in_type_name_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[type.\"Regexx\"]\ninject = \"x\"\n").unwrap();
    assert!(apply_overlay(&mut spec, &overlay).is_err(), "unknown type must error");
}
