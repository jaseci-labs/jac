//! Walk a rustdoc JSON document and classify its public API into bridgeable items.
//!
//! Entry point: [`classify`].  Returns a [`BridgeSpec`] describing everything
//! the v1 rule set can emit, plus a [`Skip`] list for items that need a later
//! rule (lifetime erasure, cursors, closures) or an overlay.

use std::collections::HashMap;

use rustdoc_types::{Crate, Id, Item, ItemEnum, StructKind, Type};

use crate::overlay::Overlay;
use crate::types::{
    BridgeFn, BridgeParam, BridgeReturn, BridgeSpec, BridgeType, DrainCollect, MonoType,
    OwningWrapper, Recv, RootProducer, ScalarType, Skip, SkipReason, TypeKind, WrapperKind,
};

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
        pending_wrappers: vec![],
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

    BridgeSpec { module_name, crate_version, types, skips: ctx.skips }
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
    pending_wrappers: Vec<PendingWrapper>,
}

impl<'a> Ctx<'a> {
    fn item(&self, id: &Id) -> Option<&'a Item> {
        self.doc.index.get(id)
    }

    // ── Phase 1: find bridgeable types ────────────────────────────────────────

    fn find_types(&self) -> Vec<BridgeType> {
        // Walk paths, keeping only own-crate items.  When the same type is
        // re-exported at multiple depths (bytes:: and string:: variants, etc.)
        // keep the shallowest path so we get one canonical entry per name.
        // Value carries the winning score, the item, and the module segments the
        // winning path declared it under (crate root and type name stripped) — the
        // provenance an overlay `[module."m"] skip` consults.
        type Candidate<'b> = ((usize, usize), &'b Item, Vec<String>);
        let mut by_name: HashMap<String, Candidate<'a>> = HashMap::new();

        for (id, path_entry) in &self.doc.paths {
            if path_entry.path.first().map(|s| s.as_str()) != Some(&self.module_name) {
                continue;
            }
            let Some(item) = self.doc.index.get(id) else { continue };
            let name = item.name.clone().unwrap_or_default();
            if name.is_empty() {
                continue;
            }
            // Score: (depth, bytes_penalty) — prefer shallow, prefer non-bytes.
            let depth = path_entry.path.len();
            let bytes_pen = if path_entry.path.iter().any(|s| s == "bytes") { 1usize } else { 0 };
            let score = (depth, bytes_pen);
            // Module segments: drop the leading crate name and the trailing type
            // name. `["regex","error","Error"]` -> `["error"]`.
            let module_path: Vec<String> = if path_entry.path.len() >= 2 {
                path_entry.path[1..path_entry.path.len() - 1].to_vec()
            } else {
                vec![]
            };
            let entry =
                by_name.entry(name).or_insert(((usize::MAX, 1), item, module_path.clone()));
            if score < entry.0 {
                *entry = (score, item, module_path);
            }
        }

        let mut out: Vec<BridgeType> = by_name
            .into_values()
            .flat_map(|((_depth, _pen), item, module_path)| {
                self.classify_type(item, module_path)
            })
            .collect();

        sort_types(&mut out);
        out
    }

    fn classify_type(&self, item: &'a Item, module_path: Vec<String>) -> Vec<BridgeType> {
        let Some(name) = item.name.clone() else { return vec![] };
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
                let has_lifetime = s.generics.params.iter().any(|p| {
                    matches!(p.kind, rustdoc_types::GenericParamDefKind::Lifetime { .. })
                });
                if has_lifetime {
                    return vec![];
                }
                // A const-generic struct can't be bridged (the const arg is unknown
                // and there's no directive to pin it) — drop it rather than emit an
                // uncompilable `T(pub crate::T)`.
                let has_const = s.generics.params.iter().any(|p| {
                    matches!(p.kind, rustdoc_types::GenericParamDefKind::Const { .. })
                });
                if has_const {
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
                    return self.monomorphize_struct(&name, &type_params, item_id, &module_path);
                }
                let kind = if name.ends_with("Error") {
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
            ItemEnum::Enum(_) if name.ends_with("Error") => vec![BridgeType {
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

    // ── Phase 2: classify impl methods ────────────────────────────────────────

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

        for impl_id in impl_ids {
            let Some(impl_item) = self.item(&impl_id) else { continue };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else { continue };

            // Skip trait impls (Display, Debug, Clone, …).
            if impl_block.trait_.is_some() {
                continue;
            }

            for method_id in &impl_block.items {
                let Some(method) = self.item(method_id) else { continue };
                let ItemEnum::Function(f) = &method.inner else { continue };
                if matches!(method.visibility, rustdoc_types::Visibility::Crate | rustdoc_types::Visibility::Restricted { .. }) {
                    continue;
                }
                let method_name = method.name.clone().unwrap_or_default();
                let item_path = format!("{}::{}", bt.name, method_name);

                // An overlay `treat_as` on this method overrides auto-detection:
                // it either forces the method off the bridge (`skip`) or pins it
                // to exactly one rule, bypassing the usual or-else ordering.
                if let Some(kind) = self.treat_as_for(&bt.name, &method_name) {
                    self.apply_treat_as(kind, method_id.0, &method_name, &item_path, f, bt);
                    continue;
                }

                match self.classify_fn(&item_path, f, bt) {
                    Ok(bridge_fn) => {
                        let is_ctor = matches!(bridge_fn.ret, BridgeReturn::OwnSelf | BridgeReturn::OwnSelfResult)
                            && !f.sig.inputs.iter().any(|(n, _)| n == "self");
                        // A ctor's body calls `inner::method(..)`, but a mono type's
                        // inner path carries a turbofish-less type arg
                        // (`chrono::Date<chrono::Utc>::new()` is invalid syntax), so
                        // ctors on monomorphized types are recorded as skips instead.
                        if is_ctor && bt.mono.is_some() {
                            self.skips.push(Skip {
                                item: item_path,
                                reason: SkipReason::UnsupportedType(
                                    "constructor on monomorphized type".into(),
                                ),
                            });
                        } else if is_ctor {
                            bt.ctor = Some(bridge_fn);
                        } else {
                            bt.methods.push(bridge_fn);
                        }
                    }
                    Err(reason) => {
                        // Before recording the skip, try the owning-wrapper rules:
                        // a `fn(&self, &str) -> Option<Borrowed<'_>>` whose borrowed
                        // type has a readable surface becomes a producer + wrapper;
                        // failing that, a `fn(&self, &str) -> Iter<'_>` (an in-crate
                        // iterator) becomes a cursor or a Vec-as-drain. Either rescues
                        // what would otherwise be a lifetime-borrow / cursor skip.
                        match self
                            .try_owning_wrapper(&method_name, f, bt)
                            .or_else(|| self.try_cursor_wrapper(&method_name, f, bt))
                            .or_else(|| self.try_vec_drain(method_id.0, &method_name, f, bt))
                            .or_else(|| self.try_callback_wrapper(&method_name, f, bt))
                        {
                            Some((producer, pendings)) => {
                                bt.methods.push(producer);
                                self.pending_wrappers.extend(pendings);
                            }
                            None => self.skips.push(Skip { item: item_path, reason }),
                        }
                    }
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
            params.push(BridgeParam { name: pname.clone(), ty: scalar });
        }

        let ret = self.classify_return(&f.sig.output, bt)?;

        Ok(BridgeFn {
            name: path.rsplit("::").next().unwrap_or(path).to_string(),
            export_name: None,
            params,
            ret,
            throws: None,
            recv: Recv::Field0,
        })
    }

    fn classify_param_type(&self, ty: &Type) -> Result<ScalarType, SkipReason> {
        match ty {
            Type::Primitive(p) => match p.as_str() {
                "bool" => Ok(ScalarType::Bool),
                // Integer scalars are understood but not yet carryable across the
                // v1 boundary (the macro has no integer tag). Skip with a precise
                // reason instead of silently dropping the method in codegen — the
                // coverage metric depends on every non-emitted item being a skip.
                p @ ("u8" | "u16" | "u32" | "u64" | "usize" | "i8" | "i16" | "i32"
                    | "i64" | "isize") => {
                    Err(SkipReason::UnsupportedType(format!("{p} param")))
                }
                other => Err(SkipReason::UnsupportedType(other.to_string())),
            },
            Type::BorrowedRef { type_, lifetime, .. } => match type_.as_ref() {
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
                other => Err(SkipReason::UnsupportedType(other.to_string())),
            },
            Type::ResolvedPath(rp) => {
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
            Type::BorrowedRef { lifetime: Some(_), .. } => Err(SkipReason::LifetimeBorrow),
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
            if let rustdoc_types::GenericArg::Type(t) = a { Some(t) } else { None }
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
                Ok(scalar) => params.push(BridgeParam { name: pname.clone(), ty: scalar }),
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
                Ok(scalar) => params.push(BridgeParam { name: pname.clone(), ty: scalar }),
                Err(_) => return None,
            }
        }
        if params.len() != 1 || params[0].ty != ScalarType::Str {
            return None;
        }

        // Return must be a bare in-crate iterator struct (not Option / Result).
        let Some(Type::ResolvedPath(rp)) = &f.sig.output else { return None };
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
                Ok(scalar) => params.push(BridgeParam { name: pname.clone(), ty: scalar }),
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
        };
        let producer = BridgeFn {
            name: method_name.to_string(),
            export_name: None,
            params: params.clone(),
            ret: BridgeReturn::Wrapper(wrapper_name.clone()),
            throws: None,
            recv: Recv::Field0,
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
                Type::BorrowedRef { type_, .. }
                    if matches!(type_.as_ref(), Type::Primitive(p) if p == "str") =>
                {
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
        let Some(Type::ResolvedPath(rp)) = &f.sig.output else { return None };
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
                BridgeParam { name: haystack, ty: ScalarType::Str },
                BridgeParam { name: callback, ty: ScalarType::Callback },
            ],
            ret: BridgeReturn::ReplacerResult(captures_path),
            throws: None,
            recv: Recv::Field0,
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
            if let WherePredicate::BoundPredicate { type_: Type::Generic(g), bounds, .. } = wp {
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
        let ItemEnum::Struct(s) = &item.inner else { return None };
        for impl_id in &s.impls {
            let Some(impl_item) = self.item(impl_id) else { continue };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else { continue };
            let Some(tr) = &impl_block.trait_ else { continue };
            if tr.path != "Iterator" {
                continue;
            }
            for assoc_id in &impl_block.items {
                let Some(assoc) = self.item(assoc_id) else { continue };
                if assoc.name.as_deref() != Some("Item") {
                    continue;
                }
                if let ItemEnum::AssocType { type_: Some(ty), .. } = &assoc.inner {
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
        let ItemEnum::Struct(s) = &item.inner else { return None };
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
        let Some(Type::ResolvedPath(rp)) = output else { return None };
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
        let ItemEnum::Struct(s) = &item.inner else { return None };
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
            let Some(impl_item) = self.item(&impl_id) else { continue };
            let ItemEnum::Impl(impl_block) = &impl_item.inner else { continue };
            if impl_block.trait_.is_some() {
                continue;
            }
            for method_id in &impl_block.items {
                let Some(method) = self.item(method_id) else { continue };
                let ItemEnum::Function(f) = &method.inner else { continue };
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
                        Ok(scalar) => params.push(BridgeParam { name: pname.clone(), ty: scalar }),
                        Err(r) => {
                            param_err = Some(r);
                            break;
                        }
                    }
                }
                if let Some(reason) = param_err {
                    skips.push(Skip { item: item_path, reason });
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
                            None => skips.push(Skip { item: item_path, reason }),
                        }
                    }
                }
            }
        }

        readers.sort_by(|a, b| a.name.cmp(&b.name));
        skips.sort_by(|a, b| a.item.cmp(&b.item));
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
            Type::Primitive(p) => Err(SkipReason::UnsupportedType(p.clone())),
            Type::BorrowedRef { type_, .. } => match type_.as_ref() {
                Type::Primitive(p) if p == "str" => Ok(BridgeReturn::Str),
                _ => Err(SkipReason::LifetimeBorrow),
            },
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
    let Some(m) = &bt.mono else { return rp.path == bt.name };
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
    args.iter().any(|a| matches!(a, rustdoc_types::GenericArg::Lifetime(_)))
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
                        ItemEnum::Struct(s) => {
                            s.generics.params.iter().any(|p| {
                                matches!(p.kind, rustdoc_types::GenericParamDefKind::Lifetime { .. })
                            })
                        }
                        _ => false,
                    })
                    .unwrap_or(false)
        } else {
            false
        }
    })
}
