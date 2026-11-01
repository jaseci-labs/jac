"""A base class that stays Python-side.

The `async` method is what keeps this module out of any native closure: an
async ability is a statically-known native-incompatible construct, so a
native unit inheriting `PyBase` must reach its members through the
Python-object interop bridge rather than a native layout.

The `ABC` base is kept because it is what the class means, not because it
blocks placement -- it no longer does, since `ABC` is compile-time
information the native lane erases. Stating the intent with a construct the
native lane refuses by definition keeps this fixture measuring the interop
bridge rather than whichever import happens to be unsupported that week.
"""
import from abc { ABC }

obj PyBase(ABC) {
    has label: str = "none",
        count: int = 0,
        trace: str = "";

    def postinit {
        self.trace = self.trace + "|base";
        self.count = self.count + 10;
    }

    def bump(n: int) -> int {
        self.count += n;
        return self.count;
    }

    async def note_origin {
        self.trace = self.trace + "|py";
    }
}
