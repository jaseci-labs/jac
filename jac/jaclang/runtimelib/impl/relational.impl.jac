import hashlib;
import json;
import logging;
import os;
import threading;
import datetime;
import types as pytypes;
import typing;
import from dataclasses { is_dataclass }
import from decimal { Decimal }
import from enum { Enum }
import from uuid { UUID }
import from jaclang.jac0core.archetype { EdgeArchetype, NodeArchetype }

glob logger = logging.getLogger(__name__),
     # keep in sync with SCALAR_SQL in jac0core/passes/graph_schema_pass.jac
     # (the pass cannot import runtimelib, so the map is duplicated)
     SCALAR_SQL: dict[str, str] = {
         'str': 'text',
         'int': 'bigint',
         'float': 'double precision',
         'bool': 'boolean',
         'bytes': 'bytea',
         'UUID': 'uuid',
         'datetime': 'timestamptz',
         'date': 'date',
         'time': 'time',
         'timedelta': 'interval',
         'Decimal': 'numeric'
     },
     _CAST_TYPES: set[str] = {
         'uuid',
         'uuid[]',
         'jsonb',
         'timestamptz',
         'date',
         'time',
         'interval',
         'numeric',
         'bytea',
         'smallint'
     },
     _plans: dict[str, TablePlan] = {},
     _ready: set[str] = set(),
     _lock = threading.RLock();

glob _BASE_SQL: list[str] = [
         """
    CREATE TABLE IF NOT EXISTS nodes (
        id          uuid PRIMARY KEY,
        arch_type   text NOT NULL,
        arch_module text NOT NULL DEFAULT '',
        root_id     uuid,
        seq         bigserial
    )
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_nodes_type ON nodes (arch_type)
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_nodes_root
        ON nodes (root_id) WHERE root_id IS NOT NULL
    """,
         """
    CREATE TABLE IF NOT EXISTS edges (
        id          uuid PRIMARY KEY,
        edge_type   text NOT NULL,
        arch_module text NOT NULL DEFAULT '',
        src         uuid,
        dst         uuid,
        root_id     uuid,
        undirected  boolean NOT NULL DEFAULT false,
        seq         bigserial,
        props       jsonb NOT NULL DEFAULT '{}'::jsonb
    )
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_edges_src
        ON edges (src, edge_type) INCLUDE (dst, seq) WHERE src IS NOT NULL
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_edges_dst
        ON edges (dst, edge_type) INCLUDE (src, seq) WHERE dst IS NOT NULL
    """,
         """
    ALTER TABLE edges ADD COLUMN IF NOT EXISTS access jsonb
    """,
         """
    CREATE TABLE IF NOT EXISTS graph_tables (
        table_name  text PRIMARY KEY,
        kind        text NOT NULL,
        arch_type   text NOT NULL,
        arch_module text NOT NULL DEFAULT ''
    )
    """
     ];


impl relational_enabled -> bool {
    return os.environ.get('JAC_RELATIONAL', '').strip().lower()
        in ['1', 'on', 'true', 'shadow'];
}


impl relational_reset_cache -> None {
    with _lock {
        _plans.clear();
        _ready.clear();
    }
}


def _ident(name: str) -> str {
    cleaned = ''.join(ch if (ch.isalnum() or ch == '_') else '_' for ch in name);
    if not cleaned or cleaned[0].isdigit() {
        cleaned = 't_' + cleaned;
    }
    return cleaned.lower();
}


def _db_key(store: object, suffix: str) -> str {
    return f"{store.conninfo.database}::{suffix}";
}


# ---------------------------------------------------------------------------
# table plans: manifest first, runtime reflection fallback

def _manifest_fields(arch_type: str, arch_module: str) -> (list | None) {
    try {
        import from jaclang.jac0core.runtime { JacRuntime }
        prog = getattr(JacRuntime, 'program', None);
        if prog is None {
            return None;
        }
        for hub in prog._search_hubs() {
            for mod in hub.values() {
                if getattr(mod, 'name', None) != arch_module {
                    continue;
                }
                gen = getattr(mod, 'gen', None);
                man = getattr(gen, 'interop_manifest', None) if gen else None;
                gs = getattr(man, 'graph_schema', None) if man else None;
                if not gs {
                    continue;
                }
                spec = (gs.get('nodes') or {}).get(arch_type);
                if spec and isinstance(spec.get('fields'), list) {
                    return spec['fields'];
                }
            }
        }
    } except Exception as e {
        logger.debug(f"manifest schema lookup failed for {arch_type}: {e}");
    }
    return None;
}


