//! trybuild rejection tests (M2 acceptance): every non-bridgeable construct must
//! fail to compile with a diagnostic that names the violated rule — never a
//! confusing downstream type error and never a silently-wrong shim.
//!
//! Regenerate the .stderr expectations after an intentional diagnostic change:
//!   TRYBUILD=overwrite cargo test -p jac-bridge --test compile_fail

#[test]
fn rejections() {
    let t = trybuild::TestCases::new();
    t.compile_fail("tests/ui/*.rs");
}
