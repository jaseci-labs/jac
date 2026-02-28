"""Jac Type Registry implementation.

Populates the registry with all Jac primitive type entries.
Method/operator data derived from the abstract emitter contracts in primitives.jac.
Backend mappings sourced from NA type_map and ES primitive_type_names.
"""

"""Initialize the registry and populate with all primitive type entries."""
impl JacTypeRegistry.init -> None {
    self._entries: dict[str, JacPrimitiveTypeEntry] = {};
    self._builtin_functions: set[str] = set();
    self._populate_primitives();
    self._populate_builtins();
}

"""Register a new primitive type entry."""
impl JacTypeRegistry.register(entry: JacPrimitiveTypeEntry) -> None {
    self._entries[entry.name] = entry;
}

"""Get a type entry by name, or None if not found."""
impl JacTypeRegistry.get(name: str) -> JacPrimitiveTypeEntry | None {
    return self._entries.get(name, None);
}

"""Get the set of all registered primitive type names."""
impl JacTypeRegistry.get_primitive_names -> set[str] {
    return set(self._entries.keys());
}

"""Get type names that have associated emitter classes (excludes bool which inherits)."""
impl JacTypeRegistry.get_type_names_with_emitters -> set[str] {
    result: set[str] = set();
    for (name, entry) in self._entries.items() {
        if entry.emitter_class_name {
            result.add(name);
        }
    }
    return result;
}

"""Check if a type has a specific method."""
impl JacTypeRegistry.has_method(type_name: str, method_name: str) -> bool {
    entry = self._entries.get(type_name, None);
    if entry is None {
        return False;
    }
    if method_name in entry.methods {
        return True;
    }
    # Check inherited methods
    if entry.inherits_from {
        return self.has_method(entry.inherits_from, method_name);
    }
    return False;
}

"""Get the emitter class suffix for a type (e.g., 'IntEmitter' for 'int')."""
impl JacTypeRegistry.get_emitter_class_suffix(type_name: str) -> str {
    entry = self._entries.get(type_name, None);
    if entry is None {
        return "";
    }
    return entry.emitter_class_name;
}

"""Build the NA backend type_map from registry entries."""
impl JacTypeRegistry.build_na_type_map(ir_mod: object) -> dict[str, object] {
    result: dict[str, object] = {};
    for (name, entry) in self._entries.items() {
        spec = entry.backend_mappings.na_llvm_type_spec;
        if spec is None {
            continue;
        }
        if spec == "i64" {
            result[name] = ir_mod.IntType(64);
        } elif spec == "f64" {
            result[name] = ir_mod.DoubleType();
        } elif spec == "i1" {
            result[name] = ir_mod.IntType(1);
        } elif spec == "i8*" {
            result[name] = ir_mod.IntType(8).as_pointer();
        }
    }
    return result;
}

"""Get the set of all registered builtin function names."""
impl JacTypeRegistry.get_builtin_function_names -> set[str] {
    return set(self._builtin_functions);
}

# ─── Private helpers ─────────────────────────────────────────
"""Helper to build a methods dict from a list of method names."""
def _methods(*names: str, **kwargs: str) -> dict[str, MethodSignature] {
    result: dict[str, MethodSignature] = {};
    for name in names {
        ret_type = kwargs.get(name, "None");
        result[name] = MethodSignature(name=name, return_type_name=ret_type);
    }
    return result;
}

"""Helper to build static methods dict."""
def _static_methods(*names: str) -> dict[str, MethodSignature] {
    result: dict[str, MethodSignature] = {};
    for name in names {
        result[name] = MethodSignature(
            name=name, return_type_name="None", is_static=True
        );
    }
    return result;
}

"""Helper to build an operators dict from (op_name, magic_method, return_type) tuples."""
def _operators(*ops: tuple) -> dict[str, OperatorInfo] {
    result: dict[str, OperatorInfo] = {};
    for op in ops {
        result[op[0]] = OperatorInfo(
            op_name=op[0],
            magic_method=op[1],
            return_type_name=op[2] if len(op) > 2 else "self"
        );
    }
    return result;
}

"""All codespaces."""
glob ALL_CODESPACES: set[str] = {"server","client","native"};

