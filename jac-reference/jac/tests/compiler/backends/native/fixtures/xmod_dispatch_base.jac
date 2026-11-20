obj Anchor {
    has seen: int = 0;
}

obj Driver(Anchor) {
    has tick: int = 0;

    def hook {
        self.tick += 1;
    }

    def label -> str {
        return "base";
    }

    def drive {
        self.hook();
    }
}
