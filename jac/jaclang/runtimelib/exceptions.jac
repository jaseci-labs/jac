import from uuid { UUID }


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
