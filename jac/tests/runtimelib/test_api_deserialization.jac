"""API decoding uses only the consumer's compiled boundary types, at any depth."""

import copy;
import from jaclang.data.serializer { Serializer }

class WireRecord {
    has value: int | str,
        nested: dict[str, list[any]],
        empty: list,
        _jac_id: str;

    def __new__(cls: type) -> any {
        raise AssertionError(
            "decoding must not invoke a constructor or spawn a walker"
        );
    }
}

class OtherWireRecord(WireRecord) {}

test "qualified API identities disambiguate same-named declarations and survive forwarding" {
    types = {"alpha.Record": WireRecord, "beta.Record": OtherWireRecord};
    wire = [
        {"_jac_type": "Record", "_jac_type_id": "alpha.Record", "value": 1},
        {"_jac_type": "Record", "_jac_type_id": "beta.Record", "value": 2}
    ];
    result: any = Serializer.deserialize_api(wire, types);
    assert type(result[0]) is WireRecord;
    assert type(result[1]) is OtherWireRecord;
    assert Serializer.serialize(result, api_mode=True) == wire;
    empty = object.__new__(WireRecord);
    serialized: any = Serializer.serialize(empty, api_mode=True);
    assert isinstance(serialized, dict);
    assert serialized["__type__"] == "WireRecord";
}

test "API values recursively decode without mutating the wire payload" {
    leaf = {"_jac_type": "Leaf", "_jac_id": "abc", "value": 42};
    wire = {
        "_jac_type": "Record",
        "nested": {"items": [leaf, None, {"deeper": leaf}]},
        "empty": [],
        "__class__": "must not overwrite object internals"
    };
    original = copy.deepcopy(wire);
    types = {"Record": WireRecord, "Leaf": WireRecord};
    result: any = Serializer.deserialize_api(wire, types);
    assert isinstance(result, WireRecord);
    assert isinstance(result.nested["items"][0], WireRecord);
    assert result.nested["items"][0].value == 42;
    assert result.nested["items"][0]._jac_id == "abc";
    assert result.nested["items"][1] is None;
    assert isinstance(result.nested["items"][2]["deeper"], WireRecord);
    assert result.empty == [];
    assert wire == original;
}

test "unknown API tags remain data while declared descendants are decoded" {
    wire = {
        "_jac_type": "Unknown",
        "__type__": "Popen",
        "__module__": "subprocess",
        "child": {"_jac_type": "Record", "value": "known"}
    };
    result: any = Serializer.deserialize_api(wire, {"Record": WireRecord});
    assert isinstance(result, dict);
    assert result["_jac_type"] == "Unknown";
    assert result["__module__"] == "subprocess";
    assert isinstance(result["child"], WireRecord);
    assert result["child"].value == "known";
}

test "declared API targets support untagged envelopes and existing instances" {
    result: any = Serializer.deserialize_api({"value": 42}, {}, WireRecord);
    assert isinstance(result, WireRecord);
    assert result.value == 42;
    assert Serializer.deserialize_api(result, {}, WireRecord) is result;
    assert Serializer.deserialize_api(None, {}, WireRecord) is None;
    assert Serializer.deserialize_api([1, "two", False, None, {}], {})
        == [1, "two", False, None, {}];
}
