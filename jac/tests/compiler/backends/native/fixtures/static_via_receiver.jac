class Registry {
    has base: str = "/r";

    static def key_of(path: str) -> str;
    def install(self: Registry, path: str) -> str {
        return self.key_of(path);
    }
}

impl Registry.key_of(path: str) -> str {
    return path + "#" + str(len(path));
}

obj Counter {
    has start: int = 5;

    static def double(value: int) -> int {
        return value * 2;
    }

    def bump(value: int) -> int {
        return self.double(value) + self.start;
    }
}

def:pub static_through_class_receiver -> int {
    reg = Registry();
    key = reg.install("/tmp/a");
    return 1 if key == "/tmp/a#6" else 0;
}

def:pub static_through_obj_receiver -> int {
    counter = Counter();
    return counter.bump(20) + counter.double(1);
}
