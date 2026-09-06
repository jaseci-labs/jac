"""Jac field semantics are independent of Python's dataclass implementation."""
import from inspect { signature, Parameter }
import from jaclang.runtime.object_model {
    ObjectField,
    MISSING,
    field,
    fields,
    is_jac_object,
    make_object,
    asdict
}

@make_object
class BaseFields {
    has value: int = 3;
}

def derived_model(cls: type) -> type {
    setattr(cls, "items", field(default_factory=`list));
    setattr(cls, "hidden", field(`default=7, repr=False, `init=False));
    return make_object(cls);
}

@derived_model
class DerivedFields(BaseFields) {
    has required: str,
        items: list[int],
        hidden: int;

    with entry {
        category: ClassVar[str] = "example";
    }
}

@make_object
class CustomInit {
    has value: int;

    def init(self: CustomInit, value: int) {
        self.value = value * 2;
    }
}

def postinit_model(cls: type) -> type {
    setattr(cls, "ready", field(`init=False));
    return make_object(cls);
}

@postinit_model
class PostInit {
    has value: int = 1,
        ready: bool;

    def postinit(self: PostInit) {
        self.ready = True;
    }
}

test "field order, keyword-only requirements and factories are Jac-owned" {
    first = DerivedFields(required="a");
    second = DerivedFields(required="b");
    first.items.append(9);
    assert second.items == [];
    assert first.hidden == 7;
    assert [f.name for f in fields(DerivedFields)]
        == ["value", "required", "items", "hidden"];
    assert signature(DerivedFields).parameters["required"].kind
        == Parameter.KEYWORD_ONLY;
    assert "hidden=" not in repr(first);
    assert is_jac_object(first);
    assert not hasattr(DerivedFields, "__dataclass_fields__");
    assert first != DerivedFields(required="a");
}

test "explicit constructors and post initialization retain their behavior" {
    assert CustomInit(4).value == 8;
    assert PostInit().ready;
}

test "reflection copies values and does not mutate class field metadata" {
    value = DerivedFields(required="a");
    value.items.append(2);
    copied = asdict(value);
    value.items.append(3);
    assert copied["items"] == [2];
    assert not fields(BaseFields)[0].kw_only;
    assert all(isinstance(f, ObjectField) for f in fields(value));
}

test "a default and a factory cannot describe the same field" {
    rejected = False;
    try {
        field(`default=[], default_factory=`list);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
    assert field().`default is MISSING;
}

glob _jac_runtime_field: int = 99;

obj JacFields {
    has items: list[int] = [],
        label: str = "ready";
}

node JacNodeFields {
    has values: list[int] = [];
}

walker JacWalkerFields {
    has count: int = 0;
}

test "compiled Jac archetypes use Jac fields and independent mutable defaults" {
    first = JacFields();
    second = JacFields();
    first.items.append(1);
    assert second.items == [];
    assert _jac_runtime_field == 99;
    assert is_jac_object(first);
    assert not hasattr(JacFields, "__dataclass_fields__");
    nd = JacNodeFields();
    assert is_jac_object(nd);
    assert not hasattr(JacNodeFields, "__dataclass_fields__");
    w = JacWalkerFields();
    assert w.reports == [];
    assert not hasattr(JacWalkerFields, "__dataclass_fields__");
}

@make_object
class GeneratedNames {
    has _jac_self: int,
        _missing: int = 2,
        _value_1: int = 3;
}

test "constructor implementation names do not collide with fields" {
    instance = GeneratedNames(1);
    assert instance._jac_self == 1;
    assert instance._missing == 2;
    assert instance._value_1 == 3;
}

obj ExplicitFields {
    has values: list[int] = field(default_factory=`list),
        count: int = field(`default=4),
        ready: bool = field(`init=False);

    def postinit {
        self.ready = True;
    }
}

obj RequiredAfterDefaults(JacFields) {
    has required: str;
}

test "field declarations retain defaults, factories and deferred initialization" {
    first = ExplicitFields();
    second = ExplicitFields();
    first.values.append(7);
    assert second.values == [];
    assert first.count == 4;
    assert first.ready;
    assert "ready" not in signature(ExplicitFields).parameters;
    child = RequiredAfterDefaults(required="present");
    assert child.required == "present";
    assert child.items == [];
}
