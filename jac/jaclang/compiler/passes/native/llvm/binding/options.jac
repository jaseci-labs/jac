import from jaclang.compiler.passes.native.llvm.binding { ffi }
import from jaclang.compiler.passes.native.llvm.binding.common { _encode_string }
import from ctypes { c_char_p }
"""
    Set the given LLVM "command-line" option.

    For example set_option("test", "-debug-pass=Structure") would display
    all optimization passes when generating code.
    """
def set_option(name: Any, option: Any) -> object {
    ffi.lib.LLVMPY_SetCommandLine(_encode_string(name), _encode_string(option));
}

with entry {
    ffi.lib.LLVMPY_SetCommandLine.argtypes = [c_char_p, c_char_p];
}

