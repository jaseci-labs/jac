"""Persisted declaration identity is semantic data, not an accessor cache."""
import from jaclang.compiler.ir.types.nodes { ClassDetailsShared }
import from jaclang.compiler.ir.schema { Module }

test "catalog identity survives relation changes and cache clearing" {
    identity = ("/catalog/provider.pyi", 42, 1, "Value");
    first = ClassDetailsShared(
        class_name="Value",
        symbol_table=Module.make_stub(inject_name="catalog-placeholder"),
        declaration_identity=identity
    );
    second = ClassDetailsShared(
        class_name="Value",
        symbol_table=Module.make_stub(inject_name="other-placeholder"),
        declaration_identity=identity
    );
    assert first.canonical_key() == identity;
    first.mro = [];
    first._identity_key = None;
    first._identity_generation = -1;
    assert first.canonical_key() == identity;
    assert first.same_class(second);
    unrelated = ClassDetailsShared(
        class_name="Value",
        symbol_table=Module.make_stub(inject_name="unrelated-placeholder"),
        declaration_identity=("/catalog/unrelated.pyi", 42, 1, "Value")
    );
    assert not first.same_class(unrelated);
}
