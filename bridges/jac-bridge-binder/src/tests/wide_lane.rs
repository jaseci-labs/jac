//! Codegen for the serde wide lane (2.8). No corpus fixture returns/takes a
//! bare serde value (chrono's serde types are bridged as opaque handles, so
//! handle-wins keeps them off the wide lane), so this drives `emit` from a
//! hand-built spec and asserts the generated `Wide<…>` shape — the same shape
//! the runtime test (`jac-bridge/tests/wide.rs`) proves crosses the ABI.

use crate::codegen::{emit, emit_cargo_toml};
use crate::types::{
    BridgeFn, BridgeParam, BridgeReturn, BridgeSpec, BridgeType, Ownership, Recv, ScalarType,
    SerdeInfo, TypeKind, WideField, WideRecord,
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
        ret_ownership: Ownership::Owned,
        via_trait: None,
        self_mut: false,
        consumes_self: false,
        is_static: false,
    }
}

/// A `Calc` handle whose `shift(Wide<Point>, i64) -> Wide<Point>` mirrors the
/// runtime test: a wide param, a scalar wedged beside it, and a wide return.
fn spec() -> BridgeSpec {
    let calc = BridgeType {
        name: "Calc".into(),
        kind: TypeKind::Opaque,
        inner_path: "demo::Calc".into(),
        module_path: vec![],
        item_id: 0,
        ctor: Some(method("new", vec![], BridgeReturn::OwnSelf)),
        methods: vec![method(
            "shift",
            vec![
                BridgeParam {
                    name: "p".into(),
                    ty: ScalarType::Wide("demo::Point".into()),
                },
                BridgeParam {
                    name: "dx".into(),
                    ty: ScalarType::Int("i64".into()),
                },
            ],
            BridgeReturn::Wide("demo::Point".into()),
        )],
        injected_source: vec![],
        wrapper: None,
        mono: None,
        serde: SerdeInfo::default(),
        force_wide: None,
    };
    BridgeSpec {
        module_name: "demo".into(),
        crate_version: "0.1.0".into(),
        crate_features: vec![],
        types: vec![calc],
        records: vec![],
        skips: vec![],
        dropped: vec![],
        inherited_excluded: 0,
    }
}

#[test]
fn wide_param_and_return_emit_wide_marker() {
    let src = emit(&spec());
    // The wide param and return re-declare the inner type inside `Wide<…>`; the
    // scalar wedged between them keeps its own `i64` tag (per-value lane selection).
    assert!(
        src.contains("pub fn shift(&self, p: Wide<demo::Point>, dx: i64) -> Wide<demo::Point> {"),
        "wide signature\n{src}"
    );
    // The body unwraps the wide param's transparent `.0` and wraps the result.
    assert!(
        src.contains("Wide(self.0.shift(p.0, dx))"),
        "wide body\n{src}"
    );
}

#[test]
fn typed_record_emits_jac_record_struct() {
    // 2.9: a spec carrying a typed record emits a `#[jac_record]` struct whose
    // fields mirror the derived-serde shape; the macro turns it into the blob
    // record table and the loader synthesizes a typed obj. The wide signatures are
    // unchanged — the record is pure metadata beside `Wide<demo::Point>`.
    let mut s = spec();
    s.records = vec![WideRecord {
        name: "Point".into(),
        fields: vec![
            WideField { name: "x".into(), rust_ty: "i64".into() },
            WideField { name: "y".into(), rust_ty: "i64".into() },
            WideField { name: "label".into(), rust_ty: "String".into() },
        ],
    }];
    let src = emit(&s);
    assert!(src.contains("#[jac_record]"), "missing marker\n{src}");
    assert!(src.contains("pub struct Point {"), "missing record struct\n{src}");
    assert!(src.contains("pub x: i64,"), "missing field x\n{src}");
    assert!(src.contains("pub label: String,"), "missing field label\n{src}");
    // The wide signature still marshals the foreign type, not the local record.
    assert!(src.contains("p: Wide<demo::Point>"), "wide sig changed\n{src}");
}

#[test]
fn wide_bridge_cargo_toml_declares_serde_and_rmp() {
    // The macro emits `::serde` / `::rmp_serde` paths for a wide slot, so the
    // GENERATED crate must depend on both — jac-bridge lists them only as
    // dev-deps, which do not flow downstream. Without this the bridge fails to
    // compile with "could not find `rmp_serde`".
    let toml = emit_cargo_toml(&spec(), "/path/to/jac-bridge");
    assert!(toml.contains("serde = \"1\""), "missing serde\n{toml}");
    assert!(toml.contains("rmp-serde = \"1\""), "missing rmp-serde\n{toml}");
}

#[test]
fn non_wide_bridge_omits_serde_deps() {
    // A scalar-only bridge stays minimal (byte-identical default-feature output).
    let mut s = spec();
    s.types[0].methods = vec![method(
        "bump",
        vec![BridgeParam {
            name: "dx".into(),
            ty: ScalarType::Int("i64".into()),
        }],
        BridgeReturn::Int("i64".into()),
    )];
    let toml = emit_cargo_toml(&s, "/path/to/jac-bridge");
    assert!(!toml.contains("rmp-serde"), "unexpected rmp-serde\n{toml}");
}

/// 2.11 perf gate (source-inspection half): a signature built ENTIRELY from
/// scalar/handle lanes must never route through the wide lane. The wide lane
/// msgpack-encodes every value (an allocation + a serde walk per call), so a
/// scalar signature silently regressing onto it is a real, invisible perf cliff.
/// This test pins lane selection by asserting the emitted source for an
/// all-scalar bridge carries ZERO `Wide<…>` markers (and no serde deps). It is
/// deterministic — no timing — so it is the CI-friendly guard; the wall-clock
/// backstop lives in `jac-bridge/tests/wide.rs::wide_bulk_vec_f64_under_ceiling`.
#[test]
fn scalar_signatures_never_emit_wide_lane_calls() {
    let mut s = spec();
    // Every non-wide lane the binder can emit: int/uint/f64/bool/str/bytes,
    // by value and by return, plus a handle ctor. None is serde.
    s.types[0].ctor = Some(method("new", vec![], BridgeReturn::OwnSelf));
    s.types[0].methods = vec![
        method(
            "scale",
            vec![
                BridgeParam { name: "n".into(), ty: ScalarType::Int("i64".into()) },
                BridgeParam { name: "u".into(), ty: ScalarType::Uint("u64".into()) },
                BridgeParam { name: "b".into(), ty: ScalarType::Bool },
                BridgeParam { name: "s".into(), ty: ScalarType::Str },
                BridgeParam { name: "raw".into(), ty: ScalarType::Bytes },
            ],
            BridgeReturn::Uint("u64".into()),
        ),
        method("name", vec![], BridgeReturn::Str),
        method("digest", vec![], BridgeReturn::Bytes),
        method("count", vec![], BridgeReturn::Int("i64".into())),
        method("ok", vec![], BridgeReturn::Bool),
    ];
    s.records = vec![];
    let src = emit(&s);
    assert!(
        !src.contains("Wide<") && !src.contains("Wide("),
        "a scalar-only bridge must not emit any wide-lane marshaling\n{src}"
    );
    let toml = emit_cargo_toml(&s, "/path/to/jac-bridge");
    assert!(
        !toml.contains("rmp-serde") && !toml.contains("serde ="),
        "a scalar-only bridge must not pull in serde/rmp-serde\n{toml}"
    );
}
