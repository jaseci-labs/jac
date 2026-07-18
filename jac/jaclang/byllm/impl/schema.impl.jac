impl _type_to_schema(
    ty: type, title: str = "", desc: str = "", info: Info | None = None
) -> dict {
    title = title.replace("_", " ").title();
    context = ({"title": title} if title else {}) | (
        {"description": desc} if desc else {}
    );
    if info?.type_info {
        info_type: str = info.type_info[0] if isinstance(info.type_info, tuple) else "";
        info = info.type_info[1] if isinstance(info.type_info, tuple) else info;
    } elif isinstance(info, tuple) {
        info_type = info[0];
        info = info[1];
    } else {
        info_type = "";
    }
    semstr: str = ty?._jac_semstr or "";
    semstr = semstr or ty?.__doc__ or "";
    semstr_inner: dict[str, str] = ty?._jac_semstr_inner or {};

    if ty in (list, dict, set, tuple) {
        raise ConfigurationError(
            f"Untyped {ty.__name__} is not supported for schema generation. "
            f"Use {ty.__name__}[T, ...] instead."
        );
    }

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

    if get_origin(ty) in (Union, UnionType) {
        args = get_args(ty);
        return {
            "anyOf": [
                _type_to_schema(
                    arg,
                    info=(
                        info.type_info[i + 1]
                            if (
                                info
                                and info?.type_info
                                and info.type_info
                                and isinstance(info.type_info, (list, tuple))
                                and len(info.type_info) > i + 1
                            )
                            else None
                    ),
                ) for (i, arg) in enumerate(args)
            ],
            "title": title,

        } | context;
    }

    if get_origin(ty) is list {
        item_type: type = get_args(ty)[0];
        return {
            "type": "array",
            "items": _type_to_schema(
                item_type, info=info if info_type == "list" else None
            ),

        } | context;
    }

    if get_origin(ty) in (tuple, set) {
        origin = get_origin(ty).__name__;
        args = get_args(ty);
        if len(args) == 2 and args[1] is Ellipsis {
            item_type = args[0];
            return {
                "type": "array",
                "items": _type_to_schema(
                    item_type, info=info[1] if info[0] == "tuple" else None
                ),

            } | context;
        }
        raise ConfigurationError(
            f"Unsupported {origin} type for schema generation: {ty}. Only {origin} of the form {origin}[T, ...] are supported."
        );
    }

    if get_origin(ty) is dict {
        return _convert_dict_to_schema(ty) | context;
    }

    if is_dataclass(ty) {
        fields: dict[str, type] = {
            name: type
            for (name, type) in get_type_hints(ty).items()
            if not name.startswith("_")
        };
        if isinstance(info, FieldInfo) {
            info_fields = info.type_info.fields if info else [];
            ;
        } else {
            info_fields = info.fields if info else [];
        }

        info_fields_map = {field.name: field for field in info_fields};

        properties = {
            field_name: _type_to_schema(
                field_type,
                field_name,
                info_fields_map[field_name].semstr
                    if field_name in info_fields_map
                    else "",
                info=info_fields_map.get(field_name)
            ) for (field_name, field_type) in fields.items()
        };
        return {
            "title": title or ty.__name__,
            "description": semstr,
            "type": "object",
            "properties": properties,
            "required": list(properties.keys()),
            "additionalProperties": False,

        };
    }

    if isinstance(ty, type) and issubclass(ty, Enum) {
        enum_info_to_use = None;
        if isinstance(info, EnumInfo) {
            enum_info_to_use = info;
        } elif info and info?.type_info and isinstance(info.type_info, EnumInfo) {
            enum_info_to_use = info.type_info;
        }
        if enum_info_to_use and enum_info_to_use.members {
            enum_type = None;
            enum_names = [];
            enum_values = [];
            for member in enum_info_to_use.members {
                runtime_member = None;
                try {
                    runtime_member = ty.__members__.get(member.name);
                } except Exception {
                    runtime_member = None;
                }
                if runtime_member is None {
                    continue;
                }
                enum_names.append(member.name);
                enum_values.append(runtime_member.value);

                if member.type_info {
                    member_type_str = member.type_info;
                    if enum_type is None {
                        enum_type = member_type_str;
                    } elif member_type_str != enum_type {
                        raise ConfigurationError(
                            f"Enum {ty.__name__} has mixed types. Not supported for schema generation."
                        );
                    }
                }
            }

            enum_type = enum_type or "int";

            if enum_type not in ("int", "str") {
                raise ConfigurationError(
                    f"Enum {ty.__name__} has unsupported type {enum_type}. "
                    "Only int and str enums are supported for schema generation."
                );
            }

            names_str = ", ".join(enum_names);
            if enum_values {
                enum_desc = f"\nThe value *should* be one in this list: {enum_values} where the names are [{names_str}].";
            } else {
                enum_desc = f"\nThe value *should* be one of the following the names are [{names_str}].";
            }
            enum_semstr = [
                member.semstr
                for member in enum_info_to_use.members
                if member.semstr
            ];
            if enum_semstr {
                enum_desc += "\nDetails:\n" + "\n".join(
                    [
                        f"- {member.name}: {member.semstr}"
                        for member in enum_info_to_use.members
                        if member.semstr
                    ]
                );
            }
            base_desc = enum_info_to_use.semstr or semstr or "";
            full_desc = f"{base_desc}{enum_desc}";
            schema_out: dict = {
                "description": full_desc,
                "type": "integer" if enum_type == "int" else "string",

            };

            if enum_values {
                schema_out["enum"] = enum_values;
            }
            return schema_out;
        }

        enum_type = None;
        enum_values = [];
        for member in ty.__members__.values() {
            enum_values.append(member.value);
            if enum_type is None {
                enum_type = type(member.value);
            } elif type(member.value) is not enum_type {
                raise ConfigurationError(
                    f"Enum {ty.__name__} has mixed types. Not supported for schema generation."
                );
            }
            enum_type = enum_type or int;
        }
        enum_desc = f"\nThe value *should* be one in this list: {enum_values} where";
        enum_desc += " the names are [" + ", ".join([e.name for e in ty]) + "].";
        if enum_type not in (int, str) {
            raise ConfigurationError(
                f"Enum {ty.__name__} has unsupported type {enum_type}. "
                "Only int and str enums are supported for schema generation."
            );
        }
        schema_fb: dict = {
            "description": semstr + enum_desc,
            "type": "integer" if enum_type is int else "string",

        };
        if enum_values {
            schema_fb["enum"] = enum_values;
        }
        return schema_fb;
    }

    if isinstance(ty, (FunctionType, MethodType)) {
        hints = get_type_hints(ty);
        hints.pop("return", None);

        if info and info?.params and info.params {
            sem_by_name = {p.name: p for p in info.params};
            params = {
                param_name: _type_to_schema(
                    param_type,
                    param_name,
                    sem_by_name[param_name].semstr if param_name in sem_by_name else "",
                    info=sem_by_name.get(param_name)
                ) for (param_name, param_type) in hints.items()
            };
        } else {
            params = {
                param_name: _type_to_schema(param_type, param_name)
                for (param_name, param_type) in hints.items()
            };
        }
        return {
            "title": title or ty.__name__,
            "type": "function",
            "description": semstr,
            "properties": params,
            "required": list(params.keys()),
            "additionalProperties": False,

        };
    }
    raise ConfigurationError(
        f"Unsupported type for schema generation: {ty}. Only primitive types, dataclasses, and Union types are supported."
    );
}

