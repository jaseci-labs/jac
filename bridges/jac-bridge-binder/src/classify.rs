//! Walk a rustdoc JSON document and classify its public API into bridgeable items.
//!
//! Entry point: [`classify`].  Returns a [`BridgeSpec`] describing everything
//! the v1 rule set can emit, plus a [`Skip`] list for items that need a later
//! rule (lifetime erasure, cursors, closures) or an overlay.

use std::collections::{HashMap, HashSet};

use rustdoc_types::{Attribute, Crate, Id, Item, ItemEnum, StructKind, Type};

use crate::overlay::Overlay;
use crate::types::{
    BridgeFn, BridgeParam, BridgeReturn, BridgeSpec, BridgeType, DrainCollect, DropReason,
    DroppedType, MonoType, Ownership, OwningWrapper, RecordKind, Recv, RootProducer, ScalarType,
    SerdeInfo, Skip, SkipReason, TypeKind, WideField, WideRecord, WrapperKind,
};

/// Which serde trait a path check / whitelist-leaf lookup is after. A wide return
/// value must be `Serialize` (Rust encodes it); a wide param must be `Deserialize`
/// (Rust decodes it).
#[derive(Clone, Copy, PartialEq, Eq)]
enum SerdeTrait {
    Serialize,
    Deserialize,
}

impl SerdeTrait {
    /// Final path segment of the trait (`Serialize`/`Deserialize`).
    fn leaf(self) -> &'static str {
        match self {
            SerdeTrait::Serialize => "Serialize",
            SerdeTrait::Deserialize => "Deserialize",
        }
    }
    /// The `serde`/`serde_core` submodule the trait lives in (`ser`/`de`).
    fn module(self) -> &'static str {
        match self {
            SerdeTrait::Serialize => "ser",
            SerdeTrait::Deserialize => "de",
        }
    }
}

/// Traits whose methods are binder NOISE (D1): protocol / marker / formatting /
/// derive-shaped traits that carry no semantic crate API. Flattening them would
/// corrupt the coverage metric with derive-and-blanket boilerplate and pull in
/// method names (`clone`, `eq`, `fmt`, `next`) that are not the crate's surface.
///
/// This is ONE central, versioned policy list — never a per-crate overlay knob,
/// so the metric stays comparable across crates and the ratchet stays ungameable
/// (D1). Matched on the trait's SIMPLE (final path segment) name, so a crate-local
/// trait that happens to share a std name is treated the same (acceptably rare and
/// still noise-shaped). Everything NOT here is SEMANTIC and gets flattened.
const NOISE_TRAITS: &[&str] = &[
    // formatting / debug
    "Debug",
    "Display",
    "Binary",
    "Octal",
    "LowerHex",
    "UpperHex",
    "LowerExp",
    "UpperExp",
    "Pointer",
    "Write",
    // clone / copy / default / drop / ownership markers
    "Clone",
    "CloneToUninit",
    "Copy",
    "Default",
    "Drop",
    "ToOwned",
    // conversions (mechanical, not crate semantics)
    "From",
    "Into",
    "TryFrom",
    "TryInto",
    "AsRef",
    "AsMut",
    "Borrow",
    "BorrowMut",
    "ToString",
    // equality / ordering / hashing
    "PartialEq",
    "Eq",
    "StructuralPartialEq",
    "PartialOrd",
    "Ord",
    "Hash",
    // parsing — `FromStr::from_str` is re-admitted by the dedicated FromStr lane
    // (a fully-qualified `<T as ::std::str::FromStr>::from_str` static), so the
    // generic trait-flatten must NOT also emit an (unusable, private-path) `use`.
    "FromStr",
    // auto / marker traits
    "Send",
    "Sync",
    "Unpin",
    "Sized",
    "Any",
    "Freeze",
    "RefUnwindSafe",
    "UnwindSafe",
    "UnsafeUnpin",
    "Error",
    // serde
    "Serialize",
    "Deserialize",
    // deref / index (transparent access, not API)
    "Deref",
    "DerefMut",
    "Index",
    "IndexMut",
    // iteration (blanket-default heavy — ~80 provided defaults on Iterator alone)
    "Iterator",
    "IntoIterator",
    "DoubleEndedIterator",
    "ExactSizeIterator",
    "FusedIterator",
    // operators (std::ops)
    "Add",
    "Sub",
    "Mul",
    "Div",
    "Rem",
    "Neg",
    "Not",
    "BitAnd",
    "BitOr",
    "BitXor",
    "Shl",
    "Shr",
    "AddAssign",
    "SubAssign",
    "MulAssign",
    "DivAssign",
    "RemAssign",
    "BitAndAssign",
    "BitOrAssign",
    "BitXorAssign",
    "ShlAssign",
    "ShrAssign",
    "Fn",
    "FnMut",
    "FnOnce",
];

/// Classify a crate's public API with no overlay hints. Equivalent to
/// [`classify_with_overlay`] with `None`.
pub fn classify(doc: &Crate) -> BridgeSpec {
    classify_with_overlay(doc, None)
}

/// Classify a crate's public API, letting an overlay's `treat_as` directives
/// steer classification while the raw rustdoc is still in hand. `treat_as` is the
/// one overlay directive that must run *during* classify — it forces a method
/// onto a specific rule (or off the bridge entirely), which cannot be
/// reconstructed post-hoc from a [`BridgeSpec`]. Every other directive (skip,
/// rename, inject, module, monomorphize) is applied afterwards by
/// [`crate::apply_overlay`]. Pass the SAME overlay to both.
pub fn classify_with_overlay(doc: &Crate, overlay: Option<&Overlay>) -> BridgeSpec {
    let module_name = doc.index[&doc.root].name.clone().unwrap_or_default();
    let crate_version = doc.crate_version.clone().unwrap_or_else(|| "0.0.0".into());

    let mut ctx = Ctx {
        doc,
        overlay,
        module_name: module_name.clone(),
        skips: vec![],
        dropped: vec![],
        pending_wrappers: vec![],
        inherited_excluded: 0,
        ref_type_names: HashSet::new(),
        root_reexports: collect_root_reexports(doc),
        root_glob_modules: collect_root_glob_modules(doc, &module_name),
        wide_record_ids: std::cell::RefCell::new(vec![]),
        qual_stack: std::cell::RefCell::new(vec![]),
    };

    let mut types = ctx.find_types();
    // 1.2.4: the set of non-mono opaque type names, so a method return naming
    // another bridged type (`NaiveDate::and_hms -> NaiveDateTime`) classifies as a
    // cross-type owned handle. Built before method classification (types are all
    // known after `find_types`); mono types are excluded (their return path reads as
    // the generic origin and needs the instantiation check `returns_self` does).
    ctx.ref_type_names = types
        .iter()
        .filter(|t| t.mono.is_none() && t.kind == TypeKind::Opaque)
        .map(|t| t.name.clone())
        .collect();
    for bt in &mut types {
        ctx.classify_impl(bt);
    }

    // A cross-type handle return (`Ref`/`OptRef`, 1.2.4) may name a type that —
    // after its own methods are classified — has NO bridgeable surface: no ctor,
    // no method, no injected source (uuid's `Uuid::get_timestamp -> Option<Timestamp>`,
    // where `Timestamp`'s whole API is closures/unsupported types). codegen drops
    // such a dead-opaque type, so a surviving return to it would reference an
    // undeclared wrapper and the macro rejects the crate. `ref_type_names` is built
    // optimistically before classification and can't foresee this, so reconcile now:
    // demote any return to a would-be-dropped type into an honest skip, iterating to
    // a fixpoint (removing a type's last method can make IT dead in turn).
    reconcile_ref_returns(&mut types, &mut ctx.skips);

    // A fallible `-> Result<Self, E>` method/ctor lowers to `Result<Self, String>`,
    // which the macro rejects unless the module declares a `#[jac_error]` type —
    // and the module gets one only when some bridged type is itself an error
    // (`TypeKind::Error`). A crate with fallible constructors but NO detected error
    // type (sha2's `Sha256VarCore::new(usize) -> Result<Self, _>`, whose error lives
    // in an un-bridged external crate) would emit an uncompilable Result return.
    // Demote those to honest skips so the emitted crate always compiles.
    reconcile_fallible_returns(&mut types, &mut ctx.skips);

    // Materialize synthesized owning wrappers (M4 Phase B v1). The same wrapper
    // can be requested by several producers — a ROOT producer (`Regex::find`) and
    // a NESTED one (`OwnedCaptures::name`) both yield `OwnedMatch`. Merge requests
    // by borrowed type so the wrapper is emitted once, keeping a root construction
    // path if ANY requester has one and unioning readers/skips. Encounter order is
    // preserved for deterministic output. Reader-skips land in the global skip list.
    let mut order: Vec<u32> = vec![];
    let mut merged: HashMap<u32, PendingWrapper> = HashMap::new();
    for pw in std::mem::take(&mut ctx.pending_wrappers) {
        match merged.get_mut(&pw.borrowed_id) {
            None => {
                order.push(pw.borrowed_id);
                merged.insert(pw.borrowed_id, pw);
            }
            Some(existing) => existing.merge(pw),
        }
    }
    for id in order {
        let pw = merged.remove(&id).unwrap();
        ctx.skips.extend(pw.reader_skips);
        types.push(BridgeType {
            name: pw.wrapper_name,
            kind: TypeKind::Opaque,
            inner_path: pw.wrapper.borrowed_path.clone(),
            // Synthesized wrappers have no source submodule; leave provenance
            // empty so a `[module]` skip never drops them.
            module_path: vec![],
            item_id: pw.borrowed_id,
            ctor: None,
            methods: pw.readers,
            injected_source: vec![],
            wrapper: Some(pw.wrapper),
            mono: None,
            // A synthesized ouroboros wrapper is not a wire-crossable value.
            serde: SerdeInfo::default(),
            force_wide: None,
        });
    }
    sort_types(&mut types);

    ctx.dropped.sort_by(|a, b| a.name.cmp(&b.name));
    let records = ctx.build_wide_records();
    BridgeSpec {
        module_name,
        crate_version,
        crate_features: overlay.map(|o| o.features().to_vec()).unwrap_or_default(),
        types,
        records,
        skips: ctx.skips,
        dropped: ctx.dropped,
        inherited_excluded: ctx.inherited_excluded,
    }
}

/// Map each item id to the name it is `pub use`-re-exported under in the crate
/// ROOT module (`pub use non_nil::NonNilUuid;` → `129 → "NonNilUuid"`). Only the
/// root is scanned: it is the overwhelmingly common re-export site and gives the
/// shortest public path (`crate::Name`), which is guaranteed to compile even when
/// the definition module is private. Glob and primitive (`id: None`) re-exports
/// are ignored.
fn collect_root_reexports(doc: &Crate) -> HashMap<u32, String> {
    let mut map = HashMap::new();
    let Some(root) = doc.index.get(&doc.root) else {
        return map;
    };
    let ItemEnum::Module(m) = &root.inner else {
        return map;
    };
    for item_id in &m.items {
        if let Some(item) = doc.index.get(item_id) {
            if let ItemEnum::Use(u) = &item.inner {
                if !u.is_glob {
                    if let Some(target) = &u.id {
                        map.entry(target.0).or_insert_with(|| u.name.clone());
                    }
                }
            }
        }
    }
    map
}

/// The module paths the crate root re-exports with a glob (`pub use
/// crate::regex::string::*;`). Returned as crate-root-stripped `::`-joined strings
/// (`"regex::string"`) so they can be compared against a type's `module_path`. A
/// type in such a module is reachable at the crate root under its own name.
fn collect_root_glob_modules(doc: &Crate, module_name: &str) -> HashSet<String> {
    let mut set = HashSet::new();
    let Some(root) = doc.index.get(&doc.root) else {
        return set;
    };
    let ItemEnum::Module(m) = &root.inner else {
        return set;
    };
    for item_id in &m.items {
        if let Some(item) = doc.index.get(item_id) {
            if let ItemEnum::Use(u) = &item.inner {
                if u.is_glob {
                    // `source` is the module path with a `crate::` prefix (own-crate
                    // re-export) or a `<crate>::` prefix (external). Strip just the
                    // crate root — NOT `crate::<module_name>::`, since a crate often
                    // has a submodule sharing its own name (`crate::regex::string`
                    // in the `regex` crate) — so the remainder lines up with a
                    // type's crate-relative `module_path` (`["regex","string"]`).
                    let rel = u
                        .source
                        .strip_prefix("crate::")
                        .or_else(|| u.source.strip_prefix(&format!("{module_name}::")))
                        .unwrap_or(&u.source);
                    set.insert(rel.to_string());
                }
            }
        }
    }
    set
}

/// The bridged type a `Ref`/`OptRef` return points at, if any. Other returns
/// (scalars, `Self`, bytes, synthesized wrappers — which always carry readers)
/// never dangle, so they are `None` here.
fn ref_return_target(ret: &BridgeReturn) -> Option<&str> {
    match ret {
        BridgeReturn::Ref(n)
        | BridgeReturn::OptRef(n)
        | BridgeReturn::RefResult(n)
        | BridgeReturn::HandleList(n) => Some(n.as_str()),
        _ => None,
    }
}

/// True when a trait-flattened STATIC (1.3) can't be emitted because its trait's
/// public `use` path is unrecoverable. `trait_use_path` resolves an external
/// trait as `{module}::{defining_crate}::{Trait}`, which is correct when the
/// bridged crate re-exports its dependency (sha2 re-exports `digest` as
/// `sha2::digest`), but WRONG for a std trait (`FromStr`) — `core`/`alloc`/`std`
/// are never re-exported under the bridged crate, and rustdoc's canonical path
/// (`core::str::traits::FromStr`) traverses a private module, so no reliable
/// public path exists. A static needs its trait in scope for the
/// `<Inner as Trait>::fn` call, so an unusable path means an honest skip rather
/// than an unresolved-import in the generated crate. (An ordinary trait-flattened
/// *method* uses UFCS through the same path and would share this hazard, but no
/// std semantic trait's methods currently reach codegen; statics are the first to
/// surface it, via `-> Self` factories like `Regex::from_str`.)
fn static_trait_path_unusable(via_trait: &Option<String>) -> bool {
    let Some(path) = via_trait else {
        return false;
    };
    let segs: Vec<&str> = path.split("::").collect();
    // In-crate trait: `{module}::{Trait}` (2 segments) — always usable.
    // External:        `{module}::{defining_crate}::{Trait}` — usable unless the
    // defining crate is the std family, which the module never re-exports.
    segs.len() >= 3 && matches!(segs[1], "core" | "alloc" | "std")
}

/// Mirror of codegen's dead-opaque test: an opaque type with no constructor, no
/// method, and no injected source is never emitted (codegen skips it to stay
/// warning-clean), so it must not be a live `Ref`/`OptRef` target. Kept in sync
/// with `codegen::is_dead_opaque`.
fn is_dead_opaque_ty(t: &BridgeType) -> bool {
    t.kind == TypeKind::Opaque
        && t.ctor.is_none()
        && t.methods.is_empty()
        && t.injected_source.is_empty()
}

/// Demote every `Ref`/`OptRef` method return that names a type codegen will drop
/// (dead-opaque) into a skip, so the emitted source never references an undeclared
/// wrapper. Iterated to a fixpoint: stripping a type's last surviving method can
/// itself make that type dead, invalidating a return elsewhere.
fn reconcile_ref_returns(types: &mut [BridgeType], skips: &mut Vec<Skip>) {
    loop {
        let live: HashSet<String> = types
            .iter()
            .filter(|t| !is_dead_opaque_ty(t))
            .map(|t| t.name.clone())
            .collect();
        let mut changed = false;
        for bt in types.iter_mut() {
            let mut kept = Vec::with_capacity(bt.methods.len());
            for m in std::mem::take(&mut bt.methods) {
                match ref_return_target(&m.ret) {
                    Some(target) if !live.contains(target) => {
                        skips.push(Skip {
                            item: format!("{}::{}", bt.name, m.name),
                            reason: SkipReason::UnsupportedType(format!(
                                "cross-type return to unbridged type ({target})"
                            )),
                        });
                        changed = true;
                    }
                    _ => kept.push(m),
                }
            }
            bt.methods = kept;
        }
        if !changed {
            break;
        }
    }
}

/// A fallible return the macro can only lower when a `#[jac_error]` type exists.
fn is_fallible_return(ret: &BridgeReturn) -> bool {
    matches!(
        ret,
        BridgeReturn::OwnSelfResult | BridgeReturn::RefResult(_)
    )
}

/// Demote every `Result<Self, E>` ctor/method to a skip when the crate has NO
/// bridged error type — the macro would otherwise reject the `Result` return for
/// lack of a `#[jac_error]` struct. A crate WITH an error type keeps them (the
/// error crosses Display-stringified). Mirrors `reconcile_ref_returns`.
fn reconcile_fallible_returns(types: &mut [BridgeType], skips: &mut Vec<Skip>) {
    if types.iter().any(|t| t.kind == TypeKind::Error) {
        return;
    }
    let reason = || {
        SkipReason::UnsupportedType("fallible return but crate has no bridged error type".into())
    };
    for bt in types.iter_mut() {
        if let Some(c) = &bt.ctor {
            if is_fallible_return(&c.ret) {
                skips.push(Skip {
                    item: format!("{}::{}", bt.name, c.name),
                    reason: reason(),
                });
                bt.ctor = None;
            }
        }
        let name = bt.name.clone();
        let mut kept = Vec::with_capacity(bt.methods.len());
        for m in std::mem::take(&mut bt.methods) {
            if is_fallible_return(&m.ret) {
                skips.push(Skip {
                    item: format!("{name}::{}", m.name),
                    reason: reason(),
                });
            } else {
                kept.push(m);
            }
        }
        bt.methods = kept;
    }
}

/// Deterministic type order: opaque types first, then error types, each by name.
fn sort_types(types: &mut [BridgeType]) {
    types.sort_by(|a, b| {
        let k = |t: &BridgeType| match t.kind {
            TypeKind::Opaque => 0u8,
            TypeKind::Error => 1,
        };
        k(a).cmp(&k(b)).then(a.name.cmp(&b.name))
    });
}

/// A wrapper synthesis request, deferred until after all owner types are walked.
struct PendingWrapper {
    wrapper_name: String,
    borrowed_id: u32,
    wrapper: OwningWrapper,
    readers: Vec<BridgeFn>,
    reader_skips: Vec<Skip>,
}

impl PendingWrapper {
    /// Fold another request for the SAME borrowed type into this one: adopt a root
    /// construction path if we lack one (a nested-only request has `root: None`, a
    /// root producer supplies it), and union readers/skips by name so the wrapper's
    /// full surface is emitted exactly once. Sorted for deterministic output.
    fn merge(&mut self, other: PendingWrapper) {
        if self.wrapper.root.is_none() {
            self.wrapper.root = other.wrapper.root;
        }
        for r in other.readers {
            if !self.readers.iter().any(|x| x.name == r.name) {
                self.readers.push(r);
            }
        }
        for s in other.reader_skips {
            if !self.reader_skips.iter().any(|x| x.item == s.item) {
                self.reader_skips.push(s);
            }
        }
        self.readers.sort_by(|a, b| a.name.cmp(&b.name));
        self.reader_skips.sort_by(|a, b| a.item.cmp(&b.item));
    }
}

struct Ctx<'a> {
    doc: &'a Crate,
    /// Overlay whose `treat_as` directives steer classification, if supplied.
    overlay: Option<&'a Overlay>,
    module_name: String,
    skips: Vec<Skip>,
    /// Whole types dropped before method classification — see [`BridgeSpec::dropped`].
    dropped: Vec<DroppedType>,
    pending_wrappers: Vec<PendingWrapper>,
    /// Unresolvable trait-provided defaults excluded from the denominator (D1).
    /// See [`BridgeSpec::inherited_excluded`].
    inherited_excluded: usize,
    /// Names of the NON-monomorphized opaque types that will be emitted (built from
    /// `find_types()` before method classification). A return whose path names one
    /// of these (and isn't the method's own `Self`) is a cross-type owned handle
    /// (1.2.4, `BridgeReturn::Ref`/`OptRef`). Mono types are excluded: their return
    /// path reads as the generic origin name (`Date`) and would need the same
    /// instantiation check `returns_self` does, deferred with the rest of the mono
    /// surface.
    ref_type_names: HashSet<String>,
    /// Item id → the name it is `pub use`-re-exported under at the crate root.
    /// A type defined in a PRIVATE module (`uuid::non_nil::NonNilUuid`) is only
    /// reachable through its root re-export (`uuid::NonNilUuid`); the canonical
    /// path from `doc.paths` traverses the private module and won't compile. When
    /// present, this shortest public path wins over the canonical one.
    root_reexports: HashMap<u32, String>,
    /// Module paths (crate-root and glob stripped, `"regex::string"`) that the
    /// crate root re-exports with a glob (`pub use crate::regex::string::*;`).
    /// Every pub item in such a module is reachable at the crate root under its
    /// own name, so a type whose defining module is glob-re-exported keeps the
    /// flat `crate::Type` path even though its canonical path is deeper
    /// (`regex::regex::string::Regex`).
    root_glob_modules: HashSet<String>,
    /// Rustdoc ids of the derived-record structs a wide slot resolved to a TYPED
    /// record (2.9), in first-seen order, deduplicated. Collected during method
    /// classification (via `&self` wide-slot resolution, hence the interior
    /// mutability) and turned into [`BridgeSpec::records`] afterwards. A struct
    /// lands here only when it passes `record_qualifies`' gate — derived serde,
    /// no stripped fields, and every field admissible (scalar/String, a nested
    /// qualifying record, or a container of those). Nested records are registered
    /// transitively (2.9-followup).
    wide_record_ids: std::cell::RefCell<Vec<u32>>,
    /// Record ids currently on the `record_qualifies` recursion stack — the cycle
    /// guard for a self-referential serde type (e.g. a tree `Node { kids:
    /// Vec<Node> }`). A re-entered id is assumed to qualify (the enclosing frame
    /// does the real field check), so the recursion terminates.
    qual_stack: std::cell::RefCell<Vec<u32>>,
}

