"""Serializer implementations."""
import from contextlib { suppress }
import from jaclang.runtimelib.server.types { JsonValue }
import from jaclang.runtimelib.server.serializer { JacSerializer }

"""Serialize objects to JSON-compatible format."""
impl JacSerializer.serialize(<>obj: object) -> JsonValue {
    import from jaclang.pycore.constructs { Archetype }
    if ((<>obj is None) or isinstance(<>obj, (str, int, float, bool))) {
        return <>obj;
    }
    if isinstance(<>obj, (<>list, <>tuple)) {
        return [JacSerializer.serialize(item) for item in <>obj];
    }
    if isinstance(<>obj, <>dict) {
        return {key: JacSerializer.serialize(value) for (key, value) in <>obj.items()};
    }
    if isinstance(<>obj, Archetype) {
        return JacSerializer._serialize_archetype(<>obj);
    }
    if <>obj?.__dict__ {
        with suppress(Exception) {
            return JacSerializer.serialize(
                {
                    k: v
                    for (k, v) in <>obj.__dict__.items()
                    if not k.startswith('_')
                }
            );
        }
    }
    return str(<>obj);
}

"""Serialize Archetype instances."""
impl JacSerializer._serialize_archetype(arch: Archetype) -> dict[str, JsonValue] {
    import from jaclang.pycore.constructs { NodeArchetype, WalkerArchetype }
    result: dict[(str, JsonValue)] = {
        '_jac_type': <>type(arch).__name__,
        '_jac_id': arch.__jac__.id.hex,
        '_jac_archetype': 'node'
        if isinstance(arch, NodeArchetype)
        else 'walker' if isinstance(arch, WalkerArchetype) else 'archetype'
    };
    for attr_name in dir(arch) {
        if (not attr_name.startswith('_') and (attr_name != '__jac__')) {
            with suppress(Exception) {
                attr_value = getattr(arch, attr_name);
                if not callable(attr_value) {
                    result[attr_name] = JacSerializer.serialize(attr_value);
                }
            }
        }
    }
    return result;
}
