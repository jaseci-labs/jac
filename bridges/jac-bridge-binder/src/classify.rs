//! Walk a rustdoc JSON document and classify its public API into bridgeable items.
//!
//! Entry point: [`classify`].  Returns a [`BridgeSpec`] describing everything
//! the v1 rule set can emit, plus a [`Skip`] list for items that need a later
//! rule (lifetime erasure, cursors, closures) or an overlay.

use std::collections::HashMap;

use rustdoc_types::{Crate, Id, Item, ItemEnum, StructKind, Type};

use crate::overlay::Overlay;
use crate::types::{
    BridgeFn, BridgeParam, BridgeReturn, BridgeSpec, BridgeType, DrainCollect, DropReason,
    DroppedType, MonoType, Ownership, OwningWrapper, Recv, RootProducer, ScalarType, Skip,
    SkipReason, TypeKind, WrapperKind,
};

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
    "Debug", "Display", "Binary", "Octal", "LowerHex", "UpperHex", "LowerExp", "UpperExp",
    "Pointer", "Write",
    // clone / copy / default / drop / ownership markers
    "Clone", "CloneToUninit", "Copy", "Default", "Drop", "ToOwned",
    // conversions (mechanical, not crate semantics)
    "From", "Into", "TryFrom", "TryInto", "AsRef", "AsMut", "Borrow", "BorrowMut", "ToString",
    // equality / ordering / hashing
    "PartialEq", "Eq", "StructuralPartialEq", "PartialOrd", "Ord", "Hash",
    // auto / marker traits
    "Send", "Sync", "Unpin", "Sized", "Any", "Freeze", "RefUnwindSafe", "UnwindSafe",
    "UnsafeUnpin", "Error",
    // serde
    "Serialize", "Deserialize",
    // deref / index (transparent access, not API)
    "Deref", "DerefMut", "Index", "IndexMut",
    // iteration (blanket-default heavy — ~80 provided defaults on Iterator alone)
    "Iterator", "IntoIterator", "DoubleEndedIterator", "ExactSizeIterator", "FusedIterator",
    // operators (std::ops)
    "Add", "Sub", "Mul", "Div", "Rem", "Neg", "Not",
    "BitAnd", "BitOr", "BitXor", "Shl", "Shr",
    "AddAssign", "SubAssign", "MulAssign", "DivAssign", "RemAssign",
    "BitAndAssign", "BitOrAssign", "BitXorAssign", "ShlAssign", "ShrAssign",
    "Fn", "FnMut", "FnOnce",
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
    };

    let mut types = ctx.find_types();
    for bt in &mut types {
        ctx.classify_impl(bt);
    }

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
        });
    }
    sort_types(&mut types);

    ctx.dropped.sort_by(|a, b| a.name.cmp(&b.name));
    BridgeSpec {
        module_name,
        crate_version,
        types,
        skips: ctx.skips,
        dropped: ctx.dropped,
        inherited_excluded: ctx.inherited_excluded,
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

    fn classify_type(&mut self, item: &'a Item, module_path: Vec<String>) -> Vec<BridgeType> {
        let Some(name) = item.name.clone() else {
            return vec![];
        };
        let inner_path = format!("{}::{}", self.module_name, name);
        let item_id = item.id.0;

        match &item.inner {
            ItemEnum::Struct(s) => {
                let has_hidden = matches!(&s.kind, StructKind::Plain { has_stripped_fields, .. } if *has_stripped_fields);
                if !has_hidden {
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
                    inner_path: format!("{}::{}<{}>", self.module_name, name, c),
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

    // ── Phase 2: classify impl methods ────────────────────────────────────────

    /// The trait's use-path for the generated `use`, spelled through the BRIDGED
    /// MODULE's own re-export — `sha2::Digest`, `chrono::Datelike` — NOT the trait's
    /// defining crate. A crate whose public types expose a trait's methods
    /// re-exports that trait at its root by convention (`sha2` does
    /// `pub use digest::{self, Digest}`; `chrono` re-exports `Datelike`), so this
    /// path always resolves AND — critically — binds to the EXACT trait version the
    /// bridged crate itself uses. Naming the defining crate directly (`digest`)
    /// would need a separate dependency whose version we can't pin from rustdoc; a
    /// `"*"` there can resolve to a DIFFERENT major than the one `sha2` impls,
    /// leaving `self.0.output_size()` unsatisfied. Going through the module avoids
    /// the extra dep and the skew entirely.
    fn trait_use_path(&self, tr: &rustdoc_types::Path) -> String {
        format!("{}::{}", self.module_name, self.trait_simple_name(tr))
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
        let mut seen_names: std::collections::HashSet<String> =
            std::collections::HashSet::new();

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
            for method_id in impl_block.items.clone() {
                self.classify_impl_method(
                    &method_id,
                    bt,
                    None,
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
            for method_id in impl_block.items.clone() {
                self.classify_impl_method(
                    &method_id,
                    bt,
                    Some(&via),
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
        ctor_candidates.sort_by(|a, b| {
            (a.1.via_trait.is_some(), &a.1.name).cmp(&(b.1.via_trait.is_some(), &b.1.name))
        });
        let mut candidates = ctor_candidates.into_iter();
        if let Some((_, winner)) = candidates.next() {
            bt.ctor = Some(winner);
            for (item_path, extra) in candidates {
                self.skips.push(Skip {
                    item: item_path,
                    reason: SkipReason::UnsupportedType(format!(
                        "additional constructor ({})",
                        extra.name
                    )),
                });
            }
        }
    }

    /// Classify one impl method (inherent or trait-flattened) onto `bt`.
    /// `via_trait` is the flattened trait's full path — `Some` only for a SEMANTIC
    /// trait impl (Track A) — stamped on the emitted `BridgeFn` so codegen brings
    /// the trait into scope for the `self.0.<method>()` call. `seen_names` enforces
    /// first-wins dedup (1.1.3) across the whole type; a name already claimed
    /// becomes a visible skip instead of a duplicate `pub fn`.
    fn classify_impl_method(
        &mut self,
        method_id: &Id,
        bt: &mut BridgeType,
        via_trait: Option<&str>,
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
            self.apply_treat_as(kind, method_id.0, &method_name, &item_path, f, bt);
            return;
        }

        match self.classify_fn(&item_path, f, bt) {
            Ok(mut bridge_fn) => {
                bridge_fn.via_trait = via_trait.map(str::to_string);
                // The emitted wrapper method delegates through the newtype behind a
                // shared `&self` (`self.0.<m>()`), so two receiver shapes can't be
                // lowered as-is and are recorded as VISIBLE skips rather than
                // mis-compiled emits (both surfaced by flattening `Digest` onto the
                // sha2 hashers). Ctors have no `self` param, so they never trip this.
                //   * BY-VALUE `self` (`Digest::finalize(self)`): `self.0.finalize()`
                //     moves out of a borrow. Sound lowering is a Clone-gated
                //     `self.0.clone().finalize()`, deferred to the sha2 byte lane
                //     (1.2.2) that makes such returns bridgeable at all.
                //   * `&mut self` (`Digest::reset(&mut self)`): can't borrow `self.0`
                //     mutably through `&self`. Emitting `&mut self` on a shared handle
                //     is a separate lane (the cursor pull methods already do it for
                //     synthesized wrappers); deferred for direct methods.
                let self_recv = f.sig.inputs.iter().find(|(n, _)| n == "self").map(|(_, t)| t);
                let bad_recv = match self_recv {
                    Some(Type::Generic(g)) if g == "Self" => Some("consumes self by value"),
                    Some(Type::BorrowedRef { is_mutable: true, .. }) => {
                        Some("requires &mut self (mutable handle method)")
                    }
                    _ => None,
                };
                if let Some(reason) = bad_recv {
                    self.skips.push(Skip {
                        item: item_path,
                        reason: SkipReason::UnsupportedType(reason.into()),
                    });
                    return;
                }
                let has_self = f.sig.inputs.iter().any(|(n, _)| n == "self");
                let is_ctor = matches!(
                    bridge_fn.ret,
                    BridgeReturn::OwnSelf | BridgeReturn::OwnSelfResult
                ) && !has_self;
                // An associated fn with NO receiver that isn't a constructor
                // (returns something other than `Self`, e.g. `Digest::output_size()
                // -> usize`) can't be emitted as an instance method `self.0.f()`, and
                // the bridge ABI has no static non-ctor method. Honest skip rather
                // than a mis-compiled `self.0.output_size()` (no such method exists on
                // the value). Flattening `Digest` first surfaced this class.
                if !is_ctor && !has_self {
                    self.skips.push(Skip {
                        item: item_path,
                        reason: SkipReason::UnsupportedType(
                            "associated fn (no receiver, not a constructor)".into(),
                        ),
                    });
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
                    .try_owning_wrapper(&method_name, f, bt)
                    .or_else(|| self.try_cursor_wrapper(&method_name, f, bt))
                    .or_else(|| self.try_vec_drain(method_id.0, &method_name, f, bt))
                    .or_else(|| self.try_callback_wrapper(&method_name, f, bt))
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
                    None => self.skips.push(Skip { item: item_path, reason }),
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
    fn apply_treat_as(
        &mut self,
        kind: &str,
        method_id: u32,
        method_name: &str,
        item_path: &str,
        f: &rustdoc_types::Function,
        bt: &mut BridgeType,
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
            "owning" => self.try_owning_wrapper(method_name, f, bt),
            "cursor" => self.try_cursor_wrapper(method_name, f, bt),
            "drain" => self.try_vec_drain(method_id, method_name, f, bt),
            "callback" => self.try_callback_wrapper(method_name, f, bt),
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

    fn classify_fn(
        &self,
        path: &str,
        f: &rustdoc_types::Function,
        bt: &BridgeType,
    ) -> Result<BridgeFn, SkipReason> {
        let mut params = vec![];

        for (pname, pty) in &f.sig.inputs {
            // Skip `self` / `&self` / `&mut self` receivers.
            if pname == "self" {
                continue;
            }
            let scalar = self.classify_param_type(pty)?;
            params.push(BridgeParam {
                name: pname.clone(),
                ty: scalar,
            });
        }

        let ret = self.classify_return(&f.sig.output, bt)?;

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
        })
    }

    fn classify_param_type(&self, ty: &Type) -> Result<ScalarType, SkipReason> {
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
                Type::Generic(g) if g == "Self" => {
                    Err(SkipReason::UnsupportedType("&Self receiver".into()))
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
            Type::ImplTrait(_) => Err(SkipReason::Closure),
            _ => Err(SkipReason::UnsupportedType(format!("{ty:?}"))),
        }
    }

    fn classify_return(
        &self,
        output: &Option<Type>,
        bt: &BridgeType,
    ) -> Result<BridgeReturn, SkipReason> {
        let Some(ty) = output else {
            return Ok(BridgeReturn::Void);
        };

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
                    return classify_vec_return(rp);
                }
                // A `-> Self` return reads as the type's own path. For a
                // monomorphized type that path is still the ORIGINAL generic name
                // (`Date`), not the mono name (`DateUtc`) — match on origin.
                if returns_self(bt, rp) {
                    return Ok(BridgeReturn::OwnSelf);
                }
                if rp.path == "Result" {
                    return self.classify_result_return(rp, bt);
                }
                if has_lifetime_args(rp) || inner_has_lifetime(rp, self.doc) {
                    return Err(SkipReason::LifetimeBorrow);
                }
                Err(SkipReason::UnsupportedType(rp.path.clone()))
            }
            Type::BorrowedRef {
                lifetime: Some(_), ..
            } => Err(SkipReason::LifetimeBorrow),
            Type::BorrowedRef { type_, .. } => match type_.as_ref() {
                Type::Primitive(p) if p == "str" => Ok(BridgeReturn::Str),
                _ => Err(SkipReason::LifetimeBorrow),
            },
            Type::Generic(_) => Err(SkipReason::Generic),
            Type::ImplTrait(_) => Err(SkipReason::Cursor),
            _ => Err(SkipReason::UnsupportedType(format!("{ty:?}"))),
        }
    }

    fn classify_result_return(
        &self,
        rp: &rustdoc_types::Path,
        bt: &BridgeType,
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
            Some(Type::ResolvedPath(ok_rp)) if returns_self(bt, ok_rp) => {
                Ok(BridgeReturn::OwnSelfResult)
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
            match self.classify_param_type(pty) {
                Ok(scalar) => params.push(BridgeParam {
                    name: pname.clone(),
                    ty: scalar,
                }),
                Err(_) => return None,
            }
        }
        if params.len() != 1 || params[0].ty != ScalarType::Str {
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
        let producer = BridgeFn {
            name: method_name.to_string(),
            export_name: None,
            params,
            ret: BridgeReturn::OptWrapper(wrapper_name.clone()),
            throws: None,
            recv: Recv::Field0,
            is_async: false,
            ret_ownership: Ownership::Owned,
            via_trait: None,
        };
        let pending = PendingWrapper {
            wrapper_name,
            borrowed_id,
            wrapper: OwningWrapper {
                borrowed_path: format!("{}::{}", self.module_name, borrowed_name),
                lifetimes,
                root: Some(RootProducer {
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
    ) -> Option<(BridgeFn, Vec<PendingWrapper>)> {
        if !f.sig.inputs.iter().any(|(n, _)| n == "self") {
            return None;
        }
        // Exactly one non-self `&str` param — the buffer the wrapper owns.
        let mut params = vec![];
        for (pname, pty) in &f.sig.inputs {
            if pname == "self" {
                continue;
            }
            match self.classify_param_type(pty) {
                Ok(scalar) => params.push(BridgeParam {
                    name: pname.clone(),
                    ty: scalar,
                }),
                Err(_) => return None,
            }
        }
        if params.len() != 1 || params[0].ty != ScalarType::Str {
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
                };
                let kind = WrapperKind::Drain {
                    params: params.clone(),
                    collect: DrainCollect::IterStr,
                };
                (next, vec![], kind)
            }
            // Item = in-crate lifetime struct with readers → cursor of nested wrappers.
            Type::ResolvedPath(item_rp) => {
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
            match self.classify_param_type(pty) {
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
                    match self.classify_param_type(pty) {
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
                    }),
                    // A reader whose return is `Option<Borrowed<'h>>` isn't a dead
                    // skip — it's a NESTED producer of another owning wrapper, so
                    // long as that borrowed type is itself readable. Recurse.
                    Err(reason) => {
                        match self.try_nested_wrapper(&mname, &params, &f.sig.output, seen) {
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
fn returns_self(bt: &BridgeType, rp: &rustdoc_types::Path) -> bool {
    let Some(m) = &bt.mono else {
        return rp.path == bt.name;
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