glob _PY_SCALARS: dict[type, str] = {
         str: 'str',
         int: 'int',
         float: 'float',
         bool: 'bool',
         bytes: 'bytes',
         UUID: 'UUID',
         datetime.datetime: 'datetime',
         datetime.date: 'date',
         datetime.time: 'time',
         datetime.timedelta: 'timedelta',
         Decimal: 'Decimal'
     };


def _spec_from_pytype(name: str, t: object) -> dict {
    out = {
        'name': name,
        'tier': 'json',
        'type': 'any',
        'target': None,
        'optional': False
    };
    origin = typing.get_origin(t);
    if origin is typing.Union or origin is pytypes.UnionType {
        args = [
            a
            for a in typing.get_args(t)
            if a is not type(None)
        ];
        if len(args) == 1 and len(typing.get_args(t)) > 1 {
            inner = _spec_from_pytype(name, args[0]);
            inner['optional'] = True;
            return inner;
        }
        out['type'] = 'union';
        return out;
    }
    if origin in [list, set] {
        args = typing.get_args(t);
        if len(args) == 1 {
            elem = _spec_from_pytype(name, args[0]);
            if elem['tier'] == 'node_ref' {
                out['tier'] = 'node_ref_list';
                out['target'] = elem['target'];
            } elif elem['tier'] == 'scalar' {
                out['tier'] = 'scalar_list';
                out['type'] = f"list[{elem['type']}]";
            }
        }
        return out;
    }
    if not isinstance(t, type) {
        return out;
    }
    # bool must win over int (bool subclasses int)
    if t is bool {
        out['tier'] = 'scalar';
        out['type'] = 'bool';
        return out;
    }
    if t in _PY_SCALARS {
        out['tier'] = 'scalar';
        out['type'] = _PY_SCALARS[t];
        return out;
    }
    if issubclass(t, NodeArchetype) {
        out['tier'] = 'node_ref';
        out['type'] = t.__name__;
        out['target'] = t.__name__;
        return out;
    }
    if issubclass(t, EdgeArchetype) {
        out['tier'] = 'edge_ref';
        out['type'] = t.__name__;
        out['target'] = t.__name__;
        return out;
    }
    if issubclass(t, Enum) {
        out['tier'] = 'enum';
        out['type'] = t.__name__;
        out['target'] = t.__name__;
        return out;
    }
    if is_dataclass(t) {
        out['tier'] = 'obj';
        out['type'] = t.__name__;
        out['target'] = t.__name__;
        return out;
    }
    return out;
}


def _reflect_fields(arch_type: str, arch_module: str) -> (list | None) {
    try {
        import from jaclang.runtimelib.serializer { Serializer }
        cls = Serializer._get_class(arch_module, arch_type);
        if cls is None {
            return None;
        }
        import from jaclang.runtimelib.typecache { get_field_types }
        fts = get_field_types(cls);
        return [
            _spec_from_pytype(n, t)
            for (n, t) in fts.items()
            if not n.startswith('_')
        ];
    } except Exception as e {
        logger.debug(f"reflection schema lookup failed for {arch_type}: {e}");
        return None;
    }
}


def _sql_type_for(spec: dict) -> str {
    tier = spec.get('tier', 'json');
    if tier == 'scalar' {
        return SCALAR_SQL.get(spec.get('type'), 'text');
    }
    if tier == 'enum' {
        return 'text';
    }
    if tier in ['node_ref', 'edge_ref'] {
        return 'uuid';
    }
    if tier == 'node_ref_list' {
        return 'uuid[]';
    }
    return 'jsonb';
}


impl plan_for(arch_type: str, arch_module: str) -> (TablePlan | None) {
    key = f"{arch_module}::{arch_type}";
    with _lock {
        if key in _plans {
            return _plans[key];
        }
    }
    fields = _manifest_fields(arch_type, arch_module);
    if fields is None {
        fields = _reflect_fields(arch_type, arch_module);
    }
    if fields is None {
        # not cached: the class may register later (import order, dynamic
        # types); a permanent negative would silently starve the typed table
        return None;
    }
    mod6 = hashlib.md5(arch_module.encode()).hexdigest()[:6];
    cols = [
        ColumnSpec(
            name=str(f.get('name')),
            col='f_' + _ident(str(f.get('name'))),
            tier=str(f.get('tier', 'json')),
            sql_type=_sql_type_for(f)
        )
        for f in fields
        if f.get('name') and not str(f.get('name')).startswith('_')
    ];
    plan = TablePlan(
        table=f"n_{_ident(arch_type.lower())}_{mod6}",
        arch_type=arch_type,
        arch_module=arch_module,
        columns=cols
    );
    with _lock {
        _plans[key] = plan;
    }
    return plan;
}


