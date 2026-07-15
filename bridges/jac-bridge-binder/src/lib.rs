pub mod classify;
pub mod codegen;
pub mod coverage;
pub mod overlay;
pub mod types;

pub use classify::{classify, classify_with_overlay};
pub use codegen::{emit, emit_cargo_toml};
pub use coverage::{coverage, report, Coverage};
pub use overlay::{apply_overlay, parse_overlay, Overlay};

#[cfg(test)]
mod tests {
    mod classify_regex;
    mod codegen_async;
    mod codegen_containers;
    mod codegen_regex;
    mod coverage_regex;
    mod ctor_dedup;
    mod flatten_trait;
    mod monomorphize_chrono;
    mod overlay_regex;
    mod ref_lane;
    mod self_alias;
    mod tuple_struct;
}
