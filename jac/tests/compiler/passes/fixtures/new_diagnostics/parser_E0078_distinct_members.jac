"""Fields, methods and abilities with distinct names, and a field whose
property accessors share its name, are not clashes."""

obj Meter {
    has level: int = 0,
        _peak: int = 0;

    has peak: int {
        getter {
            return self._peak;
        }
    }

    def raise_level(by: int) -> None {
        self.level = self.level + by;
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