# ---------------------------------------------------------------------------
# DDL

def _ensure_base(store: object) -> None {
    key = _db_key(store, '__base__');
    with _lock {
        if key in _ready {
            return;
        }
    }
    for sql in _BASE_SQL {
        store._run(sql, {});
    }
    with _lock {
        _ready.add(key);
    }
}


def _ensure_table(store: object, plan: TablePlan) -> None {
    key = _db_key(store, plan.table);
    with _lock {
        if key in _ready {
            return;
        }
    }
    store._run(
        f"""
        CREATE TABLE IF NOT EXISTS {plan.table} (
            id       uuid PRIMARY KEY,
            root_id  uuid,
            acl_all  smallint NOT NULL DEFAULT -1,
            acl_spec boolean NOT NULL DEFAULT false,
            access   jsonb,
            extra    jsonb NOT NULL DEFAULT '{{}}'::jsonb
        )
        """,
        {}
    );
    for c in plan.columns {
        store._run(
            f"ALTER TABLE {plan.table} ADD COLUMN IF NOT EXISTS {c.col} {c.sql_type}",
            {}
        );
    }
    store._run(
        f"""
        CREATE INDEX IF NOT EXISTS idx_{plan.table}_root
            ON {plan.table} (root_id) WHERE root_id IS NOT NULL
        """,
        {}
    );
    store._run(
        """
        INSERT INTO graph_tables (table_name, kind, arch_type, arch_module)
        VALUES (:t, 'node', :at, :am)
        ON CONFLICT (table_name) DO NOTHING
        """,
        {'t': plan.table, 'at': plan.arch_type, 'am': plan.arch_module}
    );
    with _lock {
        _ready.add(key);
    }
}


# ---------------------------------------------------------------------------
# value extraction

def _ref_uuid(v: object) -> (str | None) {
    raw: object = v;
    if isinstance(v, dict) {
        raw = v.get('$ref');
    }
    if isinstance(raw, UUID) {
        return str(raw);
    }
    if isinstance(raw, str) {
        try {
            return str(UUID(raw));
        } except ValueError {
            return None;
        }
    }
    return None;
}


def _coerce(c: ColumnSpec, v: object) -> tuple {
    if v is None {
        return (True, None);
    }
    if c.tier == 'scalar' {
        st = c.sql_type;
        if st == 'text' {
            return (True, v) if isinstance(v, str) else (False, None);
        }
        if st == 'bigint' {
            ok = isinstance(v, int) and not isinstance(v, bool);
            return (True, v) if ok else (False, None);
        }
        if st == 'double precision' {
            ok = isinstance(v, (int, float)) and not isinstance(v, bool);
            return (True, v) if ok else (False, None);
        }
        if st == 'boolean' {
            return (True, v) if isinstance(v, bool) else (False, None);
        }
        if st == 'uuid' {
            u = _ref_uuid(v);
            return (True, u) if u else (False, None);
        }
        # timestamptz/date/time/interval/numeric/bytea travel as text and
        # rely on the CAST; the serializer stringifies these types upstream
        return (True, v) if isinstance(v, str) else (False, None);
    }
    if c.tier == 'enum' {
        if isinstance(v, str) {
            return (True, v);
        }
        if isinstance(v, (int, float)) and not isinstance(v, bool) {
            return (True, str(v));
        }
        return (False, None);
    }
    if c.tier in ['node_ref', 'edge_ref'] {
        u = _ref_uuid(v);
        return (True, u) if u else (False, None);
    }
    if c.tier == 'node_ref_list' {
        if not isinstance(v, list) {
            return (False, None);
        }
        out: list[str] = [];
        for item in v {
            u = _ref_uuid(item);
            if u is None {
                return (False, None);
            }
            out.append(u);
        }
        return (True, out);
    }
    try {
        return (True, json.dumps(v, default=str));
    } except Exception {
        return (False, None);
    }
}


def _acl_scalars(props: dict) -> tuple {
    a = props.get('access');
    if not isinstance(a, dict) {
        return (-1, False, None);
    }
    all_v = a.get('all');
    acl_all = all_v if (isinstance(all_v, int) and not isinstance(all_v, bool)) else -1;
    roots = a.get('roots');
    anchors = roots.get('anchors') if isinstance(roots, dict) else None;
    acl_spec = bool(anchors);
    return (acl_all, acl_spec, json.dumps(a, default=str));
}


