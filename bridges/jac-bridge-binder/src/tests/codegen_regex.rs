use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, emit, emit_cargo_toml};

// Whitespace-insensitive substring check: collapses all whitespace in both
// sides before matching so rustfmt or multi-line emission doesn't break tests.
fn sig_contains(src: &str, pat: &str) -> bool {
    let a: String = src.chars().filter(|c| !c.is_whitespace()).collect();
    let b: String = pat.chars().filter(|c| !c.is_whitespace()).collect();
    a.contains(&b)
}

fn sig_count(src: &str, pat: &str) -> usize {
    let a: String = src.chars().filter(|c| !c.is_whitespace()).collect();
    let b: String = pat.chars().filter(|c| !c.is_whitespace()).collect();
    if b.is_empty() {
        return 0;
    }
    let mut count = 0;
    let mut start = 0;
    while let Some(pos) = a[start..].find(&b) {
        count += 1;
        start += pos + b.len();
    }
    count
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
    assert!(sig_contains(&src, "#[bridge(module = \"regex\")]"), "missing bridge attribute\n{}", src);
}

#[test]
fn regex_struct_wraps_inner() {
    let src = generated();
    assert!(
        sig_contains(&src, "pub struct Regex(pub regex::Regex);"),
        "missing opaque struct\n{}",
        src
    );
}

#[test]
fn error_struct_renamed_to_regex_error() {
    let src = generated();
    assert!(sig_contains(&src, "#[jac_error]"), "missing #[jac_error]\n{}", src);
    assert!(sig_contains(&src, "pub struct RegexError;"), "missing RegexError\n{}", src);
    // Original "Error" name must not appear as a bare struct (it becomes RegexError).
    assert!(
        !sig_contains(&src, "pub struct Error;"),
        "bare Error struct leaked into output\n{}",
        src
    );
}

#[test]
fn ctor_new_emitted_correctly() {
    let src = generated();
    // The param name comes from rustdoc; regex 1.12.4 uses `re` not `pattern`.
    assert!(
        sig_contains(&src, "-> Result<Self, String>"),
        "missing Result<Self,String> return on new\n{}",
        src
    );
    assert!(
        sig_contains(&src, ".map(Self).map_err(|e| e.to_string())"),
        "missing fallible ctor body pattern\n{}",
        src
    );
}

#[test]
fn method_is_match_emitted_correctly() {
    let src = generated();
    // The param name comes from rustdoc; regex 1.12.4 uses `haystack`.
    assert!(
        sig_contains(&src, "pub fn is_match(&self,") && sig_contains(&src, "-> bool"),
        "missing is_match signature\n{}",
        src
    );
    assert!(
        sig_contains(&src, "self.0.is_match("),
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
        !sig_contains(&src, "is_match_at"),
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
        sig_contains(&src, "pub struct OwnedMatch {")
            && sig_contains(&src, "inner: regex::Match<'static>,")
            && sig_contains(&src, "_input: std::sync::Arc<String>,"),
        "missing OwnedMatch ouroboros struct\n{src}"
    );
    // The non-pub wrap ctor clones the input into an Arc, produces from it, erases
    // the borrow. The Arc lets a nested wrapper share this exact buffer.
    assert!(
        sig_contains(&src, "fn wrap(owner: &regex::Regex, input: &str) -> Option<OwnedMatch>")
            && sig_contains(&src, "let owned = std::sync::Arc::new(input.to_owned());")
            && sig_contains(&src, "let inner = owner.find(owned.as_str())?;")
            && sig_contains(&src, "let inner: regex::Match<'static> = unsafe { std::mem::transmute(inner) };"),
        "missing/incorrect wrap ctor\n{src}"
    );
    // The producer on Regex returns the wrapper.
    assert!(
        sig_contains(&src, "pub fn find(&self, haystack: &str) -> Option<OwnedMatch>")
            && sig_contains(&src, "OwnedMatch::wrap(&self.0, haystack)"),
        "missing find producer\n{src}"
    );
    // Readers delegate through self.inner (the erased borrowing value).
    assert!(
        sig_contains(&src, "pub fn as_str(&self) -> String") && sig_contains(&src, "self.inner.as_str().to_string()"),
        "missing OwnedMatch::as_str reader\n{src}"
    );
    assert!(
        sig_contains(&src, "pub fn is_empty(&self) -> bool") && sig_contains(&src, "self.inner.is_empty()"),
        "missing OwnedMatch::is_empty reader\n{src}"
    );
}

