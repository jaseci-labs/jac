//! Walk a rustdoc JSON document and classify its public API into bridgeable items.
//!
//! Entry point: [`classify`].  Returns a [`BridgeSpec`] describing everything
//! the v1 rule set can emit, plus a [`Skip`] list for items that need a later
//! rule (lifetime erasure, cursors, closures) or an overlay.

use std::collections::HashMap;

use rustdoc_types::{Crate, Id, Item, ItemEnum, StructKind, Type};

use crate::types::{
    BridgeFn, BridgeParam, BridgeReturn, BridgeSpec, BridgeType, OwningWrapper, Recv, RootProducer,
    ScalarType, Skip, SkipReason, TypeKind,
};

pub fn classify(doc: &Crate) -> BridgeSpec {
    let module_name = doc.index[&doc.root].name.clone().unwrap_or_default();
    let crate_version = doc.crate_version.clone().unwrap_or_else(|| "0.0.0".into());

    let mut ctx =
        Ctx { doc, module_name: module_name.clone(), skips: vec![], pending_wrappers: vec![] };

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
            item_id: pw.borrowed_id,
            ctor: None,
            methods: pw.readers,
            injected_source: vec![],
            wrapper: Some(pw.wrapper),
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
        let mut by_name: HashMap<String, ((usize, usize), &Item)> = HashMap::new();

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
            let entry = by_name.entry(name).or_insert(((usize::MAX, 1), item));
            if score < entry.0 {
                *entry = (score, item);
            }
        }

        let mut out: Vec<BridgeType> = by_name
            .into_values()
            .filter_map(|((_depth, _pen), item)| self.classify_type(item))
            .collect();

        sort_types(&mut out);
        out
    }

    fn classify_type(&self, item: &'a Item) -> Option<BridgeType> {
        let name = item.name.clone()?;
        let inner_path = format!("{}::{}", self.module_name, name);
        let item_id = item.id.0;

        match &item.inner {
            ItemEnum::Struct(s) => {
                let has_hidden = matches!(&s.kind, StructKind::Plain { has_stripped_fields, .. } if *has_stripped_fields);
                if !has_hidden {
                    return None;
                }
                // Types with lifetime params can't be stored in Box<T> — skip them.
                // This excludes cursor types like Match<'h>, Captures<'m,'h>, etc.
                let has_lifetime = s.generics.params.iter().any(|p| {
                    matches!(p.kind, rustdoc_types::GenericParamDefKind::Lifetime { .. })
                });
                if has_lifetime {
                    return None;
                }
                let kind = if name.ends_with("Error") {
                    TypeKind::Error
                } else {
                    TypeKind::Opaque
                };
                Some(BridgeType {
                    name,
                    kind,
                    inner_path,
                    item_id,
                    ctor: None,
                    methods: vec![],
                    injected_source: vec![],
                    wrapper: None,
                })
            }
            ItemEnum::Enum(_) if name.ends_with("Error") => Some(BridgeType {
                name,
                kind: TypeKind::Error,
                inner_path,
                item_id,
                ctor: None,
                methods: vec![],
                injected_source: vec![],
                wrapper: None,
            }),
            _ => None,
        }
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

                match self.classify_fn(&item_path, f, bt) {
                    Ok(bridge_fn) => {
                        let is_ctor = matches!(bridge_fn.ret, BridgeReturn::OwnSelf | BridgeReturn::OwnSelfResult)
                            && !f.sig.inputs.iter().any(|(n, _)| n == "self");
                        if is_ctor {
                            bt.ctor = Some(bridge_fn);
                        } else {
                            bt.methods.push(bridge_fn);
                        }
                    }
                    Err(reason) => {
                        // Before recording the skip, try the owning-wrapper rule:
                        // a `fn(&self, &str) -> Option<Borrowed<'_>>` whose borrowed
                        // type has a readable surface becomes a producer + wrapper
                        // instead of a lifetime-borrow skip.
                        match self.try_owning_wrapper(&method_name, f, bt) {
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
                if rp.path == bt.name {
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
            Some(Type::ResolvedPath(ok_rp)) if ok_rp.path == bt.name => Ok(BridgeReturn::OwnSelfResult),
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
            },
            readers,
            reader_skips,
        };
        let mut pendings = vec![pending];
        pendings.extend(deeper);
        Some((reader, pendings))
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
