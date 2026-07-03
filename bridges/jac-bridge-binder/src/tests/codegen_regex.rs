use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, emit, emit_cargo_toml};

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
    panic!(
        "regex rustdoc JSON not found — run: cargo +nightly rustdoc -Z unstable-options \
         --output-format json --manifest-path \
         ~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/regex-1.12.4/Cargo.toml"
    );
}

fn generated() -> String {
    let doc = load_regex_doc();
    let spec = classify(&doc);
    emit(&spec)
}

// ── structural checks ─────────────────────────────────────────────────────────

#[test]
fn has_bridge_attribute() {
    let src = generated();
    assert!(src.contains("#[bridge(module = \"regex\")]"), "missing bridge attribute\n{}", src);
}

#[test]
fn regex_struct_wraps_inner() {
    let src = generated();
    assert!(
        src.contains("pub struct Regex(pub regex::Regex);"),
        "missing opaque struct\n{}",
        src
    );
}

#[test]
fn error_struct_renamed_to_regex_error() {
    let src = generated();
    assert!(src.contains("#[jac_error]"), "missing #[jac_error]\n{}", src);
    assert!(src.contains("pub struct RegexError;"), "missing RegexError\n{}", src);
    // Original "Error" name must not appear as a bare struct (it becomes RegexError).
    assert!(
        !src.contains("pub struct Error;"),
        "bare Error struct leaked into output\n{}",
        src
    );
}

#[test]
fn ctor_new_emitted_correctly() {
    let src = generated();
    // The param name comes from rustdoc; regex 1.12.4 uses `re` not `pattern`.
    assert!(
        src.contains("-> Result<Self, String>"),
        "missing Result<Self,String> return on new\n{}",
        src
    );
    assert!(
        src.contains(".map(Self).map_err(|e| e.to_string())"),
        "missing fallible ctor body pattern\n{}",
        src
    );
}

#[test]
fn method_is_match_emitted_correctly() {
    let src = generated();
    // The param name comes from rustdoc; regex 1.12.4 uses `haystack`.
    assert!(
        src.contains("pub fn is_match(&self,") && src.contains("-> bool"),
        "missing is_match signature\n{}",
        src
    );
    assert!(
        src.contains("self.0.is_match("),
        "missing is_match body\n{}",
        src
    );
}

// ── integer-param methods are silently dropped ─────────────────────────────────

#[test]
fn integer_param_methods_not_emitted() {
    let src = generated();
    // is_match_at(&self, &str, usize) — usize param, must be absent from bridge source.
    assert!(
        !src.contains("is_match_at"),
        "integer-param method leaked into codegen output\n{}",
        src
    );
}

// ── owning-wrapper synthesis (M4 Phase B v1) ───────────────────────────────────

#[test]
fn owned_match_wrapper_emitted() {
    let src = generated();
    // The ouroboros struct: borrower (lifetime erased) before the owned input.
    assert!(
        src.contains("pub struct OwnedMatch {")
            && src.contains("inner: regex::Match<'static>,")
            && src.contains("_input: std::sync::Arc<String>,"),
        "missing OwnedMatch ouroboros struct\n{src}"
    );
    // The non-pub wrap ctor clones the input into an Arc, produces from it, erases
    // the borrow. The Arc lets a nested wrapper share this exact buffer.
    assert!(
        src.contains("fn wrap(owner: &regex::Regex, input: &str) -> Option<OwnedMatch>")
            && src.contains("let owned = std::sync::Arc::new(input.to_owned());")
            && src.contains("let inner = owner.find(owned.as_str())?;")
            && src.contains("let inner: regex::Match<'static> = unsafe { std::mem::transmute(inner) };"),
        "missing/incorrect wrap ctor\n{src}"
    );
    // The producer on Regex returns the wrapper.
    assert!(
        src.contains("pub fn find(&self, haystack: &str) -> Option<OwnedMatch>")
            && src.contains("OwnedMatch::wrap(&self.0, haystack)"),
        "missing find producer\n{src}"
    );
    // Readers delegate through self.inner (the erased borrowing value).
    assert!(
        src.contains("pub fn as_str(&self) -> String") && src.contains("self.inner.as_str().to_string()"),
        "missing OwnedMatch::as_str reader\n{src}"
    );
    assert!(
        src.contains("pub fn is_empty(&self) -> bool") && src.contains("self.inner.is_empty()"),
        "missing OwnedMatch::is_empty reader\n{src}"
    );
}

#[test]
fn owned_captures_nested_producer_emitted() {
    let src = generated();
    // The OwnedCaptures wrapper struct (Arc-shared input) and its root wrap ctor.
    assert!(
        src.contains("pub struct OwnedCaptures {")
            && src.contains("inner: regex::Captures<'static>,")
            && src.contains("_input: std::sync::Arc<String>,"),
        "missing OwnedCaptures struct\n{src}"
    );
    assert!(
        src.contains("fn wrap(owner: &regex::Regex, input: &str) -> Option<OwnedCaptures>")
            && src.contains("let inner = owner.captures(owned.as_str())?;"),
        "missing OwnedCaptures root wrap ctor\n{src}"
    );
    // Regex::captures is now a root producer of the wrapper.
    assert!(
        src.contains("pub fn captures(&self, haystack: &str) -> Option<OwnedCaptures>")
            && src.contains("OwnedCaptures::wrap(&self.0, haystack)"),
        "missing captures producer\n{src}"
    );
    // The NESTED producer: OwnedCaptures::name builds an OwnedMatch inline from the
    // parent's borrowing value, sharing the owned buffer via an Arc clone — no
    // transmute, no re-allocation.
    assert!(
        src.contains("pub fn name(&self, name: &str) -> Option<OwnedMatch>")
            && src.contains("let inner = self.inner.name(name)?;")
            && src.contains(
                "Some(OwnedMatch { inner, _input: std::sync::Arc::clone(&self._input) })"
            ),
        "missing/incorrect OwnedCaptures::name nested producer\n{src}"
    );
}

