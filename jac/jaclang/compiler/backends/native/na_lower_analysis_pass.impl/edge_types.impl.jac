impl NativeLowering._osp_edge_class_name(expr: uni.UniNode) -> (str | None) {
    return self._class_expr_bound(expr, unbounded="Edge");
}

impl NativeLowering._osp_edge_descriptor_is_class(
    expr: uni.UniNode, nd: uni.UniNode
) -> bool {
    if self._osp_edge_class_name(expr) is None {
        self.emit(
            E5092, node_override=nd, kind="edge type", name="non-class expression"
        );
        return False;
    }
    return True;
}
