"""Layer 3 unit tests: archetype alias registry + type coercion table.

Complements test_persistence_migration.jac (Layer 1+2 unit tests). These
cover the drift-tolerance surface that Layer 3 adds on top of fingerprint
detection: class rename resolution via alias, and value coercion for
common primitive/container/temporal type changes.
"""

import from datetime { date, datetime, time }
import from enum { Enum }
import from uuid { UUID, uuid4 }
import from jaclang.jac0core.archetype { NodeAnchor, Root }
# archetype_alias is an ambient Jac builtin (no import). Serializer is
# an explicit import because we directly test its internals here.
import from jaclang.runtimelib.serializer { Serializer }


# --- Alias registry ---------------------------------------------------------
obj _AliasTarget(Root) {
    has name: str = "";
}


@archetype_alias("oldmod.LegacyName")
obj _AliasedNewName(Root) {
    has name: str = "";
}


test "register_alias maps old qualified name to new class" {
    # _AliasedNewName's decorator ran at module load; alias should exist.
    mod = getattr(_AliasedNewName, '__module__');
    nm = getattr(_AliasedNewName, '__name__');
    key = f"{mod}.{nm}";
    assert Serializer._aliases.get("oldmod.LegacyName") == key , (
        f"alias not recorded: {Serializer._aliases}"
    );
    # _get_class should resolve the old name to the new class.
    resolved = Serializer._get_class("oldmod", "LegacyName");
    assert resolved is _AliasedNewName , (
        f"_get_class did not follow alias: got {resolved}"
    );
}


test "alias to same qualified name is a no-op (does not self-alias)" {
    mod = getattr(_AliasTarget, '__module__');
    nm = getattr(_AliasTarget, '__name__');
    key = f"{mod}.{nm}";
    before = dict(Serializer._aliases);
    Serializer.register_alias(key, _AliasTarget);
    assert key not in Serializer._aliases , (
        "self-aliases must be rejected to avoid resolution cycles"
    );
    assert Serializer._aliases == before;
}


test "_get_class returns None for truly unregistered class names" {
    resolved = Serializer._get_class("definitely.not", "Present");
    assert resolved is None;
}


# --- Coercion table ---------------------------------------------------------
test "coerce: primitive already matches target (no-op)" {
    assert Serializer.coerce(5, int) == (5, True);
    assert Serializer.coerce("x", str) == ("x", True);
    assert Serializer.coerce(True, bool) == (True, True);
}


test "coerce: str to int, float, bool, UUID" {
    assert Serializer.coerce("42", int) == (42, True);
    assert Serializer.coerce("3.14", float) == (3.14, True);
    assert Serializer.coerce("true", bool) == (True, True);
    assert Serializer.coerce("False", bool) == (False, True);
    u = uuid4();
    assert Serializer.coerce(str(u), UUID) == (u, True);
}


test "coerce: int, float, bool to str" {
    assert Serializer.coerce(5, str) == ("5", True);
    assert Serializer.coerce(3.14, str) == ("3.14", True);
    assert Serializer.coerce(True, str) == ("True", True);
}


test "coerce: int float bool cross-conversions" {
    assert Serializer.coerce(5, float) == (5.0, True);
    assert Serializer.coerce(5.9, int) == (5, True);  # truncation is expected
    assert Serializer.coerce(0, bool) == (False, True);
    assert Serializer.coerce(1, bool) == (True, True);
}


test "coerce: ISO string to datetime/date/time" {
    (v, ok) = Serializer.coerce("2026-04-14T10:30:00", datetime);
    assert ok and isinstance(v, datetime);
    (v, ok) = Serializer.coerce("2026-04-14", date);
    assert ok and isinstance(v, date);
    (v, ok) = Serializer.coerce("10:30:00", time);
    assert ok and isinstance(v, time);
}


test "coerce: list tuple widening" {
    assert Serializer.coerce([1, 2, 3], tuple) == ((1, 2, 3), True);
    assert Serializer.coerce((1, 2, 3), list) == ([1, 2, 3], True);
}


enum _Color { RED = "red", BLUE = "blue" }


test "coerce: Enum by value and by name" {
    assert Serializer.coerce("red", _Color) == (_Color.RED, True);
    # Name-based lookup fallback:
    assert Serializer.coerce("BLUE", _Color) == (_Color.BLUE, True);
}


test "coerce: Optional[T] unwraps, None passes through" {
    (v, ok) = Serializer.coerce(None, (int | None));
    assert v is None and ok;
    # Non-None coerces against the inner type.
    (v, ok) = Serializer.coerce("7", (int | None));
    assert v == 7 and ok;
}


test "coerce: unresolvable returns (val, False) but does not raise" {
    (v, ok) = Serializer.coerce("not-a-number", int);
    assert v == "not-a-number" and not ok;
}


test "coerce: unknown string annotation (forward ref) returns (val, False)" {
    # A raw string annotation (unresolved) must not pretend to coerce.
    (v, ok) = Serializer.coerce(42, "SomeUnknownType");
    assert v == 42 and not ok;
}


# --- Coercion integration with _deserialize_archetype ----------------------
obj _Typed(Root) {
    has count: int = 0,
        ratio: float = 0.0,
        label: str = "";
}


test "_deserialize_archetype coerces str to int when stored type changed" {
    # Build canonical data by serializing an instance, then mutate fields
    # to simulate drift from a past schema.
    original = _Typed(count=42, ratio=3.14, label="seven");
    raw = Serializer.serialize(original, include_type=True);
    assert isinstance(raw, dict);
    # Simulate: old schema had count as str, ratio as str, label as int.
    raw['count'] = '42';
    raw['ratio'] = '3.14';
    raw['label'] = 7;
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    assert getattr(arch, 'count') == 42;
    assert isinstance(getattr(arch, 'count'), int);
    assert getattr(arch, 'ratio') == 3.14;
    assert isinstance(getattr(arch, 'ratio'), float);
    assert getattr(arch, 'label') == "7";
    assert isinstance(getattr(arch, 'label'), str);
}


obj _Shrunken(Root) {
    has name: str = "";
}


test "_deserialize_archetype drops fields removed from schema" {
    original = _Shrunken(name="ok");
    raw = Serializer.serialize(original, include_type=True);
    assert isinstance(raw, dict);
    # Simulate: the old schema had `legacy_field` that was since removed.
    raw['legacy_field'] = 'stale';
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    assert getattr(arch, 'name') == 'ok';
    assert not hasattr(arch, 'legacy_field') , (
        "removed fields must not leak onto the rehydrated archetype"
    );
}
