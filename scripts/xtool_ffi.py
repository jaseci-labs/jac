#!/usr/bin/env python3
"""Committed cross-tool FFI producer for JacInteropBench (Section sec:xtool).

Answers STEPS.md #39 ("make cross-tool FFI comparisons truly matched") and the
"more kernels" scope expansion in the Related Work / Conclusion. Every binding
is built from ONE C translation unit (ib_fixture.o) bound five ways -- ctypes /
cffi dlopen a .so built from it; the C-extension and pybind11 LINK that object;
PyO3 static-links its archive through `extern "C"`. All five therefore run the
byte-identical foreign machine code of ib_sqrt / ib_dot / ib_fnv1a, and every
kernel uses the SAME signature across toolchains -- the struct kernel passes two
Vec3 BY VALUE in all five, not a scalar the callee re-expands (interop-bench#1).
Only the boundary marshalling differs, which is exactly what tab:xtool measures.

What it does, for each KERNEL (sqrt / struct-by-value / bytes-digest) x each
TOOLCHAIN (ctypes, cffi ABI, C-extension, pybind11, PyO3/Rust):

  * MATCHED  -- per-foreign-call cost under the kernel's exact loop, warmed and
                digest-verified (the honest end-to-end number a user pays).
  * ISOLATED -- the boundary alone: a tight call loop minus an empty loop, so
                CPython interpreter dispatch is differenced out and only the
                call transition + argument conversion remains.

Plus each side's no-FFI arithmetic floor (pure Python) so "overhead above the
matching no-FFI reference" (STEPS #39) is reportable.

All variants recompute one byte-identical digest per kernel; the run ABORTS if
any toolchain disagrees -- the cross-toolchain oracle is load-bearing, not
decorative. Missing toolchains (no compiler, no pybind11, no cargo) are recorded
as skipped with a reason rather than silently dropped.

Jac's own native FFI kernels (iop_ffi_scalar sqrt, iop_ffi_struct struct-by-
value, iop_ffi_bytes FNV-1a over a byte buffer) are measured via `jac run` and
pulled in with --jac-na as ANCHORS beside the Python toolchains, one per
signature shape (scalar / struct-by-value / bytes-pointer). They are a separate
workload/digest, reported but NOT folded into the cross-toolchain digest oracle.

Usage:
    python3 scripts/xtool_ffi.py --reps 5 --matched-n 2000 --isolated-n 2000000 \
        --out results/controlled/xtool_ffi.json
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import shutil
import statistics
import subprocess
import sys
import sysconfig
import tempfile
import time
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "jac" / "examples" / "interopbench"

# ---------------------------------------------------------------------------
# Kernel definitions. Each kernel is one C function signature plus the exact
# host loop that consumes it. The Python "ref" is the identical arithmetic with
# no foreign call, so overhead-above-floor is well defined. digest() must agree
# across every toolchain AND the ref.
# ---------------------------------------------------------------------------

# The C fixture is ONE translation unit compiled ONCE (to ib_fixture.o) and then
# bound five ways: ctypes/cffi dlopen a .so built from that object; the raw
# C-extension and pybind11 LINK that same object; PyO3 links a static archive of
# it and calls it through `extern "C"`. Every toolchain therefore executes the
# byte-identical machine code of ib_sqrt / ib_dot / ib_fnv1a -- the only thing
# that differs per toolchain is the argument marshalling at the boundary, which
# is exactly what tab:xtool measures. The public header (extern "C" so C++/pybind
# links cleanly) is the single source of the Vec3 type and the three prototypes.
C_HEADER = r"""
#ifndef IB_FIXTURE_H
#define IB_FIXTURE_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct { double x, y, z; } Vec3;
long ib_sqrt(double x);
double ib_dot(Vec3 a, Vec3 b);
uint64_t ib_fnv1a(const uint8_t *p, size_t n);
#ifdef __cplusplus
}
#endif
#endif
"""

C_FIXTURE = r"""
#include "ib_fixture.h"
#include <math.h>

/* sqrt kernel: integer sqrt of a perfect square -> exact i. */
long ib_sqrt(double x) { return (long)sqrt(x); }

