"""Shared pure helper under no app root: compiled into whichever side imports it."""

def stamp(text: str) -> str {
    return "[" + text + "]";
}
