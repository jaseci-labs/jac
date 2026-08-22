"""Native unit whose class inherits a Python-side base (epic #8201).

`Kid` exercises the three Python-base boundary seams: `super.postinit()`
chaining into the base's Python `__post_init__`, a store to an inherited
field (`self.count = 99`), and a call to an inherited Python-resident
method (`self.bump(1)`).
"""
import from pyb_base_lib { PyBase }

glob KEEPER: list[Kid] = [];

obj Kid(PyBase) {
    has extra: int = 1;

    def postinit {
        super.postinit();
        self.extra = self.count + 1;
    }

    def poke -> int {
        self.count = 99;
        return self.bump(1);
    }

    def read_back -> int {
        return self.count;
    }
}

def run_all -> int {
    k = Kid(label="kid");
    a = k.poke();
    b = k.read_back();
    return a * 100000 + b * 10 + k.extra;
}

def keep_and_poke -> int {
    k = Kid(label="kid");
    KEEPER.append(k);
    return k.poke();
}

with entry {
    print(run_all());
}
