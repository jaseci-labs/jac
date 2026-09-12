"""Native LLVM IR compilation passes, loaded only when code generation needs them."""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from jaclang.compiler.backends.native.na_compile_pass import NativeCompilePass
    from jaclang.compiler.backends.native.na_ir_gen_pass import NaIRGenPass


def __getattr__(name: str) -> object:
    if name == "NativeCompilePass":
        from jaclang.compiler.backends.native.na_compile_pass import NativeCompilePass

        globals()[name] = NativeCompilePass
        return NativeCompilePass
    if name == "NaIRGenPass":
        from jaclang.compiler.backends.native.na_ir_gen_pass import NaIRGenPass

        globals()[name] = NaIRGenPass
        return NaIRGenPass
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = ["NativeCompilePass", "NaIRGenPass"]
