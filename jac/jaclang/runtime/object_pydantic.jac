import from contextvars { ContextVar }
import from typing { get_type_hints }
import from pydantic { GetCoreSchemaHandler }
import from pydantic_core { core_schema }
import from jaclang.runtime.object_model { fields, MISSING }

glob _schema_refs: ContextVar[dict[object, str] | None] = ContextVar(
         "jac_object_schema_refs", `default=None
     );

def object_schema(
    cls: type, source: object, handler: GetCoreSchemaHandler
) -> core_schema.CoreSchema {
    refs = _schema_refs.get() or {};
    if source in refs {
        return core_schema.definition_reference_schema(refs[source]);
    }
    ref = f"{cls.__module__}.{cls.__qualname__}:{id(source)}";
    token = _schema_refs.set(refs | {source: ref});
    try {
        schema = _build_object_schema(cls, handler);
        schema["ref"] = ref;
        return schema;
    } finally {
        _schema_refs.reset(token);
    }
}

def _build_object_schema(
    cls: type, handler: GetCoreSchemaHandler
) -> core_schema.CoreSchema {
    hints = get_type_hints(cls);
    declared: dict[str, core_schema.TypedDictField] = {};
    for f in fields(cls) {
        if not f.`init {
            continue;
        }
        declared[f.name] = core_schema.typed_dict_field(
            handler.generate_schema(hints.get(f.name, f.`type)),
            required=f.`default is MISSING and f.default_factory is None
        );
    }
    def construct(values: dict[str, object]) -> object {
        return cls(**values);
    }
    def serialize(value: object) -> dict[str, object] {
        return {f.name: getattr(value, f.name) for f in fields(cls)};
    }
    mapping = core_schema.typed_dict_schema(declared);
    construct_schema = core_schema.no_info_after_validator_function(construct, mapping);
    return core_schema.json_or_python_schema(
        json_schema=construct_schema,
        python_schema=core_schema.union_schema(
            [core_schema.is_instance_schema(cls), construct_schema]
        ),
        serialization=core_schema.plain_serializer_function_ser_schema(
            serialize, return_schema=mapping
        )
    );
}
