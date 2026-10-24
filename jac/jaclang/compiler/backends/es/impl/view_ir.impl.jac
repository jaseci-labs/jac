impl view_attr_node(
    attr: (StaticAttr | DynamicAttr | EventAttr | RefAttr | SpreadAttr)
) -> (uni.UniNode | None) {
    if isinstance(attr, StaticAttr) {
        return attr.jac_node;
    }
    if isinstance(attr, DynamicAttr) {
        return attr.jac_node;
    }
    if isinstance(attr, EventAttr) {
        return attr.jac_node;
    }
    if isinstance(attr, RefAttr) {
        return attr.jac_node;
    }
    return attr.jac_node;
}

impl ViewLocator.at(
    es_node: _Located, jac_node: (uni.UniNode | None) = None
) -> _Located {
    source = jac_node if jac_node is not None else self.anchor;
    if not self.locate or source is None or source.loc is None {
        return es_node;
    }
    es_node.loc = es.SourceLocation(
        start=es.Position(line=source.loc.first_line, column=source.loc.col_start),
        end=es.Position(line=source.loc.last_line, column=source.loc.col_end)
    );
    return es_node;
}
