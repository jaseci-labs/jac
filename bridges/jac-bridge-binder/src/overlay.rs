//! `<crate>.overlay.toml` — the sparse exception file the binder consumes
//! alongside its rules (D6). Every entry is a *decision*; the binder still does
//! all the work. The shape is bindgen/autocxx-style directives, never a UDL
//! that restates the whole interface.
//!
//! ```toml
//! [fn."Regex::shortest_match"]
//! rename = "find_end"          # nicer Jac-side name
//!
//! [fn."Regex::is_match_at"]
//! skip = true                  # hide a method
//!
//! [type."SetMatchesIntoIter"]
//! skip = true                  # hide a type
//! inject = """
//!     pub fn as_str(&self) -> String { self.0.as_str().to_string() }
//! """
//! ```
//!
//! The full directive set is honoured (M4 Phase B): `skip`/`rename`/`inject`
//! plus `treat_as` (reclassify a method or force it off — applied during
//! `classify_with_overlay`), `monomorphize` (pin a generic struct's concrete
//! instantiations — also classify-time), and `[module."m"] skip` (drop a whole
//! submodule by provenance). An unknown value or an empty `monomorphize` set is
//! rejected with a precise reason — an overlay entry is a decision the author
//! expects to take effect, never a silent no-op.

use std::collections::BTreeMap;

use serde::Deserialize;

use crate::types::BridgeSpec;

