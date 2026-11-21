import from typing { Final }

obj Once {
    has x: Final[int],
        tag: Final[str] postinit;

    def init(v: int) {
        self.x = v;
    }

    def postinit {
        self.tag = "t";
    }
}

obj Branches {
    has x: Final[int];

    def init(flag: bool) {
        if flag {
            self.x = 1;
        } else {
            self.x = 2;
        }
    }
}

obj Deferred {
    has x: Final[int],
        tag: Final[str] postinit;

    def postinit {
        self.tag = "t";
    }
}

obj Twice {
    has x: Final[int];

    def init(v: int) {
        self.x = v;
        self.x = v + 1;  # <-- Error
    }
}

obj InitThenPost {
    has x: Final[int];

    def init(v: int) {
        self.x = v;
    }

    def postinit {
        self.x = 99;  # <-- Error
    }
}

obj InLoop {
    has x: Final[int];

    def init(vs: list[int]) {
        for v in vs {
            self.x = v;  # <-- Error
        }
    }
}

obj PassedThenPost {
    has x: Final[int];

    def postinit {
        self.x = 99;  # <-- Error
    }
}

obj ParseOrDefault {
    has x: Final[int];

    def init(s: str) {
        try {
            self.x = int(s);
        } except ValueError {
            self.x = 0;
        }
    }
}

obj TryTwice {
    has x: Final[int];

    def init {
        try {
            self.x = 1;
            raise ValueError("retry");
        } except ValueError {
            self.x = 2;  # <-- Error
        }
    }
}

obj FailedPath {
    has x: Final[int];

    def init(flag: bool) {
        if flag {
            self.x = 1;
            raise ValueError("abort");
        }
        self.postinit();
    }

    def postinit {
        self.x = 2;
    }
}

obj NestedThenFinally {
    has x: Final[int];

    def init(flag: bool) {
        try {
            if flag {
                self.x = 1;
            }
        } finally {
            self.x = 2;  # <-- Error
        }
    }
}

obj ParseOrReturn {
    has x: Final[int];

    def init(s: str) {
        try {
            self.x = int(s);
            return;
        } except ValueError {
            self.x = 0;
        }
    }
}
