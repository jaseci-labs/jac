import from jaclang.runtimelib.archetype {AccessLevel}

node A {
    has val1: str = "NO_ACCESS";
    has val2: int = 0;

    # suggested to be `with access {}`
    def __jac_access__ {

        ###############################################
        #              YOUR PROCESS HERE              #
        ###############################################

        # Allowed string return "NO_ACCESS", "READ", "CONNECT", "WRITE"
        return self.val1;

        # Allowed enum return AccessLevel.NO_ACCESS, AccessLevel.READ, AccessLevel.CONNECT, AccessLevel.WRITE
        # return AccessLevel.NO_ACCESS;

        # Not recommended as it may change in the future
        # Allowed int return -1 (NO_ACCESS), 0 (READ), 1 (CONNECT), 2 (WRITE)
        # return -1;

    }
}

walker create_other_root {
    can enter with `root entry {
        other_root = `root().__jac__;
        _.save(other_root);
        print(other_root.id);
    }
}

walker create {
    can enter with `root entry {
        a = root ++> A();
        print(a[0].__jac__.id);
    }
}


walker update {
    has val1: str | None = None;
    has val2: int | None = None;

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