"""Populate the registry with all primitive type entries."""
impl JacTypeRegistry._populate_primitives -> None {
    # ── int ──────────────────────────────────────────────────
    int_methods = _methods(
        "bit_length", "bit_count", "to_bytes", "as_integer_ratio", "conjugate"
    );
    int_methods.update(_static_methods("from_bytes"));
    int_ops = _operators(
        ("op_add", "__add__", "int"),
        ("op_sub", "__sub__", "int"),
        ("op_mul", "__mul__", "int"),
        ("op_truediv", "__truediv__", "float"),
        ("op_floordiv", "__floordiv__", "int"),
        ("op_mod", "__mod__", "int"),
        ("op_pow", "__pow__", "int"),
        ("op_and", "__and__", "int"),
        ("op_or", "__or__", "int"),
        ("op_xor", "__xor__", "int"),
        ("op_lshift", "__lshift__", "int"),
        ("op_rshift", "__rshift__", "int"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_lt", "__lt__", "bool"),
        ("op_gt", "__gt__", "bool"),
        ("op_le", "__le__", "bool"),
        ("op_ge", "__ge__", "bool"),
        ("op_neg", "__neg__", "int"),
        ("op_pos", "__pos__", "int"),
        ("op_invert", "__invert__", "int")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="int",
            methods=int_methods,
            operators=int_ops,
            codespace_tags=ALL_CODESPACES,
            backend_mappings=BackendTypeMapping(
                sv_type="int", cl_type="Number", na_llvm_type_spec="i64"
            ),
            emitter_class_name="IntEmitter"
        )
    );

    # ── float ────────────────────────────────────────────────
    float_methods = _methods("is_integer", "as_integer_ratio", "conjugate", "hex");
    float_methods.update(_static_methods("fromhex"));
    float_ops = _operators(
        ("op_add", "__add__", "float"),
        ("op_sub", "__sub__", "float"),
        ("op_mul", "__mul__", "float"),
        ("op_truediv", "__truediv__", "float"),
        ("op_floordiv", "__floordiv__", "float"),
        ("op_mod", "__mod__", "float"),
        ("op_pow", "__pow__", "float"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_lt", "__lt__", "bool"),
        ("op_gt", "__gt__", "bool"),
        ("op_le", "__le__", "bool"),
        ("op_ge", "__ge__", "bool"),
        ("op_neg", "__neg__", "float"),
        ("op_pos", "__pos__", "float")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="float",
            methods=float_methods,
            operators=float_ops,
            codespace_tags=ALL_CODESPACES,
            backend_mappings=BackendTypeMapping(
                sv_type="float", cl_type="Number", na_llvm_type_spec="f64"
            ),
            emitter_class_name="FloatEmitter"
        )
    );

    # ── bool ─────────────────────────────────────────────────
    # bool inherits from int; no additional methods/operators of its own
    self.register(
        JacPrimitiveTypeEntry(
            name="bool",
            methods={},
            operators={},
            codespace_tags=ALL_CODESPACES,
            backend_mappings=BackendTypeMapping(
                sv_type="bool", cl_type="Boolean", na_llvm_type_spec="i1"
            ),
            emitter_class_name="BoolEmitter",
            inherits_from="int"
        )
    );

    # ── complex ──────────────────────────────────────────────
    complex_methods = _methods("conjugate");
    complex_ops = _operators(
        ("op_add", "__add__", "complex"),
        ("op_sub", "__sub__", "complex"),
        ("op_mul", "__mul__", "complex"),
        ("op_truediv", "__truediv__", "complex"),
        ("op_pow", "__pow__", "complex"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_neg", "__neg__", "complex"),
        ("op_pos", "__pos__", "complex")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="complex",
            methods=complex_methods,
            operators=complex_ops,
            codespace_tags={"server","client"},
            backend_mappings=BackendTypeMapping(sv_type="complex", cl_type="Complex"),
            emitter_class_name="ComplexEmitter"
        )
    );

