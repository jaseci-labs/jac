enum Linkage {
    external = 0,
    available_externally = 1,
    linkonce_any = 2,
    linkonce_odr = 3,
    linkonce_odr_autohide = 4,
    weak_any = 5,
    weak_odr = 6,
    appending = 7,
    internal = 8,
    private = 9,
    dllimport = 10,
    dllexport = 11,
    external_weak = 12,
    ghost = 13,
    common = 14,
    linker_private = 15,
    linker_private_weak = 16
}

enum Visibility { `default = 0, hidden = 1, protected = 2 }

glob LINKAGES: list[Linkage] = [
         Linkage.external,
         Linkage.available_externally,
         Linkage.linkonce_any,
         Linkage.linkonce_odr,
         Linkage.linkonce_odr_autohide,
         Linkage.weak_any,
         Linkage.weak_odr,
         Linkage.appending,
         Linkage.internal,
         Linkage.private,
         Linkage.dllimport,
         Linkage.dllexport,
         Linkage.external_weak,
         Linkage.ghost,
         Linkage.common,
         Linkage.linker_private,
         Linkage.linker_private_weak
     ],
     VISIBILITIES: list[Visibility] = [
         Visibility.`default,
         Visibility.hidden,
         Visibility.protected
     ];

"""A borrowed reference to a value inside a module: the module owns it."""
class ValueRef(ObjectRef) {
    has kind: str = "",
        owner: any = None;

    def init(self: ValueRef, handle: ptr, kind: str, owner: any = None) {
        super.init(handle);
        self.kind = kind;
        self.owner = owner;
    }

    def __str__(self: ValueRef) -> str {
        out: ptr[u8] = ptr[u8]();
        LLVMPY_PrintValueToString(self.live(), &mut out);
        return take_text(out);
    }

    has is_function: bool {
        getter {
            return self.kind == "function";
        }
    }

    has is_global: bool {
        getter {
            return self.kind == "global";
        }
    }

    has name: str {
        getter {
            return c_text(LLVMPY_GetValueName(self.live()));
        }
        setter(self: ValueRef, value: str) {
            LLVMPY_SetValueName(self.live(), value);
        }
    }

    has linkage: Linkage {
        getter {
            return LINKAGES[int(LLVMPY_GetLinkage(self.live()))];
        }
        setter(self: ValueRef, value: Linkage) {
            LLVMPY_SetLinkage(self.live(), i32(value.value));
        }
    }

    has visibility: Visibility {
        getter {
            return VISIBILITIES[int(LLVMPY_GetVisibility(self.live()))];
        }
        setter(self: ValueRef, value: Visibility) {
            LLVMPY_SetVisibility(self.live(), i32(value.value));
        }
    }

    has is_declaration: bool {
        getter {
            if not (self.is_global or self.is_function) {
                raise ValueError(f"expected a global or function value, got {self.kind}");
            }
            return LLVMPY_IsDeclaration(self.live()) != 0;
        }
    }

    has global_value_type: str {
        getter {
            if not (self.is_global or self.is_function) {
                raise ValueError(f"expected a global or function value, got {self.kind}");
            }
            return take_text(LLVMPY_PrintType(LLVMPY_GlobalGetValueType(self.live())));
        }
    }

    def function_signature(self: ValueRef) -> tuple[str, list[str], bool] {
        if not self.is_function {
            raise TypeError("a function signature needs a function value");
        }
        function_type = LLVMPY_GlobalGetValueType(self.live());
        result = take_text(LLVMPY_PrintType(LLVMPY_GetReturnType(function_type)));
        count = int(LLVMPY_CountParamTypes(function_type));
        parameters: list[str] = [];
        if count > 0 {
            table = ptr[ptr](malloc(u64(8 * count)));
            if not table {
                raise MemoryError("cannot allocate LLVM parameter types");
            }
            LLVMPY_GetParamTypes(function_type, table);
            cells = table.view(count);
            for index in range(count) {
                parameters.append(take_text(LLVMPY_PrintType(cells[index])));
            }
            free(ptr(table));
        }
        return (result, parameters, LLVMPY_IsFunctionVararg(function_type) != 0);
    }
}