def _fields_dict(props: dict) -> dict {
    arch = props.get('archetype');
    if not isinstance(arch, dict) {
        return {};
    }
    # __type__/__module__ are derivable from arch_type/arch_module; every
    # other key (including __jac_attic__) must survive the round-trip
    return {
        k: v
        for (k, v) in arch.items()
        if k not in ['__type__', '__module__']
    };
}


def _cast_expr(pname: str, sql_type: str) -> str {
    if sql_type in _CAST_TYPES {
        return f"CAST(:{pname} AS {sql_type})";
    }
    return f":{pname}";
}


# ---------------------------------------------------------------------------
# routing

def _upsert_directory(store: object, rows: list) -> None {
    if not rows {
        return;
    }
    values: list[str] = [];
    params: dict = {};
    for (i, row) in enumerate(rows) {
        values.append(
            f"(CAST(:id{i} AS uuid), :at{i}, :am{i}, CAST(:root{i} AS uuid))"
        );
        params[f"id{i}"] = str(row.id);
        params[f"at{i}"] = row.arch_type;
        params[f"am{i}"] = row.arch_module;
        params[f"root{i}"] = str(row.root_id) if row.root_id else None;
    }
    store._run(
        'INSERT INTO nodes (id, arch_type, arch_module, root_id) VALUES '
            + ', '.join(values)
            + """
        ON CONFLICT (id) DO UPDATE SET
            arch_type = EXCLUDED.arch_type,
            arch_module = EXCLUDED.arch_module,
            root_id = EXCLUDED.root_id
        """,
        params
    );
}


def _upsert_typed(store: object, plan: TablePlan, rows: list) -> None {
    if not rows {
        return;
    }
    col_names = ['id', 'root_id', 'acl_all', 'acl_spec', 'access', 'extra']
        + [c.col for c in plan.columns];
    values: list[str] = [];
    params: dict = {};
    for (i, row) in enumerate(rows) {
        fieldsd = _fields_dict(row.props);
        (acl_all, acl_spec, access_json) = _acl_scalars(row.props);
        extra: dict = {};
        exprs = [
            f"CAST(:id{i} AS uuid)",
            f"CAST(:root{i} AS uuid)",
            f"CAST(:aall{i} AS smallint)",
            f":aspec{i}",
            f"CAST(:acc{i} AS jsonb)"
        ];
        params[f"id{i}"] = str(row.id);
        params[f"root{i}"] = str(row.root_id) if row.root_id else None;
        params[f"aall{i}"] = acl_all;
        params[f"aspec{i}"] = acl_spec;
        params[f"acc{i}"] = access_json;
        planned: set[str] = set();
        for (j, c) in enumerate(plan.columns) {
            planned.add(c.name);
            v = fieldsd.get(c.name);
            (ok, coerced) = _coerce(c, v);
            if not ok {
                extra[c.name] = v;
                coerced = None;
            }
            pname = f"c{i}_{j}";
            exprs.append(_cast_expr(pname, c.sql_type));
            params[pname] = coerced;
        }
        for (k, v) in fieldsd.items() {
            if k not in planned {
                extra[k] = v;
            }
        }
        exprs.insert(5, f"CAST(:extra{i} AS jsonb)");
        params[f"extra{i}"] = json.dumps(extra, default=str);
        values.append('(' + ', '.join(exprs) + ')');
    }
    updates = ',\n'.join(
        f"{c} = EXCLUDED.{c}"
        for c in col_names
        if c != 'id'
    );
    store._run(
        f"INSERT INTO {plan.table} ({', '.join(col_names)}) VALUES\n"
            + ',\n'.join(values)
            + f"\nON CONFLICT (id) DO UPDATE SET {updates}",
        params
    );
}


