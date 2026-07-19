//! The fixed-arity INTEGER TUPLE return lane (`BridgeReturn::Tuple`).
//!
//! `time`'s `Time::as_hms(&self) -> (u8, u8, u8)` (and the `_milli`/`_micro`/`_nano`
//! siblings, `to_hms*`) return a by-value tuple of integer scalars. na has no tuple
//! type and the frozen v1 ABI has a single return out-slot, so a tuple does NOT get a
//! new wire tag: codegen binds the source tuple once and re-projects its fields into a
//! `Vec<i64>` (`vec![__t.0 as i64, __t.1 as i64, __t.2 as i64]`) which rides the
//! existing `List` wire lane — the macro tags it `TAG_LIST_BIT | TAG_INT` and both
//! loaders already decode it into a real Jac `list[int]` / Python `list`. A tuple whose
//! elements are NOT all `i64`-fittable ints (the `(i32, Month, u8)` calendar shapes,
//! float tuples) stays an honest skip via the wide fallback. Pinned on real `time`.

use std::path::PathBuf;

use rustdoc_types::Crate;

use crate::{classify, emit};

fn load(fixture: &str) -> Crate {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join(format!("tests/fixtures/{fixture}.json"));
    let data = std::fs::read_to_string(&p).unwrap_or_else(|_| panic!("read {fixture}"));
    serde_json::from_str(&data).unwrap_or_else(|e| panic!("parse {fixture}: {e}"))
}

fn method<'a>(spec: &'a crate::types::BridgeSpec, ty: &str, m: &str) -> &'a crate::types::BridgeFn {
    let bt = spec
        .types
        .iter()
        .find(|t| t.name == ty)
        .unwrap_or_else(|| panic!("{ty} not bridged"));
    bt.ctor
        .iter()
        .chain(bt.methods.iter())
        .find(|f| f.exposed() == m)
        .unwrap_or_else(|| panic!("{ty}::{m} not bridged"))
}

/// `Time::as_hms -> (u8, u8, u8)` classifies as a 3-element integer `Tuple`, each
/// element carrying its concrete Rust width spelling in declaration order.
#[test]
fn as_hms_classifies_as_three_int_tuple() {
    let spec = classify(&load("time-0.3.53"));
    let f = method(&spec, "Time", "as_hms");
    match &f.ret {
        crate::types::BridgeReturn::Tuple(elems) => {
            assert_eq!(elems, &vec!["u8".to_string(), "u8".to_string(), "u8".to_string()]);
        }
        other => panic!("as_hms must be a Tuple return, got {other:?}"),
    }
}

/// The widest sibling `as_hms_nano -> (u8, u8, u8, u32)` is a 4-element tuple mixing
/// `u8` and `u32` — both widen losslessly to the `i64` list slot.
#[test]
fn as_hms_nano_is_four_element_mixed_width_tuple() {
    let spec = classify(&load("time-0.3.53"));
    let f = method(&spec, "Time", "as_hms_nano");
    match &f.ret {
        crate::types::BridgeReturn::Tuple(elems) => {
            assert_eq!(elems, &vec![
                "u8".to_string(),
                "u8".to_string(),
                "u8".to_string(),
                "u32".to_string(),
            ]);
        }
        other => panic!("as_hms_nano must be a 4-tuple, got {other:?}"),
    }
}

/// Codegen re-projects the tuple onto the `List` lane: a `-> Vec<i64>` signature and
/// a body that binds the source call once and widens every positional field to `i64`.
/// This is the whole lane — the emitted `Vec<i64>` needs no new macro or loader path.
#[test]
fn tuple_return_lowers_to_vec_i64_on_the_list_lane() {
    let spec = classify(&load("time-0.3.53"));
    let src = emit(&spec);
    assert!(
        src.contains("pub fn as_hms(&self) -> Vec<i64>"),
        "as_hms must lower to a `-> Vec<i64>` list-lane return\n\
         (searched generated `time` bridge source)"
    );
    // `Time::as_hms(self)` consumes `self` (a `Copy` type), so the source call goes
    // through `self.0.clone()`; the tuple is bound once and its fields widened.
    assert!(
        src.contains(
            "{ let __t = self.0.clone().as_hms(); vec![__t.0 as i64, __t.1 as i64, __t.2 as i64] }"
        ),
        "the tuple must be bound once and its fields widened into a Vec<i64>"
    );
    // The 4-tuple projects its fourth field too.
    assert!(
        src.contains("vec![__t.0 as i64, __t.1 as i64, __t.2 as i64, __t.3 as i64]"),
        "as_hms_nano must project all four fields"
    );
}

/// A tuple carrying a non-int element (`Date::to_calendar_date -> (i32, Month, u8)`,
/// where `Month` is a fieldless enum) is NOT admitted to the int-tuple lane — it stays
/// a skip (the wide fallback finds no serde-named leaf), so the lane is narrow and
/// can't silently pull mixed calendar tuples wide. It must never emit a `Tuple` return.
#[test]
fn tuple_with_enum_element_is_not_an_int_tuple() {
    let spec = classify(&load("time-0.3.53"));
    let has_enum_tuple = spec
        .types
        .iter()
        .flat_map(|t| t.ctor.iter().chain(t.methods.iter()))
        .any(|f| {
            matches!(&f.ret, crate::types::BridgeReturn::Tuple(elems)
                if elems.iter().any(|e| e == "Month" || e == "Weekday"))
        });
    assert!(
        !has_enum_tuple,
        "an int-tuple return must never carry an enum element spelling"
    );
    // And `to_calendar_date` (a `(i32, Month, u8)` return) must not be a Tuple.
    let bt = spec.types.iter().find(|t| t.name == "Date").expect("Date bridged");
    if let Some(f) = bt
        .ctor
        .iter()
        .chain(bt.methods.iter())
        .find(|f| f.exposed() == "to_calendar_date")
    {
        assert!(
            !matches!(f.ret, crate::types::BridgeReturn::Tuple(_)),
            "to_calendar_date's (i32, Month, u8) must not classify as an int Tuple"
        );
    }
}
