"""Serving sees constructor arguments independently of generated receiver names."""

import from jaclang.server.serving.coerce { coerce_value }
import from jaclang.server.serving.openapi { _object_schema }
import from jaclang.server.server { ModuleIntrospector }

obj Payload {
    has args: int,
        kwargs: str = "default";
}

walker Greeting {
    has name: str = "world";
}

test "object coercion and schemas use the public constructor signature" {
    value = coerce_value({"args": "7"}, Payload);
    assert value.args == 7;
    assert value.kwargs == "default";
    schemas: dict = {};
    _object_schema(Payload, schemas);
    schema = schemas["Payload"];
    assert set(schema["properties"]) == {"args", "kwargs"};
    assert schema["required"] == ["args"];
}

test "walker introspection excludes the generated receiver" {
    introspector = ModuleIntrospector("constructor_contract", None);
    fields = introspector.introspect_walker(Greeting)["fields"];
    assert set(fields) == {"name", "_jac_spawn_node"};
    assert not fields["name"]["required"];
}
