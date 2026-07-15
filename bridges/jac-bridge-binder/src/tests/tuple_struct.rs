//! Single-field tuple-struct admission (1.2.5) — the uuid unlock.
//!
//! `uuid::Uuid` is `pub struct Uuid([u8; 16])`: a single-field tuple struct whose
//! only field is private (rustdoc renders it `Tuple([None])`). `classify_type`
//! previously admitted only Plain structs with stripped fields, so the whole crate
//! bridged NOTHING. Admitting the newtype-with-opaque-inner shape unlocks `Uuid`
//! and its format-handle siblings.
//!
//! These are classification + source-shape asserts; the airtight proof that the
//! generated crate compiles against real uuid under `-D warnings` is the ignored
//! `uuid_bridge_compiles_clean` roundtrip test (CI runs it).

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::types::BridgeReturn;
use crate::{classify, emit};

fn load(fixture: &str) -> Crate {
    let p =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(format!("tests/fixtures/{fixture}.json"));
    let data = std::fs::read_to_string(&p).unwrap_or_else(|_| panic!("read {fixture}"));
    serde_json::from_str(&data).unwrap_or_else(|e| panic!("parse {fixture}: {e}"))
}

fn ty<'a>(spec: &'a crate::types::BridgeSpec, name: &str) -> &'a crate::types::BridgeType {
    spec.types
        .iter()
        .find(|t| t.name == name)
        .unwrap_or_else(|| panic!("{name} not bridged"))
}

fn method<'a>(spec: &'a crate::types::BridgeSpec, t: &str, m: &str) -> &'a crate::types::BridgeFn {
    ty(spec, t)
        .methods
        .iter()
        .find(|f| f.name == m)
        .unwrap_or_else(|| panic!("{t}::{m} not bridged"))
}

/// `Uuid` — the flagship single-field private tuple struct — is admitted as an
/// opaque handle with a constructor and its scalar-return inherent methods.
#[test]
fn uuid_tuple_struct_is_admitted_as_opaque_handle() {
    let spec = classify(&load("uuid-1.23.4"));

    let uuid = ty(&spec, "Uuid");
    assert!(
        uuid.ctor.is_some(),
        "Uuid must expose a constructor (a `-> Self`/`-> Result<Self>` assoc fn)"
    );

    // The `is_nil`/`is_max` predicates — the plan's conformance round-trip surface —
    // bridge as bool returns.
    assert_eq!(method(&spec, "Uuid", "is_nil").ret, BridgeReturn::Bool);
    assert_eq!(method(&spec, "Uuid", "is_max").ret, BridgeReturn::Bool);

    // The newtype wraps the crate-root `uuid::Uuid`, and the emitted source declares
    // it as an opaque handle.
    assert_eq!(uuid.inner_path, "uuid::Uuid");
    let src = emit(&spec);
    assert!(
        src.contains("pub struct Uuid(pub uuid::Uuid);"),
        "Uuid must emit as an opaque newtype\n{src}"
    );
}

/// A fully public tuple struct is transparent DATA, not an opaque handle — only a
/// stripped (private) inner field admits the newtype. `Uuid`'s inner is private, so
/// it is admitted; the corpus (regex, base64) covers the all-public negative case
/// by construction (those never admitted spurious tuple structs before this change).
#[test]
fn format_handles_admitted_with_correct_module_paths() {
    let spec = classify(&load("uuid-1.23.4"));

    // The format handles live in the PUBLIC `uuid::fmt` submodule and are NOT
    // re-exported at the crate root, so they must be wrapped at their submodule
    // path — not the flat `uuid::Simple`, which does not exist.
    for name in ["Simple", "Braced", "Hyphenated", "Urn"] {
        let t = ty(&spec, name);
        assert_eq!(
            t.inner_path,
            format!("uuid::fmt::{name}"),
            "{name} must wrap its public submodule path"
        );
        // Each round-trips back to a `Uuid` handle via the 1.2.4 ref lane.
        assert_eq!(
            method(&spec, name, "into_uuid").ret,
            BridgeReturn::Ref("Uuid".into()),
            "{name}::into_uuid returns a Uuid handle"
        );
    }
}

/// `NonNilUuid` is defined in the PRIVATE `uuid::non_nil` module and reachable only
/// through its crate-root re-export (`pub use non_nil::NonNilUuid;`). The wrapper
/// must use that root path — the canonical `uuid::non_nil::NonNilUuid` traverses a
/// private module and would not compile.
#[test]
fn private_module_type_uses_root_reexport_path() {
    let spec = classify(&load("uuid-1.23.4"));
    assert_eq!(ty(&spec, "NonNilUuid").inner_path, "uuid::NonNilUuid");
}

/// The single-ctor ABI: `Uuid` has many `-> Self` associated fns (`parse_str`,
/// `try_parse`, `from_slice_le`, …) but only ONE wins the constructor slot. The
/// losers are recorded as honest "additional constructor" skips, not silently
/// dropped — exposing them all needs the deferred FN_STATIC lane (the same gap
/// sha2's one-shot `digest` hit).
#[test]
fn extra_self_constructors_are_visible_skips() {
    let spec = classify(&load("uuid-1.23.4"));
    assert!(
        spec.skips.iter().any(|s| {
            s.item == "Uuid::parse_str"
                && format!("{:?}", s.reason).contains("additional constructor")
        }),
        "Uuid::parse_str must be a visible additional-constructor skip"
    );
}

/// `Uuid::get_timestamp -> Option<Timestamp>` names `Timestamp`, whose entire API
/// is closures/unsupported types, so it bridges NOTHING and codegen drops it as a
/// dead-opaque type. A return to a would-be-dropped type must not survive (it would
/// reference an undeclared wrapper and the macro would reject the crate), so the
/// reconciliation pass demotes it to a skip.
#[test]
fn ref_return_to_dead_opaque_type_is_reconciled_to_skip() {
    let spec = classify(&load("uuid-1.23.4"));

    assert!(
        !spec
            .types
            .iter()
            .any(|t| t.name == "Uuid" && t.methods.iter().any(|m| m.name == "get_timestamp")),
        "get_timestamp must not survive as a bridged method"
    );
    assert!(
        spec.skips.iter().any(|s| {
            s.item == "Uuid::get_timestamp" && format!("{:?}", s.reason).contains("Timestamp")
        }),
        "get_timestamp must be a recorded cross-type-to-unbridged skip"
    );

    // The demoted target is genuinely never emitted — no dangling `Timestamp` wrapper.
    let src = emit(&spec);
    assert!(
        !src.contains("Option<Timestamp>"),
        "no method may reference the dropped Timestamp handle\n{src}"
    );
}