def _upsert_edges(store: object, rows: list) -> None {
    if not rows {
        return;
    }
    values: list[str] = [];
    params: dict = {};
    for (i, row) in enumerate(rows) {
        values.append(
            f"(CAST(:id{i} AS uuid), :et{i}, :am{i}, CAST(:src{i} AS uuid), "
            f"CAST(:dst{i} AS uuid), CAST(:root{i} AS uuid), :und{i}, "
            f"CAST(:props{i} AS jsonb), CAST(:acc{i} AS jsonb))"
        );
        params[f"id{i}"] = str(row.id);
        params[f"et{i}"] = row.arch_type or 'GenericEdge';
        params[f"am{i}"] = row.arch_module;
        params[f"src{i}"] = str(row.src) if row.src else None;
        params[f"dst{i}"] = str(row.dst) if row.dst else None;
        params[f"root{i}"] = str(row.root_id) if row.root_id else None;
        params[f"und{i}"] = row.undirected;
        params[f"props{i}"] = json.dumps(_fields_dict(row.props), default=str);
        a = row.props.get('access');
        params[f"acc{i}"] = json.dumps(a, default=str) if isinstance(a, dict) else None;
    }
    store._run(
        'INSERT INTO edges '
        '(id, edge_type, arch_module, src, dst, root_id, undirected, '
        'props, access) VALUES '
            + ', '.join(values)
            + """
        ON CONFLICT (id) DO UPDATE SET
            edge_type = EXCLUDED.edge_type,
            arch_module = EXCLUDED.arch_module,
            src = EXCLUDED.src,
            dst = EXCLUDED.dst,
            root_id = EXCLUDED.root_id,
            undirected = EXCLUDED.undirected,
            props = EXCLUDED.props,
            access = EXCLUDED.access
        """,
        params
    );
}


impl relational_after_upsert(store: object, rows: list) -> None {
    if not relational_enabled() {
        return;
    }
    node_rows = [
        r
        for r in rows
        if r.kind == 'NodeAnchor'
    ];
    edge_rows = [
        r
        for r in rows
        if r.kind == 'EdgeAnchor'
    ];
    if not (node_rows or edge_rows) {
        return;
    }
    _ensure_base(store);
    _upsert_directory(store, node_rows);
    groups: dict[tuple, list] = {};
    for row in node_rows {
        groups.setdefault((row.arch_type, row.arch_module), []).append(row);
    }
    for ((at, am), grp) in groups.items() {
        plan = plan_for(at, am);
        if plan is None {
            # directory-only: no class and no manifest for this type yet
            continue;
        }
        _ensure_table(store, plan);
        _upsert_typed(store, plan, grp);
    }
    _upsert_edges(store, edge_rows);
}


impl relational_after_delete(store: object, ids: list[UUID]) -> None {
    if not relational_enabled() or not ids {
        return;
    }
    _ensure_base(store);
    sids = [str(i) for i in ids];
    store._run('DELETE FROM edges WHERE id = ANY(CAST(:ids AS uuid[]))', {'ids': sids});
    returned = store._run(
        """
        DELETE FROM nodes WHERE id = ANY(CAST(:ids AS uuid[]))
        RETURNING id, arch_type, arch_module
        """,
        {'ids': sids}
    );
    groups: dict[tuple, list] = {};
    for r in returned {
        groups.setdefault((str(r[1]), str(r[2])), []).append(str(r[0]));
    }
    for ((at, am), gids) in groups.items() {
        plan = plan_for(at, am);
        if plan is None {
            continue;
        }
        _ensure_table(store, plan);
        store._run(
            f"DELETE FROM {plan.table} WHERE id = ANY(CAST(:ids AS uuid[]))",
            {'ids': gids}
        );
    }
}


# ---------------------------------------------------------------------------
# parity

def _norm_uuid(v: object) -> (str | None) {
    if v is None {
        return None;
    }
    try {
        return str(UUID(str(v)));
    } except ValueError {
        return str(v);
    }
}


def _norm_json(v: object) -> object {
    if isinstance(v, str) {
        try {
            return json.loads(v);
        } except ValueError {
            return v;
        }
    }
    return v;
}


def _scalar_equal(sql_type: str, stored: object, expected: object) -> bool {
    if stored is None or expected is None {
        return stored is None and expected is None;
    }
    if sql_type == 'bigint' {
        try {
            return int(str(stored)) == int(str(expected));
        } except ValueError {
            return False;
        }
    }
    if sql_type == 'double precision' {
        try {
            return abs(float(str(stored)) - float(str(expected))) < 1e-9;
        } except ValueError {
            return False;
        }
    }
    if sql_type == 'boolean' {
        return bool(stored) == bool(expected);
    }
    if sql_type == 'uuid' {
        return _norm_uuid(stored) == _norm_uuid(expected);
    }
    return str(stored) == str(expected);
}


impl relational_parity(store: object, limit: int = 1000) -> list[str] {
    # read-only: works regardless of JAC_RELATIONAL so `jac db parity` can
    # inspect any database; absent tables are a finding, not a crash
    present = store._run(
        """
        SELECT 1 FROM pg_tables
        WHERE schemaname = current_schema() AND tablename = 'nodes'
        """,
        {}
    );
    if not present {
        return [
            'relational tables absent ' '(enable JAC_RELATIONAL=shadow and write first)'
        ];
    }
    problems: list[str] = [];
    arows = store._run(
        """
        SELECT id, kind, arch_type, arch_module, root_id, src, dst,
               undirected, props
        FROM anchors WHERE kind IN ('NodeAnchor', 'EdgeAnchor')
        ORDER BY seq LIMIT :n
        """,
        {'n': limit}
    );
    node_anchors = [
        r
        for r in arows
        if str(r[1]) == 'NodeAnchor'
    ];
    edge_anchors = [
        r
        for r in arows
        if str(r[1]) == 'EdgeAnchor'
    ];

