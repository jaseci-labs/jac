"""Reads and writes C data another module defines."""

import from data { bump, counter, enabled, pair, works }

glob READY: bool = True;

obj Probe {
    has seen: int = 0;

    def run -> bool {
        if READY and works != 0 {
            self.seen = int(works);
        }
        if not READY or works == 0 {
            return False;
        }
        works = i32(2);
        return True;
    }
}

def snapshot -> int {
    copy = works;
    return int(copy);
}

with entry {
    record = addressof(pair).view(1);
    print(counter, record[0].left, record[0].right);
    bump();
    counter = counter + 10;
    record[0].right = 40;
    print(counter, addressof(pair).view(1)[0].right);
    bump();
    print(counter);
    probe = Probe();
    print(probe.run(), probe.seen, snapshot(), enabled);
}
