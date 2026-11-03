"""Create a module from LLVM IR text."""
def parse_assembly(llvmir: str, context: (ContextRef | None) = None) -> ModuleRef {
    owner = context if context is not None else get_global_context();
    err: ptr[u8] = ptr[u8]();
    handle = LLVMPY_ParseAssembly(owner.live(), llvmir, &mut err);
    if err {
        message = take_text(err);
        if handle {
            LLVMPY_DisposeModule(handle);
        }
        raise RuntimeError(
            "LLVM IR parsing error\n" + message + _parse_error_context(llvmir, message)
        );
    }
    return ModuleRef(handle, owner);
}

"""The IR lines a parse error points at.

LLVM reports `<string>:LINE:COL`. A unit's IR runs to millions of lines and is
not kept once the parse fails, so the message quotes the line and its two
neighbours: that is what names the function or global at fault."""
def _parse_error_context(llvmir: str, message: str) -> str {
    marker = message.find("<string>:");
    if marker < 0 {
        return "";
    }
    digits = "";
    for character in message[marker + 9:] {
        if not character.isdigit() {
            break;
        }
        digits += character;
    }
    if not digits {
        return "";
    }
    wanted = int(digits);
    lines = llvmir.split("\n");
    first = max(wanted - 1, 1);
    rows: list[str] = [];
    for number in range(first, min(first + 3, len(lines) + 1)) {
        rows.append(f"  {number}: {lines[number - 1][:400]}");
    }
    return "\nIR at that position:\n" + "\n".join(rows);
}

"""Create a module from LLVM bitcode."""
def parse_bitcode(bitcode: bytes, context: (ContextRef | None) = None) -> ModuleRef {
    owner = context if context is not None else get_global_context();
    err: ptr[u8] = ptr[u8]();
    handle = LLVMPY_ParseBitcode(owner.live(), bitcode, u64(len(bitcode)), &mut err);
    if err {
        message = take_text(err);
        if handle {
            LLVMPY_DisposeModule(handle);
        }
        raise RuntimeError("LLVM bitcode parsing error\n" + message);
    }
    return ModuleRef(handle, owner);
}

"""An owned LLVM module."""
class ModuleRef(ObjectRef) {
    has context: (ContextRef | None) = None;

    def init(self: ModuleRef, handle: ptr, context: (ContextRef | None) = None) {
        super.init(handle);
        self.context = context;
    }

    def _dispose(self: ModuleRef) {
        LLVMPY_DisposeModule(self.handle);
    }

    def __str__(self: ModuleRef) -> str {
        out: ptr[u8] = ptr[u8]();
        LLVMPY_PrintModuleToString(self.live(), &mut out);
        return take_text(out);
    }

    def as_bitcode(self: ModuleRef) -> bytes {
        out: ptr[u8] = ptr[u8]();
        size: u64 = u64(0);
        LLVMPY_WriteBitcodeToString(self.live(), &mut out, &mut size);
        if not out {
            raise MemoryError("LLVM wrote no bitcode");
        }
        return take_bytes(out, int(size));
    }

    """Split the module into `parts` linkable partitions and return each as
    bitcode, for code generation on separate threads. The module is consumed:
    its local symbols are renamed and made hidden globals."""
    def split_bitcode(self: ModuleRef, parts: int) -> list[bytes] {
        buffers = ptr[ptr[u8]](malloc(u64(8 * parts)));
        sizes = ptr[u64](malloc(u64(8 * parts)));
        if not buffers or not sizes {
            raise MemoryError("cannot allocate the bitcode partitions");
        }
        LLVMPY_SplitModuleBitcode(self.live(), u32(parts), buffers, sizes);
        out: list[bytes] = [];
        buffer_cells = buffers.view(parts);
        size_cells = sizes.view(parts);
        failed = False;
        for index in range(parts) {
            address = buffer_cells[index];
            if not address {
                failed = True;
                continue;
            }
            out.append(take_bytes(address, int(size_cells[index])));
        }
        free(ptr(buffers));
        free(ptr(sizes));
        if failed {
            raise MemoryError("LLVM wrote no bitcode for a partition");
        }
        return out;
    }

    def get_function(self: ModuleRef, name: str) -> ValueRef {
        handle = LLVMPY_GetNamedFunction(self.live(), name);
        if not handle {
            raise NameError(name);
        }
        return ValueRef(handle, "function", self);
    }

    def get_global_variable(self: ModuleRef, name: str) -> ValueRef {
        handle = LLVMPY_GetNamedGlobalVariable(self.live(), name);
        if not handle {
            raise NameError(name);
        }
        return ValueRef(handle, "global", self);
    }

    def verify(self: ModuleRef) {
        out: ptr[u8] = ptr[u8]();
        failed = LLVMPY_VerifyModule(self.live(), &mut out);
        message = take_text(out);
        if failed {
            raise RuntimeError(message);
        }
    }

    has name: str {
        getter {
            return c_text(LLVMPY_GetModuleName(self.live()));
        }
        setter(self: ModuleRef, value: str) {
            LLVMPY_SetModuleName(self.live(), value);
        }
    }

    has data_layout: str {
        getter {
            out: ptr[u8] = ptr[u8]();
            LLVMPY_GetDataLayout(self.live(), &mut out);
            return c_text(out);
        }
        setter(self: ModuleRef, value: str) {
            LLVMPY_SetDataLayout(self.live(), value);
        }
    }

    has triple: str {
        getter {
            out: ptr[u8] = ptr[u8]();
            LLVMPY_GetTarget(self.live(), &mut out);
            return c_text(out);
        }
        setter(self: ModuleRef, value: str) {
            LLVMPY_SetTarget(self.live(), value);
        }
    }

    """Link `other` into this module; `other` is consumed unless `preserve`."""
    def link_in(self: ModuleRef, other: ModuleRef, preserve: bool = False) {
        link_modules(self, other.clone() if preserve else other);
    }

    has global_variables: list[ValueRef] {
        getter {
            iterator = LLVMPY_ModuleGlobalsIter(self.live());
            found: list[ValueRef] = [];
            handle = LLVMPY_GlobalsIterNext(iterator);
            while handle {
                found.append(ValueRef(handle, "global", self));
                handle = LLVMPY_GlobalsIterNext(iterator);
            }
            LLVMPY_DisposeGlobalsIter(iterator);
            return found;
        }
    }

    has functions: list[ValueRef] {
        getter {
            iterator = LLVMPY_ModuleFunctionsIter(self.live());
            found: list[ValueRef] = [];
            handle = LLVMPY_FunctionsIterNext(iterator);
            while handle {
                found.append(ValueRef(handle, "function", self));
                handle = LLVMPY_FunctionsIterNext(iterator);
            }
            LLVMPY_DisposeFunctionsIter(iterator);
            return found;
        }
    }

    def clone(self: ModuleRef) -> ModuleRef {
        return ModuleRef(LLVMPY_CloneModule(self.live()), self.context);
    }
}
