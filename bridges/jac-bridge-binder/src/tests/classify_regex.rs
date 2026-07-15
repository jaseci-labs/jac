//! Acceptance test: classify regex 1.12.4's public API.
//!
//! The expected items mirror what `jac-bridge-regex-v2` exposes manually.
//! This test is the north-star for binder correctness: if it passes, the
//! classify pass understands the regex crate well enough to generate a
//! correct `#[bridge(...)]` input.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{
    classify,
    types::{BridgeReturn, DrainCollect, Recv, ScalarType, TypeKind, WrapperKind},
};

fn load_regex_doc() -> Crate {
    // The JSON is generated during `cargo +nightly rustdoc` on regex 1.12.4.
    // In CI this would be a fixture; locally we use the cargo registry copy.
    let candidates = [
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/regex-1.12.4.json"),
        PathBuf::from(env!("HOME"))
            .join(".cargo/registry/src/index.crates.io-1949cf8c6b5b557f/regex-1.12.4/target/doc/regex.json"),
    ];
    for p in &candidates {
        if p.exists() {
            let data = std::fs::read_to_string(p).expect("read rustdoc json");
            return serde_json::from_str(&data).expect("parse rustdoc json");
        }
    }
    panic!("regex rustdoc JSON not found — run: cargo +nightly rustdoc -Z unstable-options --output-format json --manifest-path ~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/regex-1.12.4/Cargo.toml");
}

#[test]
fn module_name_and_version() {
    let doc = load_regex_doc();
    let spec = classify(&doc);
    assert_eq!(spec.module_name, "regex");
    assert_eq!(spec.crate_version, "1.12.4");
}

#[test]
fn regex_is_opaque_with_ctor_and_is_match() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    let regex_type = spec
        .types
        .iter()
        .find(|t| t.name == "Regex")
        .expect("Regex type");
    assert_eq!(regex_type.kind, TypeKind::Opaque);

    // Constructor: new(&str) -> Result<Regex, Error>
    let ctor = regex_type.ctor.as_ref().expect("Regex::new ctor");
    assert_eq!(ctor.name, "new");
    assert_eq!(ctor.params.len(), 1);
    assert_eq!(ctor.params[0].ty, ScalarType::Str);
    assert_eq!(ctor.ret, BridgeReturn::OwnSelfResult);

    // Method: is_match(&self, &str) -> bool
    let is_match = regex_type
        .methods
        .iter()
        .find(|m| m.name == "is_match")
        .expect("is_match");
    assert_eq!(is_match.params.len(), 1);
    assert_eq!(is_match.params[0].ty, ScalarType::Str);
    assert_eq!(is_match.ret, BridgeReturn::Bool);
}

#[test]
fn error_type_classified() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    let err_type = spec
        .types
        .iter()
        .find(|t| t.name == "Error")
        .expect("Error type");
    assert_eq!(err_type.kind, TypeKind::Error);
}

#[test]
fn no_duplicate_types() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    let mut names: Vec<&str> = spec.types.iter().map(|t| t.name.as_str()).collect();
    names.sort_unstable();
    let deduped: Vec<&str> = {
        let mut d = names.clone();
        d.dedup();
        d
    };
    assert_eq!(names, deduped, "duplicate types in classify output");
}

