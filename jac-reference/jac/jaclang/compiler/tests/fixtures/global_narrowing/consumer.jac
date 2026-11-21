"""Unrelated consumer sharing the batch program with the singleton module."""

import from .service { load_counts, Response }

def total -> int {
    counts = load_counts();
    resp = Response(text="{}");
    return len(counts) + len(resp.json());
}
