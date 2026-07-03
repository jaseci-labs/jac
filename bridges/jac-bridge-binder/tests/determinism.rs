//! Determinism (D6): same crate + binder version + overlay → byte-identical
//! bridge source. Reproducible artifacts fall out of this, which is what makes
//! the registry-as-cache verifiable by re-derivation.
//!
//! `classify` funnels its type set through a `HashMap` whose iteration order is
//! seeded per process, so the true test runs the binder as *separate processes*
//! (fresh seeds) and diffs stdout — an in-process loop would share one seed and
//! could hide an ordering bug that a canonicalizing `sort` is meant to mask.

use std::path::PathBuf;
use std::process::Command;

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures").join(name)
}

fn run_binder(doc: &PathBuf) -> String {
    let out = Command::new(env!("CARGO_BIN_EXE_jac-bridge-binder"))
        .arg(doc)
        .output()
        .expect("run binder");
    assert!(out.status.success(), "binder exited non-zero");
    String::from_utf8(out.stdout).expect("utf8 stdout")
}

#[test]
fn emit_is_byte_identical_across_processes() {
    let doc = fixture("regex-1.12.4.json");
    let first = run_binder(&doc);
    for i in 0..4 {
        let again = run_binder(&doc);
        assert_eq!(
            first, again,
            "binder output differs across runs (iteration {i}) — nondeterministic codegen"
        );
    }
    assert!(first.contains("#[bridge(module = \"regex\")]"));
}
