"""JSON serialization for Jac objects with type-safe deserialization."""

import logging;
import from enum { Enum }
import from typing { cast }
import from uuid { UUID }
import from jaclang.jac0core.archetype {
    Anchor,
    NodeAnchor,
    EdgeAnchor,
    Permission,
    Access,
    AccessLevel
}
import from jaclang.jac0core.constructs {
    Archetype,
    NodeArchetype,
    WalkerArchetype,
    Root,
    GenericEdge
}

glob logger = logging.getLogger(__name__);

"""Converts Jac objects to/from JSON-compatible dicts.

Only classes registered via Archetype subclassing can be deserialized,
preventing arbitrary code execution from untrusted data.
"""
obj Serializer {
    static has _registry: dict[str, type] = {};

    """Register a class for deserialization."""
    static def register(cls: type) -> None;

    """Convert object to JSON-compatible dict.

    Set include_type=True for storage (enables round-trip).
    Set api_mode=True for API responses (adds _jac_* metadata).
    """
    static def serialize(
        `obj: object, include_type: bool = False, api_mode: bool = False
    ) -> object;

    """Reconstruct object from serialized data."""
    static def deserialize(data: dict[str, object]) -> (object | None);

    # Internal helpers
    static def _serialize_value(
        val: object, include_type: bool, api_mode: bool = False
    ) -> object;

    static def _type_info(obj: object, include: bool) -> dict[str, object];
    static def _serialize_attrs(
        obj: object, include_type: bool, api_mode: bool
    ) -> dict[str, object];

    static def _deserialize_value(val: object) -> object;
    static def _get_class(module_name: str, class_name: str) -> (type | None);
    static def _deserialize_anchor(data: dict[str, object]) -> (object | None);
    static def _deserialize_permission(data: object) -> object;
    static def _deserialize_access(data: object) -> object;
    static def _deserialize_archetype(
        data: dict[str, object], anchor: object
    ) -> (object | None);
}

# Auto-register user archetypes via __init_subclass__ hook.
glob _register_hook:
         object = Archetype._subclass_hooks.append(
         lambda cls: type :
             Serializer.register(cls)
             if not cls.__module__.startswith('jaclang.')
             else None
     ),
     _register_root: object = Serializer.register(cast(type, Root)),
     _register_generic_edge: object = Serializer.register(cast(type, GenericEdge));
