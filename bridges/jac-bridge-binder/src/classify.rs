//! Walk a rustdoc JSON document and classify its public API into bridgeable items.
//!
//! Entry point: [`classify`].  Returns a [`BridgeSpec`] describing everything
//! the v1 rule set can emit, plus a [`Skip`] list for items that need a later
//! rule (lifetime erasure, cursors, closures) or an overlay.

use std::collections::HashMap;

use rustdoc_types::{Crate, Id, Item, ItemEnum, StructKind, Type};

use crate::types::{
    BridgeFn, BridgeParam, BridgeReturn, BridgeSpec, BridgeType, ScalarType, Skip, SkipReason,
    TypeKind,
};

pub fn classify(doc: &Crate) -> BridgeSpec {
    let module_name = doc.index[&doc.root].name.clone().unwrap_or_default();
    let crate_version = doc.crate_version.clone().unwrap_or_else(|| "0.0.0".into());

    let mut ctx = Ctx { doc, module_name: module_name.clone(), skips: vec![] };

    let mut types = ctx.find_types();
    for bt in &mut types {
        ctx.classify_impl(bt);
    }

    BridgeSpec { module_name, crate_version, types, skips: ctx.skips }
}

struct Ctx<'a> {
    doc: &'a Crate,
    module_name: String,
    skips: Vec<Skip>,
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

        out.sort_by(|a, b| {
            let k = |t: &BridgeType| match t.kind {
                TypeKind::Opaque => 0u8,
                TypeKind::Error => 1,
            };
            k(a).cmp(&k(b)).then(a.name.cmp(&b.name))
        });
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
                        self.skips.push(Skip { item: item_path, reason });
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
