//! Full-parity synth lanes proven on the real semver fixture:
//!   * Display lane   — `impl Display`  -> `to_string(&self) -> String`
//!   * Ord lane       — `impl Ord`      -> `cmp(&self, &Self) -> i8` (Ordering)
//!   * FromStr lane    — `impl FromStr`  -> `from_str(text) -> Result<Self, String>`
//!                      static, called `<T as ::std::str::FromStr>::from_str`
//!   * field-reader lane — public fields -> scalar / handle / enum-name readers
//!
//! These replace the hand-written `major`/`minor`/`patch`/`cmp` overlay `inject`;
//! the overlay now carries only `treat_as = "opaque"` on the three public-field
//! structs. The remaining skips (`Option<u64>` fields, `Vec<Comparator>`, generic
//! `from_iter`) are honest ABI limits, asserted here so they can't silently change.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::types::{BridgeReturn, BridgeSpec, ScalarType};
use crate::{apply_overlay, classify_with_overlay, emit, parse_overlay};

fn load(name: &str) -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(format!("{name}.json"));
    let data = std::fs::read_to_string(&p).unwrap_or_else(|_| panic!("read {name} fixture"));
    serde_json::from_str(&data).unwrap_or_else(|_| panic!("parse {name} fixture"))
}

/// Classify semver WITH its overlay (`treat_as = "opaque"` on the three public-field
/// structs), mirroring the CLI's two-step flow.
fn semver_spec() -> BridgeSpec {
    let doc = load("semver-1.0.27");
    let overlay_src = std::fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/semver.overlay.toml"),
    )
    .expect("read semver overlay");
    let overlay = parse_overlay(&overlay_src).expect("parse semver overlay");
    let mut spec = classify_with_overlay(&doc, Some(&overlay));
    apply_overlay(&mut spec, &overlay).expect("apply semver overlay");
    spec
}

fn method<'a>(spec: &'a BridgeSpec, ty: &str, m: &str) -> &'a crate::types::BridgeFn {
    spec.types
        .iter()
        .find(|t| t.name == ty)
        .unwrap_or_else(|| panic!("type {ty}"))
        .methods
        .iter()
        .find(|f| f.name == m)
        .unwrap_or_else(|| panic!("{ty}::{m} must be bridged"))
}

#[test]
fn display_lane_synthesizes_to_string() {
    let spec = semver_spec();
    // Every opaque semver type is Display -> a `to_string` reader.
    for ty in [
        "Version",
        "VersionReq",
        "Comparator",
        "Prerelease",
        "BuildMetadata",
    ] {
        let f = method(&spec, ty, "to_string");
        assert_eq!(f.ret, BridgeReturn::DisplayString, "{ty}::to_string lane");
        assert!(f.field_read.is_none() && !f.is_static);
    }
    let src = emit(&spec);
    assert!(
        src.contains("pub fn to_string(&self) -> String {\n            self.0.to_string()"),
        "to_string body must forward a single self.0.to_string()\n{src}"
    );
}

#[test]
fn ord_lane_synthesizes_cmp_with_handle_param() {
    let spec = semver_spec();
    // Version/Prerelease/BuildMetadata impl Ord; Comparator/VersionReq do NOT.
    for ty in ["Version", "Prerelease", "BuildMetadata"] {
        let f = method(&spec, ty, "cmp");
        assert_eq!(
            f.ret,
            BridgeReturn::Ordering,
            "{ty}::cmp rides the Ordering lane"
        );
        assert_eq!(
            f.params,
            vec![crate::types::BridgeParam {
                name: "other".into(),
                ty: ScalarType::Handle(ty.to_string()),
            }],
            "{ty}::cmp takes an inbound &Self handle"
        );
    }
    for ty in ["Comparator", "VersionReq"] {
        assert!(
            !spec
                .types
                .iter()
                .find(|t| t.name == ty)
                .unwrap()
                .methods
                .iter()
                .any(|m| m.name == "cmp"),
            "{ty} has no Ord impl, so no synthesized cmp"
        );
    }
    let src = emit(&spec);
    assert!(
        src.contains("pub fn cmp(&self, other: &Version) -> i8"),
        "cmp must expose the &Version handle param and an i8 return\n{src}"
    );
}

