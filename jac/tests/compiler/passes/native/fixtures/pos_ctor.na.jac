obj Widget {
    has size: int;

    def area -> int {
        return self.size * self.size;
    }
}

obj Vec {
    has x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0;
}

obj Label {
    has name: str = "anon",
        count: int = 0;
}

def direct_area(n: int) -> int {
    w = Widget(n);
    return w.area();
}

def vec_mix(a: float, c: float) -> float {
    v = Vec(a, z=c);
    return v.x * 100.0 + v.y * 10.0 + v.z;
}

def label_count(n: int) -> int {
    tag = Label("tag", n);
    return tag.count + len(tag.name);
}

with entry {
    print(direct_area(5));
}
