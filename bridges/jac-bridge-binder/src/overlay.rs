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
//! Directives the rule set can't yet honour (`treat_as`, `monomorphize`,
//! `[module]`) parse but are rejected with a precise reason rather than silently
//! ignored — an overlay entry is a decision the author expects to take effect.

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
    /// Reserved: correct a rule's classification (e.g. `"cursor"`). Phase B.
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
    /// Reserved: pin a monomorphization set the rules couldn't infer. Phase B.
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
    // ── [module."m"] — reserved ──────────────────────────────────────────────
    for (name, m) in &overlay.modules {
        if m.skip {
            return Err(format!(
                "overlay: [module.\"{name}\"] skip is not supported yet — classify \
                 flattens submodule provenance; reserved for M4 Phase B"
            ));
        }
    }

    // ── [type."T"] ───────────────────────────────────────────────────────────
    for (name, t) in &overlay.types {
        if t.monomorphize.is_some() {
            return Err(format!(
                "overlay: [type.\"{name}\"] monomorphize is not supported yet — \
                 needs the generic-monomorphization rule (M4 Phase B)"
            ));
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

        if let Some(kind) = &f.treat_as {
            return Err(format!(
                "overlay: [fn.\"{key}\"] treat_as = \"{kind}\" is not supported yet — \
                 needs the cursor/owning-wrapper rules (M4 Phase B)"
            ));
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
