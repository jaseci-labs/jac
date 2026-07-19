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
    mod callback_escape;
    mod classify_regex;
    mod classify_semver;
    mod codegen_async;
    mod codegen_containers;
    mod codegen_regex;
    mod coverage_regex;
    mod ctor_dedup;
    mod enum_param;
    mod flatten_trait;
    mod float_scalar;
    mod fn_static;
    mod handle_value_param;
    mod monomorphize_chrono;
    mod opt_str;
    mod opt_str_ref;
    mod overlay_regex;
    mod ref_lane;
    mod regex_parity;
    mod self_alias;
    mod string_return;
    mod tuple_return;
    mod tuple_struct;
    mod unit_enum;
    mod wide_lane;
}
