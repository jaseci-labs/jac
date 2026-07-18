"""Unit tests for the typecache module (cached dataclass field-type introspection)."""

import from dataclasses { dataclass, field }
import from uuid { UUID, uuid4 }
import from jaclang.runtimelib.typecache { get_field_types, invalidate, clear }
import from jaclang.jac0core.constructs { Root }


@dataclass
class _Simple {
    name: str = "";
    count: int = 0;
    ratio: float = 0.0;
}


@dataclass
class _WithGenerics {
    tags: list[str] = field(default_factory=list);
    meta: dict[str, int] = field(default_factory=dict);
    uid: UUID = field(default_factory=uuid4);
    maybe: (int | None) = None;
}


class _NotDataclass {
    x: int = 0;
}


test "get_field_types returns correct types for a simple dataclass" {
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


test "get_field_types returns empty dict for non-dataclass" {
    ft = get_field_types(_NotDataclass);
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
