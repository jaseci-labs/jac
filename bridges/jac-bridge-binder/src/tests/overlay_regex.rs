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
    assert!(o.types["Regex"]
        .inject
        .as_ref()
        .unwrap()
        .contains("find_str"));
    assert!(o.fns["RegexBuilder::new"].skip);
    assert_eq!(
        o.fns["Regex::shortest_match"].rename.as_deref(),
        Some("find_end")
    );
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
    assert!(
        !sig_contains(&src, "pub struct RegexSet("),
        "skipped type leaked\n{src}"
    );
    assert!(
        sig_contains(&src, "pub struct Regex("),
        "Regex must survive\n{src}"
    );
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
    assert!(
        sig_contains(&src, "pub fn matches(&self,"),
        "renamed fn missing\n{src}"
    );
    // …but the Rust call target is still the real method.
    assert!(
        sig_contains(&src, "self.0.is_match("),
        "call target changed\n{src}"
    );
    // Regex no longer exposes the old name (RegexSet::is_match is untouched, so
    // check the renamed method's body sits next to the new signature).
    let matches_line = src.find("pub fn matches(&self,").unwrap();
    let body = &src[matches_line..matches_line + 120];
    assert!(
        body.contains("self.0.is_match("),
        "renamed body must call is_match\n{body}"
    );
}

#[test]
fn inject_source_appears_in_codegen() {
    let mut spec = classify(&load_regex_doc());
    let snippet = "        pub fn sentinel_method(&self) -> bool { true }\n";
    let overlay_src = format!("[type.\"Regex\"]\ninject = '''\n{snippet}'''\n");
    let overlay = parse_overlay(&overlay_src).unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();

    let src = emit(&spec);
    assert!(
        sig_contains(&src, "sentinel_method"),
        "injected method missing\n{src}"
    );
}

// ── reserved directives fail loud, not silently ────────────────────────────────

#[test]
fn treat_as_skip_forces_a_bridged_method_off() {
    // Regex::is_match auto-classifies as a bridged bool method; treat_as="skip"
    // forces it off the bridge and records it as an honest skip.
    let overlay = parse_overlay("[fn.\"Regex::is_match\"]\ntreat_as = \"skip\"\n").unwrap();
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
    let find = regex
        .methods
        .iter()
        .find(|m| m.name == "find")
        .expect("find still a producer");
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
    assert!(
        err.contains("treat_as"),
        "err should name the directive: {err}"
    );
    assert!(
        err.contains("teleport"),
        "err should quote the bad value: {err}"
    );
}

#[test]
fn monomorphize_empty_set_is_rejected() {
    // A monomorphize directive that pins nothing is a mistake, not a no-op.
    // (The positive path — pinning a real generic struct — is covered against the
    // chrono fixture in `monomorphize_chrono`, since regex has no generic types.)
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[type.\"RegexSet\"]\nmonomorphize = []\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(
        err.contains("monomorphize"),
        "empty pin set must be rejected: {err}"
    );
}

#[test]
fn module_skip_drops_submodule_types() {
    let mut spec = classify(&load_regex_doc());
    // regex's `Error` enum is declared under the `error` submodule; Regex and
    // RegexSet live under `regex::string` / `regexset::string`.
    assert!(
        spec.types.iter().any(|t| t.name == "Error"),
        "precondition: Error present"
    );
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
    assert!(
        spec.types.iter().any(|t| t.name == "Regex"),
        "Regex must survive"
    );
    assert!(
        spec.types.iter().any(|t| t.name == "RegexSet"),
        "RegexSet must survive"
    );

    let src = emit(&spec);
    assert!(
        !sig_contains(&src, "pub struct RegexError;"),
        "skipped error type leaked\n{src}"
    );
    assert!(
        sig_contains(&src, "pub struct Regex("),
        "Regex must remain in codegen\n{src}"
    );
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
    assert!(
        apply_overlay(&mut spec, &overlay).is_err(),
        "unknown type must error"
    );
}

#[test]
fn fn_treat_as_with_skip_is_rejected() {
    // treat_as fully determines the method's fate; pairing it with skip on the
    // same entry would silently drop the skip. It must fail loud instead.
    let mut spec = classify(&load_regex_doc());
    let overlay =
        parse_overlay("[fn.\"Regex::find\"]\ntreat_as = \"owning\"\nskip = true\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(
        err.contains("exclusive"),
        "err should explain exclusivity: {err}"
    );
}

#[test]
fn fn_treat_as_with_rename_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay =
        parse_overlay("[fn.\"Regex::find\"]\ntreat_as = \"owning\"\nrename = \"seek\"\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(
        err.contains("exclusive"),
        "err should explain exclusivity: {err}"
    );
}

