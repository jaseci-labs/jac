"""Fixture: an unencodable enum refuses where it is read, not where it is declared.

A native enum is its table of compile-time member values. `Ratio` holds
floats, which that table cannot carry; the emitter used to store each such
member as `0`, so every member compared equal to every other. Reading it now
refuses under E5092. `enum_unencodable_lib` declares `Unread`, just as
unencodable, but nothing reads it -- so neither lowering the library nor
walking its import may report it.
"""

import from enum_unencodable_lib { scaled }

enum Ratio { Half = 0.5, Whole = 1.0 }


with entry {
    print(Ratio.Half == Ratio.Whole);
    print(scaled(14));
}
