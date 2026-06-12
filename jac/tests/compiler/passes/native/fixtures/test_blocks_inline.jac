"""Fixture: test blocks inside an inline na {} block of a regular module."""

na {
    def double(x: int) -> int {
        return x * 2;
    }

    test "inline double works" {
        assert double(21) == 42;
    }

    test "inline deliberate failure" {
        assert double(2) == 5;
    }
}

with entry {}