impl<'a> Ctx<'a> {
    fn item(&self, id: &Id) -> Option<&'a Item> {
        self.doc.index.get(id)
    }

    // ── Phase 1: find bridgeable types ────────────────────────────────────────

    fn find_types(&mut self) -> Vec<BridgeType> {
        // Walk paths, keeping only own-crate items.  When the same type is
        // re-exported at multiple depths (bytes:: and string:: variants, etc.)
        // keep the shallowest path so we get one canonical entry per name.
        // Value carries the winning sort key, the item, and the module segments the
        // winning path declared it under (crate root and type name stripped) — the
        // provenance an overlay `[module."m"] skip` consults.
        //
        // The sort key is a TOTAL order so the winner among equal-depth duplicates
        // is deterministic and correct, not HashMap-iteration-order dependent:
        //   (depth, bytes_penalty, impl_deficit, id)
        // Lower wins. `impl_deficit` (usize::MAX - impl count) prefers the item that
        // actually carries the inherent/trait impls — a re-export stub and the real
        // definition can share a name and depth, but only the definition has the
        // `impl std::error::Error` / method list; picking the stub silently loses
        // error typing and methods (and, before this key, did so at random). `id`
        // is the final, always-unique tiebreak.
        type SortKey = (usize, usize, usize, u32);
        type Candidate<'b> = (SortKey, &'b Item, Vec<String>);
        let mut by_name: HashMap<String, Candidate<'a>> = HashMap::new();

        for (id, path_entry) in &self.doc.paths {
            if path_entry.path.first().map(|s| s.as_str()) != Some(&self.module_name) {
                continue;
            }
            let Some(item) = self.doc.index.get(id) else {
                continue;
            };
            let name = item.name.clone().unwrap_or_default();
            if name.is_empty() {
                continue;
            }
            let depth = path_entry.path.len();
            let bytes_pen = if path_entry.path.iter().any(|s| s == "bytes") {
                1usize
            } else {
                0
            };
            let impls = match &item.inner {
                ItemEnum::Struct(s) => s.impls.len(),
                ItemEnum::Enum(e) => e.impls.len(),
                _ => 0,
            };
            let key: SortKey = (depth, bytes_pen, usize::MAX - impls, id.0);
            // Module segments: drop the leading crate name and the trailing type
            // name. `["regex","error","Error"]` -> `["error"]`.
            let module_path: Vec<String> = if path_entry.path.len() >= 2 {
                path_entry.path[1..path_entry.path.len() - 1].to_vec()
            } else {
                vec![]
            };
            let worst: SortKey = (usize::MAX, usize::MAX, usize::MAX, u32::MAX);
            let entry = by_name
                .entry(name)
                .or_insert((worst, item, module_path.clone()));
            if key < entry.0 {
                *entry = (key, item, module_path);
            }
        }

        let mut out: Vec<BridgeType> = vec![];
        for (_key, item, module_path) in by_name.into_values() {
            out.extend(self.classify_type(item, module_path));
        }

        sort_types(&mut out);
        out
    }

    /// The path a generated newtype should wrap, resolved to the SHORTEST path
    /// that actually compiles (never the raw `doc.paths` canonical path, which can
    /// traverse private modules). In priority order:
    ///   1. a named crate-root re-export (`pub use non_nil::NonNilUuid;`) — the only
    ///      valid path when the defining module is private;
    ///   2. a crate-root definition or a glob-re-exported module — flat `crate::Type`;
    ///   3. otherwise the (public) defining submodule, `crate::mod::Type`
    ///      (`uuid::fmt::Simple`).
    fn accessible_type_path(&self, item_id: u32, module_path: &[String], name: &str) -> String {
        if let Some(alias) = self.root_reexports.get(&item_id) {
            return format!("{}::{}", self.module_name, alias);
        }
        if module_path.is_empty() || self.root_glob_modules.contains(&module_path.join("::")) {
            return format!("{}::{}", self.module_name, name);
        }
        format!("{}::{}::{}", self.module_name, module_path.join("::"), name)
    }

    fn classify_type(&mut self, item: &'a Item, module_path: Vec<String>) -> Vec<BridgeType> {
        let Some(name) = item.name.clone() else {
            return vec![];
        };
        // The newtype wraps the type at its CANONICAL path. A type defined in a
        // submodule (`uuid::fmt::Simple`, `uuid::non_nil::NonNilUuid`) is NOT
        // reachable as `crate::Type` unless separately re-exported, so fold the
        // module segments (`find_types` already stripped the crate root and type
        // name) into the path — else the generated `pub struct S(pub uuid::S);`
        // names a nonexistent path. Crate-root, root-re-exported, and
        // glob-re-exported types keep the flat `crate::Type`; only a type reachable
        // ONLY through its (public) defining submodule (`uuid::fmt::Simple`) gets
        // the qualified path.
        let item_id = item.id.0;
        let inner_path = self.accessible_type_path(item_id, &module_path, &name);

        match &item.inner {
            ItemEnum::Struct(s) => {
                // A struct is an opaque handle only if it has private/hidden state
                // — a caller can't construct it field-by-field, so it must cross as
                // a boxed newtype driven through methods. A struct with only public
                // fields is transparent data (a wide-lane serde candidate), not a
                // handle, so it's left for that lane.
                //
                //  - Plain `{ .. }` structs: the `has_stripped_fields` flag.
                //  - Tuple structs: a stripped field renders as `None` in the field
                //    list (rustdoc emits private/hidden positions as `None` to keep
                //    order). A single-field tuple with a private inner is the newtype
                //    pattern — `uuid::Uuid([u8; 16])` renders as `Tuple([None])` —
                //    and is the entire uuid fix.
                let has_hidden = match &s.kind {
                    StructKind::Plain {
                        has_stripped_fields,
                        ..
                    } => *has_stripped_fields,
                    StructKind::Tuple(fields) => fields.len() == 1 && fields[0].is_none(),
                    StructKind::Unit => false,
                };
                // An overlay `[type."T"] treat_as = "opaque"` forces an
                // all-public-field struct through as a boxed handle — the escape
                // hatch for a type whose API lives in methods, not fields
                // (`semver::Version`, `VersionReq`). Without it such a struct is
                // transparent data left for the wide (serde) lane.
                let forced_opaque = self
                    .overlay
                    .and_then(|o| o.types.get(&name))
                    .and_then(|t| t.treat_as.as_deref())
                    == Some("opaque");
                if !has_hidden && !forced_opaque {
                    // A public-field struct that ALSO carries inherent methods and
                    // no serde impl is real API that would otherwise vanish with no
                    // trace (neither bridged, skipped, nor dropped). Record the drop
                    // so coverage stays honest and `jac add` can hint `treat_as =
                    // "opaque"`. Pure serde-data structs are correctly wide-laned, so
                    // they are left silent.
                    let s = self.serde_disposition(item_id);
                    if !s.serialize && !s.deserialize && self.has_inherent_methods(item_id) {
                        self.dropped.push(DroppedType {
                            name,
                            reason: DropReason::TransparentData,
                        });
                    }
                    return vec![];
                }
                // Types with lifetime params can't be stored in Box<T> — drop them.
                // This excludes cursor types like Match<'h>, Captures<'m,'h>, etc.
                let has_lifetime =
                    s.generics.params.iter().any(|p| {
                        matches!(p.kind, rustdoc_types::GenericParamDefKind::Lifetime { .. })
                    });
                if has_lifetime {
                    self.dropped.push(DroppedType {
                        name,
                        reason: DropReason::Lifetime,
                    });
                    return vec![];
                }
                // A const-generic struct can't be bridged (the const arg is unknown
                // and there's no directive to pin it) — drop it rather than emit an
                // uncompilable `T(pub crate::T)`.
                let has_const =
                    s.generics.params.iter().any(|p| {
                        matches!(p.kind, rustdoc_types::GenericParamDefKind::Const { .. })
                    });
                if has_const {
                    self.dropped.push(DroppedType {
                        name,
                        reason: DropReason::ConstGeneric,
                    });
                    return vec![];
                }
                // A type-generic struct likewise can't cross as a bare newtype — its
                // type arg is unknown. An overlay `monomorphize` directive pins one
                // or more concrete instantiations; absent that, drop it.
                let type_params: Vec<String> = s
                    .generics
                    .params
                    .iter()
                    .filter_map(|p| match &p.kind {
                        rustdoc_types::GenericParamDefKind::Type { .. } => Some(p.name.clone()),
                        _ => None,
                    })
                    .collect();
                if !type_params.is_empty() {
                    let monos =
                        self.monomorphize_struct(&name, &type_params, item_id, &module_path);
                    if monos.is_empty() {
                        // No `monomorphize` overlay pinned it (or the single-param rule
                        // couldn't apply) — record the drop so coverage stays honest.
                        self.dropped.push(DroppedType {
                            name,
                            reason: DropReason::UnpinnedGeneric,
                        });
                    }
                    return monos;
                }
                let kind = if self.is_error_type(&name, item_id) {
                    TypeKind::Error
                } else {
                    TypeKind::Opaque
                };
                vec![BridgeType {
                    name,
                    kind,
                    inner_path,
                    module_path,
                    item_id,
                    ctor: None,
                    methods: vec![],
                    injected_source: vec![],
                    wrapper: None,
                    mono: None,
                    serde: self.serde_disposition(item_id),
                    force_wide: None,
                }]
            }
            ItemEnum::Enum(_) if self.is_error_type(&name, item_id) => vec![BridgeType {
                name,
                kind: TypeKind::Error,
                inner_path,
                module_path,
                item_id,
                ctor: None,
                methods: vec![],
                injected_source: vec![],
                wrapper: None,
                mono: None,
                serde: self.serde_disposition(item_id),
                force_wide: None,
            }],
            _ => vec![],
        }
    }

    /// Expand a generic struct into its pinned monomorphizations, or drop it if no
    /// `[type."T"] monomorphize = [..]` directive applies. Only a single type
    /// param can be pinned (a multi-param struct has no unambiguous single-suffix
    /// naming); each concrete type in the list yields one opaque bridged type
    /// named `T<Suffix>` wrapping `crate::T<concrete>`. All variants share the
    /// original struct's item id so `classify_impl` finds the same impl list, and
    /// carry a [`MonoType`] so classification substitutes the generic param.
    fn monomorphize_struct(
        &self,
        name: &str,
        type_params: &[String],
        item_id: u32,
        module_path: &[String],
    ) -> Vec<BridgeType> {
        let Some(concretes) = self
            .overlay
            .and_then(|o| o.types.get(name))
            .and_then(|t| t.monomorphize.as_ref())
        else {
            return vec![];
        };
        // Only a lone type param is pinnable, and an empty set pins nothing.
        if type_params.len() != 1 || concretes.is_empty() {
            return vec![];
        }
        let generic = &type_params[0];
        concretes
            .iter()
            .map(|c| {
                // Suffix from the concrete type's last path segment, generics
                // stripped: `chrono::Utc` -> `Utc`, `foo::Bar<T>` -> `Bar`.
                let leaf = c.rsplit("::").next().unwrap_or(c);
                let leaf = leaf.split('<').next().unwrap_or(leaf);
                BridgeType {
                    name: format!("{name}{}", to_camel(leaf)),
                    kind: TypeKind::Opaque,
                    inner_path: format!(
                        "{}<{}>",
                        self.accessible_type_path(item_id, module_path, name),
                        c
                    ),
                    module_path: module_path.to_vec(),
                    item_id,
                    ctor: None,
                    methods: vec![],
                    injected_source: vec![],
                    wrapper: None,
                    mono: Some(MonoType {
                        origin_name: name.to_string(),
                        generic_param: generic.clone(),
                        concrete: c.clone(),
                    }),
                    // The generic origin's serde impl (`impl<Tz> Serialize for
                    // DateTime<Tz>`) applies to each instantiation; item_id is
                    // shared, so detect against it.
                    serde: self.serde_disposition(item_id),
                    force_wide: None,
                }
            })
            .collect()
    }

    /// Whether a type should be bridged as an error, in priority order:
    ///   1. an overlay `[type."T"] treat_as = "error" | "opaque"` override,
    ///   2. an `impl std::error::Error for T` (the authoritative signal),
    ///   3. the `*Error` name-suffix heuristic (last resort — many error types
    ///      are not named `*Error`, and a domain type can be named `…Error`
    ///      without being one, so name is only a fallback).
    fn is_error_type(&self, name: &str, item_id: u32) -> bool {
        if let Some(over) = self.overlay.and_then(|o| o.types.get(name)) {
            match over.treat_as.as_deref() {
                Some("error") => return true,
                Some("opaque") => return false,
                _ => {}
            }
        }
        self.implements_error_trait(item_id) || name.ends_with("Error")
    }

    /// True if the struct/enum with `item_id` implements the standard-library
    /// `Error` trait (canonically `core::error::Error`, re-exported as
    /// `std::error::Error`).
    ///
    /// The impl'd trait's id is resolved through rustdoc's `paths` table and the
    /// CANONICAL path is checked, so a crate-local trait that merely happens to be
    /// named `Error` (or `mycrate::Error`) is not mistaken for the std one. When
    /// the trait id has no `paths` summary — rare, a fully external trait rustdoc
    /// did not index — it falls back to the fully-qualified display path and never
    /// to a bare `Error`, keeping the check conservative; the overlay `treat_as`
    /// remains the authoritative override either way.
    fn implements_error_trait(&self, item_id: u32) -> bool {
        let Some(item) = self.doc.index.get(&Id(item_id)) else {
            return false;
        };
        let impls = match &item.inner {
            ItemEnum::Struct(s) => &s.impls,
            ItemEnum::Enum(e) => &e.impls,
            _ => return false,
        };
        impls.iter().any(|impl_id| {
            let Some(impl_item) = self.item(impl_id) else {
                return false;
            };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else {
                return false;
            };
            impl_block
                .trait_
                .as_ref()
                .map(|t| self.is_std_error_path(t))
                .unwrap_or(false)
        })
    }

    /// Whether the bridged type implements `Clone` (1.2.2). A consuming-`self`
    /// method (`Digest::finalize(self)`) is lowered as `self.0.clone().finalize()`,
    /// which only compiles when the newtype's inner value is `Clone`; a non-`Clone`
    /// consuming method stays a visible skip instead of a broken move-out-of-borrow.
    /// Scans the type's own impl list for a `core::clone::Clone` (or a derived
    /// `Clone`) impl, mirroring [`Self::implements_error_trait`].
    fn type_is_clone(&self, bt: &BridgeType) -> bool {
        let Some(item) = self.doc.index.get(&Id(bt.item_id)) else {
            return false;
        };
        let impls = match &item.inner {
            ItemEnum::Struct(s) => &s.impls,
            ItemEnum::Enum(e) => &e.impls,
            _ => return false,
        };
        impls.iter().any(|impl_id| {
            let Some(impl_item) = self.item(impl_id) else {
                return false;
            };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else {
                return false;
            };
            impl_block
                .trait_
                .as_ref()
                .map(|t| rp_name(&t.path) == "Clone")
                .unwrap_or(false)
        })
    }

    /// Whether a trait reference resolves to `core`/`std` `::error::Error`.
    fn is_std_error_path(&self, tr: &rustdoc_types::Path) -> bool {
        // Prefer the canonical path from rustdoc's `paths` index (precise).
        if let Some(summary) = self.doc.paths.get(&tr.id) {
            let p = &summary.path;
            return p.len() >= 3
                && p[p.len() - 1] == "Error"
                && p[p.len() - 2] == "error"
                && matches!(p.first().map(|s| s.as_str()), Some("core" | "std"));
        }
        // Fallback for an unindexed trait: accept only a fully-qualified display
        // path, never a bare `Error`, so a crate-local `Error` trait is not misread.
        matches!(tr.path.as_str(), "std::error::Error" | "core::error::Error")
    }

    // ── serde detection (2.3) ─────────────────────────────────────────────────

    /// The serde-trait presence on the struct/enum with `item_id` — mirrors
    /// [`Self::serde_disposition`]'s twin [`Self::implements_error_trait`]. Walks
    /// the type's impl list once, unioning `Serialize`/`Deserialize` and noting
    /// whether ANY of those impls is `#[automatically_derived]` (a `#[derive]`,
    /// whose wire shape is the rustdoc field list — 2.9). A non-struct/enum item,
    /// or one absent from the index, is all-false.
    fn serde_disposition(&self, item_id: u32) -> SerdeInfo {
        let Some(item) = self.doc.index.get(&Id(item_id)) else {
            return SerdeInfo::default();
        };
        let impls = match &item.inner {
            ItemEnum::Struct(s) => &s.impls,
            ItemEnum::Enum(e) => &e.impls,
            _ => return SerdeInfo::default(),
        };
        let mut info = SerdeInfo::default();
        for impl_id in impls {
            let Some(impl_item) = self.item(impl_id) else {
                continue;
            };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else {
                continue;
            };
            let Some(tr) = impl_block.trait_.as_ref() else {
                continue;
            };
            let is_ser = self.is_serde_trait_path(tr, SerdeTrait::Serialize);
            let is_de = self.is_serde_trait_path(tr, SerdeTrait::Deserialize);
            if !is_ser && !is_de {
                continue;
            }
            info.serialize |= is_ser;
            info.deserialize |= is_de;
            if impl_item
                .attrs
                .iter()
                .any(|a| matches!(a, Attribute::AutomaticallyDerived))
            {
                info.automatically_derived = true;
            }
        }
        info
    }

    /// True if the type has at least one inherent (`impl T`, no trait) method —
    /// i.e. real API that would be lost if the type is filtered out as transparent
    /// data. Used only to keep the drop report honest (see `classify_type`).
    fn has_inherent_methods(&self, item_id: u32) -> bool {
        let Some(item) = self.doc.index.get(&Id(item_id)) else {
            return false;
        };
        let impls = match &item.inner {
            ItemEnum::Struct(s) => &s.impls,
            ItemEnum::Enum(e) => &e.impls,
            _ => return false,
        };
        impls.iter().any(|impl_id| {
            let Some(impl_item) = self.item(impl_id) else {
                return false;
            };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else {
                return false;
            };
            impl_block.trait_.is_none()
                && impl_block.items.iter().any(|iid| {
                    matches!(
                        self.item(iid).map(|i| &i.inner),
                        Some(ItemEnum::Function(_))
                    )
                })
        })
    }

    /// Whether a trait reference resolves to serde's `Serialize`/`Deserialize`.
    ///
    /// serde ≥ 1.0.220 split its trait/derive core into a `serde_core` crate, so
    /// the CANONICAL path is now `serde_core::ser::Serialize` (`serde::Serialize`
    /// is a re-export) — matching only the `serde::` root finds NOTHING on any
    /// current crate. Both roots are accepted, checked against the precise
    /// `paths` summary first (so a crate-local trait merely named `Serialize`
    /// isn't mistaken for serde's), then a fully-qualified display-path fallback
    /// for an unindexed trait — never a bare `Serialize`.
    fn is_serde_trait_path(&self, tr: &rustdoc_types::Path, which: SerdeTrait) -> bool {
        if let Some(summary) = self.doc.paths.get(&tr.id) {
            let p = &summary.path;
            return p.len() >= 3
                && p[p.len() - 1] == which.leaf()
                && p[p.len() - 2] == which.module()
                && matches!(p.first().map(|s| s.as_str()), Some("serde" | "serde_core"));
        }
        // Fallback for an unindexed trait: accept only a fully-qualified display
        // path (either root, either module spelling), never a bare name.
        let m = which.module();
        let leaf = which.leaf();
        matches!(
            tr.path.as_str(),
            p if p == format!("serde::{m}::{leaf}")
                || p == format!("serde_core::{m}::{leaf}")
                || p == format!("serde::{leaf}")
                || p == format!("serde_core::{leaf}")
        )
    }

    /// The external-type structural whitelist for the wide (msgpack) lane (2.3).
    ///
    /// rustdoc only indexes the LOCAL crate's impls, so serde support on the
    /// ubiquitous std / external types a data signature is built from (`String`,
    /// `Vec<T>`, `Option<T>`, `HashMap<String, V>`, tuples, `Duration`, ranges)
    /// can't be proven via [`Self::serde_disposition`]; they're admitted
    /// structurally, recursing into type args and doing a real local-impl lookup
    /// only at a leaf that names a crate type. `dir` is the trait a leaf must
    /// implement — `Serialize` for a return value, `Deserialize` for a param.
    fn is_wide_serializable(&self, ty: &Type, dir: SerdeTrait) -> bool {
        match ty {
            // msgpack scalars: bool, all fixed-width ints/floats, char, str. `u128`/
            // `i128` are intentionally excluded — msgpack has no 128-bit integer.
            Type::Primitive(p) => matches!(
                p.as_str(),
                "bool"
                    | "char"
                    | "str"
                    | "u8"
                    | "u16"
                    | "u32"
                    | "u64"
                    | "usize"
                    | "i8"
                    | "i16"
                    | "i32"
                    | "i64"
                    | "isize"
                    | "f32"
                    | "f64"
            ),
            // A borrow is transparent at the wire — `&T`/`&mut T` cross as `T`.
            Type::BorrowedRef { type_, .. } => self.is_wide_serializable(type_, dir),
            // A tuple / fixed array / slice is wide iff every element is.
            Type::Tuple(elems) => elems.iter().all(|e| self.is_wide_serializable(e, dir)),
            Type::Slice(inner) => self.is_wide_serializable(inner, dir),
            Type::Array { type_, .. } => self.is_wide_serializable(type_, dir),
            Type::ResolvedPath(rp) => self.is_wide_path(rp, dir),
            _ => false,
        }
    }

    /// The `ResolvedPath` arm of [`Self::is_wide_serializable`]: the container /
    /// std whitelist by name (recursing into args), else a local-impl lookup on a
    /// leaf type that names a crate type.
    fn is_wide_path(&self, rp: &rustdoc_types::Path, dir: SerdeTrait) -> bool {
        match rp_name(&rp.path) {
            // A String (owned or the leaf of `std::string::String`) is wide.
            "String" => true,
            // Homogeneous containers: wide iff their element type args are.
            "Vec" | "Option" | "Range" | "RangeInclusive" => self.wide_all_args(rp, dir),
            // A map crosses wide only with a String key (msgpack map keys); the
            // value type arg must itself be wide.
            "HashMap" | "BTreeMap" => self.wide_map(rp, dir),
            // `std::time::Duration` serializes structurally (secs+nanos) under
            // serde — admit it without an impl lookup rustdoc can't do for std.
            "Duration" => true,
            // A leaf naming a LOCAL crate type: real impl lookup (external leaves
            // aren't in the index, so `serde_disposition` is all-false — correct,
            // the structural whitelist above didn't cover them).
            _ => {
                let info = self.serde_disposition(rp.id.0);
                match dir {
                    SerdeTrait::Serialize => info.serialize,
                    SerdeTrait::Deserialize => info.deserialize,
                }
            }
        }
    }

    /// Every angle-bracketed type arg of `rp` is wide (used for `Vec`/`Option`/
    /// ranges). A path with no type args (e.g. a bare alias) is not admitted.
    fn wide_all_args(&self, rp: &rustdoc_types::Path, dir: SerdeTrait) -> bool {
        let args = angle_type_args(rp);
        !args.is_empty() && args.iter().all(|t| self.is_wide_serializable(t, dir))
    }

    /// A `HashMap`/`BTreeMap` is wide iff its key is `String` and its value is
    /// wide (msgpack map keys must be strings for a dict-shaped decode).
    fn wide_map(&self, rp: &rustdoc_types::Path, dir: SerdeTrait) -> bool {
        let args = angle_type_args(rp);
        if args.len() != 2 {
            return false;
        }
        let key_is_string = matches!(
            &args[0],
            Type::ResolvedPath(k) if rp_name(&k.path) == "String"
        );
        key_is_string && self.is_wide_serializable(args[1], dir)
    }

    // ── serde wide lane resolution (2.8) ──────────────────────────────────────

    /// The per-type overlay `[type."T"] wide = true|false` override (2.3) for the
    /// named leaf of `ty`, if any. `Some(true)` forces the wide lane (even over an
    /// opaque-handle classification), `Some(false)` forbids it, `None` = follow
    /// structural detection. Only a LEAF type (a bare named type, transparently
    /// through a borrow) maps to a single overlay type key; a container has no
    /// single `[type]` entry and returns `None`.
    fn wide_override_for(&self, ty: &Type) -> Option<bool> {
        let rp = match ty {
            Type::ResolvedPath(rp) => rp,
            Type::BorrowedRef { type_, .. } => return self.wide_override_for(type_),
            _ => return None,
        };
        self.overlay?
            .types
            .get(rp_name(&rp.path))
            .and_then(|t| t.wide)
    }

    /// Lane resolution for a value of type `ty` crossing in direction `dir`,
    /// consulted only AFTER every scalar/handle lane has been ruled out (so the
    /// handle-wins canonical rule holds by construction — an opaque-bridged type
    /// has already classified as a handle before control reaches here). Returns the
    /// inner Rust type spelling for the `Wide<…>` marker when the value should
    /// cross the wide (msgpack) lane, else `None` (leaving the caller's original
    /// skip in place). A `[type."T"] wide = false` overlay forbids the lane even
    /// when detection admits it; `wide = true` is handled earlier by the caller (it
    /// must override the handle lane, so it can't wait for this fallback).
    fn wide_fallback(&self, ty: &Type, dir: SerdeTrait) -> Option<String> {
        if self.wide_override_for(ty) == Some(false) {
            return None;
        }
        // The structural whitelist ([`Self::is_wide_serializable`]) admits pure-std
        // shapes (`Vec<f64>`, `(usize, usize)`) that are serializable in principle
        // but carry no serde INTENT — auto-crossing every such signature wide would
        // grab items that are honest skips today and destabilize the coverage
        // baselines. So the DETECTION fallback additionally requires a genuine
        // serde-attested named leaf; a shape with only std/primitive leaves stays a
        // skip. (`[type."T"] wide = true` bypasses this — it is handled earlier.)
        if self.is_wide_serializable(ty, dir) && self.wide_has_serde_leaf(ty, dir) {
            let rendered = self.render_wide_ty(ty)?;
            // 2.9: if the wide value's TOP type is a derived-serde record with a
            // statically known field shape, register it so codegen emits a
            // `#[jac_record]` and the loader synthesizes a typed object. Only the
            // DETECTION path collects records; an overlay `wide = true` escape hatch
            // (handled earlier) stays a dynamic document by design.
            self.note_wide_top(ty);
            Some(rendered)
        } else {
            None
        }
    }

    /// The Rust spelling of a record FIELD type if it is admissible for typed-obj
    /// synthesis, else `None` (which disqualifies the enclosing record). Admissible
    /// = a scalar/`String`, a nested qualifying record (rendered as its LOCAL leaf
    /// name — the `#[jac_record]` the binder also emits, matched by the macro by
    /// name), or an `Option`/`Vec`/`HashMap<String,_>` of an admissible type
    /// (2.9-followup). This is a PURE check — it registers nothing — so
    /// `record_qualifies` can use it while deciding, and `register_records_deep`
    /// does the registration separately.
    fn render_field_ty(&self, ty: &Type) -> Option<String> {
        match ty {
            Type::BorrowedRef { type_, .. } => self.render_field_ty(type_),
            Type::Primitive(p) => match p.as_str() {
                "bool" | "i8" | "i16" | "i32" | "i64" | "isize" | "u8" | "u16" | "u32" | "u64"
                | "usize" | "f32" | "f64" => Some(p.clone()),
                _ => None,
            },
            Type::ResolvedPath(rp) => match rp_name(&rp.path) {
                "String" => Some("String".into()),
                "Vec" => {
                    let args = angle_type_args(rp);
                    if args.len() != 1 {
                        return None;
                    }
                    Some(format!("Vec<{}>", self.render_field_ty(args[0])?))
                }
                "Option" => {
                    let args = angle_type_args(rp);
                    if args.len() != 1 {
                        return None;
                    }
                    Some(format!("Option<{}>", self.render_field_ty(args[0])?))
                }
                "HashMap" | "BTreeMap" => {
                    let args = angle_type_args(rp);
                    if args.len() != 2 {
                        return None;
                    }
                    // A msgpack map crosses with string keys only.
                    if !matches!(args[0], Type::ResolvedPath(k) if rp_name(&k.path) == "String") {
                        return None;
                    }
                    Some(format!(
                        "std::collections::HashMap<String, {}>",
                        self.render_field_ty(args[1])?
                    ))
                }
                // A nested type: admissible iff it is itself a qualifying record.
                // Rendered as its own local record name (the emitted `#[jac_record]`).
                _ => {
                    let (id, _) = self.record_qualifies(ty)?;
                    self.doc.index.get(&Id(id))?.name.clone()
                }
            },
            _ => None,
        }
    }

    /// The `(id, kind)` of `ty` IF it is a derived-serde struct or enum, WITHOUT the
    /// full field check — the cheap gate `record_qualifies` builds on. A struct must
    /// be a plain-named struct with no stripped fields; an enum must have no stripped
    /// variants. Both must carry an `#[automatically_derived]` serde impl (so
    /// rustdoc's fields/variants ARE the wire shape). A leading `&` is peeled.
    fn record_shell(&self, ty: &Type) -> Option<(u32, RecordKind)> {
        let ty = match ty {
            Type::BorrowedRef { type_, .. } => &**type_,
            t => t,
        };
        let Type::ResolvedPath(rp) = ty else {
            return None;
        };
        let id = rp.id.0;
        let item = self.doc.index.get(&Id(id))?;
        if !self.serde_disposition(id).automatically_derived {
            return None;
        }
        match &item.inner {
            ItemEnum::Struct(s) => match &s.kind {
                StructKind::Plain {
                    has_stripped_fields: false,
                    ..
                } => Some((id, RecordKind::Struct)),
                _ => None,
            },
            ItemEnum::Enum(e) if !e.has_stripped_variants => Some((id, RecordKind::Enum)),
            _ => None,
        }
    }

    /// The `(id, kind)` of the typed record `ty` resolves to, if it qualifies for
    /// typed-obj synthesis (2.9 / 2.9-followup): a derived-serde struct whose every
    /// field is admissible, or a derived-serde enum whose every variant is a unit or
    /// newtype variant with an admissible payload. `None` keeps the value on the
    /// dynamic wide lane. A self-referential type is broken by the `qual_stack` cycle
    /// guard (a re-entered id is assumed to qualify).
    fn record_qualifies(&self, ty: &Type) -> Option<(u32, RecordKind)> {
        let (id, kind) = self.record_shell(ty)?;
        if self.qual_stack.borrow().contains(&id) {
            return Some((id, kind));
        }
        self.qual_stack.borrow_mut().push(id);
        let ok = self.record_members_admissible(id, kind);
        self.qual_stack.borrow_mut().pop();
        if ok {
            Some((id, kind))
        } else {
            None
        }
    }

    /// True when every field (struct) / variant payload (enum) of record `id` is
    /// admissible. Assumes `id` is a valid record shell of `kind`.
    fn record_members_admissible(&self, id: u32, kind: RecordKind) -> bool {
        let Some(item) = self.doc.index.get(&Id(id)) else {
            return false;
        };
        match kind {
            RecordKind::Struct => {
                let ItemEnum::Struct(s) = &item.inner else {
                    return false;
                };
                let StructKind::Plain { fields, .. } = &s.kind else {
                    return false;
                };
                fields.iter().all(|fid| {
                    self.item(fid)
                        .and_then(|f| match &f.inner {
                            ItemEnum::StructField(fty) => self.render_field_ty(fty),
                            _ => None,
                        })
                        .is_some()
                })
            }
            RecordKind::Enum => {
                let ItemEnum::Enum(e) = &item.inner else {
                    return false;
                };
                e.variants
                    .iter()
                    .all(|vid| self.variant_payload_ty(vid).is_some())
            }
        }
    }

    /// The admissible payload spelling of an enum variant: `Some(None)` for a unit
    /// variant, `Some(Some(ty))` for a newtype variant with an admissible payload,
    /// `None` for anything unsupported (struct-payload / multi-field tuple / an
    /// inadmissible payload) — which disqualifies the whole enum.
    fn variant_payload_ty(&self, vid: &Id) -> Option<Option<String>> {
        let v = self.item(vid)?;
        let ItemEnum::Variant(var) = &v.inner else {
            return None;
        };
        match &var.kind {
            rustdoc_types::VariantKind::Plain => Some(None),
            rustdoc_types::VariantKind::Tuple(fields) if fields.len() == 1 => {
                let fid = fields[0].as_ref()?;
                let f = self.item(fid)?;
                let ItemEnum::StructField(fty) = &f.inner else {
                    return None;
                };
                Some(Some(self.render_field_ty(fty)?))
            }
            _ => None,
        }
    }

    /// Register `ty`'s top type as a typed record if it qualifies, then recurse into
    /// every nested record it references so the whole reachable graph gets a
    /// `#[jac_record]` (dedup, first-seen order). Interior mutability: the wide-slot
    /// resolution path is `&self`.
    fn note_wide_top(&self, ty: &Type) {
        if let Some((id, _)) = self.record_qualifies(ty) {
            self.register_record_deep(id);
        }
    }

    /// Register record `id` and, transitively, every nested record reachable from
    /// its fields/variants. Guarded against cycles + re-registration by the
    /// `wide_record_ids` set itself.
    fn register_record_deep(&self, id: u32) {
        {
            let mut ids = self.wide_record_ids.borrow_mut();
            if ids.contains(&id) {
                return;
            }
            ids.push(id);
        }
        // Walk the record's member types and register any nested records.
        let Some(item) = self.doc.index.get(&Id(id)) else {
            return;
        };
        let member_tys: Vec<Type> = match &item.inner {
            ItemEnum::Struct(s) => match &s.kind {
                StructKind::Plain { fields, .. } => fields
                    .iter()
                    .filter_map(|fid| match &self.item(fid)?.inner {
                        ItemEnum::StructField(fty) => Some(fty.clone()),
                        _ => None,
                    })
                    .collect(),
                _ => vec![],
            },
            ItemEnum::Enum(e) => e
                .variants
                .iter()
                .filter_map(|vid| match &self.item(vid)?.inner {
                    ItemEnum::Variant(rustdoc_types::Variant {
                        kind: rustdoc_types::VariantKind::Tuple(fields),
                        ..
                    }) if fields.len() == 1 => {
                        let fid = fields[0].as_ref()?;
                        match &self.item(fid)?.inner {
                            ItemEnum::StructField(fty) => Some(fty.clone()),
                            _ => None,
                        }
                    }
                    _ => None,
                })
                .collect(),
            _ => vec![],
        };
        for mty in &member_tys {
            for nested in self.nested_record_types(mty) {
                if let Some((nid, _)) = self.record_qualifies(&nested) {
                    self.register_record_deep(nid);
                }
            }
        }
    }

    /// The record-typed leaves inside a field type, peeling `Option`/`Vec`/`Map`
    /// containers (e.g. `Option<Vec<Point>>` yields `Point`). A scalar yields none.
    fn nested_record_types(&self, ty: &Type) -> Vec<Type> {
        match ty {
            Type::BorrowedRef { type_, .. } => self.nested_record_types(type_),
            Type::ResolvedPath(rp) => match rp_name(&rp.path) {
                "Vec" | "Option" => angle_type_args(rp)
                    .iter()
                    .flat_map(|t| self.nested_record_types(t))
                    .collect(),
                "HashMap" | "BTreeMap" => angle_type_args(rp)
                    .iter()
                    .skip(1) // key is String, only the value can be a record
                    .flat_map(|t| self.nested_record_types(t))
                    .collect(),
                "String" => vec![],
                // A path that is itself a record.
                _ => {
                    if self.record_shell(ty).is_some() {
                        vec![ty.clone()]
                    } else {
                        vec![]
                    }
                }
            },
            _ => vec![],
        }
    }

    /// Materialize [`BridgeSpec::records`] from the ids collected during
    /// classification: each struct's name + fields (with full type spellings), or
    /// each enum's name + variants (unit or newtype payload), in declaration order.
    fn build_wide_records(&self) -> Vec<WideRecord> {
        let ids = self.wide_record_ids.borrow();
        ids.iter()
            .filter_map(|&id| {
                let item = self.doc.index.get(&Id(id))?;
                let name = item.name.clone()?;
                match &item.inner {
                    ItemEnum::Struct(s) => {
                        let StructKind::Plain { fields, .. } = &s.kind else {
                            return None;
                        };
                        let mut wf = Vec::new();
                        for fid in fields {
                            let f = self.item(fid)?;
                            let fname = f.name.clone()?;
                            let ItemEnum::StructField(fty) = &f.inner else {
                                return None;
                            };
                            let rust_ty = self.render_field_ty(fty)?;
                            wf.push(WideField {
                                name: fname,
                                rust_ty: Some(rust_ty),
                            });
                        }
                        Some(WideRecord {
                            name,
                            kind: RecordKind::Struct,
                            fields: wf,
                        })
                    }
                    ItemEnum::Enum(e) => {
                        let mut wf = Vec::new();
                        for vid in &e.variants {
                            let vname = self.item(vid)?.name.clone()?;
                            let payload = self.variant_payload_ty(vid)?;
                            wf.push(WideField {
                                name: vname,
                                rust_ty: payload,
                            });
                        }
                        Some(WideRecord {
                            name,
                            kind: RecordKind::Enum,
                            fields: wf,
                        })
                    }
                    _ => None,
                }
            })
            .collect()
    }

    /// True when `ty` contains at least one NAMED leaf that actually implements the
    /// wanted serde trait (a `#[derive(Serialize)]`/manual-impl crate type) — the
    /// serde-intent gate on the detection-driven wide lane. Std container/leaf names
    /// (`String`, `Vec`, `Duration`, …) are transparent shells, not intent; only a
    /// real user type at a leaf counts.
    fn wide_has_serde_leaf(&self, ty: &Type, dir: SerdeTrait) -> bool {
        match ty {
            Type::BorrowedRef { type_, .. } => self.wide_has_serde_leaf(type_, dir),
            Type::Tuple(elems) => elems.iter().any(|e| self.wide_has_serde_leaf(e, dir)),
            Type::Slice(inner) => self.wide_has_serde_leaf(inner, dir),
            Type::Array { type_, .. } => self.wide_has_serde_leaf(type_, dir),
            Type::ResolvedPath(rp) => match rp_name(&rp.path) {
                "String" | "Duration" => false,
                "Vec" | "Option" | "Range" | "RangeInclusive" | "HashMap" | "BTreeMap" => {
                    angle_type_args(rp)
                        .iter()
                        .any(|t| self.wide_has_serde_leaf(t, dir))
                }
                _ => {
                    let info = self.serde_disposition(rp.id.0);
                    match dir {
                        SerdeTrait::Serialize => info.serialize,
                        SerdeTrait::Deserialize => info.deserialize,
                    }
                }
            },
            _ => false,
        }
    }

    /// Render `ty` as the Rust source the wrapper re-declares inside `Wide<…>`,
    /// mirroring [`Self::is_wide_serializable`]'s whitelist. Non-prelude std types
    /// are spelled fully-qualified (`std::collections::HashMap`, `std::time::
    /// Duration`, `std::ops::Range`) so no extra `use` is needed; a local leaf is
    /// spelled through its accessible crate path (the same path the newtype wraps).
    /// `None` for a shape outside the whitelist — the caller then keeps its skip.
    fn render_wide_ty(&self, ty: &Type) -> Option<String> {
        match ty {
            Type::Primitive(p) => Some(p.clone()),
            Type::BorrowedRef { type_, .. } => self.render_wide_ty(type_),
            Type::Slice(inner) => Some(format!("Vec<{}>", self.render_wide_ty(inner)?)),
            Type::Array { type_, len, .. } => {
                Some(format!("[{}; {}]", self.render_wide_ty(type_)?, len))
            }
            Type::Tuple(elems) => {
                let parts: Option<Vec<String>> =
                    elems.iter().map(|e| self.render_wide_ty(e)).collect();
                Some(format!("({})", parts?.join(", ")))
            }
            Type::ResolvedPath(rp) => self.render_wide_path(rp),
            _ => None,
        }
    }

    /// The `ResolvedPath` arm of [`Self::render_wide_ty`].
    fn render_wide_path(&self, rp: &rustdoc_types::Path) -> Option<String> {
        let render_args = |sep: &str| -> Option<String> {
            let parts: Option<Vec<String>> = angle_type_args(rp)
                .iter()
                .map(|t| self.render_wide_ty(t))
                .collect();
            Some(parts?.join(sep))
        };
        match rp_name(&rp.path) {
            "String" => Some("String".into()),
            "Vec" => Some(format!("Vec<{}>", render_args(", ")?)),
            "Option" => Some(format!("Option<{}>", render_args(", ")?)),
            "Range" => Some(format!("std::ops::Range<{}>", render_args(", ")?)),
            "RangeInclusive" => Some(format!("std::ops::RangeInclusive<{}>", render_args(", ")?)),
            "HashMap" => Some(format!("std::collections::HashMap<{}>", render_args(", ")?)),
            "BTreeMap" => Some(format!(
                "std::collections::BTreeMap<{}>",
                render_args(", ")?
            )),
            "Duration" => Some("std::time::Duration".into()),
            // A local leaf naming a crate type: spell it through the accessible
            // crate path (`crate::Point`), the same path the newtype would wrap.
            _ => self.wide_leaf_path(rp),
        }
    }

    /// Accessible crate path for a local leaf named by `rp` (`chrono::NaiveDate`),
    /// reusing the same submodule/re-export resolution the newtype wrapping uses.
    /// `None` for an unindexed (external) leaf — its path can't be spelled and its
    /// serde support was never proven, so it isn't a wide value.
    fn wide_leaf_path(&self, rp: &rustdoc_types::Path) -> Option<String> {
        let summary = self.doc.paths.get(&rp.id)?;
        let segs = &summary.path;
        let (name, module_path) = segs.split_last()?;
        // Strip the crate-root segment; the middle segments are the type's module.
        let module_path = module_path.split_first().map(|(_, m)| m).unwrap_or(&[]);
        Some(self.accessible_type_path(rp.id.0, module_path, name))
    }

    // ── Phase 2: classify impl methods ────────────────────────────────────────

    /// The trait's use-path for the generated `use`, always spelled through the
    /// BRIDGED MODULE (never the trait's defining crate directly) so the `use`
    /// binds the EXACT trait version the bridged crate uses — naming `digest`
    /// directly would need a separate dependency whose version we can't pin from
    /// rustdoc, and a `"*"` there can resolve to a different major than the one
    /// `sha2` impls, leaving `self.0.output_size()` unsatisfied. Two module-relative
    /// shapes, chosen by where the trait is DEFINED:
    ///   * LOCAL trait (defined in the bridged crate): re-exported at the module
    ///     root by convention — `chrono::Datelike`.
    ///   * EXTERNAL trait (`sha2` exposes `digest`'s `Digest`/`DynDigest`): NOT
    ///     guaranteed at the root — `DynDigest` lives at `sha2::digest::DynDigest`,
    ///     not `sha2::DynDigest`. A facade crate re-exports the whole defining crate
    ///     (`sha2` does `pub use digest;`), so route through that re-export:
    ///     `sha2::digest::DynDigest`. `Digest` (root-re-exported) also resolves this
    ///     way (`sha2::digest::Digest`), so external traits use one uniform shape.
    fn trait_use_path(&self, tr: &rustdoc_types::Path) -> String {
        let simple = self.trait_simple_name(tr);
        // path[0] in the rustdoc summary is the DEFINING crate name.
        if let Some(defining_crate) = self.doc.paths.get(&tr.id).and_then(|s| s.path.first()) {
            if defining_crate != &self.module_name {
                return format!("{}::{}::{}", self.module_name, defining_crate, simple);
            }
        }
        format!("{}::{}", self.module_name, simple)
    }

    /// The trait's simple (final-segment) name, for the NOISE policy match.
    fn trait_simple_name(&self, tr: &rustdoc_types::Path) -> String {
        if let Some(summary) = self.doc.paths.get(&tr.id) {
            if let Some(last) = summary.path.last() {
                return last.clone();
            }
        }
        tr.path.rsplit("::").next().unwrap_or(&tr.path).to_string()
    }

    /// D1 disposition: is this trait binder NOISE (a marker/protocol/derive trait
    /// whose methods carry no semantic crate API)? `true` → the impl is ignored
    /// wholesale (as before Track A). `false` → a SEMANTIC trait whose concretely
    /// provided methods are flattened onto the type as inherent methods, and whose
    /// unresolvable provided-defaults are excluded from the denominator (D1).
    fn is_noise_trait(&self, tr: &rustdoc_types::Path) -> bool {
        NOISE_TRAITS.contains(&self.trait_simple_name(tr).as_str())
    }

    fn classify_impl(&mut self, bt: &mut BridgeType) {
        // Owned copy of the type name so self-alias slices can reference it while
        // `bt` is borrowed mutably by `classify_impl_method`.
        let type_name = bt.name.clone();
        // Use the stored item ID directly — avoids re-resolving by name which
        // could pick the wrong variant when multiple modules re-export the same name.
        let impl_ids: Vec<Id> = self
            .doc
            .index
            .get(&Id(bt.item_id))
            .and_then(|item| match &item.inner {
                ItemEnum::Struct(s) => Some(s.impls.clone()),
                _ => None,
            })
            .unwrap_or_default();

        // 0.3.1: a type can expose several `-> Self` associated fns (uuid's
        // `nil`/`max`/`new_v4`/`parse_str`, chrono date ctors, …). Only one can be
        // THE constructor the wrapper's `init` calls; collect every candidate here
        // and resolve deterministically after the walk instead of letting the
        // last-walked one silently clobber `bt.ctor`. Each entry is
        // `(item_path, bridge_fn)`.
        let mut ctor_candidates: Vec<(String, BridgeFn)> = vec![];

        // 1.1.3: first-wins method dedup across the WHOLE type. Inherent impls are
        // classified before flattened trait impls, so an inherent method always
        // wins a name collision, and cross-trait duplicates (18 in sha2 alone) are
        // recorded as visible skips instead of emitted twice — two `pub fn`s of the
        // same name is a duplicate-definition error under `-D warnings`.
        let mut seen_names: std::collections::HashSet<String> = std::collections::HashSet::new();

        // Pass 1 — inherent impls (`impl T { … }`): every item is a real inherent
        // method, no trait provenance.
        for impl_id in &impl_ids {
            let Some(impl_item) = self.item(impl_id) else {
                continue;
            };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else {
                continue;
            };
            if impl_block.trait_.is_some() {
                continue;
            }
            // Inherent impls have only one self-alias: the type's own name.
            let self_aliases: [&str; 1] = [type_name.as_str()];
            for method_id in impl_block.items.clone() {
                self.classify_impl_method(
                    &method_id,
                    bt,
                    None,
                    &self_aliases,
                    &mut ctor_candidates,
                    &mut seen_names,
                );
            }
        }

        // Pass 2 — trait impls, three-way disposition (D1, Track A 1.1.1). NOISE
        // traits (Debug/Clone/Iterator/operators/…) are ignored wholesale as
        // before; a SEMANTIC trait's concretely-provided methods are FLATTENED onto
        // the type as inherent methods (carrying `via_trait` so codegen emits the
        // `use`); its provided-defaults not overridden in this impl are name-only
        // here (resolving them needs the trait definition + `Self` substitution,
        // task 1.1.2) so they are EXCLUDED from the denominator (D1) — neither
        // bridged nor a skip — keeping the ratio comparable across crates.
        for impl_id in &impl_ids {
            let Some(impl_item) = self.item(impl_id) else {
                continue;
            };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else {
                continue;
            };
            let Some(tr) = &impl_block.trait_ else {
                continue;
            };
            if self.is_noise_trait(tr) {
                continue;
            }
            let via = self.trait_use_path(tr);
            // 1.1.2: a blanket `impl<D> Trait for D` rustdoc-materialized onto this
            // type keeps its generic param (`D`) in method signatures where `Self`
            // is meant. Add that param as a self-alias for this impl's methods so
            // `Digest::new() -> D` reads as a `-> Self` constructor. `blanket_impl`
            // holds the blanket type (`Type::Generic("D")`) when present.
            let blanket_generic = impl_block.blanket_impl.as_ref().and_then(|t| match t {
                Type::Generic(g) => Some(g.clone()),
                _ => None,
            });
            let mut self_aliases: Vec<&str> = vec![type_name.as_str()];
            if let Some(g) = &blanket_generic {
                self_aliases.push(g.as_str());
            }
            for method_id in impl_block.items.clone() {
                self.classify_impl_method(
                    &method_id,
                    bt,
                    Some(&via),
                    &self_aliases,
                    &mut ctor_candidates,
                    &mut seen_names,
                );
            }
            self.inherited_excluded += impl_block.provided_trait_methods.len();
        }

        // Resolve the collected `-> Self` associated fns (0.3.1 + 1.1.3). An
        // INHERENT ctor (`via_trait: None`) beats a trait-flattened one — a type's
        // own `Regex::new` wins THE constructor slot over a flattened
        // `FromStr::from_str` — and ties break by name, so the winner is
        // deterministic across rustdoc index orderings. Losers are recorded as
        // honest "additional constructor" skips rather than silently dropped. Uses
        // `UnsupportedType` (the plan's `Skip("additional constructor")` string
        // form) so no new `SkipReason` variant is required.
        // A `-> Self` factory flattened off a std/core trait (`FromStr::from_str`)
        // has no recoverable public `use` path, so it can NEVER be a compiling ctor
        // OR static. The loser loop below already skips such candidates, but the
        // WINNER bypassed that check — a type whose ONLY `-> Self` candidate is
        // `from_str` (uuid's `fmt::Braced`/`Simple`/…) would let it win the ctor
        // slot and emit an uncompilable `Type::from_str(..)` + bogus trait `use`.
        // Drain them up front so an unusable trait ctor can't win.
        ctor_candidates.retain(|(item_path, cand)| {
            if static_trait_path_unusable(&cand.via_trait) {
                self.skips.push(Skip {
                    item: item_path.clone(),
                    reason: SkipReason::UnsupportedType(
                        "additional constructor via a std/core trait (no reliable public use path)"
                            .into(),
                    ),
                });
                false
            } else {
                true
            }
        });
        ctor_candidates.sort_by(|a, b| {
            (a.1.via_trait.is_some(), &a.1.name).cmp(&(b.1.via_trait.is_some(), &b.1.name))
        });
        let mut candidates = ctor_candidates.into_iter();
        if let Some((_, winner)) = candidates.next() {
            bt.ctor = Some(winner);
            for (item_path, mut extra) in candidates {
                // 1.3 FN_STATIC: the ctor slot holds exactly one ctor (the wrapper's
                // `init`); every OTHER `-> Self` factory (`Uuid::nil`/`max`/
                // `parse_str`, `Sha256::new_with_prefix`) becomes a STATIC — the same
                // associated-fn codegen, exposed as a static method on the type
                // rather than as `init`. None of these are mono (a mono ctor is
                // skipped before it reaches `ctor_candidates`), so the associated
                // call form always compiles. Dedup against methods already claimed.
                if static_trait_path_unusable(&extra.via_trait) {
                    // A `-> Self` factory flattened off a std/core trait
                    // (`FromStr::from_str`): its `<Inner as Trait>::from_str` call
                    // needs the trait `use`d, but the trait's PUBLIC path isn't
                    // recoverable from rustdoc's canonical (private-module) path, so
                    // `trait_use_path` can't form a compiling `use`. Honest skip
                    // rather than an unresolved-import in the generated crate.
                    self.skips.push(Skip {
                        item: item_path,
                        reason: SkipReason::UnsupportedType(
                            "additional constructor via a std/core trait (no reliable public use path)"
                                .into(),
                        ),
                    });
                } else if seen_names.insert(extra.exposed().to_string()) {
                    extra.is_static = true;
                    bt.methods.push(extra);
                } else {
                    self.skips.push(Skip {
                        item: item_path,
                        reason: SkipReason::UnsupportedType(format!(
                            "duplicate method name ({})",
                            extra.exposed()
                        )),
                    });
                }
            }
        }

        // Synthesize the trait-driven and field-driven surface the noise-trait
        // policy and the public-field model don't reach through method flattening:
        //   * `impl Display`  -> `to_string(&self) -> String`
        //   * `impl Ord`      -> `cmp(&self, &Self) -> i8` (rides the Ordering lane)
        //   * `impl FromStr`  -> `from_str(text) -> Result<Self, String>` static
        //   * public fields   -> per-field reader methods (scalar / handle / enum)
        // Each is deduped against `seen_names`, so a synthesized name never shadows
        // a real inherent/flattened method (first-wins, 1.1.3).
        self.synth_display(bt, &mut seen_names);
        self.synth_ord(bt, &mut seen_names);
        self.synth_from_str(bt, &mut seen_names);
        self.synth_field_readers(bt, &mut seen_names);
    }

    /// A `BridgeFn` skeleton for a `&self` reader/method synthesized by the lanes
    /// below — no receiver-mutation, no async, owned return, no trait provenance.
    /// Callers set `name`, `params`, `ret`, and any of `is_static`/`field_read`/
    /// `std_from_str` that apply.
    fn synth_fn(name: &str, params: Vec<BridgeParam>, ret: BridgeReturn) -> BridgeFn {
        BridgeFn {
            name: name.to_string(),
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

    /// True iff the struct/enum with `item_id` carries a trait impl whose simple
    /// (final-segment) name is `simple`. Mirrors [`Self::implements_error_trait`]
    /// but matched on the trait's simple name (the same key the noise policy uses),
    /// which is enough to detect the std leaf traits the synth lanes key on
    /// (`Display`/`Ord`/`FromStr`) on a bridged crate's own type.
    fn type_impls_trait(&self, item_id: u32, simple: &str) -> bool {
        let Some(item) = self.doc.index.get(&Id(item_id)) else {
            return false;
        };
        let impls = match &item.inner {
            ItemEnum::Struct(s) => &s.impls,
            ItemEnum::Enum(e) => &e.impls,
            _ => return false,
        };
        impls.iter().any(|impl_id| {
            self.item(impl_id)
                .and_then(|ii| match &ii.inner {
                    ItemEnum::Impl(ib) => ib.trait_.as_ref(),
                    _ => None,
                })
                .map(|tr| self.trait_simple_name(tr) == simple)
                .unwrap_or(false)
        })
    }

    /// Display lane: `impl std::fmt::Display for T` -> a `to_string(&self) -> String`
    /// reader (`self.0.to_string()`). Every semver opaque type (`Version`,
    /// `Comparator`, `Prerelease`, …) is `Display`, so this recovers the string form
    /// the crate's own users rely on.
    fn synth_display(&mut self, bt: &mut BridgeType, seen: &mut HashSet<String>) {
        if bt.kind != TypeKind::Opaque || !self.type_impls_trait(bt.item_id, "Display") {
            return;
        }
        if seen.insert("to_string".to_string()) {
            bt.methods.push(Self::synth_fn(
                "to_string",
                vec![],
                BridgeReturn::DisplayString,
            ));
        }
    }

    /// Ord lane: `impl std::cmp::Ord for T` -> a `cmp(&self, other: &Self) -> i8`
    /// method riding the Ordering return lane and the inbound-handle-param lane.
    /// `self.0.cmp(&other.0)` is unambiguous (only `Ord` provides `cmp`; `Ord` is in
    /// the prelude, so no `use` is needed) and lowers to `-1/0/1` like
    /// `cmp_precedence`. The `&Self` param crosses as the caller's handle.
    fn synth_ord(&mut self, bt: &mut BridgeType, seen: &mut HashSet<String>) {
        if bt.kind != TypeKind::Opaque || !self.type_impls_trait(bt.item_id, "Ord") {
            return;
        }
        // The `&Self` handle param requires this type to be a live opaque handle
        // (in `ref_type_names`); a mono type carries a turbofish inner path a `&Self`
        // handle can't spell, so skip it there.
        if bt.mono.is_some() || !self.ref_type_names.contains(&bt.name) {
            return;
        }
        if seen.insert("cmp".to_string()) {
            let params = vec![BridgeParam {
                name: "other".into(),
                ty: ScalarType::Handle(bt.name.clone()),
            }];
            bt.methods
                .push(Self::synth_fn("cmp", params, BridgeReturn::Ordering));
        }
    }

    /// FromStr lane: `impl std::str::FromStr for T` -> a `from_str(text: &str) ->
    /// Result<Self, String>` static, emitted fully-qualified as `<Inner as
    /// ::std::str::FromStr>::from_str(text)` (see [`BridgeFn::std_from_str`]). This
    /// admits the additional string constructor the generic trait-flatten had to
    /// skip (FromStr's public path is unrecoverable), killing the "additional
    /// constructor via a std/core trait" skips. Demoted to a skip later by
    /// `reconcile_fallible_returns` iff the crate has no bridged error type.
    fn synth_from_str(&mut self, bt: &mut BridgeType, seen: &mut HashSet<String>) {
        if bt.kind != TypeKind::Opaque || bt.mono.is_some() {
            return;
        }
        if !self.type_impls_trait(bt.item_id, "FromStr") {
            return;
        }
        if seen.insert("from_str".to_string()) {
            let params = vec![BridgeParam {
                name: "text".into(),
                ty: ScalarType::Str,
            }];
            let mut f = Self::synth_fn("from_str", params, BridgeReturn::OwnSelfResult);
            f.is_static = true;
            f.std_from_str = true;
            bt.methods.push(f);
        }
    }

    /// Opaque field-reader lane: for an opaque type with PUBLIC named fields (only a
    /// `treat_as = "opaque"`-forced transparent struct has these — a naturally
    /// opaque struct has private/stripped state), synthesize a reader per field:
    ///   * a scalar field (`u64`/`i64`/`bool`) -> a scalar reader (`self.0.major`);
    ///   * a handle field naming another LIVE bridged opaque type -> an owned-handle
    ///     producer (`Prerelease(self.0.pre.clone())`, semver types are all `Clone`);
    ///   * a public FIELDLESS enum field -> a variant-name string reader.
    /// A field the ABI can't carry (`Option<int>` has no in-band None channel;
    /// `Vec<Handle>` has no list-of-handle lane) is recorded as an honest skip.
    fn synth_field_readers(&mut self, bt: &mut BridgeType, seen: &mut HashSet<String>) {
        if bt.kind != TypeKind::Opaque || bt.mono.is_some() {
            return;
        }
        for (fname, fty) in self.public_named_fields(bt.item_id) {
            if seen.contains(&fname) {
                continue;
            }
            match self.classify_field_reader(&fty) {
                Ok(ret) => {
                    seen.insert(fname.clone());
                    let mut f = Self::synth_fn(&fname, vec![], ret);
                    f.field_read = Some(fname);
                    bt.methods.push(f);
                }
                Err(reason) => self.skips.push(Skip {
                    item: format!("{}::{}", bt.name, fname),
                    reason,
                }),
            }
        }
    }

    /// The public NAMED fields (name, type) of a plain struct, in declaration order.
    /// Empty for a tuple/unit struct, a non-struct, or a struct whose fields are all
    /// private (rustdoc omits non-public fields from `fields`). Only public fields
    /// are returned, so a reader never names inaccessible state.
    fn public_named_fields(&self, item_id: u32) -> Vec<(String, Type)> {
        let Some(item) = self.doc.index.get(&Id(item_id)) else {
            return vec![];
        };
        let ItemEnum::Struct(s) = &item.inner else {
            return vec![];
        };
        let StructKind::Plain { fields, .. } = &s.kind else {
            return vec![];
        };
        let mut out = vec![];
        for fid in fields {
            let Some(fitem) = self.item(fid) else {
                continue;
            };
            if matches!(
                fitem.visibility,
                rustdoc_types::Visibility::Crate | rustdoc_types::Visibility::Restricted { .. }
            ) {
                continue;
            }
            let (Some(name), ItemEnum::StructField(fty)) = (&fitem.name, &fitem.inner) else {
                continue;
            };
            out.push((name.clone(), fty.clone()));
        }
        out
    }

    /// The return lane for a public field of an opaque type, or a skip reason the
    /// v1 ABI can't carry. Scalars ride the int/bool lanes, a handle field the Ref
    /// lane, a fieldless enum the variant-name string lane.
    fn classify_field_reader(&self, fty: &Type) -> Result<BridgeReturn, SkipReason> {
        match fty {
            Type::Primitive(p) => match p.as_str() {
                "bool" => Ok(BridgeReturn::Bool),
                p @ ("u8" | "u16" | "u32" | "u64" | "usize") => Ok(BridgeReturn::Uint(p.into())),
                p @ ("i8" | "i16" | "i32" | "i64" | "isize") => Ok(BridgeReturn::Int(p.into())),
                other => Err(SkipReason::UnsupportedType(format!(
                    "field of type {other}"
                ))),
            },
            Type::ResolvedPath(rp) => {
                // A field naming another LIVE bridged opaque handle -> owned clone.
                if self.ref_type_names.contains(&rp.path)
                    && !has_lifetime_args(rp)
                    && !inner_has_lifetime(rp, self.doc)
                {
                    return Ok(BridgeReturn::Ref(rp.path.clone()));
                }
                // A public FIELDLESS enum (all-unit variants) -> variant-name string.
                if let Some(variants) = self.fieldless_enum_variants(rp.id.0) {
                    let enum_path = self.accessible_type_path(rp.id.0, &[], rp_name(&rp.path));
                    return Ok(BridgeReturn::EnumName(enum_path, variants));
                }
                // An `Option<int>` field (`Comparator.minor: Option<u64>`) rides
                // the Option<int> return lane: Some crosses as an 8-byte JacBuf,
                // None as a null pointer (`TAG_OPT_BIT | TAG_INT/UINT`). The field
                // is `Copy`, so the reader forwards it by value with no clone.
                // A `Vec<Handle>` field still has no list-of-handle lane.
                if rp_name(&rp.path) == "Option" {
                    if let Some(Type::Primitive(p)) = vec_first_type_arg(rp) {
                        match p.as_str() {
                            "u8" | "u16" | "u32" | "u64" | "usize" => {
                                return Ok(BridgeReturn::OptUintValue(p.clone()));
                            }
                            "i8" | "i16" | "i32" | "i64" | "isize" => {
                                return Ok(BridgeReturn::OptIntValue(p.clone()));
                            }
                            _ => {}
                        }
                    }
                }
                // A `Vec<Handle>` field (`VersionReq.comparators: Vec<Comparator>`)
                // rides the Vec-of-handle lane when the element is a live bridged
                // opaque type AND the element is `Clone` (the reader clones each
                // element out of the borrowed Vec into its own owned handle box).
                if rp_name(&rp.path) == "Vec" {
                    if let Some(Type::ResolvedPath(elem)) = vec_first_type_arg(rp) {
                        if self.ref_type_names.contains(&elem.path)
                            && !has_lifetime_args(elem)
                            && !inner_has_lifetime(elem, self.doc)
                            && self.type_impls_trait(elem.id.0, "Clone")
                        {
                            return Ok(BridgeReturn::HandleList(elem.path.clone()));
                        }
                    }
                }
                match rp_name(&rp.path) {
                    "Option" => Err(SkipReason::UnsupportedType(
                        "Option<non-integer> field: no in-band None channel in the v1 ABI".into(),
                    )),
                    "Vec" => Err(SkipReason::UnsupportedType(
                        "Vec<non-handle or non-Clone> field: no lane".into(),
                    )),
                    other => Err(SkipReason::UnsupportedType(format!(
                        "field of type {other}"
                    ))),
                }
            }
            _ => Err(SkipReason::UnsupportedType(format!("field {fty:?}"))),
        }
    }

    /// The variant names of the enum with `id` IF it is a public FIELDLESS enum
    /// (every variant a unit variant), else `None`. A fieldless enum has no bridged
    /// handle and no scalar spelling, so its value crosses as its variant name.
    fn fieldless_enum_variants(&self, id: u32) -> Option<Vec<String>> {
        let item = self.doc.index.get(&Id(id))?;
        let ItemEnum::Enum(e) = &item.inner else {
            return None;
        };
        let mut names = vec![];
        for vid in &e.variants {
            let vitem = self.item(vid)?;
            let ItemEnum::Variant(v) = &vitem.inner else {
                return None;
            };
            // Only plain unit variants map cleanly onto a name string.
            if !matches!(v.kind, rustdoc_types::VariantKind::Plain) {
                return None;
            }
            names.push(vitem.name.clone()?);
        }
        (!names.is_empty()).then_some(names)
    }

    /// Classify one impl method (inherent or trait-flattened) onto `bt`.
    /// `via_trait` is the flattened trait's full path — `Some` only for a SEMANTIC
    /// trait impl (Track A) — stamped on the emitted `BridgeFn` so codegen brings
    /// the trait into scope for the `self.0.<method>()` call. `seen_names` enforces
    /// first-wins dedup (1.1.3) across the whole type; a name already claimed
    /// becomes a visible skip instead of a duplicate `pub fn`. `self_aliases` (1.1.2)
    /// are the names that read as `Self` in this impl's signatures — the type name
    /// plus, for a flattened blanket `impl<D> Trait for D`, the blanket param `D`.
    #[allow(clippy::too_many_arguments)]
    fn classify_impl_method(
        &mut self,
        method_id: &Id,
        bt: &mut BridgeType,
        via_trait: Option<&str>,
        self_aliases: &[&str],
        ctor_candidates: &mut Vec<(String, BridgeFn)>,
        seen_names: &mut std::collections::HashSet<String>,
    ) {
        let Some(method) = self.item(method_id) else {
            return;
        };
        let ItemEnum::Function(f) = &method.inner else {
            return;
        };
        if matches!(
            method.visibility,
            rustdoc_types::Visibility::Crate | rustdoc_types::Visibility::Restricted { .. }
        ) {
            return;
        }
        let method_name = method.name.clone().unwrap_or_default();
        let item_path = format!("{}::{}", bt.name, method_name);

        // An overlay `treat_as` on this method overrides auto-detection: it either
        // forces the method off the bridge (`skip`) or pins it to exactly one rule,
        // bypassing the usual or-else ordering.
        if let Some(kind) = self.treat_as_for(&bt.name, &method_name) {
            self.apply_treat_as(
                kind,
                method_id.0,
                &method_name,
                &item_path,
                f,
                bt,
                self_aliases,
            );
            return;
        }

        match self.classify_fn(&item_path, f, bt, self_aliases) {
            Ok(mut bridge_fn) => {
                bridge_fn.via_trait = via_trait.map(str::to_string);
                // 1.2.2 lifted the two receiver shapes the byte lane needs:
                //   * `&mut self` (`Digest::update`/`reset`) emits a `&mut self`
                //     wrapper (`bridge_fn.self_mut`), routed through the macro's
                //     reentrancy busy-latch.
                //   * BY-VALUE `self` (`Digest::finalize(self)`) is cloned out of the
                //     shared handle (`self.0.clone().finalize()`, `consumes_self`) —
                //     sound only when the newtype's inner type is `Clone`. A
                //     consuming method on a non-`Clone` type stays a VISIBLE skip
                //     rather than a mis-compiled move out of a borrow.
                if bridge_fn.consumes_self && !self.type_is_clone(bt) {
                    self.skips.push(Skip {
                        item: item_path,
                        reason: SkipReason::UnsupportedType(
                            "consumes self by value (inner type is not Clone)".into(),
                        ),
                    });
                    return;
                }
                let has_self = f.sig.inputs.iter().any(|(n, _)| n == "self");
                let is_ctor = matches!(
                    bridge_fn.ret,
                    BridgeReturn::OwnSelf | BridgeReturn::OwnSelfResult
                ) && !has_self;
                // An associated fn with NO receiver that isn't THE constructor
                // (returns something other than `Self`, e.g. `Digest::output_size()
                // -> usize`, or `Sha256::digest(data) -> Output`). 1.3 admits it as
                // a STATIC: codegen emits the associated form `Type::fn(args)` (no
                // receiver) and stamps `#[jac(assoc)]` so the macro tags it
                // FN_STATIC — no handle in, dispatched by name. A mono type's inner
                // path carries a turbofish-less type arg (`Date<Utc>::f()` is
                // invalid syntax), so a static on it stays a skip, exactly as a
                // ctor on a mono type does.
                if !is_ctor && !has_self {
                    if bt.mono.is_some() {
                        self.skips.push(Skip {
                            item: item_path,
                            reason: SkipReason::UnsupportedType(
                                "associated fn on monomorphized type".into(),
                            ),
                        });
                    } else if static_trait_path_unusable(&bridge_fn.via_trait) {
                        self.skips.push(Skip {
                            item: item_path,
                            reason: SkipReason::UnsupportedType(
                                "associated fn via a std/core trait (no reliable public use path)"
                                    .into(),
                            ),
                        });
                    } else if seen_names.insert(bridge_fn.exposed().to_string()) {
                        bridge_fn.is_static = true;
                        bt.methods.push(bridge_fn);
                    } else {
                        // 1.1.3 dedup: a same-named method/static already claimed the
                        // exposed name; a second `pub fn` would not compile.
                        self.skips.push(Skip {
                            item: item_path,
                            reason: SkipReason::UnsupportedType(format!(
                                "duplicate method name ({})",
                                bridge_fn.exposed()
                            )),
                        });
                    }
                    return;
                }
                // A ctor's body calls `inner::method(..)`, but a mono type's inner
                // path carries a turbofish-less type arg (`chrono::Date<chrono::Utc>
                // ::new()` is invalid syntax), so ctors on monomorphized types are
                // recorded as skips instead.
                if is_ctor && bt.mono.is_some() {
                    self.skips.push(Skip {
                        item: item_path,
                        reason: SkipReason::UnsupportedType(
                            "constructor on monomorphized type".into(),
                        ),
                    });
                } else if is_ctor {
                    ctor_candidates.push((item_path, bridge_fn));
                } else if seen_names.insert(bridge_fn.exposed().to_string()) {
                    bt.methods.push(bridge_fn);
                } else {
                    // 1.1.3: an earlier inherent method (or trait) already claimed
                    // this name; the duplicate is a visible skip, never emitted.
                    self.skips.push(Skip {
                        item: item_path,
                        reason: SkipReason::UnsupportedType(format!(
                            "duplicate method name ({})",
                            bridge_fn.exposed()
                        )),
                    });
                }
            }
            Err(reason) => {
                // Before recording the skip, try the owning-wrapper rules: a
                // `fn(&self, &str) -> Option<Borrowed<'_>>` whose borrowed type has
                // a readable surface becomes a producer + wrapper; failing that, a
                // `fn(&self, &str) -> Iter<'_>` (an in-crate iterator) becomes a
                // cursor or a Vec-as-drain. Either rescues what would otherwise be a
                // lifetime-borrow / cursor skip.
                match self
                    .try_owning_wrapper(&method_name, f, bt, self_aliases)
                    .or_else(|| self.try_cursor_wrapper(&method_name, f, bt, self_aliases))
                    .or_else(|| self.try_vec_drain(method_id.0, &method_name, f, bt, self_aliases))
                    .or_else(|| self.try_callback_wrapper(&method_name, f, bt, self_aliases))
                    .or_else(|| self.try_replacer_str(&method_name, f, self_aliases))
                    .or_else(|| self.try_int_collect(&method_name, f, self_aliases))
                {
                    Some((producer, pendings)) => {
                        if seen_names.insert(producer.exposed().to_string()) {
                            bt.methods.push(producer);
                            self.pending_wrappers.extend(pendings);
                        } else {
                            self.skips.push(Skip {
                                item: item_path,
                                reason: SkipReason::UnsupportedType(format!(
                                    "duplicate method name ({})",
                                    producer.exposed()
                                )),
                            });
                        }
                    }
                    None => self.skips.push(Skip {
                        item: item_path,
                        reason,
                    }),
                }
            }
        }
    }

    /// The `treat_as` value an overlay pins on `Type::method`, if any.
    fn treat_as_for(&self, type_name: &str, method_name: &str) -> Option<&'a str> {
        let key = format!("{type_name}::{method_name}");
        self.overlay?.fns.get(&key)?.treat_as.as_deref()
    }

    /// Honour a `treat_as` directive on a method: force it off the bridge
    /// (`"skip"`), or pin it to exactly one rule regardless of what auto-detection
    /// would pick. A pinned rule whose preconditions the method doesn't meet
    /// becomes an honest skip (never a silent drop). Unknown `treat_as` values are
    /// rejected earlier by [`crate::apply_overlay`], so they don't reach here.
    #[allow(clippy::too_many_arguments)]
    fn apply_treat_as(
        &mut self,
        kind: &str,
        method_id: u32,
        method_name: &str,
        item_path: &str,
        f: &rustdoc_types::Function,
        bt: &mut BridgeType,
        self_aliases: &[&str],
    ) {
        if kind == "skip" {
            self.skips.push(Skip {
                item: item_path.to_string(),
                reason: SkipReason::OverlayTreatAs("skip".into()),
            });
            return;
        }
        // A pinned rule: run exactly that one, bypassing the auto or-else chain.
        // `"cursor"` covers in-crate iterators (both cursors and &str-drains);
        // `"drain"` covers direct `Vec`/slice-of-string returns.
        let forced = match kind {
            "owning" => self.try_owning_wrapper(method_name, f, bt, self_aliases),
            "cursor" => self.try_cursor_wrapper(method_name, f, bt, self_aliases),
            "drain" => self.try_vec_drain(method_id, method_name, f, bt, self_aliases),
            "callback" => self.try_callback_wrapper(method_name, f, bt, self_aliases),
            _ => None,
        };
        match forced {
            Some((producer, pendings)) => {
                bt.methods.push(producer);
                self.pending_wrappers.extend(pendings);
            }
            None => self.skips.push(Skip {
                item: item_path.to_string(),
                reason: SkipReason::OverlayTreatAs(format!("{kind} (rule not applicable)")),
            }),
        }
    }

    /// A `ScalarType::Handle` for `name` when it names a LIVE bridged opaque type
    /// (present in `ref_type_names`, the same set the cross-type Ref return uses).
    /// `None` otherwise, so an unresolved `&Self`/`&Other` stays an honest skip.
    fn handle_param_target(&self, name: Option<&str>) -> Option<ScalarType> {
        let name = name?;
        self.ref_type_names
            .contains(name)
            .then(|| ScalarType::Handle(name.to_string()))
    }

    fn classify_fn(
        &self,
        path: &str,
        f: &rustdoc_types::Function,
        bt: &BridgeType,
        self_aliases: &[&str],
    ) -> Result<BridgeFn, SkipReason> {
        let mut params = vec![];

        // Iterator-of-strings monomorphization: a generic param `I` bounded
        // `I: IntoIterator<Item = S>, S: AsRef<str>` (`RegexSet::new`,
        // `RegexSetBuilder::new`) is pinned to the concrete `Vec<String>` and
        // crosses on the existing wide (msgpack) lane as `Wide<Vec<String>>` -
        // `Vec<String>` satisfies the bound, so the inner call compiles verbatim.
        let strings_iter = strings_iter_generic(f);

        for (pname, pty) in &f.sig.inputs {
            // Skip `self` / `&self` / `&mut self` receivers.
            if pname == "self" {
                continue;
            }
            if let Type::Generic(g) = pty {
                if Some(g) == strings_iter.as_ref() {
                    params.push(BridgeParam {
                        name: pname.clone(),
                        ty: ScalarType::Wide("Vec<String>".into()),
                    });
                    continue;
                }
            }
            let scalar = self.classify_param_type(pty, self_aliases)?;
            params.push(BridgeParam {
                name: pname.clone(),
                ty: scalar,
            });
        }

        let ret = self.classify_return(&f.sig.output, bt, self_aliases)?;
        // A `&Self` return without a receiver has no handle to be identical TO -
        // the self-identity lane is method-only (the macro rejects it likewise).
        if ret == BridgeReturn::SelfRef && !f.sig.inputs.iter().any(|(n, _)| n == "self") {
            return Err(SkipReason::UnsupportedType(
                "&Self return on an associated fn".into(),
            ));
        }

        // 1.2.2: the receiver's mutability/consumption drives codegen. `&mut self`
        // emits a mutable wrapper (routed through the macro's busy-latch);
        // by-value `self` is cloned out of the shared handle. The
        // consumes-self-but-not-Clone case is rejected by the caller's guard.
        let self_recv = f
            .sig
            .inputs
            .iter()
            .find(|(n, _)| n == "self")
            .map(|(_, t)| t);
        let self_mut = matches!(
            self_recv,
            Some(Type::BorrowedRef {
                is_mutable: true,
                ..
            })
        );
        let consumes_self = matches!(self_recv, Some(t) if is_value_self(t, self_aliases));

        Ok(BridgeFn {
            name: path.rsplit("::").next().unwrap_or(path).to_string(),
            export_name: None,
            params,
            ret,
            throws: None,
            recv: Recv::Field0,
            is_async: f.header.is_async,
            ret_ownership: Ownership::Owned,
            via_trait: None,
            self_mut,
            consumes_self,
            is_static: false,
            field_read: None,
            std_from_str: false,
        })
    }

    fn classify_param_type(
        &self,
        ty: &Type,
        self_aliases: &[&str],
    ) -> Result<ScalarType, SkipReason> {
        // 2.8: a `[type."T"] wide = true` overlay forces the wide lane even for a
        // type that WOULD classify as an opaque handle — checked before the scalar
        // arms so the override actually wins. Detection-driven wide is the fallback
        // (after every scalar lane misses), keeping the handle-wins default. A param
        // is DESERIALIZED on the Rust side.
        if self.wide_override_for(ty) == Some(true) {
            if let Some(inner) = self.render_wide_ty(ty) {
                return Ok(ScalarType::Wide(inner));
            }
        }
        match ty {
            Type::Primitive(p) => match p.as_str() {
                "bool" => Ok(ScalarType::Bool),
                // Integer scalars cross in a single u64 slot; only the sign
                // discipline (TAG_INT vs TAG_UINT) is preserved. The concrete Rust
                // width is kept so the wrapper's re-declared param matches the crate.
                p @ ("u8" | "u16" | "u32" | "u64" | "usize") => Ok(ScalarType::Uint(p.to_string())),
                p @ ("i8" | "i16" | "i32" | "i64" | "isize") => Ok(ScalarType::Int(p.to_string())),
                other => Err(SkipReason::UnsupportedType(other.to_string())),
            },
            Type::BorrowedRef {
                type_, lifetime, ..
            } => match type_.as_ref() {
                Type::Primitive(p) if p == "str" => Ok(ScalarType::Str),
                // 1.2.2: `&[u8]` crosses as a (ptr, len) TAG_BYTES slot. A
                // lifetime-bearing `&'a [u8]` is fine — the slice is copied at the
                // boundary, so no borrow outlives the call.
                _ if is_u8_slice(type_) => Ok(ScalarType::Bytes),
                // An inbound handle param: `&Self` (1.1.2: also `&D` inside a
                // flattened blanket impl) is a reference to THIS bridged type
                // (`Version::cmp_precedence(&self, other: &Self)`). Crosses as the
                // caller's handle; `self_aliases[0]` is always the concrete name.
                Type::Generic(g) if g == "Self" || self_aliases.contains(&g.as_str()) => self
                    .handle_param_target(self_aliases.first().copied())
                    .ok_or_else(|| SkipReason::UnsupportedType("&Self receiver".into())),
                // An inbound handle param to ANOTHER bridged opaque type in the same
                // module (`VersionReq::matches(&self, other: &Version)`). Mirrors the
                // 1.2.4 cross-type Ref RETURN rule: the path must name a live handle
                // and carry no lifetime (a lifetime-borrowed handle can't cross).
                Type::ResolvedPath(inner)
                    if self.ref_type_names.contains(&inner.path)
                        && !has_lifetime_args(inner)
                        && !inner_has_lifetime(inner, self.doc) =>
                {
                    Ok(ScalarType::Handle(inner.path.clone()))
                }
                _ => {
                    if lifetime.is_some() {
                        Err(SkipReason::LifetimeBorrow)
                    } else {
                        Err(SkipReason::UnsupportedType(format!("{ty:?}")))
                    }
                }
            },
            Type::Generic(_) => Err(SkipReason::Generic),
            // 1.2.2: `impl AsRef<[u8]>` (sha2's `update`/`digest` byte sink) is a
            // bytes param; `&[u8]` satisfies the bound, so the wrapper re-declares
            // it as `&[u8]`. Any other `impl Trait` stays a Closure skip.
            Type::ImplTrait(bounds) if impl_is_asref_u8(bounds) => Ok(ScalarType::Bytes),
            Type::ImplTrait(_) => Err(SkipReason::Closure),
            // 2.8: no scalar/handle lane fits. A by-value `Deserialize` type (a
            // local serde struct, or a whitelisted std shape like `Vec<f64>`)
            // crosses the wide (msgpack) lane; anything else stays the skip below.
            _ => match self.wide_fallback(ty, SerdeTrait::Deserialize) {
                Some(inner) => Ok(ScalarType::Wide(inner)),
                None => Err(SkipReason::UnsupportedType(format!("{ty:?}"))),
            },
        }
    }

    /// 1.2.4: the target wrapper name for an `Option<…>` return whose inner is an
    /// owned bridged handle. `Option<Self>` (Datelike `with_year`) → the own type;
    /// `Option<BridgedType>` (`with_month -> Option<NaiveDate>`) → that type. `None`
    /// for `Option<scalar>` / `Option<Borrowed<'_>>` / anything else, leaving it to
    /// the wrapper-rescue path or a skip. A lifetime-bearing inner is rejected.
    fn option_ref_target(
        &self,
        rp: &rustdoc_types::Path,
        bt: &BridgeType,
        self_aliases: &[&str],
    ) -> Option<String> {
        match vec_first_type_arg(rp)? {
            Type::Generic(g) if g == "Self" || self_aliases.contains(&g.as_str()) => {
                Some(bt.name.clone())
            }
            Type::ResolvedPath(inner) => {
                if returns_self(bt, inner, self_aliases) {
                    return Some(bt.name.clone());
                }
                if self.ref_type_names.contains(&inner.path)
                    && !has_lifetime_args(inner)
                    && !inner_has_lifetime(inner, self.doc)
                {
                    return Some(inner.path.clone());
                }
                None
            }
            _ => None,
        }
    }

    fn classify_return(
        &self,
        output: &Option<Type>,
        bt: &BridgeType,
        self_aliases: &[&str],
    ) -> Result<BridgeReturn, SkipReason> {
        let Some(ty) = output else {
            return Ok(BridgeReturn::Void);
        };

        // 2.8: a `[type."T"] wide = true` overlay forces the wide lane over an
        // opaque-handle return (checked before the handle arms so it wins). A
        // return value is SERIALIZED on the Rust side.
        if self.wide_override_for(ty) == Some(true) {
            if let Some(inner) = self.render_wide_ty(ty) {
                return Ok(BridgeReturn::Wide(inner));
            }
        }

        match ty {
            Type::Primitive(p) => match p.as_str() {
                "bool" => Ok(BridgeReturn::Bool),
                p @ ("u8" | "u16" | "u32" | "u64" | "usize") => {
                    Ok(BridgeReturn::Uint(p.to_string()))
                }
                p @ ("i8" | "i16" | "i32" | "i64" | "isize") => {
                    Ok(BridgeReturn::Int(p.to_string()))
                }
                other => Err(SkipReason::UnsupportedType(other.to_string())),
            },
            Type::ResolvedPath(rp) => {
                // HashMap<String, V> / Vec<V> marshal as real dict[str, V] / list[V]
                // (V in bool/int/str). Checked before the generic-path arms so the
                // container idents are not mistaken for opaque type references.
                if rp_name(&rp.path) == "HashMap" {
                    return classify_map_return(rp);
                }
                if rp_name(&rp.path) == "Vec" {
                    // 1.2.2: `Vec<u8>` is a byte string (a digest / raw buffer), not
                    // a `list[int]`. Intercepted before the generic `Vec<V>` list
                    // arm, mirroring the macro's own `Vec<u8>`-before-`Vec<V>` order.
                    if first_type_arg_is_u8(rp) {
                        return Ok(BridgeReturn::Bytes);
                    }
                    // Vec-of-handle: `Vec<Other>` where the element names another
                    // live bridged opaque type (no lifetime). The owned Vec's
                    // elements move into per-element boxed handles on the
                    // `TAG_LIST_BIT | TAG_REF` wire (see `HandleList`). Checked
                    // before the scalar list arm so the element ident is not
                    // rejected as an unsupported scalar.
                    if let Some(Type::ResolvedPath(elem)) = vec_first_type_arg(rp) {
                        if self.ref_type_names.contains(&elem.path)
                            && !has_lifetime_args(elem)
                            && !inner_has_lifetime(elem, self.doc)
                        {
                            return Ok(BridgeReturn::HandleList(elem.path.clone()));
                        }
                    }
                    return classify_vec_return(rp);
                }
                // 1.2.2: a digest output — `Array<u8, _>` / `GenericArray<u8, _>`
                // (sha2's `finalize`/`finalize_reset` return `Array<u8,
                // OutputSize<D>>`). The const-generic length is irrelevant at the
                // boundary; the bytes cross length-explicit as a `Vec<u8>`.
                if matches!(rp_name(&rp.path), "Array" | "GenericArray") && first_type_arg_is_u8(rp)
                {
                    return Ok(BridgeReturn::Bytes);
                }
                // 1.2.3: an owned `String` return crosses on the same JacBuf lane as
                // a borrowed `&str` (no new tag). Codegen already normalizes the
                // `Str` return to an owned `-> String` via `.to_string()`, which is a
                // clone on a `String` source and an allocation on `&str` — both
                // valid. `String` carries no lifetime, so it's a plain owned value.
                if rp.path == "String" {
                    return Ok(BridgeReturn::Str);
                }
                // A `std::cmp::Ordering` return (`Version::cmp_precedence`) has no
                // primitive spelling, so it fits no scalar arm — but its three
                // variants map onto an `i8` (-1/0/1). Lower it there: codegen wraps
                // the call in a `match` and emits `-> i8`, so it rides the existing
                // `TAG_INT` lane through the macro and both loaders. Matched on the
                // leaf name like the other std leaves (`String`/`Vec`/`Option`).
                if rp_name(&rp.path) == "Ordering" {
                    return Ok(BridgeReturn::Ordering);
                }
                // A `-> Self` return reads as the type's own path. For a
                // monomorphized type that path is still the ORIGINAL generic name
                // (`Date`), not the mono name (`DateUtc`) — match on origin.
                if returns_self(bt, rp, self_aliases) {
                    return Ok(BridgeReturn::OwnSelf);
                }
                // 1.2.4: `Option<Self>` / `Option<BridgedType>` — a nullable owned
                // handle (`with_year -> Option<Self>`, `with_month ->
                // Option<NaiveDate>`). Checked before the wrapper-rescue path so a
                // real bridged inner isn't mistaken for a borrowed view.
                if rp_name(&rp.path) == "Option" {
                    if let Some(target) = self.option_ref_target(rp, bt, self_aliases) {
                        return Ok(BridgeReturn::OptRef(target));
                    }
                    // M6: `Option<String>` — a nullable owned string. Crosses the
                    // `Str` JacBuf lane with `TAG_OPT_BIT` set; the macro signals
                    // `None` in-band as a null buffer pointer. Only owned `String`
                    // qualifies (an `Option<&str>` inner carries a lifetime); checked
                    // after the owned-handle arm so a bridged inner isn't shadowed.
                    if let Some(Type::ResolvedPath(inner)) = vec_first_type_arg(rp) {
                        if rp_name(&inner.path) == "String" {
                            return Ok(BridgeReturn::OptStrValue);
                        }
                        // M6: `Option<Vec<u8>>` (or `Option<Array<u8, _>>`) — a
                        // nullable owned byte string. The byte analogue of
                        // `Option<String>`: crosses the `Bytes` JacBuf lane with
                        // `TAG_OPT_BIT` set, `None` as a null buffer pointer. Mirror
                        // the plain-`Bytes` return arm's `Vec<u8>` / `Array<u8, _>`
                        // recognition on the Option's inner path.
                        if matches!(rp_name(&inner.path), "Vec" | "Array" | "GenericArray")
                            && first_type_arg_is_u8(inner)
                        {
                            return Ok(BridgeReturn::OptBytesValue);
                        }
                    }
                    // Option<int>: a nullable scalar integer (`Regex::shortest_match
                    // -> Option<usize>`). Crosses `TAG_OPT_BIT | TAG_INT/UINT` as an
                    // 8-byte JacBuf whose null pointer signals None in-band - the
                    // same channel discipline as Option<String>, never a sentinel.
                    if let Some(Type::Primitive(p)) = vec_first_type_arg(rp) {
                        match p.as_str() {
                            "u8" | "u16" | "u32" | "u64" | "usize" => {
                                return Ok(BridgeReturn::OptUintValue(p.clone()));
                            }
                            "i8" | "i16" | "i32" | "i64" | "isize" => {
                                return Ok(BridgeReturn::OptIntValue(p.clone()));
                            }
                            _ => {}
                        }
                    }
                }
                // 1.2.4: a bare cross-type return naming another bridged (non-mono)
                // type is a fresh owned handle (`and_hms -> NaiveDateTime`). `Self`
                // was already caught above, so this only fires for a DIFFERENT type.
                if self.ref_type_names.contains(&rp.path) {
                    if has_lifetime_args(rp) || inner_has_lifetime(rp, self.doc) {
                        return Err(SkipReason::LifetimeBorrow);
                    }
                    return Ok(BridgeReturn::Ref(rp.path.clone()));
                }
                if rp.path == "Result" {
                    return self.classify_result_return(rp, bt, self_aliases);
                }
                if has_lifetime_args(rp) || inner_has_lifetime(rp, self.doc) {
                    return Err(SkipReason::LifetimeBorrow);
                }
                // 2.8: no scalar/handle lane fit — a by-value `Serialize` type
                // (a local serde struct rustdoc missed no lane for) crosses wide.
                if let Some(inner) = self.wide_fallback(ty, SerdeTrait::Serialize) {
                    return Ok(BridgeReturn::Wide(inner));
                }
                Err(SkipReason::UnsupportedType(rp.path.clone()))
            }
            // A `&Self` / `&mut Self` return on a method with a receiver is the
            // SELF-IDENTITY lane (builder-chain setters: `case_insensitive(&mut
            // self, bool) -> &mut Self`). Checked before the lifetime guard - the
            // borrow IS the receiver, so no lifetime ever escapes. The caller
            // (`classify_fn`) rejects a receiver-less `&Self` return.
            Type::BorrowedRef { type_, .. }
                if match type_.as_ref() {
                    Type::Generic(g) => g == "Self" || self_aliases.contains(&g.as_str()),
                    Type::ResolvedPath(rp) => returns_self(bt, rp, self_aliases),
                    _ => false,
                } =>
            {
                Ok(BridgeReturn::SelfRef)
            }
            Type::BorrowedRef {
                lifetime: Some(_), ..
            } => Err(SkipReason::LifetimeBorrow),
            Type::BorrowedRef { type_, .. } => match type_.as_ref() {
                Type::Primitive(p) if p == "str" => Ok(BridgeReturn::Str),
                _ => Err(SkipReason::LifetimeBorrow),
            },
            // 1.1.2: a bare `-> D` inside a flattened blanket impl is a `-> Self`
            // return (sha2's `Digest::new() -> D`). Any other free generic stays a
            // Generic skip.
            Type::Generic(g) if g == "Self" || self_aliases.contains(&g.as_str()) => {
                Ok(BridgeReturn::OwnSelf)
            }
            Type::Generic(_) => Err(SkipReason::Generic),
            Type::ImplTrait(_) => Err(SkipReason::Cursor),
            // 2.8: a by-value tuple/array/slice return of wide values (`(f64, f64)`)
            // crosses the wide lane; everything else stays an honest skip.
            _ => match self.wide_fallback(ty, SerdeTrait::Serialize) {
                Some(inner) => Ok(BridgeReturn::Wide(inner)),
                None => Err(SkipReason::UnsupportedType(format!("{ty:?}"))),
            },
        }
    }

    fn classify_result_return(
        &self,
        rp: &rustdoc_types::Path,
        bt: &BridgeType,
        self_aliases: &[&str],
    ) -> Result<BridgeReturn, SkipReason> {
        let Some(args) = &rp.args else {
            return Err(SkipReason::Generic);
        };
        let rustdoc_types::GenericArgs::AngleBracketed { args, .. } = args.as_ref() else {
            return Err(SkipReason::Generic);
        };
        let ok_ty = args.first().and_then(|a| {
            if let rustdoc_types::GenericArg::Type(t) = a {
                Some(t)
            } else {
                None
            }
        });
        match ok_ty {
            Some(Type::ResolvedPath(ok_rp)) if returns_self(bt, ok_rp, self_aliases) => {
                Ok(BridgeReturn::OwnSelfResult)
            }
            // `Result<Self, E>` — the literal `Self` alias always denotes this type
            // (rustdoc renders an inherent `fn parse() -> Result<Self, Error>` with
            // the ok type as `Generic("Self")`, and `self_aliases` holds only the
            // concrete name). 1.1.2: `Result<D, E>` in a flattened blanket impl is
            // likewise `Result<Self, E>`. The error crosses Display-stringified
            // (see `OwnSelfResult` codegen), so a concrete `semver::Error` works
            // exactly like regex's `String`.
            Some(Type::Generic(g)) if g == "Self" || self_aliases.contains(&g.as_str()) => {
                Ok(BridgeReturn::OwnSelfResult)
            }
            // A CROSS-TYPE fallible producer: `Result<Other, E>` whose ok type is a
            // DIFFERENT live bridged opaque type (`RegexBuilder::build ->
            // Result<Regex, Error>`). Mirrors the 1.2.4 `Ref` rule for the ok slot;
            // the error crosses Display-stringified through the module's
            // `#[jac_error]` channel exactly like `OwnSelfResult` (and is demoted by
            // `reconcile_fallible_returns` when the crate has no error type).
            Some(Type::ResolvedPath(ok_rp))
                if self.ref_type_names.contains(&ok_rp.path)
                    && !has_lifetime_args(ok_rp)
                    && !inner_has_lifetime(ok_rp, self.doc) =>
            {
                Ok(BridgeReturn::RefResult(ok_rp.path.clone()))
            }
            _ => Err(SkipReason::UnsupportedType(format!("{args:?}"))),
        }
    }

    // ── owning-wrapper synthesis (M4 Phase B v1) ──────────────────────────────

    /// Attempt to rescue a borrowed return via an owning wrapper.
    ///
    /// The mechanical rule: an owner method `fn(&self, input: &str) ->
    /// Option<Borrowed<'_>>` where `Borrowed` is an in-crate struct carrying a
    /// lifetime, *and* `Borrowed` exposes at least one int-free reader. Returns
    /// the producer `BridgeFn` (emitted on the owner) plus the deferred wrapper
    /// request. `None` if any condition fails — the caller then records the
    /// original skip, so a wrapper with no readable surface (e.g. `Captures`,
    /// whose readers are all `usize`/nested `Match`) stays a precise skip.
    fn try_owning_wrapper(
        &self,
        method_name: &str,
        f: &rustdoc_types::Function,
        bt: &BridgeType,
        self_aliases: &[&str],
    ) -> Option<(BridgeFn, Vec<PendingWrapper>)> {
        // Must be a method (has a receiver), not a constructor.
        if !f.sig.inputs.iter().any(|(n, _)| n == "self") {
            return None;
        }
        // Exactly one non-self param, and it must be the `&str` the wrapper owns.
        // (A single owned input keeps the ouroboros unambiguous; multi-`&str`
        // producers would need to own several buffers — deferred.)
        let mut params = vec![];
        for (pname, pty) in &f.sig.inputs {
            if pname == "self" {
                continue;
            }
            match self.classify_param_type(pty, self_aliases) {
                Ok(scalar) => params.push(BridgeParam {
                    name: pname.clone(),
                    ty: scalar,
                }),
                Err(_) => return None,
            }
        }
        // The FIRST param must be the `&str` the wrapper owns; any extras must be
        // plain integer scalars forwarded verbatim (`find_at`'s `start: usize`).
        // A single-`&str` producer becomes THE root (the shared `wrap` ctor); a
        // multi-param producer builds the wrapper INLINE in its own body, since
        // `wrap` is keyed to exactly one root call.
        if params.is_empty() || params[0].ty != ScalarType::Str {
            return None;
        }
        if !params[1..]
            .iter()
            .all(|p| matches!(p.ty, ScalarType::Int(_) | ScalarType::Uint(_)))
        {
            return None;
        }

        // Return must be `Option<Borrowed<'_>>` with `Borrowed` an in-crate
        // lifetime-bearing struct.
        let (borrowed_id, borrowed_name, lifetimes) = self.option_borrowed_struct(&f.sig.output)?;

        // The wrapper is viable only if the borrowed type has a readable surface.
        // Its readers may themselves be nested producers (a reader returning
        // `Option<Borrowed<'h>>`), which pend further wrappers — collected here.
        let mut seen = vec![];
        let (readers, reader_skips, nested) =
            self.discover_readers(borrowed_id, &borrowed_name, &mut seen);
        if readers.is_empty() {
            return None;
        }

        let wrapper_name = format!("Owned{borrowed_name}");
        let borrowed_path = format!("{}::{}", self.module_name, borrowed_name);
        let is_root = params.len() == 1;
        let ret = if is_root {
            BridgeReturn::OptWrapper(wrapper_name.clone())
        } else {
            BridgeReturn::OptWrapperInline {
                wrapper: wrapper_name.clone(),
                borrowed_path: borrowed_path.clone(),
                lifetimes,
            }
        };
        let producer = BridgeFn {
            name: method_name.to_string(),
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
        };
        let pending = PendingWrapper {
            wrapper_name,
            borrowed_id,
            wrapper: OwningWrapper {
                borrowed_path,
                lifetimes,
                // An inline producer builds its instances itself; only the
                // single-`&str` shape supplies the shared root `wrap` ctor.
                root: is_root.then(|| RootProducer {
                    owner_inner_path: bt.inner_path.clone(),
                    producer_call: method_name.to_string(),
                }),
                kind: WrapperKind::Owning,
            },
            readers,
            reader_skips,
        };
        let mut pendings = vec![pending];
        pendings.extend(nested);
        Some((producer, pendings))
    }

    /// A wrapper reader that returns `Option<Borrowed<'h>>` (another in-crate
    /// lifetime-bearing struct) becomes a NESTED producer: `Owned<Borrowed>` built
    /// inline from the parent wrapper's borrowing value, sharing its owned buffer
    /// via an `Arc` clone. Returns the nested producer reader plus the wrapper
    /// requests it implies (the nested wrapper, `root: None`, plus anything IT
    /// nests). `None` if the borrowed type has no readable surface — the caller
    /// then records the original lifetime-borrow skip.
    fn try_nested_wrapper(
        &self,
        reader_name: &str,
        params: &[BridgeParam],
        output: &Option<Type>,
        seen: &mut Vec<u32>,
    ) -> Option<(BridgeFn, Vec<PendingWrapper>)> {
        let (borrowed_id, borrowed_name, lifetimes) = self.option_borrowed_struct(output)?;
        let (readers, reader_skips, deeper) =
            self.discover_readers(borrowed_id, &borrowed_name, seen);
        if readers.is_empty() {
            return None;
        }
        let wrapper_name = format!("Owned{borrowed_name}");
        let reader = BridgeFn {
            name: reader_name.to_string(),
            export_name: None,
            params: params.to_vec(),
            ret: BridgeReturn::OptWrapper(wrapper_name.clone()),
            throws: None,
            recv: Recv::Inner,
            is_async: false,
            ret_ownership: Ownership::Owned,
            via_trait: None,
            self_mut: false,
            consumes_self: false,
            is_static: false,
            field_read: None,
            std_from_str: false,
        };
        let pending = PendingWrapper {
            wrapper_name,
            borrowed_id,
            wrapper: OwningWrapper {
                borrowed_path: format!("{}::{}", self.module_name, borrowed_name),
                lifetimes,
                // Nested-only here; if a root producer (e.g. `find`) also targets
                // this type, its `root: Some(..)` merges in at materialization.
                root: None,
                kind: WrapperKind::Owning,
            },
            readers,
            reader_skips,
        };
        let mut pendings = vec![pending];
        pendings.extend(deeper);
        Some((reader, pendings))
    }

    /// The NON-NULLABLE twin of [`Self::try_nested_wrapper`]: a wrapper reader
    /// returning a BARE in-crate lifetime struct (`Captures::get_match ->
    /// Match<'h>` - group 0 always exists, so no `Option`). The child wrapper is
    /// built inline exactly like the nested case, only without the `?`; the
    /// producer's return is `Wrapper(name)` (`recv: Inner`).
    fn try_nested_wrapper_plain(
        &self,
        reader_name: &str,
        params: &[BridgeParam],
        output: &Option<Type>,
        seen: &mut Vec<u32>,
    ) -> Option<(BridgeFn, Vec<PendingWrapper>)> {
        let (borrowed_id, borrowed_name, lifetimes) = self.plain_borrowed_struct(output)?;
        let (readers, reader_skips, deeper) =
            self.discover_readers(borrowed_id, &borrowed_name, seen);
        if readers.is_empty() {
            return None;
        }
        let wrapper_name = format!("Owned{borrowed_name}");
        let reader = BridgeFn {
            name: reader_name.to_string(),
            export_name: None,
            params: params.to_vec(),
            ret: BridgeReturn::Wrapper(wrapper_name.clone()),
            throws: None,
            recv: Recv::Inner,
            is_async: false,
            ret_ownership: Ownership::Owned,
            via_trait: None,
            self_mut: false,
            consumes_self: false,
            is_static: false,
            field_read: None,
            std_from_str: false,
        };
        let pending = PendingWrapper {
            wrapper_name,
            borrowed_id,
            wrapper: OwningWrapper {
                borrowed_path: format!("{}::{}", self.module_name, borrowed_name),
                lifetimes,
                root: None,
                kind: WrapperKind::Owning,
            },
            readers,
            reader_skips,
        };
        let mut pendings = vec![pending];
        pendings.extend(deeper);
        Some((reader, pendings))
    }

    /// If `output` is a BARE own-crate struct with ≥1 lifetime param, return
    /// `(id, name, lifetime_count)` - the non-`Option` sibling of
    /// [`Self::option_borrowed_struct`].
    fn plain_borrowed_struct(&self, output: &Option<Type>) -> Option<(u32, String, usize)> {
        let Some(Type::ResolvedPath(rp)) = output else {
            return None;
        };
        if rp_name(&rp.path) == "Option" {
            return None;
        }
        let item = self.doc.index.get(&rp.id)?;
        let ItemEnum::Struct(s) = &item.inner else {
            return None;
        };
        let lifetimes = s
            .generics
            .params
            .iter()
            .filter(|p| matches!(p.kind, rustdoc_types::GenericParamDefKind::Lifetime { .. }))
            .count();
        if lifetimes == 0 {
            return None;
        }
        let name = item.name.clone()?;
        Some((rp.id.0, name, lifetimes))
    }

    /// Attempt to rescue an ITERATOR return via a cursor or a Vec-as-drain wrapper.
    ///
    /// The rule: an owner method `fn(&self, input: &str) -> Iter<'_,…>` where `Iter`
    /// is an in-crate struct implementing `Iterator`. The synthesized wrapper owns
    /// the input (and the owner, for a cursor) and exposes a single `next` pull
    /// method — always constructed, so the producer returns the wrapper directly
    /// (not `Option`). Two item shapes:
    ///   * `Item = &str` → a DRAIN: eagerly collect owned `String`s, `next -> Option<String>`.
    ///   * `Item = Borrowed<'h>` (an in-crate lifetime struct with a readable
    ///     surface) → a CURSOR: `next -> Option<Owned<Borrowed>>`, each pulled item
    ///     an owning wrapper sharing the cursor's input `Arc` (the nested rule, per
    ///     iteration). The item wrapper is pended (and merges with any root-produced
    ///     one, e.g. `find`'s `OwnedMatch`).
    ///
    /// `None` if the return isn't an in-crate iterator, or its item is an unreadable
    /// struct — the caller then records the original cursor/lifetime skip.
    fn try_cursor_wrapper(
        &self,
        method_name: &str,
        f: &rustdoc_types::Function,
        bt: &BridgeType,
        self_aliases: &[&str],
    ) -> Option<(BridgeFn, Vec<PendingWrapper>)> {
        if !f.sig.inputs.iter().any(|(n, _)| n == "self") {
            return None;
        }
        // The first non-self param must be the `&str` buffer the wrapper owns.
        // Extra integer scalars (`splitn`'s `limit: usize`) are forwarded - legal
        // for a DRAIN (which collects eagerly, so no lifetime survives) but not for
        // a CURSOR, whose hardcoded `wrap(owner, input)` owns exactly one buffer;
        // the cursor arm below re-checks the single-param shape.
        let mut params = vec![];
        for (pname, pty) in &f.sig.inputs {
            if pname == "self" {
                continue;
            }
            match self.classify_param_type(pty, self_aliases) {
                Ok(scalar) => params.push(BridgeParam {
                    name: pname.clone(),
                    ty: scalar,
                }),
                Err(_) => return None,
            }
        }
        if params.is_empty() || params[0].ty != ScalarType::Str {
            return None;
        }
        if !params[1..]
            .iter()
            .all(|p| matches!(p.ty, ScalarType::Int(_) | ScalarType::Uint(_)))
        {
            return None;
        }

        // Return must be a bare in-crate iterator struct (not Option / Result).
        let Some(Type::ResolvedPath(rp)) = &f.sig.output else {
            return None;
        };
        let iter_name = rp.path.clone();
        let iter_id = rp.id.0;
        let iter_lifetimes = self.struct_lifetimes(iter_id)?;
        let item = self.iterator_item(iter_id)?;

        let wrapper_name = format!("Owned{iter_name}");
        let root = RootProducer {
            owner_inner_path: bt.inner_path.clone(),
            producer_call: method_name.to_string(),
        };

        // Classify the iterator's Item to pick cursor vs drain.
        let (next_reader, item_pendings, kind) = match &item {
            // Item = &str → drain of owned Strings.
            Type::BorrowedRef { type_, .. } if matches!(type_.as_ref(), Type::Primitive(p) if p == "str") =>
            {
                let next = BridgeFn {
                    name: "next".to_string(),
                    export_name: None,
                    params: vec![],
                    ret: BridgeReturn::OptStr,
                    throws: None,
                    recv: Recv::DrainNext,
                    is_async: false,
                    ret_ownership: Ownership::Owned,
                    via_trait: None,
                    self_mut: false,
                    consumes_self: false,
                    is_static: false,
                    field_read: None,
                    std_from_str: false,
                };
                let kind = WrapperKind::Drain {
                    params: params.clone(),
                    collect: DrainCollect::IterStr,
                };
                (next, vec![], kind)
            }
            // Item = in-crate lifetime struct with readers → cursor of nested wrappers.
            Type::ResolvedPath(item_rp) => {
                // A cursor's `wrap(owner, input)` owns exactly one buffer; a
                // multi-param iterator producer has no cursor shape yet.
                if params.len() != 1 {
                    return None;
                }
                let item_name = item_rp.path.clone();
                let item_id = item_rp.id.0;
                // The item type must itself be a readable in-crate lifetime struct.
                self.struct_lifetimes(item_id)?;
                let mut seen = vec![];
                let (readers, reader_skips, nested) =
                    self.discover_readers(item_id, &item_name, &mut seen);
                if readers.is_empty() {
                    return None;
                }
                let item_wrapper = format!("Owned{item_name}");
                let next = BridgeFn {
                    name: "next".to_string(),
                    export_name: None,
                    params: vec![],
                    ret: BridgeReturn::OptWrapper(item_wrapper.clone()),
                    throws: None,
                    recv: Recv::IterNext,
                    is_async: false,
                    ret_ownership: Ownership::Owned,
                    via_trait: None,
                    self_mut: false,
                    consumes_self: false,
                    is_static: false,
                    field_read: None,
                    std_from_str: false,
                };
                // Pend the item wrapper (an owning wrapper, built inline by `next`;
                // root None so it merges with any root producer like `find`).
                let mut pendings = vec![PendingWrapper {
                    wrapper_name: item_wrapper.clone(),
                    borrowed_id: item_id,
                    wrapper: OwningWrapper {
                        borrowed_path: format!("{}::{}", self.module_name, item_name),
                        lifetimes: self.struct_lifetimes(item_id).unwrap_or(1),
                        root: None,
                        kind: WrapperKind::Owning,
                    },
                    readers,
                    reader_skips,
                }];
                pendings.extend(nested);
                (next, pendings, WrapperKind::Cursor { item_wrapper })
            }
            _ => return None,
        };

        let producer = BridgeFn {
            name: method_name.to_string(),
            export_name: None,
            params,
            ret: BridgeReturn::Wrapper(wrapper_name.clone()),
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
        };
        // The cursor/drain wrapper itself: its only reader is the synthesized `next`.
        let mut pendings = vec![PendingWrapper {
            wrapper_name,
            borrowed_id: iter_id,
            wrapper: OwningWrapper {
                borrowed_path: format!("{}::{}", self.module_name, iter_name),
                lifetimes: iter_lifetimes,
                root: Some(root),
                kind,
            },
            readers: vec![next_reader],
            reader_skips: vec![],
        }];
        pendings.extend(item_pendings);
        Some((producer, pendings))
    }

    /// Attempt to rescue a Vec/slice-of-string RETURN via a drain wrapper.
    ///
    /// Unlike [`Self::try_cursor_wrapper`] (which owns a `&str` input and lazily
    /// pulls from an in-crate iterator), this rule fires on a method that returns
    /// an owned or borrowed *string collection directly* — `Vec<String>`,
    /// `&[String]`, `Vec<&str>`, or `&[&str]` (e.g. `RegexSet::patterns(&self) ->
    /// &[String]`). The synthesized wrapper eagerly copies every element into an
    /// owned `Vec<String>` and drains it via `next -> Option<String>`. The
    /// producer may take zero or more scalar params (all forwarded); it needs no
    /// owned input buffer because the collected Strings are self-owned.
    ///
    /// `method_id` is the producer's unique rustdoc item id — used as the
    /// wrapper's merge key so distinct drains never collide (there is no borrowed
    /// struct id to key on, and item ids are unique across the whole index).
    /// `None` if the return isn't a recognised string collection, or any param
    /// can't cross the boundary — the caller then records the original skip.
    fn try_vec_drain(
        &self,
        method_id: u32,
        method_name: &str,
        f: &rustdoc_types::Function,
        bt: &BridgeType,
        self_aliases: &[&str],
    ) -> Option<(BridgeFn, Vec<PendingWrapper>)> {
        // Must be a method (borrows the owner) — an associated fn has no owner to
        // call the producer through.
        if !f.sig.inputs.iter().any(|(n, _)| n == "self") {
            return None;
        }
        // Every non-self param must cross the boundary as a scalar.
        let mut params = vec![];
        for (pname, pty) in &f.sig.inputs {
            if pname == "self" {
                continue;
            }
            match self.classify_param_type(pty, self_aliases) {
                Ok(scalar) => params.push(BridgeParam {
                    name: pname.clone(),
                    ty: scalar,
                }),
                Err(_) => return None,
            }
        }
        // Classify the return into a drain collection shape; bail if it isn't one.
        let collect = drain_collect_of(f.sig.output.as_ref()?)?;

        // Name the wrapper after the method (there is no iterator struct to borrow
        // a name from): `patterns` -> `OwnedPatterns`.
        let wrapper_name = format!("Owned{}", to_camel(method_name));
        let next = BridgeFn {
            name: "next".to_string(),
            export_name: None,
            params: vec![],
            ret: BridgeReturn::OptStr,
            throws: None,
            recv: Recv::DrainNext,
            is_async: false,
            ret_ownership: Ownership::Owned,
            via_trait: None,
            self_mut: false,
            consumes_self: false,
            is_static: false,
            field_read: None,
            std_from_str: false,
        };
        let producer = BridgeFn {
            name: method_name.to_string(),
            export_name: None,
            params: params.clone(),
            ret: BridgeReturn::Wrapper(wrapper_name.clone()),
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
        };
        let pending = PendingWrapper {
            wrapper_name: wrapper_name.clone(),
            borrowed_id: method_id,
            wrapper: OwningWrapper {
                // No borrowed struct here — record the owner path as a stable
                // placeholder. Codegen's Drain arm never reads `borrowed_path`.
                borrowed_path: bt.inner_path.clone(),
                lifetimes: 0,
                root: Some(RootProducer {
                    owner_inner_path: bt.inner_path.clone(),
                    producer_call: method_name.to_string(),
                }),
                kind: WrapperKind::Drain { params, collect },
            },
            readers: vec![next],
            reader_skips: vec![],
        };
        Some((producer, vec![pending]))
    }

    /// The CALLBACK rule: a `fn(&self, &str, R) -> Cow<str>` where `R: Replacer`
    /// (`Regex::replace_all`) becomes a callback method taking a `JacCallback`.
    /// Rust calls back into Jac once per match; the callback returns each match's
    /// replacement. This is the one vertical where the boundary is crossed
    /// inward — realized via the na trampoline (a `def:pub` C-ABI thunk) and a
    /// CPython CFUNCTYPE.  `replacen` (an extra `usize` limit param) stays a skip.
    fn try_callback_wrapper(
        &self,
        method_name: &str,
        f: &rustdoc_types::Function,
        bt: &BridgeType,
        // The callback rescue inspects param types structurally (haystack `&str` +
        // Replacer generic) rather than via `classify_param_type`, so self-aliases
        // don't participate; kept for a uniform rescue-rule signature.
        _self_aliases: &[&str],
    ) -> Option<(BridgeFn, Vec<PendingWrapper>)> {
        if !f.sig.inputs.iter().any(|(n, _)| n == "self") {
            return None;
        }
        // A generic type param bounded by a `Replacer` trait — the closure the
        // caller supplies. (regex: `pub fn replace_all<R: Replacer>(…)`.)
        let replacer_generic = self.replacer_generic_param(f)?;

        // Params besides self: exactly one `&str` (the haystack) and one generic
        // param that IS the Replacer generic — nothing else (so `replacen`, with
        // its extra usize limit, correctly falls through to a skip).
        let mut haystack: Option<String> = None;
        let mut callback: Option<String> = None;
        for (pname, pty) in &f.sig.inputs {
            if pname == "self" {
                continue;
            }
            match pty {
                Type::BorrowedRef { type_, .. } if matches!(type_.as_ref(), Type::Primitive(p) if p == "str") => {
                    if haystack.replace(pname.clone()).is_some() {
                        return None;
                    }
                }
                Type::Generic(g) if *g == replacer_generic => {
                    if callback.replace(pname.clone()).is_some() {
                        return None;
                    }
                }
                _ => return None,
            }
        }
        let haystack = haystack?;
        let callback = callback?;

        // Return must be a `Cow` (owned-or-borrowed string) — replace_all's return.
        let Some(Type::ResolvedPath(rp)) = &f.sig.output else {
            return None;
        };
        if !rp.path.ends_with("Cow") {
            return None;
        }

        // The closure argument the replacer walks is the crate's `Captures` type;
        // derive its path from the owner's inner path (`regex::Regex` -> `regex`).
        let crate_prefix = bt.inner_path.rsplit_once("::").map_or("", |(p, _)| p);
        let captures_path = format!("{crate_prefix}::Captures");

        let producer = BridgeFn {
            name: method_name.to_string(),
            export_name: None,
            params: vec![
                BridgeParam {
                    name: haystack,
                    ty: ScalarType::Str,
                },
                BridgeParam {
                    name: callback,
                    ty: ScalarType::Callback,
                },
            ],
            ret: BridgeReturn::ReplacerResult(captures_path),
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
        };
        Some((producer, vec![]))
    }

    /// The REPLACER `&str` MONOMORPHIZATION: a `fn(&self, …, rep: R) -> Cow<str>`
    /// where `R: Replacer` and every OTHER param is a plain scalar. The callback
    /// rule (which is stronger - Rust calls back into Jac per match) claims the
    /// exact `(haystack, R)` shape first; this rule catches what it declines
    /// (`replacen`, whose extra `limit: usize` the closure vertical can't carry)
    /// by pinning `R` to the literal `&str` replacement - `&str: Replacer` in the
    /// source crate, so the inner call compiles verbatim. The `Cow<'h, str>`
    /// return lowers to the owned `Str` lane (`.to_string()` via Display).
    fn try_replacer_str(
        &self,
        method_name: &str,
        f: &rustdoc_types::Function,
        self_aliases: &[&str],
    ) -> Option<(BridgeFn, Vec<PendingWrapper>)> {
        if !f.sig.inputs.iter().any(|(n, _)| n == "self") {
            return None;
        }
        let rep_generic = self.replacer_generic_param(f)?;

        let mut params = vec![];
        for (pname, pty) in &f.sig.inputs {
            if pname == "self" {
                continue;
            }
            if matches!(pty, Type::Generic(g) if *g == rep_generic) {
                params.push(BridgeParam {
                    name: pname.clone(),
                    ty: ScalarType::Str,
                });
                continue;
            }
            match self.classify_param_type(pty, self_aliases) {
                Ok(scalar) => params.push(BridgeParam {
                    name: pname.clone(),
                    ty: scalar,
                }),
                Err(_) => return None,
            }
        }

        // Return must be `Cow<'_, str>` - the owned-or-borrowed string every
        // replace-family method yields. The bytes variant (`Cow<[u8]>`) stays out.
        let Some(Type::ResolvedPath(rp)) = &f.sig.output else {
            return None;
        };
        if rp_name(&rp.path) != "Cow"
            || !matches!(vec_first_type_arg(rp), Some(Type::Primitive(p)) if p == "str")
        {
            return None;
        }

        let producer = BridgeFn {
            name: method_name.to_string(),
            export_name: None,
            params,
            ret: BridgeReturn::Str,
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
        };
        Some((producer, vec![]))
    }

    /// An INTEGER-ITERATOR COLLECT: `fn(&self, …) -> Iter<'_>` where `Iter` is an
    /// in-crate iterator whose `Item` is a scalar integer (`SetMatches::iter ->
    /// SetMatchesIter`, `Item = usize`). No cursor is synthesized - the sequence is
    /// eagerly collected into a `Vec<{int}>` riding the existing list-return lane
    /// (`TAG_LIST_BIT`), so no lifetime survives the call.
    fn try_int_collect(
        &self,
        method_name: &str,
        f: &rustdoc_types::Function,
        self_aliases: &[&str],
    ) -> Option<(BridgeFn, Vec<PendingWrapper>)> {
        if !f.sig.inputs.iter().any(|(n, _)| n == "self") {
            return None;
        }
        let mut params = vec![];
        for (pname, pty) in &f.sig.inputs {
            if pname == "self" {
                continue;
            }
            match self.classify_param_type(pty, self_aliases) {
                Ok(scalar) => params.push(BridgeParam {
                    name: pname.clone(),
                    ty: scalar,
                }),
                Err(_) => return None,
            }
        }
        let Some(Type::ResolvedPath(rp)) = &f.sig.output else {
            return None;
        };
        let item = self.iterator_item(rp.id.0)?;
        let elem = match &item {
            Type::Primitive(p)
                if matches!(
                    p.as_str(),
                    "u8" | "u16"
                        | "u32"
                        | "u64"
                        | "usize"
                        | "i8"
                        | "i16"
                        | "i32"
                        | "i64"
                        | "isize"
                ) =>
            {
                p.clone()
            }
            _ => return None,
        };
        let producer = BridgeFn {
            name: method_name.to_string(),
            export_name: None,
            params,
            ret: BridgeReturn::CollectList(format!("Vec<{elem}>")),
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
        };
        Some((producer, vec![]))
    }

    /// The name of a generic type param bounded (inline or via a where-clause) by
    /// a trait whose path ends in `Replacer`, if any.
    fn replacer_generic_param(&self, f: &rustdoc_types::Function) -> Option<String> {
        use rustdoc_types::{GenericBound, GenericParamDefKind, WherePredicate};
        let is_replacer = |bounds: &[GenericBound]| {
            bounds.iter().any(|b| {
                matches!(b, GenericBound::TraitBound { trait_, .. }
                    if trait_.path.ends_with("Replacer"))
            })
        };
        for p in &f.generics.params {
            if let GenericParamDefKind::Type { bounds, .. } = &p.kind {
                if is_replacer(bounds) {
                    return Some(p.name.clone());
                }
            }
        }
        for wp in &f.generics.where_predicates {
            if let WherePredicate::BoundPredicate {
                type_: Type::Generic(g),
                bounds,
                ..
            } = wp
            {
                if is_replacer(bounds) {
                    return Some(g.clone());
                }
            }
        }
        None
    }

    /// The `Item` associated type of an in-crate struct's `impl Iterator`, if it
    /// has one. Reads the assoc-type binding from the iterator's trait impl.
    fn iterator_item(&self, struct_id: u32) -> Option<Type> {
        let item = self.doc.index.get(&Id(struct_id))?;
        let ItemEnum::Struct(s) = &item.inner else {
            return None;
        };
        for impl_id in &s.impls {
            let Some(impl_item) = self.item(impl_id) else {
                continue;
            };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else {
                continue;
            };
            let Some(tr) = &impl_block.trait_ else {
                continue;
            };
            if tr.path != "Iterator" {
                continue;
            }
            for assoc_id in &impl_block.items {
                let Some(assoc) = self.item(assoc_id) else {
                    continue;
                };
                if assoc.name.as_deref() != Some("Item") {
                    continue;
                }
                if let ItemEnum::AssocType {
                    type_: Some(ty), ..
                } = &assoc.inner
                {
                    return Some(ty.clone());
                }
            }
        }
        None
    }

    /// Lifetime-param count of an in-crate struct, or `None` if it isn't a struct
    /// or has zero lifetimes (a lifetime-free return isn't a borrowed cursor).
    fn struct_lifetimes(&self, struct_id: u32) -> Option<usize> {
        let item = self.doc.index.get(&Id(struct_id))?;
        let ItemEnum::Struct(s) = &item.inner else {
            return None;
        };
        let n = s
            .generics
            .params
            .iter()
            .filter(|p| matches!(p.kind, rustdoc_types::GenericParamDefKind::Lifetime { .. }))
            .count();
        if n == 0 {
            None
        } else {
            Some(n)
        }
    }

    /// If `output` is `Option<T>` with `T` an own-crate struct that has ≥1
    /// lifetime param, return `(id, name, lifetime_count)`. Otherwise `None`.
    fn option_borrowed_struct(&self, output: &Option<Type>) -> Option<(u32, String, usize)> {
        let Some(Type::ResolvedPath(rp)) = output else {
            return None;
        };
        if rp.path != "Option" {
            return None;
        }
        let args = rp.args.as_ref()?;
        let rustdoc_types::GenericArgs::AngleBracketed { args, .. } = args.as_ref() else {
            return None;
        };
        let inner = args.iter().find_map(|a| match a {
            rustdoc_types::GenericArg::Type(Type::ResolvedPath(inner_rp)) => Some(inner_rp),
            _ => None,
        })?;
        let item = self.doc.index.get(&inner.id)?;
        let ItemEnum::Struct(s) = &item.inner else {
            return None;
        };
        let lifetimes = s
            .generics
            .params
            .iter()
            .filter(|p| matches!(p.kind, rustdoc_types::GenericParamDefKind::Lifetime { .. }))
            .count();
        if lifetimes == 0 {
            return None;
        }
        let name = item.name.clone()?;
        Some((inner.id.0, name, lifetimes))
    }

    /// Walk a borrowed type's inherent impls, splitting its public `&self`
    /// methods into int-free readers (str/bool returns, delegated through
    /// `self.inner`) and recorded skips (everything else — `usize`, nested
    /// borrows, …), so a wrapped type's whole surface stays honestly counted.
    fn discover_readers(
        &self,
        borrowed_id: u32,
        borrowed_name: &str,
        seen: &mut Vec<u32>,
    ) -> (Vec<BridgeFn>, Vec<Skip>, Vec<PendingWrapper>) {
        // Cycle guard: a wrapper reachable from its own reader chain would recurse
        // forever. `seen` carries the borrowed-type ids already being expanded.
        if seen.contains(&borrowed_id) {
            return (vec![], vec![], vec![]);
        }
        seen.push(borrowed_id);

        let impl_ids: Vec<Id> = self
            .doc
            .index
            .get(&Id(borrowed_id))
            .and_then(|item| match &item.inner {
                ItemEnum::Struct(s) => Some(s.impls.clone()),
                _ => None,
            })
            .unwrap_or_default();

        let mut readers: Vec<BridgeFn> = vec![];
        let mut skips: Vec<Skip> = vec![];
        let mut nested_pendings: Vec<PendingWrapper> = vec![];
        let mut seen_names: Vec<String> = vec![];

        for impl_id in impl_ids {
            let Some(impl_item) = self.item(&impl_id) else {
                continue;
            };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else {
                continue;
            };
            if impl_block.trait_.is_some() {
                continue;
            }
            for method_id in &impl_block.items {
                let Some(method) = self.item(method_id) else {
                    continue;
                };
                let ItemEnum::Function(f) = &method.inner else {
                    continue;
                };
                if matches!(
                    method.visibility,
                    rustdoc_types::Visibility::Crate | rustdoc_types::Visibility::Restricted { .. }
                ) {
                    continue;
                }
                // Readers must borrow the wrapped value — skip associated fns.
                if !f.sig.inputs.iter().any(|(n, _)| n == "self") {
                    continue;
                }
                let mname = method.name.clone().unwrap_or_default();
                if mname.is_empty() || seen_names.contains(&mname) {
                    continue;
                }
                seen_names.push(mname.clone());
                let item_path = format!("{borrowed_name}::{mname}");

                // Params must all cross the boundary.
                let mut params = vec![];
                let mut param_err = None;
                for (pname, pty) in &f.sig.inputs {
                    if pname == "self" {
                        continue;
                    }
                    // Wrapper readers are classified against the WRAPPER type, not
                    // the flattened origin, so no self-aliases apply here.
                    match self.classify_param_type(pty, &[]) {
                        Ok(scalar) => params.push(BridgeParam {
                            name: pname.clone(),
                            ty: scalar,
                        }),
                        Err(r) => {
                            param_err = Some(r);
                            break;
                        }
                    }
                }
                if let Some(reason) = param_err {
                    skips.push(Skip {
                        item: item_path,
                        reason,
                    });
                    continue;
                }

                match self.classify_reader_return(&f.sig.output) {
                    Ok(ret) => readers.push(BridgeFn {
                        name: mname,
                        export_name: None,
                        params,
                        ret,
                        throws: None,
                        recv: Recv::Inner,
                        is_async: false,
                        ret_ownership: Ownership::Owned,
                        via_trait: None,
                        self_mut: false,
                        consumes_self: false,
                        is_static: false,
                        field_read: None,
                        std_from_str: false,
                    }),
                    // A reader whose return is `Option<Borrowed<'h>>` isn't a dead
                    // skip — it's a NESTED producer of another owning wrapper, so
                    // long as that borrowed type is itself readable. Recurse.
                    Err(reason) => {
                        match self
                            .try_nested_wrapper(&mname, &params, &f.sig.output, seen)
                            .or_else(|| {
                                self.try_nested_wrapper_plain(&mname, &params, &f.sig.output, seen)
                            }) {
                            Some((reader, pendings)) => {
                                readers.push(reader);
                                nested_pendings.extend(pendings);
                            }
                            None => skips.push(Skip {
                                item: item_path,
                                reason,
                            }),
                        }
                    }
                }
            }
        }

        readers.sort_by(|a, b| a.name.cmp(&b.name));
        skips.sort_by(|a, b| a.item.cmp(&b.item));
        // Pop: `seen` is the ACTIVE expansion path (prevents A->B->A cycles), not a
        // visited-ever set. Popping lets two sibling readers of the same parent
        // both produce the same nested wrapper (e.g. `Captures::name` AND
        // `Captures::get` each yield an `OwnedMatch`) — the duplicate pending
        // wrappers merge by name later. Without the pop the second sibling is
        // spuriously cycle-guarded out and its method silently vanishes.
        seen.retain(|&id| id != borrowed_id);
        (readers, skips, nested_pendings)
    }

    /// Return classifier for a wrapper reader. Unlike [`Self::classify_return`],
    /// a `&str` return with a *named* lifetime is fine — the reader immediately
    /// copies it to an owned `String` (the wrapper owns the borrowed-from buffer),
    /// so `Match::as_str -> &'h str` is a reader, not a lifetime-borrow skip. Only
    /// `bool` and `&str` cross; everything else stays a recorded skip.
    fn classify_reader_return(&self, output: &Option<Type>) -> Result<BridgeReturn, SkipReason> {
        let Some(ty) = output else {
            return Err(SkipReason::UnsupportedType("() reader".into()));
        };
        match ty {
            Type::Primitive(p) if p == "bool" => Ok(BridgeReturn::Bool),
            Type::Primitive(p) => match p.as_str() {
                "u8" | "u16" | "u32" | "u64" | "usize" => Ok(BridgeReturn::Uint(p.clone())),
                "i8" | "i16" | "i32" | "i64" | "isize" => Ok(BridgeReturn::Int(p.clone())),
                other => Err(SkipReason::UnsupportedType(other.to_string())),
            },
            Type::BorrowedRef { type_, .. } => match type_.as_ref() {
                Type::Primitive(p) if p == "str" => Ok(BridgeReturn::Str),
                _ => Err(SkipReason::LifetimeBorrow),
            },
            // HashMap/Vec readers marshal as dict/list; other paths (Option<Borrowed>,
            // …) stay an Err so the caller can try the nested-wrapper rescue.
            Type::ResolvedPath(rp) if rp_name(&rp.path) == "HashMap" => classify_map_return(rp),
            Type::ResolvedPath(rp) if rp_name(&rp.path) == "Vec" => classify_vec_return(rp),
            Type::ResolvedPath(rp) => Err(SkipReason::UnsupportedType(rp.path.clone())),
            _ => Err(SkipReason::UnsupportedType(format!("{ty:?}"))),
        }
    }
}

