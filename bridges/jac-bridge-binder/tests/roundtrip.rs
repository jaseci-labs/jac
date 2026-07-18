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
    // rename - proving it compiles, not just the pure rule-set output.
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
    let own_overlay =
        jac_bridge_binder::parse_overlay("[fn.\"Regex::find\"]\nownership = \"borrowed\"\n")
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

    // Overlay took effect: the renamed export is in the source, and the retired
    // `find_str` inject stays gone (the owned `find` wrapper covers it for real).
    assert!(
        lib_src.contains("pub fn matches(&self,"),
        "rename missing\n{lib_src}"
    );
    assert!(
        !lib_src.contains("find_str"),
        "the find_str inject hack must stay deleted\n{lib_src}"
    );

    // Full-parity lanes: builder chain setters ride the self-identity `&Self`
    // return; `build` is a cross-type fallible handle producer.
    assert!(
        lib_src.contains("pub fn case_insensitive(&mut self, yes: bool) -> &Self"),
        "builder chain setter missing\n{lib_src}"
    );
    assert!(
        lib_src.contains("pub fn build(&self) -> Result<Regex, String>"),
        "cross-type fallible build missing\n{lib_src}"
    );
    assert!(
        lib_src.contains("pub fn build(&self) -> Result<RegexSet, String>"),
        "RegexSetBuilder::build missing\n{lib_src}"
    );
    // Option<int> returns ride the null-JacBuf channel.
    assert!(
        lib_src.contains("pub fn shortest_match(&self, haystack: &str) -> Option<usize>"),
        "Option<usize> lane missing\n{lib_src}"
    );
    // Iterator-of-strings generic params monomorphize to Wide<Vec<String>>.
    assert!(
        lib_src.contains("pub fn new(patterns: Wide<Vec<String>>) -> Self"),
        "RegexSetBuilder::new Wide<Vec<String>> param missing\n{lib_src}"
    );
    // Replacer &str monomorphization (replacen) + splitn drain + int collect.
    assert!(
        lib_src
            .contains("pub fn replacen(&self, haystack: &str, limit: usize, rep: &str) -> String"),
        "replacen &str monomorphization missing\n{lib_src}"
    );
    assert!(
        lib_src.contains("pub fn splitn(&self, haystack: &str, limit: usize) -> OwnedSplitN"),
        "splitn drain missing\n{lib_src}"
    );
    assert!(
        lib_src.contains("pub fn iter(&self) -> Vec<usize>"),
        "SetMatches::iter collect missing\n{lib_src}"
    );

    // Ownership overlay took effect: `find` carries the borrowed attribute (which
    // the macro consumed to set the return tag's borrow bit — its presence in the
    // source plus a clean compile is the proof the attribute is macro-legal).
    let find_pos = lib_src
        .find("pub fn find(&self,")
        .expect("find method missing");
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
        "jac_regex_Regex_find",        // producer of the synthesized wrapper
        "jac_regex_Regex_shortest_match", // Option<usize> null-JacBuf lane
        "jac_regex_Regex_replacen",    // replacer &str monomorphization
        "jac_regex_Regex_splitn",      // multi-param drain
        "jac_regex_Regex_find_at",     // inline owning producer
        "jac_regex_RegexBuilder_case_insensitive", // chain setter (&Self identity)
        "jac_regex_RegexBuilder_build", // cross-type fallible handle producer
        "jac_regex_RegexSetBuilder_new", // Wide<Vec<String>> param ctor
        "jac_regex_SetMatches_iter",   // int-iterator collect (list return)
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