/* struct-by-value kernel: dot product of two 3-vectors passed BY VALUE.
   Exercises the register-vs-byval ABI distinction the paper calls out. */
double ib_dot(Vec3 a, Vec3 b) { return a.x*b.x + a.y*b.y + a.z*b.z; }

/* bytes kernel: FNV-1a over a small buffer passed by pointer+length.
   Exercises pointer/length marshalling (the string/bytes seam). */
uint64_t ib_fnv1a(const uint8_t *p, size_t n) {
    uint64_t h = 1469598103934665603ULL;
    for (size_t i = 0; i < n; i++) { h ^= p[i]; h *= 1099511628211ULL; }
    return h;
}
"""

MATCHED_N_DEFAULT = 2000
ISOLATED_N_DEFAULT = 2_000_000
BUF_LEN = 16  # fnv1a buffer length per call


def sqrt_ref(n: int) -> int:
    acc = 0
    for i in range(1, n + 1):
        acc += int(math.sqrt(float(i * i)))
    return acc


def struct_ref(n: int) -> int:
    acc = 0
    for i in range(1, n + 1):
        # dot({i,i,i},{i,i,i}) = 3*i*i, exact in double for our range
        acc += int(3.0 * float(i) * float(i))
    return acc


def bytes_ref(n: int) -> int:
    acc = 0
    for i in range(1, n + 1):
        buf = (i & 0xFF).to_bytes(1, "little") * BUF_LEN
        h = 1469598103934665603
        for b in buf:
            h ^= b
            h = (h * 1099511628211) & 0xFFFFFFFFFFFFFFFF
        acc = (acc ^ h) & 0xFFFFFFFFFFFFFFFF
    return acc


KERNELS = {
    "sqrt": {"digest_prefix": "sqrt", "ref": sqrt_ref},
    "struct": {"digest_prefix": "struct", "ref": struct_ref},
    "bytes": {"digest_prefix": "bytes", "ref": bytes_ref},
}


def digest(kernel: str, value: int) -> str:
    return f"{KERNELS[kernel]['digest_prefix']}:{value}"


# ---------------------------------------------------------------------------
# Timing helper: median-of-reps per-call ns.
# ---------------------------------------------------------------------------
def time_loop(fn: Callable[[], object], reps: int) -> float:
    """Return median wall-ns of fn() across reps (fn does its own iteration)."""
    samples = []
    for _ in range(reps):
        t0 = time.perf_counter_ns()
        fn()
        samples.append(time.perf_counter_ns() - t0)
    return statistics.median(samples)


# ---------------------------------------------------------------------------
# Toolchain builders. Each returns a dict of callables:
#   sqrt(x)->long, dot_call(i)->float, fnv(buf)->int   (raw single calls)
# plus we build the matched loops in Python around them. Returns None + reason
# if the toolchain can't be built here.
# ---------------------------------------------------------------------------
_FIXTURE_CACHE: dict | None = None


def _compile_fixture(workdir: Path) -> dict | None:
    """Compile C_FIXTURE ONCE into shared artifacts reused by every toolchain.

    Returns {"o": ib_fixture.o, "so": libibfixture.so, "a": libibfixture.a,
    "inc": <dir with ib_fixture.h>} or None if gcc/ar are unavailable. The .o is
    the single translation unit; the .so (ctypes/cffi), the .o directly
    (C-ext/pybind11) and the .a (PyO3) all wrap that same object so the foreign
    machine code is byte-identical across toolchains.
    """
    global _FIXTURE_CACHE
    if _FIXTURE_CACHE is not None:
        return _FIXTURE_CACHE
    if not shutil.which("gcc") or not shutil.which("ar"):
        return None
    (workdir / "ib_fixture.h").write_text(C_HEADER)
    src = workdir / "ib_fixture.c"
    src.write_text(C_FIXTURE)
    obj = workdir / "ib_fixture.o"
    # one compile -> one object file, the single TU every binding shares
    p = subprocess.run(
        ["gcc", "-O2", "-fPIC", f"-I{workdir}", "-c", str(src), "-o", str(obj)],
        capture_output=True,
    )
    if p.returncode != 0:
        return None
    so = workdir / "libibfixture.so"
    p = subprocess.run(
        ["gcc", "-shared", str(obj), "-o", str(so), "-lm"], capture_output=True
    )
    if p.returncode != 0:
        return None
    ar = workdir / "libibfixture.a"
    p = subprocess.run(["ar", "rcs", str(ar), str(obj)], capture_output=True)
    if p.returncode != 0:
        return None
    _FIXTURE_CACHE = {"o": obj, "so": so, "a": ar, "inc": workdir}
    return _FIXTURE_CACHE


def _compile_shared(workdir: Path) -> Path | None:
    """Back-compat shim: the shared lib built from the single shared TU."""
    fx = _compile_fixture(workdir)
    return fx["so"] if fx else None


def build_ctypes(workdir: Path) -> tuple[dict | None, str | None]:
    import ctypes

    so = _compile_shared(workdir)
    if so is None:
        return None, "gcc missing or C fixture failed to compile"
    lib = ctypes.CDLL(str(so))
    lib.ib_sqrt.restype = ctypes.c_long
    lib.ib_sqrt.argtypes = [ctypes.c_double]

    class Vec3(ctypes.Structure):
        _fields_ = [
            ("x", ctypes.c_double),
            ("y", ctypes.c_double),
            ("z", ctypes.c_double),
        ]

    lib.ib_dot.restype = ctypes.c_double
    lib.ib_dot.argtypes = [Vec3, Vec3]
    lib.ib_fnv1a.restype = ctypes.c_uint64
    lib.ib_fnv1a.argtypes = [ctypes.c_char_p, ctypes.c_size_t]

    def dot_call(a: tuple, b: tuple) -> float:
        # genuine struct-by-value: two Vec3 marshalled and passed by value
        return lib.ib_dot(Vec3(*a), Vec3(*b))

    return {
        "sqrt": lib.ib_sqrt,
        "dot": dot_call,
        "fnv": lambda buf: lib.ib_fnv1a(buf, len(buf)),
    }, None


def build_cffi(workdir: Path) -> tuple[dict | None, str | None]:
    try:
        import cffi
    except ImportError:
        return None, "cffi not importable"
    so = _compile_shared(workdir)
    if so is None:
        return None, "gcc missing or C fixture failed to compile"
    ffi = cffi.FFI()
    ffi.cdef(
        "long ib_sqrt(double);"
        "typedef struct { double x, y, z; } Vec3;"
        "double ib_dot(Vec3 a, Vec3 b);"
        "uint64_t ib_fnv1a(const uint8_t *p, size_t n);"
    )
    lib = ffi.dlopen(str(so))

    def dot_call(a: tuple, b: tuple) -> float:
        va = ffi.new("Vec3 *", list(a))[0]
        vb = ffi.new("Vec3 *", list(b))[0]
        return lib.ib_dot(va, vb)

    def fnv(buf: bytes) -> int:
        return lib.ib_fnv1a(buf, len(buf))

    return {"sqrt": lib.ib_sqrt, "dot": dot_call, "fnv": fnv}, None


C_EXT_SOURCE = r"""
#include <Python.h>
#include "ib_fixture.h"   /* real ib_sqrt / ib_dot / ib_fnv1a, linked from ib_fixture.o */

