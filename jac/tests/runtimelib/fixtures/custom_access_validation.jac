node A {
    has val1: str = "NO_ACCESS",
        val2: int = 0;

    # suggested to be `with access {}`
    def __jac_access__ -> any {
        ###############################################
        #              YOUR PROCESS HERE              #
        ###############################################

        # Preferred: the ambient AccessLevel enum (no import needed)
        # return AccessLevel.NO_ACCESS;  # or .READ / .CONNECT / .WRITE

        # Strings "NO_ACCESS" / "READ" / "CONNECT" / "WRITE" are accepted -
        # mainly for policies stored in data, as here. A typo'd literal
        # raises KeyError at access-check time, so never hand-write them.
        return self.val1;

        # Not recommended as it may change in the future
        # Allowed int return -1 (NO_ACCESS), 0 (READ), 1 (CONNECT), 2 (WRITE)
        # return -1;
    }
}

walker create_other_root {
    can enter with Root entry {
        other_root = Root().__jac__;
        save(other_root);
        print(other_root.id);
    }
}

walker create {
    can enter with Root entry {
        a = root ++> A();
        print(a.__jac__.id);
    }
}

walker update {
    has val1: str | None = None,
        val2: int | None = None;

    can enter with A entry {
        if self.val1 is not None {
            here.val1 = self.val1;
        }

        if self.val2 is not None {
            here.val2 = self.val2;
        }
    }
}

walker check {
    can enter with A entry {
        print(here);
    }
}
