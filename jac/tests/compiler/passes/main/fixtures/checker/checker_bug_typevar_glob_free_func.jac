import from typing { TypeVar }

obj Base {
    has tag: str = "base";
}

obj Derived(Base) {
    has derived_attr: str = "extra";
}

glob T = TypeVar('T', bound=Base);

def identity(x: T) -> T {
    return x;
}

glob d = Derived();

with entry {
    print(identity(d).derived_attr);
}