/// Parsed overlay. Maps are `BTreeMap` so iteration is deterministic (the D6
/// byte-identical-output guarantee must not depend on hash order).
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Overlay {
    /// Keyed by `"Type::method"`.
    #[serde(rename = "fn", default)]
    pub fns: BTreeMap<String, FnOverlay>,
    /// Keyed by type name.
    #[serde(rename = "type", default)]
    pub types: BTreeMap<String, TypeOverlay>,
    /// Keyed by submodule name.
    #[serde(rename = "module", default)]
    pub modules: BTreeMap<String, ModuleOverlay>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FnOverlay {
    #[serde(default)]
    pub skip: bool,
    /// Nicer Jac-side name; the Rust call target is unchanged.
    pub rename: Option<String>,
    /// Override auto-classification (applied at classify time). `"skip"` forces
    /// the method off the bridge; `"owning"` / `"cursor"` / `"drain"` /
    /// `"callback"` pin it to exactly that rule regardless of what detection would
    /// pick. A pinned rule whose preconditions the method fails records an honest
    /// skip. Exclusive with `skip`/`rename` on the same entry.
    pub treat_as: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TypeOverlay {
    #[serde(default)]
    pub skip: bool,
    pub rename: Option<String>,
    /// Raw Rust `impl`-body source appended verbatim after generated methods —
    /// the documented-last-resort escape hatch (8-space indentation expected).
    pub inject: Option<String>,
    /// Pin the concrete instantiations of a generic struct the rules can't infer
    /// (applied at classify time). Each entry is a concrete type substituted for
    /// the struct's single type param, yielding one opaque bridged type named
    /// `T<Suffix>` wrapping `crate::T<concrete>` — e.g. `["chrono::Utc"]` on
    /// `DateTime` emits `DateTimeUtc(pub chrono::DateTime<chrono::Utc>)`. An empty
    /// list is rejected.
    pub monomorphize: Option<Vec<String>>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ModuleOverlay {
    #[serde(default)]
    pub skip: bool,
}

/// Parse an overlay from a TOML string.
pub fn parse_overlay(src: &str) -> Result<Overlay, toml::de::Error> {
    toml::from_str(src)
}

/// Apply `overlay` to `spec` in-place. Returns an error naming any directive
/// the current rule set cannot honour, so overlays fail loud, never silently.
pub fn apply_overlay(spec: &mut BridgeSpec, overlay: &Overlay) -> Result<(), String> {
    // ── [module."m"] skip = true ─────────────────────────────────────────────
    // Drop every bridged type whose module provenance contains `m`, along with
    // the method skips recorded against those types. classify tracks provenance
    // on `BridgeType::module_path` (crate root + type name stripped), so a
    // `[module."bytes"]` skip removes the whole `bytes` submodule surface.
    for (name, m) in &overlay.modules {
        if !m.skip {
            continue;
        }
        let removed: Vec<String> = spec
            .types
            .iter()
            .filter(|bt| bt.module_path.iter().any(|seg| seg == name))
            .map(|bt| bt.name.clone())
            .collect();
        spec.types.retain(|bt| !bt.module_path.iter().any(|seg| seg == name));
        spec.skips
            .retain(|s| !removed.iter().any(|t| s.item.starts_with(&format!("{t}::"))));
    }

    // ── [type."T"] ───────────────────────────────────────────────────────────
    for (name, t) in &overlay.types {
        // `monomorphize` is honoured during classification (see
        // `classify_with_overlay`), which expands the generic struct into concrete
        // `T<Suffix>` types. Here we only validate it and move on — the original
        // generic name `T` is intentionally absent from the spec afterwards, so the
        // usual "no such bridged type" lookup below must not run for it.
        if let Some(set) = &t.monomorphize {
            if set.is_empty() {
                return Err(format!(
                    "overlay: [type.\"{name}\"] monomorphize = [] pins no \
                     instantiation — list at least one concrete type"
                ));
            }
            continue;
        }
        if t.skip {
            spec.types.retain(|bt| bt.name != *name);
            // A skipped type's method skips are noise; drop them too.
            spec.skips.retain(|s| !s.item.starts_with(&format!("{name}::")));
            continue;
        }
        let Some(bt) = spec.types.iter_mut().find(|bt| bt.name == *name) else {
            return Err(format!("overlay: [type.\"{name}\"] — no such bridged type"));
        };
        if let Some(new) = &t.rename {
            bt.name = new.clone();
        }
        if let Some(src) = &t.inject {
            bt.injected_source.push(src.clone());
        }
    }

    // ── [fn."T::m"] ──────────────────────────────────────────────────────────
    for (key, f) in &overlay.fns {
        let (type_name, method) = key
            .split_once("::")
            .ok_or_else(|| format!("overlay: [fn.\"{key}\"] — key must be \"Type::method\""))?;

        // `treat_as` is honoured during classification (see
        // `classify_with_overlay`), not here — this pass only validates the value
        // so a typo fails loud instead of silently pinning nothing.
        if let Some(kind) = &f.treat_as {
            const ALLOWED: &[&str] = &["skip", "owning", "cursor", "drain", "callback"];
            if !ALLOWED.contains(&kind.as_str()) {
                return Err(format!(
                    "overlay: [fn.\"{key}\"] treat_as = \"{kind}\" is not a known \
                     reclassification — expected one of {ALLOWED:?}"
                ));
            }
            // A treat_as directive is exclusive: it fully determines the method's
            // fate at classify time, so skip/rename on the same entry are ignored.
            continue;
        }

        let Some(bt) = spec.types.iter_mut().find(|bt| bt.name == type_name) else {
            // The type may itself have been skipped above — tolerate silently
            // only if it is genuinely absent; otherwise the author mistyped.
            return Err(format!(
                "overlay: [fn.\"{key}\"] — type `{type_name}` is not a bridged type"
            ));
        };

        if f.skip {
            bt.methods.retain(|m| m.name != method);
            if bt.ctor.as_ref().map(|c| c.name == method).unwrap_or(false) {
                bt.ctor = None;
            }
            continue;
        }
        if let Some(new) = &f.rename {
            let target = bt
                .methods
                .iter_mut()
                .chain(bt.ctor.iter_mut())
                .find(|m| m.name == method);
            match target {
                Some(m) => m.export_name = Some(new.clone()),
                None => {
                    return Err(format!(
                        "overlay: [fn.\"{key}\"] rename — no bridged method `{method}` on `{type_name}`"
                    ))
                }
            }
        }
    }

    Ok(())
}
