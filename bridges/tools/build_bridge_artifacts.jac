"""Build publishable Rust-bridge cdylibs for the host target (M5.4 CI).

This is the CI-side counterpart to jaclang's _builder.jac local build pipeline.
It leans only on the Python standard library (reached through Jac imports) so it
runs unchanged on every runner OS (Linux/macOS/Windows). For each requested
crate it:

  1. cargo add <crate>[@ver] into a throwaway project (pins an exact version)
  2. cargo +nightly rustdoc --output-format json  (unstable, nightly-only)
  3. jac-bridge-binder <doc.json> --out <gen> --jac-bridge <rt>
  4. cargo build --release   (produces the cdylib)
  5. copy the cdylib to <out>/<crate>/<version>/<triple>/<canonical-name>
     and record {crate, version, triple, filename, sha256, relpath}

The per-artifact records are written to <out>/manifest-<triple>.json; a later
merge step (merge_registry_index.jac) folds every runner's manifest into the
single static index.json the resolver reads.

Usage:
  jac run build_bridge_artifacts.jac --workspace <bridges/> --out <dir> \
      --triple <target-triple> regex[@1.12] uuid sha2 ...
"""

import argparse;
import hashlib;
import json;
import os;
import shutil;
import sys;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._build_core {
    run_build_pipeline,
    target_triple
}


def cdylib_name(stem: str, triple: str) -> str {
    # The finder resolves lib<stem>.so / lib<stem>.dylib / <stem>.dll.
    if "windows" in triple {
        return f"{stem}.dll";
    }
    if "apple" in triple or "darwin" in triple {
        return f"lib{stem}.dylib";
    }
    return f"lib{stem}.so";
}


def built_cdylib(release_dir: Path, stem: str, triple: str) -> Path {
    for name in (
        cdylib_name(stem, triple),
        f"lib{stem}.so",
        f"{stem}.dll",
        f"lib{stem}.dylib",

    ) {
        cand = release_dir / name;
        if cand.is_file() {
            return cand;
        }
    }
    raise RuntimeError(f"no cdylib for {stem} under {release_dir}");
}


def build_one(crate: str, version: str, ws: Path, out: Path, triple: str) -> dict {
    stem = crate.replace("-", "_");
    pipeline = run_build_pipeline(crate, version, ws);
    exact = pipeline[0];
    gen = pipeline[1];
    work = pipeline[2];
    try {
        built = built_cdylib(gen / "target" / "release", f"jac_bridge_{stem}", triple);
        canonical = cdylib_name(f"jac_bridge_{stem}", triple);
        dest_dir = out / crate / exact / triple;
        dest_dir.mkdir(parents=True, exist_ok=True);
        dest = dest_dir / canonical;
        shutil.copy2(built, dest);

        digest = hashlib.sha256(dest.read_bytes()).hexdigest();
        relpath = str(Path(crate) / exact / triple / canonical).replace(os.sep, "/");
        print(f"  OK {crate} {exact} [{triple}] {digest[:12]}... -> {relpath}");
        return {
            "crate": crate,
            "version": exact,
            "triple": triple,
            "filename": canonical,
            "sha256": digest,
            "relpath": relpath,

        };
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
}


def main -> int {
    ap = argparse.ArgumentParser();
    ap.add_argument("--workspace", required=True);
    ap.add_argument("--out", required=True);
    ap.add_argument("--triple", default=None);
    ap.add_argument("specs", nargs="+", help="crate or crate@version");
    args = ap.parse_args();

    triple = str(args.triple) if args.triple else target_triple();
    ws = Path(str(args.workspace)).resolve();
    out_dir = Path(str(args.out));
    if not (ws / "jac-bridge").is_dir() {
        sys.stderr.write(
            f"error: {ws} is not the bridges workspace (no jac-bridge/)\n"
        );
        return 2;
    }
    out_dir.mkdir(parents=True, exist_ok=True);

    records = [];
    failures = [];
    for spec in args.specs {
        parts = str(spec).partition("@");
        crate = parts[0];
        version = parts[2] or "*";
        try {
            records.append(build_one(crate, version, ws, out_dir, triple));
        } except Exception as exc {
            failures.append((spec, str(exc)));
            sys.stderr.write(f"  FAIL {spec}: {exc}\n");
        }
    }

    manifest = out_dir / f"manifest-{triple}.json";
    manifest.write_text(json.dumps(records, indent=2), encoding="utf-8");
    print(f"wrote {len(records)} record(s) to {manifest}");
    if failures {
        sys.stderr.write(f"{len(failures)} crate(s) failed to build\n");
        return 1;
    }
    return 0;
}


with entry:__main__ {
    raise SystemExit(main());
}
