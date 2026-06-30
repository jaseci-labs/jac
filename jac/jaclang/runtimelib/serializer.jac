import logging;
import from dataclasses { fields, is_dataclass, MISSING }
import from datetime { date, datetime, time }
import from enum { Enum }
import from hashlib { sha256 }
import from json { dumps as _json_dumps }
import from typing { cast, get_args, get_origin, get_type_hints }
import from types { NoneType, UnionType }
import from typing { Union }
import from uuid { UUID }
import from jaclang.runtimelib.typecache { get_field_types }
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
     FINGERPRINT_LENGTH: int = 16;

obj Serializer {
    static has _registry: dict[str, type] = {},
        _aliases: dict[str, str] = {};

    static def register(cls: type) -> None;
    static def register_alias(old_name: str, cls: type) -> None;
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

glob _register_hook: object = Archetype._subclass_hooks.append(
         lambda cls: type :
             Serializer.register(cls)
                 if (
                     not cls.__module__.startswith('jaclang.')
                     or cls.__module__.startswith('jaclang.scale.')
                 )
                 else None
     ),
     _register_root: object = Serializer.register(cast(type, Root)),
     _register_generic_edge: object = Serializer.register(cast(type, GenericEdge));
