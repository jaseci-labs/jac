import from uuid { UUID }


obj MissingAnchorError(ValueError) {
    has anchor_id: str;

    def __str__ -> str {
        return (
            f"Anchor {self.anchor_id} does not exist in the anchor store "
            "(was the data store reset or migrated?)"
        );
    }
}


obj WriteConflict(Exception) {
    has anchor_id: UUID,
        expected_version: int = -1,
        actual_version: int = -1,
        siblings: (list | None) = None;

    def postinit {
        super.init(self.message());
    }

    def message -> str {
        return (
            f"WriteConflict: anchor {self.anchor_id} changed concurrently "
            f"(expected v{self.expected_version}, found v{self.actual_version})"
        );
    }
}
