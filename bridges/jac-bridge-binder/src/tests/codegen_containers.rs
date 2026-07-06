//! Codegen for the integer / HashMap / Vec return + integer-param verticals
//! (M6 binder tail). No corpus fixture exercises a `HashMap<String, V>` or
//! `Vec<V>` return, so this drives `emit` from a hand-built spec and asserts the
//! generated Rust shape — the same shape the hand-written seed crates
//! (`jac-bridge-map` / `jac-bridge-list`) prove compiles under the macro.

use crate::codegen::emit;
use crate::types::{
    BridgeFn, BridgeParam, BridgeReturn, BridgeSpec, BridgeType, Recv, ScalarType, TypeKind,
};

fn method(name: &str, params: Vec<BridgeParam>, ret: BridgeReturn) -> BridgeFn {
    BridgeFn {
        name: name.into(),
        export_name: None,
        params,
        ret,
        throws: None,
        recv: Recv::Field0,
        is_async: false,
    }
}

fn spec() -> BridgeSpec {
    let store = BridgeType {
        name: "Store".into(),
        kind: TypeKind::Opaque,
        inner_path: "demo::Store".into(),
        module_path: vec![],
        item_id: 0,
        ctor: Some(method(
            "new",
            vec![BridgeParam {
                name: "n".into(),
                ty: ScalarType::Uint("u32".into()),
            }],
            BridgeReturn::OwnSelf,
        )),
        methods: vec![
            method("seed", vec![], BridgeReturn::Uint("u32".into())),
            method("delta", vec![], BridgeReturn::Int("i64".into())),
            method(
                "at",
                vec![BridgeParam {
                    name: "i".into(),
                    ty: ScalarType::Uint("usize".into()),
                }],
                BridgeReturn::Bool,
            ),
            method("counts", vec![], BridgeReturn::List("Vec<i64>".into())),
            method(
                "labels",
                vec![],
                BridgeReturn::Map("HashMap<String, String>".into()),
            ),
        ],
        injected_source: vec![],
        wrapper: None,
        mono: None,
    };
    BridgeSpec {
        module_name: "demo".into(),
        crate_version: "0.1.0".into(),
        types: vec![store],
        skips: vec![],
        dropped: vec![],
    }
}

#[test]
fn integer_returns_and_params_emit_verbatim() {
    let src = emit(&spec());
    // Unsigned/signed returns keep their concrete width; the macro tags the sign.
    assert!(
        src.contains("pub fn seed(&self) -> u32 {"),
        "seed sig\n{src}"
    );
    assert!(src.contains("self.0.seed()"), "seed body\n{src}");
    assert!(
        src.contains("pub fn delta(&self) -> i64 {"),
        "delta sig\n{src}"
    );
    // An integer param crosses in a u64 slot but the wrapper preserves the width.
    assert!(
        src.contains("pub fn at(&self, i: usize) -> bool {"),
        "at sig\n{src}"
    );
    assert!(src.contains("self.0.at(i)"), "at body\n{src}");
    // A ctor taking an integer.
    assert!(
        src.contains("pub fn new(n: u32) -> Self {"),
        "ctor sig\n{src}"
    );
    assert!(
        src.contains("Self(demo::Store::new(n))"),
        "ctor body\n{src}"
    );
}

#[test]
fn container_returns_emit_verbatim_with_hashmap_import() {
    let src = emit(&spec());
    // Vec<V> forwarded directly (no `.to_string()` / `Self(..)` wrapping).
    assert!(
        src.contains("pub fn counts(&self) -> Vec<i64> {"),
        "counts sig\n{src}"
    );
    assert!(src.contains("self.0.counts()"), "counts body\n{src}");
    // HashMap<String, V> forwarded directly, and the type brought into scope.
    assert!(
        src.contains("pub fn labels(&self) -> HashMap<String, String> {"),
        "labels sig\n{src}"
    );
    assert!(src.contains("self.0.labels()"), "labels body\n{src}");
    assert!(
        src.contains("    use std::collections::HashMap;"),
        "a map return must import HashMap into the module\n{src}"
    );
}

#[test]
fn no_hashmap_import_without_a_map_return() {
    // Same type, but drop the map method — the import must not appear.
    let mut s = spec();
    s.types[0].methods.retain(|m| m.name != "labels");
    let src = emit(&s);
    assert!(
        !src.contains("use std::collections::HashMap;"),
        "HashMap import should only appear when a map return exists\n{src}"
    );
    // Vec is in the prelude, so a list return needs no import.
    assert!(
        src.contains("pub fn counts(&self) -> Vec<i64> {"),
        "counts still present\n{src}"
    );
}
