import from jaclang.runtime.scalars {
    ScalarShape,
    numeric_shapes,
    sized_scalar_names,
    shape_literal_fits,
    shape_range,
    shapes_unify,
    shapes_widen_to
}

enum NumericKind {
    NotNumeric = "not_numeric",
    IntKind = "int_kind",
    FloatKind = "float_kind"
}

obj JacTypeEntry {
    has name: str,
        emitter_suffix: str,
        numeric_kind: NumericKind = NumericKind.NotNumeric,
        width: int = 0,
        signed: bool = False,
        is_float: bool = False,
        sized: bool = False;

    def size_bytes -> int {
        return max(1, self.width // 8);
    }

    def align -> int {
        return self.size_bytes();
    }

    def is_int_kind -> bool {
        return self.numeric_kind == NumericKind.IntKind;
    }

    def is_float_kind -> bool {
        return self.numeric_kind == NumericKind.FloatKind;
    }
}

def _numeric_entry(shape: ScalarShape, emitter_suffix: str) -> JacTypeEntry {
    return JacTypeEntry(
        name=shape.name,
        emitter_suffix=emitter_suffix,
        numeric_kind=NumericKind.FloatKind if shape.is_float else NumericKind.IntKind,
        width=shape.width,
        signed=shape.signed,
        is_float=shape.is_float,
        sized=shape.sized
    );
}

def _registry_entries -> dict[str, JacTypeEntry] {
    out: dict[str, JacTypeEntry] = {};
    for shape in numeric_shapes() {
        suffix = "BoolEmitter"
            if shape.name == "bool"
            else ("FloatEmitter" if shape.is_float else "IntEmitter");
        out[shape.name] = _numeric_entry(shape, suffix);
    }
    out["complex"] = JacTypeEntry(name="complex", emitter_suffix="ComplexEmitter");
    out["str"] = JacTypeEntry(name="str", emitter_suffix="StrEmitter", width=64);
    out["bytes"] = JacTypeEntry(name="bytes", emitter_suffix="BytesEmitter");
    out["list"] = JacTypeEntry(name="list", emitter_suffix="ListEmitter");
    out["dict"] = JacTypeEntry(name="dict", emitter_suffix="DictEmitter");
    out["set"] = JacTypeEntry(name="set", emitter_suffix="SetEmitter");
    out["frozenset"] = JacTypeEntry(
        name="frozenset", emitter_suffix="FrozensetEmitter"
    );
    out["tuple"] = JacTypeEntry(name="tuple", emitter_suffix="TupleEmitter");
    out["range"] = JacTypeEntry(name="range", emitter_suffix="RangeEmitter");
    return out;
}

obj JacTypeRegistry {
    has _entries: dict[str, JacTypeEntry],
        _builtin_names: frozenset[str],
        _non_retaining_builtins: frozenset[str],
        _exception_parents: dict[str, str | None],
        _shapes: dict[str, ScalarShape];

    def is_non_retaining_builtin(name: str) -> bool {
        return name in self._non_retaining_builtins;
    }

    def shape_of(name: str) -> ScalarShape | None {
        return self._shapes.get(name, None);
    }

    def get(name: str) -> JacTypeEntry | None {
        return self._entries.get(name, None);
    }

    def primitive_names -> set[str] {
        return set(self._entries.keys());
    }

    def is_primitive(name: str) -> bool {
        return name in self._entries;
    }

    def emitter_items -> list[tuple[str, str]] {
        return [(e.name, e.emitter_suffix) for e in self._entries.values()];
    }

    def scalar_entries -> list[JacTypeEntry] {
        return [
            e
            for e in self._entries.values()
            if e.width > 0
        ];
    }

    def builtin_names -> set[str] {
        return set(self._builtin_names);
    }

    def is_builtin(name: str) -> bool {
        return name in self._builtin_names;
    }

    def numeric_kind_of(name: str) -> NumericKind {
        `entry = self._entries.get(name, None);
        if `entry is None {
            return NumericKind.NotNumeric;
        }
        return `entry.numeric_kind;
    }

    def is_numeric(name: str) -> bool {
        return self.numeric_kind_of(name) != NumericKind.NotNumeric;
    }

    def is_sized(name: str) -> bool {
        shape = self._shapes.get(name, None);
        return shape is not None and shape.sized;
    }

    def sized_int_names -> list[str] {
        return [
            s.name
            for s in self._shapes.values()
            if s.sized and not s.is_float
        ];
    }

    def sized_float_names -> list[str] {
        return [
            s.name
            for s in self._shapes.values()
            if s.sized and s.is_float
        ];
    }

    def sized_scalar_names -> list[str] {
        return [
            s.name
            for s in self._shapes.values()
            if s.sized
        ];
    }

    def range_of(name: str) -> tuple[int, int] {
        shape = self._shapes.get(name, None);
        if shape is None {
            raise KeyError(name);
        }
        return shape_range(shape);
    }

    def literal_fits(name: str, value: int | float) -> bool {
        shape = self._shapes.get(name, None);
        return shape is not None and shape_literal_fits(shape, value);
    }

    def widens_to(src: str, dst: str) -> bool {
        if src == dst {
            return True;
        }
        s = self._shapes.get(src, None);
        d = self._shapes.get(dst, None);
        return s is not None and d is not None and shapes_widen_to(s, d);
    }

    def unify(a: str, b: str) -> str | None {
        s = self._shapes.get(a, None);
        d = self._shapes.get(b, None);
        if s is None or d is None {
            return None;
        }
        out = shapes_unify(s, d);
        return None if out is None else out.name;
    }

    def is_exception(name: str) -> bool {
        return name in self._exception_parents;
    }

    def exception_entries -> list[tuple[str, str | None]] {
        return [(name, parent) for (name, parent) in self._exception_parents.items()];
    }

    def exception_type_id(name: str) -> int {
        if name == "Exception" {
            return 0;
        }
        idx = 0;
        for n in self._exception_parents.keys() {
            idx += 1;
            if n == name {
                return idx;
            }
        }
        import hashlib;
        digest = hashlib.sha256(name.encode("utf-8")).hexdigest();
        return 0x40000000 + (int(digest[:8], 16) % 0x3FFFFFFF);
    }

    def exception_descendants(type_name: str) -> list[str] {
        descendants: list[str] = [];
        for child in self._exception_parents.keys() {
            cur = self._exception_parents[child];
            while cur is not None {
                if cur == type_name {
                    descendants.append(child);
                    break;
                }
                cur = self._exception_parents.get(cur, None);
            }
        }
        return descendants;
    }
}

def _non_retaining_builtin_set -> frozenset[str] {
    return frozenset(
        {
            "print",
            "len",
            "repr",
            "str",
            "int",
            "float",
            "bool",
            "isinstance",
            "type",
            "id",
            "hash",
            "region_of"
        }
    );
}

def _builtin_name_set -> frozenset[str] {
    names: set[str] = {
        "wrapping_add",
        "wrapping_sub",
        "wrapping_mul",
        "wrapping_shl",
        "wrapping_neg",
        "print",
        "input",
        "len",
        "abs",
        "round",
        "min",
        "max",
        "sum",
        "sorted",
        "reversed",
        "enumerate",
        "zip",
        "map",
        "filter",
        "any",
        "all",
        "isinstance",
        "issubclass",
        "type",
        "callable",
        "id",
        "hash",
        "jid",
        "new",
        "unsafe_html",
        "managed",
        "take",
        "swap",
        "Region",
        "region_of",
        "repr",
        "format",
        "ascii",
        "chr",
        "ord",
        "hex",
        "oct",
        "bin",
        "pow",
        "divmod",
        "iter",
        "next",
        "getattr",
        "setattr",
        "hasattr",
        "delattr",
        "vars",
        "dir",
        "open",
        "str",
        "int",
        "float",
        "bool",
        "list",
        "dict",
        "set",
        "tuple",
        "frozenset",
        "bytes",
        "complex",
        "range",
        "slice",
        "bytearray"
    };
    for sized in sized_scalar_names() {
        names.add(sized);
    }
    return frozenset(names);
}

def _shape_table -> dict[str, ScalarShape] {
    out: dict[str, ScalarShape] = {};
    for shape in numeric_shapes() {
        out[shape.name] = shape;
    }
    return out;
}

glob JAC_TYPE_REGISTRY = JacTypeRegistry(
         _entries=_registry_entries(),
         _shapes=_shape_table(),
         _builtin_names=_builtin_name_set(),
         _non_retaining_builtins=_non_retaining_builtin_set(),
         _exception_parents={
             "BaseException": None,
             "Exception": "BaseException",
             "ArithmeticError": "Exception",
             "ZeroDivisionError": "ArithmeticError",
             "OverflowError": "ArithmeticError",
             "FloatingPointError": "ArithmeticError",
             "LookupError": "Exception",
             "IndexError": "LookupError",
             "KeyError": "LookupError",
             "ValueError": "Exception",
             "TypeError": "Exception",
             "AttributeError": "Exception",
             "RuntimeError": "Exception",
             "NotImplementedError": "RuntimeError",
             "RecursionError": "RuntimeError",
             "OSError": "Exception",
             "FileNotFoundError": "OSError",
             "FileExistsError": "OSError",
             "PermissionError": "OSError",
             "TimeoutError": "OSError",
             "IsADirectoryError": "OSError",
             "NotADirectoryError": "OSError",
             "AssertionError": "Exception",
             "ImportError": "Exception",
             "ModuleNotFoundError": "ImportError",
             "NameError": "Exception",
             "UnboundLocalError": "NameError",
             "StopIteration": "Exception",
             "StopAsyncIteration": "Exception",
             "EOFError": "Exception",
             "MemoryError": "Exception",
             "ReferenceError": "Exception",
             "KeyboardInterrupt": "BaseException",
             "SystemExit": "BaseException",
             "GeneratorExit": "BaseException"
         }
     );
