"""Non-generic control: same construction, same wrong answer."""
import from pyb_hollow_plain_lib { PlainBase }

obj PlainKid(PlainBase) {
    has seen: int = 5;

    def hook(n: int) -> int {
        self.seen = n + 100;
        return n;
    }
}

def read_back -> int {
    k = PlainKid(seed=3);
    return k.seen;
}

with entry {
    print(read_back());
}
