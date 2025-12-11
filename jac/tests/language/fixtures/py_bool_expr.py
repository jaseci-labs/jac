# flake8: noqa
from __future__ import annotations


def bool_expr(
    prev_token_index, next_token_index, tok, change_end_line, change_end_char
):
    if (not (prev_token_index is None or next_token_index is None)) and (
        tok[0] > change_end_line
        or (tok[0] == change_end_line and tok[1] > change_end_char)
    ):
        return True
    return False