static PyObject* m_sqrt(PyObject* self, PyObject* a) {
    return PyLong_FromLong(ib_sqrt(PyFloat_AsDouble(a)));
}
/* struct-by-value: marshal two Python 3-sequences into two Vec3 and pass both
   BY VALUE into the shared ib_dot. Same foreign function as ctypes/cffi. */
static PyObject* m_dot(PyObject* self, PyObject* args) {
    Vec3 a, b;
    if (!PyArg_ParseTuple(args, "(ddd)(ddd)",
                          &a.x, &a.y, &a.z, &b.x, &b.y, &b.z)) return NULL;
    return PyFloat_FromDouble(ib_dot(a, b));
}
static PyObject* m_fnv(PyObject* self, PyObject* a) {
    Py_buffer view;
    if (PyObject_GetBuffer(a, &view, PyBUF_SIMPLE) != 0) return NULL;
    uint64_t h = ib_fnv1a((const uint8_t*)view.buf, (size_t)view.len);
    PyBuffer_Release(&view);
    return PyLong_FromUnsignedLongLong(h);
}
static PyObject* m_noop(PyObject* self, PyObject* a) { Py_RETURN_NONE; }
static PyMethodDef Methods[] = {
    {"sqrt", m_sqrt, METH_O, ""}, {"dot", m_dot, METH_VARARGS, ""},
    {"fnv", m_fnv, METH_O, ""}, {"noop", m_noop, METH_O, ""},
    {NULL, NULL, 0, NULL}
};
static struct PyModuleDef mod = {PyModuleDef_HEAD_INIT, "ib_cext", "", -1, Methods};
PyMODINIT_FUNC PyInit_ib_cext(void) { return PyModule_Create(&mod); }
"""


def _build_ext_module(
    workdir: Path,
    name: str,
    source: str,
    extra: list[str],
    lang_cpp: bool = False,
    link: list[str] | None = None,
) -> tuple[object | None, str | None]:
    """Compile a Python C/C++ extension module and import it. Returns module.

    ``extra`` are pre-source flags (includes, std); ``link`` are post-source
    inputs (the shared ib_fixture.o object and -lm) so the linker resolves the
    fixture symbols the extension calls.
    """
    cc = sysconfig.get_config_var("CC") or ("g++" if lang_cpp else "gcc")
    if lang_cpp:
        cc = shutil.which("g++") or "g++"
    inc = sysconfig.get_path("include")
    src = workdir / f"{name}.c" if not lang_cpp else workdir / f"{name}.cpp"
    src.write_text(source)
    so = workdir / f"{name}.so"
    cmd = [cc, "-O2", "-fPIC", "-shared", f"-I{inc}", *extra, str(src), "-o", str(so)]
    cmd += list(link or [])
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        return None, f"compile failed: {p.stderr.strip().splitlines()[-1:]}"
    spec = importlib.util.spec_from_file_location(name, so)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod, None


def build_cext(workdir: Path) -> tuple[dict | None, str | None]:
    if not shutil.which("gcc"):
        return None, "gcc missing"
    fx = _compile_fixture(workdir)
    if fx is None:
        return None, "shared C fixture failed to compile"
    mod, err = _build_ext_module(
        workdir, "ib_cext", C_EXT_SOURCE, [f"-I{fx['inc']}"], link=[str(fx["o"]), "-lm"]
    )
    if mod is None:
        return None, err
    return {
        "sqrt": mod.sqrt,
        "dot": mod.dot,
        "fnv": mod.fnv,
        "noop": mod.noop,
    }, None


PYBIND_SOURCE = r"""
#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <array>
#include "ib_fixture.h"   /* real ib_sqrt / ib_dot / ib_fnv1a (extern "C") */
namespace py = pybind11;
static long b_sqrt(double x) { return ib_sqrt(x); }
/* struct-by-value: two Python 3-sequences -> two Vec3 -> shared ib_dot. */
static double b_dot(std::array<double,3> a, std::array<double,3> b) {
    Vec3 va{ a[0], a[1], a[2] }, vb{ b[0], b[1], b[2] };
    return ib_dot(va, vb);
}
static uint64_t b_fnv(py::buffer b) {
    py::buffer_info info = b.request();
    return ib_fnv1a((const uint8_t*)info.ptr, (size_t)info.size);
}
PYBIND11_MODULE(ib_pybind, m) {
    m.def("sqrt", &b_sqrt); m.def("dot", &b_dot); m.def("fnv", &b_fnv);
}
"""


def build_pybind(workdir: Path) -> tuple[dict | None, str | None]:
    try:
        import pybind11
    except ImportError:
        return None, "pybind11 not importable"
    if not shutil.which("g++"):
        return None, "g++ missing"
    fx = _compile_fixture(workdir)
    if fx is None:
        return None, "shared C fixture failed to compile"
    extra = [f"-I{pybind11.get_include()}", f"-I{fx['inc']}", "-std=c++14"]
    mod, err = _build_ext_module(
        workdir,
        "ib_pybind",
        PYBIND_SOURCE,
        extra,
        lang_cpp=True,
        link=[str(fx["o"]), "-lm"],
    )
    if mod is None:
        return None, err
    return {"sqrt": mod.sqrt, "dot": mod.dot, "fnv": mod.fnv}, None


PYO3_LIB_RS = r"""
use pyo3::prelude::*;
use pyo3::types::PyBytes;

