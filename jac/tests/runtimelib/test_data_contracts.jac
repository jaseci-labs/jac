import from jaclang.data.contracts { ContractError, decode_contract }

obj ContractChild {
    has name: str;
}

obj ContractRecord {
    has child: ContractChild,
        items: list[int] = [];
}

test "external contracts decode Jac records with independent defaults" {
    first = decode_contract({"child": {"name": "first"}}, ContractRecord);
    second = decode_contract({"child": {"name": "second"}}, ContractRecord);
    assert isinstance(first, ContractRecord);
    assert isinstance(first.child, ContractChild);
    assert first.child.name == "first";
    first.items.append(3);
    assert second.items == [];
    try {
        decode_contract({"child": {}}, ContractRecord);
        assert False , "missing nested required field was accepted";
    } except ContractError as error {
        assert "response.child.name: missing required field" in str(error);
    }
}

test "external contracts retain Python dataclass compatibility" {
    import dataclasses;
    Record = dataclasses.make_dataclass(
        "PythonContractRecord",
        [("name", str), ("items", list[int], dataclasses.field(default_factory=list))]
    );
    first = decode_contract({"name": "first"}, Record);
    second = decode_contract({"name": "second"}, Record);
    assert type(first) is Record;
    first.items.append(3);
    assert second.items == [];
    try {
        decode_contract({}, Record);
        assert False , "missing required field was accepted";
    } except ContractError as error {
        assert "response.name: missing required field" in str(error);
    }
}
