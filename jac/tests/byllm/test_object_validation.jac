import from pydantic { TypeAdapter, ValidationError }
import from jaclang.runtime.object_model { field }

obj AdapterChild {
    has name: str;
}

obj AdapterParent {
    has child: AdapterChild,
        count: int = 2,
        tags: list[str] = field(default_factory=`list);
}

obj AdapterLink {
    has value: int,
        next: AdapterLink | None = None;
}

test "Jac object adapters validate nested fields and retain constructor defaults" {
    adapter = TypeAdapter(AdapterParent);
    first = adapter.validate_python({"child": {"name": "Ada"}});
    second = adapter.validate_python({"child": {"name": "Bob"}});
    assert first.child.name == "Ada";
    assert first.count == 2;
    first.tags.append("first");
    assert not second.tags;
    assert adapter.validate_python(first) is first;
    assert adapter.validate_json('{"child":{"name":"Joe"}}').child.name == "Joe";
    assert adapter.dump_python(first)
        == {"child": {"name": "Ada"}, "count": 2, "tags": ["first"]};
    rejected = False;
    try {
        adapter.validate_python({"child": {"name": []}});
    } except ValidationError {
        rejected = True;
    }
    assert rejected;
}

test "Jac object adapters support recursive fields without retaining schema state" {
    adapter = TypeAdapter(AdapterLink);
    value = adapter.validate_python({"value": 1, "next": {"value": 2}});
    next_link = value.next;
    assert next_link is not None;
    assert next_link.value == 2;
    assert next_link.next is None;
    assert TypeAdapter(AdapterLink).validate_python({"value": 3}).next is None;
    schema = adapter.json_schema();
    assert "$defs" in schema;
}
