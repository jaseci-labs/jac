def _ident_ok(name: str) -> bool {
    if not name {
        return False;
    }
    for ch in name {
        if not (ch.isalnum() or ch == '_') {
            return False;
        }
    }
    return not name[0].isdigit();
}


def _scalar(v: any) -> any {
    return str(v) if isinstance(v, UUID) else v;
}


def _pushable_value(v: any) -> bool {
    if isinstance(v, (str, int, float, bool, UUID)) or v is None {
        return True;
    }
    if isinstance(v, (list, tuple, set)) {
        for x in v {
            if not isinstance(x, (str, int, float, bool, UUID)) {
                return False;
            }
        }
        return True;
    }
    return False;
}


def _type_cond(alias: str, tname: str, params: dict[str, any], pfx: str) -> str {
    key = f"{pfx}t";
    params[key] = tname;
    return (
        f"({alias}.arch_type = :{key} OR {alias}.arch_type IN "
        f"(SELECT type_name FROM graph_types WHERE ancestor = :{key}))"
    );
}


def _sql_type_of(v: any) -> str {
    if isinstance(v, bool) {
        return 'boolean';
    }
    if isinstance(v, int) {
        return 'bigint';
    }
    if isinstance(v, float) {
        return 'float8';
    }
    return 'text';
}


def _sanitize_ident(name: str) -> str {
    out = '';
    for ch in name.lower() {
        out += ch if (ch.isalnum() or ch == '_') else '_';
    }
    return out;
}


def _promoted_col(
    alias: str, arch_names: list[str], field: str, promotions: (dict[str, any] | None)
) -> (str | None) {
    if not promotions {
        return None;
    }
    for arch in arch_names {
        declared = promotions.get(arch);
        if declared and field in declared {
            col = f"g_{_sanitize_ident(arch)}_{_sanitize_ident(field)}";
            return f"{alias}.{col}";
        }
    }
    return None;
}


def _field_expr(
    alias: str, field: str, arch_names: list[str], promotions: (dict[str, any] | None)
) -> str {
    col = _promoted_col(alias, arch_names, field, promotions);
    return col if col is not None else f"{alias}.props->'archetype'->'{field}'";
}


def _row_cond(
    alias: str,
    p: QPred,
    params: dict[str, any],
    pfx: str,
    arch_names: list[str],
    promotions: (dict[str, any] | None)
) -> (str | None) {
    op = {'<': '<', '<=': '<=', '>': '>', '>=': '>=', '==': '=', '!=': '<>'}.get(p.op);
    if op is None {
        return None;
    }
    names = p.field;
    vals = p.value;
    if not isinstance(names, tuple) or not isinstance(vals, tuple) {
        return None;
    }
    lhs: list[str] = [];
    rhs: list[str] = [];
    for (i, name) in enumerate(names) {
        if not _ident_ok(name) {
            return None;
        }
        key = f"{pfx}k{i}";
        params[key] = _scalar(vals[i]);
        lhs.append(_field_expr(alias, name, arch_names, promotions));
        rhs.append(f"to_jsonb(CAST(:{key} AS {_sql_type_of(vals[i])}))");
    }
    return f"({', '.join(lhs)}) {op} ({', '.join(rhs)})";
}


def _pred_cond(
    alias: str,
    p: QPred,
    params: dict[str, any],
    pfx: str,
    arch_names: (list[str] | None) = None,
    promotions: (dict[str, any] | None) = None
) -> (str | None) {
    if isinstance(p.field, tuple) {
        return _row_cond(alias, p, params, pfx, arch_names or [], promotions);
    }
    if not _ident_ok(p.field) or not _pushable_value(p.value) {
        return None;
    }
    expr = _field_expr(alias, p.field, arch_names or [], promotions);
    if p.op == 'in' {
        vals = list(p.value) if isinstance(p.value, (list, tuple, set)) else [p.value];
        parts: list[str] = [];
        for (i, v) in enumerate(vals) {
            key = f"{pfx}v{i}";
            params[key] = _scalar(v);
            parts.append(f"to_jsonb(CAST(:{key} AS {_sql_type_of(v)}))");
        }
        if not parts {
            return 'FALSE';
        }
        return f"{expr} IN ({', '.join(parts)})";
    }
    if p.value is None {
        if p.op == '==' {
            return f"{expr} = 'null'::jsonb";
        }
        if p.op == '!=' {
            return f"({expr} IS NULL OR {expr} <> 'null'::jsonb)";
        }
        return 'FALSE';
    }
    key = f"{pfx}v";
    params[key] = _scalar(p.value);
    rhs = f"to_jsonb(CAST(:{key} AS {_sql_type_of(p.value)}))";
    if p.op == '==' {
        return f"{expr} = {rhs}";
    }
    if p.op == '!=' {
        return f"({expr} IS NULL OR {expr} <> {rhs})";
    }
    op = {'<': '<', '<=': '<=', '>': '>', '>=': '>='}.get(p.op);
    if op is None {
        return None;
    }
    return f"{expr} {op} {rhs}";
}


def _acl_cond(alias: str, root_id: str, params: dict[str, any], pfx: str) -> str {
    mu = f"{pfx}mu";
    mt = f"{pfx}mt";
    params[mu] = root_id;
    params[mt] = root_id;
    return (
        f"({alias}.root_id = CAST(:{mu} AS uuid)"
        f" OR ({alias}.props->'access'->>'all')::int > -1"
        f" OR ({alias}.props->'access'->'roots'->'anchors')"
        f" ? CAST(:{mt} AS text)"
        f" OR EXISTS ("
        f"SELECT 1 FROM anchors ge"
        f" WHERE ge.kind = 'EdgeAnchor' AND ge.src = CAST(:{mu} AS uuid)"
        f" AND ({alias}.props->'access'->'groups'->'anchors')"
        f" ? CAST(ge.dst AS text)"
        f"))"
    );
}


