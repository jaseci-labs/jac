import from enum { Enum }
import from jaclang.compiler.types.type_utils { PropertyWriteKind }

class LegacyPropertyWriteKind(Enum) {
    with entry {
        NOT_PROPERTY = 0;
        READ_ONLY = 1;
        WRITABLE = 2;
    }
}

test "Jac property kinds preserve plain Enum values and identity" {
    for value in (0, 1, 2) {
        actual = PropertyWriteKind(value);
        expected = LegacyPropertyWriteKind(value);
        assert actual.name == expected.name;
        assert actual.value == expected.value;
        assert actual is PropertyWriteKind(value);
        assert (actual == value) == (expected == value);
        assert isinstance(actual, int) == isinstance(expected, int);
    }
}

test "Jac property kinds preserve invalid-value rejection" {
    for value in (-1, 3, 100) {
        rejected = False;
        try {
            PropertyWriteKind(value);
        } except ValueError {
            rejected = True;
        }
        assert rejected;
    }
}
