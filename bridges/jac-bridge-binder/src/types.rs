//! Output types of the classify pass — what the binder knows about a crate's
//! bridgeable surface before codegen.

/// The full bridge specification for one crate.
#[derive(Debug, Clone)]
pub struct BridgeSpec {
    pub module_name: String,
    pub crate_version: String,
    /// Cargo features enabled for the bridged crate, sourced from the overlay
    /// `[crate] features` (2.4). Emitted onto the source-crate dependency in the
    /// generated `Cargo.toml` so optional impls (serde and other wide-lane
    /// surface) actually compile into the bridge; also the identity a build /
    /// registry artifact is keyed by. Empty is the default-feature build.
    pub crate_features: Vec<String>,
    pub types: Vec<BridgeType>,
    /// Typed wide records (2.9): derived-serde structs whose rustdoc field list IS
    /// the msgpack wire shape, so the loader synthesizes a typed Jac `obj` /
    /// Python class instead of a dynamic dict. Emitted as `#[jac_record]` structs
    /// in the generated module (the macro turns them into the blob record table)
    /// and referenced from a wide slot by name. Ordered; the 1-based position is
    /// the record id the macro packs into the wide tag. Only FLAT records with
    /// scalar/String fields qualify in v1 — a record with a nested/container field
    /// stays on the dynamic wide lane.
    pub records: Vec<WideRecord>,
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

/// A typed wide record (2.9): a derived-serde struct emitted as a `#[jac_record]`
/// struct so the loader can synthesize a typed object. `name` is both the emitted
/// struct's name and the record's name in the blob table; it matches the LAST
/// segment of the `Wide<..>` inner type spelled in signatures, which is how the
/// macro links a wide slot to its record. Fields are in declaration order (==
/// msgpack map key order); each `rust_ty` is the field's Rust type spelling the
/// macro re-maps to a tag — a scalar (`i64`/`String`/…), a nested record name, or a
/// container of those (`Vec<Point>`, `Option<String>`), 2.9-followup.
#[derive(Debug, Clone, PartialEq)]
pub struct WideRecord {
    pub name: String,
    /// A plain struct, or a serde enum (each field is a variant).
    pub kind: RecordKind,
    pub fields: Vec<WideField>,
}

/// Whether a [`WideRecord`] is a plain struct or a serde enum.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RecordKind {
    Struct,
    Enum,
}

/// One field of a struct record, or one variant of an enum record. For a struct
/// field `rust_ty` is always `Some` (the field's type spelling). For an enum
/// variant, `rust_ty` is `None` for a unit variant and `Some(payload)` for a
/// newtype variant `V(payload)`.
#[derive(Debug, Clone, PartialEq)]
pub struct WideField {
    pub name: String,
    pub rust_ty: Option<String>,
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
    /// A struct with only public fields and no serde impl, but carrying inherent
    /// methods that would be lost — the wide (serde) lane doesn't rescue it, so
    /// the real API silently vanishes unless `[type."T"] treat_as = "opaque"`
    /// forces it through as a handle.
    TransparentData,
}

/// Serde-trait presence on a bridged type, detected from its impl list by
/// [`crate::classify`] (2.3). Consumed by the wide (msgpack) lane: a value whose
/// type is `Serialize`/`Deserialize` but has no scalar/handle lane can cross
/// msgpack-encoded (2.8), and typed-obj synthesis (2.9) only trusts rustdoc field
/// names when the impl is `#[automatically_derived]` — a hand-written impl (e.g.
/// chrono serializes `NaiveDate` as an ISO-8601 string) has a wire shape rustdoc
/// cannot see, so it must cross as its actual encoded value, never a field record.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct SerdeInfo {
    /// Implements `serde::Serialize` (canonically `serde_core::ser::Serialize`
    /// since the serde ≥1.0.220 core split — both roots are accepted).
    pub serialize: bool,
    /// Implements `serde::Deserialize` (canonically `serde_core::de::Deserialize`).
    pub deserialize: bool,
    /// At least one of the serde impls is `#[automatically_derived]` — i.e. a
    /// `#[derive(Serialize)]`, whose wire shape IS the rustdoc field list. `false`
    /// for a manual impl.
    pub automatically_derived: bool,
}

