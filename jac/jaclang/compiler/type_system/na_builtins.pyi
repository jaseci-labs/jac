# ruff: noqa: N801, N802, N803
"""Native (.na.jac) ambient type stubs.

These model the native runtime surface that NaIRGenPass lowers directly to
LLVM (see compiler/passes/native/na_ir_gen_pass.impl/file_io.impl.jac). Unlike
jac_builtins.pyi / dom_types.pyi, this stub is NOT merged into the global
builtins: the TypeEvaluator resolves these names only inside .na.jac modules
(native context), so `File` and the native `open` never leak into regular Jac.

Signatures mirror the emitted File struct and methods so that File-typed code
type-checks accurately instead of degrading to UnknownType.
"""

from __future__ import annotations

from typing import Literal, Protocol, TypeVar, overload

__all__ = [
    "File",
    "BinaryFile",
    "open",
    "Iterable",
    "Iterator",
    "iter",
    "next",
    "managed",
]

_T = TypeVar("_T")

def managed(__x: _T) -> _T: ...

class Iterable(Protocol[_T]):
    def __iter__(self) -> Iterator[_T]: ...

class Iterator(Iterable[_T], Protocol[_T]):
    def __iter__(self) -> Iterator[_T]: ...
    def __next__(self) -> _T: ...

def iter(__o: Iterable[_T]) -> Iterator[_T]: ...
def next(__i: Iterator[_T]) -> _T: ...

class File:
    # Fields backing the emitted struct (handle is opaque and intentionally
    # not exposed): path, mode and the closed flag.
    path: str
    mode: str
    closed: bool

    def read(self) -> str: ...
    def readline(self) -> str: ...
    def write(self, data: str) -> int: ...
    def close(self) -> None: ...
    def flush(self) -> None: ...
    def __enter__(self) -> File: ...
    def __exit__(
        self, exc_type: object, exc_val: object, traceback: object
    ) -> bool: ...

class BinaryFile:
    # open(path, "rb"/"wb"/...) -> binary file: read()/readline() yield a
    # length-aware bytes value, write() takes bytes (mirrors CPython's
    # BufferedReader/Writer split from TextIOWrapper).
    path: str
    mode: str
    closed: bool

    def read(self) -> bytes: ...
    def readline(self) -> bytes: ...
    def write(self, data: bytes) -> int: ...
    def close(self) -> None: ...
    def flush(self) -> None: ...
    def __enter__(self) -> BinaryFile: ...
    def __exit__(
        self, exc_type: object, exc_val: object, traceback: object
    ) -> bool: ...

# A binary mode literal (containing "b") selects BinaryFile; any other mode is
# a text File. The codegen reads the same literal to pick the struct, so the
# static type and emitted object always agree (#6404).
@overload
def open(
    path: str,
    mode: Literal[
        "rb",
        "br",
        "rb+",
        "r+b",
        "wb",
        "bw",
        "wb+",
        "w+b",
        "ab",
        "ba",
        "ab+",
        "a+b",
        "xb",
        "bx",
        "xb+",
        "x+b",
    ],
) -> BinaryFile: ...
@overload
def open(path: str, mode: str = "r") -> File: ...
