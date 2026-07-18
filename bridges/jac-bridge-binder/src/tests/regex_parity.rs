//! Full-parity lanes for the regex fixture (the 39 -> 77 lift):
//!
//!   * BUILDER CHAIN: `(&mut self, v) -> &mut Self` setters classify as
//!     `SelfRef` and emit `-> &Self` bodies returning the receiver, riding the
//!     macro's self-identity arm (loader RC-pins via the `rh == self` guard).
//!   * CROSS-TYPE FALLIBLE PRODUCER: `build -> Result<Regex, Error>` classifies
//!     as `RefResult("Regex")` and emits `-> Result<Regex, String>`.
//!   * OPTION<INT>: `shortest_match -> Option<usize>` classifies as
//!     `OptUintValue` (null-JacBuf None channel, no sentinel).
//!   * ITERATOR-OF-STRINGS PARAM: `I: IntoIterator<Item = S>, S: AsRef<str>`
//!     monomorphizes to `Wide<Vec<String>>` on the existing msgpack lane.
//!   * MULTI-PARAM WRAPPER SHAPES: `splitn` (drain with a forwarded `limit`),
//!     `find_at`/`captures_at` (inline owning producers), `Captures::get_match`
//!     (plain non-`Option` nested producer), `SetMatches::iter` (int collect).

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::types::{BridgeReturn, ScalarType, WrapperKind};
use crate::{classify, emit};

fn load_regex_doc() -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/regex-1.12.4.json");
    let data = std::fs::read_to_string(&p).expect("read regex fixture");
    serde_json::from_str(&data).expect("parse regex fixture")
}

fn find_method<'s>(
    spec: &'s crate::types::BridgeSpec,
    ty: &str,
    m: &str,
) -> &'s crate::types::BridgeFn {
    spec.types
        .iter()
        .find(|t| t.name == ty)
        .unwrap_or_else(|| panic!("{ty} bridged"))
        .methods
        .iter()
        .find(|f| f.name == m)
        .unwrap_or_else(|| panic!("{ty}::{m} bridged"))
}

#[test]
fn builder_setters_classify_as_self_ref_chain() {
    let spec = classify(&load_regex_doc());
    for ty in ["RegexBuilder", "RegexSetBuilder"] {
        for setter in ["case_insensitive", "multi_line", "size_limit", "nest_limit"] {
            let f = find_method(&spec, ty, setter);
            assert_eq!(f.ret, BridgeReturn::SelfRef, "{ty}::{setter} is a chain");
            assert!(f.self_mut, "{ty}::{setter} takes &mut self");
        }
    }
    // All 11 setters per builder bridge; none is left a lifetime-borrow skip.
    assert!(
        !spec
            .skips
            .iter()
            .any(|s| s.item.starts_with("RegexBuilder::") || s.item.starts_with("RegexSetBuilder::")),
        "no builder method may remain a skip"
    );
}

#[test]
fn self_ref_emits_identity_body() {
    let spec = classify(&load_regex_doc());
    let src = emit(&spec);
    let block = &src[src.find("impl RegexBuilder {").expect("impl RegexBuilder")..];
    let sig = &block[block.find("pub fn case_insensitive").expect("setter emitted")..];
    let head = &sig[..sig.find("\n        }").unwrap_or(sig.len())];
    assert!(
        head.starts_with("pub fn case_insensitive(&mut self, yes: bool) -> &Self"),
        "setter signature must be `-> &Self`:\n{head}"
    );
    assert!(
        head.contains("let _ = self.0.case_insensitive(yes);") && head.contains("self"),
        "setter body runs the call and returns the receiver:\n{head}"
    );
}

#[test]
fn build_classifies_as_cross_type_fallible_producer() {
    let spec = classify(&load_regex_doc());
    let b = find_method(&spec, "RegexBuilder", "build");
    assert_eq!(b.ret, BridgeReturn::RefResult("Regex".into()));
    let sb = find_method(&spec, "RegexSetBuilder", "build");
    assert_eq!(sb.ret, BridgeReturn::RefResult("RegexSet".into()));

    let src = emit(&spec);
    assert!(
        src.contains("pub fn build(&self) -> Result<Regex, String> {"),
        "build must emit Result<Regex, String>\n{src}"
    );
    assert!(
        src.contains(".map(Regex).map_err(|e| e.to_string())"),
        "build maps the ok value into the target newtype\n{src}"
    );
}

