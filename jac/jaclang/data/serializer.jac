import importlib;
import logging;
import sys;
import threading;
import from time { monotonic }
import from jaclang.runtime.object_interop { fields, is_record }
import from jaclang.runtime.object_model { MISSING }
import from datetime { date, datetime, time }
import from enum { Enum }
import from hashlib { sha256 }
import from json { dumps as _json_dumps }
import from typing { cast, get_args, get_origin }
import from types { NoneType, UnionType }
import from typing { Union }
import from uuid { UUID }
import from jaclang.runtime.typecache { get_field_types }
import from jaclang.runtime.archetype {
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
import from jaclang.runtime.constructs {
    Archetype,
    NodeArchetype,
    WalkerArchetype,
    Root,
    GenericEdge
}

glob logger = logging.getLogger(__name__),
     FINGERPRINT_LENGTH: int = 16,
     _MAX_WARNED_CLASS_KEYS: int = 1024,
     _MAX_IMPORT_FAILURES: int = 1024,
     _IMPORT_RETRY_SECONDS: float = 30.0,
     _IMPORT_RETRY_CEILING_SECONDS: float = 900.0,
     _IMPORT_RETRY_MAX_DOUBLINGS: int = 8,
     _PLAIN_WIRE_SCALARS: frozenset = frozenset({str, int, float, bool}),
     _SIZED_FIELD_CACHE: dict = {};

obj ImportFailure {
    has attempts: int = 0,
        failed_at: float = 0.0;
}

obj Serializer {
    static has _registry: dict[str, type] = {},
        _aliases: dict[str, str] = {},
        _warn_counts: dict[str, int] = {},
        _warn_dedup_saturated: bool = False,
        _import_failures: dict[str, ImportFailure] = {},
        _import_lock: threading.Lock = threading.Lock(),
        _warn_lock: threading.Lock = threading.Lock();

    static def register(cls: type) -> None;
    static def register_alias(old_name: str, cls: type) -> None;
    static def is_auto_registered_module(module_name: str) -> bool;
    static def fingerprint(cls: type) -> str;
    static def repair(data: dict[str, object], cls: type) -> tuple;
    static def coerce(val: object, target_type: object) -> tuple;
    static def serialize(
        `obj: object,
        include_type: bool = False,
        api_mode: bool = False,
        ref_mode: bool = False
    ) -> object;

    static def deserialize(data: dict[str, object]) -> (object | None);
    static def deserialize_api(
        value: object, boundary_types: dict[str, type], target: (type | None) = None
    ) -> object;

    static def _serialize_value(
        val: object,
        include_type: bool,
        api_mode: bool = False,
        ref_mode: bool = False,
        _seen: (tuple[set, set] | None) = None,
        declared: object = None
    ) -> object;

    static def _declared_of(owner: object, attr: str) -> object;
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
    static def _resolve_class_by_import(
        module_name: str, class_name: str
    ) -> (type | None);

    static def _import_allowed(module_name: str) -> bool;
    static def _record_import_failure(module_name: str) -> float;
    static def _clear_import_failure(module_name: str) -> None;
    static def _reset_import_failures -> None;
    static def _warn_occurrence(scope: str, key: str) -> int;
    static def _is_report_threshold(n: int) -> bool;
    static def _occurrence_note(n: int) -> str;
    static def _reset_warn_cache -> None;
    static def _id_to_stub(anchor_cls: type[Anchor], id_str: str) -> (Anchor | None);
    static def _deserialize_anchor(data: dict[str, object]) -> (Anchor | None);
    static def _deserialize_permission(data: object) -> (Permission | None);
    static def _deserialize_access(data: object) -> Access;
    static def _deserialize_archetype(
        data: dict[str, object], anchor: Anchor
    ) -> (object | None);

    static def _compute_hash(anchor: Anchor) -> int;
    static def serialize_fields(
        anchor: Anchor, field_names: set[str]
    ) -> dict[str, object];
}

glob _register_hook: object = Archetype.install_subclass_hook(
         lambda (cls: type) { Serializer.register(cls)
             if Serializer.is_auto_registered_module(cls.__module__)
             else None; }
     ),
     _register_root: object = Serializer.register(cast(type, Root)),
     _register_generic_edge: object = Serializer.register(cast(type, GenericEdge));