#[test]
fn captures_rescued_by_nested_wrapper() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    // Regex::captures becomes a producer of the OwnedCaptures wrapper.
    let regex_type = spec
        .types
        .iter()
        .find(|t| t.name == "Regex")
        .expect("Regex type");
    let captures = regex_type
        .methods
        .iter()
        .find(|m| m.name == "captures")
        .expect("captures producer");
    assert_eq!(
        captures.ret,
        BridgeReturn::OptWrapper("OwnedCaptures".into())
    );
    assert_eq!(captures.recv, Recv::Field0); // root producer on the plain owner

    // OwnedCaptures exists and its `name` reader is a NESTED producer of OwnedMatch,
    // delegating through self.inner (recv Inner), not a lifetime-borrow skip.
    let oc = spec
        .types
        .iter()
        .find(|t| t.name == "OwnedCaptures")
        .expect("OwnedCaptures type");
    let name = oc
        .methods
        .iter()
        .find(|m| m.name == "name")
        .expect("name nested producer");
    assert_eq!(name.ret, BridgeReturn::OptWrapper("OwnedMatch".into()));
    assert_eq!(name.recv, Recv::Inner);
    assert_eq!(name.params.len(), 1);
    assert_eq!(name.params[0].ty, ScalarType::Str);

    // OwnedCaptures is a nested-only wrapper OF an owner (Regex::captures gives it a
    // root path), so its wrapper metadata carries a root producer via `captures`.
    let ocw = oc.wrapper.as_ref().expect("OwnedCaptures wrapper metadata");
    assert_eq!(ocw.borrowed_path, "regex::Captures");
    let ocroot = ocw
        .root
        .as_ref()
        .expect("OwnedCaptures root producer (captures)");
    assert_eq!(ocroot.producer_call, "captures");

    // The single shared OwnedMatch keeps its root `wrap` ctor (from find) even
    // though it is ALSO produced nested — the two requests merged.
    let om_count = spec.types.iter().filter(|t| t.name == "OwnedMatch").count();
    assert_eq!(
        om_count, 1,
        "OwnedMatch must be emitted exactly once (merged)"
    );
    let om = spec.types.iter().find(|t| t.name == "OwnedMatch").unwrap();
    assert!(
        om.wrapper.as_ref().and_then(|w| w.root.as_ref()).is_some(),
        "merged OwnedMatch must retain its root wrap ctor from find"
    );
}

#[test]
fn iterators_rescued_as_cursors_and_drains() {
    let doc = load_regex_doc();
    let spec = classify(&doc);
    let regex_type = spec
        .types
        .iter()
        .find(|t| t.name == "Regex")
        .expect("Regex type");

    // Regex::find_iter -> Matches<'r,'h> (Item = Match) becomes a CURSOR producer:
    // a non-nullable OwnedMatches whose next() pulls OwnedMatch.
    let find_iter = regex_type
        .methods
        .iter()
        .find(|m| m.name == "find_iter")
        .expect("find_iter producer");
    assert_eq!(find_iter.ret, BridgeReturn::Wrapper("OwnedMatches".into()));
    let om = spec
        .types
        .iter()
        .find(|t| t.name == "OwnedMatches")
        .expect("OwnedMatches cursor");
    let ocw = om.wrapper.as_ref().expect("cursor wrapper metadata");
    assert_eq!(
        ocw.kind,
        WrapperKind::Cursor {
            item_wrapper: "OwnedMatch".into()
        }
    );
    let next = om
        .methods
        .iter()
        .find(|m| m.name == "next")
        .expect("OwnedMatches::next");
    assert_eq!(next.ret, BridgeReturn::OptWrapper("OwnedMatch".into()));
    assert_eq!(next.recv, Recv::IterNext);
    assert!(next.params.is_empty());

    // Regex::captures_iter -> CaptureMatches (Item = Captures) is ALSO a cursor; its
    // item wrapper is OwnedCaptures, which MERGES with the one `captures` produces.
    let ci = regex_type
        .methods
        .iter()
        .find(|m| m.name == "captures_iter")
        .expect("captures_iter");
    assert_eq!(ci.ret, BridgeReturn::Wrapper("OwnedCaptureMatches".into()));
    let ocm = spec
        .types
        .iter()
        .find(|t| t.name == "OwnedCaptureMatches")
        .expect("cursor type");
    assert_eq!(
        ocm.wrapper.as_ref().unwrap().kind,
        WrapperKind::Cursor {
            item_wrapper: "OwnedCaptures".into()
        }
    );
    let occ = spec
        .types
        .iter()
        .filter(|t| t.name == "OwnedCaptures")
        .count();
    assert_eq!(
        occ, 1,
        "OwnedCaptures emitted once (captures + captures_iter merged)"
    );

    // Regex::split -> Split (Item = &str) becomes a DRAIN: OwnedSplit.next -> Option<String>.
    let split = regex_type
        .methods
        .iter()
        .find(|m| m.name == "split")
        .expect("split producer");
    assert_eq!(split.ret, BridgeReturn::Wrapper("OwnedSplit".into()));
    let os = spec
        .types
        .iter()
        .find(|t| t.name == "OwnedSplit")
        .expect("OwnedSplit drain");
    assert!(matches!(
        os.wrapper.as_ref().unwrap().kind,
        WrapperKind::Drain { .. }
    ));
    let dnext = os
        .methods
        .iter()
        .find(|m| m.name == "next")
        .expect("OwnedSplit::next");
    assert_eq!(dnext.ret, BridgeReturn::OptStr);
    assert_eq!(dnext.recv, Recv::DrainNext);

    // None of the three are skips any more.
    for item in ["Regex::find_iter", "Regex::captures_iter", "Regex::split"] {
        assert!(
            spec.skips.iter().all(|s| s.item != item),
            "{item} should be rescued"
        );
    }

    // Honest limits still hold: an iterator with NO &str input to own can't be a
    // cursor under this rule (Captures::iter iterates an already-owned Captures).
    assert!(
        spec.skips.iter().any(|s| s.item == "Captures::iter"),
        "Captures::iter (no &str param) should remain a recorded skip"
    );
    // RegexSet::matches -> SetMatches is NOT an iterator, so it is not a cursor —
    // but since 1.2.5 admitted `SetMatches` (a single-field private tuple struct)
    // as an opaque handle, the return crosses as a cross-type owned handle (the
    // 1.2.4 ref lane) instead of a skip. It is a proper bridge, not a silent drop.
    let matches = regex_type_matches(&spec);
    assert_eq!(
        matches.ret,
        BridgeReturn::Ref("SetMatches".into()),
        "RegexSet::matches returns the SetMatches handle"
    );
}

