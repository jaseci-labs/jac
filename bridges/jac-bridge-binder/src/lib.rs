pub mod classify;
pub mod codegen;
pub mod coverage;
pub mod overlay;
pub mod types;

pub use classify::classify;
pub use codegen::{emit, emit_cargo_toml};
pub use coverage::{coverage, report, Coverage};
pub use overlay::{apply_overlay, parse_overlay, Overlay};

#[cfg(test)]
mod tests {
    mod classify_regex;
    mod codegen_regex;
    mod coverage_regex;
    mod overlay_regex;
}
