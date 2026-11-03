obj TargetLayout {
    has data_layout: str,
        triple: str;
}

glob _TARGETS: dict[str, TargetLayout] = {};

def target_layout(triple: str) -> TargetLayout;

def target_fact_text(triple: str) -> str;

def measure_struct_layouts(
    data_layout: str, probe_ir: str, counts: dict[str, int]
) -> dict[str, tuple[list[int], int]];