    dir_map: dict[str, tuple] = {};
    if node_anchors {
        for r in store._run(
            'SELECT id, arch_type, root_id FROM nodes '
            'WHERE id = ANY(CAST(:ids AS uuid[]))',
            {'ids': [str(r[0]) for r in node_anchors]}
        ) {
            dir_map[_norm_uuid(r[0])] = (str(r[1]), _norm_uuid(r[2]));
        }
    }
    edge_map: dict[str, tuple] = {};
    if edge_anchors {
        for r in store._run(
            'SELECT id, edge_type, src, dst, undirected FROM edges '
            'WHERE id = ANY(CAST(:ids AS uuid[]))',
            {'ids': [str(r[0]) for r in edge_anchors]}
        ) {
            edge_map[_norm_uuid(r[0])] = (
                str(r[1]),
                _norm_uuid(r[2]),
                _norm_uuid(r[3]),
                bool(r[4])
            );
        }
    }

    groups: dict[tuple, list] = {};
    for r in node_anchors {
        rid = _norm_uuid(r[0]);
        got = dir_map.get(rid);
        if got is None {
            problems.append(f"node {rid} ({r[2]}) missing from nodes directory");
            continue;
        }
        if got[0] != str(r[2]) {
            problems.append(f"node {rid}: directory type {got[0]} != {r[2]}");
        }
        if got[1] != _norm_uuid(r[4]) {
            problems.append(f"node {rid}: directory root {got[1]} != {r[4]}");
        }
        groups.setdefault((str(r[2]), str(r[3])), []).append(r);
    }

    for r in edge_anchors {
        rid = _norm_uuid(r[0]);
        got = edge_map.get(rid);
        if got is None {
            problems.append(f"edge {rid} ({r[2]}) missing from edges table");
            continue;
        }
        if got[0] != str(r[2]) {
            problems.append(f"edge {rid}: edge_type {got[0]} != {r[2]}");
        }
        if got[1] != _norm_uuid(r[5]) or got[2] != _norm_uuid(r[6]) {
            problems.append(
                f"edge {rid}: endpoints ({got[1]}, {got[2]}) != "
                f"({_norm_uuid(r[5])}, {_norm_uuid(r[6])})"
            );
        }
        if got[3] != bool(r[7]) {
            problems.append(f"edge {rid}: undirected {got[3]} != {bool(r[7])}");
        }
    }

    for ((at, am), grp) in groups.items() {
        plan = plan_for(at, am);
        if plan is None {
            continue;
        }
        cols = [
            c
            for c in plan.columns
            if c.tier in ['scalar', 'enum', 'node_ref']
        ];
        sel = ['id'] + [c.col for c in cols];
        typed: dict[str, tuple] = {};
        for tr in store._run(
            f"SELECT {', '.join(sel)} FROM {plan.table} "
            'WHERE id = ANY(CAST(:ids AS uuid[]))',
            {'ids': [str(r[0]) for r in grp]}
        ) {
            typed[_norm_uuid(tr[0])] = tr;
        }
        for r in grp {
            rid = _norm_uuid(r[0]);
            tr = typed.get(rid);
            if tr is None {
                problems.append(f"node {rid} ({at}) missing from {plan.table}");
                continue;
            }
            raw_props = r[8];
            props = (
                raw_props if isinstance(raw_props, dict) else json.loads(str(raw_props))
            );
            fieldsd = _fields_dict(props);
            for (j, c) in enumerate(cols) {
                (ok, expected) = _coerce(c, fieldsd.get(c.name));
                if not ok {
                    continue;
                }
                if not _scalar_equal(c.sql_type, tr[j + 1], expected) {
                    problems.append(
                        f"node {rid} ({at}).{c.name}: "
                        f"typed {tr[j + 1]!r} != props {expected!r}"
                    );
                }
            }
        }
    }
    return problems;
}


# ---------------------------------------------------------------------------
# read path (A3): materialize anchors from the relational layout

impl relational_read_enabled -> bool {
    return os.environ.get('JAC_RELATIONAL', '').strip().lower() == 'on';
}