// The single C translation unit, bound through extern "C". Same ib_sqrt/ib_dot/
// ib_fnv1a machine code as ctypes/cffi/C-ext/pybind -- statically linked via
// build.rs. Nothing here reimplements the kernels.
#[repr(C)]
#[derive(Clone, Copy)]
struct Vec3 { x: f64, y: f64, z: f64 }

extern "C" {
    fn ib_sqrt(x: f64) -> i64;
    fn ib_dot(a: Vec3, b: Vec3) -> f64;
    fn ib_fnv1a(p: *const u8, n: usize) -> u64;
}

#[pyfunction]
fn sqrt(x: f64) -> i64 { unsafe { ib_sqrt(x) } }

// struct-by-value: two Python 3-tuples -> two repr(C) Vec3 -> shared ib_dot.
#[pyfunction]
fn dot(a: (f64, f64, f64), b: (f64, f64, f64)) -> f64 {
    let va = Vec3 { x: a.0, y: a.1, z: a.2 };
    let vb = Vec3 { x: b.0, y: b.1, z: b.2 };
    unsafe { ib_dot(va, vb) }
}

#[pyfunction]
fn fnv(b: &Bound<'_, PyBytes>) -> u64 {
    let s = b.as_bytes();
    unsafe { ib_fnv1a(s.as_ptr(), s.len()) }
}