/// sha2 closes the Track A loop (1.1.2 + 1.1.5): its hashers get their `new`
/// constructor from a blanket `impl<D> Digest for D` whose signatures spell `Self`
/// as the generic `D` (`Digest::new() -> D`). The self-alias substitution must turn
/// that into a real `-> Self` ctor, and the flattened trait's `use` must resolve
/// (`Digest`/`DynDigest` route through sha2's `pub use digest;` re-export). The only
/// airtight proof of both is the generated crate compiling warning-clean against the
/// real sha2 + digest crates and exporting the ctor shims.
#[test]
#[ignore = "compiles a full crate; run with --ignored (CI does)"]
fn sha2_bridge_compiles_clean() {
    let doc_path = fixture("sha2-0.11.0.json");
    let doc: rustdoc_types::Crate =
        serde_json::from_str(&std::fs::read_to_string(&doc_path).expect("read fixture"))
            .expect("parse fixture");

    let spec = jac_bridge_binder::classify(&doc);
    let lib_src = jac_bridge_binder::emit(&spec);

    // The blanket-generic `Digest::new() -> D` became a real `-> Self` ctor, brought
    // into scope through sha2's re-export of the (external) digest crate.
    assert!(
        lib_src.contains("Self(sha2::Sha256::new())"),
        "Sha256 constructor (self-alias `D` → Self) missing\n{lib_src}"
    );
    assert!(
        lib_src.contains("use sha2::digest::Digest;"),
        "flattened Digest must be `use`d via the module's digest re-export\n{lib_src}"
    );

    let jac_bridge = manifest_dir().join("../jac-bridge");
    let cargo_src = jac_bridge_binder::emit_cargo_toml(&spec, &jac_bridge.to_string_lossy());

    let out = manifest_dir().join("../target/binder-roundtrip/sha2");
    let _ = std::fs::remove_dir_all(&out);
    std::fs::create_dir_all(out.join("src")).expect("mkdir");
    std::fs::write(out.join("src/lib.rs"), &lib_src).expect("write lib.rs");
    let cargo_src = format!("{cargo_src}\n[workspace]\n");
    std::fs::write(out.join("Cargo.toml"), &cargo_src).expect("write Cargo.toml");

    let output = Command::new(env!("CARGO"))
        .current_dir(&out)
        .args(["build", "--release"])
        // -D warnings: no separate `digest` dep is added (the trait resolves through
        // sha2's own re-export), so an unsatisfied trait would surface as an error.
        .env("RUSTFLAGS", "-D warnings")
        .output()
        .expect("run cargo build");

    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        output.status.success(),
        "generated sha2 bridge failed to compile:\n{stderr}\n\n--- lib.rs ---\n{lib_src}"
    );

    let so = out.join("target/release/libjac_bridge_sha2.so");
    assert!(so.exists(), "cdylib not produced at {}", so.display());
    let nm = Command::new("nm")
        .args(["-D"])
        .arg(&so)
        .output()
        .expect("nm");
    let syms = String::from_utf8_lossy(&nm.stdout);
    for want in [
        "jac_sha2_Sha256_new",         // self-alias constructor
        "jac_sha2_Sha256_output_size", // flattened DynDigest method
        "jac_sha2_Sha256_drop",
        "jac_sha2_Sha512_new",
        "jac_bridge_init_sha2",
        // 1.2.2 byte lane: the SHA-256 compute surface reaches the C ABI.
        "jac_sha2_Sha256_update",         // &mut self, &[u8] sink
        "jac_sha2_Sha256_finalize",       // consuming self, Vec<u8> digest
        "jac_sha2_Sha256_finalize_reset", // &mut self, Vec<u8> digest
    ] {
        assert!(syms.contains(want), "missing exported symbol {want}");
    }
    // The byte-lane bodies compiled: `update` takes a slice, `finalize` clones the
    // handle out and returns owned bytes. (Runtime hash-equivalence against known
    // SHA-256 vectors is the CPython conformance test in the CI matrix; na is gated
    // on the two proven na byte-lane gaps.)
    assert!(
        lib_src.contains("Digest::update(&mut self.0, data)"),
        "update must sink bytes through a &mut receiver\n{lib_src}"
    );
    assert!(
        lib_src.contains("Digest::finalize(self.0.clone()).to_vec()"),
        "finalize must clone the handle out and return owned bytes\n{lib_src}"
    );
}

