impl merged_span(sizes: list[int]) -> int {
    def slot(unit: int) -> int {
        return Chunk(align=unit, size=unit).align;
    }

    total = 0;
    for s in sizes {
        if s > 0 {
            align = max(s, 4);
            total = total + slot(align) + align;
        }
    }
    return total;
}