impl SerdeInfo {
    /// The type can be produced by (returned as) a wide value — it serializes.
    pub fn any(&self) -> bool {
        self.serialize || self.deserialize
    }
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
    /// Serde-trait presence detected on this type (2.3). Default (all-false) for a
    /// synthesized owning wrapper or a monomorphization, which are not themselves
    /// wide-lane candidates. Consumed by wide-lane selection (2.8).
    pub serde: SerdeInfo,
    /// Overlay override of the wide-lane decision for this type (`[type."T"]
    /// wide = true|false`). `Some(true)` forces the type wide even when `serde`
    /// detection was empty (a manual impl rustdoc missed, or an external type the
    /// structural whitelist doesn't cover); `Some(false)` forbids it even when
    /// serde says yes (keep it an opaque handle). `None` = follow detection. Set by
    /// [`crate::apply_overlay`]; consumed by wide-lane selection (2.8).
    pub force_wide: Option<bool>,
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
    /// Set (1.2.2 bytes lane) when the source method takes `&mut self` — the
    /// emitted wrapper is `pub fn f(&mut self, …)` and the macro routes it
    /// through the handle's reentrancy busy-latch. `false` for a `&self` method,
    /// a consuming-`self` method (see [`Self::consumes_self`]), or a ctor.
    pub self_mut: bool,
    /// Set (1.2.2 bytes lane) when the source method takes `self` BY VALUE
    /// (`Digest::finalize(self)`). The value lives behind the shared handle, so
    /// the body clones it out first (`self.0.clone().finalize()`); only produced
    /// when the newtype's inner type is `Clone` (verified in the classifier), so
    /// the emitted clone always compiles. Mutually exclusive with `self_mut`.
    pub consumes_self: bool,
    /// Set (1.3 FN_STATIC lane) when this is a no-receiver ASSOCIATED function
    /// that is NOT THE constructor: an extra `-> Self` factory the ctor slot
    /// couldn't hold (`Uuid::nil`/`parse_str`) or a non-`Self` static
    /// (`Sha256::digest(data) -> Vec<u8>`, `output_size() -> usize`). It lives in
    /// `methods` (so it is emitted inside the impl) but codegen omits the `&self`
    /// receiver and calls through the associated form `Type::fn(args)`, and stamps
    /// `#[jac(assoc)]` so the macro tags it `FN_STATIC` (crosses with no handle,
    /// exposed as a static method on the owning type). `false` for an ordinary
    /// method, ctor, or synthesized wrapper reader.
    pub is_static: bool,
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
    /// A plain nullable owned-`String` return (M6): a source method whose signature
    /// is `-> Option<String>` (`chrono::NaiveDate::…` shapes, `Regex`-adjacent
    /// lookups). Crosses on the SAME JacBuf lane as `Str`, only `TAG_OPT_BIT`-tagged
    /// so `None` signals in-band via a null buffer pointer (`Tag::Opt(Str)`). Codegen
    /// emits `-> Option<String>` and forwards the value verbatim — the source is
    /// already owned, so no `.to_string()`/`.map` transform is needed. Distinct from
    /// [`OptStr`] (the drain pull, whose body pops an internal buffer).
    OptStrValue,
    /// A plain nullable owned-`Vec<u8>` return (M6): a source method whose
    /// signature is `-> Option<Vec<u8>>` (also `Option<Array<u8, _>>` digest
    /// shapes). The byte analogue of [`OptStrValue`]: crosses on the SAME JacBuf
    /// lane as [`Bytes`], only `TAG_OPT_BIT`-tagged so `None` signals in-band via
    /// a null buffer pointer (`Tag::Opt(Bytes)` in the macro), distinct from a
    /// present empty `b""`. Codegen emits `-> Option<Vec<u8>>` and forwards the
    /// owned value verbatim — no `.to_vec()`/`.map` transform.
    ///
    /// [`Bytes`]: BridgeReturn::Bytes
    OptBytesValue,
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
    /// A SELF-IDENTITY reference return (`&Self` / `&mut Self`) on a method with a
    /// receiver - the builder-chain lane (`RegexBuilder::case_insensitive(&mut
    /// self, bool) -> &mut Self`). Codegen emits `-> &Self` with a body that runs
    /// the source call for its side effect and returns `self`; the macro's
    /// self-identity arm (`is_self_borrow_ret`) lowers that to the receiver's own
    /// handle and the loaders RC-pin it behind the runtime `rh == self` guard, so
    /// Jac-side chaining (`b.case_insensitive(True).multi_line(True)`) works over
    /// one shared box.
    SelfRef,
    /// A CROSS-TYPE fallible handle producer: `-> Result<Other, E>` where `Other`
    /// is a DIFFERENT bridged opaque type (`RegexBuilder::build -> Result<Regex,
    /// Error>`). The string is the target wrapper name. Codegen emits
    /// `-> Result<{Name}, String>` with `.map({Name}).map_err(|e| e.to_string())`;
    /// the macro's `extract_result` + `ret_tag` path already carries any
    /// ref-taggable ok type, so the wire shape is `TAG_REF|idx` + the module's
    /// `#[jac_error]` throw channel, exactly like `OwnSelfResult` for a non-`Self`
    /// index. Requires a bridged error type (see `reconcile_fallible_returns`).
    RefResult(String),
    /// A plain nullable signed-integer return: `-> Option<i32>` etc. The string is
    /// the concrete Rust type. Crosses `TAG_OPT_BIT | TAG_INT` as an 8-byte owned
    /// JacBuf (`None` = null buffer pointer, the same in-band channel as
    /// `Option<String>`), never a sentinel value. Codegen forwards the owned
    /// `Option` verbatim.
    OptIntValue(String),
    /// The unsigned analogue of [`OptIntValue`]: `-> Option<usize>`
    /// (`Regex::shortest_match`, `static_captures_len`). Crosses
    /// `TAG_OPT_BIT | TAG_UINT` on the same null-JacBuf channel.
    OptUintValue(String),
    /// An in-crate iterator return whose `Item` is a scalar integer, eagerly
    /// collected: `SetMatches::iter -> SetMatchesIter` (`Item = usize`) emits
    /// `-> Vec<usize>` with `.collect()` appended, riding the existing
    /// `TAG_LIST_BIT` list-return lane. The string is the full Vec type spelling.
    CollectList(String),
    /// An INLINE owning-wrapper producer (multi-param variant of `OptWrapper`):
    /// `fn(&self, haystack: &str, start: usize) -> Option<Borrowed<'_>>`
    /// (`Regex::find_at`, `captures_at`). The shared `wrap` ctor is keyed to ONE
    /// root producer, so an additional producer with extra scalar params builds
    /// the wrapper inline in its own body: own the FIRST (`&str`) param, forward
    /// the rest, erase the lifetime. Fields mirror `OwningWrapper`.
    OptWrapperInline {
        wrapper: String,
        borrowed_path: String,
        lifetimes: usize,
    },
    /// A `std::cmp::Ordering` return (`Version::cmp_precedence`). Ordering has no
    /// primitive spelling, but its three variants map cleanly onto an `i8`
    /// (`Less`/`Equal`/`Greater` → `-1`/`0`/`1`). Codegen emits a `-> i8` signature
    /// and wraps the call in a `match`, so every layer below (macro, metadata, both
    /// loaders) rides the existing signed-int `TAG_INT` lane with no change.
    Ordering,
    /// A `HashMap<String, V>` return marshaled as a real Jac `dict[str, V]`. The
    /// string is the full Rust type the wrapper re-declares (e.g.
    /// `HashMap<String, i64>`); V is one of bool/int/str.
    Map(String),
    /// A `Vec<V>` return marshaled as a real Jac `list[V]`. The string is the full
    /// Rust type (e.g. `Vec<String>`); V is one of bool/int/str.
    List(String),
    /// A byte-string return (1.2.2): `Vec<u8>`, or a digest output
    /// (`Array<u8, _>` / `GenericArray<u8, _>` / `Output<Self>`). Carried as an
    /// owned `JacBuf` tagged `TAG_BYTES` and decoded as Jac `bytes` (never utf-8
    /// validated, length-explicit so embedded NULs survive). Codegen emits
    /// `-> Vec<u8>` and appends `.to_vec()`, which turns a `GenericArray`/slice
    /// into an owned `Vec<u8>` and is a no-op-shaped clone on a `Vec<u8>` source.
    Bytes,
    /// A CROSS-TYPE owned handle return (1.2.4): the method returns a fresh owned
    /// instance of ANOTHER bridged type (`NaiveDate::and_hms -> NaiveDateTime`). The
    /// string is that type's wrapper name; codegen emits `-> {Name}` and wraps the
    /// call in the newtype (`NaiveDateTime(self.0.and_hms(…))`). The macro tags it
    /// `TAG_REF|idx` (idx = the target type's position in the spec, resolved at
    /// macro-expansion time) exactly like `OwnSelf`, only for a non-`Self` index.
    Ref(String),
    /// `Option<BridgedType>` (1.2.4), including `Option<Self>`: a nullable owned
    /// handle (`NaiveDate::with_year -> Option<Self>`, `with_month ->
    /// Option<NaiveDate>`). Codegen emits `-> Option<{Name}>` and `.map({Name})`;
    /// the macro carries `TAG_OPT_BIT | (TAG_REF|idx)`, signalling None in-band with
    /// a null handle. The string is the target wrapper name (the own type for
    /// `Option<Self>`).
    OptRef(String),
    /// A serde-wide return (2.8): a by-value type that fits no scalar/handle lane
    /// but is `Serialize`. Crosses `TAG_WIDE` as one owned `JacBuf` holding the
    /// value's MessagePack image (`rmp_serde::to_vec_named`). The string is the
    /// inner Rust type the wrapper re-declares inside `Wide<…>`; codegen emits
    /// ` -> Wide<{inner}>` and wraps the call in `Wide(…)`. Chosen only after every
    /// tag and opaque-handle lane is ruled out (handle-wins), unless a `[type."T"]
    /// wide = true` overlay forces it.
    Wide(String),
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
    /// A byte-string param (1.2.2): `&[u8]` or `impl AsRef<[u8]>`. Crosses the
    /// boundary as a `(ptr, len)` slot tagged `TAG_BYTES` with NO utf-8 check;
    /// the wrapper re-declares it as `&[u8]` (which satisfies an `AsRef<[u8]>`
    /// bound), so `self.0.update(data)` compiles for both source spellings.
    Bytes,
    /// A serde-wide param (2.8): a by-value type that fits no scalar/handle lane
    /// but is `Deserialize` (a local `#[derive(Deserialize)]` struct, or a
    /// whitelisted std shape like `Vec<f64>`). Crosses `TAG_WIDE` as a MessagePack
    /// payload decoded inside the shim. The string is the inner Rust type the
    /// wrapper re-declares inside the `Wide<…>` marker (e.g. `crate::Point`,
    /// `Vec<f64>`); codegen emits `name: Wide<{inner}>` and unwraps `name.0` at the
    /// inner call. Lane selection is per-value: a scalar beside a wide param stays
    /// its own tag (see [`crate::classify`] resolution + tests).
    Wide(String),
    /// An inbound handle param: a `&OtherBridgedType` (or `&Self`) reference to
    /// another opaque handle in the SAME bridge module (`VersionReq::matches(&self,
    /// other: &Version)`). The string is the target newtype's name. Crosses the
    /// boundary as a handle slot (the caller passes the other object's handle); the
    /// macro reconstructs `&Target` from it, the wrapper re-declares the param as
    /// `&Target` and passes `&{name}.0` to the inner call.
    Handle(String),
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