/// uuid closes the 1.2.5 loop (single-field tuple-struct admission). `uuid::Uuid`
/// and its format-handle siblings are `pub struct T([..])` newtypes with a private
/// inner — the shape `classify_type` now admits as an opaque handle. The airtight
/// proof is the generated crate compiling warning-clean against real uuid, which
/// also exercises: submodule path resolution (`uuid::fmt::Simple`, a PUBLIC module),
/// private-module root re-exports (`uuid::NonNilUuid`, whose `non_nil` module is
/// private), the 1.2.4 ref lane between the handles, and the dead-opaque reconcile
/// (`Uuid::get_timestamp` demoted so no undeclared `Timestamp` wrapper is referenced).
#[test]
#[ignore = "compiles a full crate; run with --ignored (CI does)"]
fn uuid_bridge_compiles_clean() {
    let doc_path = fixture("uuid-1.23.4.json");
    let doc: rustdoc_types::Crate =
        serde_json::from_str(&std::fs::read_to_string(&doc_path).expect("read fixture"))
            .expect("parse fixture");

    let spec = jac_bridge_binder::classify(&doc);
    let lib_src = jac_bridge_binder::emit(&spec);

    // Path resolution: a public-submodule wrap, a private-module root-reexport wrap.
    assert!(
        lib_src.contains("pub struct Simple(pub uuid::fmt::Simple);"),
        "Simple must wrap its public submodule path\n{lib_src}"
    );
    assert!(
        lib_src.contains("pub struct NonNilUuid(pub uuid::NonNilUuid);"),
        "NonNilUuid must wrap its crate-root re-export path\n{lib_src}"
    );
    // `Timestamp` is now a LIVE opaque handle — its `-> Self` ctor
    // `from_gregorian_time` bridges — so `get_timestamp -> Option<Timestamp>` is a
    // valid cross-type return and the wrapper IS emitted (must still compile).
    assert!(
        lib_src.contains("pub struct Timestamp(pub uuid::Timestamp);"),
        "the live Timestamp handle must be emitted\n{lib_src}"
    );

    let jac_bridge = manifest_dir().join("../jac-bridge");
    let cargo_src = jac_bridge_binder::emit_cargo_toml(&spec, &jac_bridge.to_string_lossy());

    let out = manifest_dir().join("../target/binder-roundtrip/uuid");
    let _ = std::fs::remove_dir_all(&out);
    std::fs::create_dir_all(out.join("src")).expect("mkdir");
    std::fs::write(out.join("src/lib.rs"), &lib_src).expect("write lib.rs");
    let cargo_src = format!("{cargo_src}\n[workspace]\n");
    std::fs::write(out.join("Cargo.toml"), &cargo_src).expect("write Cargo.toml");

    let output = Command::new(env!("CARGO"))
        .current_dir(&out)
        .args(["build", "--release"])
        .env("RUSTFLAGS", "-D warnings")
        .output()
        .expect("run cargo build");

    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        output.status.success(),
        "generated uuid bridge failed to compile:\n{stderr}\n\n--- lib.rs ---\n{lib_src}"
    );

    let so = out.join("target/release/libjac_bridge_uuid.so");
    assert!(so.exists(), "cdylib not produced at {}", so.display());
    let nm = Command::new("nm")
        .args(["-D"])
        .arg(&so)
        .output()
        .expect("nm");
    let syms = String::from_utf8_lossy(&nm.stdout);
    for want in [
        "jac_uuid_Uuid_is_nil", // the plan's conformance predicate
        "jac_uuid_Uuid_is_max",
        "jac_uuid_Uuid_drop",        // Uuid is an opaque handle
        "jac_uuid_Simple_into_uuid", // ref-lane handle conversion
        "jac_uuid_NonNilUuid_get",   // private-module type, root-reexport path
        "jac_bridge_init_uuid",
    ] {
        assert!(syms.contains(want), "missing exported symbol {want}");
    }
}

