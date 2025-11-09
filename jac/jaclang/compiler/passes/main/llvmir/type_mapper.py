"""Type mapping utilities for Jac → LLVM type conversion.

This module provides production-grade type mapping with comprehensive
type coercion and validation.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    try:
        from llvmlite import ir as _ir
    except ImportError:
        _ir = None  # type: ignore

from .types import LlvmBuilder, LlvmConstant, LlvmType, LlvmTypes, LlvmValue


class TypeMapper:
    """Maps Jac types to LLVM types and handles type coercion.

    This class provides comprehensive type mapping and coercion operations
    following type-safe patterns.
    """

    def __init__(self) -> None:
        """Initialize the type mapper."""
        self.types = LlvmTypes()

    def map_jac_to_llvm(self, jac_type: str) -> LlvmType:
        """Map a Jac type annotation to an LLVM type.

        Args:
            jac_type: The Jac type string (e.g., "int", "float", "bool", "void")

        Returns:
            The corresponding LLVM type.

        Examples:
            >>> mapper = TypeMapper()
            >>> mapper.map_jac_to_llvm("int")  # Returns i64
            >>> mapper.map_jac_to_llvm("float")  # Returns double
            >>> mapper.map_jac_to_llvm("bool")  # Returns i1
        """
        lowered = jac_type.lower()

        # Integer types
        if lowered in {"int", "i64"}:
            return self.types.i64
        if lowered in {"i8"}:
            return self.types.i8
        if lowered in {"i16"}:
            return self.types.i16
        if lowered in {"i32"}:
            return self.types.i32

        # Boolean type
        if lowered in {"bool", "i1"}:
            return self.types.i1

        # Floating point types
        if lowered in {"float", "double", "f64"}:
            return self.types.f64
        if lowered in {"f32"}:
            return self.types.f32
        if lowered in {"f16", "half"}:
            return self.types.f16

        # Special types
        if lowered == "void":
            return self.types.void

        # Default to int if type is unknown
        return self.types.int_type

    def default_value(self, llvm_type: LlvmType) -> LlvmConstant | None:
        """Get the default value for an LLVM type.

        Args:
            llvm_type: The LLVM type to get a default value for.

        Returns:
            A constant default value, or None for void type.

        Examples:
            >>> mapper = TypeMapper()
            >>> mapper.default_value(mapper.types.i64)  # Returns Constant(i64, 0)
            >>> mapper.default_value(mapper.types.void)  # Returns None
        """
        try:
            from llvmlite import ir as _ir
        except ImportError as e:
            raise ImportError("llvmlite is required") from e

        if self.types.is_void_type(llvm_type):
            return None

        if self.types.is_int_type(llvm_type):
            return _ir.Constant(llvm_type, 0)

        if self.types.is_float_type(llvm_type):
            return _ir.Constant(llvm_type, 0.0)

        if self.types.is_pointer_type(llvm_type):
            return _ir.Constant(llvm_type, None)

        # Unsupported type - return int 0 as fallback
        return _ir.Constant(self.types.i64, 0)

    def zero_like(self, llvm_type: LlvmType) -> LlvmConstant | None:
        """Create a zero constant of the given type.

        Args:
            llvm_type: The LLVM type to create a zero value for.

        Returns:
            A zero constant, or None if not applicable.
        """
        try:
            from llvmlite import ir as _ir
        except ImportError as e:
            raise ImportError("llvmlite is required") from e

        if self.types.is_int_type(llvm_type):
            return _ir.Constant(llvm_type, 0)

        if self.types.is_float_type(llvm_type):
            return _ir.Constant(llvm_type, 0.0)

        return None

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

        Supported coercions:
            - int → float (sitofp)
            - float → int (fptosi)
            - int → int (sext/trunc)
            - ptr → ptr (bitcast)
        """
        # No coercion needed if types match
        if str(value.type) == str(target_type):
            return value

        # Float ← Int
        if self.types.is_float_type(target_type) and self.types.is_int_type(value.type):
            return builder.sitofp(value, target_type, name="coerce_fp")

        # Int ← Float
        if self.types.is_int_type(target_type) and self.types.is_float_type(value.type):
            return builder.fptosi(value, target_type, name="coerce_int")

        # Int ← Int (different widths)
        if self.types.is_int_type(target_type) and self.types.is_int_type(value.type):
            src_width = self.types.int_bitwidth(value.type)
            dst_width = self.types.int_bitwidth(target_type)

            if src_width < dst_width:
                return builder.sext(value, target_type, name="sext")
            elif src_width > dst_width:
                return builder.trunc(value, target_type, name="trunc")

        # Ptr ← Ptr
        if self.types.is_pointer_type(target_type) and self.types.is_pointer_type(
            value.type
        ):
            return builder.bitcast(value, target_type, name="bitcast")

        # Coercion not supported
        return None

    def align_binary_operands(
        self, left: LlvmValue, right: LlvmValue, builder: LlvmBuilder
    ) -> tuple[LlvmValue, LlvmValue] | tuple[None, None]:
        """Align binary operands to a common type.

        Args:
            left: The left operand.
            right: The right operand.
            builder: The IR builder to use for coercion.

        Returns:
            A tuple of (aligned_left, aligned_right), or (None, None) if
            alignment is not possible.

        Rules:
            - If both types are the same, no conversion needed.
            - If one is float and the other is int, promote int to float.
            - Otherwise, incompatible types.
        """
        # Same type - no conversion needed
        if str(left.type) == str(right.type):
            return left, right

        # Float + Int → promote int to float
        if self.types.is_float_type(left.type) and self.types.is_int_type(right.type):
            return left, builder.sitofp(right, left.type, name="coerce_rhs")

        # Int + Float → promote int to float
        if self.types.is_float_type(right.type) and self.types.is_int_type(left.type):
            return builder.sitofp(left, right.type, name="coerce_lhs"), right

        # Incompatible types
        return None, None
