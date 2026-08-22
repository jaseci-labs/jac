"""Fixture: a constructor that only fails while lowering still refuses callers.

`Sink` declares no fields, so its `init` writes a slot that is not in the
class layout. No capability check can see that ahead of time -- it surfaces
only once the constructor's body reaches the emitter. `Early.make`
constructs `Sink` and is declared first, so the construction site would
bind the initializer before it demoted unless every constructor is lowered
ahead of every other body.
"""

obj Early {
    def make -> int {
        s = Sink(4);
        return 1;
    }

    def pure(x: int) -> int {
        return x + 5;
    }
}

class Sink {
    def init(self: Sink, v: int) {
        self.v = v;
    }
}

with entry {
    print(Early().pure(2));
}
