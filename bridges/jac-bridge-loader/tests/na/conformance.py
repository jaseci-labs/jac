#!/usr/bin/env python3
"""M3 conformance: prove the na and CPython runtimes are observationally
identical against the SAME libjac_bridge_regex.so.

CPython side: the real loader (jac_bridge_loader.load_bridge -> ctypes module).
na side:      synthesize Jac source from the same .so's metadata, nacompile it
              with an appended probe that prints one line per assertion outcome,
              run the binary, and compare the outputs.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
JAC = REPO / "jac"
LOADER = REPO / "bridges" / "jac-bridge-loader"
SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_regex.so"
SHIM = JAC / "zig-out" / "lib" / "libjacllvm.so"

CASES = [
    ("foo\\d+", "foo42", True),
    ("foo\\d+", "bar", False),
    ("^[a-z]+$", "hello", True),
    ("^[a-z]+$", "Hello", False),
    ("\\bcat\\b", "the cat sat", True),
    ("\\bcat\\b", "category", False),
]
BAD_PATTERNS = ["(unclosed", "a{", "[z-a]"]


def cpython_side() -> list[str]:
    sys.path.insert(0, str(LOADER))
    from jac_bridge_loader import load_bridge

    regex = load_bridge(str(SO))
    lines = []
    for pat, text, _ in CASES:
        re = regex.Regex(pat)
        lines.append(f"match {pat!r} {text!r} = {int(re.is_match(text))}")
        re.close()
    for pat in BAD_PATTERNS:
        try:
            regex.Regex(pat)
            lines.append(f"bad {pat!r} = NOERROR")
        except Exception as e:
            # Compare the REAL error text, not just "RAISED": the message is the
            # Rust regex crate's own (multi-line) parse error, decoded from the
            # error handle's JacBuf — the exact path the na JacBuf->str read must
            # reproduce byte-for-byte against the same .so.
            lines.append(f"bad {pat!r} = {e}")
    # Normalize multi-line messages the same way the na side does (below), so the
    # two line-lists are structurally comparable.
    return [ln for ln in "\n".join(lines).splitlines() if ln.strip()]


def _jac_str(s: str) -> str:
    # embed a Python string as a Jac double-quoted literal
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def na_side() -> list[str]:
    sys.path.insert(0, str(LOADER))
    from jac_bridge_loader._blob import parse
    from jac_bridge_loader._elf import read_jac_bridge_section
    from jac_bridge_loader._na_codegen import render_na_source

    meta = parse(read_jac_bridge_section(str(SO)))
    src = render_na_source(meta, SO.name).source

    probe = ["\nwith entry {"]
    for pat, text, _ in CASES:
        label = f"match {pat!r} {text!r} = "
        probe.append(f"    re = Regex({_jac_str(pat)});")
        probe.append(f"    if re.is_match({_jac_str(text)}) {{")
        probe.append(f"        print({_jac_str(label + '1')});")
        probe.append("    } else {")
        probe.append(f"        print({_jac_str(label + '0')});")
        probe.append("    }")
        probe.append("    re.close();")
    for pat in BAD_PATTERNS:
        label = f"bad {pat!r} = "
        # Print the decoded error text (prefix identical to the CPython side), so
        # conformance checks the JacBuf->str message bytes, not merely that it
        # raised.  str(e) on na yields the same Rust message as CPython's `{e}`.
        probe.append(
            f"    try {{ bad = Regex({_jac_str(pat)}); "
            f"print({_jac_str(label + 'NOERROR')}); }} "
            f"except Exception as e {{ print({_jac_str(label)} + str(e)); }}"
        )
    probe.append("}")
    src = src + "\n".join(probe)

    with tempfile.TemporaryDirectory() as td:
        jac_file = Path(td) / "conf.jac"
        jac_file.write_text(src)
        binp = Path(td) / "conf"
        env = dict(os.environ, JAC_LLVM_SHIM=str(SHIM), PYTHONPATH=str(JAC))
        r = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "nacompile",
                str(jac_file),
                "-o",
                str(binp),
            ],
            cwd=str(JAC),
            env=env,
            capture_output=True,
            text=True,
            timeout=600,
        )
        if not binp.exists():
            raise RuntimeError(
                "nacompile failed:\n" + r.stdout[-2000:] + r.stderr[-2000:]
            )
        run = subprocess.run(
            [str(binp)],
            capture_output=True,
            text=True,
            timeout=60,
            env=dict(os.environ, LD_LIBRARY_PATH=str(SO.parent)),
        )
        if run.returncode != 0:
            raise RuntimeError(
                f"binary exited {run.returncode}:\n{run.stdout}\n{run.stderr}"
            )
        return [ln for ln in run.stdout.splitlines() if ln.strip()]


def main() -> int:
    cpy = cpython_side()
    na = na_side()
    print("=== CPython ===")
    for ln in cpy:
        print(" ", ln)
    print("=== na ===")
    for ln in na:
        print(" ", ln)
    if cpy == na:
        print(f"\nCONFORMANCE PASS: {len(cpy)} observations identical on both runtimes")
        return 0
    print("\nCONFORMANCE FAIL: divergence")
    for i, (a, b) in enumerate(zip(cpy, na, strict=False)):
        if a != b:
            print(f"  [{i}] cpy={a!r} na={b!r}")
    if len(cpy) != len(na):
        print(f"  length mismatch: cpy={len(cpy)} na={len(na)}")
    return 1


def test_na_cpython_conformance() -> None:
    """pytest entry: skips unless the bridge .so and LLVM shim are both present.

    The na half needs a jaclang LLVM shim (JAC_LLVM_SHIM or jac/zig-out/lib);
    without it we can still run the CPython half in the unit suite, so here we
    simply skip rather than fail on machines with no native toolchain.
    """
    import pytest

    if not SO.is_file():
        pytest.skip("libjac_bridge_regex.so not built")
    if not (SHIM.is_file() or os.environ.get("JAC_LLVM_SHIM")):
        pytest.skip("no LLVM shim (JAC_LLVM_SHIM unset and jac/zig-out/lib absent)")
    assert cpython_side() == na_side()


if __name__ == "__main__":
    sys.exit(main())