#[pymodule]
fn ib_pyo3(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(sqrt, m)?)?;
    m.add_function(wrap_pyfunction!(dot, m)?)?;
    m.add_function(wrap_pyfunction!(fnv, m)?)?;
    Ok(())
}
"""

# Links the shared libibfixture.a (built once from ib_fixture.o) statically into
# the cdylib, plus libm for the sqrt symbol the fixture calls. IB_FIXTURE_DIR is
# passed in the cargo env below.
PYO3_BUILD_RS = r"""
fn main() {
    let dir = std::env::var("IB_FIXTURE_DIR").expect("IB_FIXTURE_DIR");
    println!("cargo:rustc-link-search=native={dir}", dir = dir);
    println!("cargo:rustc-link-lib=static=ibfixture");
    println!("cargo:rustc-link-lib=dylib=m");
}
"""

PYO3_CARGO_TOML = """
[package]
name = "ib_pyo3"
version = "0.1.0"
edition = "2021"
build = "build.rs"

[lib]
name = "ib_pyo3"
crate-type = ["cdylib"]

[dependencies]
pyo3 = { version = "0.22", features = ["extension-module", "abi3-py39"] }
"""


def build_pyo3(workdir: Path) -> tuple[dict | None, str | None]:
    if not shutil.which("cargo"):
        return None, "cargo missing"
    fx = _compile_fixture(workdir)
    if fx is None:
        return None, "shared C fixture failed to compile"
    crate = workdir / "pyo3crate"
    (crate / "src").mkdir(parents=True, exist_ok=True)
    (crate / "Cargo.toml").write_text(PYO3_CARGO_TOML)
    (crate / "build.rs").write_text(PYO3_BUILD_RS)
    (crate / "src" / "lib.rs").write_text(PYO3_LIB_RS)
    # PyO3 <=0.22 caps at CPython 3.13; on 3.14+ build against the stable ABI
    # (abi3) with the forward-compat escape hatch. PYO3_PYTHON pins the target
    # interpreter to the one running this script.
    import os

    env = {
        **os.environ,
        "PYO3_PYTHON": sys.executable,
        "PYO3_USE_ABI3_FORWARD_COMPATIBILITY": "1",
        "IB_FIXTURE_DIR": str(fx["a"].parent),
    }
    p = subprocess.run(
        ["cargo", "build", "--release"],
        cwd=str(crate),
        capture_output=True,
        text=True,
        env=env,
    )
    if p.returncode != 0:
        return None, f"cargo build failed: {p.stderr.strip().splitlines()[-1:]}"
    built = crate / "target" / "release" / "libib_pyo3.so"
    if not built.exists():
        return None, "cargo build produced no libib_pyo3.so"
    so = workdir / "ib_pyo3.so"
    shutil.copy(built, so)
    spec = importlib.util.spec_from_file_location("ib_pyo3", so)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return {"sqrt": mod.sqrt, "dot": mod.dot, "fnv": mod.fnv}, None


BUILDERS = {
    "ctypes": build_ctypes,
    "cffi": build_cffi,
    "cext": build_cext,
    "pybind11": build_pybind,
    "pyo3": build_pyo3,
}


# ---------------------------------------------------------------------------
# Matched + isolated measurement over a bound toolchain.
# ---------------------------------------------------------------------------
def matched_digest(kernel: str, calls: dict, n: int) -> int:
    if kernel == "sqrt":
        f = calls["sqrt"]
        acc = 0
        for i in range(1, n + 1):
            acc += int(f(float(i * i)))
        return acc
    if kernel == "struct":
        f = calls["dot"]
        acc = 0
        for i in range(1, n + 1):
            v = (float(i), float(i), float(i))
            acc += int(f(v, v))  # dot({i,i,i},{i,i,i}) = 3*i*i
        return acc
    if kernel == "bytes":
        f = calls["fnv"]
        acc = 0
        for i in range(1, n + 1):
            buf = (i & 0xFF).to_bytes(1, "little") * BUF_LEN
            acc = (acc ^ int(f(buf))) & 0xFFFFFFFFFFFFFFFF
        return acc
    raise ValueError(kernel)


def isolated_per_call_ns(kernel: str, calls: dict, n: int, reps: int) -> float:
    """Tight call loop minus empty loop -> boundary+conversion per call ns."""
    if kernel == "sqrt":
        f = calls["sqrt"]
        arg = 4.0

        def full():
            for _ in range(n):
                f(arg)
    elif kernel == "struct":
        f = calls["dot"]
        v = (2.0, 2.0, 2.0)

        def full():
            for _ in range(n):
                f(v, v)
    else:  # bytes
        f = calls["fnv"]
        buf = b"\x07" * BUF_LEN

        def full():
            for _ in range(n):
                f(buf)

    def empty():
        for _ in range(n):
            pass

    full_ns = time_loop(full, reps)
    empty_ns = time_loop(empty, reps)
    return max(0.0, (full_ns - empty_ns) / n)


def matched_per_call_ns(kernel: str, calls: dict, n: int, reps: int) -> tuple:
    """Per-call cost under the kernel's exact digest loop. Returns (ns, digest)."""
    dg = {"v": None}

    def run():
        dg["v"] = matched_digest(kernel, calls, n)

    total = time_loop(run, reps)
    return total / n, dg["v"]


