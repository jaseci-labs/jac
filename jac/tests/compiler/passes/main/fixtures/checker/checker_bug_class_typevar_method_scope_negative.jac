"""A TypeVar no enclosing scope binds still has no meaning in that context."""

glob G = TypeVar('G');

obj Sibling[G] {
    has value: (G | None) = None;

    def keep -> list[G] {
        out: list[G] = [];
        return out;
    }
}

obj Plain {
    has tag: int = 0;

    def body_use {
        z: list[G] = [];
        print(z);
    }
}

obj AlsoPlain {
    has holder: list[G] = [];
}

obj Holder[P] {
    has slot: (P | None) = None;

    obj Nested {
        has kept: list[P] = [];

        def peek {
            seen: list[P] = [];
            print(seen);
        }
    }
}

glob at_module: list[G] = [];