#[test]
fn from_str_lane_admitted_as_fully_qualified_static() {
    let spec = semver_spec();
    for ty in [
        "Version",
        "VersionReq",
        "Comparator",
        "Prerelease",
        "BuildMetadata",
    ] {
        let f = method(&spec, ty, "from_str");
        assert!(
            f.is_static && f.std_from_str && f.via_trait.is_none(),
            "{ty}::from_str is a std-FromStr static"
        );
        assert_eq!(
            f.ret,
            BridgeReturn::OwnSelfResult,
            "{ty}::from_str is fallible"
        );
    }
    // No from_str skips survive, and the emitted call is fully-qualified.
    assert!(
        !spec.skips.iter().any(|s| s.item.ends_with("::from_str")),
        "no from_str skip should remain"
    );
    let src = emit(&spec);
    assert!(
        src.contains("<semver::Version as ::std::str::FromStr>::from_str(text)"),
        "from_str body must call the trait's associated fn fully-qualified\n{src}"
    );
    assert!(
        !src.contains("use semver::core::") && !src.contains("use semver::std::"),
        "no unresolvable std-trait `use` may leak\n{src}"
    );
}

#[test]
fn field_reader_lane_scalar_handle_and_enum() {
    let spec = semver_spec();

    // Scalar field readers (u64) — no `.clone()`, a plain Uint return.
    for m in ["major", "minor", "patch"] {
        let f = method(&spec, "Version", m);
        assert_eq!(
            f.ret,
            BridgeReturn::Uint("u64".into()),
            "Version::{m} is u64"
        );
        assert_eq!(f.field_read.as_deref(), Some(m));
    }

    // Option<u64> field readers ride the Option<int> lane (Comparator.minor/.patch).
    for m in ["minor", "patch"] {
        let f = method(&spec, "Comparator", m);
        assert_eq!(
            f.ret,
            BridgeReturn::OptUintValue("u64".into()),
            "Comparator::{m} rides the Option<int> lane"
        );
        assert_eq!(f.field_read.as_deref(), Some(m));
    }

    // Handle field readers — an owned-clone producer of another bridged handle.
    let pre = method(&spec, "Version", "pre");
    assert_eq!(pre.ret, BridgeReturn::Ref("Prerelease".into()));
    let build = method(&spec, "Version", "build");
    assert_eq!(build.ret, BridgeReturn::Ref("BuildMetadata".into()));

    // Vec-of-handle field reader (`VersionReq.comparators: Vec<Comparator>`).
    let comps = method(&spec, "VersionReq", "comparators");
    assert_eq!(
        comps.ret,
        BridgeReturn::HandleList("Comparator".into()),
        "VersionReq::comparators rides the Vec-of-handle lane"
    );
    assert_eq!(comps.field_read.as_deref(), Some("comparators"));

    // Fieldless-enum field reader (`Comparator.op: semver::Op`) -> variant-name str.
    let op = method(&spec, "Comparator", "op");
    match &op.ret {
        BridgeReturn::EnumName(path, variants, non_exhaustive) => {
            assert_eq!(path, "semver::Op");
            assert_eq!(variants.first().map(String::as_str), Some("Exact"));
            assert!(variants.contains(&"Wildcard".to_string()));
            assert!(
                *non_exhaustive,
                "semver::Op is #[non_exhaustive] — its match needs a wildcard arm"
            );
        }
        other => panic!("Comparator::op must be an EnumName reader, got {other:?}"),
    }

    let src = emit(&spec);
    assert!(
        src.contains(
            "pub fn pre(&self) -> Prerelease {\n            Prerelease(self.0.pre.clone())"
        ),
        "handle field reader must clone + wrap the inner field\n{src}"
    );
    assert!(
        src.contains("pub fn major(&self) -> u64 {\n            self.0.major"),
        "scalar field reader must read the field directly\n{src}"
    );
    assert!(
        src.contains("semver::Op::Exact => \"Exact\",") && src.contains("_ => \"unknown\","),
        "enum reader must map variants to names with a non_exhaustive wildcard\n{src}"
    );
}

#[test]
fn honest_skips_for_unbridgeable_fields() {
    let spec = semver_spec();
    let skip_reason = |item: &str| {
        spec.skips
            .iter()
            .find(|s| s.item == item)
            .map(|s| format!("{:?}", s.reason))
            .unwrap_or_else(|| panic!("{item} must be a recorded skip"))
    };
    // FromIterator is generic.
    assert!(skip_reason("VersionReq::from_iter")
        .to_lowercase()
        .contains("generic"));
}

#[test]
fn overlay_carries_no_inject_hack() {
    // The full-parity lanes replaced the hand-written major/minor/patch/cmp inject;
    // the overlay is now pure `treat_as = "opaque"` decisions.
    let overlay_src = std::fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/semver.overlay.toml"),
    )
    .expect("read semver overlay");
    assert!(
        !overlay_src.contains("inject ="),
        "semver overlay must no longer carry an `inject` directive"
    );
}
