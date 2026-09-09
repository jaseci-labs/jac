import os;
import type from jaclang.compiler.backends.native.llvm.binding.value { ValueRef }
import from ctypes {
    POINTER,
    c_char_p,
    c_longlong,
    c_int,
    c_size_t,
    c_void_p,
    string_at
}
import from jaclang.compiler.backends.native.llvm.binding { ffi }
import from jaclang.compiler.backends.native.llvm.binding.initfini { llvm_version_info }
import from jaclang.compiler.backends.native.llvm.binding.common {
    _decode_string,
    _encode_string
}
import from jaclang.compiler.backends.native.llvm.binding.config {
    _has_svml as has_svml
}

"""
    Return a target triple suitable for generating code for the current process.
    An example when the default triple from ``get_default_triple()`` is not be
    suitable is when LLVM is compiled for 32-bit but the process is executing
    in 64-bit mode.
    """
class FeatureMap(`dict) {
    """
        Args
        ----
        sort: bool
            Optional.  If True, the features are sorted by name; otherwise,
            the ordering is unstable between python session due to hash
            randomization.  Defaults to True.

        Returns a string suitable for use as the ``features`` argument to
        ``Target.create_target_machine()``.

        """
    def flatten(self: FeatureMap, sort: any = True) -> object {
        iterator = sorted(self.items()) if sort else iter(self.items());
        flag_map = {True: '+', False: '-'};
        return ','.join('{0}{1}'.format(flag_map[v], k) for (k, v) in iterator);
    }
}

"""
    Returns a dictionary-like object indicating the CPU features for current
    architecture and whether they are enabled for this CPU.  The key-value pairs
    are the feature name as string and a boolean indicating whether the feature
    is available.  The returned value is an instance of ``FeatureMap`` class,
    which adds a new method ``.flatten()`` for returning a string suitable for
    use as the "features" argument to ``Target.create_target_machine()``.

    If LLVM has not implemented this feature or it fails to get the information,
    this function will raise a RuntimeError exception.
    """
def get_default_triple -> str {
    with ffi.OutputString() as out {
        ffi.lib.LLVMPY_GetDefaultTargetTriple(out);
        return str(out);
    }
}

"""
    Get the name of the host's CPU, suitable for using with
    :meth:`Target.create_target_machine()`.
    """
glob llvm_version_major = llvm_version_info[0],
     _object_formats = {
         0: "Unknown",
         1: "COFF",
         2: "DXContainer",
         3: "ELF",
         4: "GOFF",
         5: "MachO",
         6: "SPIRV",
         7: "Wasm",
         8: "XCOFF"
     };

"""
    Get the object format for the given *triple* string (or the default
    triple if omitted).
    A string is returned
    """
def get_object_format(triple: any = None) -> object {
    if (triple is None) {
        triple = get_default_triple();
    }
    res = ffi.lib.LLVMPY_GetTripleObjectFormat(_encode_string(triple));
    return _object_formats[res];
}

"""
    Create a TargetData instance for the given *layout* string.
    """
def create_target_data(layout: str) -> TargetData {
    return TargetData(ffi.lib.LLVMPY_CreateTargetData(_encode_string(layout)));
}

"""
    A TargetData provides structured access to a data layout.
    Use :func:`create_target_data` to create instances.
    """
class TargetData(ffi.ObjectRef) {
    def get_global_struct_layout(
        self: TargetData, value: ValueRef, field_count: int
    ) -> tuple[list[int], int] {
        """Query a global's struct type while its owning module is alive.""";
        typ = ffi.lib.LLVMPY_GlobalGetValueType(value);
        return (
            [int(self.get_element_offset(typ, i)) for i in range(field_count)],
            int(self.get_abi_size(typ))
        );
    }

    def __str__(self: TargetData) -> object {
        if self._closed {
            return "<dead TargetData>";
        }
        with ffi.OutputString() as out {
            ffi.lib.LLVMPY_CopyStringRepOfTargetData(self, out);
            return str(out);
        }
    }

    def _dispose(self: TargetData) -> object {
        self._capi.LLVMPY_DisposeTargetData(self);
    }

    """
        Get ABI size of LLVM type *ty*.
        """
    def get_abi_size(self: TargetData, ty: any) -> object {
        return ffi.lib.LLVMPY_ABISizeOfType(self, ty);
    }

    """
        Get byte offset of type's ty element at the given position
        """
    def get_element_offset(self: TargetData, ty: any, position: any) -> object {
        offset = ffi.lib.LLVMPY_OffsetOfElement(self, ty, position);
        if (offset == -1) {
            raise ValueError(
                "Could not determined offset of {}th "
                "element of the type '{}'. Is it a struct"
                "type?".format(
                    position, str(ty)
                )
            );
        }
        return offset;
    }

    """
        Get minimum ABI alignment of LLVM type *ty*.
        """
    def get_abi_alignment(self: TargetData, ty: any) -> object {
        return ffi.lib.LLVMPY_ABIAlignmentOfType(self, ty);
    }
}

with entry {
    RELOC = frozenset(['default', 'static', 'pic', 'dynamicnopic']);
    CODEMODEL = frozenset(
        ['default', 'jitdefault', 'small', 'kernel', 'medium', 'large']
    );
}

class Target(ffi.ObjectRef) {
    with entry {
        _triple = '';
    }

    """
        Create a Target instance for the default triple.
        """
    @classmethod
    def from_default_triple(cls: any) -> Target {
        triple = get_default_triple();
        return cls.from_triple(triple);
    }

    """
        Create a Target instance for the given triple (a string).
        """
    @classmethod
    def from_triple(cls: any, triple: any) -> Target {
        with ffi.OutputString() as outerr {
            target = ffi.lib.LLVMPY_GetTargetFromTriple(triple.encode('utf8'), outerr);
            if not target {
                raise RuntimeError(str(outerr));
            }
            target = cls(target);
            target._triple = triple;
            return target;
        }
    }

    @property
    def name(self: Target) -> object {
        s = ffi.lib.LLVMPY_GetTargetName(self);
        return _decode_string(s);
    }

    @property
    def description(self: Target) -> object {
        s = ffi.lib.LLVMPY_GetTargetDescription(self);
        return _decode_string(s);
    }

    @property
    def triple(self: Target) -> str {
        return self._triple;
    }

    def __str__(self: Target) -> object {
        return "<Target {0} ({1})>".format(self.name, self.description);
    }

    """
        Create a new TargetMachine for this target and the given options.

        Specifying codemodel='default' will result in the use of the "small"
        code model. Specifying codemodel='jitdefault' will result in the code
        model being picked based on platform bitness (32="small", 64="large").

        The `printmc` option corresponds to llvm's `-print-machineinstrs`.

        The `jit` option should be set when the target-machine is to be used
        in a JIT engine.

        The `abiname` option specifies the ABI. RISC-V targets with hard-float
        needs to pass the ABI name to LLVM.
        """
    def create_target_machine(
        self: Target,
        cpu: any = '',
        features: any = '',
        opt: any = 2,
        reloc: any = 'default',
        codemodel: any = 'jitdefault',
        printmc: any = False,
        jit: any = False,
        abiname: any = ''
    ) -> TargetMachine {
        assert (0 <= opt <= 3);
        assert (reloc in RELOC);
        assert (codemodel in CODEMODEL);
        triple = self._triple;
        if ((os.name == 'nt') and (codemodel == 'jitdefault')) {
            triple += '-elf';
        }
        tm = ffi.lib.LLVMPY_CreateTargetMachine(
            self,
            _encode_string(triple),
            _encode_string(cpu),
            _encode_string(features),
            opt,
            _encode_string(reloc),
            _encode_string(codemodel),
            int(printmc),
            int(jit),
            _encode_string(abiname)
        );
        if tm {
            return TargetMachine(tm);
        } else {
            raise RuntimeError("Cannot create target machine");
        }
    }
}

class TargetMachine(ffi.ObjectRef) {
    def _dispose(self: TargetMachine) -> object {
        self._capi.LLVMPY_DisposeTargetMachine(self);
    }

    """
        Register analysis passes for this target machine with a pass manager.
        """
    def add_analysis_passes(self: TargetMachine, pm: any) -> object {
        ffi.lib.LLVMPY_AddAnalysisPasses(self, pm);
    }

    """
        Set whether this target machine will emit assembly with human-readable
        comments describing control flow, debug information, and so on.
        """
    def set_asm_verbosity(self: TargetMachine, verbose: any) -> object {
        ffi.lib.LLVMPY_SetTargetMachineAsmVerbosity(self, verbose);
    }

    """
        Represent the module as a code object, suitable for use with
        the platform's linker.  Returns a byte string.
        """
    def emit_object(self: TargetMachine, module: any) -> bytes {
        return self._emit_to_memory(module, use_object=True);
    }

    """
        Return the raw assembler of the module, as a string.

        llvm.initialize_native_asmprinter() must have been called first.
        """
    def emit_assembly(self: TargetMachine, module: any) -> object {
        return _decode_string(self._emit_to_memory(module, use_object=False));
    }

    """Returns bytes of object code of the module.

        Args
        ----
        use_object : bool
            Emit object code or (if False) emit assembly code.
        """
    def _emit_to_memory(
        self: TargetMachine, module: any, use_object: any = False
    ) -> bytes {
        with ffi.OutputString() as outerr {
            mb = ffi.lib.LLVMPY_TargetMachineEmitToMemory(
                self, module, int(use_object), outerr
            );
            if not mb {
                raise RuntimeError(str(outerr));
            }
        }
        bufptr = ffi.lib.LLVMPY_GetBufferStart(mb);
        bufsz = ffi.lib.LLVMPY_GetBufferSize(mb);
        try {
            return string_at(bufptr, bufsz);
        } finally {
            ffi.lib.LLVMPY_DisposeMemoryBuffer(mb);
        }
    }

    @property
    def target_data(self: TargetMachine) -> object {
        return TargetData(ffi.lib.LLVMPY_CreateTargetMachineData(self));
    }

    @property
    def triple(self: TargetMachine) -> str {
        with ffi.OutputString() as out {
            ffi.lib.LLVMPY_GetTargetMachineTriple(self, out);
            return str(out);
        }
    }
}

with entry {
    ffi.lib.LLVMPY_GetTripleParts.argtypes = [
        c_char_p,
        POINTER(c_char_p),
        POINTER(c_char_p),
        POINTER(c_char_p),
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_GetDefaultTargetTriple.argtypes = [POINTER(c_char_p)];
    ffi.lib.LLVMPY_GetTripleObjectFormat.argtypes = [c_char_p];
    ffi.lib.LLVMPY_GetTripleObjectFormat.restype = c_int;
    ffi.lib.LLVMPY_CreateTargetData.argtypes = [c_char_p];
    ffi.lib.LLVMPY_CreateTargetData.restype = ffi.LLVMTargetDataRef;
    ffi.lib.LLVMPY_CopyStringRepOfTargetData.argtypes = [
        ffi.LLVMTargetDataRef,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_DisposeTargetData.argtypes = [ffi.LLVMTargetDataRef];
    ffi.lib.LLVMPY_ABISizeOfType.argtypes = [ffi.LLVMTargetDataRef, ffi.LLVMTypeRef];
    ffi.lib.LLVMPY_ABISizeOfType.restype = c_longlong;
    ffi.lib.LLVMPY_OffsetOfElement.argtypes = [
        ffi.LLVMTargetDataRef,
        ffi.LLVMTypeRef,
        c_int
    ];
    ffi.lib.LLVMPY_OffsetOfElement.restype = c_longlong;
    ffi.lib.LLVMPY_ABIAlignmentOfType.argtypes = [
        ffi.LLVMTargetDataRef,
        ffi.LLVMTypeRef
    ];
    ffi.lib.LLVMPY_ABIAlignmentOfType.restype = c_longlong;
    ffi.lib.LLVMPY_GetTargetFromTriple.argtypes = [c_char_p, POINTER(c_char_p)];
    ffi.lib.LLVMPY_GetTargetFromTriple.restype = ffi.LLVMTargetRef;
    ffi.lib.LLVMPY_GetTargetName.argtypes = [ffi.LLVMTargetRef];
    ffi.lib.LLVMPY_GetTargetName.restype = c_char_p;
    ffi.lib.LLVMPY_GetTargetDescription.argtypes = [ffi.LLVMTargetRef];
    ffi.lib.LLVMPY_GetTargetDescription.restype = c_char_p;
    ffi.lib.LLVMPY_CreateTargetMachine.argtypes = [
        ffi.LLVMTargetRef,
        c_char_p,
        c_char_p,
        c_char_p,
        c_int,
        c_char_p,
        c_char_p,
        c_int,
        c_int,
        c_char_p
    ];
    ffi.lib.LLVMPY_CreateTargetMachine.restype = ffi.LLVMTargetMachineRef;
    ffi.lib.LLVMPY_DisposeTargetMachine.argtypes = [ffi.LLVMTargetMachineRef];
    ffi.lib.LLVMPY_GetTargetMachineTriple.argtypes = [
        ffi.LLVMTargetMachineRef,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_SetTargetMachineAsmVerbosity.argtypes = [
        ffi.LLVMTargetMachineRef,
        c_int
    ];
    ffi.lib.LLVMPY_AddAnalysisPasses.argtypes = [
        ffi.LLVMTargetMachineRef,
        ffi.LLVMPassManagerRef
    ];
    ffi.lib.LLVMPY_TargetMachineEmitToMemory.argtypes = [
        ffi.LLVMTargetMachineRef,
        ffi.LLVMModuleRef,
        c_int,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_TargetMachineEmitToMemory.restype = ffi.LLVMMemoryBufferRef;
    ffi.lib.LLVMPY_GetBufferStart.argtypes = [ffi.LLVMMemoryBufferRef];
    ffi.lib.LLVMPY_GetBufferStart.restype = c_void_p;
    ffi.lib.LLVMPY_GetBufferSize.argtypes = [ffi.LLVMMemoryBufferRef];
    ffi.lib.LLVMPY_GetBufferSize.restype = c_size_t;
    ffi.lib.LLVMPY_DisposeMemoryBuffer.argtypes = [ffi.LLVMMemoryBufferRef];
    ffi.lib.LLVMPY_CreateTargetMachineData.argtypes = [ffi.LLVMTargetMachineRef];
    ffi.lib.LLVMPY_CreateTargetMachineData.restype = ffi.LLVMTargetDataRef;
}
