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
