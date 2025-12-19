"""Convert a Python type to a JSON schema representation.

Handles primitive types, Union types, lists, tuples, sets, dicts,
dataclasses, enums, and functions.
"""
impl _type_to_schema(ty: type, title: str = "", desc: str = "") -> dict {
    title = title.replace("_", " ").title();
    context = ({"title": title} if title else {}) | (
        {"description": desc} if desc else {}
    );
    semstr: str = ty._jac_semstr if ty?._jac_semstr else "";
    semstr = semstr or (ty.__doc__ if ty?.__doc__ else "") or "";  # type: ignore
    semstr_inner: dict[str, str] = (
        ty._jac_semstr_inner if ty?._jac_semstr_inner else {}
    );
    # Raise on unsupported types
    if ty in (list, dict, set, tuple) {
        raise ValueError(
            f"Untyped {ty.__name__} is not supported for schema generation. "
            f"Use {ty.__name__}[T, ...] instead."
        ) ;
    }
    # Handle primitive types
    if ty is type(None) {
        return {"type": "null"} | context;
    }
    if ty is bool {
        return {"type": "boolean"} | context;
    }
    if ty is int {
        return {"type": "integer"} | context;
    }
    if ty is float {
        return {"type": "number"} | context;
    }
    if ty is str {
        return {"type": "string"} | context;
    }
    # Handle Union
    if get_origin(ty) in (Union, UnionType) {
        args = get_args(ty);
        return {"anyOf": [_type_to_schema(arg) for arg in args], "title": title,} | context;
    }
    # Handle annotated list
    if get_origin(ty) is list {
        item_type: type = get_args(ty)[0];
        return {"type": "array", "items": _type_to_schema(item_type),} | context;
    }
    # Handle annotated tuple/set
    if get_origin(ty) in (tuple, set) {
        origin = get_origin(ty).__name__;  # type: ignore
        args = get_args(ty);
        if len(args) == 2 and args[1] is Ellipsis {
            item_type = args[0];
            return {"type": "array", "items": _type_to_schema(item_type),} | context;
        }
        raise ValueError(
            f"Unsupported {origin} type for schema generation: {ty}. Only {origin} of the form {origin}[T, ...] are supported."
        ) ;
    }
    # Handle annotated dictionaries
    if get_origin(ty) is dict {
        return _convert_dict_to_schema(ty) | context;
    }
    # Handle dataclass
    if is_dataclass(ty) {
        fields: dict[str, type] = {
            name: type
            for (name, type) in get_type_hints(ty).items()
            if not name.startswith("_")
        };
        properties = {
            name: _type_to_schema(
                type, name, semstr_inner.get(name, "")
            )  # type: ignore
             for (name, type) in fields.items()
        };
        return {
            "title": title or ty.__name__,
            "description": semstr,
            "type": "object",
            "properties": properties,
            "required": list(fields.keys()),
            "additionalProperties": False,

        };
    }
    # Handle enums
    if isinstance(ty, type) and issubclass(ty, Enum) {
        enum_type = None;
        enum_values = [];
        for member in ty.__members__.values() {
            enum_values.append(member.value);
            if enum_type is None {
                enum_type = type(member.value);
            } elif type(member.value) is not enum_type {
                raise ValueError(
                    f"Enum {ty.__name__} has mixed types. Not supported for schema generation."
                ) ;
            }
            enum_type = enum_type or int;
        }
        enum_desc = f"\nThe value *should* be one in this list: {enum_values} where";
        enum_desc += " the names are [" + ", ".join([e.name for e in ty]) + "].";
        if enum_type not in (int, str) {
            raise ValueError(
                f"Enum {ty.__name__} has unsupported type {enum_type}. "
                "Only int and str enums are supported for schema generation."
            ) ;
        }
        return {
            "description": semstr + enum_desc,
            "type": "integer" if enum_type is int else "string",

        };
    }
    # Handle functions
    if isinstance(ty, (FunctionType, MethodType)) {
        hints = get_type_hints(ty);
        hints.pop("return", None);
        params = {
            name: _type_to_schema(type, name, semstr_inner.get(name, ""))
            for (name, type) in hints.items()
        };
        return {
            "title": title or ty.__name__,
            "type": "function",
            "description": semstr,
            "properties": params,
            "required": list(params.keys()),
            "additionalProperties": False,

        };
    }
    raise ValueError(
        f"Unsupported type for schema generation: {ty}. Only primitive types, dataclasses, and Union types are supported."
    ) ;
}

