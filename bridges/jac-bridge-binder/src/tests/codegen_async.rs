//! Codegen tests for the async fn vertical (M6.3).
//!
//! Drives `emit` and `emit_cargo_toml` from hand-built specs that contain
//! `is_async: true` functions and asserts the generated Rust shape matches
//! the hand-written `jac-bridge-async` proof crate:
//!   * the wrapper method must be `pub async fn`,
//!   * the inner call must end with `.await` (before any post-call transform),
//!   * `emit_cargo_toml` must include a `tokio` dependency only when async fns exist.

use crate::codegen::{emit, emit_cargo_toml};
use crate::types::{
    BridgeFn, BridgeParam, BridgeReturn, BridgeSpec, BridgeType, Ownership, Recv, ScalarType,
    TypeKind,
};

fn async_method(name: &str, params: Vec<BridgeParam>, ret: BridgeReturn) -> BridgeFn {
    BridgeFn {
        name: name.into(),
        export_name: None,
        params,
        ret,
        throws: None,
        recv: Recv::Field0,
        is_async: true,
        ret_ownership: Ownership::Owned,
        via_trait: None,
        self_mut: false,
        consumes_self: false,
        is_static: false,
        field_read: None,
        std_from_str: false,
    }
}

fn sync_method(name: &str, params: Vec<BridgeParam>, ret: BridgeReturn) -> BridgeFn {
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
        field_read: None,
        std_from_str: false,
    }
}

