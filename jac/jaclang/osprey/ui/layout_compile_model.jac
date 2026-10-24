def _wants(phase: str, horizontal: bool) -> bool;


obj NodeEdges {
    has id_str: str,
        key: str,
        left: Variable,
        top: Variable,
        right: Variable,
        bottom: Variable;
}


obj CompileResult {
    has ok: bool = True,
        solver: Solver | None = None,
        nodes: dict[str, NodeEdges] = {},
        diagnostics: list[LayoutDiagnostic] = [],
        partitions: list[PartitionInfo] = [];
}


obj PartitionInfo {
    has parent_id: str,
        horizontal: bool,
        span: float,
        child_ids: list[str] = [],
        targets: list[float] = [],
        fixed: list[bool] = [],
        minimums: list[float] = [],
        maximums: list[float] = [];
}


obj _ScopedNode {
    has target: UiNode,
        id_str: str = "",
        key: str = "",
        parent_id: str = "",
        rank: int = 0,
        is_overlay: bool = False,
        z_index: int = 0;
}


obj _Scope {
    has order: list[_ScopedNode] = [],
        parent_of: dict[str, str] = {},
        error: LayoutDiagnostic | None = None;
}


obj _Entry {
    has scoped: _ScopedNode,
        edges: NodeEdges,
        spec: LayoutSpec;
}


obj _FlowChild {
    has ent: _Entry,
        size: AxisSize,
        natural: float | None = None;
}


obj _Allocation {
    has targets: list[float] = [],
        overflow: bool = False,
        hard_overflow: bool = False;
}

impl _wants(phase: str, horizontal: bool) -> bool {
    if phase == "h" {
        return horizontal;
    }
    if phase == "v" {
        return not horizontal;
    }
    return True;
}
