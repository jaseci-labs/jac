//! Output types of the classify pass — what the binder knows about a crate's
//! bridgeable surface before codegen.

/// The full bridge specification for one crate.
#[derive(Debug, Clone)]
pub struct BridgeSpec {
    pub module_name: String,
    pub crate_version: String,
    pub types: Vec<BridgeType>,
    pub skips: Vec<Skip>,
    /// Whole public types the classifier dropped before it could even reach their
    /// methods — a lifetime/const/type-generic struct with no overlay directive to
    /// pin it. Kept distinct from `skips` (which are per-method) so coverage counts
    /// hidden surface honestly: dropping a type must not silently raise the ratio.
    pub dropped: Vec<DroppedType>,
    /// Trait-provided default methods (Track A, D1) that classify deliberately did
    /// NOT enumerate because they are unresolvable — name-only entries in an impl's
    /// `provided_trait_methods` whose trait definition isn't in the rustdoc index
    /// (std `Iterator`'s ~80 blanket defaults, blanket provided-defaults from a
    /// non-dep crate). They are neither bridged nor a `Skip`; counted here and
    /// EXCLUDED from the coverage denominator so the metric stays comparable across
    /// crates (a crate implementing `Iterator` must not have its ratio wrecked by
    /// 80 defaults nothing can reach). Surfaced as "+N inherited defaults not
    /// considered" in the report — auditable, but out of `total()`/`pct()`.
    pub inherited_excluded: usize,
}

/// A public type removed wholesale during classify (not a per-method skip). Each
/// carries a machine-readable reason so the corpus job can diff what a binder
/// version can and cannot yet reach.
#[derive(Debug, Clone, PartialEq)]
pub struct DroppedType {
    /// The rustdoc type name, e.g. `DateTime`.
    pub name: String,
    pub reason: DropReason,
}

#[derive(Debug, Clone, PartialEq)]
pub enum DropReason {
    /// A struct carrying a lifetime param — can't be stored in a `Box<T>` handle
    /// (cursor/borrow types like `Match<'h>`).
    Lifetime,
    /// A const-generic struct — the const arg is unknown and there's no directive
    /// to pin it.
    ConstGeneric,
    /// A type-generic struct with no `[type."T"] monomorphize = [..]` directive
    /// (or one the single-param rule can't apply). Its concrete instantiations are
    /// unknown, so it can't cross as a bare newtype.
    UnpinnedGeneric,
}

/// One bridgeable type — either an opaque resource or an error type.
#[derive(Debug, Clone)]
pub struct BridgeType {
    pub name: String,
    pub kind: TypeKind,
    /// Inner path as it appears in the original crate: e.g. `regex::Regex`.
    pub inner_path: String,
    /// Submodule segments the type is declared under, between the crate root and
    /// the type name — e.g. `regex::error::Error` yields `["error"]`, and
    /// `regex::regex::string::Regex` yields `["regex", "string"]`. Empty for a
    /// crate-root type or a synthesized wrapper (which has no source module). An
    /// overlay `[module."m"] skip = true` drops every type whose provenance
    /// contains `m`.
    pub module_path: Vec<String>,
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
    /// Set when this type is one monomorphization of a generic struct, pinned by
    /// an overlay `[type."T"] monomorphize = [..]` directive. A generic struct
    /// can't be bridged as a bare `T(pub crate::T)` newtype — the type arg is
    /// unknown — so by default the classifier drops it. With this directive each
    /// concrete instantiation becomes its own opaque type (`DateUtc(pub
    /// chrono::Date<chrono::Utc>)`). `None` for a non-generic type.
    pub mono: Option<MonoType>,
}

/// A pinned monomorphization of a generic struct (overlay `monomorphize`).
#[derive(Debug, Clone, PartialEq)]
pub struct MonoType {
    /// The generic struct's original rustdoc name (`Date`), used to recognise a
    /// `-> Self` return whose path still reads `Date`, not the mono name.
    pub origin_name: String,
    /// The struct's single type-param name (`Tz`).
    pub generic_param: String,
    /// The concrete type the param is pinned to, verbatim from the overlay
    /// (`chrono::Utc`) — substituted into the newtype's inner type.
    pub concrete: String,
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
    /// For a cursor this is the iterator type (`regex::Matches`); for a drain it
    /// is the `&str`-yielding iterator (`regex::Split`) — codegen only uses it to
    /// name the erased iterator field's type in the `Cursor` case.
    pub borrowed_path: String,
    /// Number of lifetime params on the borrowed type — each erased to `'static`
    /// in the stored field (`Match<'static>`, `Matches<'static, 'static>`, …).
    pub lifetimes: usize,
    /// How the wrapper is built from a plain owner type (e.g. `Regex::find`), if
    /// it is. `None` for a wrapper reached ONLY by nesting — produced from another
    /// wrapper's reader (e.g. an `OwnedMatch` returned by `OwnedCaptures::name`) —
    /// which has no owner `&str`-taking method to synthesize a root `wrap` ctor
    /// from; its instances are built inline by the nested producer instead.
    /// Cursor and drain wrappers always have a root (their iterator-producing
    /// owner method).
    pub root: Option<RootProducer>,
    /// Which owning shape codegen emits for this wrapper.
    pub kind: WrapperKind,
}