#[test]
fn type_treat_as_unknown_value_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[type.\"Regex\"]\ntreat_as = \"quantum\"\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(
        err.contains("treat_as"),
        "err should name the directive: {err}"
    );
    assert!(
        err.contains("quantum"),
        "err should quote the bad value: {err}"
    );
}

#[test]
fn type_treat_as_with_skip_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[type.\"Regex\"]\ntreat_as = \"error\"\nskip = true\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(
        err.contains("exclusive"),
        "err should explain exclusivity: {err}"
    );
}

// ── Phase S: ownership overlay (owned / shared / borrowed) ─────────────────────

/// The Rust source between a method's `#[jac(...)]` attribute (if any) and its
/// `pub fn <name>(` header, so a test can prove the attribute sits ON that method
/// and not on a neighbour. Returns the slice `[attr_start .. header_end)`.
fn method_prelude<'a>(src: &'a str, exposed: &str) -> &'a str {
    let header = format!("pub fn {exposed}(");
    let hdr_pos = src.find(&header).unwrap_or_else(|| panic!("no `{header}`\n{src}"));
    // Walk back to the start of the line before the header.
    let line_start = src[..hdr_pos].rfind('\n').map(|i| i + 1).unwrap_or(0);
    // Include the immediately-preceding line (the attribute, when present).
    let prev_line_start = src[..line_start.saturating_sub(1)]
        .rfind('\n')
        .map(|i| i + 1)
        .unwrap_or(0);
    &src[prev_line_start..hdr_pos + header.len()]
}

#[test]
fn ownership_borrowed_stamps_jac_attribute() {
    // `Regex::find -> Option<OwnedMatch>` is a bridged handle return with `&self` —
    // a legitimate borrowed-view target. The overlay forces the class rustdoc
    // can't prove; codegen stamps the helper attribute the macro reads.
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[fn.\"Regex::find\"]\nownership = \"borrowed\"\n").unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();

    let src = emit(&spec);
    let prelude = method_prelude(&src, "find");
    assert!(
        prelude.contains("#[jac(borrowed)]"),
        "borrowed attr missing on `find`\n{prelude}"
    );
    // The call target is untouched — ownership only tags the return.
    assert!(
        sig_contains(&src, "OwnedMatch::wrap(&self.0, haystack)"),
        "borrowed override must not change the body\n{src}"
    );
}

#[test]
fn ownership_shared_is_rejected() {
    // `shared` is retired (Phase 1.2.4): an unconditional retain-on-adopt leaks a
    // fresh handle box, so the overlay refuses the class rather than stamp a
    // leak-by-construction attribute. A co-owned handle is a `&Self` return, which
    // the loader RC-pins behind a runtime `rh == self` guard.
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[fn.\"Regex::find\"]\nownership = \"shared\"\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(
        err.contains("retired") && err.contains("&Self"),
        "shared overlay must be rejected with a &Self pointer, got:\n{err}"
    );
}

#[test]
fn ownership_default_and_explicit_owned_emit_no_jac_attribute() {
    // No ownership key: byte-for-byte the pre-Phase-S output — no `#[jac(` anywhere.
    let spec_default = classify(&load_regex_doc());
    let src_default = emit(&spec_default);
    assert!(
        !src_default.contains("#[jac("),
        "default codegen must not stamp any ownership attribute\n{src_default}"
    );

    // Explicit `ownership = "owned"` is an accepted no-op — same output.
    let mut spec_owned = classify(&load_regex_doc());
    let overlay = parse_overlay("[fn.\"Regex::find\"]\nownership = \"owned\"\n").unwrap();
    apply_overlay(&mut spec_owned, &overlay).unwrap();
    assert_eq!(
        emit(&spec_owned),
        src_default,
        "explicit owned must be byte-identical to the default"
    );
}

#[test]
fn ownership_unknown_class_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[fn.\"Regex::find\"]\nownership = \"leased\"\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("ownership"), "err should name the directive: {err}");
    assert!(err.contains("leased"), "err should quote the bad value: {err}");
}

#[test]
fn ownership_with_skip_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay =
        parse_overlay("[fn.\"Regex::find\"]\nownership = \"borrowed\"\nskip = true\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("exclusive"), "err should explain exclusivity: {err}");
}

#[test]
fn ownership_with_treat_as_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay =
        parse_overlay("[fn.\"Regex::find\"]\ntreat_as = \"owning\"\nownership = \"shared\"\n")
            .unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("exclusive"), "err should explain exclusivity: {err}");
}

#[test]
fn ownership_on_absent_method_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[fn.\"Regex::no_such_method\"]\nownership = \"shared\"\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(
        err.contains("no_such_method") || err.contains("no bridged method"),
        "err should name the missing method: {err}"
    );
}

// ── skip-with-reason (S.5.2/S.6.4): a deliberately-refused method stays visible ──

