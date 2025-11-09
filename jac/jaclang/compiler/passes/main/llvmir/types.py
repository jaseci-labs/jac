"""Type-safe type definitions for LLVM IR generation.

This module provides production-grade type safety for LLVM IR operations,
following the architecture guidelines in notes.md.
"""

from __future__ import annotations

from typing import Protocol, TYPE_CHECKING, TypeAlias, TypedDict

if TYPE_CHECKING:
    try:
        from llvmlite import ir as _ir
        from llvmlite import binding as _llvm
    except ImportError:
        # Provide stubs for type checking when llvmlite not installed
        _ir = None  # type: ignore
        _llvm = None  # type: ignore


# Core LLVM type aliases for type safety
try:
    from llvmlite import ir as _ir

    LlvmModule: TypeAlias = _ir.Module
    LlvmFunction: TypeAlias = _ir.Function
    LlvmValue: TypeAlias = _ir.Value
    LlvmType: TypeAlias = _ir.Type
    LlvmBuilder: TypeAlias = _ir.IRBuilder
    LlvmBasicBlock: TypeAlias = _ir.Block
    LlvmAllocaInstr: TypeAlias = _ir.AllocaInstr
    LlvmConstant: TypeAlias = _ir.Constant
except ImportError:
    # Provide runtime stubs when llvmlite not installed
    LlvmModule = None  # type: ignore
    LlvmFunction = None  # type: ignore
    LlvmValue = None  # type: ignore
    LlvmType = None  # type: ignore
    LlvmBuilder = None  # type: ignore
    LlvmBasicBlock = None  # type: ignore
    LlvmAllocaInstr = None  # type: ignore
    LlvmConstant = None  # type: ignore


class FunctionSignature(TypedDict):
    """Type-safe function signature metadata."""

    return_type: str  # LLVM type string (e.g., "i64", "double", "void")
    args: list[str]  # List of LLVM type strings for parameters


class SymbolEntry(TypedDict):
    """Type-safe symbol table entry."""

    alloca: LlvmAllocaInstr  # Alloca instruction for this symbol
    ir_type: LlvmType  # LLVM IR type
    jac_type: str  # Original Jac type annotation


class LlvmTypes:
    """Container for commonly-used LLVM types.

    This class provides type-safe access to standard LLVM types
    used throughout the code generation process.
    """

    def __init__(self) -> None:
        """Initialize LLVM type containers.

        Raises:
            ImportError: If llvmlite is not installed.
        """
        try:
            from llvmlite import ir as _ir
        except ImportError as e:
            raise ImportError(
                "llvmlite is required for LLVM IR generation. "
                "Install it with: pip install llvmlite"
            ) from e

        # Integer types
        self.i1: _ir.IntType = _ir.IntType(1)  # bool
        self.i8: _ir.IntType = _ir.IntType(8)
        self.i16: _ir.IntType = _ir.IntType(16)
        self.i32: _ir.IntType = _ir.IntType(32)
        self.i64: _ir.IntType = _ir.IntType(64)

        # Floating point types
        self.f16: _ir.HalfType = _ir.HalfType()
        self.f32: _ir.FloatType = _ir.FloatType()
        self.f64: _ir.DoubleType = _ir.DoubleType()

        # Special types
        self.void: _ir.VoidType = _ir.VoidType()

        # Common pointer types
        self.i8_ptr: _ir.PointerType = _ir.PointerType(_ir.IntType(8))

        # Aliases for common usage
        self.bool_type = self.i1
        self.int_type = self.i64  # Default int is 64-bit
        self.float_type = self.f64  # Default float is double

    def is_int_type(self, typ: LlvmType) -> bool:
        """Check if a type is an integer type."""
        return str(typ).startswith("i")

    def is_float_type(self, typ: LlvmType) -> bool:
        """Check if a type is a floating point type."""
        return str(typ) in {"half", "float", "double", "fp128"}

    def is_pointer_type(self, typ: LlvmType) -> bool:
        """Check if a type is a pointer type."""
        return str(typ).endswith("*")

    def is_void_type(self, typ: LlvmType) -> bool:
        """Check if a type is void."""
        return str(typ) == "void"

    def int_bitwidth(self, typ: LlvmType) -> int:
        """Get the bitwidth of an integer type."""
        return getattr(
            typ, "width", int(str(typ)[1:]) if str(typ).startswith("i") else 0
        )

    def encode_type(self, typ: LlvmType) -> str:
        """Encode an LLVM type as a string for metadata."""
        return str(typ)


class TypeMapperProtocol(Protocol):
    """Protocol for type mapping implementations.

    This protocol defines the interface that all type mappers must implement,
    ensuring type safety across different type mapping strategies.
    """

    def map_jac_to_llvm(self, jac_type: str) -> LlvmType:
        """Map a Jac type annotation to an LLVM type.

        Args:
            jac_type: The Jac type string (e.g., "int", "float", "bool")

        Returns:
            The corresponding LLVM type.
        """
        ...

    def default_value(self, llvm_type: LlvmType) -> LlvmConstant | None:
        """Get the default value for an LLVM type.

        Args:
            llvm_type: The LLVM type to get a default value for.

        Returns:
            A constant default value, or None for void type.
        """
        ...

    def coerce_value(
        self, value: LlvmValue, target_type: LlvmType, builder: LlvmBuilder
    ) -> LlvmValue | None:
        """Coerce a value to a target type.

        Args:
            value: The value to coerce.
            target_type: The target LLVM type.
            builder: The IR builder to use for generating coercion instructions.

        Returns:
            The coerced value, or None if coercion is not possible.
        """
        ...
