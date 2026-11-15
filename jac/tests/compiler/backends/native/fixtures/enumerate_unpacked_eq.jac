"""`==` on a name unpacked from `enumerate`.

A name bound by tuple unpacking sits in an erased pointer slot. Comparing it
with an object whose class defines `__eq__` used to compare addresses, so an
equal object read as different. The expression's own type now names the class
and the class's `__eq__` is asked."""
obj T {
    def __eq__(other: object) -> bool {
        return isinstance(other, T) and str(self) == str(other);
    }

    def __str__ -> str {
        return "T";
    }
}

obj IntT(T) {
    has width: int = 64;

    def __eq__(other: object) -> bool {
        return isinstance(other, IntT) and other.width == self.width;
    }

    def __str__ -> str {
        return f"i{self.width}";
    }
}

obj PtrT(T) {
    has pointee: T;

    def __eq__(other: object) -> bool {
        return isinstance(other, PtrT) and other.pointee == self.pointee;
    }

    def __str__ -> str {
        return f"{self.pointee}*";
    }
}

def chain(items: list[T]) -> str {
    i8p = PtrT(pointee=IntT(width=8));
    out = "";
    for ety in items {
        if isinstance(ety, IntT) {
            out += "int ";
        } elif ety == i8p {
            out += "str ";
        } elif isinstance(ety, PtrT) {
            out += "ptr ";
        } else {
            out += "? ";
        }
    }
    return out;
}

def plain(items: list[T]) -> str {
    i8p = PtrT(pointee=IntT(width=8));
    out = "";
    for (i, ety) in enumerate(items) {
        if ety == i8p {
            out += "str ";
        } else {
            out += "other ";
        }
    }
    return out;
}

with entry {
    items: list[T] = [
        PtrT(pointee=IntT(width=8)),
        IntT(width=64),
        PtrT(pointee=IntT(width=64))
    ];
    print(chain(items));
    print(plain(items));
}
