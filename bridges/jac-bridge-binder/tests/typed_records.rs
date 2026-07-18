//! Typed-record classification (2.9-followup) on the purpose-built geo_demo
//! fixture: an opaque Canvas handle whose methods pass derived-serde DTOs by value.
//! Asserts the binder synthesizes a `#[jac_record]` for the flat, NESTED,
//! CONTAINER, and ENUM shapes with faithful field/variant type spellings, and that
//! nested records are registered transitively.

use jac_bridge_binder::classify;
use jac_bridge_binder::types::{BridgeSpec, RecordKind, WideRecord};

fn geo_demo_spec() -> BridgeSpec {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/geo_demo-0.1.0.json");
    let data = std::fs::read_to_string(path).expect("read geo_demo fixture");
    let doc: rustdoc_types::Crate = serde_json::from_str(&data).expect("parse geo_demo fixture");
    classify(&doc)
}

/// Look up a record by name; the collection order is registration order, not source.
fn rec<'a>(
    spec: &'a BridgeSpec,
    name: &str,
) -> &'a WideRecord {
    spec.records.iter().find(|r| r.name == name).unwrap_or_else(|| panic!("no record {name}"))
}

fn fields(r: &WideRecord) -> Vec<(String, Option<String>)> {
    r.fields.iter().map(|f| (f.name.clone(), f.rust_ty.clone())).collect()
}

#[test]
fn nested_container_and_enum_records_are_synthesized() {
    let spec = geo_demo_spec();

    // All four DTOs are registered (Point reached transitively via Region/Shape).
    let mut names: Vec<&str> = spec.records.iter().map(|r| r.name.as_str()).collect();
    names.sort_unstable();
    assert_eq!(names, vec!["Path", "Point", "Region", "Shape"]);

    // Flat scalar/String record (the 2.9 baseline shape).
    let point = rec(&spec, "Point");
    assert_eq!(point.kind, RecordKind::Struct);
    assert_eq!(
        fields(point),
        vec![
            ("x".into(), Some("i64".into())),
            ("y".into(), Some("i64".into())),
            ("label".into(), Some("String".into())),
        ]
    );

    // NESTED record: both fields are the Point record, spelled by its local name.
    let region = rec(&spec, "Region");
    assert_eq!(region.kind, RecordKind::Struct);
    assert_eq!(
        fields(region),
        vec![("tl".into(), Some("Point".into())), ("br".into(), Some("Point".into()))]
    );

    // CONTAINER fields: list-of-record, optional scalar, string-keyed map.
    let path = rec(&spec, "Path");
    assert_eq!(path.kind, RecordKind::Struct);
    assert_eq!(
        fields(path),
        vec![
            ("pts".into(), Some("Vec<Point>".into())),
            ("name".into(), Some("Option<String>".into())),
            ("weights".into(), Some("std::collections::HashMap<String, i64>".into())),
        ]
    );

    // ENUM record: unit variant (None payload), newtype record/scalar/String payloads.
    let shape = rec(&spec, "Shape");
    assert_eq!(shape.kind, RecordKind::Enum);
    assert_eq!(
        fields(shape),
        vec![
            ("Empty".into(), None),
            ("Dot".into(), Some("Point".into())),
            ("Area".into(), Some("Region".into())),
            ("Tag".into(), Some("String".into())),
        ]
    );
}

#[test]
fn canvas_handle_bridges_ctor_and_all_wide_methods() {
    let spec = geo_demo_spec();
    let canvas = spec.types.iter().find(|t| t.name == "Canvas").expect("Canvas type");
    assert!(canvas.ctor.is_some(), "Canvas::new should be the constructor");
    assert_eq!(
        canvas.methods.len(),
        7,
        "translate/trace/make_path/describe/origin_shape/shape_name/shape_name_bytes"
    );
    assert!(spec.skips.is_empty(), "geo_demo should bridge with zero skips, got {:?}", spec.skips);
}
