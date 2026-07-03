//! Output types of the classify pass — what the binder knows about a crate's
//! bridgeable surface before codegen.

/// The full bridge specification for one crate.
#[derive(Debug, Clone)]
pub struct BridgeSpec {
    pub module_name: String,
    pub crate_version: String,
    pub types: Vec<BridgeType>,
    pub skips: Vec<Skip>,
}

/// One bridgeable type — either an opaque resource or an error type.
#[derive(Debug, Clone)]
pub struct BridgeType {
    pub name: String,
    pub kind: TypeKind,
    /// Inner path as it appears in the original crate: e.g. `regex::Regex`.
    pub inner_path: String,
    /// Rustdoc item ID — used by classify_impl to look up the correct impl list.
    pub item_id: u32,
    pub ctor: Option<BridgeFn>,
    pub methods: Vec<BridgeFn>,
    /// Raw Rust method source blocks injected by an overlay, emitted verbatim
    /// inside the `impl` block after auto-generated methods.
    pub injected_source: Vec<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TypeKind {
    /// Opaque resource: stored as a `Box<T>` handle, dropped by the bridge.
    Opaque,
    /// Error type: carries a message string; stored as `Box<String>`.
    Error,
}

/// One bridgeable function (constructor or method).
#[derive(Debug, Clone)]
pub struct BridgeFn {
    /// The Rust method name — the call target (`self.0.<name>(…)`).
    pub name: String,
    /// Jac-visible name, when an overlay `rename` diverges it from `name`.
    /// `None` means the exposed name equals `name`.
    pub export_name: Option<String>,
    pub params: Vec<BridgeParam>,
    pub ret: BridgeReturn,
    /// Index into `BridgeSpec::types` for the error type, if the function is fallible.
    pub throws: Option<usize>,
}

impl BridgeFn {
    /// The name to emit as `pub fn …` — the overlay rename, or the Rust name.
    pub fn exposed(&self) -> &str {
        self.export_name.as_deref().unwrap_or(&self.name)
    }
}

#[derive(Debug, Clone)]
pub struct BridgeParam {
    pub name: String,
    pub ty: ScalarType,
}

/// Return types the v1 rule set can bridge without lifetime erasure or generic
/// monomorphization — the subset we emit in this milestone.
#[derive(Debug, Clone, PartialEq)]
pub enum BridgeReturn {
    Void,
    Bool,
    Str,
    /// Returns an owned instance of the declaring type (infallible).
    OwnSelf,
    /// Returns `Result<Self, E>` — bridge source emits `-> Result<Self, String>`.
    OwnSelfResult,
}

/// Scalar parameter types the v1 ABI can actually carry at the boundary.
///
/// The macro's boundary tag set (`jac-bridge/src/lib.rs`) is `bool`, `str`,
/// `String`, void, and opaque refs — there is no integer tag yet. Integer
/// params are therefore recorded as skips in `classify`, not stored here; the
/// enum lists only what codegen can emit, so there is no silently-dropped case.
#[derive(Debug, Clone, PartialEq)]
pub enum ScalarType {
    Str,
    Bool,
}

/// A public item the classifier could not bridge, with a machine-readable reason.
#[derive(Debug, Clone)]
pub struct Skip {
    /// Dotted path of the skipped item, e.g. `Regex::find`.
    pub item: String,
    pub reason: SkipReason,
}

#[derive(Debug, Clone, PartialEq)]
pub enum SkipReason {
    /// Return type carries a lifetime — needs owning-wrapper (M4 v2 rules).
    LifetimeBorrow,
    /// Return or param is an iterator/cursor type.
    Cursor,
    /// Parameter is a closure / `impl Fn` — needs JacCallback (M4 v2 rules).
    Closure,
    /// Unresolved generic parameter.
    Generic,
    /// Type is not in the bridgeable set (e.g. tuples, raw pointers, trait objects).
    UnsupportedType(String),
}