/// The three owning-wrapper shapes, all of which reduce a borrowed return to
/// "an opaque handle + methods" — no new ABI tag. They differ only in what the
/// synthesized struct owns and how its readers are built.
#[derive(Debug, Clone, PartialEq, Default)]
pub enum WrapperKind {
    /// Owns the borrowing value (`inner`, lifetime erased) plus the input
    /// `Arc<String>`. Readers delegate through `self.inner`. This is the
    /// find/captures case and every nested reader-producer.
    #[default]
    Owning,
    /// A CURSOR over an iterator return (`Regex::find_iter -> Matches<'r,'h>`):
    /// owns `Arc<Owner>` + `Arc<String>` + the iterator with both lifetimes
    /// erased, and exposes a single `next(&mut self) -> Option<item_wrapper>`
    /// pull method. Each pulled item is an owning wrapper sharing this cursor's
    /// input `Arc`. `item_wrapper` is that item's `Owned…` type name.
    Cursor { item_wrapper: String },
    /// A DRAIN: eagerly collects a producer's string sequence into an owned
    /// `Vec<String>` (no lifetime survives) and drains it via
    /// `next(&mut self) -> Option<String>`. Two entry points feed this shape:
    ///   * an in-crate `&str`-yielding iterator (`Regex::split -> Split<'r,'h>`),
    ///     collected with [`DrainCollect::IterStr`];
    ///   * a method returning a string collection directly (`RegexSet::patterns
    ///     -> &[String]`, or a `Vec<String>` / `Vec<&str>` / `&[&str]`), which
    ///     needs no owned input buffer at all — see [`DrainCollect`].
    ///
    /// `params` are the producer's non-self params, forwarded verbatim into the
    /// `wrap` ctor and the producer call (the iterator case has one `&str`; a
    /// direct collection return may have zero or several scalar params).
    Drain {
        params: Vec<BridgeParam>,
        collect: DrainCollect,
    },
}

/// How a drain's `wrap` ctor turns the producer's return into the owned
/// `Vec<String>` it drains. Each variant names the exact tail expression
/// appended to `owner.<producer>(<args>)`.
#[derive(Debug, Clone, PartialEq)]
pub enum DrainCollect {
    /// An in-crate iterator whose `Item = &str`: `.map(|s| s.to_owned()).collect()`.
    IterStr,
    /// The method already returns an owned `Vec<String>`: no tail, used as-is.
    VecString,
    /// The method returns a borrowed `&[String]`: `.to_vec()`.
    SliceString,
    /// The method returns `Vec<&str>` or `&[&str]`: `.iter().map(|s| s.to_string()).collect()`.
    VecStr,
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

/// Ownership class of an opaque-handle return (Phase S, Track B). Rides the
/// `Ref` return tag as an append-only high bit the loader reads
/// (`TAG_SHARED_BIT`/`TAG_BORROW_BIT`); `Owned` is the default and emits no bit,
/// keeping every existing handle return byte-identical.
///
///   * `Owned`    — the wrapper owns the returned object; `close()` drops it.
///     Correct for a FRESH object (`NaiveDate::and_time -> NaiveDateTime`) and
///     for every owning wrapper the M4 rules synthesize.
///   * `Shared`   — RETIRED (Phase 1.2.4). It asked the loader to `retain` on
///     adopt unconditionally, but the macro boxes every return fresh (rc = 1), so
///     a retained-but-single-owner box leaks (its one close drops rc 2→1, never
///     0). The only alias the toolchain can PROVE is a `&self -> &Self` return
///     (self-identity), RC-pinned behind the loader's runtime `rh == self` guard.
///     No classifier path emits it and the overlay rejects `ownership = "shared"`;
///     the variant survives only to keep `TAG_SHARED_BIT` reserved (append-only).
///   * `Borrowed` — a live, RC-pinned view into the receiver's interior; minting
///     it `retain`s the owner so the view can never dangle.
///
/// The classifier defaults every handle return to `Owned` (see
/// `classify_return`) because rustdoc cannot prove an honest crate's return is
/// anything else; `borrowed` is forced by an overlay
/// `[fn."T::m"] ownership = "borrowed"` key. The binder never infers a non-`Owned`
/// class today — a Rust-level-unsound double-own is the crate author's bug and is
/// handled by skip-with-reason, not silently defended.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub enum Ownership {
    #[default]
    Owned,
    /// Retired — see the type docs. Kept to reserve the ABI bit; never constructed.
    Shared,
    Borrowed,
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
    /// True when the source API is `async fn` — the emitted wrapper must also be
    /// `pub async fn` so the macro detects asyncness and emits a blocking C shim.
    pub is_async: bool,
    /// Ownership class of the return when it is an opaque handle (Phase S). See
    /// [`Ownership`]. `Owned` (the default) emits no `#[jac(…)]` attribute, so a
    /// method that returns a fresh object stays byte-identical to pre-Phase-S
    /// output; `Shared`/`Borrowed` make codegen stamp `#[jac(shared|borrowed)]`
    /// which the macro turns into the return tag's ownership bit.
    pub ret_ownership: Ownership,
    /// Set (Track A, 1.1.4) when this fn was FLATTENED off a semantic trait impl
    /// (`impl Datelike for NaiveDate` → `year`/`month`/…). The string is the full
    /// trait path (`chrono::Datelike`, `digest::Digest`) so codegen can emit
    /// `use <trait_path>;` (the method call `self.0.year()` needs the trait in
    /// scope) and add the trait's crate as a dep when its root differs from the
    /// bridged module. `None` for an ordinary inherent method or a synthesized
    /// wrapper reader. Also breaks the ctor tie: an inherent (`None`) `-> Self`
    /// associated fn beats a trait-flattened one for THE constructor slot.
    pub via_trait: Option<String>,
}

