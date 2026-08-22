"""Fixture: a keyword-argument key spelled like a local, in an annex body.

`elf_linker._merge_crt_object`'s shape reduced to one function: a local
`align`, an `align=` keyword argument beside it, and `align` as a field name
on the operand the keyword names.
"""

obj Chunk {
    has align: int = 1,
        size: int = 0;
}


def merged_span(sizes: list[int]) -> int;


def run -> int {
    return merged_span([3, 5, 8]);
}


with entry {
    print(run());
}