impl _name_of_type(ty: type, info: Info = None) -> str {
    if get_origin(ty) in (Union, UnionType) {
        names = [_name_of_type(arg) for arg in get_args(ty)];
        return "_or_".join(names);
    }
    if ty?.__name__ {
        return ty.__name__;
    }
    return "type";
}

impl _convert_dict_to_schema(ty_dict: type) -> dict {
    if get_origin(ty_dict) is not dict {
        raise ConfigurationError(f"Expected a dictionary type, got {ty_dict}.");
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

impl _unwrap_from_object(json_obj: dict) -> dict {
    if _SCHEMA_OBJECT_WRAPPER in json_obj {
        return json_obj[_SCHEMA_OBJECT_WRAPPER];
    }
    return json_obj;
}

impl type_to_schema(resp_type: type, info: Info) -> dict[str, object] {
    type_name = _name_of_type(resp_type, info=info);
    schema = _type_to_schema(resp_type, type_name, info=info);
    schema = _wrap_to_object(schema);
    return {
        "type": "json_schema",
        "json_schema": {"name": type_name, "schema": schema, "strict": True,},

    };
}

impl tool_to_schema(
    func: Callable, description: str, params_desc: dict[str, str], info: Info
) -> dict[str, object] {
    schema = _type_to_schema(func, info=info);
    properties: dict[str, object] = schema.get("properties", {});
    required: list[str] = schema.get("required", []);
    for (param_name, param_info) in properties.items() {
        param_info["description"] = params_desc.get(param_name, "");
        param_info.pop("title", None);
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

impl json_to_instance(json_obj: dict, ty: type) -> object {
    json_obj = _unwrap_from_object(json_obj);
    json_obj = _decode_dict(json_obj);
    return TypeAdapter(ty).validate_python(json_obj);
}

impl _format_enum_hint(values: list, names: list) -> str {
    if not values {
        return "";
    }
    pairs: list[str] = [];
    for (i, v) in enumerate(values) {
        if i < len(names) {
            pairs.append(f"{v}={names[i]}");
        } else {
            pairs.append(f"{v}");
        }
    }
    return ", ".join(pairs);
}

impl _hints_from_schema(name: str, prop: dict) -> list[str] {
    out: list[str] = [];
    if not isinstance(prop, dict) {
        return out;
    }
    desc = prop.get("description");
    enum_vals = prop.get("enum");
    ty = prop.get("type", "");
    label = name or "value";
    if isinstance(enum_vals, list) and enum_vals {
        names: list[str] = [];
        if isinstance(desc, str) and "names are [" in desc {
            chunk = desc.split("names are [", 1)[1];
            chunk = chunk.split("]", 1)[0];
            names = [
                n.strip()
                for n in chunk.split(",")
                if n.strip()
            ];
        }
        hint = _format_enum_hint(enum_vals, names);
        if hint {
            out.append(f"- {label} must be one of: {hint}");
        } else {
            out.append(f"- {label} must be one of: {enum_vals}");
        }
    } elif ty {
        suffix = ' -- ' + desc if isinstance(desc, str) and desc else '';
        out.append(f"- {label} ({ty}){suffix}");
    }

    if prop.get("type") == "object" {
        nested = prop.get("properties");
        if isinstance(nested, dict) {
            for (sub, sub_prop) in nested.items() {
                if sub != name {
                    out.extend(_hints_from_schema(sub, sub_prop));
                }
            }
        }
    }
    return out;
}

impl schema_to_hint_text(rf: dict | None) -> str {
    if not isinstance(rf, dict) {
        return "";
    }

    schema: dict | None = None;
    rf_type = rf.get("type");
    if rf_type == "json_schema" {
        js = rf.get("json_schema");
        if isinstance(js, dict) {
            inner = js.get("schema");
            if isinstance(inner, dict) {
                schema = inner;
            }
        }
    } elif rf_type == "json_object" {
        inner2 = rf.get("schema");
        if isinstance(inner2, dict) {
            schema = inner2;
        }
    }
    if schema is None {
        return "";
    }
    props = schema.get("properties");
    if not isinstance(props, dict) {
        return "";
    }
    lines: list[str] = [];
    for (name, prop) in props.items() {
        if isinstance(prop, dict) {
            lines.extend(_hints_from_schema(name, prop));
        }
    }
    if not lines {
        return "";
    }
    return "Schema requirements:\n" + "\n".join(lines);
}

impl attach_schema_hint(messages: list, rf: dict | None) -> list {
    hint: str = schema_to_hint_text(rf);
    if not hint or not messages {
        return messages;
    }
    last_user_idx: int = -1;
    for (i, m) in enumerate(messages) {
        if isinstance(m, dict) {
            mdict: dict = m;
            if mdict.get("role") == "user" {
                last_user_idx = i;
            }
        }
    }
    if last_user_idx < 0 {
        return messages;
    }
    out: list = list(messages);
    target_raw = out[last_user_idx];
    if not isinstance(target_raw, dict) {
        return messages;
    }
    target: dict = dict(target_raw);
    body = target.get("content", "");
    if isinstance(body, str) {
        body_str: str = body;
        if hint in body_str {
            return messages;
        }
        target["content"] = body_str.rstrip() + "\n\n" + hint;
    } elif isinstance(body, list) {
        body_list: list = body;
        for part in body_list {
            if isinstance(part, dict) and part.get("type") == "text" {
                if hint in str(part.get("text", "")) {
                    return messages;
                }
            }
        }
        target["content"] = body_list + [{"type": "text", "text": hint}];
    } else {
        return messages;
    }
    out[last_user_idx] = target;
    return out;
}

impl inject_schema_hint(params: dict) -> dict {
    rf = params.get("response_format");
    msgs = params.get("messages");
    if not isinstance(msgs, list) or rf is None {
        return params;
    }
    new_msgs = attach_schema_hint(msgs, rf);
    if new_msgs is msgs {
        return params;
    }
    out: dict = dict(params);
    out["messages"] = new_msgs;
    return out;
}