/// The receiver expression a method body delegates through.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub enum Recv {
    /// `self.0` — the opaque newtype's wrapped value (the common case).
    #[default]
    Field0,
    /// `self.inner` — an owning wrapper's lifetime-erased borrowing value.
    Inner,
    /// `self.iter.next()` — a cursor's `&mut self` pull method, wrapping each
    /// pulled item into a nested owning wrapper that shares the cursor's input.
    IterNext,
    /// `self.items.pop()` — a drain cursor's `&mut self` pull method.
    DrainNext,
}

impl BridgeFn {
    /// The name to emit as `pub fn …` — the overlay rename, or the Rust name.
    pub fn exposed(&self) -> &str {
        self.export_name.as_deref().unwrap_or(&self.name)
    }
}

#[derive(Debug, Clone, PartialEq)]
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
    /// wrapper's borrowing value, sharing the owned buffer via an `Arc` clone; a
    /// CURSOR pull (`recv: IterNext`) builds it from `self.iter.next()`.
    OptWrapper(String),
    /// Producer of a NON-nullable owning wrapper: `-> Wrapper`. A cursor/drain is
    /// always constructed (an empty stream is a live handle), so `find_iter`/
    /// `split` return the wrapper directly via `Wrapper::wrap(&self.0, …)`.
    Wrapper(String),
    /// A drain cursor's pull method: `-> Option<String>`, body `self.items.pop()`
    /// (`recv: DrainNext`). None terminates the drain, distinct from a present "".
    OptStr,
    /// The CALLBACK vertical (`Regex::replace_all` with a closure `Replacer`):
    /// emit `-> Result<String, String>` whose body calls the owner's replacer
    /// method with a closure that invokes the `JacCallback` param on each match's
    /// text and splices in its result, capturing the first callback error to
    /// surface as the method's `Err`. The string is the crate's captures type
    /// (e.g. `regex::Captures`) — the closure argument the replacer walks.
    ReplacerResult(String),
    /// A signed-integer return. The string is the concrete Rust type (`i32`,
    /// `i64`, `isize`, …); the macro carries it in a u64 slot tagged `TAG_INT`,
    /// so the Jac side reads a signed `int`.
    Int(String),
    /// An unsigned-integer return. The string is the concrete Rust type (`u32`,
    /// `u64`, `usize`, …); carried in a u64 slot tagged `TAG_UINT`.
    Uint(String),
    /// A `HashMap<String, V>` return marshaled as a real Jac `dict[str, V]`. The
    /// string is the full Rust type the wrapper re-declares (e.g.
    /// `HashMap<String, i64>`); V is one of bool/int/str.
    Map(String),
    /// A `Vec<V>` return marshaled as a real Jac `list[V]`. The string is the full
    /// Rust type (e.g. `Vec<String>`); V is one of bool/int/str.
    List(String),
}

/// Scalar parameter types the v1 ABI can actually carry at the boundary.
///
/// The macro's boundary tag set (`jac-bridge/src/lib.rs`) is `bool`, `str`,
/// `String`, integers (`TAG_INT`/`TAG_UINT`), void, and opaque refs. The enum
/// lists only what codegen can emit, so there is no silently-dropped case.
#[derive(Debug, Clone, PartialEq)]
pub enum ScalarType {
    Str,
    Bool,
    /// A callback the Jac side supplies: crosses as `JacCallback` (a C-ABI fn
    /// pointer). Only appears on a `replace_all`-shaped method's `Replacer` param.
    Callback,
    /// A signed-integer param; the string is the concrete Rust type (`i32`, …).
    Int(String),
    /// An unsigned-integer param; the string is the concrete Rust type (`u32`, …).
    Uint(String),
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
    /// An overlay `treat_as` directive forced this item out of the bridge — either
    /// `treat_as = "skip"`, or a forced rule (`"cursor"`/`"drain"`/…) whose
    /// preconditions the method did not meet. The string records which.
    OverlayTreatAs(String),
    /// An overlay `[fn."T::m"] skip = true` removed this method by explicit author
    /// decision. The optional string is the author's `reason` — the machine-visible
    /// rationale for the skip-with-reason contract (e.g. a Rust-level-unsound
    /// aliasing API that hands out a second raw owner, which the binder refuses
    /// rather than silently "defends"). `None` when the author gave no reason.
    OverlaySkip(Option<String>),
}
