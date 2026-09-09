import from jaclang.runtime.object_model {
    ObjectField,
    MISSING,
    fields as jac_fields,
    is_jac_object
}

def is_record(value: object) -> bool {
    if is_jac_object(value) {
        return True;
    }
    import dataclasses;
    return dataclasses.is_dataclass(value);
}

def fields(value: object) -> tuple[ObjectField, ...] {
    if is_jac_object(value) {
        return jac_fields(value);
    }
    import dataclasses;
    out: list[ObjectField] = [];
    for f in dataclasses.fields(value) {
        out.append(
            ObjectField(
                name=f.name,
                annotation=f.`type,
                `default=f.`default
                    if f.`default is not dataclasses.MISSING
                    else MISSING,
                default_factory=f.default_factory
                    if f.default_factory is not dataclasses.MISSING
                    else None,
                `init=f.`init,
                repr=f.repr,
                compare=f.compare,
                kw_only=f.kw_only,
                metadata=dict(f.metadata)
            )
        );
    }
    return tuple(out);
}
