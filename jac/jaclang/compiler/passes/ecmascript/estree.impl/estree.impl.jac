"""Convert an ESTree node to a dictionary representation."""

impl es_node_to_dict(<>node: Node) -> dict[str, Any] {
    result: dict[(str, Any)] = {'type': <>node.type};
    for (key, value) in <>node.__dict__.items() {
        if ((key in ('type', 'loc')) or (value is None)) {
            continue;
        }
        if isinstance(value, Node) {
            result[key] = es_node_to_dict(value);
        } elif isinstance(value, <>list) {
            result[key] = [
                es_node_to_dict(item) if isinstance(item, Node) else item
                for item in value
            ];
        } else {
            result[key] = value;
        }
    }
    if <>node.loc {
        result['loc'] = {
            'source': <>node.loc.source,
            'start': {'line': <>node.loc.start.line, 'column': <>node.loc.start.column}
            if <>node.loc.start
            else None,
            'end': {'line': <>node.loc.end.line, 'column': <>node.loc.end.column}
            if <>node.loc.end
            else None
        };
    }
    return result;
}
