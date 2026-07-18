//! Plain `-> Option<String>` return arm (M6 nullable-String lane).
//!
//! A source method returning an owned `Option<String>` (`Canvas::shape_name`)
//! classifies as `OptStrValue` and crosses on the SAME JacBuf lane as a `Str`
//! return, only `TAG_OPT_BIT`-tagged: `None` signals in-band as a null buffer
//! pointer (`Tag::Opt(Str)` in the macro), distinct from a present `""`. Before
//! this arm `classify_return` skipped `Option<String>` — the macro, both codecs
//! (na `_synth` is_opt-Str decode, ctypes), and the `TAG_OPT_BIT | TAG_STR` wire
//! tag already supported it end to end; only the binder refused to emit the
//! wrapper method. Distinct from the drain-cursor `OptStr` (body `self.items.pop()`).
//!
//! geo_demo's `shape_name(Shape) -> Option<String>` is the fixture: a wide ENUM
//! param feeding a nullable owned-String return.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::types::BridgeReturn;
use crate::{classify, emit};

fn load_geo() -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/geo_demo-0.1.0.json");
    let data = std::fs::read_to_string(&p).expect("read geo_demo fixture");
    serde_json::from_str(&data).expect("parse geo_demo fixture")
}

/// `Canvas::shape_name -> Option<String>` classifies as the `OptStrValue` lane.
#[test]
fn option_string_return_classifies_as_opt_str_value() {
    let spec = classify(&load_geo());
    let canvas = spec
        .types
        .iter()
        .find(|t| t.name == "Canvas")
        .expect("Canvas bridged");
    let f = canvas
        .methods
        .iter()
        .find(|m| m.name == "shape_name")
        .expect("shape_name must bridge (Option<String> return)");
    assert_eq!(f.ret, BridgeReturn::OptStrValue);
}

/// The emitted wrapper spells `-> Option<String>` and forwards the owned value
/// verbatim — no `.to_string()`/`.map` transform, since the source is already owned.
#[test]
fn option_string_return_emits_nullable_string_signature() {
    let spec = classify(&load_geo());
    let src = emit(&spec);

    let block = &src[src.find("impl Canvas {").expect("impl Canvas block")..];
    let sig = block
        .find("fn shape_name")
        .map(|i| &block[i..])
        .expect("shape_name method emitted");
    assert!(
        sig[..sig.find('\n').unwrap_or(sig.len()).min(200)].contains("-> Option < String >")
            || sig.contains("-> Option<String>"),
        "shape_name must return Option<String>:\n{}",
        &sig[..sig.len().min(200)]
    );
    // Owned passthrough: no `.to_string()` normalization on this method's body.
    let body_end = sig.find("\n    }").unwrap_or(sig.len().min(400));
    assert!(
        !sig[..body_end].contains(".to_string()"),
        "Option<String> body forwards the owned value verbatim (no .to_string()):\n{}",
        &sig[..body_end.min(400)]
    );
}

/// `Canvas::shape_name_bytes -> Option<Vec<u8>>` classifies as the byte analogue
/// lane `OptBytesValue` (`Tag::Opt(Bytes)` in the macro).
#[test]
fn option_bytes_return_classifies_as_opt_bytes_value() {
    let spec = classify(&load_geo());
    let canvas = spec
        .types
        .iter()
        .find(|t| t.name == "Canvas")
        .expect("Canvas bridged");
    let f = canvas
        .methods
        .iter()
        .find(|m| m.name == "shape_name_bytes")
        .expect("shape_name_bytes must bridge (Option<Vec<u8>> return)");
    assert_eq!(f.ret, BridgeReturn::OptBytesValue);
}

/// The emitted wrapper spells `-> Option<Vec<u8>>` and forwards the owned value
/// verbatim — no `.to_vec()`/`.map` transform, since the source is already owned.
#[test]
fn option_bytes_return_emits_nullable_bytes_signature() {
    let spec = classify(&load_geo());
    let src = emit(&spec);

    let block = &src[src.find("impl Canvas {").expect("impl Canvas block")..];
    let sig = block
        .find("fn shape_name_bytes")
        .map(|i| &block[i..])
        .expect("shape_name_bytes method emitted");
    assert!(
        sig[..sig.find('\n').unwrap_or(sig.len()).min(200)].contains("-> Option < Vec < u8 > >")
            || sig.contains("-> Option<Vec<u8>>"),
        "shape_name_bytes must return Option<Vec<u8>>:\n{}",
        &sig[..sig.len().min(200)]
    );
    // Owned passthrough: no `.to_vec()` normalization on this method's body.
    let body_end = sig.find("\n    }").unwrap_or(sig.len().min(400));
    assert!(
        !sig[..body_end].contains(".to_vec()"),
        "Option<Vec<u8>> body forwards the owned value verbatim (no .to_vec()):\n{}",
        &sig[..body_end.min(400)]
    );
}
