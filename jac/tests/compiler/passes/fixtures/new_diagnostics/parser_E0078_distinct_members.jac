"""Fields, methods and abilities with distinct names, a field whose
property accessors share its name, and fields named `init`/`postinit`
beside the constructor hooks (which become `__init__`/`__post_init__`),
are not clashes, in an archetype body or an `impl` block body."""

obj Meter {
    has level: int = 0,
        _peak: int = 0;

    has peak: int {
        getter {
            return self._peak;
        }
    }

    def raise_level(amount: int) {
        self.level = self.level + amount;
    }
}

walker Visit {
    can start with Root entry {
        visit [-->];
    }
}

node Spot {
    has height: int = 3;

    can rise with Visit entry {
        print(self.height);
    }
}

obj Setting {
    has `init: bool = True,
        `postinit: bool = False;

    def init(flag: bool) {
        self.`init = flag;
    }

    def postinit {
        self.`postinit = True;
    }
}

obj Crate;

impl Crate {
    has size: int = 1;

    def area -> int {
        return self.size * self.size;
    }
}
