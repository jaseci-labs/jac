impl es_children(nd: Node) -> dict[str, any] {
    return {
        f.name: getattr(nd, f.name)
        for f in fields(nd)
        if f.name not in ("type", "loc")
    };
}

impl es_node_to_dict(nd: Node) -> dict[str, any] {
    result: dict[(str, any)] = {'type': nd.type};
    for (key, value) in es_children(nd).items() {
        if value is None {
            continue;
        }
        if isinstance(value, Node) {
            result[key] = es_node_to_dict(value);
        } elif isinstance(value, list) {
            result[key] = [
                es_node_to_dict(item) if isinstance(item, Node) else item
                for item in value
            ];
        } else {
            result[key] = value;
        }
    }
    if nd.loc {
        result['loc'] = {
            'source': nd.loc.source,
            'start': {'line': nd.loc.start.line, 'column': nd.loc.start.column}
                if nd.loc.start
                else None,
            'end': {'line': nd.loc.end.line, 'column': nd.loc.end.column}
                if nd.loc.end
                else None
        };
    }
    return result;
}
