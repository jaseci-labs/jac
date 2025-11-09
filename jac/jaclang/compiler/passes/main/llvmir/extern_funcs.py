"""External function declarations for LLVM IR generation.

This module provides utilities for declaring and calling external C library
functions from Jac native code.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    try:
        from llvmlite import ir as _ir
    except ImportError:
        _ir = None  # type: ignore


class ExternalFunctions:
    """Manages external function declarations for LLVM modules.

    This class provides a registry of common C library functions that can
    be called from Jac native code, such as printf, malloc, free, etc.
    """

    def __init__(self, module: _ir.Module) -> None:
        """Initialize external function manager.

        Args:
            module: The LLVM module to add declarations to.
        """
        self.module = module
        self._declared_functions: dict[str, _ir.Function] = {}

    def declare_printf(self) -> _ir.Function:
        """Declare the printf function from libc.

        Returns:
            LLVM function object for printf.

        Example:
            >>> printf = extern_funcs.declare_printf()
            >>> # Create format string
            >>> fmt = builder.global_string_ptr("%d\\n", "fmt")
            >>> # Call printf
            >>> builder.call(printf, [fmt, value])
        """
        if "printf" in self._declared_functions:
            return self._declared_functions["printf"]

        try:
            from llvmlite import ir as _ir
        except ImportError as e:
            raise ImportError("llvmlite is required") from e

        # printf signature: int printf(const char *format, ...)
        # In LLVM: i32 (i8*, ...)
        i8_ptr = _ir.PointerType(_ir.IntType(8))
        printf_type = _ir.FunctionType(
            _ir.IntType(32),  # return type: int
            [i8_ptr],  # format string
            var_arg=True,  # variadic
        )

        printf_func = _ir.Function(self.module, printf_type, name="printf")
        self._declared_functions["printf"] = printf_func
        return printf_func

    def declare_puts(self) -> _ir.Function:
        """Declare the puts function from libc.

        Returns:
            LLVM function object for puts.

        Example:
            >>> puts = extern_funcs.declare_puts()
            >>> msg = builder.global_string_ptr("Hello, World!", "msg")
            >>> builder.call(puts, [msg])
        """
        if "puts" in self._declared_functions:
            return self._declared_functions["puts"]

        try:
            from llvmlite import ir as _ir
        except ImportError as e:
            raise ImportError("llvmlite is required") from e

        # puts signature: int puts(const char *s)
        i8_ptr = _ir.PointerType(_ir.IntType(8))
        puts_type = _ir.FunctionType(
            _ir.IntType(32),  # return type: int
            [i8_ptr],  # string
        )

        puts_func = _ir.Function(self.module, puts_type, name="puts")
        self._declared_functions["puts"] = puts_func
        return puts_func

    def declare_malloc(self) -> _ir.Function:
        """Declare the malloc function from libc.

        Returns:
            LLVM function object for malloc.
        """
        if "malloc" in self._declared_functions:
            return self._declared_functions["malloc"]

        try:
            from llvmlite import ir as _ir
        except ImportError as e:
            raise ImportError("llvmlite is required") from e

        # malloc signature: void* malloc(size_t size)
        i8_ptr = _ir.PointerType(_ir.IntType(8))
        malloc_type = _ir.FunctionType(
            i8_ptr,  # return type: void*
            [_ir.IntType(64)],  # size_t
        )

        malloc_func = _ir.Function(self.module, malloc_type, name="malloc")
        self._declared_functions["malloc"] = malloc_func
        return malloc_func

    def declare_free(self) -> _ir.Function:
        """Declare the free function from libc.

        Returns:
            LLVM function object for free.
        """
        if "free" in self._declared_functions:
            return self._declared_functions["free"]

        try:
            from llvmlite import ir as _ir
        except ImportError as e:
            raise ImportError("llvmlite is required") from e

        # free signature: void free(void *ptr)
        i8_ptr = _ir.PointerType(_ir.IntType(8))
        free_type = _ir.FunctionType(
            _ir.VoidType(),  # return type: void
            [i8_ptr],  # ptr
        )

        free_func = _ir.Function(self.module, free_type, name="free")
        self._declared_functions["free"] = free_func
        return free_func

    def get_function(self, name: str) -> _ir.Function | None:
        """Get a declared external function by name.

        Args:
            name: Function name (e.g., "printf", "malloc").

        Returns:
            The declared function, or None if not declared.
        """
        return self._declared_functions.get(name)


def create_string_constant(
    module: _ir.Module, builder: _ir.IRBuilder, string: str, name: str = "str"
) -> _ir.Value:
    """Create a global string constant and return a pointer to it.

    This is useful for passing string literals to functions like printf.

    Args:
        module: The LLVM module.
        builder: The IR builder.
        string: The string content.
        name: Optional name for the global string.

    Returns:
        Pointer to the string constant (i8*).

    Example:
        >>> fmt_str = create_string_constant(module, builder, "Result: %d\\n")
        >>> printf = extern_funcs.declare_printf()
        >>> builder.call(printf, [fmt_str, result_value])
    """
    try:
        from llvmlite import ir as _ir
    except ImportError as e:
        raise ImportError("llvmlite is required") from e

    # Create the string constant with null terminator
    string_const = _ir.Constant(
        _ir.ArrayType(_ir.IntType(8), len(string) + 1),
        bytearray((string + "\0").encode("utf-8")),
    )

    # Create a global variable to hold the string
    global_str = _ir.GlobalVariable(module, string_const.type, name=name)
    global_str.linkage = "internal"
    global_str.global_constant = True
    global_str.initializer = string_const

    # Get pointer to first element (i8*)
    zero = _ir.Constant(_ir.IntType(32), 0)
    return builder.gep(
        global_str,
        [zero, zero],
        inbounds=True,
        name=f"{name}_ptr",
    )
