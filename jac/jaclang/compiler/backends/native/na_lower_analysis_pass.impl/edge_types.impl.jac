impl NativeLowering._osp_edge_class_name(expr: uni.UniNode) -> (str | None) {
    return self._class_expr_bound(expr, unbounded="Edge");
}