    # ── str ──────────────────────────────────────────────────
    str_methods = _methods(
        # Case conversion
        "capitalize",
        "casefold",
        "lower",
        "upper",
        "title",
        "swapcase",
        "count",
        "find",
        "rfind",
        "index",
        "rindex",
        "startswith",
        "endswith",
        "replace",
        "strip",
        "lstrip",
        "rstrip",
        "removeprefix",
        "removesuffix",
        "split",
        "rsplit",
        "splitlines",
        "join",
        "partition",
        "rpartition",
        "format",
        "format_map",
        "center",
        "ljust",
        "rjust",
        "zfill",
        "expandtabs",
        "isalnum",
        "isalpha",
        "isascii",
        "isdecimal",
        "isdigit",
        "isidentifier",
        "islower",
        "isnumeric",
        "isprintable",
        "isspace",
        "istitle",
        "isupper",
        "encode",
        "translate"
        # Search
        # Modification
        # Split and join
        # Formatting and alignment
        # Character tests
        # Encoding
        # Translation
    );
    str_methods.update(_static_methods("maketrans"));
    str_ops = _operators(
        ("op_add", "__add__", "str"),
        ("op_mul", "__mul__", "str"),
        ("op_mod", "__mod__", "str"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_lt", "__lt__", "bool"),
        ("op_gt", "__gt__", "bool"),
        ("op_le", "__le__", "bool"),
        ("op_ge", "__ge__", "bool"),
        ("op_contains", "__contains__", "bool")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="str",
            methods=str_methods,
            operators=str_ops,
            codespace_tags=ALL_CODESPACES,
            backend_mappings=BackendTypeMapping(
                sv_type="str", cl_type="String", na_llvm_type_spec="i8*"
            ),
            emitter_class_name="StrEmitter"
        )
    );

    # ── bytes ────────────────────────────────────────────────
    bytes_methods = _methods(
        # Decoding
        "decode",
        "hex",
        "count",
        "find",
        "rfind",
        "index",
        "rindex",
        "startswith",
        "endswith",
        "replace",
        "strip",
        "lstrip",
        "rstrip",
        "removeprefix",
        "removesuffix",
        "split",
        "rsplit",
        "splitlines",
        "join",
        "partition",
        "rpartition",
        "capitalize",
        "lower",
        "upper",
        "title",
        "swapcase",
        "isalnum",
        "isalpha",
        "isascii",
        "isdigit",
        "islower",
        "isspace",
        "istitle",
        "isupper",
        "center",
        "ljust",
        "rjust",
        "zfill",
        "expandtabs",
        "translate"
        # Search
        # Modification
        # Split and join
        # Case (ASCII only)
        # Character tests (ASCII only)
        # Alignment
        # Translation
    );
    bytes_methods.update(_static_methods("fromhex", "maketrans"));
    bytes_ops = _operators(
        ("op_add", "__add__", "bytes"),
        ("op_mul", "__mul__", "bytes"),
        ("op_mod", "__mod__", "bytes"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_lt", "__lt__", "bool"),
        ("op_gt", "__gt__", "bool"),
        ("op_le", "__le__", "bool"),
        ("op_ge", "__ge__", "bool"),
        ("op_contains", "__contains__", "bool")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="bytes",
            methods=bytes_methods,
            operators=bytes_ops,
            codespace_tags={"server","client"},
            backend_mappings=BackendTypeMapping(sv_type="bytes", cl_type="Uint8Array"),
            emitter_class_name="BytesEmitter"
        )
    );

    # ── list ─────────────────────────────────────────────────
    list_methods = _methods(
        "append",
        "extend",
        "insert",
        "remove",
        "pop",
        "clear",
        "index",
        "count",
        "sort",
        "reverse",
        "copy"
    );
    list_ops = _operators(
        ("op_add", "__add__", "list"),
        ("op_mul", "__mul__", "list"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_lt", "__lt__", "bool"),
        ("op_gt", "__gt__", "bool"),
        ("op_le", "__le__", "bool"),
        ("op_ge", "__ge__", "bool"),
        ("op_contains", "__contains__", "bool"),
        ("op_iadd", "__iadd__", "list"),
        ("op_imul", "__imul__", "list")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="list",
            methods=list_methods,
            operators=list_ops,
            codespace_tags=ALL_CODESPACES,
            backend_mappings=BackendTypeMapping(sv_type="list", cl_type="Array"),
            emitter_class_name="ListEmitter"
        )
    );

    # ── dict ─────────────────────────────────────────────────
    dict_methods = _methods(
        "get",
        "keys",
        "values",
        "items",
        "pop",
        "popitem",
        "setdefault",
        "update",
        "clear",
        "copy"
    );
    dict_methods.update(_static_methods("fromkeys"));
    dict_ops = _operators(
        ("op_or", "__or__", "dict"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_contains", "__contains__", "bool"),
        ("op_ior", "__ior__", "dict")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="dict",
            methods=dict_methods,
            operators=dict_ops,
            codespace_tags=ALL_CODESPACES,
            backend_mappings=BackendTypeMapping(sv_type="dict", cl_type="Map"),
            emitter_class_name="DictEmitter"
        )
    );

