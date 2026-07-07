import from ctypes {
    c_char_p,
    byref,
    POINTER,
    c_bool,
    create_string_buffer,
    c_size_t,
    string_at
}
import from jaclang.compiler.passes.native.llvm.binding { ffi }
import from jaclang.compiler.passes.native.llvm.binding.linker { link_modules }
import from jaclang.compiler.passes.native.llvm.binding.common { _decode_string, _encode_string }
import from jaclang.compiler.passes.native.llvm.binding.value { ValueRef }
import from jaclang.compiler.passes.native.llvm.binding.context { get_global_context }
"""
    Create Module from a LLVM IR string
    """
def parse_assembly(llvmir: Any, context: Any = None) -> object {
    if (context is None) {
        context = get_global_context();
    }
    llvmir = _encode_string(llvmir);
    strbuf = c_char_p(llvmir);
    with ffi.OutputString() as errmsg {
        mod = ModuleRef(ffi.lib.LLVMPY_ParseAssembly(context, strbuf, errmsg), context);
        if errmsg {
            mod.close();
            raise RuntimeError("LLVM IR parsing error\n{0}".format(errmsg));
        }
    }
    return mod;
}

"""
    Create Module from a LLVM *bitcode* (a bytes object).
    """
def parse_bitcode(bitcode: Any, context: Any = None) -> object {
    if (context is None) {
        context = get_global_context();
    }
    buf = c_char_p(bitcode);
    bufsize = len(bitcode);
    with ffi.OutputString() as errmsg {
        mod = ModuleRef(
            ffi.lib.LLVMPY_ParseBitcode(context, buf, bufsize, errmsg), context
        );
        if errmsg {
            mod.close();
            raise RuntimeError("LLVM bitcode parsing error\n{0}".format(errmsg));
        }
    }
    return mod;
}

"""
    A reference to a LLVM module.
    """
class ModuleRef(ffi.ObjectRef) {
    def init(self: ModuleRef, module_ptr: Any, context: Any) -> object {
        super.init(module_ptr);
        self._context = context;
    }
    def __str__(self: ModuleRef) -> object {
        with ffi.OutputString() as outstr {
            ffi.lib.LLVMPY_PrintModuleToString(self, outstr);
            return str(outstr);
        }
    }
    """
        Return the module's LLVM bitcode, as a bytes object.
        """
    def as_bitcode(self: ModuleRef) -> object {
        ptr = c_char_p(None);
        size = c_size_t(-1);
        ffi.lib.LLVMPY_WriteBitcodeToString(self, byref(ptr), byref(size));
        if not ptr {
            raise MemoryError;
        }
        try {
            assert (size.value >= 0);
            return string_at(ptr, size.value);
        } finally {
            ffi.lib.LLVMPY_DisposeString(ptr);
        }
    }

    def _dispose(self: ModuleRef) -> object {
        self._capi.LLVMPY_DisposeModule(self);
    }
    """
        Get a ValueRef pointing to the function named *name*.
        NameError is raised if the symbol isn't found.
        """
    def get_function(self: ModuleRef, name: Any) -> object {
        p = ffi.lib.LLVMPY_GetNamedFunction(self, _encode_string(name));
        if not p {
            raise NameError(name);
        }
        return ValueRef(p, 'function', `dict(module=self));
    }

    """
        Get a ValueRef pointing to the global variable named *name*.
        NameError is raised if the symbol isn't found.
        """
    def get_global_variable(self: ModuleRef, name: Any) -> object {
        p = ffi.lib.LLVMPY_GetNamedGlobalVariable(self, _encode_string(name));
        if not p {
            raise NameError(name);
        }
        return ValueRef(p, 'global', `dict(module=self));
    }

    """
        Verify the module IR's correctness.  RuntimeError is raised on error.
        """
    def verify(self: ModuleRef) -> object {
        with ffi.OutputString() as outmsg {
            if ffi.lib.LLVMPY_VerifyModule(self, outmsg) {
                raise RuntimeError(str(outmsg));
            }
        }
    }

