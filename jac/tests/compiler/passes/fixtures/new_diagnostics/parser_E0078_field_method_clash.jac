"""A field and a method or ability of the same name: the later class
attribute replaces the field, so `self.<name>` reads a function. The
members of an `impl` block body clash the same way."""

obj Box {
    has grow: int = 3,
        size: int = 1;

    def grow -> int {
        return 7;
    }

    def area -> int {
        return self.size * self.size;
    }
}

walker Visit {
    can start with Root entry {
        visit [-->];
    }
}

node Spot {
    has rise: int = 3;

    can rise with Visit entry {
        print(self.rise);
    }
}

obj Crate;

impl Crate {
    has grow: int = 3;

    def grow -> int {
        return 7;
    }
}
