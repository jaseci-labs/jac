"""Fixture for the export-trie prefix-masking regression test.

Two :pub functions where one name is a strict prefix of the other
(jrender / jrender_buf).  Without descending-length sorting in the flat
export trie, dyld commits to the jrender edge when looking up jrender_buf
and finds no children for the remaining _buf suffix -> "symbol not found".
"""

def:pub jrender() -> int {
    return 1;
}

def:pub jrender_buf() -> int {
    return 2;
}

with entry {}
