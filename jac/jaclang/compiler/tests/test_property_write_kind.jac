"""The type evaluator builds PropertyWriteKind from the provider's raw
property_kind() integer, so the numbering is a contract."""
test "property write kinds keep the numbers providers report" {
    assert PropertyWriteKind(0) is PropertyWriteKind.NOT_PROPERTY;
    assert PropertyWriteKind(1) is PropertyWriteKind.READ_ONLY;
    assert PropertyWriteKind(2) is PropertyWriteKind.WRITABLE;
    for value in (-1, 3) {
        rejected = False;
        try {
            PropertyWriteKind(value);
        } except ValueError {
            rejected = True;
        }
        assert rejected , value;
    }
}
