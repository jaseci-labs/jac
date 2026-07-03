//! Corpus tests: classify + codegen every fixture in tests/fixtures/*.json.
//!
//! These tests are deliberately coarse — they verify the pipeline doesn't panic
//! and that the output is structurally valid.  To add a new crate to the corpus,
//! add its rustdoc JSON to tests/fixtures/ (see tests/corpus/gen-fixtures.sh).

use std::collections::BTreeMap;
use std::path::PathBuf;

use serde::Deserialize;

fn fixture_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

fn corpus_fixtures() -> Vec<PathBuf> {
    let dir = fixture_dir();
    if !dir.exists() {
        return vec![];
    }
    let mut paths: Vec<PathBuf> = std::fs::read_dir(&dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| p.extension().map(|x| x == "json").unwrap_or(false))
        .collect();
    paths.sort();
    paths
}

#[test]
fn corpus_classify_and_codegen() {
    let fixtures = corpus_fixtures();
    if fixtures.is_empty() {
        eprintln!("no corpus fixtures — run tests/corpus/gen-fixtures.sh to populate");
        return;
    }

    for path in &fixtures {
        let name = path.file_stem().unwrap().to_string_lossy();
        let data = std::fs::read_to_string(path)
            .unwrap_or_else(|_| panic!("read {name}"));
        let doc: rustdoc_types::Crate =
            serde_json::from_str(&data).unwrap_or_else(|e| panic!("{name}: {e}"));

        let spec = jac_bridge_binder::classify(&doc);

        assert!(
            !spec.module_name.is_empty(),
            "{name}: module_name must not be empty"
        );
        assert!(
            !spec.crate_version.is_empty(),
            "{name}: crate_version must not be empty"
        );

        let src = jac_bridge_binder::emit(&spec);

        assert!(
            src.contains("#[bridge(module ="),
            "{name}: missing #[bridge] attribute\n{src}"
        );

        // No duplicate struct declarations.
        let mut struct_names: Vec<&str> = src
            .lines()
            .filter(|l| l.trim_start().starts_with("pub struct "))
            .map(|l| l.trim_start().trim_start_matches("pub struct ").split('(').next().unwrap().split(';').next().unwrap().trim())
            .collect();
        struct_names.sort_unstable();
        let deduped: Vec<&str> = {
            let mut d = struct_names.clone();
            d.dedup();
            d
        };
        assert_eq!(struct_names, deduped, "{name}: duplicate structs in codegen output");

        let cargo = jac_bridge_binder::emit_cargo_toml(&spec, "../jac-bridge");
        assert!(
            cargo.contains("crate-type = [\"cdylib\", \"rlib\"]"),
            "{name}: Cargo.toml missing cdylib"
        );

        eprintln!(
            "ok  {name}  types={} skips={}",
            spec.types.len(),
            spec.skips.len()
        );
    }
}

// ── coverage regression gate ───────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct Floor {
    bridged: usize,
    total: usize,
}

/// The north-star gate (D6): coverage must never regress below the checked-in
/// floor. Every corpus fixture must have a baseline entry, and its bridged count
/// must meet or exceed the floor. Raising a floor is how Phase B progress is
/// ratcheted in; a drop blocks merge.
#[test]
fn coverage_does_not_regress() {
    let fixtures = corpus_fixtures();
    if fixtures.is_empty() {
        eprintln!("no corpus fixtures — run tests/corpus/gen-fixtures.sh to populate");
        return;
    }

    let baseline_path =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/corpus/coverage-baseline.toml");
    let baseline: BTreeMap<String, Floor> = toml::from_str(
        &std::fs::read_to_string(&baseline_path).expect("read coverage-baseline.toml"),
    )
    .expect("parse coverage-baseline.toml");

    let mut failures: Vec<String> = vec![];
    let mut seen: Vec<String> = vec![];

    eprintln!("\ncrate            bridged / total   pct   floor");
    eprintln!("---------------  ---------------   ---   -----");
    for path in &fixtures {
        let data = std::fs::read_to_string(path).unwrap();
        let doc: rustdoc_types::Crate = serde_json::from_str(&data).unwrap();
        let spec = jac_bridge_binder::classify(&doc);
        let cov = jac_bridge_binder::coverage(&spec);
        seen.push(cov.module.clone());

        let floor = match baseline.get(&cov.module) {
            Some(f) => f,
            None => {
                failures.push(format!(
                    "{}: no baseline entry — add one to coverage-baseline.toml",
                    cov.module
                ));
                continue;
            }
        };

        let ok = cov.bridged >= floor.bridged;
        eprintln!(
            "{:<15}  {:>5} / {:<5}   {:>3}%  >= {}  {}",
            cov.module,
            cov.bridged,
            cov.total(),
            cov.pct(),
            floor.bridged,
            if ok { "ok" } else { "REGRESSED" }
        );
        if !ok {
            failures.push(format!(
                "{}: bridged {} < floor {} — coverage regressed",
                cov.module, cov.bridged, floor.bridged
            ));
        }
        // A shrinking surface (fewer items considered) usually means the parser
        // broke or a fixture lost API; warn loudly but don't fail on version bumps.
        if cov.total() < floor.total {
            eprintln!(
                "  warn: {} total surface {} < baseline {} (fixture bump or parser change?)",
                cov.module,
                cov.total(),
                floor.total
            );
        }
    }

    // Every baseline entry should correspond to a fixture (catch stale floors).
    for crate_name in baseline.keys() {
        if !seen.contains(crate_name) {
            eprintln!("  warn: baseline has `{crate_name}` but no fixture present");
        }
    }

    assert!(failures.is_empty(), "coverage gate failed:\n  {}", failures.join("\n  "));
}
