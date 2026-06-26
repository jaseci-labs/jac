import from ctypes { c_void_p, c_char_p, c_bool, POINTER }
import from jaclang.compiler.passes.native.llvm.binding { ffi }
import from jaclang.compiler.passes.native.llvm.binding.common { _encode_string }
"""
    Get the in-process address of symbol named *name*.
    An integer is returned, or None if the symbol isn't found.
    """
def address_of_symbol(name: Any) -> object {
    return ffi.lib.LLVMPY_SearchAddressOfSymbol(_encode_string(name));
}

"""
    Register the *address* of global symbol *name*.  This will make
    it usable (e.g. callable) from LLVM-compiled functions.
    """
def add_symbol(name: Any, address: Any) -> object {
    ffi.lib.LLVMPY_AddSymbol(_encode_string(name), c_void_p(address));
}

"""
    Load an external library
    """
def load_library_permanently(filename: Any) -> object {
    with ffi.OutputString() as outerr {
        if ffi.lib.LLVMPY_LoadLibraryPermanently(_encode_string(filename), outerr) {
            raise RuntimeError(str(outerr));
        }
    }
}

with entry {
    ffi.lib.LLVMPY_AddSymbol.argtypes = [c_char_p, c_void_p];
    ffi.lib.LLVMPY_SearchAddressOfSymbol.argtypes = [c_char_p];
    ffi.lib.LLVMPY_SearchAddressOfSymbol.restype = c_void_p;
    ffi.lib.LLVMPY_LoadLibraryPermanently.argtypes = [c_char_p, POINTER(c_char_p)];
    ffi.lib.LLVMPY_LoadLibraryPermanently.restype = c_bool;
}

