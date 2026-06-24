import os;
import warnings;
import from functools { cache }
import from ctypes { c_int, c_char_p }
import from jaclang.compiler.passes.native.llvm.binding { ffi }
with entry {
    ffi.lib.LLVMPY_HasSVMLSupport.argtypes = ();
    ffi.lib.LLVMPY_HasSVMLSupport.restype = c_int;
    ffi.lib.LLVMPY_IsStaticLibstdcxxLinkageBuild.argtypes = ();
    ffi.lib.LLVMPY_IsStaticLibstdcxxLinkageBuild.restype = c_int;
    ffi.lib.LLVMPY_IsDynamicLLVMLinkageBuild.argtypes = ();
    ffi.lib.LLVMPY_IsDynamicLLVMLinkageBuild.restype = c_int;
    ffi.lib.LLVMPY_PackageFormat.argtypes = ();
    ffi.lib.LLVMPY_PackageFormat.restype = c_char_p;
    ffi.lib.LLVMPY_LlvmAssertionsState.argtypes = ();
    ffi.lib.LLVMPY_LlvmAssertionsState.restype = c_char_p;
}
"""
    Returns True if SVML was enabled at FFI support compile time.
    """
def _has_svml() -> object {
    if (ffi.lib.LLVMPY_HasSVMLSupport() == 0) {
        return False;
    } else {
        return True;
    }
}

with entry {
    has_svml = _has_svml();
}
"""
    Returns "static" if the FFI support is statically linked against LLVM,
    returns "dynamic" otherwise.
    """
def _build_llvm_linkage_type() -> object {
    if (ffi.lib.LLVMPY_IsDynamicLLVMLinkageBuild() == 0) {
        return "static";
    } else {
        return "dynamic";
    }
}

with entry {
    build_llvm_linkage_type = _build_llvm_linkage_type();
}
"""
    Returns "static" if the FFI support is statically linked against libstdc++,
    returns "dynamic" otherwise.
    """
def _build_libstdcxx_linkage_type() -> object {
    if (ffi.lib.LLVMPY_IsStaticLibstdcxxLinkageBuild() == 1) {
        return "static";
    } else {
        return "dynamic";
    }
}

with entry {
    build_libstdcxx_linkage_type = _build_libstdcxx_linkage_type();
}
"""
    Returns "wheel", "conda" or "unspecified"
    """
def _package_format() -> object {
    return ffi.lib.LLVMPY_PackageFormat().decode();
}

with entry {
    package_format = _package_format();
}
"""
    Returns one of "on", "off" or "unknown". Depending on whether it is
    determined that LLVM was build with assertions on, off, or is not known.
    "Is not known" is typically from a dynamic linkage against LLVM in which
    case it's not easily identified whether LLVM was built with assertions.
    """
def _llvm_assertions_state() -> object {
    return ffi.lib.LLVMPY_LlvmAssertionsState().decode();
}

with entry {
    llvm_assertions_state = _llvm_assertions_state();
}
@cache
def get_sysinfo() -> object {
    d = `dict();
    d["ffi_lib_location"] = ffi.lib._name;
    d["package_format"] = package_format;
    d["llvm_linkage_type"] = build_llvm_linkage_type;
    d["libstdcxx_linkage_type"] = build_libstdcxx_linkage_type;
    d["llvm_assertions_state"] = llvm_assertions_state;
    HAVE_LIEF = False;
    try {
        import lief;
        HAVE_LIEF = True;
    } except ImportError {
        msg = "py-lief package not found, sysinfo is limited as a result";
        warnings.warn(msg);
    }
    d["lief_probe_status"] = HAVE_LIEF;
    d["linked_libraries"] = None;
    d["canonicalised_linked_libraries"] = None;
    """Canonicalises the representation of the binary::libraries as a
        sequence of strings""";
    def canonicalise_library_type(dso: Any) -> object {
        return [getattr(x, "name", x) for x in dso.libraries];
    }
    def canonicalise_library_spelling(libs: Any) -> object {
        fixes = [];
        for lib in libs {
            path_stripped = os.path.split(lib)[-1];
            prefix_libname = path_stripped.split(".")[0];
            linker_name = prefix_libname.replace("lib", "").replace("LIB", "");
            fixes.append(linker_name.lower());
        }
        return fixes;
    }
    if HAVE_LIEF {
        dso = lief.parse(d["ffi_lib_location"]);
        link_libs = `tuple(canonicalise_library_type(dso));
        d["linked_libraries"] = link_libs;
        canonicalised_libs = canonicalise_library_spelling(link_libs);
        d["canonicalised_linked_libraries"] = canonicalised_libs;
    }
    return d;
}

