"""The dict-validating configuration class for the cross-module invariant
fixture: it lives one import away from the call site that needs its proof,
so resolving it requires materializing this module's AST on demand."""

class RopeConfig {
    def __init__(self: RopeConfig, rope_scaling: (dict | None) = None) -> None {
        self.rope_scaling = rope_scaling;
        if self.rope_scaling is None {
            return;
        }
        if not isinstance(self.rope_scaling, dict) or (len(self.rope_scaling) != 3) {
            raise ValueError("rope_scaling must be a dict of len 3");
        }
    }
}
