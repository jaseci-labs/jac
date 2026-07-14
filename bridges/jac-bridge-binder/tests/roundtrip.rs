//! Round-trip validation: the binder's output must actually *compile*.
//!
//! The unit tests check the generated source *structurally*; this test closes
//! the loop by writing a full crate from the regex fixture and building it with
//! the real `jac-bridge` proc macro + the real `regex` crate, asserting the
//! build is warning-clean and exports the expected shim symbols.
//!
//! It compiles a whole crate (~15s cold), so it is `#[ignore]`d by default —
//! run it explicitly with `cargo test -p jac-bridge-binder -- --ignored`, and
//! the CI corpus job runs it on every push.

use std::path::PathBuf;
use std::process::Command;

fn manifest_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn fixture(name: &str) -> PathBuf {
    manifest_dir().join("tests/fixtures").join(name)
}

#[test]
#[ignore = "compiles a full crate; run with --ignored (CI does)"]
fn regex_bridge_compiles_clean() {
    let doc_path = fixture("regex-1.12.4.json");
    let doc: rustdoc_types::Crate =
        serde_json::from_str(&std::fs::read_to_string(&doc_path).expect("read fixture"))
            .expect("parse fixture");

    let mut spec = jac_bridge_binder::classify(&doc);

    // Apply the adjacent example overlay so the generated crate also exercises
    // inject (raw Rust source) and rename — proving both compile, not just the
    // pure rule-set output.
    let overlay_path = fixture("regex.overlay.toml");
    let overlay = jac_bridge_binder::parse_overlay(
        &std::fs::read_to_string(&overlay_path).expect("read overlay"),
    )
    .expect("parse overlay");
    jac_bridge_binder::apply_overlay(&mut spec, &overlay).expect("apply overlay");

    // Phase S: also force a `borrowed` ownership class on a bridged handle return
    // (`Regex::find -> Option<OwnedMatch>`, a `&self` method). This proves the
    // binder-emitted `#[jac(borrowed)]` attribute is macro-legal and the generated
    // crate still compiles warning-clean with the ownership bit in play — S.2.3's
    // "generated crate compiles under -D warnings" gate for the ownership path.
    let own_overlay = jac_bridge_binder::parse_overlay(
        "[fn.\"Regex::find\"]\nownership = \"borrowed\"\n",
    )
    .expect("parse ownership overlay");
    jac_bridge_binder::apply_overlay(&mut spec, &own_overlay).expect("apply ownership overlay");

    let jac_bridge = manifest_dir().join("../jac-bridge");
    let lib_src = jac_bridge_binder::emit(&spec);
    let cargo_src = jac_bridge_binder::emit_cargo_toml(&spec, &jac_bridge.to_string_lossy());

    // Write the generated crate under target/ so it is gitignored and can reuse
    // the workspace's cargo registry cache for deps.
    let out = manifest_dir().join("../target/binder-roundtrip/regex");
    let _ = std::fs::remove_dir_all(&out);
    std::fs::create_dir_all(out.join("src")).expect("mkdir");
    std::fs::write(out.join("src/lib.rs"), &lib_src).expect("write lib.rs");
    // The output lives under the workspace tree; declare it its own workspace
    // root so cargo doesn't treat it as an (unlisted) member. Real generated
    // bridge crates are standalone, so this only affects the test sandbox.
    let cargo_src = format!("{cargo_src}\n[workspace]\n");
    std::fs::write(out.join("Cargo.toml"), &cargo_src).expect("write Cargo.toml");

    let output = Command::new(env!("CARGO"))
        .current_dir(&out)
        .args(["build", "--release"])
        // -D warnings: generated code must be clean, not merely valid.
        .env("RUSTFLAGS", "-D warnings")
        .output()
        .expect("run cargo build");

    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        output.status.success(),
        "generated regex bridge failed to compile:\n{stderr}\n\n--- lib.rs ---\n{lib_src}"
    );

    // Overlay took effect: injected method + renamed export are in the source.
    assert!(
        lib_src.contains("pub fn find_str("),
        "inject missing\n{lib_src}"
    );
    assert!(
        lib_src.contains("pub fn matches(&self,"),
        "rename missing\n{lib_src}"
    );

    // Ownership overlay took effect: `find` carries the borrowed attribute (which
    // the macro consumed to set the return tag's borrow bit — its presence in the
    // source plus a clean compile is the proof the attribute is macro-legal).
    let find_pos = lib_src.find("pub fn find(&self,").expect("find method missing");
    assert!(
        lib_src[..find_pos].trim_end().ends_with("#[jac(borrowed)]"),
        "borrowed attribute must sit immediately above `pub fn find`\n{lib_src}"
    );

    // Owning-wrapper synthesis (M4 Phase B v1): the generated crate compiling
    // under -D warnings is the real proof the ouroboros transmute is sound.
    assert!(
        lib_src.contains("pub struct OwnedMatch {"),
        "OwnedMatch missing\n{lib_src}"
    );
    assert!(
        lib_src.contains("std::mem::transmute(inner)"),
        "wrap transmute missing\n{lib_src}"
    );

    // The compiled cdylib must export the auto-generated shim + drop symbols.
    let so = out.join("target/release/libjac_bridge_regex.so");
    assert!(so.exists(), "cdylib not produced at {}", so.display());
    let nm = Command::new("nm")
        .args(["-D"])
        .arg(&so)
        .output()
        .expect("nm");
    let syms = String::from_utf8_lossy(&nm.stdout);
    for want in [
        "jac_regex_Regex_new",
        "jac_regex_Regex_matches",     // is_match, renamed by the overlay
        "jac_regex_Regex_find_str",    // injected by the overlay
        "jac_regex_Regex_find",        // producer of the synthesized wrapper
        "jac_regex_OwnedMatch_as_str", // wrapper reader
        "jac_regex_OwnedMatch_is_empty",
        "jac_regex_OwnedMatch_drop",    // wrapper is an opaque handle
        "jac_regex_RegexSet_patterns",  // Vec/slice-drain producer (M4 Phase B)
        "jac_regex_OwnedPatterns_next", // its drain pull method
        "jac_regex_OwnedPatterns_drop", // the drain is an opaque handle
        "jac_regex_Regex_drop",
        "jac_regex_error_message",
        "jac_regex_free_buf",
        "jac_bridge_init_regex",
    ] {
        assert!(syms.contains(want), "missing exported symbol {want}");
    }
}
