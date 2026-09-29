"""Native `==` / `!=` is Python's structural equality, not pointer identity.

Dictionaries compare by their key/value pairs whatever the insertion order;
containers nested inside containers compare (and answer `in`) by content
rather than through the erased element pointer; dictionary views compare as sets (keys, items) or
by identity (values); and archetypes answer through their own `__eq__` /
`__ne__`, honouring Python's subclass-first rule.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity, compile_native_ir }
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }

glob FIXTURE: str = "container_equality.jac";

test "container equality lowers natively through structural comparisons" {
    module = compile_native_ir(FIXTURE);
    llvm = str(module.gen.llvm_ir);
    issues = native_lowering_issues(llvm);
    assert not issues , str(issues);
    assert "__jac_eq_dict" in llvm , "dictionary == must walk the entries, not compare addresses";
    assert "__jac_eq_setlike" in llvm , "key/item views must compare as sets";
    assert "cmp__eq__" in llvm or "call.__eq__" in llvm , "archetype == must call __eq__";
}

test "container equality agrees with Python under the managed profiles" {
    # The full fixture nests containers inside literals, which the headerless
    # (nogc) profile's ownership rules reject; its own fixture follows.
    source = str(Path(__file__).resolve().parent / "fixtures" / FIXTURE);
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    for line in [
        "str-int True False False False",
        "mutation pop False 2 3",
        "nested True False True",
        "dunder True False False True",
        "virtual True True True",
        "ne False True True",
        "list-list True False True",
        "list-dict True False",
        "tuple-dict True False",
        "index 0 1",
        "in-list True False True False",
        "in-list-dunder True True",
        "in-tuple True False True False",
        "keys True False True",
        "items True False",
        "values False True",
        "keys-set True True False",
        "keys-list False"
    ] {
        assert line in out.splitlines() , f"missing {line!r} in:\n{out}";
    }
}

test "dictionary and view equality agree with Python under every memory profile" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "container_equality_nogc.jac"
    );
    assert assert_native_identity(source).splitlines()
        == [
            "str-int True False False False",
            "int-float True False",
            "mutated False True",
            "list-list True False",
            "keys True False False",
            "dunder True True"
        ];
}
