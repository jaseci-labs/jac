//! Coverage metric — the north-star number for the binder (D6).
//!
//! Coverage is measured over *functions* (constructors + methods): every public
//! method on a bridged type is either emitted or a recorded [`Skip`], so the
//! ratio is honest by construction. Types that classify drops wholesale (e.g.
//! lifetime-bearing cursor types) surface here indirectly — the methods that
//! return or consume them appear as skips on the types that *are* bridged.

use crate::types::{BridgeSpec, SkipReason};

/// Coverage summary for one crate.
#[derive(Debug, Clone, PartialEq)]
pub struct Coverage {
    pub module: String,
    pub version: String,
    /// Constructors + methods that made it into the bridge source.
    pub bridged: usize,
    /// Public items skipped with a machine-readable reason.
    pub skipped: usize,
}

impl Coverage {
    /// Total public items considered (bridged + skipped).
    pub fn total(&self) -> usize {
        self.bridged + self.skipped
    }

    /// Percent of the considered surface that was bridged, rounded to the
    /// nearest integer. An empty surface is defined as 100% (nothing to miss).
    pub fn pct(&self) -> u32 {
        let total = self.total();
        if total == 0 {
            return 100;
        }
        ((self.bridged as f64 / total as f64) * 100.0).round() as u32
    }
}

/// Compute the coverage summary for a classified (and overlay-applied) spec.
pub fn coverage(spec: &BridgeSpec) -> Coverage {
    let bridged = spec
        .types
        .iter()
        .map(|t| t.ctor.is_some() as usize + t.methods.len())
        .sum();
    Coverage {
        module: spec.module_name.clone(),
        version: spec.crate_version.clone(),
        bridged,
        skipped: spec.skips.len(),
    }
}

/// Human-readable coverage line plus the skip list, e.g.
///
/// ```text
/// regex v1.12.4: 63% of public API bridged (12/19);
///   skipped: Regex::find (lifetime borrow), Regex::is_match_at (unsupported type: usize param), ...
/// ```
pub fn report(spec: &BridgeSpec) -> String {
    let cov = coverage(spec);
    // An empty surface is not "100% covered" — it means classify found nothing
    // bridgeable (trait-only API, type aliases, feature-gated methods). Say so,
    // rather than printing a flattering percentage.
    if cov.total() == 0 {
        return format!(
            "{} v{}: no bridgeable public surface found",
            cov.module, cov.version
        );
    }
    let mut out = format!(
        "{} v{}: {}% of public API bridged ({}/{})",
        cov.module,
        cov.version,
        cov.pct(),
        cov.bridged,
        cov.total(),
    );
    if spec.skips.is_empty() {
        out.push(';');
        return out;
    }
    out.push_str(";\n  skipped: ");
    let mut items: Vec<String> = spec
        .skips
        .iter()
        .map(|s| format!("{} ({})", s.item, reason_label(&s.reason)))
        .collect();
    items.sort();
    out.push_str(&items.join(", "));
    out
}

/// Short prose label for a skip reason — machine-readable and stable so the CI
/// corpus job can diff skip reasons across binder versions.
fn reason_label(r: &SkipReason) -> String {
    match r {
        SkipReason::LifetimeBorrow => "lifetime borrow".into(),
        SkipReason::Cursor => "iterator/cursor".into(),
        SkipReason::Closure => "closure arg".into(),
        SkipReason::Generic => "generic".into(),
        SkipReason::UnsupportedType(t) => format!("unsupported type: {t}"),
    }
}
