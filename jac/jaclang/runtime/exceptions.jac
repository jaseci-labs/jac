import from uuid { UUID }


obj MissingAnchorError(ValueError) {
    has anchor_id: str;

    def init(anchor_id: str);
    def __str__ -> str;
}


obj WriteConflict(Exception) {
    has anchor_id: UUID,
        expected_version: int = -1,
        actual_version: int = -1,
        siblings: (list[any] | None) = None;

    def init(
        anchor_id: UUID,
        expected_version: int = -1,
        actual_version: int = -1,
        siblings: (list[any] | None) = None
    );

    def message -> str;
}


obj ReadOnlyRetry(WriteConflict) {
    has unit_key: str = '';

    def init(
        anchor_id: UUID,
        expected_version: int = -1,
        actual_version: int = -1,
        siblings: (list[any] | None) = None,
        unit_key: str = ''
    );

    def message -> str;
}


obj TransactionLost(WriteConflict) {
    def message -> str;
}