"""Get a string name for a type, handling Union types specially."""
impl _name_of_type(ty: type) -> str {
    if get_origin(ty) in (Union, UnionType) {
        names = [_name_of_type(arg) for arg in get_args(ty)];
        return "_or_".join(names);
    }
    if ty?.__name__ {
        return ty.__name__;
    }
    return "type";
}

"""Convert a dictionary type to a schema with key-value array structure."""
impl _convert_dict_to_schema(ty_dict: type) -> dict {
    if get_origin(ty_dict) is not dict {
        raise ValueError(f"Expected a dictionary type, got {ty_dict}.") ;
    }
    (key_type, value_type) = get_args(ty_dict);
    return {
        "type": "object",
        "title": _SCHEMA_DICT_WRAPPER,
        "properties": {
            _SCHEMA_DICT_WRAPPER: {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "key": _type_to_schema(key_type),
                        "value": _type_to_schema(value_type),

                    },
                    "required": ["key", "value"],
                    "additionalProperties": False,

                },

            }
        },
        "additionalProperties": False,
        "required": [_SCHEMA_DICT_WRAPPER],

    };
}

"""Decode a JSON dictionary from wrapped key-value array format."""
impl _decode_dict(json_obj: dict) -> dict {
    if not isinstance(json_obj, dict) {
        return json_obj;
    }
    if _SCHEMA_DICT_WRAPPER in json_obj {
        items = json_obj[_SCHEMA_DICT_WRAPPER];
        return {item["key"]: _decode_dict(item["value"]) for item in items};
    }
    return {key: _decode_dict(value) for (key, value) in json_obj.items()};
}

"""Wrap a non-object schema in an object wrapper for API compatibility."""
impl _wrap_to_object(schema: dict[str, object]) -> dict[str, object] {
    if "type" in schema and schema["type"] == "object" {
        return schema;
    }
    return {
        "type": "object",
        "title": _SCHEMA_OBJECT_WRAPPER,
        "properties": {_SCHEMA_OBJECT_WRAPPER: schema,},
        "required": [_SCHEMA_OBJECT_WRAPPER],
        "additionalProperties": False,

    };
}

"""Unwrap a JSON object from the object wrapper if present."""
impl _unwrap_from_object(json_obj: dict) -> dict {
    if _SCHEMA_OBJECT_WRAPPER in json_obj {
        return json_obj[_SCHEMA_OBJECT_WRAPPER];
    }
    return json_obj;
}

"""Return the JSON schema for a response type, formatted for LLM APIs."""
impl type_to_schema(resp_type: type) -> dict[str, object] {
    type_name = _name_of_type(resp_type);
    schema = _type_to_schema(resp_type, type_name);
    schema = _wrap_to_object(schema);
    return {
        "type": "json_schema",
        "json_schema": {"name": type_name, "schema": schema, "strict": True,},

    };
}

"""Return the JSON schema for a tool function, formatted for LLM APIs."""
impl tool_to_schema(
    func: Callable, description: str, params_desc: dict[str, str]
) -> dict[str, object] {
    schema = _type_to_schema(func);  # type: ignore
    properties: dict[str, object] = schema.get("properties", {});  # type: ignore
    required: list[str] = schema.get("required", []);  # type: ignore
    for (param_name, param_info) in properties.items() {
        param_info["description"] = params_desc.get(param_name, "");  # type: ignore
    }
    return {
        "type": "function",
        "function": {
            "name": func.__name__,
            "description": description,
            "parameters": {
                "type": "object",
                "properties": properties,
                "required": required,
                "additionalProperties": False,

            },

        },

    };
}

"""Convert a JSON dictionary to an instance of the given type."""
impl json_to_instance(json_obj: dict, ty: type) -> object {
    json_obj = _unwrap_from_object(json_obj);
    json_obj = _decode_dict(json_obj);
    return TypeAdapter(ty).validate_python(json_obj);
}