fn async_spec() -> BridgeSpec {
    let calc = BridgeType {
        name: "AsyncCalc".into(),
        kind: TypeKind::Opaque,
        inner_path: "mylib::AsyncCalc".into(),
        module_path: vec![],
        item_id: 0,
        ctor: Some(async_method(
            "new",
            vec![BridgeParam {
                name: "seed".into(),
                ty: ScalarType::Int("i64".into()),
            }],
            BridgeReturn::OwnSelfResult,
        )),
        methods: vec![
            async_method("seed", vec![], BridgeReturn::Int("i64".into())),
            async_method("label", vec![], BridgeReturn::Str),
            async_method(
                "checked_div",
                vec![BridgeParam {
                    name: "divisor".into(),
                    ty: ScalarType::Int("i64".into()),
                }],
                BridgeReturn::Int("i64".into()),
            ),
            async_method(
                "counts",
                vec![BridgeParam {
                    name: "n".into(),
                    ty: ScalarType::Uint("u32".into()),
                }],
                BridgeReturn::List("Vec<i64>".into()),
            ),
        ],
        injected_source: vec![],
        wrapper: None,
        mono: None,
        serde: Default::default(),
        force_wide: None,
    };
    BridgeSpec {
        module_name: "mylib".into(),
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
fn async_fn_emits_pub_async_fn() {
    let src = emit(&async_spec());
    assert!(
        src.contains("pub async fn seed("),
        "seed must be pub async fn\n{src}"
    );
    assert!(
        src.contains("pub async fn label("),
        "label must be pub async fn\n{src}"
    );
    assert!(
        src.contains("pub async fn checked_div("),
        "checked_div must be pub async fn\n{src}"
    );
    assert!(
        src.contains("pub async fn counts("),
        "counts must be pub async fn\n{src}"
    );
}

#[test]
fn async_fn_ctor_emits_pub_async_fn() {
    let src = emit(&async_spec());
    assert!(
        src.contains("pub async fn new("),
        "async ctor must be pub async fn\n{src}"
    );
}

#[test]
fn async_body_appends_await_before_transforms() {
    let src = emit(&async_spec());
    // seed(): i64 return — inner call + .await forwarded directly
    assert!(
        src.contains("self.0.seed().await"),
        "seed body must contain .await\n{src}"
    );
    // label(): String return — .await before .to_string()
    assert!(
        src.contains("self.0.label().await.to_string()"),
        "label body must .await before .to_string()\n{src}"
    );
    // checked_div: i64 return with param
    assert!(
        src.contains("self.0.checked_div(divisor).await"),
        "checked_div body must contain .await\n{src}"
    );
    // counts: Vec<i64> return with param
    assert!(
        src.contains("self.0.counts(n).await"),
        "counts body must contain .await\n{src}"
    );
    // new (ctor): OwnSelfResult — .await before .map(Self).map_err(...)
    assert!(
        src.contains("mylib::AsyncCalc::new(seed).await.map(Self).map_err("),
        "async ctor body must .await before .map(Self)\n{src}"
    );
}

#[test]
fn sync_fn_does_not_emit_async_or_await() {
    let mut spec = async_spec();
    // Replace all fns with sync versions.
    spec.types[0].ctor = Some(sync_method(
        "new",
        vec![BridgeParam {
            name: "seed".into(),
            ty: ScalarType::Int("i64".into()),
        }],
        BridgeReturn::OwnSelf,
    ));
    spec.types[0].methods = vec![sync_method("seed", vec![], BridgeReturn::Int("i64".into()))];
    let src = emit(&spec);
    assert!(
        !src.contains("async fn"),
        "no async fn should appear when is_async is false\n{src}"
    );
    assert!(
        !src.contains(".await"),
        "no .await should appear when is_async is false\n{src}"
    );
}

#[test]
fn emit_cargo_toml_includes_tokio_for_async_spec() {
    let toml = emit_cargo_toml(&async_spec(), "../jac-bridge");
    assert!(
        toml.contains("tokio"),
        "Cargo.toml must include tokio when spec has async fns\n{toml}"
    );
    assert!(
        toml.contains("rt-multi-thread"),
        "tokio dep must include rt-multi-thread feature\n{toml}"
    );
}

#[test]
fn emit_cargo_toml_no_tokio_for_sync_spec() {
    let mut spec = async_spec();
    spec.types[0].ctor = Some(sync_method(
        "new",
        vec![BridgeParam {
            name: "seed".into(),
            ty: ScalarType::Int("i64".into()),
        }],
        BridgeReturn::OwnSelf,
    ));
    spec.types[0].methods = vec![sync_method("seed", vec![], BridgeReturn::Int("i64".into()))];
    let toml = emit_cargo_toml(&spec, "../jac-bridge");
    assert!(
        !toml.contains("tokio"),
        "Cargo.toml must NOT include tokio when no async fns exist\n{toml}"
    );
}

#[test]
fn emit_cargo_toml_bare_crate_dep_without_features() {
    // Default-feature build: the source-crate dep stays a bare `= "=x"` so
    // existing bridges are byte-identical.
    let toml = emit_cargo_toml(&async_spec(), "../jac-bridge");
    let module = &async_spec().module_name;
    assert!(
        toml.contains(&format!("{module} = \"=")),
        "no-feature spec must emit a bare crate dep\n{toml}"
    );
    assert!(
        !toml.contains(&format!("{module} = {{")),
        "no-feature spec must NOT emit an inline table\n{toml}"
    );
}

#[test]
fn emit_cargo_toml_pins_panic_unwind() {
    // SOUNDNESS (HOLE 2): every shim is `catch_unwind`-guarded, but `catch_unwind`
    // is a no-op under `panic = "abort"`. The generated crate must PIN
    // `panic = "unwind"` in BOTH profiles so a user/workspace default can't
    // silently downgrade the "panics never kill the host" contract.
    let toml = emit_cargo_toml(&async_spec(), "../jac-bridge");
    assert!(
        toml.contains("[profile.release]"),
        "Cargo.toml must pin a release profile\n{toml}"
    );
    assert!(
        toml.contains("[profile.dev]"),
        "Cargo.toml must pin a dev profile\n{toml}"
    );
    // Exactly the two `panic = "unwind"` lines (release + dev), no `abort`.
    assert_eq!(
        toml.matches("panic = \"unwind\"").count(),
        2,
        "both profiles must pin panic = unwind\n{toml}"
    );
    assert!(
        !toml.contains("panic = \"abort\""),
        "Cargo.toml must never emit panic = abort\n{toml}"
    );
}

#[test]
fn emit_cargo_toml_crate_features_land_on_source_dep() {
    // Overlay `[crate] features` must reach the source-crate dependency, else
    // the optional serde impls the wide lane needs compile out of the bridge.
    let mut spec = async_spec();
    spec.crate_features = vec!["serde".into(), "clock".into()];
    let module = spec.module_name.clone();
    let toml = emit_cargo_toml(&spec, "../jac-bridge");
    assert!(
        toml.contains(&format!(
            "{module} = {{ version = \"={}\", features = [\"serde\", \"clock\"] }}",
            spec.crate_version
        )),
        "crate features must land on the source dep as an inline table\n{toml}"
    );
}
