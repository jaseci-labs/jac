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
    /// Set on a synthesized owning wrapper (M4 Phase B v1): instead of the
    /// `pub struct T(pub inner)` newtype, codegen emits an ouroboros struct that
    /// owns a copy of the borrowed-from input plus the borrowing value with its
    /// lifetime erased to `'static`. `None` for ordinary opaque/error types.
    pub wrapper: Option<OwningWrapper>,
}

/// Describes how to synthesize an owning wrapper around a borrowed return.
///
/// A method `fn(&self, input: &str) -> Option<Borrowed<'_>>` on the owner type
/// (where `Borrowed` is an in-crate struct carrying a lifetime) can't cross the
/// ABI as-is. The wrapper owns the input `String` and the borrowing value (its
/// lifetime transmuted to `'static`); it is sound because the owned buffer is
/// never mutated or moved-out and the borrower field drops before the owner.
#[derive(Debug, Clone, PartialEq)]
pub struct OwningWrapper {
    /// The borrowed inner type's path with no lifetime args, e.g. `regex::Match`.
    pub borrowed_path: String,
    /// Number of lifetime params on the borrowed type — each erased to `'static`
    /// in the stored field (`Match<'static>`, `Captures<'static>`, …).
    pub lifetimes: usize,
    /// How the wrapper is built from a plain owner type (e.g. `Regex::find`), if
    /// it is. `None` for a wrapper reached ONLY by nesting — produced from another
    /// wrapper's reader (e.g. an `OwnedMatch` returned by `OwnedCaptures::name`) —
    /// which has no owner `&str`-taking method to synthesize a root `wrap` ctor
    /// from; its instances are built inline by the nested producer instead.
    pub root: Option<RootProducer>,
}

/// The root construction path for an owning wrapper: an owner method
/// `fn(&self, &str) -> Option<Borrowed<'_>>` that both owns the input and
/// produces the borrowing value. Emitted as the wrapper's non-pub `wrap` ctor.
#[derive(Debug, Clone, PartialEq)]
pub struct RootProducer {
    /// The owner type's inner path, e.g. `regex::Regex` — the `wrap` ctor's first arg.
    pub owner_inner_path: String,
    /// The owner method that produces the borrowed value, e.g. `find`.
    pub producer_call: String,
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
    /// Which receiver expression the emitted body calls through. Ordinary methods
    /// delegate to the newtype field (`self.0`); synthesized wrapper readers
    /// delegate to the erased borrowing value (`self.inner`).
    pub recv: Recv,
}

/// The receiver expression a method body delegates through.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub enum Recv {
    /// `self.0` — the opaque newtype's wrapped value (the common case).
    #[default]
    Field0,
    /// `self.inner` — an owning wrapper's lifetime-erased borrowing value.
    Inner,
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
    /// Producer of a synthesized owning wrapper: the method returns
    /// `Option<Wrapper>`. The string is the wrapper type name (e.g. `OwnedMatch`).
    /// A ROOT producer (`recv: Field0`) delegates to `Wrapper::wrap(&self.0, …)`;
    /// a NESTED producer (`recv: Inner`) builds the wrapper inline from the parent
    /// wrapper's borrowing value, sharing the owned buffer via an `Arc` clone.
    OptWrapper(String),
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
