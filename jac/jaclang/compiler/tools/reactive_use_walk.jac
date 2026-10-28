walker ReactiveUseWalker {
    has reactive: set[str],
        writes: list[tuple[int, int, str]] = [],
        reads: list[tuple[int, int, str, uni.Name]] = [];

    can walk_children with uni.UniNode entry;
    can collect_assignment with uni.Assignment entry;
    can collect_name with uni.Name entry;
}
