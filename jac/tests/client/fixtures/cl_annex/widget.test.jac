"""Annex for `widget`; `label` is in scope only once merged into it."""

test "label counts the items" {
    assert label([1, 2, 3]) == "3 items";
}