# ---------------------------------------------------------------------------
# Pure-Python no-FFI floor (matched loop, no foreign call).
# ---------------------------------------------------------------------------
def python_ref_per_call_ns(kernel: str, n: int, reps: int) -> float:
    ref = KERNELS[kernel]["ref"]
    return time_loop(lambda: ref(n), reps) / n


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernels", default=",".join(KERNELS))
    ap.add_argument("--toolchains", default=",".join(BUILDERS))
    ap.add_argument("--matched-n", type=int, default=MATCHED_N_DEFAULT)
    ap.add_argument("--isolated-n", type=int, default=ISOLATED_N_DEFAULT)
    ap.add_argument("--reps", type=int, default=5)
    ap.add_argument(
        "--jac-na",
        action="store_true",
        help="also measure the Jac-native iop_ffi_* anchor points "
        "(scalar sqrt, struct-by-value, bytes-pointer FNV-1a)",
    )
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    kernels = [k.strip() for k in args.kernels.split(",") if k.strip()]
    toolchains = [t.strip() for t in args.toolchains.split(",") if t.strip()]

    gov = _governor()
    if gov["governor"] and gov["governor"] != "performance":
        print(
            f"WARNING: governor is '{gov['governor']}' (not 'performance'); "
            f"absolutes will be noisy.",
            file=sys.stderr,
        )

    workdir = Path(tempfile.mkdtemp(prefix="xtool_ffi_"))
    print(f"build dir: {workdir}", file=sys.stderr)

    # Build every requested toolchain once.
    bound: dict[str, dict] = {}
    skipped: dict[str, str] = {}
    for tc in toolchains:
        builder = BUILDERS.get(tc)
        if builder is None:
            skipped[tc] = "unknown toolchain"
            continue
        try:
            calls, err = builder(workdir)
        except Exception as e:  # noqa: BLE001 - report, don't crash the suite
            calls, err = None, f"{type(e).__name__}: {e}"
        if calls is None:
            skipped[tc] = err
            print(f"  SKIP {tc}: {err}", file=sys.stderr)
        else:
            bound[tc] = calls
            print(f"  built {tc}", file=sys.stderr)

    # Reference digests (pure Python) define the oracle target per kernel.
    ref_digests = {k: digest(k, KERNELS[k]["ref"](args.matched_n)) for k in kernels}

    cells: dict = {}
    oracle_ok = True
    for k in kernels:
        py_ref_ns = python_ref_per_call_ns(k, args.matched_n, args.reps)
        tc_rows = {}
        for tc, calls in bound.items():
            matched_ns, mval = matched_per_call_ns(k, calls, args.matched_n, args.reps)
            mdig = digest(k, mval)
            iso_ns = isolated_per_call_ns(k, calls, args.isolated_n, args.reps)
            agree = mdig == ref_digests[k]
            oracle_ok = oracle_ok and agree
            tc_rows[tc] = {
                "matched_per_call_ns": round(matched_ns, 2),
                "isolated_per_call_ns": round(iso_ns, 2),
                "overhead_above_ref_ns": round(matched_ns - py_ref_ns, 2),
                "digest": mdig,
                "digest_ok": agree,
            }
            print(
                f"  {k:7s} {tc:9s} matched={matched_ns:8.1f}ns "
                f"isolated={iso_ns:7.1f}ns digest={mdig} ok={agree}",
                file=sys.stderr,
            )
        cells[k] = {
            "reference_digest": ref_digests[k],
            "python_ref_per_call_ns": round(py_ref_ns, 2),
            "toolchains": tc_rows,
        }

    jac_na = None
    if args.jac_na:
        jac_na = _measure_jac_na(args.reps)

    shutil.rmtree(workdir, ignore_errors=True)

    doc = {
        "schema_version": 1,
        "kind": "cross_tool_ffi",
        "captured_utc": datetime.now(UTC).isoformat(),
        "matched_n": args.matched_n,
        "isolated_n": args.isolated_n,
        "reps": args.reps,
        "python": sys.version.split()[0],
        "machine_control": gov,
        "oracle_all_toolchains_agree": oracle_ok,
        "one_translation_unit": True,
        "matched_signatures": {
            "sqrt": "double -> long",
            "struct": "ib_dot(Vec3, Vec3) -> double, both structs BY VALUE",
            "bytes": "ib_fnv1a(const uint8_t*, size_t) -> uint64",
        },
        "skipped_toolchains": skipped,
        "jac_na": jac_na,
        "note": "One C translation unit (ib_fixture.o) is bound five ways: "
        "ctypes/cffi dlopen a .so built from it; the C-extension and pybind11 "
        'link that object; PyO3 static-links its archive via extern "C". Every '
        "toolchain runs the identical foreign machine code and every kernel uses "
        "the SAME signature across toolchains (struct = two Vec3 passed BY VALUE) "
        "-- only the boundary marshalling differs. matched = per foreign call "
        "under the kernel loop (warmed, digest-verified); isolated = tight call "
        "loop minus empty loop (boundary+conversion only). overhead_above_ref = "
        "matched minus the pure-Python no-FFI floor. Digest identity across all "
        "toolchains is the cross-tool oracle. jac_na = Jac's own native FFI "
        "kernels as anchors (separate workload/digest, not in the oracle).",
        "cells": cells,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=1))
    print(f"wrote {out}", file=sys.stderr)
    if not oracle_ok:
        print("ORACLE FAILED: toolchains disagree on a digest.", file=sys.stderr)
        sys.exit(3)


