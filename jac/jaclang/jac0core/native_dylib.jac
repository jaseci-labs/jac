import ctypes;
import from types { SimpleNamespace }

glob NATIVE_ABI_VERSION: int = 1;

obj DylibEngine {
    has lib_path: str,
        _cdll: any = None,
        _initialized: bool = False;

    def postinit {
        self._cdll = ctypes.CDLL(self.lib_path);
    }

    def get_function_address(name: str) -> int {
        try {
            fn = getattr(self._cdll, name);
        } except AttributeError {
            return 0;
        }
        return ctypes.cast(fn, ctypes.c_void_p).value or 0;
    }

    def initialize {
        if self._initialized {
            return;
        }
        addr = self.get_function_address("__jac_shared_init");
        if addr {
            ctypes.CFUNCTYPE(None)(addr)();
        }
        self._initialized = True;
    }
}

def _tuple_layout(d: any) -> any {
    if d is None {
        return None;
    }
    return SimpleNamespace(
        key=d["key"],
        element_types=list(d.get("element_types", [])),
        element_struct_hints=list(d.get("element_struct_hints", []))
    );
}

def _func_layout(d: any) -> any {
    return SimpleNamespace(
        name=d["name"],
        param_types=list(d.get("param_types", [])),
        param_names=list(d.get("param_names", [])),
        ret_type=d.get("ret_type", "i64"),
        ret_struct_name=d.get("ret_struct_name"),
        ret_tuple_layout=_tuple_layout(d.get("ret_tuple_layout")),
        ret_enum_type=d.get("ret_enum_type"),
        ret_elem_keys=d.get("ret_elem_keys")
    );
}

def _field_info(f: any) -> any {
    return SimpleNamespace(
        name=f["name"],
        llvm_type=f["llvm_type"],
        index=f["index"],
        enum_type=f.get("enum_type"),
        is_func_ptr=f.get("is_func_ptr", False),
        func_param_types=f.get("func_param_types"),
        func_ret_type=f.get("func_ret_type"),
        elem_keys=f.get("elem_keys")
    );
}

def layout_from_dict(data: any) -> any {
    stamped = data.get("abi_version");
    if stamped != NATIVE_ABI_VERSION {
        raise ValueError(
            f"sealed native layout has abi_version={stamped}, "
            f"this runtime expects {NATIVE_ABI_VERSION}"
        );
    }
    structs: dict = {};
    structs_raw: any = data.get("structs") or {};
    for (name, s) in structs_raw.items() {
        sd: any = s;
        structs[name] = SimpleNamespace(
            name=sd["name"],
            has_vtable=sd.get("has_vtable", False),
            fields=[_field_info(f) for f in (sd.get("fields") or [])]
        );
    }
    enums: dict = {};
    enums_raw: any = data.get("enums") or {};
    for (name, e) in enums_raw.items() {
        ed: any = e;
        enums[name] = SimpleNamespace(
            name=ed["name"],
            is_string_valued=ed.get("is_string_valued", False),
            members=[
                tuple(m) if isinstance(m, list) else m
                for m in (ed.get("members") or [])
            ]
        );
    }
    functions: dict = {};
    functions_raw: any = data.get("functions") or {};
    for (n, f) in functions_raw.items() {
        functions[n] = _func_layout(f);
    }
    methods: dict = {};
    methods_raw: any = data.get("methods") or {};
    for (n, f) in methods_raw.items() {
        methods[n] = _func_layout(f);
    }
    tuples: dict = {};
    tuples_raw: any = data.get("tuples") or {};
    for (k, t) in tuples_raw.items() {
        tuples[k] = _tuple_layout(t);
    }
    return SimpleNamespace(
        abi_version=stamped,
        structs=structs,
        enums=enums,
        functions=functions,
        methods=methods,
        list_elem_types=dict(data.get("list_elem_types") or {}),
        tuples=tuples,
        tests=[],
        str_headerless=data.get("str_headerless")
    );
}