/// The seed-crate proof: `semver` bridged WITH its overlay (`treat_as = "opaque"`
/// on `Version`/`VersionReq`) must compile — exercising the INBOUND HANDLE PARAM
/// lane (`VersionReq::matches(&self, &Version)`), the literal-`Self` alias fix
/// (`Version::parse -> Result<Self, Error>`), and two bridged types interacting.
#[test]
#[ignore = "compiles a full crate; run with --ignored (CI does)"]
fn semver_bridge_compiles_clean() {
    let doc_path = fixture("semver-1.0.27.json");
    let doc: rustdoc_types::Crate =
        serde_json::from_str(&std::fs::read_to_string(&doc_path).expect("read fixture"))
            .expect("parse fixture");
    let overlay_src =
        std::fs::read_to_string(fixture("semver.overlay.toml")).expect("read overlay");
    let overlay = jac_bridge_binder::parse_overlay(&overlay_src).expect("parse overlay");

    // `treat_as` steers classification; `inject`/`rename` are applied afterwards
    // (mirrors the CLI's two-step flow in main.rs).
    let mut spec = jac_bridge_binder::classify_with_overlay(&doc, Some(&overlay));
    jac_bridge_binder::apply_overlay(&mut spec, &overlay).expect("apply overlay");
    let lib_src = jac_bridge_binder::emit(&spec);

    // The inbound-handle-param lane: a param that is a reference to another bridged
    // handle, forwarded as `&{name}.0` to the inner call.
    assert!(
        lib_src.contains("pub fn matches(&self, version: &Version) -> bool"),
        "VersionReq::matches must take a &Version handle param\n{lib_src}"
    );
    assert!(
        lib_src.contains("self.0.matches(&version.0)"),
        "matches must forward the handle's inner value\n{lib_src}"
    );

    // The Ordering return lane: `Version::cmp_precedence(&self, &Version) -> Ordering`
    // is a REAL inherent semver method with NO overlay inject — the binder lowers its
    // `Ordering` return automatically onto the `i8` lane (`-> i8` signature + a `match`
    // mapping the three variants to -1/0/1). This is the whole point of the lane: no
    // hand-written `cmp` inject is needed anymore.
    assert!(
        lib_src.contains("pub fn cmp_precedence(&self, other: &Version) -> i8"),
        "cmp_precedence must bridge automatically as an i8 return\n{lib_src}"
    );
    assert!(
        lib_src.contains("::std::cmp::Ordering::Less => -1i8"),
        "cmp_precedence body must map Ordering variants to -1/0/1\n{lib_src}"
    );

    // Full-parity synth lanes (no overlay inject): Display -> to_string, Ord -> cmp,
    // FromStr -> a fully-qualified static, and the opaque field-reader lane
    // (scalar / handle / fieldless-enum readers). All must compile against real
    // semver under -D warnings, which is the airtight proof.
    assert!(
        lib_src.contains("pub fn to_string(&self) -> String {\n            self.0.to_string()"),
        "Display lane must synthesize to_string\n{lib_src}"
    );
    assert!(
        lib_src.contains("pub fn cmp(&self, other: &Version) -> i8"),
        "Ord lane must synthesize cmp with a &Version handle param\n{lib_src}"
    );
    assert!(
        lib_src.contains("<semver::Version as ::std::str::FromStr>::from_str(text)"),
        "FromStr lane must emit a fully-qualified associated call\n{lib_src}"
    );
    assert!(
        lib_src.contains(
            "pub fn pre(&self) -> Prerelease {\n            Prerelease(self.0.pre.clone())"
        ),
        "handle field reader must clone + wrap the inner field\n{lib_src}"
    );
    assert!(
        lib_src.contains("semver::Op::Exact => \"Exact\",")
            && lib_src.contains("_ => \"unknown\","),
        "Comparator.op fieldless-enum reader must map variants to names\n{lib_src}"
    );
    // Option<int> lane on a FIELD: `Comparator.minor: Option<u64>` reads directly
    // (the field is Copy) and crosses the null-JacBuf None channel.
    assert!(
        lib_src.contains("pub fn minor(&self) -> Option<u64> {\n            self.0.minor"),
        "Comparator.minor must ride the Option<int> field-reader lane\n{lib_src}"
    );
    // No unresolvable std-trait `use` leaked (the FromStr call is fully-qualified).
    assert!(
        !lib_src.contains("use semver::core::") && !lib_src.contains("use semver::std::"),
        "no std-trait use may be emitted\n{lib_src}"
    );

    let jac_bridge = manifest_dir().join("../jac-bridge");
    let cargo_src = jac_bridge_binder::emit_cargo_toml(&spec, &jac_bridge.to_string_lossy());

    let out = manifest_dir().join("../target/binder-roundtrip/semver");
    let _ = std::fs::remove_dir_all(&out);
    std::fs::create_dir_all(out.join("src")).expect("mkdir");
    std::fs::write(out.join("src/lib.rs"), &lib_src).expect("write lib.rs");
    let cargo_src = format!("{cargo_src}\n[workspace]\n");
    std::fs::write(out.join("Cargo.toml"), &cargo_src).expect("write Cargo.toml");

    let output = Command::new(env!("CARGO"))
        .current_dir(&out)
        .args(["build", "--release"])
        .env("RUSTFLAGS", "-D warnings")
        .output()
        .expect("run cargo build");
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        output.status.success(),
        "generated semver bridge failed to compile:\n{stderr}\n\n--- lib.rs ---\n{lib_src}"
    );

    let so = out.join("target/release/libjac_bridge_semver.so");
    assert!(so.exists(), "cdylib not produced at {}", so.display());
    let nm = Command::new("nm")
        .args(["-D"])
        .arg(&so)
        .output()
        .expect("nm");
    let syms = String::from_utf8_lossy(&nm.stdout);
    for want in [
        "jac_semver_Version_parse", // Result<Self, Error> ctor (literal-Self fix)
        "jac_semver_VersionReq_matches", // inbound handle param (&Version)
        "jac_semver_Version_cmp",   // Ord lane: synthesized handle-param cmp
        "jac_semver_Version_cmp_precedence", // Ordering return lane (auto -1/0/1 i8)
        "jac_semver_Version_to_string", // Display lane
        "jac_semver_Version_from_str", // FromStr lane (fully-qualified static)
        "jac_semver_Version_major", // scalar field-reader lane
        "jac_semver_Version_pre",   // handle field-reader lane (-> Prerelease)
        "jac_semver_Version_drop",  // Version is now an opaque handle
        "jac_semver_Comparator_matches", // Comparator forced opaque: its methods bridge
        "jac_semver_Comparator_op", // fieldless-enum field reader (-> String)
        "jac_semver_Comparator_minor", // Option<u64> field reader (Option<int> lane)
        "jac_semver_BuildMetadata_cmp", // Ord lane on a naturally-opaque type
        "jac_bridge_init_semver",
    ] {
        assert!(syms.contains(want), "missing exported symbol {want}");
    }
}