    # ── set ──────────────────────────────────────────────────
    set_methods = _methods(
        # Mutation
        "add",
        "remove",
        "discard",
        "pop",
        "clear",
        "union",
        "intersection",
        "difference",
        "symmetric_difference",
        "update",
        "intersection_update",
        "difference_update",
        "symmetric_difference_update",
        "issubset",
        "issuperset",
        "isdisjoint",
        "copy"
        # Set algebra (return new set)
        # In-place set algebra
        # Tests
    );
    set_ops = _operators(
        ("op_or", "__or__", "set"),
        ("op_and", "__and__", "set"),
        ("op_sub", "__sub__", "set"),
        ("op_xor", "__xor__", "set"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_le", "__le__", "bool"),
        ("op_lt", "__lt__", "bool"),
        ("op_ge", "__ge__", "bool"),
        ("op_gt", "__gt__", "bool"),
        ("op_contains", "__contains__", "bool"),
        ("op_ior", "__ior__", "set"),
        ("op_iand", "__iand__", "set"),
        ("op_isub", "__isub__", "set"),
        ("op_ixor", "__ixor__", "set")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="set",
            methods=set_methods,
            operators=set_ops,
            codespace_tags=ALL_CODESPACES,
            backend_mappings=BackendTypeMapping(sv_type="set", cl_type="Set"),
            emitter_class_name="SetEmitter"
        )
    );

    # ── frozenset ────────────────────────────────────────────
    frozenset_methods = _methods(
        "union",
        "intersection",
        "difference",
        "symmetric_difference",
        "issubset",
        "issuperset",
        "isdisjoint",
        "copy"
    );
    frozenset_ops = _operators(
        ("op_or", "__or__", "frozenset"),
        ("op_and", "__and__", "frozenset"),
        ("op_sub", "__sub__", "frozenset"),
        ("op_xor", "__xor__", "frozenset"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_le", "__le__", "bool"),
        ("op_lt", "__lt__", "bool"),
        ("op_ge", "__ge__", "bool"),
        ("op_gt", "__gt__", "bool"),
        ("op_contains", "__contains__", "bool")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="frozenset",
            methods=frozenset_methods,
            operators=frozenset_ops,
            codespace_tags={"server","client"},
            backend_mappings=BackendTypeMapping(sv_type="frozenset", cl_type="Set"),
            emitter_class_name="FrozensetEmitter"
        )
    );

    # ── tuple ────────────────────────────────────────────────
    tuple_methods = _methods("count", "index");
    tuple_ops = _operators(
        ("op_add", "__add__", "tuple"),
        ("op_mul", "__mul__", "tuple"),
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_lt", "__lt__", "bool"),
        ("op_gt", "__gt__", "bool"),
        ("op_le", "__le__", "bool"),
        ("op_ge", "__ge__", "bool"),
        ("op_contains", "__contains__", "bool")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="tuple",
            methods=tuple_methods,
            operators=tuple_ops,
            codespace_tags=ALL_CODESPACES,
            backend_mappings=BackendTypeMapping(sv_type="tuple", cl_type="Array"),
            emitter_class_name="TupleEmitter"
        )
    );

    # ── range ────────────────────────────────────────────────
    range_methods = _methods("count", "index");
    range_ops = _operators(
        ("op_eq", "__eq__", "bool"),
        ("op_ne", "__ne__", "bool"),
        ("op_contains", "__contains__", "bool")
    );
    self.register(
        JacPrimitiveTypeEntry(
            name="range",
            methods=range_methods,
            operators=range_ops,
            codespace_tags=ALL_CODESPACES,
            backend_mappings=BackendTypeMapping(sv_type="range", cl_type="Range"),
            emitter_class_name="RangeEmitter"
        )
    );
}

"""Populate the registry with builtin function names."""
impl JacTypeRegistry._populate_builtins -> None {
    self._builtin_functions = {
    # I/O
    "print","input",
    # Aggregation
    "len","abs","round","min","max","sum",
    # Iteration
    "sorted","reversed","enumerate","zip","map","filter","any","all",
    # Type checking
    "isinstance","issubclass","type","callable",
    # Identity / hashing
    "id","hash",
    # Representation
    "repr","format","ascii",
    # Char/ord conversion
    "chr","ord",
    # Number formatting
    "hex","oct","bin",
    # Arithmetic
    "pow","divmod",
    # Iteration protocol
    "iter","next",
    # Attribute access
    "getattr","setattr","hasattr","delattr",
    # Introspection
    "vars","dir",
    # File I/O
    "open",
    # Type conversion
    "str","int","float","bool","list","dict","set","tuple","frozenset","bytes","complex","range","slice","bytearray"};
}
