#!/usr/bin/env bash
# Ensure compiler/runtime shard directories cover all test files (no omissions).
# Shard layout is defined in scripts/ci/ci-coverage.yml (compiler_shards, runtime_shards).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${ROOT}/scripts/ci/ci-coverage.yml"

python3 - "$ROOT" "$MANIFEST" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required")

root = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
manifest = yaml.safe_load(manifest_path.read_text())
jac = root / "jac"


def resolve(rel: str) -> Path:
    return jac / rel


def test_files(base: Path) -> set[Path]:
    if not base.exists():
        return set()
    return {
        p
        for p in base.rglob("test_*.jac")
        if "fixtures" not in p.parts
    }


def collect_shard_files(cfg: dict) -> set[Path]:
    found: set[Path] = set()
    for rel in cfg.get("paths", []):
        found |= test_files(resolve(rel))
    for rel in cfg.get("ignore", []):
        ignore_path = resolve(rel)
        found = {
            p
            for p in found
            if ignore_path not in p.parents and p.parent != ignore_path
        }
    for rel in cfg.get("ignore_cli_docs", []):
        found.discard(resolve(rel))
    return found


compiler_shards = manifest.get("compiler_shards", {})
runtime_shards = manifest.get("runtime_shards", {})

if not compiler_shards:
    raise SystemExit("::error::compiler_shards missing from ci-coverage.yml")
if not runtime_shards:
    raise SystemExit("::error::runtime_shards missing from ci-coverage.yml")

compiler_all: set[Path] = set()
for cfg in compiler_shards.values():
    for rel in cfg.get("paths", []):
        compiler_all |= test_files(resolve(rel))

compiler_covered: set[Path] = set()
for name, cfg in compiler_shards.items():
    shard_files = collect_shard_files(cfg)
    overlap = compiler_covered & shard_files
    if overlap:
        sample = sorted(overlap)[:3]
        raise SystemExit(
            f"::error::Compiler shard {name} overlaps prior shards, e.g. {sample}"
        )
    compiler_covered |= shard_files

# Canonical runtime universe: every test_*.jac under jac/tests/, derived from
# the repository root rather than from the shard paths themselves. A new
# top-level suite that no runtime shard lists appears here and is reported
# missing, instead of being silently invisible (the old self-derived universe
# could not detect it because it was built from those same shard paths).
canonical_runtime = test_files(jac / "tests")

# Files owned by non-runtime jobs: the compiler shards (tests/compiler/** and
# jaclang/compiler/tests/**) plus the client/docs subtrees the runtime shards
# explicitly decline via their `ignore` / `ignore_cli_docs`.
non_runtime: set[Path] = set(compiler_all)
for cfg in runtime_shards.values():
    for rel in cfg.get("ignore", []):
        non_runtime |= test_files(resolve(rel))
    for rel in cfg.get("ignore_cli_docs", []):
        non_runtime.add(resolve(rel))

expected_runtime = canonical_runtime - non_runtime

runtime_covered: set[Path] = set()
for name, cfg in runtime_shards.items():
    shard_files = collect_shard_files(cfg)
    overlap = runtime_covered & shard_files
    if overlap:
        sample = sorted(overlap)[:3]
        raise SystemExit(
            f"::error::Runtime shard {name} overlaps prior shards, e.g. {sample}"
        )
    runtime_covered |= shard_files

errors = []
if compiler_all != compiler_covered:
    missing = sorted(compiler_all - compiler_covered)
    extra = sorted(compiler_covered - compiler_all)
    if missing:
        errors.append(f"Compiler shard missing {len(missing)} tests, e.g. {missing[:3]}")
    if extra:
        errors.append(f"Compiler shard extra {len(extra)} tests, e.g. {extra[:3]}")

if expected_runtime != runtime_covered:
    missing = sorted(expected_runtime - runtime_covered)
    extra = sorted(runtime_covered - expected_runtime)
    if missing:
        errors.append(
            f"Runtime shard missing {len(missing)} test(s) under jac/tests/, "
            f"e.g. {missing[:3]} -- add the suite to runtime_shards"
        )
    if extra:
        errors.append(
            f"Runtime shard covers tests outside its declared universe: {extra[:3]}"
        )

print(f"Compiler inventory: {len(compiler_all)} test files across {len(compiler_shards)} shards")
print(
    f"Runtime inventory (jac/tests, excl. compiler/client/docs): "
    f"{len(expected_runtime)} test files across {len(runtime_shards)} shards"
)

if errors:
    for e in errors:
        print(f"::error::{e}")
    raise SystemExit(1)

print("Shard inventory complete.")
PY
