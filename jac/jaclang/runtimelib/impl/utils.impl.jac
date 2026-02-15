"""Check if all classes is subclass of target type."""

impl all_issubclass(
    classes: type | UnionType | tuple[((type | UnionType), ...)], target: type
) -> bool {
    match classes {
        case type():
            return issubclass(classes, target);

        case UnionType():
            return all(all_issubclass(cls, target) for cls in classes.__args__);

        case tuple():
            return all(all_issubclass(cls, target) for cls in classes);

        case _:
            return False;

    }
}

"""Check if object is instance of target type."""
impl is_instance(
    `obj: object, target: type | UnionType | tuple[((type | UnionType), ...)]
) -> bool {
    match target {
        case UnionType():
            return any(is_instance(`obj, trg) for trg in target.__args__);

        case tuple():
            return any(is_instance(`obj, trg) for trg in target);

        case type():
            return isinstance(`obj, target);

        case _:
            return False;

    }
}

"""Extract model parameters, include and exclude information."""
impl extract_params(
    body: uni.FuncCall
) -> tuple[
    dict[(str, uni.Expr)],
    list[tuple[(str, ast3.AST)]],
    list[tuple[(str, ast3.AST)]]
] {
    model_params = {};
    include_info = [];
    exclude_info = [];
    if body.params {
        for param in body.params {
            if (isinstance(param, uni.KWPair) and isinstance(param.key, uni.Name)) {
                key = param.key.value;
                value = param.value;
                if (key not in ['incl_info', 'excl_info']) {
                    model_params[key] = value;
                } elif (key == 'incl_info') {
                    if isinstance(value, uni.AtomUnit) {
                        var_name = value.value.right.value
                        if (
                            isinstance(value.value, uni.AtomTrailer)
                            and isinstance(value.value.right, uni.Name)
                        )
                        else value.value.value
                        if isinstance(value.value, uni.Name)
                        else '';
                        include_info.append((var_name, value.gen.py_ast[0]));
                    } elif (isinstance(value, uni.TupleVal) and value.values) {
                        for i in value.values {
                            var_name = i.right.value
                            if (
                                isinstance(i, uni.AtomTrailer)
                                and isinstance(i.right, uni.Name)
                            )
                            else i.value if isinstance(i, uni.Name) else '';
                            include_info.append((var_name, i.gen.py_ast[0]));
                        }
                    }
                } elif (key == 'excl_info') {
                    if isinstance(value, uni.AtomUnit) {
                        var_name = value.value.right.value
                        if (
                            isinstance(value.value, uni.AtomTrailer)
                            and isinstance(value.value.right, uni.Name)
                        )
                        else value.value.value
                        if isinstance(value.value, uni.Name)
                        else '';
                        exclude_info.append((var_name, value.gen.py_ast[0]));
                    } elif (isinstance(value, uni.TupleVal) and value.values) {
                        for i in value.values {
                            var_name = i.right.value
                            if (
                                isinstance(i, uni.AtomTrailer)
                                and isinstance(i.right, uni.Name)
                            )
                            else i.value if isinstance(i, uni.Name) else '';
                            exclude_info.append((var_name, i.gen.py_ast[0]));
                        }
                    }
                }
            }
        }
    }
    return (model_params, include_info, exclude_info);
}

"""Collect type information in assignment using bfs."""
impl extract_type(nd: uni.UniNode) -> list[str] {
    extracted_type = [];
    if isinstance(nd, (uni.BuiltinType, uni.Token)) {
        extracted_type.append(nd.value);
    }
    for child in nd.kid {
        extracted_type.extend(extract_type(child));
    }
    return extracted_type;
}

"""Traverse the graph using Breadth-First Search (BFS) or Depth-First Search (DFS)."""
impl traverse_graph(
    nd: NodeArchetype,
    cur_depth: int,
    depth: int,
    edge_type: list[str],
    traverse: bool,
    connections: list,
    node_depths: dict[(NodeArchetype, int)],
    visited_nodes: list,
    queue: list,
    bfs: bool,
    dfs: Callable,
    node_limit: int,
    edge_limit: int
) -> None {
    for `edge in nd.__jac__.edges {
        is_self_loop = id(`edge.source) == id(`edge.target);
        is_in_edge = `edge.target == nd.__jac__;
        if (
            (traverse and is_in_edge)
            or (`edge.archetype.__class__.__name__ in edge_type)
        ) {
            continue;
        }
        if is_self_loop {
            continue;
        } elif (
            (other_nda := (`edge.target if not is_in_edge else `edge.source))
            and (other_nd := other_nda.archetype)
        ) {
            new_con = (nd, other_nd, `edge.archetype)
            if not is_in_edge
            else (other_nd, nd, `edge.archetype);
            if ((nd in node_depths) and (node_depths[nd] is not None)) {
                if (other_nd in node_depths) {
                    node_depths[nd] = min(
                        cur_depth, node_depths[nd], (node_depths[other_nd] + 1)
                    );
                    node_depths[other_nd] = min(
                        (cur_depth + 1), (node_depths[nd] + 1), node_depths[other_nd]
                    );
                } elif other_nd {
                    node_depths[other_nd] = min((cur_depth + 1), (node_depths[nd] + 1));
                } else {
                    raise ValueError('Edge is detached from node in graph') ;
                }
            }
            if (
                other_nd
                and (new_con not in connections)
                and (
                    (
                        (depth < 0)
                        or ((min(node_depths[nd], node_depths[other_nd]) + 1) <= depth)
                    )
                    and (node_limit > len(visited_nodes))
                    and (edge_limit > len(connections))
                )
            ) {
                connections.append(new_con);
                if bfs {
                    queue.append([other_nd, (cur_depth + 1)]);
                } else {
                    dfs(other_nd, (cur_depth + 1));
                }
            }
        }
    }
}

"""Nodes and edges representing the graph are collected in visited_nodes and connections."""
impl collect_node_connections(
    current_node: NodeArchetype, visited_nodes: set, connections: set, edge_ids: set
) -> None {
    if (current_node not in visited_nodes) {
        visited_nodes.add(current_node);
        edges = current_node.__jac__.edges;
        for edge_ in edges {
            if (edge_.id in edge_ids) {
                continue;
            }
            edge_ids.add(edge_.id);
            target = edge_.target;
            if target {
                connections.add(
                    (
                        edge_.id,
                        edge_.source.archetype,
                        target.archetype,
                        edge_.archetype
                    )
                );
                collect_node_connections(
                    target.archetype, visited_nodes, connections, edge_ids
                );
            }
        }
    }
}

"""Add a path to sys.path temporarily."""
impl sys_path_context(path: str) -> Iterator[None] {
    novel_path = path not in sys.path;
    try {
        if novel_path {
            sys.path.append(path);
        }
        yield ;
        ;
    } finally {
        if novel_path {
            sys.path.remove(path);
        }
    }
}