def _reconstruct_value(c: ColumnSpec, v: object) -> object {
    if v is None {
        return None;
    }
    if c.tier in ['node_ref', 'edge_ref'] {
        kind = 'node' if c.tier == 'node_ref' else 'edge';
        try {
            return {'$ref': UUID(str(v)).hex, '$type': kind};
        } except ValueError {
            return str(v);
        }
    }
    if c.tier == 'node_ref_list' {
        items: list = [];
        raw = v;
        if isinstance(raw, str) {
            raw = [
                x
                for x in raw.strip('{}').split(',')
                if x
            ];
        }
        for item in (raw if isinstance(raw, list) else []) {
            try {
                items.append({'$ref': UUID(str(item)).hex, '$type': 'node'});
            } except ValueError {
                items.append(str(item));
            }
        }
        return items;
    }
    if c.tier == 'enum' {
        s = str(v);
        if s.lstrip('-').isdigit() {
            return int(s);
        }
        return s;
    }
    if c.sql_type == 'jsonb' {
        return _norm_json(v);
    }
    return v;
}


def _adjacency_map(store: object, node_ids: list[str]) -> dict {
    adj: dict[str, list] = {i: [] for i in node_ids};
    seen: dict[str, set] = {i: set() for i in node_ids};
    rows = store._run(
        """
        SELECT src, dst, id FROM edges
        WHERE src = ANY(CAST(:ids AS uuid[])) OR dst = ANY(CAST(:ids AS uuid[]))
        ORDER BY seq, id
        """,
        {'ids': node_ids}
    );
    for r in rows {
        eid = str(r[2]);
        for endpoint in [r[0], r[1]] {
            if endpoint is None {
                continue;
            }
            key = _norm_uuid(endpoint);
            if key in adj and eid not in seen[key] {
                seen[key].add(eid);
                adj[key].append(eid);
            }
        }
    }
    return adj;
}


impl relational_load_full(store: object, ids: list[UUID]) -> tuple {
    """Returns (rows: dict[UUID, AnchorRow-args-dict], missing: list[UUID]).

    rows values are dicts consumable as AnchorRow fields by the store; ids
    that cannot be fully reconstructed relationally (walkers, unplanned
    types, pre-shadow rows) land in missing for the anchors fallback.
    """;
    sids = [str(i) for i in ids];
    found: dict = {};
    resolved: set[str] = set();

    # anchors stays the source of truth pre-cutover: ids missing there must
    # not resurrect from a stale mirror row (index-only pkey probe)
    live = {
        _norm_uuid(r[0])
        for r in store._run(
            'SELECT id FROM anchors WHERE id = ANY(CAST(:ids AS uuid[]))', {'ids': sids}
        )
    };
    sids = [
        x
        for x in sids
        if x in live
    ];
    if not sids {
        return ({}, list(ids));
    }

    dir_rows = store._run(
        'SELECT id, arch_type, arch_module, root_id FROM nodes '
        'WHERE id = ANY(CAST(:ids AS uuid[]))',
        {'ids': sids}
    );
    node_groups: dict[tuple, list] = {};
    node_meta: dict[str, tuple] = {};
    for r in dir_rows {
        rid = _norm_uuid(r[0]);
        node_meta[rid] = (str(r[1]), str(r[2]), _norm_uuid(r[3]));
        node_groups.setdefault((str(r[1]), str(r[2])), []).append(rid);
    }

    adj = _adjacency_map(store, list(node_meta.keys())) if node_meta else {};

    for ((at, am), gids) in node_groups.items() {
        plan = plan_for(at, am);
        if plan is None {
            continue;
        }
        _ensure_table(store, plan);
        sel = ['id', 'root_id', 'access', 'extra', 'xmin::text']
            + [c.col for c in plan.columns];
        for tr in store._run(
            f"SELECT {', '.join(sel)} FROM {plan.table} "
            'WHERE id = ANY(CAST(:ids AS uuid[]))',
            {'ids': gids}
        ) {
            rid = _norm_uuid(tr[0]);
            root_id = _norm_uuid(tr[1]);
            access = _norm_json(tr[2]);
            extra = _norm_json(tr[3]) or {};
            arch: dict = {'__type__': at, '__module__': am};
            for (j, c) in enumerate(plan.columns) {
                arch[c.name] = _reconstruct_value(c, tr[5 + j]);
            }
            if isinstance(extra, dict) {
                arch.update(extra);
            }
            edge_list = adj.get(rid, []);
            props = {
                '__type__': 'NodeAnchor',
                '__module__': 'jaclang.jac0core.archetype',
                'id': rid,
                'root': root_id,
                'persistent': True,
                'access': access if isinstance(access, dict) else {},
                'archetype': arch,
                'edges': edge_list,
                'version': int(str(tr[4]))
            };
            found[rid] = {
                'kind': 'NodeAnchor',
                'arch_type': at,
                'arch_module': am,
                'root_id': root_id,
                'props': props,
                'version': int(str(tr[4])),
                'adjacency': edge_list
            };
            resolved.add(rid);
        }
    }

