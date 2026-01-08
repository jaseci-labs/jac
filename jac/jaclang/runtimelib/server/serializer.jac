"""Type-safe serializer for Jac objects."""
import from typing { TYPE_CHECKING }
import from jaclang.runtimelib.server.types { JsonValue }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.constructs { Archetype }
    }
}

"""Type-safe serializer for Jac objects."""
obj JacSerializer {
    static def serialize(<>obj: object) -> JsonValue;
    static def _serialize_archetype(arch: Archetype) -> dict[str, JsonValue];
}
