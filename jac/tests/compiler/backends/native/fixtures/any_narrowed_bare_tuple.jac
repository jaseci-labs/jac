"""An `any` narrowed by `isinstance(x, tuple)` is a tuple of unknown arity."""

def first_of(address: any) -> str {
    addr: any = address;
    extra: any = 32;
    if isinstance(address, tuple) {
        nt: int = len(address);
        if nt == 0 {
            raise IndexError("tuple index out of range");
        }
        addr = address[0];
        if nt > 1 {
            extra = address[1];
        }
    }
    return str(addr) + "/" + str(extra);
}

with entry {
    print(first_of(("10.0.0.1", 24)));
    print(first_of(("10.0.0.2", )));
    print(first_of("10.0.0.3"));
    try {
        first_of(());
    } except IndexError as e {
        print("IndexError", e);
    }
}
