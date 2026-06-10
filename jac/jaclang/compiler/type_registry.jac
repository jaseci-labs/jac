"""Centralized Jac Type Registry.

Single source of truth for primitive type coordination across all compilation
backends (SV/Python, CL/ECMAScript, NA/LLVM).

Emitter contracts (abstract method signatures) live in primitives.jac.
Emitter implementations live in each backend's primitives_*.jac.
This module provides the coordination data that connects them.
"""

"""Numeric kind of a primitive type.

Same-kind primitives are mutually assignable (the type checker treats them
as width refinements, not unrelated subclasses). IntKind covers
int / bool / i8..u64; FloatKind covers float / f32 / f64.
"""
enum NumericKind {
    NotNumeric = "not_numeric",
    IntKind = "int_kind",
    FloatKind = "float_kind"
}

"""A single primitive type entry with all cross-backend metadata."""
obj JacTypeEntry {
    has name: str,  # Jac type name ("int", "str", ...)
        emitter_suffix: str,  # Emitter class suffix ("IntEmitter")
        na_type_spec: str | None = None,  # LLVM type spec ("i64") or None
        numeric_kind: NumericKind = NumericKind.NotNumeric;
}

"""Typed registry of all Jac primitive types."""
obj JacTypeRegistry {
    has _entries: dict[str, JacTypeEntry],
        _builtin_names: frozenset[str],
        # Builtin exception hierarchy (child -> direct parent), ordered
        # topologically so parents precede children. The root maps to None.
        # See the "Exception Types" section of primitives.jac for the human
        # readable tree; this is the machine-readable source of truth.
        _exception_parents: dict[str, str | None];

    """Get a type entry by name, or None if not found."""
    def get(name: str) -> JacTypeEntry | None {
        return self._entries.get(name, None);
    }

    """Set of all primitive type names."""
    def primitive_names -> set[str] {
        return set(self._entries.keys());
    }

    """True if name is a primitive type."""
    def is_primitive(name: str) -> bool {
        return name in self._entries;
    }

    """List of (name, emitter_suffix) pairs for building emitter dicts."""
    def emitter_items -> list[tuple[str, str]] {
        return [(e.name, e.emitter_suffix) for e in self._entries.values()];
    }

    """List of (name, na_type_spec) for types with LLVM representations."""
    def na_type_entries -> list[tuple[str, str]] {
        return [
            (e.name, e.na_type_spec)
            for e in self._entries.values()
            if e.na_type_spec is not None
        ];
    }

    """Set of all builtin function names."""
    def builtin_names -> set[str] {
        return set(self._builtin_names);
    }

    """True if name is a builtin function."""
    def is_builtin(name: str) -> bool {
        return name in self._builtin_names;
    }

    """Numeric kind for a primitive type name; NotNumeric if unknown / non-numeric."""
    def numeric_kind_of(name: str) -> NumericKind {
        entry = self._entries.get(name, None);
        if entry is None {
            return NumericKind.NotNumeric;
        }
        return entry.numeric_kind;
    }

    """True if name is a builtin exception type."""
    def is_exception(name: str) -> bool {
        return name in self._exception_parents;
    }

    """Direct parent of an exception type; None for the root or unknown names."""
    def exception_parent(name: str) -> str | None {
        return self._exception_parents.get(name, None);
    }

    """All builtin exceptions as (name, parent) pairs in topological order
    (parents before children). The root's parent is None.
    """
    def exception_entries -> list[tuple[str, str | None]] {
        return [(name, parent) for (name, parent) in self._exception_parents.items()];
    }

    """All transitive descendants of an exception type (excluding itself).

    Enables hierarchy-aware matching: `except ArithmeticError` must also catch
    ZeroDivisionError, OverflowError and FloatingPointError.
    """
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

# ── Registry singleton ────────────────────────────────────────────
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
             # Fixed-width integer types
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
             # Fixed-width float types
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
                 # I/O
                 "print",
                 "input",
                 # Aggregation
                 "len",
                 "abs",
                 "round",
                 "min",
                 "max",
                 "sum",
                 # Iteration
                 "sorted",
                 "reversed",
                 "enumerate",
                 "zip",
                 "map",
                 "filter",
                 "any",
                 "all",
                 # Type checking
                 "isinstance",
                 "issubclass",
                 "type",
                 "callable",
                 # Identity / hashing
                 "id",
                 "hash",
                 "jid",
                 # Portable constructor (server: Cls(*args); cl: Reflect.construct)
                 "new",
                 # JSX raw-HTML opt-in (returns a marker recognised by __jacJsx)
                 "unsafe_html",
                 # Representation
                 "repr",
                 "format",
                 "ascii",
                 # Char/ord conversion
                 "chr",
                 "ord",
                 # Number formatting
                 "hex",
                 "oct",
                 "bin",
                 # Arithmetic
                 "pow",
                 "divmod",
                 # Iteration protocol
                 "iter",
                 "next",
                 # Attribute access
                 "getattr",
                 "setattr",
                 "hasattr",
                 "delattr",
                 # Introspection
                 "vars",
                 "dir",
                 # File I/O
                 "open",
                 # Type conversions
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
