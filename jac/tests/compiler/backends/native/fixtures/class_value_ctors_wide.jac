obj Base {
    has label: str,
        scale: int = 2;

    def describe -> str {
        return self.label;
    }
}

obj Wide(Base) {
    has f0: int = 0,
        f1: int = 1,
        f2: int = 2,
        f3: int = 3,
        f4: int = 4,
        f5: int = 5,
        f6: int = 6,
        f7: int = 7,
        f8: int = 8,
        f9: int = 9,
        f10: int = 10,
        f11: int = 11,
        f12: int = 12,
        f13: int = 13,
        f14: int = 14,
        f15: int = 15,
        f16: int = 16,
        f17: int = 17,
        f18: int = 18,
        f19: int = 19,
        f20: int = 20,
        f21: int = 21,
        f22: int = 22,
        f23: int = 23,
        f24: int = 24,
        f25: int = 25,
        f26: int = 26,
        f27: int = 27,
        f28: int = 28,
        f29: int = 29,
        f30: int = 30,
        f31: int = 31,
        f32: int = 32,
        f33: int = 33,
        f34: int = 34,
        f35: int = 35,
        f36: int = 36,
        f37: int = 37,
        f38: int = 38,
        f39: int = 39,
        f40: int = 40,
        f41: int = 41,
        f42: int = 42,
        f43: int = 43,
        f44: int = 44,
        f45: int = 45,
        f46: int = 46,
        f47: int = 47,
        f48: int = 48,
        f49: int = 49,
        f50: int = 50,
        f51: int = 51,
        f52: int = 52,
        f53: int = 53,
        f54: int = 54,
        f55: int = 55,
        f56: int = 56,
        f57: int = 57,
        f58: int = 58,
        f59: int = 59,
        f60: int = 60,
        f61: int = 61,
        f62: int = 62,
        f63: int = 63,
        f64: int = 64,
        f65: int = 65,
        f66: int = 66,
        f67: int = 67,
        f68: int = 68,
        f69: int = 69,
        tail: int = 7;

    def describe -> str {
        return self.label + ":" + str(self.scale * (self.f69 + self.tail));
    }
}

obj Small(Base) {
    has extra: int = 5;

    def describe -> str {
        return self.label + "/" + str(self.scale + self.extra);
    }
}

def build(kind: type[Base], label: str) -> Base {
    return kind(label=label, scale=3);
}

glob kinds: list[type[Base]] = [Wide, Small, Base];
with entry {
    for kind in kinds {
        print(build(kind, "x").describe());
    }
}
