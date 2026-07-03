#!/usr/bin/env python3
"""Owning-wrapper conformance: prove the na and CPython runtimes are
observationally identical for the nullable Option<Ref> surface, against the
SAME libjac_bridge_owning.so.

This is the sibling of ``conformance.py`` (which covers the plain regex bridge).
It exercises the by-handle owning wrappers that na realizes via an adopt-ctor +
``T | None`` union return:

  * Regex.find     -> Option<OwnedMatch>   (handle with as_str(), or None)
  * Regex.captures -> Option<OwnedCaptures>(handle, or None)

``OwnedCaptures.name`` is Option<Str>, now bridged on na: str|None nullability
(narrow + concat) is verified natively, so the na side reads a named group and a
null JacBuf.ptr crosses in-band as Jac ``None`` — kept DISTINCT from a present but
empty ("") group.  Everything asserted here is read identically on both runtimes:
a match yields a live wrapper (find -> its text), a non-match yields Jac ``None``,
an empty (zero-width) match is a real handle whose text is "" (distinct from None),
and ``name(group)`` returns the group text, ``""`` for a zero-width group, or
``None`` for an absent / non-existent group.

``OwnedCaptures.name_match`` is the NESTED owning-wrapper case: a reader on one
wrapper (Captures) produces ANOTHER (Match), Option<OwnedMatch>.  It carries the
same text/""/None outcomes as ``name`` but routed through an ``OwnedMatch`` handle
(``name_match(group).as_str()``) instead of a raw string, proving a
wrapper-producing-wrapper round-trips identically on both runtimes — and, on na,
that the child match's adopt-ctor resolves because the synthesizer emits
``OwnedMatch`` before the ``OwnedCaptures`` that produces it (dependency order).

na side: synthesize Jac source from the .so's metadata, nacompile it with an
appended probe that prints one line per observation, run the binary, diff the
output against the CPython loader.  Gated on the LLVM shim; skips without it.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path("/home/jac/repos/rust-ffi")
JAC = REPO / "jac"
LOADER = REPO / "bridges" / "jac-bridge-loader"
SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_owning.so"
SHIM = JAC / "zig-out" / "lib" / "libjacllvm.so"

# (pattern, haystack) -> find() text or None; brackets make "" vs None visible.
FIND_CASES = [
    (r"\d+", "abc123def"),  # match -> "123"
    (r"\d+", "no digits"),  # no match -> None
    (r"", "anything"),  # empty (zero-width) match -> "" (a real handle)
    (r"\w+", "hello world"),  # match -> "hello"
]
# (pattern, haystack, group) -> captures().name(group): text / "" / None.
# Brackets make "" (a present zero-width group) visible and distinct from None.
CAPS_CASES = [
    (r"(?P<num>\d+)-(?P<rest>\d+)", "nothing here", "num"),  # no match -> caps None
    (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "num"),  # -> "12"
    (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "nope"),  # no such group -> None
    (r"(?P<a>x)?(?P<b>y)", "y", "a"),  # optional group didn't match -> None
    (r"(?P<z>\d*)", "abc", "z"),  # zero-width group present -> "" (not None)
]
# (pattern, haystack, group) -> captures().name_match(group).as_str(): the NESTED
# wrapper path (a Captures produces a Match).  Same text/""/None outcomes as the
# name() path, but routed through an OwnedMatch handle, so it proves a
# wrapper-producing-wrapper round-trips identically on both runtimes.
NAME_MATCH_CASES = [
    (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "num"),  # present group -> "12"
    (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "nope"),  # no such group -> None
    (r"(?P<a>x)?(?P<b>y)", "y", "a"),  # optional group didn't match -> None
    (r"(?P<num>\d+)", "nothing here", "num"),  # no match at all -> caps None
    (r"(?P<z>\d*)", "abc", "z"),  # zero-width group present -> "" (a real handle)
]


def _find_label(pat: str, text: str) -> str:
    return f"find {pat!r} {text!r} = "


def _caps_label(pat: str, text: str, group: str) -> str:
    return f"caps {pat!r} {text!r} name({group!r}) = "


def _nm_label(pat: str, text: str, group: str) -> str:
    return f"nmatch {pat!r} {text!r} name_match({group!r}) = "


def cpython_side() -> list[str]:
    sys.path.insert(0, str(LOADER))
    from jac_bridge_loader import load_bridge

    owning = load_bridge(str(SO))
    lines: list[str] = []
    for pat, text in FIND_CASES:
        re = owning.Regex(pat)
        m = re.find(text)
        if m is None:
            lines.append(_find_label(pat, text) + "None")
        else:
            lines.append(_find_label(pat, text) + "[" + m.as_str() + "]")
            m.close()
        re.close()
    for pat, text, group in CAPS_CASES:
        label = _caps_label(pat, text, group)
        re = owning.Regex(pat)
        c = re.captures(text)
        if c is None:
            lines.append(label + "caps=None")
        else:
            v = c.name(group)
            if v is None:
                lines.append(label + "None")
            else:
                lines.append(label + "[" + v + "]")
            c.close()
        re.close()
    for pat, text, group in NAME_MATCH_CASES:
        label = _nm_label(pat, text, group)
        re = owning.Regex(pat)
        c = re.captures(text)
        if c is None:
            lines.append(label + "caps=None")
        else:
            mm = c.name_match(group)
            if mm is None:
                lines.append(label + "None")
            else:
                lines.append(label + "[" + mm.as_str() + "]")
                mm.close()
            c.close()
        re.close()
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
    for pat, text in FIND_CASES:
        label = _find_label(pat, text)
        probe.append(f"    re = Regex({_jac_str(pat)});")
        probe.append(f"    m = re.find({_jac_str(text)});")
        probe.append("    if m is not None {")
        # na dispatches a reader method only on a plain-typed receiver: `is not
        # None` narrows the value but not enough to call `m.as_str()` directly on
        # the `OwnedMatch | None` local (that call is silently dropped).  Rebinding
        # to an explicitly-typed local fixes dispatch.  Output parity with the
        # CPython side (which calls `m.as_str()` directly) still holds — this is a
        # caller-ergonomics caveat, not an observable divergence.
        probe.append("        om: OwnedMatch = m;")
        # label + "[" + <text> + "]" — assembled the same way CPython does above.
        probe.append(
            f"        print({_jac_str(label + '[')} + om.as_str() + {_jac_str(']')});"
        )
        probe.append("        om.close();")
        probe.append("    } else {")
        probe.append(f"        print({_jac_str(label + 'None')});")
        probe.append("    }")
        probe.append("    re.close();")
    for pat, text, group in CAPS_CASES:
        label = _caps_label(pat, text, group)
        probe.append(f"    re = Regex({_jac_str(pat)});")
        probe.append(f"    c = re.captures({_jac_str(text)});")
        probe.append("    if c is not None {")
        # Same union-receiver caveat as find above: rebind the `OwnedCaptures | None`
        # local to a plain-typed local before dispatching name().  name() returns
        # `str | None`; a null JacBuf.ptr (absent/non-existent group) narrows to
        # None, a non-null buffer decodes to its text (possibly "").
        probe.append("        oc: OwnedCaptures = c;")
        probe.append(f"        n = oc.name({_jac_str(group)});")
        probe.append("        if n is not None {")
        probe.append(
            f"            print({_jac_str(label + '[')} + n + {_jac_str(']')});"
        )
        probe.append("        } else {")
        probe.append(f"            print({_jac_str(label + 'None')});")
        probe.append("        }")
        probe.append("        oc.close();")
        probe.append("    } else {")
        probe.append(f"        print({_jac_str(label + 'caps=None')});")
        probe.append("    }")
        probe.append("    re.close();")
    for pat, text, group in NAME_MATCH_CASES:
        label = _nm_label(pat, text, group)
        probe.append(f"    re = Regex({_jac_str(pat)});")
        probe.append(f"    c = re.captures({_jac_str(text)});")
        probe.append("    if c is not None {")
        # Nested wrapper: rebind the OwnedCaptures|None local to dispatch name_match,
        # which itself returns OwnedMatch|None; rebind THAT before dispatching as_str
        # (same union-receiver caveat, applied one level deeper).
        probe.append("        oc: OwnedCaptures = c;")
        probe.append(f"        mm = oc.name_match({_jac_str(group)});")
        probe.append("        if mm is not None {")
        probe.append("            om2: OwnedMatch = mm;")
        probe.append(
            f"            print({_jac_str(label + '[')} + om2.as_str() + {_jac_str(']')});"
        )
        probe.append("            om2.close();")
        probe.append("        } else {")
        probe.append(f"            print({_jac_str(label + 'None')});")
        probe.append("        }")
        probe.append("        oc.close();")
        probe.append("    } else {")
        probe.append(f"        print({_jac_str(label + 'caps=None')});")
        probe.append("    }")
        probe.append("    re.close();")
    probe.append("}")
    src = src + "\n".join(probe)

    with tempfile.TemporaryDirectory() as td:
        jac_file = Path(td) / "owning_conf.jac"
        jac_file.write_text(src)
        binp = Path(td) / "owning_conf"
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


def test_owning_na_cpython_conformance() -> None:
    """pytest entry: skips unless the owning bridge .so and LLVM shim are present.

    The na half needs a jaclang LLVM shim (JAC_LLVM_SHIM or jac/zig-out/lib);
    without it we skip rather than fail on machines with no native toolchain.
    """
    import pytest

    if not SO.is_file():
        pytest.skip("libjac_bridge_owning.so not built")
    if not (SHIM.is_file() or os.environ.get("JAC_LLVM_SHIM")):
        pytest.skip("no LLVM shim (JAC_LLVM_SHIM unset and jac/zig-out/lib absent)")
    assert cpython_side() == na_side()


if __name__ == "__main__":
    sys.exit(main())
