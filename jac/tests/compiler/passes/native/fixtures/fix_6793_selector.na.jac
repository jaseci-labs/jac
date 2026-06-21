"""Leaf module for issue #6793 regression test — defines SelectItem.

Reached only transitively: entry -> core -> handler -> panel -> selector.
On a JIR-cached incremental build (before the fix) the dep-sweep re-inference
visited `panel` before `selector` was registered in the hub, leaving
`SelectItem` as <Unknown> in panel's `list[SelectItem]` annotation (E5090).
Mirrors the TUI's select_list module.
"""

obj:pub SelectItem {
    has label: int;
}

def:pub make_item(v: int) -> SelectItem {
    return SelectItem(label=v);
}

def:pub item_label(item: SelectItem) -> int {
    return item.label;
}
