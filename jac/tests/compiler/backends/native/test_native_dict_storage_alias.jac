"""A bool-valued dict must not lend its storage to an int- or enum-valued one.

Every integer-like value type used to share one dict representation, so the
first `dict[str, bool]` literal in a unit fixed a 1-bit value slot and every
later `dict[str, int]` / `dict[str, SomeEnum]` literal adopted it: ordinals
and ints were stored through `i1` and read back as their low bit. The sealed
`unitree` unit hit this the moment `codeinfo`'s `dict[str, bool]` fields
joined its closure ahead of `Archetype.postinit`'s `{keyword: SymbolType}`
table, and every `node` became `SymbolType.MODULE` in the kit
(E1096/E1097/E1114 on every OSP program). Red-first: the fixture emits a bool
dict, then an enum dict and an int dict, and reads the members back.
"""

import ctypes;
import from pathlib { Path }
import from tests.support { compile_mir, compile_native, get_func, write_case }

test "a bool-valued dict does not alias an int or enum-valued dict's storage" {
    (eng, _) = compile_native("dict_bool_int_alias.jac");
    fn = get_func(eng, "probe", ctypes.c_int64, ctypes.c_int64);
    got = [fn(i) for i in range(4)];
    assert got == [606, 707, 811, 1111] , (
        f"got {got}: kind_code*100 + ints. A low-bit pattern (0/1 in either "
        "half) means the enum or int dict adopted the bool dict's i1 slot"
    );
}


test "dictionary values preserve nested set layouts during iteration" {
    case_dir = str(
        Path(
            write_case(
                """
def probe -> int {
    groups: dict[str, set[str]] = {
        "first": {"one", "two"}, "second": {"two", "three"}
    };
    combined: set[str] = set();
    for names in groups.values() { combined = combined | names; }
    return len(combined) * 100 + int("one" in combined) * 10
        + int("three" in combined);
}
""",
                "dictionary_value_sets.jac"
            )
        ).parent
    );
    (engine, _) = compile_native("dictionary_value_sets.jac", case_dir);
    demoted = compile_mir("dictionary_value_sets.jac", case_dir).demoted();
    assert not demoted , str(demoted);
    probe = get_func(engine, "probe", ctypes.c_int64);
    assert probe() == 311;
}


test "object hash layouts stay distinct from strings and other object classes" {
    (engine, _) = compile_native("object_hash_layouts.jac");
    demoted = compile_mir("object_hash_layouts.jac").demoted();
    assert not demoted , str(demoted);
    probe = get_func(engine, "probe", ctypes.c_int64);
    assert probe() == 157;
}
