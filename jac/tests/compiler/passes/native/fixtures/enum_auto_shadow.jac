"""Fixture: a module-local `auto` is not `enum`'s, and must not be read as it.

The generated-value rule is keyed on the symbol behind the name rather than
its spelling, so this module's own `auto` -- which answers 40, not a counted
ordinal -- has to leave `Tone`'s members unfolded. Reading one off the class
then refuses under E5092 the way any un-foldable member value does, which is
the honest answer: a value the emitter cannot know is not a value it may
guess at.
"""

import from enum { IntEnum }


def auto -> int {
    return 40;
}


class Tone(IntEnum) {
    with entry {
        Soft = auto();
        Loud = auto();
    }
}


def loudness -> int {
    return int(Tone.Soft);
}


with entry {
    print(loudness());
}