#[test]
fn cursor_and_drain_wrappers_emitted() {
    let src = generated();

    // CURSOR struct: owns the erased iterator + the regex and haystack it borrows,
    // each via Arc. Field order borrower(iter)-before-owners.
    assert!(
        src.contains("pub struct OwnedMatches {")
            && src.contains("iter: regex::Matches<'static, 'static>,")
            && src.contains("_owner: std::sync::Arc<regex::Regex>,")
            && src.contains("_input: std::sync::Arc<String>,"),
        "missing OwnedMatches cursor struct\n{src}"
    );
    // Its wrap clones the regex + haystack into Arcs and transmutes the iterator;
    // returns the wrapper directly (a cursor is always constructed, no Option).
    assert!(
        src.contains("fn wrap(owner: &regex::Regex, input: &str) -> OwnedMatches {")
            && src.contains("let owner = std::sync::Arc::new(owner.clone());")
            && src.contains("unsafe { std::mem::transmute(owner.find_iter(owned.as_str())) };"),
        "missing/incorrect OwnedMatches::wrap\n{src}"
    );
    // The pull method: &mut self, pulls one item, shares the input Arc.
    assert!(
        src.contains("pub fn next(&mut self) -> Option<OwnedMatch> {")
            && src.contains("let inner = self.iter.next()?;"),
        "missing OwnedMatches::next pull\n{src}"
    );
    // The producer on Regex returns the cursor directly.
    assert!(
        src.contains("pub fn find_iter(&self, haystack: &str) -> OwnedMatches {")
            && src.contains("OwnedMatches::wrap(&self.0, haystack)"),
        "missing find_iter producer\n{src}"
    );

    // captures_iter is a cursor too, whose item wrapper OwnedCaptures is the SAME
    // type `captures` produces — merged, so OwnedCaptures keeps its root wrap ctor.
    assert!(
        src.contains("pub struct OwnedCaptureMatches {")
            && src.contains("pub fn next(&mut self) -> Option<OwnedCaptures> {"),
        "missing OwnedCaptureMatches cursor\n{src}"
    );
    assert_eq!(
        src.matches("pub struct OwnedCaptures {").count(),
        1,
        "OwnedCaptures must be emitted exactly once (merged)\n{src}"
    );

    // DRAIN struct: owns only a Vec<String>, drained via pop().
    assert!(
        src.contains("pub struct OwnedSplit {") && src.contains("items: Vec<String>,"),
        "missing OwnedSplit drain struct\n{src}"
    );
    assert!(
        src.contains("fn wrap(owner: &regex::Regex, input: &str) -> OwnedSplit {")
            && src.contains("owner.split(input).map(|s| s.to_owned()).collect();")
            && src.contains("items.reverse();"),
        "missing/incorrect OwnedSplit::wrap collect\n{src}"
    );
    assert!(
        src.contains("pub fn next(&mut self) -> Option<String> {")
            && src.contains("self.items.pop()"),
        "missing OwnedSplit::next drain\n{src}"
    );
    assert!(
        src.contains("pub fn split(&self, haystack: &str) -> OwnedSplit {"),
        "missing split producer\n{src}"
    );
}

#[test]
fn replace_all_callback_emitted() {
    let src = generated();

    // The callback method: haystack + a JacCallback, returning a fallible String.
    assert!(
        src.contains(
            "pub fn replace_all(&self, haystack: &str, rep: JacCallback) -> Result<String, String>"
        ),
        "missing replace_all callback signature\n{src}"
    );
    // The replacer closure walks the crate's Captures, feeds each match's text to
    // the callback, and splices in the returned replacement.
    assert!(
        src.contains("self.0.replace_all(haystack, |caps: &regex::Captures| {")
            && src.contains("let m = caps.get(0).map_or(\"\", |x| x.as_str());")
            && src.contains("match rep.call(m) {"),
        "missing/incorrect replacer closure body\n{src}"
    );
    // The first callback error is captured and surfaced as the method's Err.
    assert!(
        src.contains("if err.borrow().is_none() { *err.borrow_mut() = Some(e); }")
            && src.contains("match err.into_inner() { Some(e) => Err(e), None => Ok(out) }"),
        "missing callback-error propagation\n{src}"
    );
}

// ── Cargo.toml emitter ───────────────────────────────────────────────────────

#[test]
fn cargo_toml_correct_shape() {
    let doc = load_regex_doc();
    let spec = classify(&doc);
    let toml = emit_cargo_toml(&spec, "../jac-bridge");

    assert!(toml.contains("name = \"jac-bridge-regex\""), "wrong crate name\n{}", toml);
    assert!(toml.contains("crate-type = [\"cdylib\", \"rlib\"]"), "missing cdylib\n{}", toml);
    // Pinned exact version so generated crates are reproducible.
    assert!(
        toml.contains("regex = \"=1.12.4\""),
        "missing exact-version pin for regex\n{}",
        toml
    );
    assert!(
        toml.contains("jac-bridge = { path = \"../jac-bridge\" }"),
        "missing jac-bridge path dep\n{}",
        toml
    );
}

// ── lifetime-bearing types excluded ───────────────────────────────────────────

#[test]
fn cursor_types_not_emitted() {
    let src = generated();
    for name in &["Match", "Captures", "CaptureMatches", "Matches", "Split", "SplitN"] {
        assert!(
            !src.contains(&format!("pub struct {}(", name)),
            "cursor type {} leaked into codegen output\n{}",
            name,
            src
        );
    }
}