def _governor() -> dict:
    g = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    t = "/sys/devices/system/cpu/intel_pstate/no_turbo"
    try:
        gov = Path(g).read_text().strip()
        tur = Path(t).read_text().strip() if Path(t).exists() else None
    except OSError:
        gov, tur = None, None
    return {"governor": gov, "turbo_disabled": tur}


def _measure_jac_na_kernel(
    jac: str, kernel_file: str, digest_prefix: str, reps: int
) -> dict:
    """Measure one Jac-native iop_ffi_* kernel via `jac run`. Anchor point only.

    These are Jac's OWN native FFI kernels (scalar sqrt, struct-by-value). They
    are a separate workload from the Python-side cross-tool oracle -- reported as
    an anchor next to the Python toolchains, NOT folded into the digest identity.
    """
    import re

    per_re = re.compile(rb"m:per_ffi_call_ns=(\d+)")
    dig_re = re.compile(rf"({digest_prefix}:\d+)".encode())
    cmd = [jac, "run", kernel_file]
    samples: list[int] = []
    digest_seen = None
    for _ in range(reps):
        p = subprocess.run(cmd, cwd=str(BENCH), capture_output=True, timeout=120)
        m = per_re.search(p.stdout)
        d = dig_re.search(p.stdout)
        if m:
            samples.append(int(m.group(1)))
        if d:
            digest_seen = d.group(1).decode()
    if not samples:
        return {
            "skipped": f"{kernel_file} produced no m:per_ffi_call_ns "
            "(kernel may need nacompile); run manually"
        }
    return {
        "per_ffi_call_ns": statistics.median(samples),
        "samples": samples,
        "digest": digest_seen,
    }