// ── helpers ───────────────────────────────────────────────────────────────────

/// Whether a resolved-path return is this bridged type's own `Self`.
///
/// For an ordinary type it is a bare name match. For a monomorphized type the
/// path still reads as the original generic name (`DateTime`), so we also verify
/// the return's type arg names the SAME instantiation — otherwise a method like
/// `DateTime<Tz>::fixed_offset -> DateTime<FixedOffset>` would be miswrapped as
/// `DateTimeUtc`, producing a type-mismatched `Self(self.0.fixed_offset())`. The
/// arg is the same instantiation when it is the bare generic param (`Tz`, the
/// method preserves the caller's instantiation) or resolves to the pinned
/// concrete type (`Utc`, compared by leaf segment).
fn returns_self(bt: &BridgeType, rp: &rustdoc_types::Path, self_aliases: &[&str]) -> bool {
    let Some(m) = &bt.mono else {
        // 1.1.2: a `-> Self` return reads either as the type's own path or, inside a
        // blanket `impl<D> Trait for D` flattened onto this type, as the blanket's
        // generic param (`D`) — both are self-aliases.
        return rp.path == bt.name || self_aliases.contains(&rp.path.as_str());
    };
    if rp.path != m.origin_name {
        return false;
    }
    let Some(args) = &rp.args else { return false };
    let rustdoc_types::GenericArgs::AngleBracketed { args, .. } = args.as_ref() else {
        return false;
    };
    let first = args.iter().find_map(|a| match a {
        rustdoc_types::GenericArg::Type(t) => Some(t),
        _ => None,
    });
    match first {
        Some(Type::Generic(g)) => *g == m.generic_param,
        Some(Type::ResolvedPath(inner)) => {
            let ret_leaf = inner.path.rsplit("::").next().unwrap_or(&inner.path);
            let concrete_leaf = m.concrete.rsplit("::").next().unwrap_or(&m.concrete);
            let concrete_leaf = concrete_leaf.split('<').next().unwrap_or(concrete_leaf);
            ret_leaf == concrete_leaf
        }
        _ => false,
    }
}