/// The `RegexSet::matches` method, for the cross-type-handle assertion above.
fn regex_type_matches(spec: &crate::types::BridgeSpec) -> &crate::types::BridgeFn {
    spec.types
        .iter()
        .find(|t| t.name == "RegexSet")
        .expect("RegexSet bridged")
        .methods
        .iter()
        .find(|m| m.name == "matches")
        .expect("RegexSet::matches bridged")
}

#[test]
fn regexset_patterns_rescued_as_slice_drain() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    // RegexSet::patterns(&self) -> &[String] can't cross as a borrowed slice, but
    // its elements are owned Strings — so it becomes a Vec-drain producer of a
    // synthesized OwnedPatterns, named after the method (there's no iterator
    // struct to borrow a name from). No longer a skip.
    assert!(
        spec.skips.iter().all(|s| s.item != "RegexSet::patterns"),
        "RegexSet::patterns should be rescued as a drain, not skipped"
    );
    let rs = spec
        .types
        .iter()
        .find(|t| t.name == "RegexSet")
        .expect("RegexSet type");
    let patterns = rs
        .methods
        .iter()
        .find(|m| m.name == "patterns")
        .expect("patterns producer");
    assert_eq!(patterns.ret, BridgeReturn::Wrapper("OwnedPatterns".into()));
    assert!(
        patterns.params.is_empty(),
        "patterns takes no non-self params"
    );
    assert_eq!(patterns.recv, Recv::Field0);

    // OwnedPatterns is a Drain whose collect strategy is `&[String] -> to_vec()`,
    // with zero forwarded params and a single `next -> Option<String>` reader.
    let op = spec
        .types
        .iter()
        .find(|t| t.name == "OwnedPatterns")
        .expect("OwnedPatterns drain");
    let w = op.wrapper.as_ref().expect("OwnedPatterns wrapper metadata");
    assert_eq!(
        w.kind,
        WrapperKind::Drain {
            params: vec![],
            collect: DrainCollect::SliceString
        }
    );
    let next = op
        .methods
        .iter()
        .find(|m| m.name == "next")
        .expect("OwnedPatterns::next");
    assert_eq!(next.ret, BridgeReturn::OptStr);
    assert_eq!(next.recv, Recv::DrainNext);
    assert!(next.params.is_empty());
}

