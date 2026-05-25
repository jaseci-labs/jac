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

__all__ = ["File", "open"]

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

def open(path: str, mode: str = "r") -> File: ...