/// All trait bounds on a fn's generic type param `name`, unioned from the inline
/// declaration (`fn f<S: AsRef<str>>`) and the where clause (`where S: AsRef<str>`).
fn generic_param_bounds<'f>(
    f: &'f rustdoc_types::Function,
    name: &str,
) -> Vec<&'f rustdoc_types::GenericBound> {
    use rustdoc_types::{GenericParamDefKind, WherePredicate};
    let mut out = vec![];
    for p in &f.generics.params {
        if p.name == name {
            if let GenericParamDefKind::Type { bounds, .. } = &p.kind {
                out.extend(bounds.iter());
            }
        }
    }
    for wp in &f.generics.where_predicates {
        if let WherePredicate::BoundPredicate {
            type_: Type::Generic(g),
            bounds,
            ..
        } = wp
        {
            if g == name {
                out.extend(bounds.iter());
            }
        }
    }
    out
}

/// True when the bound list contains `AsRef<str>`.
fn bounds_have_asref_str(bounds: &[&rustdoc_types::GenericBound]) -> bool {
    bounds.iter().any(|b| {
        matches!(b, rustdoc_types::GenericBound::TraitBound { trait_, .. }
            if rp_name(&trait_.path) == "AsRef"
                && angle_type_args(trait_)
                    .iter()
                    .any(|t| matches!(t, Type::Primitive(p) if p == "str")))
    })
}

