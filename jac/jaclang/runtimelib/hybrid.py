"""Hybrid execution runtime for JIT-compiled functions.

This module provides the HybridFunction wrapper that transparently JIT-compiles
LLVM IR to native code on first call, with automatic fallback to Python.
"""

from __future__ import annotations

import ctypes
import hashlib
from typing import Any, Callable, Optional

from jaclang.settings import settings

try:
    import llvmlite.binding as llvm

    LLVM_AVAILABLE = True
except ImportError:
    LLVM_AVAILABLE = False
    llvm = None  # type: ignore


class HybridFunction:
    """Function wrapper that JIT-compiles to native on first call.

    This class wraps a Python function and its optional LLVM IR. On first call,
    it attempts to JIT-compile the LLVM IR. If successful, subsequent calls use
    the native version. Otherwise, it falls back to Python.

    Attributes:
        python_func: The Python implementation (fallback).
        llvm_ir: Optional LLVM IR string for JIT compilation.
        llvm_metadata: Function signature metadata.
        native_func: Cached native function (after JIT compilation).
        use_native: Whether to use native execution.

    Examples:
        >>> # Create hybrid function
        >>> hybrid_func = HybridFunction(
        ...     python_func=my_func,
        ...     llvm_ir="define i64 @my_func(i64 %x) { ... }",
        ...     llvm_metadata={'args': ['i64'], 'return': 'i64'}
        ... )
        >>>
        >>> # First call: JIT-compiles to native
        >>> result = hybrid_func(42)  # Uses LLVM
        >>>
        >>> # Subsequent calls: Use cached native
        >>> result = hybrid_func(100)  # Fast path
    """

    _jit_cache: dict[str, tuple[Any, Any]] = (
        {}
    )  # Global JIT cache: hash -> (native_func, engine)
    _llvm_initialized = False

    def __init__(
        self,
        python_func: Callable,
        llvm_ir: Optional[str] = None,
        llvm_metadata: Optional[dict] = None,
        llvm_triple: Optional[str] = None,
        llvm_data_layout: Optional[str] = None,
    ) -> None:
        """Initialize hybrid function wrapper.

        Args:
            python_func: The Python implementation (fallback).
            llvm_ir: Optional LLVM IR string for JIT compilation.
            llvm_metadata: Function signature metadata {'args': [...], 'return': ...}.
            llvm_triple: Target triple.
            llvm_data_layout: Data layout string.
        """
        self.python_func = python_func
        self.llvm_ir = llvm_ir
        self.llvm_metadata = llvm_metadata or {}
        self.llvm_triple = llvm_triple
        self.llvm_data_layout = llvm_data_layout

        self.native_func: Optional[Callable] = None
        self.execution_engine: Optional[Any] = None
        self.jit_attempted = False
        self.use_native = False
        self.jit_error: Optional[str] = None

        # Copy function metadata
        self.__name__ = python_func.__name__
        self.__doc__ = python_func.__doc__
        self.__module__ = python_func.__module__
        self.__wrapped__ = python_func

    def __call__(self, *args: object, **kwargs: object) -> object:
        """Call the function, using native if available.

        Args:
            *args: Positional arguments.
            **kwargs: Keyword arguments.

        Returns:
            Function result.
        """
        # Check if JIT is disabled
        if settings.jit_force_python or not settings.jit_enabled:
            return self.python_func(*args, **kwargs)

        # First call with LLVM IR: attempt JIT compilation
        if not self.jit_attempted and self.llvm_ir and LLVM_AVAILABLE:
            self._jit_compile()

        # Use native if available and arguments are positional only
        if self.use_native and self.native_func and not kwargs:
            try:
                result = self._call_native(*args)

                if settings.jit_debug:
                    print(
                        f"[JIT] Native execution: {self.__name__}(*{args}) = {result}"
                    )

                return result
            except Exception as e:
                # Fall back to Python on error
                if settings.jit_debug:
                    print(
                        f"[JIT] Native call failed for {self.__name__}, falling back to Python: {e}"
                    )

                if not settings.jit_fallback_on_error:
                    raise

                self.use_native = False

        # Fallback to Python
        return self.python_func(*args, **kwargs)

    def _jit_compile(self) -> None:
        """Attempt to JIT-compile the LLVM IR."""
        self.jit_attempted = True

        if not LLVM_AVAILABLE:
            if settings.jit_debug:
                print(f"[JIT] llvmlite not available, using Python for {self.__name__}")
            return

        try:
            # Check cache
            if not self.llvm_ir:
                return
            ir_hash = hashlib.sha256(self.llvm_ir.encode()).hexdigest()[:16]
            if ir_hash in HybridFunction._jit_cache:
                self.native_func, self.execution_engine = HybridFunction._jit_cache[
                    ir_hash
                ]
                self.use_native = True
                if settings.jit_debug:
                    print(f"[JIT] ✓ {self.__name__}: Using cached native code")
                return

            # Initialize LLVM targets
            if not HybridFunction._llvm_initialized:
                llvm.initialize_all_targets()
                llvm.initialize_all_asmprinters()
                HybridFunction._llvm_initialized = True

            if settings.jit_debug:
                print(f"[JIT] Compiling {self.__name__} to native code...")

            # Parse and verify LLVM IR
            module = llvm.parse_assembly(self.llvm_ir)
            module.verify()

            # Set target information
            if self.llvm_triple:
                module.triple = self.llvm_triple
            else:
                module.triple = llvm.get_default_triple()

            if self.llvm_data_layout:
                module.data_layout = self.llvm_data_layout

            # Create execution engine with JIT compiler
            target = llvm.Target.from_triple(module.triple)
            target_machine = target.create_target_machine()
            engine = llvm.create_mcjit_compiler(module, target_machine)
            engine.finalize_object()
            engine.run_static_constructors()

            # Get function pointer
            func_name = self.__name__
            func_ptr = engine.get_function_address(func_name)

            if func_ptr == 0:
                raise ValueError(f"Function '{func_name}' not found in compiled module")

            # Create ctypes wrapper
            self.native_func = self._create_ctypes_wrapper(func_ptr)
            self.execution_engine = engine

            # Cache it (store both function and engine to prevent GC)
            if len(HybridFunction._jit_cache) >= settings.jit_cache_size:
                # Simple LRU: remove first item
                HybridFunction._jit_cache.pop(next(iter(HybridFunction._jit_cache)))

            HybridFunction._jit_cache[ir_hash] = (
                self.native_func,
                self.execution_engine,
            )
            self.use_native = True

            if settings.jit_debug:
                arg_types = self.llvm_metadata.get("args", [])
                ret_type = self.llvm_metadata.get("return", "void")
                print(f"[JIT] ✓ {self.__name__}: JIT-compiled successfully")
                print(f"[JIT]   Signature: {ret_type} ({', '.join(arg_types)})")
                print(
                    f"[JIT]   Cache size: {len(HybridFunction._jit_cache)}/{settings.jit_cache_size}"
                )

        except Exception as e:
            self.jit_error = str(e)
            self.use_native = False

            if settings.jit_debug:
                print(f"[JIT] ✗ {self.__name__}: JIT compilation failed: {e}")

            if settings.jit_force_native:
                raise RuntimeError(
                    f"JIT compilation failed for {self.__name__} and JAC_FORCE_NATIVE is set: {e}"
                ) from e

    def _create_ctypes_wrapper(self, func_ptr: int) -> Callable:
        """Create a ctypes wrapper for the native function.

        Args:
            func_ptr: Function pointer address.

        Returns:
            Callable ctypes function wrapper.
        """
        metadata = self.llvm_metadata

        # Map LLVM types to ctypes
        def llvm_to_ctype_arg(type_str: str) -> type[ctypes._CData]:
            """Convert LLVM type to ctypes (for arguments, never void)."""
            if type_str in {"i1", "bool"}:
                return ctypes.c_uint8
            if type_str == "i8":
                return ctypes.c_int8
            if type_str == "i16":
                return ctypes.c_int16
            if type_str == "i32":
                return ctypes.c_int32
            if type_str in {"i64", "int"}:
                return ctypes.c_int64
            if type_str == "float":
                return ctypes.c_float
            if type_str == "double":
                return ctypes.c_double
            if type_str.endswith("*"):
                return ctypes.c_void_p
            raise ValueError(f"Unsupported LLVM type: {type_str}")

        def llvm_to_ctype_ret(type_str: str) -> type[ctypes._CData] | None:
            """Convert LLVM type to ctypes (for return type, can be void)."""
            if type_str == "void":
                return None
            return llvm_to_ctype_arg(type_str)

        # Get return and argument types
        ret_type_str = metadata.get("return", "void")
        arg_type_strs = metadata.get("args", [])

        ret_type = llvm_to_ctype_ret(ret_type_str)
        arg_types = [llvm_to_ctype_arg(t) for t in arg_type_strs]

        # Create ctypes function type
        if ret_type is None:
            cfunctype = ctypes.CFUNCTYPE(None, *arg_types)
        else:
            cfunctype = ctypes.CFUNCTYPE(ret_type, *arg_types)

        return cfunctype(func_ptr)

    def _call_native(self, *args: object) -> object:
        """Call the native function with type conversion.

        Args:
            *args: Arguments to pass.

        Returns:
            Native function result.
        """
        # For now, assume arguments are already the correct types
        # TODO: Add automatic type conversion based on metadata
        if not self.native_func:
            raise RuntimeError("Native function not available")
        return self.native_func(*args)

    def force_python(self) -> None:
        """Force using Python implementation."""
        self.use_native = False

    def force_native(self) -> None:
        """Force using native implementation.

        Raises:
            RuntimeError: If JIT compilation failed.
        """
        if self.native_func:
            self.use_native = True
        elif self.llvm_ir:
            if not self.jit_attempted:
                self._jit_compile()
            if not self.use_native:
                raise RuntimeError(
                    f"Cannot force native execution for {self.__name__}: "
                    f"JIT compilation failed: {self.jit_error}"
                )
        else:
            raise RuntimeError(
                f"Cannot force native execution for {self.__name__}: "
                f"No LLVM IR available"
            )

    @property
    def is_native(self) -> bool:
        """Check if function is using native execution."""
        return self.use_native and self.native_func is not None

    @property
    def has_llvm(self) -> bool:
        """Check if function has LLVM IR available."""
        return self.llvm_ir is not None

    def __repr__(self) -> str:
        """String representation."""
        mode = "native" if self.is_native else "python"
        return f"<HybridFunction {self.__name__} mode={mode}>"


def create_hybrid_function(
    python_func: Callable,
    llvm_ir: Optional[str] = None,
    llvm_metadata: Optional[dict] = None,
    llvm_triple: Optional[str] = None,
    llvm_data_layout: Optional[str] = None,
) -> HybridFunction:
    """Create a hybrid function from a Python function and optional LLVM IR.

    Args:
        python_func: The Python implementation.
        llvm_ir: Optional LLVM IR string.
        llvm_metadata: Optional function signature metadata.
        llvm_triple: Optional target triple.
        llvm_data_layout: Optional data layout string.

    Returns:
        HybridFunction wrapper.
    """
    return HybridFunction(
        python_func=python_func,
        llvm_ir=llvm_ir,
        llvm_metadata=llvm_metadata,
        llvm_triple=llvm_triple,
        llvm_data_layout=llvm_data_layout,
    )
