//! Owned `-> String` return arm (1.2.3).
//!
//! An inherent method returning an owned `String` (`DateTime::to_rfc3339 -> String`)
//! crosses on the SAME JacBuf lane as a borrowed `&str` — no new ABI tag. Before
//! this arm, `classify_return` fell through to an `UnsupportedType("String")` skip.
//! Codegen already normalizes the `Str` return to an owned `-> String` via
//! `.to_string()` (a clone on a `String` source, an allocation on `&str`), so the
//! generated-source shape and the compile path are identical to the long-proven
//! `&str` lane (the regex roundtrip's `OwnedMatch::as_str`).
//!
//! chrono's `String`-returning methods live on `DateTime<Tz>`, a generic struct, so
//! the test pins `DateTime<Utc>` with a monomorphize overlay to reach them.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::types::BridgeReturn;
use crate::{classify_with_overlay, emit, parse_overlay};

fn load_chrono() -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/chrono-0.4.45.json");
    let data = std::fs::read_to_string(&p).expect("read chrono fixture");
    serde_json::from_str(&data).expect("parse chrono fixture")
}

/// `DateTime::to_rfc3339 -> String` and `to_rfc2822 -> String` classify as `Str`
/// (the owned-String arm) once `DateTime<Utc>` is pinned.
#[test]
fn owned_string_return_classifies_as_str() {
    let overlay = parse_overlay("[type.\"DateTime\"]\nmonomorphize = [\"chrono::Utc\"]\n").unwrap();
    let spec = classify_with_overlay(&load_chrono(), Some(&overlay));

    let dtu = spec
        .types
        .iter()
        .find(|t| t.name == "DateTimeUtc")
        .expect("DateTimeUtc pinned");
    for m in ["to_rfc3339", "to_rfc2822"] {
        let f = dtu
            .methods
            .iter()
            .find(|x| x.name == m)
            .unwrap_or_else(|| panic!("{m} must bridge (owned String return)"));
        assert_eq!(f.ret, BridgeReturn::Str, "{m} returns an owned String");
    }
}

/// The emitted body matches the proven `Str` lane: signature `-> String`, value
/// normalized with `.to_string()` (owned across the FFI boundary, never a borrow).
#[test]
fn owned_string_return_emits_owned_string_signature() {
    let overlay = parse_overlay("[type.\"DateTime\"]\nmonomorphize = [\"chrono::Utc\"]\n").unwrap();
    let spec = classify_with_overlay(&load_chrono(), Some(&overlay));
    let src = emit(&spec);

    let block = &src[src
        .find("impl DateTimeUtc {")
        .expect("impl DateTimeUtc block")..];
    assert!(
        block.contains("pub fn to_rfc3339(&self) -> String {"),
        "to_rfc3339 must emit an owned String signature\n{block}"
    );
    assert!(
        block.contains("self.0.to_rfc3339().to_string()"),
        "to_rfc3339 body must normalize to an owned String\n{block}"
    );
}