/// The name of a fn generic type param that is an ITERATOR OF STRINGS - bounded
/// `I: IntoIterator<Item = S>` with `S: AsRef<str>` (or `Item = &str` / `Item =
/// String` directly). The `RegexSet::new` / `RegexSetBuilder::new` shape; the
/// binder monomorphizes it to `Vec<String>` on the wide lane. `None` when no
/// param matches.
fn strings_iter_generic(f: &rustdoc_types::Function) -> Option<String> {
    use rustdoc_types::{AssocItemConstraintKind, GenericBound, GenericParamDefKind, Term};
    let item_is_stringish = |item: &Type| -> bool {
        match item {
            // Item = S where S: AsRef<str>.
            Type::Generic(s) => bounds_have_asref_str(&generic_param_bounds(f, s)),
            // Item = &str.
            Type::BorrowedRef { type_, .. } => {
                matches!(type_.as_ref(), Type::Primitive(p) if p == "str")
            }
            // Item = String.
            Type::ResolvedPath(rp) => rp_name(&rp.path) == "String",
            _ => false,
        }
    };
    for p in &f.generics.params {
        if !matches!(p.kind, GenericParamDefKind::Type { .. }) {
            continue;
        }
        for b in generic_param_bounds(f, &p.name) {
            let GenericBound::TraitBound { trait_, .. } = b else {
                continue;
            };
            if rp_name(&trait_.path) != "IntoIterator" {
                continue;
            }
            let Some(args) = &trait_.args else { continue };
            let rustdoc_types::GenericArgs::AngleBracketed { constraints, .. } = args.as_ref()
            else {
                continue;
            };
            let item_ok = constraints.iter().any(|c| {
                c.name == "Item"
                    && matches!(
                        &c.binding,
                        AssocItemConstraintKind::Equality(Term::Type(t)) if item_is_stringish(t)
                    )
            });
            if item_ok {
                return Some(p.name.clone());
            }
        }
    }
    None
}

