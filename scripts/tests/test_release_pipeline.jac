"""End-to-end tests for the release pipeline scripts.

Tests the full pipeline in three stages using real fragment files from the repo:
  Stage 1 - Fragment validation (pre-commit simulation)
  Stage 2 - Release assembly on a temp copy of real files
  Stage 3 - Publish matrix generation from the PR title Stage 2 would produce

Stages share state: fragments validated in Stage 1 are the same ones
collected in Stage 2, mirroring the real pipeline flow.

Run from repo root: jac run scripts/tests/test_release_pipeline.jac
"""

import os;
import subprocess;
import sys;
import shutil;
import tempfile;
import tomlkit;
import from pathlib { Path }

glob REPO_ROOT: Path = Path.cwd(),
     SCRIPTS_DIR: str = str(Path.cwd() / "scripts"),
     UNRELEASED_DIR: Path = Path.cwd() / "docs" / "docs" / "community" / "release_notes" / "unreleased",
     _path_setup: bool = sys.path.insert(0, str(Path.cwd() / "scripts")) or True;

import from validate_fragments { validate }
import from collect_release_notes { assemble_package }
import from parse_release { parse_from_title, build_precompile_matrix }
import from release_utils { bump_version, PACKAGES }

# ── Test Runner ───────────────────────────────────────────────────────────────

obj ReleaseTestRunner {
    has passed: int = 0,
        failed: int = 0,
        errors: list[str] = [];

    def check(condition: bool, name: str, detail: str = "") {
        if condition {
            print(f"  PASS  {name}");
            self.passed += 1;
        } else {
            suffix = f" — {detail}" if detail else "";
            print(f"  FAIL  {name}{suffix}");
            self.failed += 1;
            self.errors.append(f"{name}" + (f": {detail}" if detail else ""));
        }
    }

    def summary -> int {
        print(f"\n{'=' * 60}");
        print("RELEASE PIPELINE TEST SUMMARY");
        print("=" * 60);
        print(f"  Passed : {self.passed}");
        print(f"  Failed : {self.failed}");
        if self.errors {
            print("\nFailures:");
            for e in self.errors {
                print(f"  - {e}");
            }
            return 1;
        }
        print("\nAll tests passed.");
        return 0;
    }
}

# ── Helpers ───────────────────────────────────────────────────────────────────

def get_fragment_category_counts(pkg_unreleased_dir: Path) -> dict {
    counts: dict = {};
    if not pkg_unreleased_dir.is_dir() {
        return counts;
    }
    for f in pkg_unreleased_dir.iterdir() {
        if not f.is_file() or f.name in ("README.md", ".gitkeep") {
            continue;
        }
        parts = f.stem.split(".");
        if len(parts) == 2 {
            cat = parts[1];
            counts[cat] = counts.get(cat, 0) + 1;
        }
    }
    return counts;
}

def get_current_version(pkg_key: str) -> str {
    pkg_info = PACKAGES[pkg_key];
    pyproject = REPO_ROOT / pkg_info.dir / "pyproject.toml";
    data = tomlkit.loads(pyproject.read_text());
    return str(data["project"]["version"]);
}

def make_clean_env -> dict {
    # Remove CI env vars so check-release-notes.sh uses local (git diff --cached) mode
    env = dict(os.environ);
    for key in ["CI", "PRE_COMMIT_FROM_REF", "PRE_COMMIT_TO_REF"] {
        env.pop(key, None);
    }
    return env;
}

# ── Stage 1: Fragment Validation ──────────────────────────────────────────────

