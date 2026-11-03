glob RELOC: list[str] = ["default", "static", "pic", "dynamicnopic"],
     CODEMODEL: list[str] = [
         "default",
         "jitdefault",
         "small",
         "kernel",
         "medium",
         "large"
     ];

def get_default_triple -> str {
    out: ptr[u8] = ptr[u8]();
    LLVMPY_GetDefaultTargetTriple(&mut out);
    return take_text(out);
}

def create_target_data(layout: str) -> TargetData {
    return TargetData(LLVMPY_CreateTargetData(layout));
}

"""Structured access to a data layout."""
class TargetData(ObjectRef) {
    def _dispose(self: TargetData) {
        LLVMPY_DisposeTargetData(self.handle);
    }

    def __str__(self: TargetData) -> str {
        out: ptr[u8] = ptr[u8]();
        LLVMPY_CopyStringRepOfTargetData(self.live(), &mut out);
        return take_text(out);
    }

    def get_abi_size(self: TargetData, type_ref: ptr) -> int {
        return int(LLVMPY_ABISizeOfType(self.live(), type_ref));
    }

    def get_element_offset(self: TargetData, type_ref: ptr, position: int) -> int {
        offset = LLVMPY_OffsetOfElement(self.live(), type_ref, i32(position));
        if offset == -1 {
            raise ValueError(
                f"cannot find the offset of element {position}: the type is not a struct"
            );
        }
        return int(offset);
    }

    def get_abi_alignment(self: TargetData, type_ref: ptr) -> int {
        return int(LLVMPY_ABIAlignmentOfType(self.live(), type_ref));
    }

    """A global's struct layout, read while its module is alive: the field
    offsets and the struct's ABI size."""
    def get_global_struct_layout(
        self: TargetData, value: ValueRef, field_count: int
    ) -> tuple[list[int], int] {
        struct_type = LLVMPY_GlobalGetValueType(value.live());
        offsets: list[int] = [];
        for index in range(field_count) {
            offsets.append(self.get_element_offset(struct_type, index));
        }
        return (offsets, self.get_abi_size(struct_type));
    }
}

class Target(ObjectRef) {
    has target_triple: str = "";

    def init(self: Target, handle: ptr, target_triple: str) {
        super.init(handle);
        self.target_triple = target_triple;
    }

    static def from_triple(triple: str) -> Target {
        err: ptr[u8] = ptr[u8]();
        handle = LLVMPY_GetTargetFromTriple(triple, &mut err);
        if not handle {
            raise RuntimeError(take_text(err));
        }
        return Target(handle, triple);
    }

    static def from_default_triple -> Target {
        return Target.from_triple(get_default_triple());
    }

    has name: str {
        getter {
            return c_text(LLVMPY_GetTargetName(self.live()));
        }
    }

    has description: str {
        getter {
            return c_text(LLVMPY_GetTargetDescription(self.live()));
        }
    }

    has triple: str {
        getter {
            return self.target_triple;
        }
    }

    def __str__(self: Target) -> str {
        return f"<Target {self.name} ({self.description})>";
    }

    def create_target_machine(
        self: Target,
        cpu: str = "",
        features: str = "",
        opt: int = 2,
        reloc: str = "default",
        codemodel: str = "jitdefault",
        printmc: bool = False,
        jit: bool = False,
        abiname: str = ""
    ) -> TargetMachine {
        if opt < 0 or opt > 3 {
            raise ValueError(f"optimization level {opt} is not 0 to 3");
        }
        if reloc not in RELOC {
            raise ValueError(f"unknown relocation model '{reloc}'");
        }
        if codemodel not in CODEMODEL {
            raise ValueError(f"unknown code model '{codemodel}'");
        }
        triple = self.target_triple;
        if codemodel == "jitdefault" and "windows" in triple {
            triple += "-elf";
        }
        handle = LLVMPY_CreateTargetMachine(
            self.live(),
            triple,
            cpu,
            features,
            i32(opt),
            reloc,
            codemodel,
            i32(1 if printmc else 0),
            i32(1 if jit else 0),
            abiname
        );
        if not handle {
            raise RuntimeError("LLVM cannot create a target machine for " + triple);
        }
        return TargetMachine(handle);
    }
}

class TargetMachine(ObjectRef) {
    def _dispose(self: TargetMachine) {
        LLVMPY_DisposeTargetMachine(self.handle);
    }

    def set_asm_verbosity(self: TargetMachine, verbose: bool) {
        LLVMPY_SetTargetMachineAsmVerbosity(self.live(), i32(1 if verbose else 0));
    }

    """The module as an object file for the platform's linker. Private
    functions are emitted with internal linkage, which generates the same
    code but keeps a local symbol, so a debugger or crash handler can name
    the function a fault is in."""
    def emit_object(self: TargetMachine, module: ModuleRef) -> bytes {
        for function in module.functions {
            if not function.is_declaration and function.linkage == Linkage.private {
                function.linkage = Linkage.internal;
            }
        }
        return self._emit_to_memory(module, True);
    }

    def emit_assembly(self: TargetMachine, module: ModuleRef) -> str {
        return self._emit_to_memory(module, False).decode("utf-8");
    }

    def _emit_to_memory(self: TargetMachine, module: ModuleRef, use_object: bool) -> bytes {
        err: ptr[u8] = ptr[u8]();
        buffer = LLVMPY_TargetMachineEmitToMemory(
            self.live(), module.live(), i32(1 if use_object else 0), &mut err
        );
        if not buffer {
            raise RuntimeError(take_text(err));
        }
        data = c_bytes(
            LLVMPY_GetBufferStart(buffer), int(LLVMPY_GetBufferSize(buffer))
        );
        LLVMPY_DisposeMemoryBuffer(buffer);
        return data;
    }

    has target_data: TargetData {
        getter {
            return TargetData(LLVMPY_CreateTargetMachineData(self.live()));
        }
    }

    has triple: str {
        getter {
            out: ptr[u8] = ptr[u8]();
            LLVMPY_GetTargetMachineTriple(self.live(), &mut out);
            return take_text(out);
        }
    }
}
