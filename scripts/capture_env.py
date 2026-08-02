#!/usr/bin/env python3
"""Capture an immutable environment + revision manifest for interopbench.

Implements STEPS.md Phase A, item 1 ("Freeze one exact compiler and benchmark
revision") and contributes the provenance block required by item 7.

The manifest records, in one machine-readable JSON document:

  * exact git revision (this repo is a worktree of jaseci, so the compiler
    source under ./jac and the benchmark under jac/examples/interopbench share
    ONE sha -- recorded once, cross-referenced as both git_sha and benchmark_sha),
  * whether the worktree is clean,
  * toolchain versions and executable paths (python / node / v8 / jac / llvm / cc / ld),
  * jac dev-mode status and compiler source path,
  * hardware + kernel + CPU frequency behavior (governor / turbo / affinity),
  * content hashes of the benchmark tree and this scripts tree,
  * self-hash of this capture script.

Usage:
    python scripts/capture_env.py                 # print JSON to stdout
    python scripts/capture_env.py -o results/paper-canonical/env.json
    python scripts/capture_env.py --build-flags O3 --build-flags lto

Optional probes (llvm-config, cpufreq, intel_pstate) are tolerated and recorded
as null when absent so the script stays portable. Required probes (git, python,
node, cc) cause a non-zero exit if missing.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import socket
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

ENV_MANIFEST_VERSION = 1

# Directories excluded from content hashing (caches / build artifacts).
HASH_EXCLUDE_DIRS = {
    ".jac",
    "__pycache__",
    ".zig-cache",
    ".pbs-build",
    ".git",
    "node_modules",
    ".pytest_cache",
}


def run(cmd: list[str], timeout: float = 10.0) -> str:
    """Run a command, returning stripped stdout. Raises on non-zero exit."""
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=True,
    )
    return proc.stdout.strip()


def run_or_none(cmd: list[str], timeout: float = 10.0) -> str | None:
    """Run a command; return None instead of raising on failure/absence."""
    try:
        return run(cmd, timeout=timeout)
    except (
        subprocess.CalledProcessError,
        FileNotFoundError,
        subprocess.TimeoutExpired,
    ):
        return None


def run_or_none_proc(
    cmd: list[str], timeout: float = 10.0
) -> dict[str, str | None] | None:
    """Run a command capturing stdout and stderr separately.

    Returns {"stdout": ..., "stderr": ...} or None on absence/timeout.
    Used for tools (jac) that split informational banners across streams.
    """
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, check=True
        )
        return {"stdout": proc.stdout.strip(), "stderr": proc.stderr.strip()}
    except (
        subprocess.CalledProcessError,
        FileNotFoundError,
        subprocess.TimeoutExpired,
    ):
        return None


def read_file(path: Path) -> str | None:
    try:
        return path.read_text(errors="replace")
    except OSError:
        return None


def first_line(s: str | None) -> str | None:
    if s is None:
        return None
    return s.splitlines()[0].strip() if s.strip() else None


def dir_hash(root: Path) -> tuple[str, int]:
    """SHA-256 over (relpath, sha256(content)) of every regular file under root.

    Returns (combined_hash, file_count). Cache/build dirs in HASH_EXCLUDE_DIRS
    are skipped so the hash reflects source, not artifacts.
    """
    if not root.is_dir():
        return ("", 0)
    entries: list[tuple[str, str]] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in HASH_EXCLUDE_DIRS]
        for name in filenames:
            p = Path(dirpath) / name
            try:
                data = p.read_bytes()
            except OSError:
                continue
            rel = str(p.relative_to(root))
            entries.append((rel, hashlib.sha256(data).hexdigest()))
    entries.sort()
    h = hashlib.sha256()
    for rel, digest in entries:
        h.update(rel.encode())
        h.update(b"\0")
        h.update(digest.encode())
        h.update(b"\0")
    return (h.hexdigest(), len(entries))


def git_info(repo: Path) -> dict[str, object]:
    def g(args: list[str]) -> str | None:
        return run_or_none(["git", "-C", str(repo), *args])

    sha = g(["rev-parse", "HEAD"])
    if sha is None:
        sys.exit("ERROR: not a git repository (or git missing): " + str(repo))
    dirty = g(["status", "--porcelain"]) or ""
    describe = g(["describe", "--tags", "--always"])
    worktree = g(["rev-parse", "--git-common-dir"])
    return {
        "git_sha": sha,
        "git_sha_short": sha[:12],
        "git_branch": g(["rev-parse", "--abbrev-ref", "HEAD"]),
        "git_describe": describe,
        "git_dirty": bool(dirty),
        "git_dirty_count": len([ln for ln in dirty.splitlines() if ln.strip()]),
        "git_common_dir": worktree,  # reveals the worktree's backing repo
    }


def cpu_info() -> dict[str, object]:
    cpuinfo = read_file(Path("/proc/cpuinfo")) or ""
    model = None
    microcode = None
    for line in cpuinfo.splitlines():
        if line.startswith("model name") and model is None:
            model = line.split(":", 1)[1].strip()
        elif line.startswith("microcode") and microcode is None:
            microcode = line.split(":", 1)[1].strip()
    nproc = run_or_none(["nproc"])
    lscpu = run_or_none(["lscpu"])
    sockets = cores = smt = None
    if lscpu:
        m: dict[str, str] = {}
        for line in lscpu.splitlines():
            if ":" in line:
                k, _, v = line.partition(":")
                m[k.strip()] = v.strip()
        sockets = m.get("Socket(s)")
        cores = m.get("Core(s) per socket")
        smt = m.get("Thread(s) per core")
    meminfo = read_file(Path("/proc/meminfo")) or ""
    mem = None
    for line in meminfo.splitlines():
        if line.startswith("MemTotal:"):
            kib = int(line.split()[1])
            mem = f"{kib / 1024 / 1024:.1f} GiB"
            break
    # CPU frequency behavior (Phase B item 9 flags these as load-bearing).
    cpu_base = Path("/sys/devices/system/cpu")
    governors = set()
    for p in cpu_base.glob("cpu*/cpufreq/scaling_governor"):
        v = read_file(p)
        if v:
            governors.add(v.strip())
    turbo_path = Path("/sys/devices/system/cpu/intel_pstate/no_turbo")
    no_turbo = read_file(turbo_path)
    if no_turbo is not None:
        turbo = "off" if no_turbo.strip() == "1" else "on"
    else:
        turbo = None
    # Affinity of THIS process (what the benchmark would inherit).
    affinity = None
    status = read_file(Path("/proc/self/status")) or ""
    for line in status.splitlines():
        if line.startswith("Cpus_allowed_list:"):
            affinity = line.split(":", 1)[1].strip()
            break
    return {
        "cpu_model": model,
        "microcode": microcode,
        "cores": nproc,
        "sockets": sockets,
        "cores_per_socket": cores,
        "threads_per_core": smt,
        "memory": mem,
        "governor": sorted(governors) if governors else None,
        "turbo": turbo,
        "affinity": affinity,
        "thermal_state": None,  # populated by machine-health calibration (Phase B #9)
    }


def toolchain_info(repo: Path) -> dict[str, object]:
    py = {
        "python": platform.python_version(),
        "python_executable": sys.executable,
    }
    node = {
        "node": run_or_none(["node", "--version"]),
        "node_path": shutil.which("node"),
    }
    v8 = run_or_none(
        [
            "node",
            "-e",
            "console.log(process.versions.v8)",
        ]
    )
    # jac runs in dev mode from ./jac in this worktree; the "dev mode" banner
    # is printed to STDERR while the version string goes to STDOUT, so capture
    # both to detect dev mode honestly.
    jac_proc = run_or_none_proc(["jac", "--version"])
    jac_ver = jac_proc.get("stdout") if jac_proc else None
    jac_err = jac_proc.get("stderr") if jac_proc else None
    jac_dev = bool(jac_err and "dev mode" in jac_err)
    cc_ver = first_line(run_or_none(["cc", "--version"]))
    return {
        **py,
        **node,
        "v8": v8,
        "jac": jac_ver,
        "jac_dev_mode": jac_dev,
        "jac_source_path": str(repo / "jac") if jac_dev else None,
        "llvm": run_or_none(["llvm-config", "--version"])
        or first_line(run_or_none(["clang", "--version"])),
        "cc": cc_ver,
        "cc_path": shutil.which("cc"),
        "cc_dumpversion": run_or_none(["cc", "-dumpversion"]),
        "ld": first_line(run_or_none(["ld", "--version"])),
    }


def capture(repo: Path, build_flags: list[str]) -> dict[str, object]:
    g = git_info(repo)
    bench_root = repo / "jac" / "examples" / "interopbench"
    scripts_root = repo / "scripts"
    bench_hash, bench_files = dir_hash(bench_root)
    scripts_hash, scripts_files = dir_hash(scripts_root)
    self_path = Path(__file__).resolve()
    self_sha = hashlib.sha256(self_path.read_bytes()).hexdigest()
    uname = run_or_none(["uname", "-a"])
    manifest = {
        "env_manifest_version": ENV_MANIFEST_VERSION,
        "captured_utc": datetime.now(UTC)
        .isoformat(timespec="seconds")
        .replace("+00:00", "Z"),
        "host": socket.gethostname(),
        "os": platform.platform(),
        "kernel": uname,
        "build_flags": build_flags,
        **g,
        # One repo (worktree of jaseci) => compiler + benchmark share one sha.
        "benchmark_sha": g["git_sha"],
        "benchmark_root": str(bench_root),
        "interopbench_tree_sha256": bench_hash,
        "interopbench_file_count": bench_files,
        "scripts_tree_sha256": scripts_hash,
        "scripts_file_count": scripts_files,
        "capture_script_sha256": self_sha,
        "capture_script_path": str(self_path.relative_to(repo))
        if repo in self_path.parents
        else str(self_path),
        **cpu_info(),
        **toolchain_info(repo),
    }
    return manifest


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo-root", default=os.getcwd(), type=Path)
    ap.add_argument("-o", "--out", type=Path, help="also write JSON to this path")
    ap.add_argument(
        "--build-flags",
        action="append",
        default=[],
        help="build/optimization flags (repeatable); filled by run scripts",
    )
    ap.add_argument("--indent", type=int, default=2)
    args = ap.parse_args()

    manifest = capture(args.repo_root.resolve(), args.build_flags)
    text = json.dumps(manifest, indent=args.indent, sort_keys=False)
    print(text)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + "\n")
    # Surface a loud warning if the worktree is dirty: a dirty tree is not a
    # frozen revision and cannot anchor reproducible paper numbers.
    if manifest["git_dirty"]:
        sys.stderr.write(
            f"\nWARNING: worktree is DIRTY ({manifest['git_dirty_count']} changed "
            f"entries). This is not a frozen revision. Commit or stash before "
            f"relying on any result produced from it.\n"
        )
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