/// Classify a return type into a drain collection shape, or `None` if it is not
/// a recognised string collection (`Vec<String>`, `&[String]`, `Vec<&str>`,
/// `&[&str]`). A `Vec<u8>` / `&[u8]` / other-element collection is deliberately
/// not a drain — its elements don't cross the string boundary — so it stays a skip.
fn drain_collect_of(ty: &Type) -> Option<DrainCollect> {
    // Element classifier: owned `String` vs borrowed `&str`; anything else fails.
    fn elem_is_owned_string(t: &Type) -> Option<bool> {
        match t {
            Type::ResolvedPath(rp) if rp.path == "String" => Some(true),
            Type::BorrowedRef { type_, .. } => match type_.as_ref() {
                Type::Primitive(p) if p == "str" => Some(false),
                _ => None,
            },
            _ => None,
        }
    }
    match ty {
        // `Vec<String>` | `Vec<&str>`
        Type::ResolvedPath(rp) if rp.path == "Vec" => {
            let el = vec_first_type_arg(rp)?;
            Some(if elem_is_owned_string(el)? {
                DrainCollect::VecString
            } else {
                DrainCollect::VecStr
            })
        }
        // `&[String]` | `&[&str]`
        Type::BorrowedRef { type_, .. } => match type_.as_ref() {
            Type::Slice(inner) => Some(if elem_is_owned_string(inner)? {
                DrainCollect::SliceString
            } else {
                DrainCollect::VecStr
            }),
            _ => None,
        },
        _ => None,
    }
}

