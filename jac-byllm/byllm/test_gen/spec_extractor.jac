"""Spec extraction from MTIR for test generation.

Walks JacRuntime.program.mtir_map and converts FunctionInfo objects into
FunctionSpec data structures suitable for prompt building and test generation.
"""

"""A field of a structured type."""
obj FieldSpec {
    has name: str,
        type_str: str,
        semstr: str | None;
}

"""A class/object return type with its fields."""
obj ClassSpec {
    has name: str,
        semstr: str | None,
        fields: list[FieldSpec];
}

"""An enum return type with its members."""
obj EnumSpec {
    has name: str,
        semstr: str | None,
        members: list[tuple];   # list of (member_name: str, member_semstr: str | None)
}

"""A single function parameter."""
obj ParamSpec {
    has name: str,
        type_str: str,
        semstr: str | None,
        nested: ClassSpec | EnumSpec | None = None;
}

"""Full specification of a single by llm() function, derived from MTIR."""
obj FunctionSpec {
    has qualified_key: str,             # e.g. "llm_semstrings.generate_password"
        name: str,                      # e.g. "generate_password"
        parent_class: str | None,       # e.g. "LevelManager" if this is a method, else None
        semstr: str | None,
        params: list[ParamSpec],
        return_type_str: str,           # human-readable via type_to_str()
        return_type_detail: ClassSpec | EnumSpec | None;

    """Compute a stable 16-hex-char hash of the spec for staleness detection."""
    def spec_hash -> str;
}

"""Extract FunctionSpec objects for all by llm() functions in an MTIR map.

Args:
    mtir_map: JacRuntime.program.mtir_map (dict[str, Info])

Returns:
    list of FunctionSpec, one per by-llm() function (excludes tool-only entries)
"""
def extract_specs(mtir_map: dict) -> list[FunctionSpec];
