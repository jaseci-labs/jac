"""The class type parameter a method uses still solves from the instantiation."""

obj Leaf {
    has num: int = 0;
}

obj Ctx[T] {
    has value: (T | None) = None;

    def sig_param(v: T) {
        self.value = v;
    }

    def collect -> list[T] {
        out: list[T] = [];
        if self.value is not None {
            out.append(self.value);
        }
        return out;
    }
}

def drive {
    c = Ctx[Leaf]();
    c.sig_param("not a leaf");
    for got in c.collect() {
        print(got.missing_member);
    }
}