    """
        The module's identifier.
        """
    @property
    def name(self: ModuleRef) -> object {
        return _decode_string(ffi.lib.LLVMPY_GetModuleName(self));
    }

    @name.setter
    def name(self: ModuleRef, value: Any) -> object {
        ffi.lib.LLVMPY_SetModuleName(self, _encode_string(value));
    }
    """
        The module's original source file name
        """
    @property
    def source_file(self: ModuleRef) -> object {
        return _decode_string(ffi.lib.LLVMPY_GetModuleSourceFileName(self));
    }

    """
        This module's data layout specification, as a string.
        """
    @property
    def data_layout(self: ModuleRef) -> object {
        with ffi.OutputString(owned=False) as outmsg {
            ffi.lib.LLVMPY_GetDataLayout(self, outmsg);
            return str(outmsg);
        }
    }

    @data_layout.setter
    def data_layout(self: ModuleRef, strrep: Any) -> object {
        ffi.lib.LLVMPY_SetDataLayout(self, create_string_buffer(strrep.encode('utf8')));
    }
    """
        This module's target "triple" specification, as a string.
        """
    @property
    def triple(self: ModuleRef) -> object {
        with ffi.OutputString(owned=False) as outmsg {
            ffi.lib.LLVMPY_GetTarget(self, outmsg);
            return str(outmsg);
        }
    }

    @triple.setter
    def triple(self: ModuleRef, strrep: Any) -> object {
        ffi.lib.LLVMPY_SetTarget(self, create_string_buffer(strrep.encode('utf8')));
    }
    """
        Link the *other* module into this one.  The *other* module will
        be destroyed unless *preserve* is true.
        """
    def link_in(self: ModuleRef, other: Any, preserve: Any = False) -> object {
        if preserve {
            other = other.clone();
        }
        link_modules(self, other);
    }

    """
        Return an iterator over this module's global variables.
        The iterator will yield a ValueRef for each global variable.

        Note that global variables don't include functions
        (a function is a "global value" but not a "global variable" in
         LLVM parlance)
        """
    @property
    def global_variables(self: ModuleRef) -> object {
        it = ffi.lib.LLVMPY_ModuleGlobalsIter(self);
        return _GlobalsIterator(it, `dict(module=self));
    }

    """
        Return an iterator over this module's functions.
        The iterator will yield a ValueRef for each function.
        """
    @property
    def functions(self: ModuleRef) -> object {
        it = ffi.lib.LLVMPY_ModuleFunctionsIter(self);
        return _FunctionsIterator(it, `dict(module=self));
    }

    def clone(self: ModuleRef) -> object {
        return ModuleRef(ffi.lib.LLVMPY_CloneModule(self), self._context);
    }
}

class _Iterator(ffi.ObjectRef) {
    with entry {
        kind = None;
    }

    def init(self: _Iterator, ptr: Any, parents: Any) -> object {
        ffi.ObjectRef.init(self, ptr);
        self._parents = parents;
        assert (self.kind is not None);
    }
    def __next__(self: _Iterator) -> object {
        vp = self._next();
        if vp {
            return ValueRef(vp, self.kind, self._parents);
        } else {
            raise StopIteration;
        }
    }

    with entry {
        next = __next__;
    }

    def __iter__(self: _Iterator) -> object {
        return self;
    }
}
class _GlobalsIterator(_Iterator) {
    with entry {
        kind = 'global';
    }

    def _dispose(self: _GlobalsIterator) -> object {
        self._capi.LLVMPY_DisposeGlobalsIter(self);
    }
    def _next(self: _GlobalsIterator) -> object {
        return ffi.lib.LLVMPY_GlobalsIterNext(self);
    }
}
class _FunctionsIterator(_Iterator) {
    with entry {
        kind = 'function';
    }

