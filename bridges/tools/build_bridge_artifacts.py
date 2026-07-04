#!/usr/bin/env python3
"""Build publishable Rust-bridge cdylibs for the host target (M5.4 CI).

This is the CI-side counterpart to jaclang's _builder.jac local build pipeline.
It is intentionally free of any jaclang import so it runs unchanged on every
runner OS (Linux/macOS/Windows). For each requested crate it:

  1. cargo add <crate>[@ver] into a throwaway project (pins an exact version)
  2. cargo +nightly rustdoc --output-format json  (unstable, nightly-only)
  3. jac-bridge-binder <doc.json> --out <gen> --jac-bridge <rt>
  4. cargo build --release   (produces the cdylib)
  5. copy the cdylib to <out>/<crate>/<version>/<triple>/<canonical-name>
     and record {crate, version, triple, filename, sha256, relpath}

The per-artifact records are written to <out>/manifest-<triple>.json; a later
merge step (merge_registry_index.py) folds every runner's manifest into the
single static index.json the resolver reads.

Usage:
  build_bridge_artifacts.py --workspace <bridges/> --out <dir> \\
      --triple <target-triple> regex[@1.12] uuid sha2 ...
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def run(cmd: list, cwd: object = None) -> subprocess.CompletedProcess:
    proc = subprocess.run(
        [str(c) for c in cmd],
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"command failed (exit {proc.returncode}): {' '.join(str(c) for c in cmd)}\n"
            f"{proc.stderr.strip()}"
        )
    return proc


def host_triple() -> str:
    """Best-effort host target triple, matching the finder's _target_triple."""
    out = run(["rustc", "-vV"]).stdout
    for line in out.splitlines():
        if line.startswith("host:"):
            return line.split(":", 1)[1].strip()
    # Fallback mirrors jaclang's _finder._target_triple.
    machine = platform.machine().lower()
    arch = {"amd64": "x86_64", "arm64": "aarch64"}.get(machine, machine)
    system = platform.system()
    if system == "Linux":
        return f"{arch}-unknown-linux-gnu"
    if system == "Darwin":
        return f"{arch}-apple-darwin"
    if system == "Windows":
        return f"{arch}-pc-windows-msvc"
    return f"{arch}-unknown-{system.lower()}"


def cdylib_name(stem: str, triple: str) -> str:
    """The finder resolves lib<stem>.so / lib<stem>.dylib / <stem>.dll."""
    if "windows" in triple:
        return f"{stem}.dll"
    if "apple" in triple or "darwin" in triple:
        return f"lib{stem}.dylib"
    return f"lib{stem}.so"


def built_cdylib(release_dir: Path, stem: str, triple: str) -> Path:
    for name in (
        cdylib_name(stem, triple),
        f"lib{stem}.so",
        f"{stem}.dll",
        f"lib{stem}.dylib",
    ):
        cand = release_dir / name
        if cand.is_file():
            return cand
    raise RuntimeError(f"no cdylib for {stem} under {release_dir}")


def binder_cmd(ws: Path) -> list:
    for profile in ("release", "debug"):
        exe = ws / "target" / profile / "jac-bridge-binder"
        win = exe.with_suffix(".exe")
        if exe.is_file():
            return [exe]
        if win.is_file():
            return [win]
    return [
        "cargo",
        "run",
        "--quiet",
        "--release",
        "--manifest-path",
        ws / "Cargo.toml",
        "-p",
        "jac-bridge-binder",
        "--",
    ]


def resolved_version(proj: Path, crate: str) -> str:
    meta = json.loads(
        run(["cargo", "metadata", "--format-version", "1"], cwd=proj).stdout
    )
    for pkg in meta.get("packages", []):
        if pkg.get("name") == crate:
            return pkg["version"]
    raise RuntimeError(f"crate {crate!r} not in resolved graph")


def build_one(crate: str, version: str, ws: Path, out: Path, triple: str) -> dict:
    stem = crate.replace("-", "_")
    jac_bridge = (ws / "jac-bridge").resolve()
    work = Path(tempfile.mkdtemp(prefix="jac-bridge-ci-"))
    try:
        proj = work / "fetch"
        proj.mkdir(parents=True)
        run(["cargo", "init", "--lib", "--quiet", "--name", "bridgefetch"], cwd=proj)
        add_spec = crate if version in ("", "*") else f"{crate}@{version}"
        run(["cargo", "add", "--quiet", add_spec], cwd=proj)
        exact = resolved_version(proj, crate)

        run(
            [
                "cargo",
                "+nightly",
                "rustdoc",
                "-p",
                crate,
                "-Z",
                "unstable-options",
                "--output-format",
                "json",
                "--quiet",
            ],
            cwd=proj,
        )
        doc_json = proj / "target" / "doc" / f"{stem}.json"
        if not doc_json.is_file():
            raise RuntimeError(f"rustdoc did not produce {doc_json}")

        gen = work / "gen"
        gen.mkdir()
        run(
            binder_cmd(ws) + [doc_json, "--out", gen, "--jac-bridge", jac_bridge],
            cwd=ws,
        )
        run(
            [
                "cargo",
                "build",
                "--release",
                "--quiet",
                "--manifest-path",
                gen / "Cargo.toml",
            ],
            cwd=gen,
        )

        built = built_cdylib(gen / "target" / "release", f"jac_bridge_{stem}", triple)
        canonical = cdylib_name(f"jac_bridge_{stem}", triple)
        dest_dir = out / crate / exact / triple
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / canonical
        shutil.copy2(built, dest)

        digest = hashlib.sha256(dest.read_bytes()).hexdigest()
        relpath = str(Path(crate) / exact / triple / canonical).replace(os.sep, "/")
        print(f"  ✔ {crate} {exact} [{triple}] {digest[:12]}… -> {relpath}")
        return {
            "crate": crate,
            "version": exact,
            "triple": triple,
            "filename": canonical,
            "sha256": digest,
            "relpath": relpath,
        }
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workspace", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--triple", default=None)
    ap.add_argument("specs", nargs="+", help="crate or crate@version")
    args = ap.parse_args()

    triple = args.triple or host_triple()
    ws = args.workspace.resolve()
    if not (ws / "jac-bridge").is_dir():
        print(
            f"error: {ws} is not the bridges workspace (no jac-bridge/)",
            file=sys.stderr,
        )
        return 2
    args.out.mkdir(parents=True, exist_ok=True)

    records, failures = [], []
    for spec in args.specs:
        crate, _, version = spec.partition("@")
        version = version or "*"
        try:
            records.append(build_one(crate, version, ws, args.out, triple))
        except Exception as exc:  # noqa: BLE001 — CI wants every failure listed
            failures.append((spec, str(exc)))
            print(f"  ✗ {spec}: {exc}", file=sys.stderr)

    manifest = args.out / f"manifest-{triple}.json"
    manifest.write_text(json.dumps(records, indent=2), encoding="utf-8")
    print(f"wrote {len(records)} record(s) to {manifest}")
    if failures:
        print(f"{len(failures)} crate(s) failed to build", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