    edge_rows = store._run(
        """
        SELECT id, edge_type, arch_module, src, dst, root_id, undirected,
               props, xmin::text, access
        FROM edges WHERE id = ANY(CAST(:ids AS uuid[]))
        """,
        {'ids': sids}
    );
    for r in edge_rows {
        rid = _norm_uuid(r[0]);
        fieldsd = _norm_json(r[7]) or {};
        arch = {'__type__': str(r[1]), '__module__': str(r[2])};
        if isinstance(fieldsd, dict) {
            arch.update(fieldsd);
        }
        src = _norm_uuid(r[3]);
        dst = _norm_uuid(r[4]);
        eaccess = _norm_json(r[9]);
        props = {
            '__type__': 'EdgeAnchor',
            '__module__': 'jaclang.jac0core.archetype',
            'id': rid,
            'root': _norm_uuid(r[5]),
            'persistent': True,
            'access': eaccess if isinstance(eaccess, dict) else {},
            'archetype': arch,
            'source': src,
            'target': dst,
            'is_undirected': bool(r[6])
        };
        found[rid] = {
            'kind': 'EdgeAnchor',
            'arch_type': str(r[1]),
            'arch_module': str(r[2]),
            'root_id': _norm_uuid(r[5]),
            'props': props,
            'src': src,
            'dst': dst,
            'undirected': bool(r[6]),
            'version': int(str(r[8]))
        };
        resolved.add(rid);
    }

    missing = [
        i
        for i in ids
        if str(i) not in resolved
    ];
    return (found, missing);
}


glob _backfilled: set[str] = set();


impl relational_backfill(store: object, batch: int = 2000) -> dict {
    _ensure_base(store);
    counts = {'nodes': 0, 'edges': 0};
    offset = 0;
    while True {
        rows = store._run(
            """
            SELECT id, kind, arch_type, arch_module, fingerprint, root_id,
                   src, dst, undirected, props
            FROM anchors WHERE kind IN ('NodeAnchor', 'EdgeAnchor')
            ORDER BY seq LIMIT :lim OFFSET :off
            """,
            {'lim': batch, 'off': offset}
        );
        if not rows {
            break;
        }
        offset += len(rows);
        shim_nodes: list = [];
        shim_edges: list = [];
        import from jaclang.runtimelib.store { AnchorRow }
        for r in rows {
            raw_props = r[9];
            props = (
                raw_props if isinstance(raw_props, dict) else json.loads(str(raw_props))
            );
            row = AnchorRow(
                id=UUID(str(r[0])),
                kind=str(r[1]),
                arch_type=str(r[2]),
                arch_module=str(r[3]),
                fingerprint=str(r[4]),
                root_id=UUID(str(r[5])) if r[5] else None,
                props=props,
                src=UUID(str(r[6])) if r[6] else None,
                dst=UUID(str(r[7])) if r[7] else None,
                undirected=bool(r[8])
            );
            if row.kind == 'NodeAnchor' {
                shim_nodes.append(row);
            } else {
                shim_edges.append(row);
            }
        }
        _upsert_directory(store, shim_nodes);
        groups: dict[tuple, list] = {};
        for row in shim_nodes {
            groups.setdefault((row.arch_type, row.arch_module), []).append(row);
        }
        for ((at, am), grp) in groups.items() {
            plan = plan_for(at, am);
            if plan is None {
                continue;
            }
            _ensure_table(store, plan);
            _upsert_typed(store, plan, grp);
        }
        _upsert_edges(store, shim_edges);
        counts['nodes'] += len(shim_nodes);
        counts['edges'] += len(shim_edges);
    }
    return counts;
}


def relational_backfill_once(store: object) -> None {
    key = _db_key(store, '__backfill__');
    with _lock {
        if key in _backfilled {
            return;
        }
        _backfilled.add(key);
    }
    try {
        counts = relational_backfill(store);
        logger.info(
            f"relational backfill: {counts['nodes']} nodes, "
            f"{counts['edges']} edges mirrored from anchors"
        );
    } except Exception as e {
        logger.error(f"relational backfill failed: {e}");
    }
}