/// The first type argument of a `Vec<..>`-shaped resolved path.
fn vec_first_type_arg(rp: &rustdoc_types::Path) -> Option<&Type> {
    let args = rp.args.as_ref()?;
    let rustdoc_types::GenericArgs::AngleBracketed { args, .. } = args.as_ref() else {
        return None;
    };
    args.iter().find_map(|a| match a {
        rustdoc_types::GenericArg::Type(t) => Some(t),
        _ => None,
    })
}

/// `[u8]` — a slice of bytes (the payload of a `&[u8]` param or an `AsRef<[u8]>`
/// bound). 1.2.2 bytes lane.
fn is_u8_slice(ty: &Type) -> bool {
    matches!(ty, Type::Slice(inner) if matches!(inner.as_ref(), Type::Primitive(p) if p == "u8"))
}

/// The first angle-bracketed type arg of `rp` is the primitive `u8` — used to tell
/// a `Vec<u8>` / `Array<u8, _>` byte string from a `Vec<i64>` list. 1.2.2.
fn first_type_arg_is_u8(rp: &rustdoc_types::Path) -> bool {
    matches!(vec_first_type_arg(rp), Some(Type::Primitive(p)) if p == "u8")
}

/// `impl AsRef<[u8]>` — the single-bound byte-sink spelling of sha2's
/// `update`/`digest` data param. Exactly one trait bound, `AsRef`, over `[u8]`.
/// 1.2.2.
fn impl_is_asref_u8(bounds: &[rustdoc_types::GenericBound]) -> bool {
    let [rustdoc_types::GenericBound::TraitBound { trait_, .. }] = bounds else {
        return false;
    };
    rp_name(&trait_.path) == "AsRef" && angle_type_args(trait_).iter().any(|t| is_u8_slice(t))
}

