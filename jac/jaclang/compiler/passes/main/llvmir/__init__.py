"""LLVM IR generation module for Jac programs.

This module provides type-safe LLVM IR generation components for compiling
Jac source code to native machine code via LLVM.
"""

from __future__ import annotations

__all__ = ["LlvmTypes", "TypeMapper", "AssemblyGenerator", "ExternalFunctions"]

try:
    from .types import LlvmTypes
    from .type_mapper import TypeMapper
    from .asm_gen import AssemblyGenerator
    from .extern_funcs import ExternalFunctions
except ImportError:
    # llvmlite not installed - gracefully handle
    LlvmTypes = None  # type: ignore
    TypeMapper = None  # type: ignore
    AssemblyGenerator = None  # type: ignore
    ExternalFunctions = None  # type: ignore