    def _dispose(self: _FunctionsIterator) -> object {
        self._capi.LLVMPY_DisposeFunctionsIter(self);
    }
    def _next(self: _FunctionsIterator) -> object {
        return ffi.lib.LLVMPY_FunctionsIterNext(self);
    }
}
with entry {
    ffi.lib.LLVMPY_ParseAssembly.argtypes = [
        ffi.LLVMContextRef,
        c_char_p,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_ParseAssembly.restype = ffi.LLVMModuleRef;
    ffi.lib.LLVMPY_ParseBitcode.argtypes = [
        ffi.LLVMContextRef,
        c_char_p,
        c_size_t,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_ParseBitcode.restype = ffi.LLVMModuleRef;
    ffi.lib.LLVMPY_DisposeModule.argtypes = [ffi.LLVMModuleRef];
    ffi.lib.LLVMPY_PrintModuleToString.argtypes = [
        ffi.LLVMModuleRef,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_WriteBitcodeToString.argtypes = [
        ffi.LLVMModuleRef,
        POINTER(c_char_p),
        POINTER(c_size_t)
    ];
    ffi.lib.LLVMPY_GetNamedFunction.argtypes = [ffi.LLVMModuleRef, c_char_p];
    ffi.lib.LLVMPY_GetNamedFunction.restype = ffi.LLVMValueRef;
    ffi.lib.LLVMPY_VerifyModule.argtypes = [ffi.LLVMModuleRef, POINTER(c_char_p)];
    ffi.lib.LLVMPY_VerifyModule.restype = c_bool;
    ffi.lib.LLVMPY_GetDataLayout.argtypes = [ffi.LLVMModuleRef, POINTER(c_char_p)];
    ffi.lib.LLVMPY_SetDataLayout.argtypes = [ffi.LLVMModuleRef, c_char_p];
    ffi.lib.LLVMPY_GetTarget.argtypes = [ffi.LLVMModuleRef, POINTER(c_char_p)];
    ffi.lib.LLVMPY_SetTarget.argtypes = [ffi.LLVMModuleRef, c_char_p];
    ffi.lib.LLVMPY_GetNamedGlobalVariable.argtypes = [ffi.LLVMModuleRef, c_char_p];
    ffi.lib.LLVMPY_GetNamedGlobalVariable.restype = ffi.LLVMValueRef;
    ffi.lib.LLVMPY_ModuleGlobalsIter.argtypes = [ffi.LLVMModuleRef];
    ffi.lib.LLVMPY_ModuleGlobalsIter.restype = ffi.LLVMGlobalsIterator;
    ffi.lib.LLVMPY_DisposeGlobalsIter.argtypes = [ffi.LLVMGlobalsIterator];
    ffi.lib.LLVMPY_GlobalsIterNext.argtypes = [ffi.LLVMGlobalsIterator];
    ffi.lib.LLVMPY_GlobalsIterNext.restype = ffi.LLVMValueRef;
    ffi.lib.LLVMPY_ModuleFunctionsIter.argtypes = [ffi.LLVMModuleRef];
    ffi.lib.LLVMPY_ModuleFunctionsIter.restype = ffi.LLVMFunctionsIterator;
    ffi.lib.LLVMPY_DisposeFunctionsIter.argtypes = [ffi.LLVMFunctionsIterator];
    ffi.lib.LLVMPY_FunctionsIterNext.argtypes = [ffi.LLVMFunctionsIterator];
    ffi.lib.LLVMPY_FunctionsIterNext.restype = ffi.LLVMValueRef;
    ffi.lib.LLVMPY_CloneModule.argtypes = [ffi.LLVMModuleRef];
    ffi.lib.LLVMPY_CloneModule.restype = ffi.LLVMModuleRef;
    ffi.lib.LLVMPY_GetModuleName.argtypes = [ffi.LLVMModuleRef];
    ffi.lib.LLVMPY_GetModuleName.restype = c_char_p;
    ffi.lib.LLVMPY_SetModuleName.argtypes = [ffi.LLVMModuleRef, c_char_p];
    ffi.lib.LLVMPY_GetModuleSourceFileName.argtypes = [ffi.LLVMModuleRef];
    ffi.lib.LLVMPY_GetModuleSourceFileName.restype = c_char_p;
}