/// A by-value `self` receiver (`Digest::finalize(self)`): the bare `Self` generic,
/// or a blanket-impl self-alias (`D`) standing in for it. 1.2.2 consuming lane.
fn is_value_self(ty: &Type, self_aliases: &[&str]) -> bool {
    matches!(ty, Type::Generic(g) if g == "Self" || self_aliases.contains(&g.as_str()))
}

/// The last `::`-separated segment of a rustdoc path string (`std::collections::
/// HashMap` → `HashMap`). rustdoc usually gives short names for std types, but
/// this is robust to a fully-qualified path.
fn rp_name(path: &str) -> &str {
    path.rsplit("::").next().unwrap_or(path)
}

/// Render a `HashMap`/`Vec` value type into the Rust string the wrapper
/// re-declares, iff the macro can carry it: bool, any integer width, or `String`.
/// Returns `None` for anything else (opaque values, nested containers, …).
fn scalar_value_rust(ty: &Type) -> Option<String> {
    match ty {
        Type::Primitive(p) => match p.as_str() {
            "bool" | "u8" | "u16" | "u32" | "u64" | "usize" | "i8" | "i16" | "i32" | "i64"
            | "isize" => Some(p.clone()),
            _ => None,
        },
        Type::ResolvedPath(rp) if rp_name(&rp.path) == "String" => Some("String".into()),
        _ => None,
    }
}

/// `HashMap<String, V>` → `BridgeReturn::Map("HashMap<String, V>")` for a carryable
/// V; a precise skip otherwise (so coverage still counts the item).
fn classify_map_return(rp: &rustdoc_types::Path) -> Result<BridgeReturn, SkipReason> {
    let args = angle_type_args(rp);
    if args.len() != 2 {
        return Err(SkipReason::UnsupportedType("HashMap arity".into()));
    }
    let key_ok = matches!(args[0], Type::ResolvedPath(k) if rp_name(&k.path) == "String");
    if !key_ok {
        return Err(SkipReason::UnsupportedType(
            "HashMap key (only HashMap<String, V>)".into(),
        ));
    }
    match scalar_value_rust(args[1]) {
        Some(v) => Ok(BridgeReturn::Map(format!("HashMap<String, {v}>"))),
        None => Err(SkipReason::UnsupportedType("HashMap value".into())),
    }
}

/// `Vec<V>` → `BridgeReturn::List("Vec<V>")` for a carryable V; a precise skip
/// otherwise.
fn classify_vec_return(rp: &rustdoc_types::Path) -> Result<BridgeReturn, SkipReason> {
    let Some(elem) = vec_first_type_arg(rp) else {
        return Err(SkipReason::UnsupportedType("Vec arity".into()));
    };
    match scalar_value_rust(elem) {
        Some(v) => Ok(BridgeReturn::List(format!("Vec<{v}>"))),
        None => Err(SkipReason::UnsupportedType("Vec element".into())),
    }
}

/// The angle-bracketed type args of a path (`HashMap<String, i64>` →
/// `[String, i64]`), dropping any non-type args (lifetimes, consts).
fn angle_type_args(rp: &rustdoc_types::Path) -> Vec<&Type> {
    let Some(args) = &rp.args else { return vec![] };
    let rustdoc_types::GenericArgs::AngleBracketed { args, .. } = args.as_ref() else {
        return vec![];
    };
    args.iter()
        .filter_map(|a| match a {
            rustdoc_types::GenericArg::Type(t) => Some(t),
            _ => None,
        })
        .collect()
}

/// `snake_case` → `CamelCase` for naming a drain wrapper after its producer
/// method (`capture_names` → `CaptureNames`, `patterns` → `Patterns`).
fn to_camel(s: &str) -> String {
    s.split('_')
        .filter(|p| !p.is_empty())
        .map(|p| {
            let mut c = p.chars();
            match c.next() {
                Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
                None => String::new(),
            }
        })
        .collect()
}

fn has_lifetime_args(rp: &rustdoc_types::Path) -> bool {
    let Some(args) = &rp.args else { return false };
    let rustdoc_types::GenericArgs::AngleBracketed { args, .. } = args.as_ref() else {
        return false;
    };
    args.iter()
        .any(|a| matches!(a, rustdoc_types::GenericArg::Lifetime(_)))
}

/// Returns true if any type arg of `rp` is itself a resolved path with lifetime
/// args — catches cases like `Option<Match<'h>>` where the lifetime is nested.
fn inner_has_lifetime(rp: &rustdoc_types::Path, doc: &Crate) -> bool {
    let Some(args) = &rp.args else { return false };
    let rustdoc_types::GenericArgs::AngleBracketed { args, .. } = args.as_ref() else {
        return false;
    };
    args.iter().any(|a| {
        if let rustdoc_types::GenericArg::Type(Type::ResolvedPath(inner_rp)) = a {
            has_lifetime_args(inner_rp)
                || doc
                    .index
                    .get(&inner_rp.id)
                    .map(|item| match &item.inner {
                        ItemEnum::Struct(s) => s.generics.params.iter().any(|p| {
                            matches!(p.kind, rustdoc_types::GenericParamDefKind::Lifetime { .. })
                        }),
                        _ => false,
                    })
                    .unwrap_or(false)
        } else {
            false
        }
    })
}

#[cfg(test)]
mod serde_lane_tests {
    //! 2.3 serde detection + wide-lane structural whitelist, exercised against the
    //! serde-featured chrono fixture (`tests/fixtures/serde/`, kept out of the
    //! corpus glob subdir so it doesn't demand a coverage baseline).
    use super::*;

    fn load_doc() -> Crate {
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/tests/fixtures/serde/chrono-0.4.45-serde.json"
        );
        let data = std::fs::read_to_string(path).expect("read serde fixture");
        serde_json::from_str(&data).expect("parse serde fixture")
    }

    fn ctx(doc: &Crate) -> Ctx<'_> {
        let module_name = doc.index[&doc.root].name.clone().unwrap_or_default();
        Ctx {
            doc,
            overlay: None,
            module_name: module_name.clone(),
            skips: vec![],
            dropped: vec![],
            pending_wrappers: vec![],
            inherited_excluded: 0,
            ref_type_names: HashSet::new(),
            root_reexports: collect_root_reexports(doc),
            root_glob_modules: collect_root_glob_modules(doc, &module_name),
            wide_record_ids: std::cell::RefCell::new(vec![]),
            qual_stack: std::cell::RefCell::new(vec![]),
        }
    }

    /// The first struct/enum in the index named `name` — the type an
    /// `is_wide_serializable` leaf lookup would resolve.
    fn find_id(doc: &Crate, name: &str) -> u32 {
        doc.index
            .iter()
            .find(|(_, it)| {
                it.name.as_deref() == Some(name)
                    && matches!(it.inner, ItemEnum::Struct(_) | ItemEnum::Enum(_))
            })
            .map(|(id, _)| id.0)
            .unwrap_or_else(|| panic!("no struct/enum named {name}"))
    }

    fn prim(p: &str) -> Type {
        Type::Primitive(p.into())
    }

    /// A `ResolvedPath` type `name<args...>` with a synthetic (unindexed) id — for
    /// the container-whitelist branches, which dispatch on the path name, never the
    /// id.
    fn path(name: &str, args: Vec<Type>) -> Type {
        let a = if args.is_empty() {
            None
        } else {
            Some(Box::new(rustdoc_types::GenericArgs::AngleBracketed {
                args: args
                    .into_iter()
                    .map(rustdoc_types::GenericArg::Type)
                    .collect(),
                constraints: vec![],
            }))
        };
        Type::ResolvedPath(rustdoc_types::Path {
            path: name.into(),
            id: Id(u32::MAX),
            args: a,
        })
    }

    #[test]
    fn serde_disposition_reads_serde_core_dual_root() {
        // chrono's serde impls are MANUAL and canonically rooted at `serde_core`
        // (the 1.0.220 core split) — a `serde::`-only matcher would find nothing.
        let doc = load_doc();
        let cx = ctx(&doc);
        let nd = cx.serde_disposition(find_id(&doc, "NaiveDate"));
        assert!(nd.serialize, "NaiveDate: Serialize via serde_core root");
        assert!(nd.deserialize, "NaiveDate: Deserialize via serde_core root");
        assert!(
            !nd.automatically_derived,
            "chrono's serde impls are hand-written, not derived"
        );

        // A struct with no serde impl reads clean.
        let days = cx.serde_disposition(find_id(&doc, "Days"));
        assert_eq!(days, SerdeInfo::default(), "Days has no serde impl");

        // A non-struct/enum id is all-false, never a panic.
        assert_eq!(cx.serde_disposition(u32::MAX), SerdeInfo::default());
    }

    #[test]
    fn wide_whitelist_admits_msgpack_scalars_and_containers() {
        let doc = load_doc();
        let cx = ctx(&doc);
        let ser = SerdeTrait::Serialize;

        // Primitives that have a msgpack lead byte.
        for p in ["bool", "char", "str", "u8", "u64", "i32", "f64", "usize"] {
            assert!(cx.is_wide_serializable(&prim(p), ser), "{p} is wide");
        }
        // 128-bit ints have no msgpack representation.
        assert!(!cx.is_wide_serializable(&prim("u128"), ser));
        assert!(!cx.is_wide_serializable(&prim("i128"), ser));

        // Std containers, recursing into element types.
        assert!(cx.is_wide_serializable(&path("String", vec![]), ser));
        assert!(cx.is_wide_serializable(&path("Vec", vec![prim("u64")]), ser));
        assert!(cx.is_wide_serializable(&path("Option", vec![prim("f64")]), ser));
        assert!(cx.is_wide_serializable(&path("Duration", vec![]), ser));

        // A map is wide only with a String key; the value must be wide too.
        let string_key = || path("String", vec![]);
        assert!(cx.is_wide_serializable(&path("HashMap", vec![string_key(), prim("u64")]), ser));
        assert!(!cx.is_wide_serializable(&path("HashMap", vec![prim("u64"), prim("u64")]), ser));

        // Tuples: wide iff every element is.
        assert!(cx.is_wide_serializable(&Type::Tuple(vec![prim("u64"), prim("bool")]), ser));
        assert!(!cx.is_wide_serializable(&Type::Tuple(vec![prim("u64"), prim("u128")]), ser));

        // A bare container with no args is not admitted (an alias, not a payload).
        assert!(!cx.is_wide_serializable(&path("Vec", vec![]), ser));
    }

    #[test]
    fn wide_whitelist_leaf_does_local_impl_lookup() {
        // A leaf naming a LOCAL serde type is admitted via the impl lookup; an
        // unknown external leaf (no index entry) is not.
        let doc = load_doc();
        let cx = ctx(&doc);
        let nd_id = find_id(&doc, "NaiveDate");
        let naive_date = Type::ResolvedPath(rustdoc_types::Path {
            path: "NaiveDate".into(),
            id: Id(nd_id),
            args: None,
        });
        assert!(cx.is_wide_serializable(&naive_date, SerdeTrait::Serialize));
        assert!(cx.is_wide_serializable(&naive_date, SerdeTrait::Deserialize));

        // `Days` is local but has no serde impl → not wide.
        let days_id = find_id(&doc, "Days");
        let days = Type::ResolvedPath(rustdoc_types::Path {
            path: "Days".into(),
            id: Id(days_id),
            args: None,
        });
        assert!(!cx.is_wide_serializable(&days, SerdeTrait::Serialize));
    }

    // ── 2.8 lane resolution ───────────────────────────────────────────────────

    /// A `ResolvedPath` leaf carrying the REAL index id of a fixture struct/enum,
    /// so a leaf serde lookup and crate-path rendering both resolve.
    fn leaf(doc: &Crate, name: &str) -> Type {
        Type::ResolvedPath(rustdoc_types::Path {
            path: name.into(),
            id: Id(find_id(doc, name)),
            args: None,
        })
    }

    /// A throwaway owner type for `classify_return` — its own name never collides
    /// with the value types under test, so `-> Self` / cross-ref arms don't fire.
    fn owner_bt() -> BridgeType {
        BridgeType {
            name: "Owner".into(),
            kind: TypeKind::Opaque,
            inner_path: "chrono::Owner".into(),
            module_path: vec![],
            item_id: 0,
            ctor: None,
            methods: vec![],
            injected_source: vec![],
            wrapper: None,
            mono: None,
            serde: SerdeInfo::default(),
            force_wide: None,
        }
    }

    #[test]
    fn wide_param_lane_beside_scalar_stays_tag() {
        // The 2.8 acceptance: lane selection is PER-VALUE. A wide serde param and a
        // scalar param, classified independently, each keep their own lane.
        let doc = load_doc();
        let cx = ctx(&doc);
        // A local serde struct by value fits no scalar lane → the wide lane.
        match cx.classify_param_type(&leaf(&doc, "NaiveDate"), &[]) {
            Ok(ScalarType::Wide(inner)) => {
                assert!(inner.ends_with("NaiveDate"), "wide inner path = {inner}")
            }
            other => panic!("expected Wide, got {other:?}"),
        }
        // The scalar wedged beside it is untouched — still a plain int tag.
        assert_eq!(
            cx.classify_param_type(&prim("i64"), &[]).unwrap(),
            ScalarType::Int("i64".into())
        );
        // A container carrying a serde leaf is wide, spelled with a fully-qualified
        // std path (no extra `use` needed) around the leaf's crate path.
        match cx.classify_param_type(
            &path(
                "HashMap",
                vec![path("String", vec![]), leaf(&doc, "NaiveDate")],
            ),
            &[],
        ) {
            Ok(ScalarType::Wide(inner)) => {
                assert!(inner.starts_with("std::collections::HashMap<String, "));
                assert!(inner.contains("NaiveDate"), "inner = {inner}");
            }
            other => panic!("expected Wide, got {other:?}"),
        }
    }

    #[test]
    fn wide_return_lane_and_render() {
        let doc = load_doc();
        let cx = ctx(&doc);
        let bt = owner_bt();
        // A local serde struct returned by value → wide, inner = its crate path.
        match cx.classify_return(&Some(leaf(&doc, "NaiveDate")), &bt, &[]) {
            Ok(BridgeReturn::Wide(inner)) => {
                assert!(inner.ends_with("NaiveDate"), "wide inner path = {inner}")
            }
            other => panic!("expected Wide, got {other:?}"),
        }
        // `Option<serde-leaf>` recurses and crosses wide (the handle-return arms
        // rule it out first — Option<NaiveDate> is neither Self nor a ref type).
        match cx.classify_return(
            &Some(path("Option", vec![leaf(&doc, "NaiveDate")])),
            &bt,
            &[],
        ) {
            Ok(BridgeReturn::Wide(inner)) => {
                assert!(inner.starts_with("Option<") && inner.contains("NaiveDate"));
            }
            other => panic!("expected Wide, got {other:?}"),
        }
        // A non-serde local type stays an honest skip, never wide.
        assert!(matches!(
            cx.classify_return(&Some(leaf(&doc, "Days")), &bt, &[]),
            Err(SkipReason::UnsupportedType(_))
        ));
    }

    #[test]
    fn ordering_return_rides_the_i8_lane() {
        // A `std::cmp::Ordering` return (`Version::cmp_precedence`) classifies as the
        // dedicated `Ordering` lane, which codegen lowers to `-> i8` — no primitive
        // spelling, no wide fallback, no skip.
        let doc = load_doc();
        let cx = ctx(&doc);
        let bt = owner_bt();
        assert_eq!(
            cx.classify_return(&Some(path("Ordering", vec![])), &bt, &[]),
            Ok(BridgeReturn::Ordering)
        );
    }

    #[test]
    fn manual_serde_impl_is_not_a_typed_record() {
        // 2.9's load-bearing safety rule: a MANUAL serde impl (chrono's `NaiveDate`
        // serializes as an ISO-8601 *string*, not a `{year, month, day}` record) must
        // NEVER become a typed obj from its rustdoc fields — the fields are private
        // and the wire shape is set by hand. It still crosses wide (dynamic), but
        // classification records NO typed record for it.
        let doc = load_doc();
        let cx = ctx(&doc);
        assert!(
            !cx.serde_disposition(find_id(&doc, "NaiveDate"))
                .automatically_derived
        );
        match cx.classify_param_type(&leaf(&doc, "NaiveDate"), &[]) {
            Ok(ScalarType::Wide(_)) => {}
            other => panic!("expected Wide, got {other:?}"),
        }
        assert!(
            cx.build_wide_records().is_empty(),
            "a manual-serde type must not synthesize a typed record"
        );
    }

    #[test]
    fn pure_std_shape_has_no_serde_intent_stays_skip() {
        // The serde-intent gate: a shape whose leaves are ALL std/primitive carries
        // no serde intent, so it is NOT auto-crossed wide (keeping today's skips —
        // and the coverage baselines — stable). Only a real serde leaf opts in.
        let doc = load_doc();
        let cx = ctx(&doc);
        // `Vec<f64>` / a scalar tuple are structurally serializable but intent-free.
        assert!(matches!(
            cx.classify_param_type(&path("Vec", vec![prim("f64")]), &[]),
            Err(SkipReason::UnsupportedType(_))
        ));
        let bt = owner_bt();
        assert!(matches!(
            cx.classify_return(&Some(Type::Tuple(vec![prim("f64"), prim("f64")])), &bt, &[]),
            Err(SkipReason::UnsupportedType(_))
        ));
    }

    #[test]
    fn handle_wins_over_wide() {
        // The canonical rule: a value whose type is opaque-bridged crosses as a
        // HANDLE even when it is serde-serializable — the handle arm fires before
        // the wide fallback. Model that by putting `NaiveDate` in `ref_type_names`.
        let doc = load_doc();
        let mut cx = ctx(&doc);
        cx.ref_type_names.insert("NaiveDate".into());
        let bt = owner_bt();
        assert_eq!(
            cx.classify_return(&Some(leaf(&doc, "NaiveDate")), &bt, &[]),
            Ok(BridgeReturn::Ref("NaiveDate".into())),
            "an opaque-bridged serde type crosses as a handle, not wide"
        );
    }

    #[test]
    fn overlay_wide_true_forces_over_handle() {
        // `[type."T"] wide = true` overrides the handle-wins default: even a type
        // that WOULD be an opaque handle crosses wide.
        let doc = load_doc();
        let ov = crate::overlay::parse_overlay("[type.\"NaiveDate\"]\nwide = true\n").unwrap();
        let mut cx = ctx(&doc);
        cx.overlay = Some(&ov);
        cx.ref_type_names.insert("NaiveDate".into());
        let bt = owner_bt();
        match cx.classify_return(&Some(leaf(&doc, "NaiveDate")), &bt, &[]) {
            Ok(BridgeReturn::Wide(inner)) => assert!(inner.ends_with("NaiveDate")),
            other => panic!("wide=true should force Wide, got {other:?}"),
        }
        // ... and as a param.
        assert!(matches!(
            cx.classify_param_type(&leaf(&doc, "NaiveDate"), &[]),
            Ok(ScalarType::Wide(_))
        ));
    }

    #[test]
    fn overlay_wide_false_forbids_lane() {
        // `[type."T"] wide = false` forbids the lane even for a serde type the
        // whitelist would admit — it falls through to an honest skip.
        let doc = load_doc();
        let ov = crate::overlay::parse_overlay("[type.\"NaiveDate\"]\nwide = false\n").unwrap();
        let mut cx = ctx(&doc);
        cx.overlay = Some(&ov);
        let bt = owner_bt();
        assert!(matches!(
            cx.classify_return(&Some(leaf(&doc, "NaiveDate")), &bt, &[]),
            Err(SkipReason::UnsupportedType(_))
        ));
        assert!(matches!(
            cx.classify_param_type(&leaf(&doc, "NaiveDate"), &[]),
            Err(SkipReason::UnsupportedType(_))
        ));
    }
}

#[cfg(test)]
mod reconcile_tests {
    //! Direct coverage for the dead-opaque reconciliation pass. The corpus used to
    //! exercise it via uuid's `Timestamp` (whose only bridgeable fn is now a
    //! `-> Self` ctor, so it is live), so this synthesizes the dead-target shape.
    use super::*;

    fn opaque(name: &str, methods: Vec<BridgeFn>) -> BridgeType {
        BridgeType {
            name: name.into(),
            kind: TypeKind::Opaque,
            inner_path: format!("crate::{name}"),
            module_path: vec![],
            item_id: 0,
            ctor: None,
            methods,
            injected_source: vec![],
            wrapper: None,
            mono: None,
            serde: SerdeInfo::default(),
            force_wide: None,
        }
    }

    fn method(name: &str, ret: BridgeReturn) -> BridgeFn {
        BridgeFn {
            name: name.into(),
            export_name: None,
            params: vec![],
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

    #[test]
    fn demotes_ref_return_to_dead_opaque_type() {
        // `Dead` is opaque with no ctor/methods/injected source → codegen never
        // emits it. `Live` stays live (a `Bool` method) but also returns `Dead` by
        // handle — a dangling wrapper reference the pass must demote to a skip.
        let dead = opaque("Dead", vec![]);
        let live = opaque(
            "Live",
            vec![
                method("is_ok", BridgeReturn::Bool),
                method("get_dead", BridgeReturn::Ref("Dead".into())),
            ],
        );
        let mut types = vec![live, dead];
        let mut skips = vec![];
        reconcile_ref_returns(&mut types, &mut skips);

        let live = types.iter().find(|t| t.name == "Live").unwrap();
        assert!(
            live.methods.iter().all(|m| m.name != "get_dead"),
            "the return-to-dead method must be stripped"
        );
        assert!(
            live.methods.iter().any(|m| m.name == "is_ok"),
            "the healthy method must survive"
        );
        assert!(
            skips
                .iter()
                .any(|s| s.item == "Live::get_dead" && format!("{:?}", s.reason).contains("Dead")),
            "the demotion must be recorded as an honest skip"
        );
    }
}
