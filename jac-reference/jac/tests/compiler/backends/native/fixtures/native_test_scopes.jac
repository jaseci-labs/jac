def read -> int {
    return 7;
}

test "first test owns its local callable" {
    seed = 3;
    def read -> int {
        return seed;
    }
    assert read() == 3;
}

test "second test resolves the module callable" {
    assert read() == 7;
}

with entry {
    assert read() == 7;
}
