"""Fixture: an enum whose name a consumer reuses for one of its own functions."""

enum Tone { SOFT = 1, LOUD = 2 }


def boost(x: int) -> int {
    return int(Tone(x)) + 10;
}
