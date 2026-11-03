import os;

def discover_spaces(
    paths: list[str], prog: (JacProgram | None) = None
) -> dict[str, set[str]];

def module_record(
    source_path: str, program: (JacProgram | None) = None
) -> (PlacementSummary | None);

def _record_at(real: str) -> (PlacementSummary | None);