def _ensure_bench_clib() -> str | None:
    """Rebuild libinteropbench.so from source so the struct/bytes anchors bind a
    .so that definitely exports the symbols they import (ib_dot-family + ib_fnv1a),
    rather than trusting a possibly-stale local build. Returns a skip reason or
    None on success."""
    src = BENCH / "kernels" / "support" / "interopbench.c"
    out = BENCH / "bin" / "libinteropbench.so"
    if not src.exists():
        return f"C fixture source missing: {src}"
    cc = shutil.which("cc") or shutil.which("gcc")
    if cc is None:
        # No compiler: fall back to an existing build if present, else skip.
        return None if out.exists() else "no C compiler (cc/gcc) and no prebuilt .so"
    out.parent.mkdir(parents=True, exist_ok=True)
    b = subprocess.run(
        [cc, "-shared", "-fPIC", "-O2", "-o", str(out), str(src)],
        capture_output=True,
        text=True,
        timeout=60,
    )
    return None if b.returncode == 0 else f"cc failed to build {out}: {b.stderr}"


def _measure_jac_na(reps: int) -> dict | None:
    """Measure Jac-native FFI anchors: scalar (sqrt), struct-by-value, bytes."""
    jac = shutil.which("jac")
    if jac is None:
        return {"skipped": "jac not on PATH"}
    clib_err = _ensure_bench_clib()
    # sqrt binds system libm; struct/bytes bind the freshly-built libinteropbench.
    struct = (
        {"skipped": clib_err}
        if clib_err
        else _measure_jac_na_kernel(
            jac, "kernels/iop_ffi_struct.na.jac", "struct", reps
        )
    )
    byts = (
        {"skipped": clib_err}
        if clib_err
        else _measure_jac_na_kernel(jac, "kernels/iop_ffi_bytes.na.jac", "bytes", reps)
    )
    return {
        "sqrt": _measure_jac_na_kernel(
            jac, "kernels/iop_ffi_scalar.na.jac", "sqrt", reps
        ),
        "struct": struct,
        "bytes": byts,
        "note": "Jac's own native FFI kernels; separate workloads/digests from "
        "the Python-side cross-tool oracle -- reported as anchors, not "
        "folded into the toolchain digest-identity check.",
    }


if __name__ == "__main__":
    main()
