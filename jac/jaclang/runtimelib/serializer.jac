"""JSON serialization for Jac objects with type-safe deserialization."""

import logging;
import from dataclasses { fields, is_dataclass }
import from datetime { date, datetime, time }
import from enum { Enum }
import from hashlib { sha256 }
import from json { dumps as _json_dumps }
import from typing { cast, get_args, get_origin, get_type_hints }
import from types { NoneType, UnionType }
import from typing { Union }
import from uuid { UUID }
import from jaclang.jac0core.archetype {
    Anchor,
    NodeAnchor,
    EdgeAnchor,
    WalkerAnchor,
    ObjectAnchor,
    Permission,
    Access,
    AccessLevel,
    access_level_cast
}
import from jaclang.jac0core.constructs {
    Archetype,
    NodeArchetype,
    WalkerArchetype,
    Root,
    GenericEdge
}

glob logger = logging.getLogger(__name__),
     # Number of hex chars kept from the SHA-256 of the archetype schema.
     # 16 hex chars = 64 bits, plenty for drift detection.
     FINGERPRINT_LENGTH: int = 16;

"""Converts Jac objects to/from JSON-compatible dicts.

Only classes registered via Archetype subclassing can be deserialized,
preventing arbitrary code execution from untrusted data.
"""
obj Serializer {
    static has _registry: dict[str, type] = {},
        # Alias map: old "module.ClassName" key -> new "module.ClassName" key.
        # Populated by `register_alias` / `archetype_alias` decorator. Used by
        # `_get_class` to resolve renamed or moved archetypes without losing
        # previously persisted anchors.
        _aliases: dict[str, str] = {};

    """Register a class for deserialization and attach its schema fingerprint."""
    static def register(cls: type) -> None;

    """Register `old_name` as an alias for `cls` in the deserialization registry.

    Use when an archetype class is renamed or moved to a different module.
    Stored anchors with `arch_module.arch_type == old_name` will now resolve
    to `cls`, instead of quarantining on load. `old_name` must be the fully
    qualified form (`module.ClassName`); `cls` must already be registered.
    """
    static def register_alias(old_name: str, cls: type) -> None;

    """Compute a stable schema fingerprint for an archetype class.

    Derived from class identity (module + name) plus dataclass field
    (name, type_repr) pairs, sorted for determinism. Hashed with SHA-256
    and truncated to FINGERPRINT_LENGTH hex chars. Used by the persistence
    layer to detect schema drift between the code running now and the
    schema of previously persisted anchors.
    """
    static def fingerprint(cls: type) -> str;

    """Best-effort value coercion for Layer 3 schema migration.

    Attempts to convert `val` to `target_type` for stored anchor fields
    whose declared type changed (e.g. `str -> int`, ISO string -> datetime,
    `str -> UUID`, `int <-> bool`, list <-> tuple). Returns
    (value, success): on success, `value` is the coerced form safe to
    assign; on failure, `value` is the original and the caller can choose
    to fall back (we log + setattr raw, so data is never lost silently).
    Handles `Optional[T]` / `T | None` by unwrapping, and Union types by
    trying each variant in order.
    """
    static def coerce(val: object, target_type: object) -> tuple;

    """Return a {field_name: resolved_annotation} map for a dataclass.

    Uses typing.get_type_hints for forward-ref resolution, falling back to
    raw __annotations__ if hints resolution fails (e.g. circular imports).
    Non-dataclass classes return empty.
    """
    static def _get_field_types(cls: type) -> dict[str, object];

    """Convert object to JSON-compatible dict.

    Set include_type=True for storage (enables round-trip).
    Set api_mode=True for API responses (adds _jac_* metadata).
    Set ref_mode=True to emit {"$ref": "<uuid-hex>", "$type": "<kind>"} for
    repeated Jac objects instead of inlining them again (prevents duplication
    and infinite recursion). Note: ref_mode registers discovered Jac objects
    in the runtime memory store so that $ref placeholders can be resolved back
    to live archetypes during deserialization.
    """
    static def serialize(
        `obj: object,
        include_type: bool = False,
        api_mode: bool = False,
        ref_mode: bool = False
    ) -> object;

    """Reconstruct object from serialized data."""
    static def deserialize(data: dict[str, object]) -> (object | None);

    # Internal helpers
    static def _serialize_value(
        val: object,
        include_type: bool,
        api_mode: bool = False,
        ref_mode: bool = False,
        _seen: (tuple[set, set] | None) = None
    ) -> object;

    static def _type_info(`obj: object, `include: bool) -> dict[str, object];
    static def _serialize_attrs(
        `obj: object,
        include_type: bool,
        api_mode: bool,
        ref_mode: bool = False,
        _seen: (tuple[set, set] | None) = None
    ) -> dict[str, object];

    static def _deserialize_value(val: object) -> object;
    static def _deserialize_jac_ref(data: dict[str, object]) -> (object | None);
    static def _get_class(module_name: str, class_name: str) -> (type | None);
    static def _id_to_stub(anchor_cls: type, id_str: str) -> (object | None);
    static def _deserialize_anchor(data: dict[str, object]) -> (object | None);
    static def _deserialize_permission(data: object) -> object;
    static def _deserialize_access(data: object) -> object;
    static def _deserialize_archetype(
        data: dict[str, object], anchor: object
    ) -> (object | None);

    static def _compute_hash(anchor: object) -> int;
    static def serialize_fields(
        anchor: object, field_names: set[str]
    ) -> dict[str, object];
}

# Auto-register user archetypes via __init_subclass__ hook.
glob _register_hook: object = Archetype._subclass_hooks.append(
         lambda cls: type :
             Serializer.register(cls)
                 if not cls.__module__.startswith('jaclang.')
                 else None
     ),
     _register_root: object = Serializer.register(cast(type, Root)),
     _register_generic_edge: object = Serializer.register(cast(type, GenericEdge));
# The `archetype_alias` decorator is an ambient Jac builtin provided by
# `jaclang.runtimelib.builtin` — user code accesses it without an import.
# The builtin implementation lives there (not here) to avoid a circular
# import: loading this module's aliasing helpers happens mid-init of the
# serializer itself, and a call-time-deferred closure in `builtin.impl`
# lets Serializer finish loading before the decorator ever fires.