def run_stage1(runner: ReleaseTestRunner) {
    print(f"\n{'─' * 60}");
    print("STAGE 1  Fragment Validation (pre-commit simulation)");
    print("─" * 60);

    # 1a: invalid filename is rejected
    bad_path = str(UNRELEASED_DIR / "jaclang" / "not-valid-name.md");
    runner.check(
        validate([bad_path]) == 1,
        "validate_fragments rejects invalid filename (not-valid-name.md)"
    );

    # 1b: unknown category is rejected
    bad_cat = str(UNRELEASED_DIR / "jaclang" / "123.hotfix.md");
    runner.check(
        validate([bad_cat]) == 1,
        "validate_fragments rejects unknown category (hotfix)"
    );

    # 1c: all real repo fragments currently pass filename validation
    real_paths: list[str] = [];
    for pkg_key in PACKAGES {
        pkg_info = PACKAGES[pkg_key];
        pkg_dir = UNRELEASED_DIR / pkg_info.notes_display;
        if pkg_dir.is_dir() {
            for f in pkg_dir.iterdir() {
                if f.is_file() and f.name not in ("README.md", ".gitkeep") {
                    real_paths.append(str(f));
                }
            }
        }
    }

    if real_paths {
        runner.check(
            validate(real_paths) == 0,
            f"all {len(real_paths)} real repo fragments pass filename validation"
        );
    } else {
        print("  SKIP  no fragments currently in unreleased dirs");
    }

    # 1d + 1e: check-release-notes.sh via subprocess against a temp git repo
    tmp = tempfile.mkdtemp(prefix="rp-s1-");
    try {
        tmp_path = Path(tmp);

        (tmp_path / "README.md").write_text("base\n");
        code_file = tmp_path / "jac" / "jaclang" / "new_feature.py";
        code_file.parent.mkdir(parents=True, exist_ok=True);
        code_file.write_text("x = 1\n");

        subprocess.run(["git", "init"], cwd=tmp, capture_output=True);
        subprocess.run(["git", "config", "user.email", "t@t.com"], cwd=tmp, capture_output=True);
        subprocess.run(["git", "config", "user.name", "T"], cwd=tmp, capture_output=True);
        subprocess.run(["git", "add", "README.md"], cwd=tmp, capture_output=True);
        subprocess.run(["git", "commit", "-m", "init"], cwd=tmp, capture_output=True);
        subprocess.run(["git", "add", "jac/jaclang/new_feature.py"], cwd=tmp, capture_output=True);

        # 1d: blocked — code changed, no fragment staged
        r = subprocess.run(
            ["bash", str(REPO_ROOT / "scripts" / "check-release-notes.sh")],
            cwd=tmp, capture_output=True, text=True,
            env=make_clean_env()
        );
        runner.check(
            r.returncode == 1,
            "check-release-notes.sh blocks code change without a fragment"
        );

        # 1e: passes — fragment is also staged
        frag_dir = tmp_path / "docs" / "docs" / "community" / "release_notes" / "unreleased" / "jaclang";
        frag_dir.mkdir(parents=True, exist_ok=True);
        frag_file = frag_dir / "999.bugfix.md";
        frag_file.write_text("- **Fix**: test fix for pipeline test\n");
        subprocess.run(["git", "add", str(frag_file)], cwd=tmp, capture_output=True);

        r2 = subprocess.run(
            ["bash", str(REPO_ROOT / "scripts" / "check-release-notes.sh")],
            cwd=tmp, capture_output=True, text=True,
            env=make_clean_env()
        );
        runner.check(
            r2.returncode == 0,
            "check-release-notes.sh passes when code change + fragment are both staged"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

# ── Stage 2: Release Assembly ─────────────────────────────────────────────────

def run_stage2(runner: ReleaseTestRunner) -> dict {
    print(f"\n{'─' * 60}");
    print("STAGE 2  Release Assembly (collect fragments → release notes)");
    print("─" * 60);

    new_versions: dict = {};

    for pkg_key in PACKAGES {
        pkg_info = PACKAGES[pkg_key];
        if not pkg_info.release_notes {
            continue;
        }

        real_unreleased = UNRELEASED_DIR / pkg_info.notes_display;
        real_notes = REPO_ROOT / pkg_info.release_notes;
        counts = get_fragment_category_counts(real_unreleased);
        total = sum(counts.values());

        if total == 0 {
            print(f"  SKIP  {pkg_key}: no fragments to collect");
            continue;
        }

        current_version = get_current_version(pkg_key);
        new_version = bump_version(current_version, "patch");
        new_versions[pkg_key] = new_version;

        print(f"\n  {pkg_key}  {current_version} → {new_version}  ({total} fragments: {counts})");

        # Copy real files to temp dir — never touch the actual repo files
        tmp = tempfile.mkdtemp(prefix=f"rp-s2-{pkg_key}-");
        try {
            tmp_path = Path(tmp);
            tmp_unreleased = tmp_path / "docs" / "docs" / "community" / "release_notes" / "unreleased" / pkg_info.notes_display;
            tmp_notes_dir = tmp_path / "docs" / "docs" / "community" / "release_notes";
            tmp_unreleased.mkdir(parents=True, exist_ok=True);
            tmp_notes_dir.mkdir(parents=True, exist_ok=True);

            for f in real_unreleased.iterdir() {
                if f.is_file() {
                    shutil.copy(f, tmp_unreleased / f.name);
                }
            }
            shutil.copy(real_notes, tmp_notes_dir / real_notes.name);

            # 2a: assemble_package returns True when fragments exist
            result = assemble_package(tmp_path, pkg_key, new_version);
            runner.check(result == True, f"{pkg_key}: assemble_package returns True");

            # 2b: new version appears in the assembled release notes
            assembled = (tmp_notes_dir / real_notes.name).read_text();
            runner.check(
                new_version in assembled,
                f"{pkg_key}: release notes contain new version {new_version}"
            );

            # 2c: correct category headings appear based on real fragment types
            if counts.get("bugfix", 0) > 0 {
                runner.check(
                    "### Bug Fixes" in assembled,
                    f"{pkg_key}: Bug Fixes section present (had {counts['bugfix']} bugfix fragments)"
                );
            }
            if counts.get("feature", 0) > 0 {
                runner.check(
                    "### New Features" in assembled,
                    f"{pkg_key}: New Features section present (had {counts['feature']} feature fragments)"
                );
            }

            # 2d: all fragment files deleted after assembly
            remaining = [
                f for f in tmp_unreleased.iterdir()
                if f.is_file() and f.name not in ("README.md", ".gitkeep")
            ];
            runner.check(
                len(remaining) == 0,
                f"{pkg_key}: all {total} fragments deleted after assembly",
                f"{len(remaining)} file(s) remain" if remaining else ""
            );

        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    }

    return new_versions;
}

# ── Stage 3: Publish Matrix ───────────────────────────────────────────────────

def run_stage3(runner: ReleaseTestRunner, new_versions: dict) {
    print(f"\n{'─' * 60}");
    print("STAGE 3  Publish Matrix Generation");
    print("─" * 60);

    if not new_versions {
        print("  SKIP  no new versions from Stage 2 (no fragments in repo)");
        return;
    }

    # Build the PR title exactly as release.py would output it
    pr_title = "release: " + ", ".join(
        [f"{pkg} {new_versions[pkg]}" for pkg in new_versions]
    );
    print(f"  PR title: {pr_title}");

    releases = parse_from_title(pr_title);

    # 3a: all packages are extracted from the PR title
    runner.check(
        len(releases) == len(new_versions),
        f"parse_from_title extracts all {len(new_versions)} package(s) from PR title"
    );

    # 3b: extracted versions match what Stage 2 computed
    for r in releases {
        pkg_name = r["name"];
        parsed_version = r["version"];
        expected = new_versions.get(pkg_name, "");
        runner.check(
            parsed_version == expected,
            f"{pkg_name}: parsed version {parsed_version} matches Stage 2 output"
        );
    }

    # 3c: releases are sorted by tier (dependency order: jaclang before plugins)
    tiers = [r["tier"] for r in releases];
    runner.check(
        tiers == sorted(tiers),
        "releases are sorted by tier for dependency-aware publishing"
    );

    # 3d: jaclang precompile matrix spans all supported python versions
    if "jaclang" in new_versions {
        jac_releases = [r for r in releases if r["name"] == "jaclang"];
        matrix = build_precompile_matrix(jac_releases);
        py_versions = [e["python_version"] for e in matrix["include"]];
        runner.check(
            "3.12" in py_versions and "3.13" in py_versions and "3.14" in py_versions,
            "jaclang precompile matrix covers python 3.12, 3.13, 3.14"
        );
    }

    # 3e: a non-release PR title produces no releases
    empty = parse_from_title("fix: some unrelated PR title");
    runner.check(
        len(empty) == 0,
        "non-release PR title returns empty list"
    );
}

# ── Entry ─────────────────────────────────────────────────────────────────────

with entry {
    print("=" * 60);
    print("RELEASE PIPELINE END-TO-END TEST");
    print("=" * 60);

    runner = ReleaseTestRunner();

    run_stage1(runner);
    new_versions = run_stage2(runner);
    run_stage3(runner, new_versions);

    sys.exit(runner.summary());
}
