def _emit_overlay(
    result: CompileResult,
    owner: _Entry,
    root_edges: NodeEdges,
    natural_sizes: dict[str, Size],
    phase: str,
) -> bool;

impl _emit_overlay(
    result: CompileResult,
    owner: _Entry,
    root_edges: NodeEdges,
    natural_sizes: dict[str, Size],
    phase: str,
) -> bool {
    edges = owner.edges;
    spec = owner.spec;
    id_str = edges.id_str;

    natural_w: float | None = None;
    natural_h: float | None = None;
    if id_str in natural_sizes {
        natural_w = float(natural_sizes[id_str].width);
        natural_h = float(natural_sizes[id_str].height);
    }

    if (
        spec.width.mode == SizeMode.FIXED
        or spec.width.mode == SizeMode.INTRINSIC
        or spec.width.mode == SizeMode.BOUNDED
    )
        and _wants(phase, True) {
        if not _emit_sized_axis(
            result,
            spec.width,
            edges.left,
            edges.right,
            True,
            id_str,
            natural_w,
            "overlay",
        ) {
            return False;
        }
    }
    if (
        spec.height.mode == SizeMode.FIXED
        or spec.height.mode == SizeMode.INTRINSIC
        or spec.height.mode == SizeMode.BOUNDED
    )
        and _wants(phase, False) {
        if not _emit_sized_axis(
            result,
            spec.height,
            edges.top,
            edges.bottom,
            False,
            id_str,
            natural_h,
            "overlay",
        ) {
            return False;
        }
    }

    anchor = spec.overlay_anchor;
    centered_h = (
        anchor is None
        or anchor == OverlayAnchor.CENTER
        or anchor == OverlayAnchor.TOP
        or anchor == OverlayAnchor.BOTTOM
    );
    centered_v = (
        anchor is None
        or anchor == OverlayAnchor.CENTER
        or anchor == OverlayAnchor.LEFT
        or anchor == OverlayAnchor.RIGHT
    );
    if centered_h and _wants(phase, True) {
        if not _emit(
            result,
            _expr(
                [
                    _t(edges.left),
                    _t(edges.right),
                    _t(root_edges.left, -1.0),
                    _t(root_edges.right, -1.0),

                ]
            ),
            Relation.EQ,
            StrengthTier.STRONG,
            _prov("overlay", id_str, "h"),
        ) {
            return False;
        }
    }
    if centered_v and _wants(phase, False) {
        if not _emit(
            result,
            _expr(
                [
                    _t(edges.top),
                    _t(edges.bottom),
                    _t(root_edges.top, -1.0),
                    _t(root_edges.bottom, -1.0),

                ]
            ),
            Relation.EQ,
            StrengthTier.STRONG,
            _prov("overlay", id_str, "v"),
        ) {
            return False;
        }
    }
    if (anchor == OverlayAnchor.TOP or anchor == OverlayAnchor.BOTTOM)
        and _wants(phase, False) {
        edge_var = edges.top if anchor == OverlayAnchor.TOP else edges.bottom;
        root_var = root_edges.top if anchor == OverlayAnchor.TOP else root_edges.bottom;
        if not _emit(
            result,
            _expr([_t(edge_var), _t(root_var, -1.0)]),
            Relation.EQ,
            StrengthTier.STRONG,
            _prov("overlay", id_str, "v"),
        ) {
            return False;
        }
    }
    if (anchor == OverlayAnchor.LEFT or anchor == OverlayAnchor.RIGHT)
        and _wants(phase, True) {
        edge_var = edges.left if anchor == OverlayAnchor.LEFT else edges.right;
        root_var = root_edges.left
            if anchor == OverlayAnchor.LEFT
            else root_edges.right;
        if not _emit(
            result,
            _expr([_t(edge_var), _t(root_var, -1.0)]),
            Relation.EQ,
            StrengthTier.STRONG,
            _prov("overlay", id_str, "h"),
        ) {
            return False;
        }
    }
    return True;
}