#[test]
fn option_int_returns_classify_and_emit() {
    let spec = classify(&load_regex_doc());
    for m in ["shortest_match", "shortest_match_at", "static_captures_len"] {
        let f = find_method(&spec, "Regex", m);
        assert_eq!(
            f.ret,
            BridgeReturn::OptUintValue("usize".into()),
            "Regex::{m} rides the Option<usize> lane"
        );
    }
    let src = emit(&spec);
    assert!(
        src.contains("pub fn static_captures_len(&self) -> Option<usize> {"),
        "Option<usize> forwarded verbatim\n{src}"
    );
}

#[test]
fn strings_iterator_param_monomorphizes_to_wide_vec_string() {
    let spec = classify(&load_regex_doc());
    // RegexSetBuilder::new is THE ctor (its only `-> Self` factory).
    let ctor = spec
        .types
        .iter()
        .find(|t| t.name == "RegexSetBuilder")
        .unwrap()
        .ctor
        .as_ref()
        .expect("RegexSetBuilder ctor");
    assert_eq!(ctor.name, "new");
    assert_eq!(ctor.params[0].ty, ScalarType::Wide("Vec<String>".into()));
    // RegexSet::new lost the ctor race to `empty` and is a STATIC with the same
    // monomorphized param.
    let new = find_method(&spec, "RegexSet", "new");
    assert!(new.is_static, "RegexSet::new is a FN_STATIC factory");
    assert_eq!(new.params[0].ty, ScalarType::Wide("Vec<String>".into()));
    assert_eq!(new.ret, BridgeReturn::OwnSelfResult);
}

#[test]
fn splitn_is_a_drain_with_forwarded_limit() {
    let spec = classify(&load_regex_doc());
    let f = find_method(&spec, "Regex", "splitn");
    assert_eq!(f.ret, BridgeReturn::Wrapper("OwnedSplitN".into()));
    let w = spec
        .types
        .iter()
        .find(|t| t.name == "OwnedSplitN")
        .expect("OwnedSplitN synthesized");
    let wk = &w.wrapper.as_ref().expect("wrapper meta").kind;
    match wk {
        WrapperKind::Drain { params, .. } => {
            assert_eq!(params.len(), 2, "haystack + limit forwarded");
            assert_eq!(params[1].ty, ScalarType::Uint("usize".into()));
        }
        other => panic!("splitn must synthesize a drain, got {other:?}"),
    }
}

#[test]
fn find_at_is_an_inline_owning_producer() {
    let spec = classify(&load_regex_doc());
    let f = find_method(&spec, "Regex", "find_at");
    assert!(
        matches!(
            &f.ret,
            BridgeReturn::OptWrapperInline { wrapper, .. } if wrapper == "OwnedMatch"
        ),
        "find_at builds OwnedMatch inline, got {:?}",
        f.ret
    );
    let c = find_method(&spec, "Regex", "captures_at");
    assert!(
        matches!(
            &c.ret,
            BridgeReturn::OptWrapperInline { wrapper, .. } if wrapper == "OwnedCaptures"
        ),
        "captures_at builds OwnedCaptures inline, got {:?}",
        c.ret
    );
    // The inline body owns the first param and forwards the rest.
    let src = emit(&spec);
    assert!(
        src.contains("self.0.find_at(owned.as_str(), start)?"),
        "inline producer forwards extra params\n{src}"
    );
}

#[test]
fn get_match_is_a_plain_nested_producer() {
    let spec = classify(&load_regex_doc());
    let f = find_method(&spec, "OwnedCaptures", "get_match");
    assert_eq!(
        f.ret,
        BridgeReturn::Wrapper("OwnedMatch".into()),
        "get_match (group 0 always present) is non-nullable"
    );
    let src = emit(&spec);
    assert!(
        src.contains("let inner = self.inner.get_match();"),
        "plain nested body builds the child inline\n{src}"
    );
}

#[test]
fn set_matches_iter_collects_ints() {
    let spec = classify(&load_regex_doc());
    let f = find_method(&spec, "SetMatches", "iter");
    assert_eq!(f.ret, BridgeReturn::CollectList("Vec<usize>".into()));
    let src = emit(&spec);
    assert!(
        src.contains("pub fn iter(&self) -> Vec<usize> {")
            && src.contains("self.0.iter().collect()"),
        "iter collects into the list-return lane\n{src}"
    );
}
