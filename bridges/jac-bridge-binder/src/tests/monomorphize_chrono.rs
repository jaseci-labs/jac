//! Monomorphization tests over the chrono fixture, whose `Date<Tz>` and
//! `DateTime<Tz>` are generic structs — the one shape the corpus offers to
//! exercise the `[type."T"] monomorphize = [..]` directive.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{
    apply_overlay, classify, classify_with_overlay, emit, parse_overlay,
    types::{BridgeReturn, MonoType},
};

fn load_chrono_doc() -> Crate {
    let p =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/chrono-0.4.45.json");
    let data = std::fs::read_to_string(&p).expect("read chrono fixture");
    serde_json::from_str(&data).expect("parse chrono fixture")
}

#[test]
fn generic_struct_is_dropped_without_a_directive() {
    let spec = classify(&load_chrono_doc());
    // Date<Tz> / DateTime<Tz> can't cross as a bare `T(pub crate::T)` newtype —
    // the type arg is unknown — so absent a monomorphize directive they are
    // dropped, exactly like a lifetime-bearing cursor type.
    assert!(!spec.types.iter().any(|t| t.name == "Date"), "generic Date must be dropped");
    assert!(!spec.types.iter().any(|t| t.name == "DateTime"), "generic DateTime must be dropped");

    // Crucially, no uncompilable generic newtype leaks into codegen.
    let src = emit(&spec);
    assert!(
        !src.contains("pub struct Date(pub chrono::Date);"),
        "invalid generic newtype (missing <Tz>) leaked\n{src}"
    );
    assert!(!src.contains("pub struct DateTime(pub chrono::DateTime);"), "invalid newtype leaked");
    // A concrete (non-generic) chrono struct is unaffected.
    assert!(spec.types.iter().any(|t| t.name == "NaiveDate"), "NaiveDate (concrete) must survive");
}

#[test]
fn monomorphize_pins_concrete_instantiations() {
    let overlay = parse_overlay(
        "[type.\"DateTime\"]\nmonomorphize = [\"chrono::Utc\"]\n\n\
         [type.\"Date\"]\nmonomorphize = [\"chrono::Utc\", \"chrono::Local\"]\n",
    )
    .unwrap();
    let spec = classify_with_overlay(&load_chrono_doc(), Some(&overlay));

    // Each concrete pin becomes its own opaque type wrapping `crate::T<concrete>`.
    let du = spec.types.iter().find(|t| t.name == "DateUtc").expect("DateUtc");
    assert_eq!(du.inner_path, "chrono::Date<chrono::Utc>");
    assert_eq!(
        du.mono.as_ref().unwrap(),
        &MonoType {
            origin_name: "Date".into(),
            generic_param: "Tz".into(),
            concrete: "chrono::Utc".into(),
        }
    );
    assert!(spec.types.iter().any(|t| t.name == "DateLocal"), "second Date pin present");
    assert!(spec.types.iter().any(|t| t.name == "DateTimeUtc"), "DateTime pin present");
    // The original generic names are gone — replaced by their monomorphizations.
    assert!(!spec.types.iter().any(|t| t.name == "Date"));
    assert!(!spec.types.iter().any(|t| t.name == "DateTime"));

    // A `-> Self` method (`Date::succ -> Date<Tz>`) is rescued: its rustdoc return
    // path still reads `Date`, and its arg is the bare generic `Tz` (same
    // instantiation), so Self-detection matches.
    let succ = du.methods.iter().find(|m| m.name == "succ").expect("succ rescued on DateUtc");
    assert_eq!(succ.ret, BridgeReturn::OwnSelf);

    // Soundness: a method returning a DIFFERENT instantiation must NOT be treated
    // as Self, or codegen would emit a type-mismatched `Self(self.0.<m>())`.
    // `DateTime<Tz>::to_utc -> DateTime<Utc>` IS Self for DateTimeUtc, but
    // `fixed_offset -> DateTime<FixedOffset>` is a different type and stays a skip.
    let dtu = spec.types.iter().find(|t| t.name == "DateTimeUtc").expect("DateTimeUtc");
    assert!(
        dtu.methods.iter().any(|m| m.name == "to_utc" && m.ret == BridgeReturn::OwnSelf),
        "to_utc -> DateTime<Utc> should be Self on DateTimeUtc"
    );
    assert!(
        !dtu.methods.iter().any(|m| m.name == "fixed_offset"),
        "fixed_offset -> DateTime<FixedOffset> must not be miswrapped as DateTimeUtc"
    );
}

#[test]
fn monomorphize_emits_valid_concrete_newtypes() {
    let overlay =
        parse_overlay("[type.\"Date\"]\nmonomorphize = [\"chrono::Utc\"]\n").unwrap();
    let spec = classify_with_overlay(&load_chrono_doc(), Some(&overlay));
    let src = emit(&spec);

    // The newtype carries the concrete type arg — valid Rust, unlike the bare
    // generic form that would fail to compile.
    assert!(
        src.contains("pub struct DateUtc(pub chrono::Date<chrono::Utc>);"),
        "missing concrete newtype\n{src}"
    );
    // Self-returning body wraps through the newtype field.
    let block = &src[src.find("impl DateUtc {").expect("impl DateUtc block")..];
    assert!(block.contains("pub fn succ(&self) -> Self {"), "missing succ signature\n{block}");
    assert!(block.contains("Self(self.0.succ())"), "wrong Self-wrapping body\n{block}");
}

#[test]
fn monomorphize_empty_set_is_rejected() {
    let overlay = parse_overlay("[type.\"Date\"]\nmonomorphize = []\n").unwrap();
    let mut spec = classify_with_overlay(&load_chrono_doc(), Some(&overlay));
    let err = apply_overlay(&mut spec, &overlay).unwrap_err();
    assert!(err.contains("monomorphize"), "empty pin set must be rejected: {err}");
}
