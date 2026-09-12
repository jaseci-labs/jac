"""Copy a real mutated native dictionary through the compiler materializer."""

import from jaclang.compiler.jc_materialize {
    CODE_NATDICT,
    CODE_STR,
    Mz,
    _copy_value,
    jc_reg_value
}

obj DictionaryOwner {
    has values: dict[str, str] = {};
}

def copy_sparse_dictionary(key_off: int, data_off: int, order_off: int) -> int {
    owner = DictionaryOwner();
    owner.values["one"] = "A";
    owner.values["two"] = "B";
    owner.values["three"] = "C";
    owner.values["four"] = "D";
    del owner.values["two"];
    del owner.values["four"];
    owner.values["five"] = "E";
    jc_reg_value(0, CODE_STR, 0, 0, 0, 0, 0);
    jc_reg_value(1, CODE_NATDICT, 0, 0, key_off, data_off, order_off);
    return _copy_value(Mz(), id(owner.values), 1);
}
