enum NumericKind {
    NotNumeric = "not_numeric",
    IntKind = "int_kind",
    FloatKind = "float_kind"
}

obj JacTypeEntry {
    has name: str,
        emitter_suffix: str,
        na_type_spec: str | None = None,
        numeric_kind: NumericKind = NumericKind.NotNumeric;
}

obj JacTypeRegistry {
    has _entries: dict[str, JacTypeEntry],
        _builtin_names: frozenset[str],
        _exception_parents: dict[str, str | None];

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

    def na_type_entries -> list[tuple[str, str]] {
        return [
            (e.name, e.na_type_spec)
            for e in self._entries.values()
            if e.na_type_spec is not None
        ];
    }

    def builtin_names -> set[str] {
        return set(self._builtin_names);
    }

    def is_builtin(name: str) -> bool {
        return name in self._builtin_names;
    }

    def numeric_kind_of(name: str) -> NumericKind {
        entry = self._entries.get(name, None);
        if entry is None {
            return NumericKind.NotNumeric;
        }
        return entry.numeric_kind;
    }

    def is_exception(name: str) -> bool {
        return name in self._exception_parents;
    }

    def exception_parent(name: str) -> str | None {
        return self._exception_parents.get(name, None);
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

glob JAC_TYPE_REGISTRY = JacTypeRegistry(
         _entries={
             "int": JacTypeEntry(
                 name="int",
                 emitter_suffix="IntEmitter",
                 na_type_spec="i64",
                 numeric_kind=NumericKind.IntKind
             ),
             "float": JacTypeEntry(
                 name="float",
                 emitter_suffix="FloatEmitter",
                 na_type_spec="f64",
                 numeric_kind=NumericKind.FloatKind
             ),
             "bool": JacTypeEntry(
                 name="bool",
                 emitter_suffix="BoolEmitter",
                 na_type_spec="i1",
                 numeric_kind=NumericKind.IntKind
             ),
             "complex": JacTypeEntry(name="complex", emitter_suffix="ComplexEmitter"),
             "str": JacTypeEntry(
                 name="str", emitter_suffix="StrEmitter", na_type_spec="i8*"
             ),
             "bytes": JacTypeEntry(name="bytes", emitter_suffix="BytesEmitter"),
             "list": JacTypeEntry(name="list", emitter_suffix="ListEmitter"),
             "dict": JacTypeEntry(name="dict", emitter_suffix="DictEmitter"),
             "set": JacTypeEntry(name="set", emitter_suffix="SetEmitter"),
             "frozenset": JacTypeEntry(
                 name="frozenset", emitter_suffix="FrozensetEmitter"
             ),
             "tuple": JacTypeEntry(name="tuple", emitter_suffix="TupleEmitter"),
             "range": JacTypeEntry(name="range", emitter_suffix="RangeEmitter"),
             "i8": JacTypeEntry(
                 name="i8",
                 emitter_suffix="IntEmitter",
                 na_type_spec="i8",
                 numeric_kind=NumericKind.IntKind
             ),
             "u8": JacTypeEntry(
                 name="u8",
                 emitter_suffix="IntEmitter",
                 na_type_spec="i8",
                 numeric_kind=NumericKind.IntKind
             ),
             "i16": JacTypeEntry(
                 name="i16",
                 emitter_suffix="IntEmitter",
                 na_type_spec="i16",
                 numeric_kind=NumericKind.IntKind
             ),
             "u16": JacTypeEntry(
                 name="u16",
                 emitter_suffix="IntEmitter",
                 na_type_spec="i16",
                 numeric_kind=NumericKind.IntKind
             ),
             "i32": JacTypeEntry(
                 name="i32",
                 emitter_suffix="IntEmitter",
                 na_type_spec="i32",
                 numeric_kind=NumericKind.IntKind
             ),
             "u32": JacTypeEntry(
                 name="u32",
                 emitter_suffix="IntEmitter",
                 na_type_spec="i32",
                 numeric_kind=NumericKind.IntKind
             ),
             "i64": JacTypeEntry(
                 name="i64",
                 emitter_suffix="IntEmitter",
                 na_type_spec="i64",
                 numeric_kind=NumericKind.IntKind
             ),
             "u64": JacTypeEntry(
                 name="u64",
                 emitter_suffix="IntEmitter",
                 na_type_spec="i64",
                 numeric_kind=NumericKind.IntKind
             ),
             "f32": JacTypeEntry(
                 name="f32",
                 emitter_suffix="FloatEmitter",
                 na_type_spec="f32",
                 numeric_kind=NumericKind.FloatKind
             ),
             "f64": JacTypeEntry(
                 name="f64",
                 emitter_suffix="FloatEmitter",
                 na_type_spec="f64",
                 numeric_kind=NumericKind.FloatKind
             ),

         },
         _builtin_names=frozenset(
             {
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
                 "bytearray",

             }
         ),
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
