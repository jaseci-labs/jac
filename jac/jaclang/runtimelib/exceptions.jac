"""Typed runtime exceptions raised by the persistence layer."""

import from uuid { UUID }


"""Raised when an optimistic-concurrency check fails: an anchor changed in
the backend between the time this request read it and the time it tried to
commit. The runtime converges on this by aborting the request's unit of
work and replaying the walker (which re-reads the now-current graph), so a
check-then-create that lost the race re-runs and takes the find branch."""
obj WriteConflict(Exception) {
    has anchor_id: UUID,
        # version this request expected vs. what the backend held.
        expected_version: int = -1,
        actual_version: int = -1,
        # Other conflicts from the same unit of work (set by commit()).
        siblings: (list | None) = None;

    def postinit {
        super.init(self.message());
    }

    """Human-readable summary of the conflict."""
    def message -> str {
        return (
            f"WriteConflict: anchor {self.anchor_id} changed concurrently "
            f"(expected v{self.expected_version}, found v{self.actual_version})"
        );
    }
}