def _dir_cond(alias: str, fid: str, dir: int) -> str {
    if dir == 1 {
        return (
            f"({alias}.dst = {fid} OR ({alias}.undirected AND {alias}.src = {fid}))"
        );
    }
    if dir == 3 {
        return f"({alias}.src = {fid} OR {alias}.dst = {fid})";
    }
    return f"({alias}.src = {fid} OR ({alias}.undirected AND {alias}.dst = {fid}))";
}


def _other_expr(alias: str, fid: str) -> str {
    return f"CASE WHEN {alias}.src = {fid} THEN {alias}.dst ELSE {alias}.src END";
}


def _nd_types(hop: QHop) -> list[type] {
    nd = hop.nd;
    if nd is None {
        return [];
    }
    return list(nd) if isinstance(nd, tuple) else [nd];
}


impl compile_query(
    q: GraphQuery,
    upto: int,
    promotions: (dict[str, any] | None) = None,
    count_only: bool = False,
    acl_root: (str | None) = None
) -> CompiledQuery {
    out = CompiledQuery();
    params: dict[str, any] = {};
    params['origin'] = [];
    joins: list[str] = [];
    order: list[str] = [];
    fid = 'f0.id';
    n = 0;
    node_names: list[str] = [];
    edge_names: list[str] = [];
    for (i, hop) in enumerate(q.hops[:upto]) {
        n = i + 1;
        e = f"e{n}";
        nd_alias = f"n{n}";
        pfx_e = f"h{n}e";
        econds = [f"{e}.kind = 'EdgeAnchor'", _dir_cond(e, fid, hop.dir)];
        if hop.`edge is not None {
            econds.append(_type_cond(e, hop.`edge.__name__, params, pfx_e));
        }
        edge_names = (
            [str(getattr(hop.`edge, '__name__', ''))] if hop.`edge is not None else []
        );
        for (j, p) in enumerate(hop.epreds) {
            cond = _pred_cond(e, p, params, f"{pfx_e}p{j}", edge_names, promotions);
            if cond is None {
                out.residual.setdefault(i, []).append(p);
            } else {
                econds.append(cond);
            }
        }
        joins.append(f"JOIN anchors {e} ON {' AND '.join(econds)}");
        nconds = [
            f"{nd_alias}.id = {_other_expr(e, fid)}",
            f"{nd_alias}.kind = 'NodeAnchor'"
        ];
        for (k, nt) in enumerate(_nd_types(hop)) {
            tname = str(getattr(nt, '__name__', ''));
            if tname {
                nconds.append(_type_cond(nd_alias, tname, params, f"h{n}n{k}"));
            }
        }
        node_names = [str(getattr(nt, '__name__', '')) for nt in _nd_types(hop)];
        for (j, p) in enumerate(hop.preds) {
            cond = _pred_cond(
                nd_alias, p, params, f"h{n}np{j}", node_names, promotions
            );
            if cond is None {
                out.residual.setdefault(i, []).append(p);
            } else {
                nconds.append(cond);
            }
        }
        if acl_root is not None {
            nconds.append(_acl_cond(nd_alias, acl_root, params, f"h{n}a"));
        }
        want = hop.only_ids();
        if want is not None {
            key = f"h{n}only";
            params[key] = [str(x) for x in want];
            nconds.append(f"{nd_alias}.id = ANY(CAST(:{key} AS uuid[]))");
        }
        joins.append(f"JOIN anchors {nd_alias} ON {' AND '.join(nconds)}");
        order.append(f"{e}.seq");
        order.append(f"{e}.id");
        fid = f"{nd_alias}.id";
    }
    if n == 0 {
        out.sql = (
            'SELECT count(DISTINCT f0.id) FROM '
            'unnest(CAST(:origin AS uuid[])) AS f0(id)'
        )
            if count_only
            else (
                'SELECT f0.id, NULL FROM ' 'unnest(CAST(:origin AS uuid[])) AS f0(id)'
            );
        out.params = params;
        return out;
    }
    if count_only {
        counted = f"e{n}.id" if q.edges_only else f"n{n}.id";
        out.sql = (
            f"SELECT count(DISTINCT {counted}) "
            f"FROM unnest(CAST(:origin AS uuid[])) AS f0(id) "
            f"LEFT JOIN anchors s1 ON s1.id = f0.id "
            + ' '.join(joins)
        );
        out.params = params;
        return out;
    }
    if q.order {
        order = [];
        for spec in q.order {
            alias = f"e{n}" if spec.on_edge else f"n{n}";
            names = edge_names if spec.on_edge else node_names;
            col = _field_expr(alias, spec.field, names, promotions);
            order.append(f"{col} {'DESC' if spec.desc else 'ASC'}");
        }
    }
    tail = '';
    if q.limit is not None {
        tail += f" LIMIT {int(q.limit)}";
    }
    if q.offset {
        tail += f" OFFSET {int(q.offset)}";
    }
    out.sql = (
        f"SELECT n{n}.id, e{n}.id "
        f"FROM unnest(CAST(:origin AS uuid[])) WITH ORDINALITY AS f0(id, ord) "
        f"LEFT JOIN anchors s1 ON s1.id = f0.id "
        + ' '.join(joins)
        + ' ORDER BY f0.ord, '
        + ', '.join(order)
        + tail
    );
    out.params = params;
    return out;
}
