"""Closes the import cycle by pulling `Tok` back from the entry module."""

import from entry { Tok }

obj Info {
    has first_tok: Tok,
        last_tok: Tok;
}
