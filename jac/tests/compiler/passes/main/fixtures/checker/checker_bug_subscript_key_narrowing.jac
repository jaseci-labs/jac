obj Segment {
    has start: int | None = None,
        end: int | None = None;
}

def segment_length(items: list[Segment]) -> int {
    if items[0].start is not None and items[0].end is not None {
        return items[0].end - items[0].start;  # both narrowed to int
    }
    return 0;
}

def first_start(items: list[Segment]) -> int {
    if items[0].start is not None {
        return items[0].start;  # narrowed to int
    }
    return -1;
}
