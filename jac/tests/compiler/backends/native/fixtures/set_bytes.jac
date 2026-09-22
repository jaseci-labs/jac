with entry {
    for data in [b"", b"\x00\x80\xff\x80\x00", b"\x01\x02\x01"] {
        values = set(data);
        frozen = frozenset(data);
        assert len(values) == len(frozen);
        for byte in data {
            assert byte in values and byte in frozen;
        }
        assert 256 not in values and -1 not in values;
        values.add(256);
        assert 256 in values and 256 not in frozen;
    }
    data = bytes([i for i in range(256)]);
    values = set(data + data);
    assert len(values) == 256;
    for i in range(256) {
        assert i in values;
    }
    assert set(b"") == set();
    assert set(b"\xff\x00") == {255, 0};
    assert frozenset(b"\xff\x00") == frozenset([255, 0]);
    print("bytes sets pass");
}