#[test]
fn skip_with_reason_is_recorded_and_visible_in_the_report() {
    use crate::report;
    use crate::types::SkipReason;

    // The skip-with-reason contract: a crate the binder cannot soundly bridge
    // (here framed as a Rust-level-unsound aliasing API that would hand out a
    // second raw owner) is refused via the overlay WITH a machine-visible
    // rationale, not silently dropped or falsely "defended".
    let mut spec = classify(&load_regex_doc());
    let reason = "unsound: hands out a second raw owner of the same allocation";
    let overlay = parse_overlay(&format!(
        "[fn.\"Regex::is_match\"]\nskip = true\nreason = \"{reason}\"\n"
    ))
    .unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();

    // The method is off the bridge …
    let regex = spec.types.iter().find(|t| t.name == "Regex").unwrap();
    assert!(!regex.methods.iter().any(|m| m.name == "is_match"));

    // … but recorded as a visible skip carrying the author's reason …
    let skip = spec
        .skips
        .iter()
        .find(|s| s.item == "Regex::is_match")
        .expect("skipped method must be recorded, not silently dropped");
    assert!(
        matches!(&skip.reason, SkipReason::OverlaySkip(Some(r)) if r == reason),
        "skip must carry the author reason, got {:?}",
        skip.reason
    );

    // … and the coverage report shows the reason verbatim.
    let r = report(&spec);
    assert!(
        r.contains(reason),
        "coverage report must surface the skip reason: {r}"
    );
}

#[test]
fn skip_without_reason_still_records_a_visible_skip() {
    use crate::types::SkipReason;

    // Even with no author reason, `skip = true` must record the removal so the
    // coverage ratio cannot be flattered by hiding a method.
    let mut spec = classify(&load_regex_doc());
    let overlay = parse_overlay("[fn.\"Regex::is_match\"]\nskip = true\n").unwrap();
    apply_overlay(&mut spec, &overlay).unwrap();

    let skip = spec
        .skips
        .iter()
        .find(|s| s.item == "Regex::is_match")
        .expect("a reasonless skip is still a recorded skip");
    assert!(matches!(&skip.reason, SkipReason::OverlaySkip(None)));
}

#[test]
fn reason_without_skip_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay =
        parse_overlay("[fn.\"Regex::is_match\"]\nreason = \"stray reason\"\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(
        err.contains("reason requires skip"),
        "err should explain a reason needs a skip: {err}"
    );
}

#[test]
fn reason_with_treat_as_is_rejected() {
    let mut spec = classify(&load_regex_doc());
    let overlay =
        parse_overlay("[fn.\"Regex::is_match\"]\ntreat_as = \"skip\"\nreason = \"x\"\n").unwrap();
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("exclusive"), "err should explain exclusivity: {err}");
}

// ── [type."T"] wide (2.3) ───────────────────────────────────────────────────────

#[test]
fn type_wide_true_sets_force_wide() {
    // `wide = true` overrides serde detection, forcing the type onto the wide lane
    // (consumed by lane resolution, 2.8). regex is serde-free, so this is purely
    // the override path.
    let doc = load_regex_doc();
    let overlay = parse_overlay("[type.\"Regex\"]\nwide = true\n").unwrap();
    let mut spec = classify_with_overlay(&doc, Some(&overlay));
    apply_overlay(&mut spec, &overlay).unwrap();
    let regex = spec.types.iter().find(|t| t.name == "Regex").unwrap();
    assert_eq!(regex.force_wide, Some(true));
    // A type with no directive keeps `None` (follow detection).
    assert!(spec
        .types
        .iter()
        .filter(|t| t.name != "Regex")
        .all(|t| t.force_wide.is_none()));
}

#[test]
fn type_wide_false_is_honoured() {
    let doc = load_regex_doc();
    let overlay = parse_overlay("[type.\"Regex\"]\nwide = false\n").unwrap();
    let mut spec = classify_with_overlay(&doc, Some(&overlay));
    apply_overlay(&mut spec, &overlay).unwrap();
    let regex = spec.types.iter().find(|t| t.name == "Regex").unwrap();
    assert_eq!(regex.force_wide, Some(false));
}

#[test]
fn type_wide_with_skip_is_rejected() {
    let doc = load_regex_doc();
    let overlay = parse_overlay("[type.\"Regex\"]\nwide = true\nskip = true\n").unwrap();
    let mut spec = classify(&doc);
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("wide is exclusive with skip"), "{err}");
}

#[test]
fn type_wide_with_monomorphize_is_rejected() {
    let doc = load_regex_doc();
    let overlay =
        parse_overlay("[type.\"Regex\"]\nwide = true\nmonomorphize = [\"u8\"]\n").unwrap();
    let mut spec = classify(&doc);
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("wide is not supported alongside monomorphize"), "{err}");
}