#[test]
fn owned_captures_nested_producer_emitted() {
    let src = generated();
    // The OwnedCaptures wrapper struct (Arc-shared input) and its root wrap ctor.
    assert!(
        sig_contains(&src, "pub struct OwnedCaptures {")
            && sig_contains(&src, "inner: regex::Captures<'static>,")
            && sig_contains(&src, "_input: std::sync::Arc<String>,"),
        "missing OwnedCaptures struct\n{src}"
    );
    assert!(
        sig_contains(&src, "fn wrap(owner: &regex::Regex, input: &str) -> Option<OwnedCaptures>")
            && sig_contains(&src, "let inner = owner.captures(owned.as_str())?;"),
        "missing OwnedCaptures root wrap ctor\n{src}"
    );
    // Regex::captures is now a root producer of the wrapper.
    assert!(
        sig_contains(&src, "pub fn captures(&self, haystack: &str) -> Option<OwnedCaptures>")
            && sig_contains(&src, "OwnedCaptures::wrap(&self.0, haystack)"),
        "missing captures producer\n{src}"
    );
    // The NESTED producer: OwnedCaptures::name builds an OwnedMatch inline from the
    // parent's borrowing value, sharing the owned buffer via an Arc clone — no
    // transmute, no re-allocation.
    assert!(
        sig_contains(&src, "pub fn name(&self, name: &str) -> Option<OwnedMatch>")
            && sig_contains(&src, "let inner = self.inner.name(name)?;")
            && sig_contains(&src,
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
        sig_contains(&src, "pub struct OwnedMatches {")
            && sig_contains(&src, "iter: regex::Matches<'static, 'static>,")
            && sig_contains(&src, "_owner: std::sync::Arc<regex::Regex>,")
            && sig_contains(&src, "_input: std::sync::Arc<String>,"),
        "missing OwnedMatches cursor struct\n{src}"
    );
    // Its wrap clones the regex + haystack into Arcs and transmutes the iterator;
    // returns the wrapper directly (a cursor is always constructed, no Option).
    assert!(
        sig_contains(&src, "fn wrap(owner: &regex::Regex, input: &str) -> OwnedMatches {")
            && sig_contains(&src, "let owner = std::sync::Arc::new(owner.clone());")
            && sig_contains(&src, "unsafe { std::mem::transmute(owner.find_iter(owned.as_str())) };"),
        "missing/incorrect OwnedMatches::wrap\n{src}"
    );
    // The pull method: &mut self, pulls one item, shares the input Arc.
    assert!(
        sig_contains(&src, "pub fn next(&mut self) -> Option<OwnedMatch> {")
            && sig_contains(&src, "let inner = self.iter.next()?;"),
        "missing OwnedMatches::next pull\n{src}"
    );
    // The producer on Regex returns the cursor directly.
    assert!(
        sig_contains(&src, "pub fn find_iter(&self, haystack: &str) -> OwnedMatches {")
            && sig_contains(&src, "OwnedMatches::wrap(&self.0, haystack)"),
        "missing find_iter producer\n{src}"
    );

    // captures_iter is a cursor too, whose item wrapper OwnedCaptures is the SAME
    // type `captures` produces — merged, so OwnedCaptures keeps its root wrap ctor.
    assert!(
        sig_contains(&src, "pub struct OwnedCaptureMatches {")
            && sig_contains(&src, "pub fn next(&mut self) -> Option<OwnedCaptures> {"),
        "missing OwnedCaptureMatches cursor\n{src}"
    );
    assert_eq!(
        sig_count(&src, "pub struct OwnedCaptures {"),
        1,
        "OwnedCaptures must be emitted exactly once (merged)\n{src}"
    );

    // DRAIN struct: owns only a Vec<String>, drained via pop().
    assert!(
        sig_contains(&src, "pub struct OwnedSplit {") && sig_contains(&src, "items: Vec<String>,"),
        "missing OwnedSplit drain struct\n{src}"
    );
    assert!(
        sig_contains(&src, "fn wrap(owner: &regex::Regex, input: &str) -> OwnedSplit {")
            && sig_contains(&src, "owner.split(input).map(|s| s.to_owned()).collect();")
            && sig_contains(&src, "items.reverse();"),
        "missing/incorrect OwnedSplit::wrap collect\n{src}"
    );
    assert!(
        sig_contains(&src, "pub fn next(&mut self) -> Option<String> {")
            && sig_contains(&src, "self.items.pop()"),
        "missing OwnedSplit::next drain\n{src}"
    );
    assert!(
        sig_contains(&src, "pub fn split(&self, haystack: &str) -> OwnedSplit {"),
        "missing split producer\n{src}"
    );
}

#[test]
fn replace_all_callback_emitted() {
    let src = generated();

    // The callback method: haystack + a JacCallback, returning a fallible String.
    assert!(
        sig_contains(&src,
            "pub fn replace_all(&self, haystack: &str, rep: JacCallback) -> Result<String, String>"
        ),
        "missing replace_all callback signature\n{src}"
    );
    // The replacer closure walks the crate's Captures, feeds each match's text to
    // the callback, and splices in the returned replacement.
    assert!(
        sig_contains(&src, "self.0.replace_all(haystack, |caps: &regex::Captures| {")
            && sig_contains(&src, "let m = caps.get(0).map_or(\"\", |x| x.as_str());")
            && sig_contains(&src, "match rep.call(m) {"),
        "missing/incorrect replacer closure body\n{src}"
    );
    // The first callback error is captured and surfaced as the method's Err.
    assert!(
        sig_contains(&src, "if err.borrow().is_none() { *err.borrow_mut() = Some(e); }")
            && sig_contains(&src, "match err.into_inner() { Some(e) => Err(e), None => Ok(out) }"),
        "missing callback-error propagation\n{src}"
    );
}

// ── Cargo.toml emitter ───────────────────────────────────────────────────────

#[test]
fn cargo_toml_correct_shape() {
    let doc = load_regex_doc();
    let spec = classify(&doc);
    let toml = emit_cargo_toml(&spec, "../jac-bridge");

    assert!(sig_contains(&toml, "name = \"jac-bridge-regex\""), "wrong crate name\n{}", toml);
    assert!(sig_contains(&toml, "crate-type = [\"cdylib\", \"rlib\"]"), "missing cdylib\n{}", toml);
    // Pinned exact version so generated crates are reproducible.
    assert!(
        sig_contains(&toml, "regex = \"=1.12.4\""),
        "missing exact-version pin for regex\n{}",
        toml
    );
    assert!(
        sig_contains(&toml, "jac-bridge = { path = \"../jac-bridge\" }"),
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
            !sig_contains(&src, &format!("pub struct {}(", name)),
            "cursor type {} leaked into codegen output\n{}",
            name,
            src
        );
    }
}