#[test]
fn find_is_rescued_by_owning_wrapper() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    // Regex::find (returns Option<Match<'h>>) is no longer a skip — it becomes a
    // producer method whose return is the synthesized OwnedMatch wrapper.
    assert!(
        spec.skips.iter().all(|s| s.item != "Regex::find"),
        "Regex::find should be rescued, not skipped"
    );
    let regex_type = spec
        .types
        .iter()
        .find(|t| t.name == "Regex")
        .expect("Regex type");
    let find = regex_type
        .methods
        .iter()
        .find(|m| m.name == "find")
        .expect("find producer");
    assert_eq!(find.ret, BridgeReturn::OptWrapper("OwnedMatch".into()));
    assert_eq!(find.params.len(), 1);
    assert_eq!(find.params[0].ty, ScalarType::Str);

    // The OwnedMatch wrapper exists, is opaque, and carries the ouroboros metadata.
    let owned = spec
        .types
        .iter()
        .find(|t| t.name == "OwnedMatch")
        .expect("OwnedMatch type");
    assert_eq!(owned.kind, TypeKind::Opaque);
    let w = owned.wrapper.as_ref().expect("wrapper metadata");
    assert_eq!(w.borrowed_path, "regex::Match");
    assert_eq!(w.lifetimes, 1);
    // OwnedMatch has a root construction path (via Regex::find) — it is also
    // produced nested (from OwnedCaptures::name), and the two requests merge so
    // the root `wrap` ctor survives.
    let root = w
        .root
        .as_ref()
        .expect("OwnedMatch has a root producer (find)");
    assert_eq!(root.owner_inner_path, "regex::Regex");
    assert_eq!(root.producer_call, "find");

    // Its readers are Match's bridgeable methods, delegating through self.inner.
    // The integer readers (start/end/len -> usize) now cross as TAG_UINT.
    let mut reader_names: Vec<&str> = owned.methods.iter().map(|m| m.name.as_str()).collect();
    reader_names.sort_unstable();
    assert_eq!(
        reader_names,
        vec!["as_str", "end", "is_empty", "len", "start"]
    );
    assert!(owned.methods.iter().all(|m| m.recv == Recv::Inner));
    let as_str = owned.methods.iter().find(|m| m.name == "as_str").unwrap();
    assert_eq!(as_str.ret, BridgeReturn::Str); // &'h str, copied to owned String
    let is_empty = owned.methods.iter().find(|m| m.name == "is_empty").unwrap();
    assert_eq!(is_empty.ret, BridgeReturn::Bool);
    let start = owned.methods.iter().find(|m| m.name == "start").unwrap();
    assert_eq!(start.ret, BridgeReturn::Uint("usize".into()));

    // `range` returns `Range<usize>` — not a carryable scalar/container, so it
    // stays an honestly-recorded skip.
    assert!(
        spec.skips.iter().any(|s| s.item == "Match::range"),
        "Match::range should be a recorded skip"
    );
}

#[test]
fn replace_all_rescued_as_callback() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    // replace_all(&self, &'h str, R: Replacer) -> Cow<'h, str> is the CALLBACK
    // vertical: rescued into a method taking a JacCallback (Rust calls back into
    // Jac once per match).  No longer a skip.
    assert!(
        !spec.skips.iter().any(|s| s.item == "Regex::replace_all"),
        "Regex::replace_all should be rescued as a callback, not skipped"
    );
    let regex = spec
        .types
        .iter()
        .find(|t| t.name == "Regex")
        .expect("Regex type");
    let ra = regex
        .methods
        .iter()
        .find(|m| m.name == "replace_all")
        .expect("replace_all method emitted");
    // Params: the haystack (&str) then the Replacer generic as a JacCallback.
    assert_eq!(ra.params.len(), 2, "replace_all takes haystack + callback");
    assert_eq!(ra.params[0].ty, ScalarType::Str);
    assert_eq!(ra.params[1].ty, ScalarType::Callback);
    assert!(
        matches!(&ra.ret, BridgeReturn::ReplacerResult(p) if p == "regex::Captures"),
        "replace_all returns a ReplacerResult over regex::Captures, got {:?}",
        ra.ret
    );

    // `replacen` (an extra usize `limit` param) is NOT a callback shape — it stays
    // an honest skip, proving the rule is specific, not a blanket generic-rescue.
    assert!(
        spec.skips.iter().any(|s| s.item == "Regex::replacen"),
        "Regex::replacen should remain a skip (extra usize param)"
    );
}

#[test]
fn types_are_ordered_opaque_then_error() {
    let doc = load_regex_doc();
    let spec = classify(&doc);

    let mut saw_error = false;
    for t in &spec.types {
        if t.kind == TypeKind::Error {
            saw_error = true;
        }
        if saw_error {
            assert_eq!(t.kind, TypeKind::Error, "opaque type after error type");
        }
    }
}
