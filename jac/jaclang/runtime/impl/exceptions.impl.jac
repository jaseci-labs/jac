impl MissingAnchorError.init(anchor_id: str) {
    self.anchor_id = anchor_id;
}

impl MissingAnchorError.__str__ -> str {
    return (
        f"Anchor {self.anchor_id} does not exist in the anchor store "
        "(was the data store reset or migrated?)"
    );
}

impl WriteConflict.init(
    anchor_id: UUID,
    expected_version: int = -1,
    actual_version: int = -1,
    siblings: (list[any] | None) = None
) {
    self.anchor_id = anchor_id;
    self.expected_version = expected_version;
    self.actual_version = actual_version;
    self.siblings = siblings;
    super.init(self.message());
}

impl ReadOnlyRetry.init(
    anchor_id: UUID,
    expected_version: int = -1,
    actual_version: int = -1,
    siblings: (list[any] | None) = None,
    unit_key: str = ''
) {
    self.unit_key = unit_key;
    super.init(anchor_id, expected_version, actual_version, siblings);
}

impl WriteConflict.message -> str {
    return (
        f"WriteConflict: anchor {self.anchor_id} changed concurrently "
        f"(expected v{self.expected_version}, found v{self.actual_version})"
    );
}

impl ReadOnlyRetry.message -> str {
    return (
        f"ReadOnlyRetry: unit {self.unit_key or '<anonymous>'} wrote inside "
        'a read-only snapshot; re-run it at SERIALIZABLE'
    );
}

impl TransactionLost.message -> str {
    return (
        'TransactionLost: the transaction was rolled back and its writes '
        'cannot be replayed; re-run the unit'
    );
}
