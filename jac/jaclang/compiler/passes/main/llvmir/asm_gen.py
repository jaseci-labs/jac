"""Assembly code generation utilities for LLVM IR.

This module provides utilities for generating native assembly code from
LLVM IR modules for various target architectures.
"""

from __future__ import annotations

from typing import Literal

try:
    from llvmlite import binding as llvm
    from llvmlite import ir as _ir

    LLVM_AVAILABLE = True
except ImportError:
    LLVM_AVAILABLE = False
    llvm = None  # type: ignore
    _ir = None  # type: ignore


class AssemblyGenerator:
    """Generate assembly code from LLVM IR modules.

    This class provides methods to generate native assembly code for
    various target architectures with configurable optimization levels.
    """

    _initialized = False

    def __init__(self) -> None:
        """Initialize the assembly generator.

        Raises:
            ImportError: If llvmlite is not installed.
        """
        if not LLVM_AVAILABLE:
            raise ImportError(
                "llvmlite is required for assembly generation. "
                "Install it with: pip install llvmlite"
            )

        if not AssemblyGenerator._initialized:
            llvm.initialize()
            llvm.initialize_native_target()
            llvm.initialize_native_asmprinter()
            AssemblyGenerator._initialized = True

    def generate(
        self,
        llvm_ir: str,
        target_triple: str | None = None,
        optimization_level: int = 2,
        emit_format: Literal["asm", "obj"] = "asm",
    ) -> bytes:
        """Generate assembly or object code from LLVM IR.

        Args:
            llvm_ir: The LLVM IR string to compile.
            target_triple: Target triple (e.g., "x86_64-unknown-linux-gnu").
                          If None, uses the default triple.
            optimization_level: Optimization level (0-3). Default is 2.
            emit_format: Output format - "asm" for assembly text, "obj" for object file.

        Returns:
            The generated assembly or object code as bytes.

        Raises:
            ValueError: If the IR is invalid or compilation fails.

        Examples:
            >>> gen = AssemblyGenerator()
            >>> asm = gen.generate(llvm_ir_string)
            >>> print(asm.decode('utf-8'))
        """
        # Parse the IR
        try:
            mod = llvm.parse_assembly(llvm_ir)
        except Exception as e:
            raise ValueError(f"Failed to parse LLVM IR: {e}") from e

        # Set target triple
        if target_triple:
            mod.triple = target_triple
        else:
            mod.triple = llvm.get_default_triple()

        # Verify the module
        try:
            mod.verify()
        except Exception as e:
            raise ValueError(f"LLVM IR verification failed: {e}") from e

        # Create target machine
        target = llvm.Target.from_triple(mod.triple)
        target_machine = target.create_target_machine(opt=optimization_level)

        # Set data layout
        mod.data_layout = target_machine.target_data

        # Emit assembly or object code
        if emit_format == "asm":
            return target_machine.emit_assembly(mod)
        else:
            return target_machine.emit_object(mod)

    def generate_for_module(
        self,
        llvm_module: _ir.Module,
        optimization_level: int = 2,
        emit_format: Literal["asm", "obj"] = "asm",
    ) -> bytes:
        """Generate assembly from an LLVM Module object.

        Args:
            llvm_module: The LLVM Module object.
            optimization_level: Optimization level (0-3).
            emit_format: Output format - "asm" or "obj".

        Returns:
            The generated assembly or object code as bytes.
        """
        return self.generate(
            str(llvm_module),
            target_triple=llvm_module.triple,
            optimization_level=optimization_level,
            emit_format=emit_format,
        )

    @staticmethod
    def get_supported_targets() -> list[str]:
        """Get a list of supported target architectures.

        Returns:
            List of target triple strings.

        Examples:
            >>> AssemblyGenerator.get_supported_targets()
            ['x86_64-unknown-linux-gnu', 'aarch64-unknown-linux-gnu', ...]
        """
        if not LLVM_AVAILABLE:
            return []

        # Common targets - actual availability depends on LLVM build
        common_targets = [
            "x86_64-unknown-linux-gnu",
            "x86_64-apple-darwin",
            "x86_64-pc-windows-msvc",
            "i686-unknown-linux-gnu",
            "aarch64-unknown-linux-gnu",
            "aarch64-apple-darwin",
            "arm-unknown-linux-gnueabi",
            "armv7-unknown-linux-gnueabihf",
        ]

        return common_targets

    @staticmethod
    def get_default_triple() -> str:
        """Get the default target triple for this platform.

        Returns:
            The target triple string.
        """
        if not LLVM_AVAILABLE:
            return "unknown"

        return llvm.get_default_triple()
