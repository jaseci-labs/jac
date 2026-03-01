"""Centralized Jac Type Registry.

Single source of truth for primitive type coordination across all compilation
backends (SV/Python, CL/ECMAScript, NA/LLVM).

Emitter contracts (abstract method signatures) live in primitives.jac.
Emitter implementations live in each backend's primitives_*.jac.
This module provides the coordination data that connects them.
"""

"""A single primitive type entry with all cross-backend metadata."""
obj JacTypeEntry {
    has name: str,  # Jac type name ("int", "str", ...)
        emitter_suffix: str,  # Emitter class suffix ("IntEmitter")
        na_type_spec: str | None = None;  # LLVM type spec ("i64") or None
}

"""Typed registry of all Jac primitive types."""
obj JacTypeRegistry {
    has _entries: dict[str, JacTypeEntry],
        _builtin_names: frozenset[str];

    """Get a type entry by name, or None if not found."""
    def get(name: str) -> JacTypeEntry | None {
        return self._entries.get(name, None);
    }

    """Set of all primitive type names."""
    def primitive_names -> set[str] {
        return set(self._entries.keys());
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
}

# ── Registry singleton ────────────────────────────────────────────
glob JAC_TYPE_REGISTRY = JacTypeRegistry(
         _entries={
             "int": JacTypeEntry(
                 name="int", emitter_suffix="IntEmitter", na_type_spec="i64"
             ),
             "float": JacTypeEntry(
                 name="float", emitter_suffix="FloatEmitter", na_type_spec="f64"
             ),
             "bool": JacTypeEntry(
                 name="bool", emitter_suffix="BoolEmitter", na_type_spec="i1"
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

         },
         _builtin_names=frozenset(
             {
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
             # Type conversions
             "str","int","float","bool","list","dict","set","tuple","frozenset","bytes","complex","range","slice","bytearray",}
         )
     );
