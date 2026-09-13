"""Copy a real mutated native dictionary through the compiler materializer."""

import from jaclang.compiler.frontend.kernel.materialize {
    CODE_NATDICT,
    CODE_OBJ,
    CODE_STR,
    Mz,
    _copy_value,
    _enqueue_value,
    jc_reg_value
}

import from jaclang.runtime.osp_graph { osp_adj_pairs }

node DictionaryOwner {
    has values: dict[str, str] = {},
        children: dict[str, DictionaryOwner] = {};
}

def:pub copy_sparse_dictionary(key_off: int, data_off: int, order_off: int) -> int {
    owner = DictionaryOwner();
    assert len(osp_adj_pairs(id(owner), 0)) == 0;
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

def:pub enqueue_sparse_dictionary(key_off: int, data_off: int, order_off: int) -> int {
    owner = DictionaryOwner();
    first = DictionaryOwner();
    third = DictionaryOwner();
    fifth = DictionaryOwner();
    owner.children["one"] = first;
    owner.children["two"] = DictionaryOwner();
    owner.children["three"] = third;
    owner.children["four"] = DictionaryOwner();
    del owner.children["two"];
    del owner.children["four"];
    owner.children["five"] = fifth;
    jc_reg_value(0, CODE_OBJ, 42, 0, 0, 0, 0);
    jc_reg_value(1, CODE_NATDICT, 0, 0, key_off, data_off, order_off);
    pending = Mz();
    _enqueue_value(pending, id(owner.children), 1);
    return 1
        if pending.q == [id(first), id(third), id(fifth)]
            and pending.q_hint == [42, 42, 42]
        else 0;
}
