//! Coverage metric — the north-star number for the binder (D6).
//!
//! Coverage is measured over *functions* (constructors + methods): every public
//! method on a bridged type is either emitted or a recorded [`Skip`], so the
//! ratio is honest by construction. Types that classify drops wholesale (e.g.
//! lifetime-bearing cursor types, unpinned generics) are counted too — each as
//! one unit of considered-but-unbridged surface (`dropped`) — so the ratio can
//! never improve merely by hiding an unsupported type. A dropped type is charged
//! one unit rather than its true method count because it is dropped *before* its
//! methods are classified; one unit is the honest floor, not an exact debit.

use crate::types::{BridgeSpec, DropReason, SkipReason};

/// Coverage summary for one crate.
#[derive(Debug, Clone, PartialEq)]
pub struct Coverage {
    pub module: String,
    pub version: String,
    /// Constructors + methods that made it into the bridge source.
    pub bridged: usize,
    /// Public items skipped with a machine-readable reason.
    pub skipped: usize,
    /// Whole public types dropped before method classification (unpinned
    /// generics, const generics, lifetime-bearing structs). Each counts as one
    /// unit of unbridged surface so hiding a type can't inflate the ratio.
    pub dropped: usize,
    /// Unresolvable trait-provided defaults (D1) — EXCLUDED from `total()`/`pct()`.
    /// Reported for auditability ("+N inherited defaults not considered") but kept
    /// out of the ratio so the metric stays comparable across crates.
    pub inherited_excluded: usize,
}

impl Coverage {
    /// Total public surface considered (bridged + skipped + dropped types).
    pub fn total(&self) -> usize {
        self.bridged + self.skipped + self.dropped
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
        dropped: spec.dropped.len(),
        inherited_excluded: spec.inherited_excluded,
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
    // Unresolvable trait-provided defaults are excluded from the ratio (D1); make
    // the exclusion auditable rather than silent.
    if cov.inherited_excluded > 0 {
        out.push_str(&format!(
            " +{} inherited defaults not considered",
            cov.inherited_excluded
        ));
    }
    if spec.skips.is_empty() && spec.dropped.is_empty() {
        out.push(';');
        return out;
    }
    if !spec.skips.is_empty() {
        out.push_str(";\n  skipped: ");
        let mut items: Vec<String> = spec
            .skips
            .iter()
            .map(|s| format!("{} ({})", s.item, reason_label(&s.reason)))
            .collect();
        items.sort();
        out.push_str(&items.join(", "));
    }
    // Dropped whole types are listed separately from per-method skips so the
    // hidden surface is visible, not silently absent from the report.
    if !spec.dropped.is_empty() {
        out.push_str(";\n  dropped types: ");
        let mut items: Vec<String> = spec
            .dropped
            .iter()
            .map(|d| format!("{} ({})", d.name, drop_label(&d.reason)))
            .collect();
        items.sort();
        out.push_str(&items.join(", "));
    }
    out
}

/// Short prose label for a drop reason, stable for corpus diffs.
fn drop_label(r: &DropReason) -> &'static str {
    match r {
        DropReason::Lifetime => "lifetime-bearing struct",
        DropReason::ConstGeneric => "const-generic struct",
        DropReason::UnpinnedGeneric => "unpinned generic (needs monomorphize overlay)",
    }
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
        SkipReason::OverlayTreatAs(m) => format!("overlay treat_as: {m}"),
        SkipReason::OverlaySkip(Some(reason)) => format!("overlay skip: {reason}"),
        SkipReason::OverlaySkip(None) => "overlay skip".into(),
    }
}
