"""Unit tests for the typecache module (cached object-model field-type introspection)."""

import from uuid { UUID, uuid4 }
import from jaclang.runtime.typecache { get_field_types, invalidate, clear }
import from jaclang.runtime.constructs { Root }


obj _Simple {
    has name: str = "",
        count: int = 0,
        ratio: float = 0.0;
}


obj _WithGenerics {
    has tags: list[str] = [],
        meta: dict[str, int] = {},
        uid: UUID = uuid4(),
        maybe: (int | None) = None;
}


class _PlainClass {
    x: int = 0;
}


test "get_field_types returns correct types for a simple Jac object" {
    ft = get_field_types(_Simple);
    assert 'name' in ft and ft['name'] is str;
    assert 'count' in ft and ft['count'] is int;
    assert 'ratio' in ft and ft['ratio'] is float;
    assert len(ft) == 3;
}


test "get_field_types resolves generic and union annotations" {
    ft = get_field_types(_WithGenerics);
    assert 'tags' in ft;
    assert 'meta' in ft;
    assert 'uid' in ft;
    assert 'maybe' in ft;
    assert len(ft) == 4;
}


test "get_field_types returns empty dict for plain class" {
    ft = get_field_types(_PlainClass);
    assert ft == {};
}


test "cache hit returns the same dict object" {
    invalidate(_Simple);
    a = get_field_types(_Simple);
    b = get_field_types(_Simple);
    assert a is b , "second call must return the cached object";
}


test "invalidate clears one entry and recomputes on next call" {
    before = get_field_types(_Simple);
    invalidate(_Simple);
    after = get_field_types(_Simple);
    assert before is not after , "must be a fresh dict after invalidate";
    assert before == after , "values must still match";
}


test "clear removes all cached entries" {
    get_field_types(_Simple);
    get_field_types(_WithGenerics);
    clear();
    a = get_field_types(_Simple);
    b = get_field_types(_WithGenerics);
    # After clear, these are freshly computed (we just verify they work).
    assert len(a) == 3;
    assert len(b) == 4;
}


obj _MyNode(Root) {
    has label: str = "",
        value: int = 0;
}


test "get_field_types works on Jac archetypes" {
    ft = get_field_types(_MyNode);
    assert 'label' in ft and ft['label'] is str;
    assert 'value' in ft and ft['value'] is int;
}


test "external Python records retain field type introspection through the adapter" {
    import from tests.compiler.fixtures.python_evaluator_workloads {
        python_contract_record
    }
    record_type = python_contract_record();
    ft = get_field_types(record_type);
    assert ft["name"] is str;
    assert ft["items"] == list[int];
}
