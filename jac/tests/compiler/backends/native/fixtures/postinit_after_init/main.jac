"""postinit runs after the generated constructor only, never after a user-defined init."""
obj WithInit {
    has x: int postinit;

    def init(v: int) {
        self.x = v;
    }

    def postinit {
        self.x = -1;
    }
}

obj InheritsInit(WithInit) {}

obj NoInit {
    has q: int postinit;

    def postinit {
        self.q = 1;
    }
}

obj AddsInit(NoInit) {
    def init {
        self.q = 3;
    }
}

def chk_postinit_after_init -> int {
    return WithInit(5).x * 1000
        + InheritsInit(1).x * 100
        + NoInit().q * 10
        + AddsInit().q;
}

with entry {
    print(chk_postinit_after_init());
}
