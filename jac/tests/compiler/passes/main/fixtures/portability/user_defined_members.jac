"""User-declared members sharing JS-idiom names must not draw W6002/W6004."""

obj Config {
    has raw: str = "",
        length: int = 0;

    def parse(src: str) -> str {
        return src;
    }

    def assign(k: str) {
        self.raw = k;
    }

    def push(v: str) {
        self.raw = v;
        self.assign(v);
    }
}

def use_config -> int {
    cfg = Config();
    cfg.parse("x=1");
    cfg.assign("k");
    cfg.push("v");
    return cfg.length;
}

def genuine_slop -> int {
    items: list = [1];
    items.push(2);
    return items.length;
}
