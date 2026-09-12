import type from jaclang.compiler.analysis.placement.worklist { PlacementWork }

obj PlacementState {
    has work: PlacementWork | None = None,
        evidence: dict[str, list[str]] = {};

    def clear {
        self.work = None;
        self.evidence.clear();
    }
}
