import os;
import from ctypes {
    POINTER,
    c_char_p,
    c_longlong,
    c_int,
    c_size_t,
    c_void_p,
    string_at
}
import from jaclang.compiler.passes.native.llvm.binding { ffi }
import from jaclang.compiler.passes.native.llvm.binding.initfini { llvm_version_info }
import from jaclang.compiler.passes.native.llvm.binding.common {
    _decode_string,
    _encode_string
}
import from collections { namedtuple }
import from jaclang.compiler.passes.native.llvm.binding.config { _has_svml as has_svml }
with entry {
    Triple = namedtuple(
        'Triple', ['Arch', 'SubArch', 'Vendor', 'OS', 'Env', 'ObjectFormat']
    );
}

def get_process_triple() -> object {
    with ffi.OutputString() as out {
        ffi.lib.LLVMPY_GetProcessTriple(out);
        return str(out);
    }
}

def get_triple_parts(triple: str) -> object {
    with ffi.OutputString() as arch, ffi.OutputString() as vendor, ffi.OutputString() as os, ffi.OutputString() as env {
        ffi.lib.LLVMPY_GetTripleParts(triple.encode('utf8'), arch, vendor, os, env);
        arch = str(arch);
        subarch = '';
        for _str in triple.split('-') {
            if _str.startswith(arch) {
                subarch = _str[len(arch):];
                break;
            }
        }
        return Triple(
            arch, subarch, str(vendor), str(os), str(env), get_object_format(triple)
        );
    }
}

class FeatureMap(`dict) {
    def flatten(self: FeatureMap, sort: Any = True) -> object {
        iterator = sorted(self.items()) if sort else iter(self.items());
        flag_map = {True: '+', False: '-'};
        return ','.join('{0}{1}'.format(flag_map[v], k) for (k, v) in iterator);
    }
}


def get_host_cpu_features() -> object {
    with ffi.OutputString() as out {
        outdict = FeatureMap();
        if not ffi.lib.LLVMPY_GetHostCPUFeatures(out) {
            return outdict;
        }
        flag_map = {'+': True, '-': False};
        content = str(out);
        if content {
            for feat in content.split(',') {
                if feat {
                    outdict[feat[1:]] = flag_map[feat[0]];
                }
            }
        }
        return outdict;
    }
}

def get_default_triple() -> object {
    with ffi.OutputString() as out {
        ffi.lib.LLVMPY_GetDefaultTargetTriple(out);
        return str(out);
    }
}

def get_host_cpu_name() -> object {
    with ffi.OutputString() as out {
        ffi.lib.LLVMPY_GetHostCPUName(out);
        return str(out);
    }
}

with entry {
    llvm_version_major = llvm_version_info[0];
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
}

def get_object_format(triple: Any = None) -> object {
    if (triple is None) {
        triple = get_default_triple();
    }
    res = ffi.lib.LLVMPY_GetTripleObjectFormat(_encode_string(triple));
    return _object_formats[res];
}

def create_target_data(layout: Any) -> object {
    return TargetData(ffi.lib.LLVMPY_CreateTargetData(_encode_string(layout)));
}

class TargetData(ffi.ObjectRef) {
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

    def get_abi_size(self: TargetData, ty: Any) -> object {
        return ffi.lib.LLVMPY_ABISizeOfType(self, ty);
    }

    def get_element_offset(self: TargetData, ty: Any, position: Any) -> object {
        offset = ffi.lib.LLVMPY_OffsetOfElement(self, ty, position);
        if (offset == -1) {
            raise ValueError(
                "Could not determined offset of {}th " "type?".format(position, str(ty))
            );
        }
        return offset;
    }

    def get_abi_alignment(self: TargetData, ty: Any) -> object {
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

    @classmethod
    def from_default_triple(cls: Any) -> object {
        triple = get_default_triple();
        return cls.from_triple(triple);
    }

    @classmethod
    def from_triple(cls: Any, triple: Any) -> object {
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
    def triple(self: Target) -> object {
        return self._triple;
    }

    def __str__(self: Target) -> object {
        return "<Target {0} ({1})>".format(self.name, self.description);
    }

    def create_target_machine(
        self: Target,
        cpu: Any = '',
        features: Any = '',
        opt: Any = 2,
        reloc: Any = 'default',
        codemodel: Any = 'jitdefault',
        printmc: Any = False,
        jit: Any = False,
        abiname: Any = ''
    ) -> object {
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

    def add_analysis_passes(self: TargetMachine, pm: Any) -> object {
        ffi.lib.LLVMPY_AddAnalysisPasses(self, pm);
    }

    def set_asm_verbosity(self: TargetMachine, verbose: Any) -> object {
        ffi.lib.LLVMPY_SetTargetMachineAsmVerbosity(self, verbose);
    }

    def emit_object(self: TargetMachine, module: Any) -> object {
        return self._emit_to_memory(module, use_object=True);
    }

    def emit_assembly(self: TargetMachine, module: Any) -> object {
        return _decode_string(self._emit_to_memory(module, use_object=False));
    }

    def _emit_to_memory(
        self: TargetMachine, module: Any, use_object: Any = False
    ) -> object {
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
    def triple(self: TargetMachine) -> object {
        with ffi.OutputString() as out {
            ffi.lib.LLVMPY_GetTargetMachineTriple(self, out);
            return str(out);
        }
    }
}

with entry {
    ffi.lib.LLVMPY_GetProcessTriple.argtypes = [POINTER(c_char_p)];
    ffi.lib.LLVMPY_GetTripleParts.argtypes = [
        c_char_p,
        POINTER(c_char_p),
        POINTER(c_char_p),
        POINTER(c_char_p),
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_GetHostCPUFeatures.argtypes = [POINTER(c_char_p)];
    ffi.lib.LLVMPY_GetHostCPUFeatures.restype = c_int;
    ffi.lib.LLVMPY_GetDefaultTargetTriple.argtypes = [POINTER(c_char_p)];
    ffi.lib.LLVMPY_GetHostCPUName.argtypes = [POINTER(c_char_p)];
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
