impl SqlValue.__setattr__(name: str, value: any) {
    if name == '_schema_cache' or name in self.__dict__ {
        raise SqlError('SQL values are immutable; construct a new value');
    }
    object.__setattr__(self, name, _freeze_sql_value(value));
}

impl SqlValue.__delattr__(name: str) {
    raise SqlError('SQL values are immutable; construct a new value');
}

impl DataType.postinit {
    if type(self.name) is not str or type(self.nullable) is not bool {
        raise SqlError('Invalid SQL type metadata');
    }
    base = self.name[:-2] if self.name.endswith('[]') else self.name;
    if base
        not in (
            'boolean',
            'integer',
            'bigint',
            'numeric',
            'double precision',
            'text',
            'uuid'
        ) {
        raise SqlError(f"Unsupported SQL type: {self.name}");
    }
}

impl Schema.postinit {
    names: set[str] = set();
    for f in self.fields {
        if not f.name or '\x00' in f.name or f.name in names {
            raise SqlError(f"Empty, NUL or duplicate field name: {f.name}");
        }
        names.add(f.name);
    }
    if not self.fields {
        raise SqlError("A row schema must have at least one field");
    }
}

impl Schema.find(name: str) -> FieldDef {
    for f in self.fields {
        if f.name == name {
            return f;
        }
    }
    raise SqlError(f"Unknown column: {name}");
}

impl Source.ref -> Source {
    if isinstance(self, Table) {
        return Table(declared_schema=self.schema, alias='', name=self.name);
    }
    if isinstance(self, NullableSource) {
        return NullableSource(alias='', target=self.target.ref());
    }
    if isinstance(self, FunctionSource) {
        return FunctionSource(
            alias='',
            argument=self.argument,
            element=self.element,
            ordinality=self.ordinality
        );
    }
    if isinstance(self, Derived) {
        return Derived(alias='', query=self.query, lateral=self.lateral);
    }
    if isinstance(self, Cte) {
        return CteUse(alias='', target=self);
    }
    if isinstance(self, CteUse) {
        return CteUse(alias='', target=self.target);
    }
    raise SqlError('Unknown source binding');
}

impl Source.col[T](key: Field[T]) -> ScalarExpr[T] {
    actual = self.schema.find(key.name);
    if not same_type(actual.dtype, key.dtype) {
        raise SqlError(f"Column type mismatch: {key.name}");
    }
    return ScalarExpr(ast=ColumnNode(dtype=actual.dtype, source=self, name=key.name));
}

impl CteBinding.__setattr__(name: str, value: any) {
    if self.__dict__.get('_definition') is not None {
        raise SqlError('CTE reference is already defined');
    }
    object.__setattr__(self, name, value);
}

impl CteBinding.bind(query: RelationNode, recursive: bool) {
    if self._definition is not None {
        raise SqlError('CTE reference is already defined');
    }
    if type(recursive) is not bool {
        raise SqlError('Recursive flag must be boolean');
    }
    self._recursive = recursive;
    self._definition = query;
}

impl Projection.key -> Field[T] {
    return Field(name=self.field.name, dtype=self.field.dtype);
}

impl Relation.as_source(lateral: bool = False) -> Source {
    if type(lateral) is not bool {
        raise SqlError('LATERAL flag must be boolean');
    }
    return Derived(alias='', query=self.ast, lateral=lateral);
}


impl same_type(a: DataType, b: DataType) -> bool {
    return a.name == b.name and a.nullable == b.nullable;
}


impl bool_type -> SqlType[SqlBool] {
    return SqlType(DataType('boolean'));
}

impl int64_type -> SqlType[SqlInt64] {
    return SqlType(DataType('bigint'));
}

impl float64_type -> SqlType[SqlFloat64] {
    return SqlType(DataType('double precision'));
}

impl text_type -> SqlType[SqlText] {
    return SqlType(DataType('text'));
}

impl uuid_type -> SqlType[SqlUUID] {
    return SqlType(DataType('uuid'));
}

impl nullable[T](dtype: SqlType[T]) -> SqlType[Nullable[T]] {
    if dtype.data.nullable {
        raise SqlError('Type is already nullable');
    }
    return SqlType(DataType(dtype.data.name, True));
}

impl field[T](name: str, dtype: SqlType[T]) -> Field[T] {
    return Field(name=name, dtype=dtype.data);
}

impl table(
    name: str, fields: list[FieldDef], alias: str = '', namespace: str | None = None
) -> Source {
    parts = [name] if namespace is None else [namespace, name];
    return Table(declared_schema=Schema(tuple(fields)), alias=alias, name=tuple(parts));
}

impl param[T](
    dtype: SqlType[T],
    value:
        bool
            | int
            | float
            | str
            | UUID
            | Decimal
            | tuple[bool | int | float | str | UUID | Decimal | None, ...]
            | None
) -> ScalarExpr[T] {
    validate_value(dtype.data, value);
    return ScalarExpr(ParamNode(dtype=dtype.data, value=value));
}

impl int64(value: int) -> ScalarExpr[SqlInt64] {
    return param(int64_type(), value);
}

impl text(value: str) -> ScalarExpr[SqlText] {
    return param(text_type(), value);
}

impl boolean(value: bool) -> ScalarExpr[SqlBool] {
    return param(bool_type(), value);
}

impl uuid(value: UUID) -> ScalarExpr[SqlUUID] {
    return param(uuid_type(), value);
}

impl validate_value(
    dtype: DataType,
    value:
        bool
            | int
            | float
            | str
            | UUID
            | Decimal
            | tuple[bool | int | float | str | UUID | Decimal | None, ...]
            | None
) -> None {
    if value is None {
        if not dtype.nullable {
            raise SqlError('NULL requires a nullable SQL type');
        }
        return;
    }
    if dtype.name.endswith('[]') {
        if not isinstance(value, (list, tuple)) {
            raise SqlError('Array parameter requires a sequence');
        }
        for item in value {
            validate_value(DataType(dtype.name[:-2]), item);
        }
        return;
    }
    valid = False;
    if dtype.name == 'integer' {
        valid = type(value) is int;
        if valid and (value < -2147483648 or value > 2147483647) {
            raise SqlError('Value is outside signed int32');
        }
    } elif dtype.name == 'numeric' {
        valid = type(value) is int or isinstance(value, Decimal);
    } elif dtype.name == 'boolean' {
        valid = type(value) is bool;
    } elif dtype.name == 'bigint' {
        valid = type(value) is int;
        if valid and (value < -9223372036854775808 or value > 9223372036854775807) {
            raise SqlError('Value is outside signed int64');
        }
    } elif dtype.name == 'double precision' {
        valid = type(value) is float;
    } elif dtype.name == 'text' {
        valid = type(value) is str;
    } elif dtype.name == 'uuid' {
        valid = isinstance(value, UUID);
    }
    if not valid {
        raise SqlError(f'Invalid parameter value for {dtype.name}');
    }
}

impl _compare[T](
    left: ScalarExpr[T], right: ScalarExpr[T], op: str
) -> ScalarExpr[SqlBool] {
    if not same_type(left.ast.dtype, right.ast.dtype) or left.ast.dtype.nullable {
        raise SqlError(
            'Comparison requires identical non-null SQL types; use eq_nullable for NULL'
        );
    }
    return ScalarExpr(
        BinaryNode(dtype=DataType('boolean'), op=op, left=left.ast, right=right.ast)
    );
}

impl eq[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool] {
    return _compare(left, right, '=');
}

impl gt[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool] {
    if left.ast.dtype.name
        not in ('integer', 'bigint', 'numeric', 'double precision', 'text', 'uuid') {
        raise SqlError('Type has no supported ordering');
    }
    return _compare(left, right, '>');
}

impl eq_nullable[T](
    left: ScalarExpr[Nullable[T]], right: ScalarExpr[Nullable[T]]
) -> ScalarExpr[Nullable[SqlBool]] {
    if not same_type(left.ast.dtype, right.ast.dtype) or not left.ast.dtype.nullable {
        raise SqlError('eq_nullable requires identical nullable types');
    }
    return ScalarExpr(
        BinaryNode(
            dtype=DataType('boolean', True), op='=', left=left.ast, right=right.ast
        )
    );
}

impl add(
    left: ScalarExpr[SqlInt64], right: ScalarExpr[SqlInt64]
) -> ScalarExpr[SqlInt64] {
    for term in [left.ast, right.ast] {
        if term.dtype.name != 'bigint' or term.dtype.nullable {
            raise SqlError('add requires non-null int64 operands');
        }
    }
    return ScalarExpr(
        BinaryNode(dtype=DataType('bigint'), op='+', left=left.ast, right=right.ast)
    );
}

impl and_(terms: list[ScalarExpr[SqlBool]]) -> ScalarExpr[SqlBool] {
    if not terms {
        raise SqlError('and_ requires at least one operand');
    }
    for term in terms {
        if term.ast.dtype.name != 'boolean' or term.ast.dtype.nullable {
            raise SqlError('and_ requires non-null boolean operands');
        }
    }
    return ScalarExpr(
        BoolNode(dtype=DataType('boolean'), op='AND', terms=tuple(t.ast for t in terms))
    );
}

impl is_null[T](term: ScalarExpr[Nullable[T]]) -> ScalarExpr[SqlBool] {
    if not term.ast.dtype.nullable {
        raise SqlError('is_null expects a nullable expression');
    }
    return ScalarExpr(
        UnaryNode(dtype=DataType('boolean'), op='IS NULL', term=term.ast)
    );
}

impl cast[T, U](term: ScalarExpr[T], dtype: SqlType[U]) -> ScalarExpr[U] {
    if term.ast.dtype.nullable and not dtype.data.nullable {
        raise SqlError('CAST does not remove NULL');
    }
    if not _cast_allowed(term.ast.dtype, dtype.data) {
        raise SqlError('Unsupported SQL cast');
    }
    return ScalarExpr(CastNode(dtype=dtype.data, term=term.ast));
}

impl count -> ScalarExpr[SqlInt64] {
    return ScalarExpr(AggregateNode(dtype=DataType('bigint'), op='COUNT', term=None));
}

impl sum_(term: ScalarExpr[SqlFloat64]) -> ScalarExpr[Nullable[SqlFloat64]] {
    if term.ast.dtype.name != 'double precision' or term.ast.dtype.nullable {
        raise SqlError('sum_ expects float64');
    }
    return ScalarExpr(
        AggregateNode(dtype=DataType('double precision', True), op='SUM', term=term.ast)
    );
}

impl coalesce[T](
    term: ScalarExpr[Nullable[T]], fallback: ScalarExpr[T]
) -> ScalarExpr[T] {
    a = term.ast.dtype;
    b = fallback.ast.dtype;
    if not a.nullable or b.nullable or a.name != b.name {
        raise SqlError('Invalid COALESCE types');
    }
    return ScalarExpr(CoalesceNode(dtype=b, term=term.ast, fallback=fallback.ast));
}

impl named[T](name: str, expr: ScalarExpr[T]) -> Projection[T] {
    if not isinstance(expr, ScalarExpr) {
        raise SqlError('Projection requires a scalar expression');
    }
    return Projection(field=Field(name=name, dtype=expr.ast.dtype), expr=expr.ast);
}

impl asc[T](expr: ScalarExpr[T], nulls: str = '') -> Order {
    return Order(expr=expr.ast, descending=False, nulls=nulls);
}

impl desc[T](expr: ScalarExpr[T], nulls: str = '') -> Order {
    return Order(expr=expr.ast, descending=True, nulls=nulls);
}

impl inner_join(
    source: Source, on: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]
) -> Join {
    if on.ast.dtype.name != 'boolean' {
        raise SqlError('JOIN ON requires a boolean');
    }
    return Join(source=source, condition=on.ast);
}

impl select(
    projections: list[ProjectionDef],
    source: Source | None = None,
    joins: list[Join] = [],
    where: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]] | None = None,
    group_by: list[ExprNode] = [],
    having: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]] | None = None,
    order_by: list[Order] = [],
    limit: int | None = None,
    distinct: bool = False,
    distinct_on: list[ExprNode] = []
) -> Relation[Schema, Many] {
    if where is not None and where.ast.dtype.name != 'boolean' {
        raise SqlError('WHERE requires a boolean');
    }
    if having is not None and having.ast.dtype.name != 'boolean' {
        raise SqlError('HAVING requires a boolean');
    }
    if limit is not None and (type(limit) is not int or limit < 0) {
        raise SqlError('LIMIT must be a non-negative integer');
    }
    return Relation(
        SelectNode(
            cardinality='many',
            projections=tuple(projections),
            source=source,
            joins=tuple(joins),
            predicate=where.ast if where is not None else None,
            groups=tuple(group_by),
            having=having.ast if having is not None else None,
            ordering=tuple(order_by),
            limit=limit,
            distinct=distinct,
            distinct_on=tuple(distinct_on)
        )
    );
}

impl limit_one[R, C](query: Relation[R, C]) -> Relation[R, AtMostOne] {
    if not isinstance(query.ast, SelectNode) {
        raise SqlError('limit_one requires a SELECT');
    }
    q = query.ast;
    ast = SelectNode(
        cardinality='at_most_one',
        projections=q.projections,
        source=q.source,
        joins=q.joins,
        predicate=q.predicate,
        groups=q.groups,
        having=q.having,
        ordering=q.ordering,
        limit=1
    );
    return Relation(ast);
}

impl aggregate(
    projections: list[ProjectionDef],
    source: Source | None = None,
    where: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]] | None = None
) -> Relation[Schema, ExactlyOne] {
    q = select(projections, source=source, where=where);
    ast = q.ast;
    if not isinstance(ast, SelectNode) {
        raise SqlError('Aggregate requires a SELECT');
    }
    return Relation(
        SelectNode(
            cardinality='exactly_one_aggregate',
            projections=ast.projections,
            source=ast.source,
            joins=ast.joins,
            predicate=ast.predicate,
            groups=ast.groups,
            having=ast.having,
            ordering=ast.ordering,
            limit=ast.limit,
            distinct=ast.distinct,
            distinct_on=ast.distinct_on
        )
    );
}

impl scalar[R, T](
    query: Relation[R, AtMostOne] | Relation[R, ExactlyOne], key: Field[T]
) -> ScalarExpr[Nullable[T]] {
    q = query.ast;
    if len(q.schema.fields) != 1
        or q.cardinality not in ('at_most_one', 'exactly_one_aggregate') {
        raise SqlError(
            'Scalar subquery requires one column and a proven at-most-one row'
        );
    }
    actual = q.schema.find(key.name);
    if not same_type(actual.dtype, key.dtype) or actual.dtype.nullable {
        raise SqlError('Scalar key must match its non-null output column');
    }
    return ScalarExpr(
        ScalarNode(dtype=DataType(actual.dtype.name, True), query=q, require_one=False)
    );
}

impl scalar_one[R, T](query: Relation[R, ExactlyOne], key: Field[T]) -> ScalarExpr[T] {
    q = query.ast;
    if q.cardinality != 'exactly_one_aggregate' or len(q.schema.fields) != 1 {
        raise SqlError('scalar_one requires exactly one row and column');
    }
    actual = q.schema.find(key.name);
    if not same_type(actual.dtype, key.dtype) {
        raise SqlError('Scalar output key mismatch');
    }
    return ScalarExpr(ScalarNode(dtype=actual.dtype, query=q, require_one=True));
}

impl exists[R, C](query: Relation[R, C]) -> ScalarExpr[SqlBool] {
    return ScalarExpr(ExistsNode(dtype=DataType('boolean'), query=query.ast));
}

impl union_all[R, C, D](
    left: Relation[R, C], right: Relation[R, D]
) -> Relation[R, Many] {
    a = left.ast.schema.fields;
    b = right.ast.schema.fields;
    if len(a) != len(b)
        or not all([x.dtype.name == y.dtype.name for (x, y) in zip(a, b)]) {
        raise SqlError('UNION requires matching column counts, types and nullability');
    }
    return Relation(
        UnionNode(
            cardinality='many', left=left.ast, right=right.ast, keep_duplicates=True
        )
    );
}

impl cte[R, C](query: Relation[R, C], materialized: bool | None = None) -> Cte {
    binding = CteBinding();
    binding.bind(query.ast, False);
    return Cte(binding=binding, alias='', materialized=materialized);
}

impl cte_ref(fields: list[FieldDef]) -> Cte {
    return Cte(binding=CteBinding(), declared_schema=Schema(tuple(fields)), alias='');
}

impl define_cte[R, C](
    reference: Cte, query: Relation[R, C], recursive: bool = False
) -> Cte {
    if reference.definition is not None {
        raise SqlError('CTE reference is already defined');
    }
    if not _schema_equal(reference.schema, query.ast.schema, False) {
        raise SqlError('CTE output schema differs from declared schema');
    }
    reference.binding.bind(query.ast, recursive);
    return reference;
}


impl validate_identifier(name: str) {
    if not isinstance(name, str) or not name or '\x00' in name {
        raise SqlError('Identifier must be a nonempty string without NUL');
    }
}

impl quote_identifier(name: str) -> str {
    validate_identifier(name);
    return '"' + name.replace('"', '""') + '"';
}


impl _key(source: Source, name: str) -> str {
    return str(id(source)) + ':' + name;
}

impl _schema_equal(a: Schema, b: Schema, names: bool = True) -> bool {
    if len(a.fields) != len(b.fields) {
        return False;
    }
    return all(
        [
            same_type(x.dtype, y.dtype) and (not names or x.name == y.name)
            for (x, y) in zip(a.fields, b.fields)
        ]
    );
}

impl validate_union(ast: UnionNode) {
    ast.schema;
    if ast.cardinality != 'many' or type(ast.keep_duplicates) is not bool {
        raise SqlError('UNION schema/cardinality mismatch');
    }
}

impl QueryGraph.visit_source(src: Source) -> None {
    if isinstance(src, CteUse) {
        self.visit_source(src.target);
        return;
    }
    if isinstance(src, Cte) {
        if id(src) not in self.bound_ctes and not `any([c is src for c in self.ctes]) {
            self.ctes.append(src);
        }
        return;
    }
    identity = id(src);
    if identity in self.seen_sources {
        return;
    }
    self.seen_sources.add(identity);
    if isinstance(src, Table) {
        if src.name {
            self.physical_names.add(src.name[-1]);
        }
        if src.alias {
            self.explicit_aliases.add(src.alias);
        }
    } elif isinstance(src, Derived) {
        self.visit_query(src.query);
    } elif isinstance(src, NullableSource) {
        self.visit_source(src.target);
    } elif isinstance(src, FunctionSource) {
        self.visit_expr(src.argument);
    } else {
        raise SqlError('Unknown SQL source ast');
    }
}

impl QueryGraph.collect(query: RelationNode) {
    self.visit_query(query);
    index = 0;
    while index < len(self.ctes) {
        reference = self.ctes[index];
        if reference.definition is None {
            raise SqlError('CTE reference has no definition');
        }
        self.visit_query(reference.definition);
        index += 1;
    }
}

impl QueryGraph.visit_expr(expr: ExprNode) -> None {
    if not isinstance(expr, ExprNode) {
        raise SqlError('Expected a scalar SQL expression');
    }
    if id(expr) in self.seen_expressions {
        return;
    }
    self.seen_expressions.add(id(expr));
    if isinstance(expr, SlotNode) {
        _validate_slot_name(expr.name);
        if expr.name in self.slot_types
            and not same_type(self.slot_types[expr.name], expr.dtype) {
            raise SqlError('Conflicting types for parameter slot: ' + expr.name);
        }
        self.slot_types[expr.name] = expr.dtype;
    }
    if isinstance(expr, ColumnNode) {
        self.visit_source(expr.source);
    } elif isinstance(expr, (ScalarNode, ExistsNode)) {
        self.visit_query(expr.query);
    } else {
        for child in _children(expr) {
            self.visit_expr(child);
        }
    }
}

impl QueryGraph.visit_query(query: RelationNode) -> None {
    if not isinstance(query, RelationNode) {
        raise SqlError('Expected a relation ast');
    }
    identity = id(query);
    if identity in self.active_queries {
        raise SqlError('Cyclic AST: use a recursive CTE reference');
    }
    if identity in self.seen_queries {
        return;
    }
    self.active_queries.add(identity);
    try {
        if isinstance(query, SelectNode) {
            if query.source is not None {
                self.visit_source(query.source);
            }
            for join in query.joins {
                self.visit_source(join.source);
                if join.condition is not None {
                    self.visit_expr(join.condition);
                }
            }
            for projection in query.projections {
                self.visit_expr(projection.expr);
            }
            for expr in query.groups {
                self.visit_expr(expr);
            }
            if query.predicate is not None {
                self.visit_expr(query.predicate);
            }
            if query.having is not None {
                self.visit_expr(query.having);
            }
            for e in query.distinct_on {
                self.visit_expr(e);
            }
            for ordering in query.ordering {
                self.visit_expr(ordering.expr);
            }
        } elif isinstance(query, UnionNode) {
            self.visit_query(query.left);
            self.visit_query(query.right);
        } elif isinstance(query, WithNode) {
            previous = self.bound_ctes;
            self.bound_ctes = previous | {id(c) for c in query.bindings};
            try {
                for c in query.bindings {
                    if c.definition is None {
                        raise SqlError('CTE reference has no definition');
                    }
                    self.visit_query(c.definition);
                }
                self.visit_query(query.body);
            } finally {
                self.bound_ctes = previous;
            }
        } elif isinstance(query, OrderedNode) {
            self.visit_query(query.body);
        } elif isinstance(query, ValuesNode) {
            for row in query.rows {
                for e in row {
                    self.visit_expr(e);
                }
            }
        } else {
            raise SqlError('Unknown relational ast');
        }
    } finally {
        self.active_queries.remove(identity);
    }
    self.seen_queries.add(identity);
}


impl QueryValidator.fresh_name(prefix: str) -> str {
    while True {
        index = self.cte_counter if prefix == '_cte' else self.alias_counter;
        if prefix == '_cte' {
            self.cte_counter += 1;
        } else {
            self.alias_counter += 1;
        }
        name = prefix + str(index);
        if name not in self.used_names {
            self.used_names.add(name);
            return name;
        }
    }
}

impl QueryValidator.alias_for(src: Source) -> str {
    if isinstance(src, Table) and src.alias {
        validate_identifier(src.alias);
        self.aliases[id(src)] = src.alias;
        return src.alias;
    }
    if src.alias {
        raise SqlError('Temporary source aliases are renderer-managed');
    }
    identity = id(src);
    if identity not in self.aliases {
        self.aliases[identity] = self.fresh_name('_t');
    }
    return self.aliases[identity];
}

impl QueryValidator.order_cte(reference: Cte) -> None {
    identity = id(reference);
    state = self.cte_states.get(identity, 0);
    if state == 2 {
        return;
    }
    if state == 1 {
        raise SqlError('Mutually dependent CTE definitions are unsupported');
    }
    if reference.definition is None {
        raise SqlError('CTE reference has no definition');
    }
    self.cte_states[identity] = 1;
    scan = QueryGraph();
    scan.visit_query(reference.definition);
    for dependency in scan.ctes {
        if dependency is reference {
            if not reference.recursive {
                raise SqlError('Self-reference requires a recursive CTE definition');
            }
        } else {
            self.order_cte(dependency);
        }
    }
    self.cte_states[identity] = 2;
    self.ordered_ctes.append(reference);
}

impl QueryValidator.analyze[R, C](query: Relation[R, C]) -> ValidatedQuery {
    if not isinstance(query, Relation) {
        raise SqlError('Expected a relation, not a scalar or command');
    }
    self.expression_cache = {};
    self.query_cache = {};
    self.cte_cache = {};
    self.active_queries = set();
    self.aliases = {};
    self.cte_names = {};
    self.used_names = set();
    self.ordered_ctes = [];
    self.cte_states = {};
    self.local_orders = {};
    self.alias_counter = 0;
    self.cte_counter = 0;
    scan = QueryGraph();
    scan.collect(query.ast);
    self.used_names = scan.physical_names | scan.explicit_aliases;
    for reference in scan.ctes {
        self.order_cte(reference);
    }
    for reference in self.ordered_ctes {
        self.cte_names[id(reference)] = self.fresh_name('_cte');
    }
    available: list[Cte] = [];
    for reference in self.ordered_ctes {
        self.validate_cte(reference, [], available);
        available.append(reference);
    }
    facts = self.query(query.ast, [], available);
    if facts.external {
        raise SqlError('Top-level query has unbound correlations');
    }
    return ValidatedQuery(
        query=query.ast,
        slots=tuple(scan.slot_types.items()),
        ctes=tuple(self.ordered_ctes),
        aliases=dict(self.aliases),
        cte_names=dict(self.cte_names),
        local_orders=dict(self.local_orders)
    );
}

impl QueryValidator.source(
    src: Source,
    ctes: list[Cte],
    outer: list[Source] = [],
    lateral_scope: list[Source] = []
) -> set[str] {
    self.alias_for(src);
    if isinstance(src, NullableSource) {
        return self.source(src.target, ctes, outer, lateral_scope);
    }
    if isinstance(src, Table) {
        if not src.name {
            raise SqlError('Table needs a name');
        }
        for name in src.name {
            validate_identifier(name);
        }
        return set();
    }
    if isinstance(src, Derived) {
        q = self.query(src.query, lateral_scope if src.lateral else outer, ctes);
        return q.external;
    }
    if isinstance(src, FunctionSource) {
        if src.argument.dtype.name != src.element.dtype.name + '[]'
            or src.element.dtype.nullable {
            raise SqlError('UNNEST element type mismatch');
        }
        if src.ordinality is not None
            and not same_type(src.ordinality.dtype, DataType('bigint')) {
            raise SqlError('Invalid ordinality type');
        }
        Schema(tuple(src.schema.fields));
        result = self.expr(src.argument, lateral_scope, lateral_scope, ctes);
        if result.aggregate or result.window {
            raise SqlError('Table function cannot contain an aggregate or window');
        }
        return result.free;
    }
    if isinstance(src, (Cte, CteUse)) {
        reference = src.target if isinstance(src, CteUse) else src;
        if not `any([x is reference for x in ctes]) {
            raise SqlError('CTE reference is outside scope');
        }
        return set();
    }
    raise SqlError('Unknown SQL source ast');
}

impl QueryValidator.expr_uncached(
    ast: ExprNode, scope: list[Source], local: list[Source], ctes: list[Cte]
) -> Checked {
    if not isinstance(ast, ExprNode) {
        raise SqlError('Expected a scalar SQL expression');
    }
    DataType(ast.dtype.name, ast.dtype.nullable);
    if isinstance(ast, ColumnNode) {
        if not `any([s is ast.source for s in scope]) {
            raise SqlError(f'Column source is outside scope: {ast.name}');
        }
        actual = ast.source.schema.find(ast.name);
        if not same_type(actual.dtype, ast.dtype) {
            raise SqlError('Column type differs from source schema');
        }
        return Checked(free={_key(ast.source, ast.name)});
    }
    if isinstance(ast, SlotNode) {
        _validate_slot_name(ast.name);
        return Checked(free=set());
    }
    if isinstance(ast, ParamNode) {
        validate_value(ast.dtype, ast.value);
        return Checked(free=set());
    }
    if isinstance(ast, BinaryNode) {
        a = self.expr(ast.left, scope, local, ctes);
        b = self.expr(ast.right, scope, local, ctes);
        if ast.left.dtype.name != ast.right.dtype.name {
            raise SqlError('Binary operands have different SQL types');
        }
        if ast.op in ('=', '<>', '<', '<=', '>', '>=') {
            if ast.op not in ('=', '<>')
                and ast.left.dtype.name
                    not in (
                        'integer',
                        'bigint',
                        'numeric',
                        'double precision',
                        'text',
                        'uuid'
                    ) {
                raise SqlError('Unsupported ordered comparison');
            }
            if ast.dtype.name != 'boolean'
                or (
                    (ast.left.dtype.nullable or ast.right.dtype.nullable)
                    and not ast.dtype.nullable
                ) {
                raise SqlError('Invalid comparison result type');
            }
        } elif ast.op in ('+', '-') {
            if not same_type(ast.left.dtype, DataType('bigint'))
                or not same_type(ast.right.dtype, DataType('bigint'))
                or not same_type(ast.dtype, DataType('bigint')) {
                raise SqlError('Arithmetic requires non-null int64');
            }
        } else {
            raise SqlError('Unsupported binary operator');
        }
        return _merge_checked([a, b]);
    }
    if isinstance(ast, BoolNode) {
        if ast.op not in ('AND', 'OR')
            or not ast.terms
            or ast.dtype.name != 'boolean'
            or not all(
                [
                    t.dtype.name == 'boolean'
                        and (not t.dtype.nullable or ast.dtype.nullable)
                    for t in ast.terms
                ]
            ) {
            raise SqlError('Invalid boolean ast');
        }
        return _merge_checked([self.expr(t, scope, local, ctes) for t in ast.terms]);
    }
    if isinstance(ast, UnaryNode) {
        term = self.expr(ast.term, scope, local, ctes);
        if ast.op == 'NOT' {
            if ast.term.dtype.name != 'boolean'
                or not same_type(ast.term.dtype, ast.dtype) {
                raise SqlError('Invalid NOT signature');
            }
        } elif ast.op in ('IS NULL', 'IS NOT NULL') {
            if not ast.term.dtype.nullable
                or not same_type(ast.dtype, DataType('boolean')) {
                raise SqlError('Invalid null-test signature');
            }
        } else {
            raise SqlError('Unsupported unary operator');
        }
        return term;
    }
    if isinstance(ast, CastNode) {
        term = self.expr(ast.term, scope, local, ctes);
        if not _cast_allowed(ast.term.dtype, ast.dtype) {
            raise SqlError('Unsupported SQL cast');
        }
        if ast.term.dtype.nullable and not ast.dtype.nullable {
            raise SqlError('CAST cannot remove nullability');
        }
        return Checked(free=term.free, aggregate=term.aggregate, window=term.window);
    }
    if isinstance(ast, AggregateNode) {
        if not same_type(ast.dtype, _aggregate_type(ast)) {
            raise SqlError('Invalid aggregate result type');
        }
        terms = [self.expr(e, scope, local, ctes) for e in _children(ast)];
        if `any([t.aggregate or t.window for t in terms]) {
            raise SqlError('Nested aggregates/windows require a subquery');
        }
        local_keys = {_key(s, f.name) for s in local for f in s.schema.fields};
        free = _merge_checked(terms).free;
        if not free <= local_keys {
            raise SqlError(
                'Outer-column aggregation requires an explicit query region'
            );
        }
        return Checked(free=set(), aggregate=True);
    }
    if isinstance(ast, CoalesceNode) {
        a = self.expr(ast.term, scope, local, ctes);
        b = self.expr(ast.fallback, scope, local, ctes);
        if not ast.term.dtype.nullable
            or ast.fallback.dtype.nullable
            or ast.term.dtype.name != ast.fallback.dtype.name
            or ast.dtype.name != ast.fallback.dtype.name
            or (ast.fallback.dtype.nullable and not ast.dtype.nullable) {
            raise SqlError('Invalid COALESCE type');
        }
        return _merge_checked([a, b]);
    }
    if isinstance(ast, ScalarNode) {
        q = self.query(ast.query, scope, ctes);
        fields = ast.query.schema.fields;
        allowed = ('exactly_one_aggregate', )
            if ast.require_one
            else ('exactly_one_aggregate', 'at_most_one');
        if len(fields) != 1 or ast.query.cardinality not in allowed {
            raise SqlError('Scalar query cardinality/schema violation');
        }
        expected = fields[0].dtype
            if ast.require_one
            else DataType(fields[0].dtype.name, True);
        if not same_type(expected, ast.dtype) {
            raise SqlError('Scalar query result type mismatch');
        }
        return Checked(free=q.external);
    }
    if isinstance(ast, ExistsNode) {
        q = self.query(ast.query, scope, ctes);
        if not same_type(ast.dtype, DataType('boolean')) {
            raise SqlError('EXISTS returns a non-null boolean');
        }
        return Checked(free=q.external);
    }
    return self.extended_expr(ast, scope, local, ctes);
}

impl QueryValidator.query(
    ast: RelationNode, outer: list[Source], ctes: list[Cte]
) -> QueryFacts {
    if not isinstance(ast, RelationNode) {
        raise SqlError('Expected a relation ast');
    }
    if id(ast) in self.active_queries {
        raise SqlError('Cyclic AST: use a recursive CTE reference');
    }
    key = (id(ast), tuple(id(s) for s in outer), tuple(id(c) for c in ctes));
    if key in self.query_cache {
        return self.query_cache[key];
    }
    self.active_queries.add(id(ast));
    try {
        facts = self.query_body(ast, outer, ctes);
        self.query_cache[key] = facts;
        return facts;
    } finally {
        self.active_queries.remove(id(ast));
    }
}

impl QueryValidator.query_body(
    ast: RelationNode, outer: list[Source], ctes: list[Cte]
) -> QueryFacts {
    if isinstance(ast, SelectNode) {
        return self.select_sql(ast, outer, ctes);
    }
    if isinstance(ast, UnionNode) {
        validate_union(ast);
        a = self.query(ast.left, outer, ctes);
        b = self.query(ast.right, outer, ctes);
        return QueryFacts(external=a.external | b.external);
    }
    if isinstance(ast, ValuesNode) {
        if ast.cardinality != 'many' {
            raise SqlError('Invalid VALUES cardinality');
        }
        if not ast.rows {
            raise SqlError('VALUES requires at least one row');
        }
        external: set[str] = set();
        for row in ast.rows {
            if len(row) != len(ast.schema.fields)
                or not all(
                    [
                        e.dtype.name == f.dtype.name
                            and (not e.dtype.nullable or f.dtype.nullable)
                        for (e, f) in zip(row, ast.schema.fields)
                    ]
                ) {
                raise SqlError('VALUES row schema mismatch');
            }
            for e in row {
                fact = self.expr(e, outer, [], ctes);
                external |= fact.free;
                if fact.aggregate or fact.window {
                    raise SqlError('VALUES cannot contain an aggregate/window');
                }
            }
        }
        return QueryFacts(external=external);
    }
    if isinstance(ast, WithNode) {
        if ast.cardinality != ast.body.cardinality {
            raise SqlError('WITH cardinality differs from body');
        }
        bindings = self.local_bindings(ast.bindings, ctes);
        self.local_orders[id(ast)] = tuple(bindings);
        available = list(ctes);
        free: set[str] = set();
        for reference in bindings {
            if id(reference) not in self.cte_names {
                self.cte_names[id(reference)] = self.fresh_name('_cte');
            }
            free |= self.validate_cte(reference, outer, available);
            available.append(reference);
        }
        facts = self.query(ast.body, outer, available);
        return QueryFacts(external=free | facts.external);
    }
    if isinstance(ast, OrderedNode) {
        if ast.cardinality != 'many' {
            raise SqlError('Invalid ordered-result cardinality');
        }
        if ast.limit is not None and (type(ast.limit) is not int or ast.limit < 0) {
            raise SqlError('Invalid LIMIT');
        }
        for order in ast.ordering {
            _validate_order(order);
            e = order.expr;
            if not isinstance(e, OutputNode)
                or not same_type(ast.schema.find(e.name).dtype, e.dtype) {
                raise SqlError('Set ordering requires a typed output column');
            }
        }
        return self.query(ast.body, outer, ctes);
    }
    raise SqlError('Unknown relational ast');
}

impl QueryValidator.select_sql(
    ast: SelectNode, outer: list[Source], ctes: list[Cte]
) -> QueryFacts {
    ast.schema;
    for projection in ast.projections {
        if not same_type(projection.field.dtype, projection.expr.dtype) {
            raise SqlError(
                f'SELECT projection {projection.field.name}: expression type differs from field'
            );
        }
    }
    if ast.limit is not None and (type(ast.limit) is not int or ast.limit < 0) {
        raise SqlError('Invalid LIMIT');
    }
    if ast.cardinality == 'at_most_one' and ast.limit != 1 {
        raise SqlError('At-most-one proof requires LIMIT 1');
    }
    if ast.cardinality not in ('many', 'at_most_one', 'exactly_one_aggregate') {
        raise SqlError('Unknown cardinality proof');
    }
    local: list[Source] = [];
    used_aliases: set[str] = set();
    all_free: set[str] = set();
    if ast.source is not None {
        local.append(ast.source);
        used_aliases.add(self.alias_for(ast.source));
        all_free |= self.source(ast.source, ctes, outer, outer);
    } elif ast.joins {
        raise SqlError('JOIN requires a FROM source');
    }
    for join in ast.joins {
        if self.alias_for(join.source) in used_aliases
            or `any([s is join.source for s in local]) {
            raise SqlError('Duplicate source binding/alias');
        }
        if join.kind not in ('INNER', 'LEFT', 'CROSS')
            or (join.kind == 'LEFT' and not isinstance(join.source, NullableSource)) {
            raise SqlError('LEFT JOIN requires an optional source');
        }
        all_free |= self.source(join.source, ctes, outer, local + outer);
        local.append(join.source);
        used_aliases.add(self.alias_for(join.source));
        if join.kind == 'CROSS' {
            if join.condition is not None {
                raise SqlError('CROSS JOIN has no ON predicate');
            }
        } else {
            if join.condition is None {
                raise SqlError('JOIN requires an ON predicate');
            }
            condition = self.expr(join.condition, local + outer, local, ctes);
            if join.condition.dtype.name != 'boolean'
                or condition.aggregate
                or condition.window {
                raise SqlError(
                    'JOIN ON requires a non-aggregate, non-window predicate'
                );
            }
            all_free |= condition.free;
        }
    }
    if `any([self.alias_for(s) in used_aliases for s in outer]) {
        raise SqlError('Nested alias shadows a correlated source');
    }
    scope = local + outer;
    projected = [self.expr(p.expr, scope, local, ctes) for p in ast.projections];
    groups = [self.expr(g, scope, local, ctes) for g in ast.groups];
    if `any([g.aggregate or g.window for g in groups]) {
        raise SqlError('GROUP BY cannot contain an aggregate');
    }

    if `any([not isinstance(g, ColumnNode) for g in ast.groups]) {
        raise SqlError('GROUP BY currently accepts column expressions');
    }
    grouped: set[str] = set();
    for g in groups {
        grouped |= g.free;
    }
    if ast.predicate is not None {
        pred = self.expr(ast.predicate, scope, local, ctes);
        if ast.predicate.dtype.name != 'boolean' or pred.aggregate or pred.window {
            raise SqlError('WHERE requires a non-aggregate boolean');
        }
        all_free |= pred.free;
    }
    having: Checked | None = None;
    if ast.having is not None {
        having = self.expr(ast.having, scope, local, ctes);
        if ast.having.dtype.name != 'boolean' or having.window {
            raise SqlError('HAVING requires a boolean');
        }
    }
    for order in ast.ordering {
        _validate_order(order);
    }
    distinct = [self.expr(e, scope, local, ctes) for e in ast.distinct_on];
    if ast.distinct and ast.distinct_on {
        raise SqlError('DISTINCT and DISTINCT ON are mutually exclusive');
    }
    if ast.distinct_on and ast.ordering {
        keys = [_expr_key(e) for e in ast.distinct_on];
        prefix = [_expr_key(o.expr) for o in ast.ordering[:len(keys)]];
        if not all([key in keys for key in prefix])
            or (
                len(prefix) == len(keys) and not all([key in prefix for key in keys])
            ) {
            raise SqlError('DISTINCT ON must match the leading ORDER BY expressions');
        }
    }
    if ast.distinct {
        if not all(
            [
                `any([_expr_key(o.expr) == _expr_key(p.expr) for p in ast.projections])
                for o in ast.ordering
            ]
        ) {
            raise SqlError('DISTINCT ordering expressions must be projected');
        }
    }
    ordered = [self.expr(o.expr, scope, local, ctes) for o in ast.ordering];
    checked = projected + ordered + distinct + ([having] if having is not None else []);
    is_aggregate = bool(groups)
        or having is not None
        or `any([v.aggregate for v in checked]);
    if ast.cardinality == 'exactly_one_aggregate'
        and (
            groups
            or ast.having is not None
            or ast.limit is not None
            or not `any([v.aggregate for v in projected])
        ) {
        raise SqlError(
            'Exactly-one aggregate proof requires an ungrouped, unfiltered aggregate result'
        );
    }
    local_keys = {_key(s, f.name) for s in local for f in s.schema.fields};
    for v in checked {
        all_free |= v.free;
        if is_aggregate and not (v.free & local_keys) <= grouped {
            raise SqlError('Non-aggregate column is missing from GROUP BY');
        }
    }
    for g in groups {
        all_free |= g.free;
    }
    return QueryFacts(external=all_free - local_keys);
}


impl PostgresRenderer.alias_for(src: Source) -> str {
    return quote_identifier(self.aliases[id(src)]);
}

impl PostgresRenderer.render(plan: ValidatedQuery) -> CompiledSQL {
    self.params = {};
    self.parameter_ids = {};
    self.slot_types = dict(plan.slots);
    self.aliases = plan.aliases;
    self.cte_names = plan.cte_names;
    self.local_orders = plan.local_orders;

    body = plan.query;
    bindings = list(plan.ctes);
    while isinstance(body, WithNode) {
        bindings.extend(self.local_orders[id(body)]);
        body = body.body;
    }
    prefix = self.with_sql(tuple(bindings), '');
    return CompiledSQL(
        sql=prefix + self.query(body), params=dict(self.params), slots=plan.slots
    );
}

impl PostgresRenderer.source(src: Source) -> str {
    base = self.source_body(src);
    target = src.target if isinstance(src, NullableSource) else src;
    columns = '';
    if isinstance(target, FunctionSource)
        or (isinstance(target, Derived) and isinstance(target.query, ValuesNode)) {
        columns = ' ('
            + ', '.join([quote_identifier(f.name) for f in src.schema.fields])
            + ')';
    }
    return base + ' AS ' + self.alias_for(src) + columns;
}

impl PostgresRenderer.expr(ast: ExprNode) -> str {
    if isinstance(ast, ColumnNode) {
        return self.alias_for(ast.source) + '.' + quote_identifier(ast.name);
    }
    if isinstance(ast, SlotNode) {
        return 'CAST(:' + ast.name + ' AS ' + ast.dtype.name + ')';
    }
    if isinstance(ast, ParamNode) {
        identity = id(ast);
        if identity not in self.parameter_ids {
            index = len(self.params);
            key = 'p' + str(index);
            while key in self.slot_types or key in self.params {
                index += 1;
                key = 'p' + str(index);
            }
            self.parameter_ids[identity] = key;
            self.params[key] = ast.value;
        }
        return 'CAST(:' + self.parameter_ids[identity] + ' AS ' + ast.dtype.name + ')';
    }
    if isinstance(ast, BinaryNode) {
        return '('
            + self.expr(ast.left)
            + ' '
            + ast.op
            + ' '
            + self.expr(ast.right)
            + ')';
    }
    if isinstance(ast, BoolNode) {
        return '(' + (' ' + ast.op + ' ').join([self.expr(t) for t in ast.terms]) + ')';
    }
    if isinstance(ast, UnaryNode) {
        return '(NOT ' + self.expr(ast.term) + ')'
            if ast.op == 'NOT'
            else '(' + self.expr(ast.term) + ' ' + ast.op + ')';
    }
    if isinstance(ast, CastNode) {
        return 'CAST(' + self.expr(ast.term) + ' AS ' + ast.dtype.name + ')';
    }
    if isinstance(ast, AggregateNode) {
        return 'COUNT(*)'
            if ast.term is None
            else ast.op
                + '('
                + ('DISTINCT ' if ast.distinct else '')
                + self.expr(ast.term)
                + (', ' + self.expr(ast.delimiter) if ast.delimiter is not None else '')
                + ')';
    }
    if isinstance(ast, CoalesceNode) {
        return 'COALESCE(' + self.expr(ast.term) + ', ' + self.expr(ast.fallback) + ')';
    }
    if isinstance(ast, ScalarNode) {
        return '(' + self.query(ast.query) + ')';
    }
    if isinstance(ast, ExistsNode) {
        return 'EXISTS (' + self.query(ast.query) + ')';
    }
    return self.extended_expr(ast);
}

impl PostgresRenderer.query(ast: RelationNode) -> str {
    if isinstance(ast, UnionNode) {
        op = ' ' + ast.operation + (' ALL ' if ast.keep_duplicates else ' ');
        return 'SELECT * FROM ('
            + self.query(ast.left)
            + ') AS "_union_l"'
            + op
            + 'SELECT * FROM ('
            + self.query(ast.right)
            + ') AS "_union_r"';
    }
    if isinstance(ast, WithNode) {
        body = ast.body;
        bindings = list(self.local_orders[id(ast)]);
        while isinstance(body, WithNode) {
            bindings.extend(self.local_orders[id(body)]);
            body = body.body;
        }
        prefix = self.with_sql(tuple(bindings), '');
        return prefix + self.query(body);
    }
    if isinstance(ast, ValuesNode) {
        return 'SELECT * FROM (VALUES '
            + ', '.join(
                ['(' + ', '.join([self.expr(e) for e in row]) + ')' for row in ast.rows]
            )
            + ') AS "_values" ('
            + ', '.join([quote_identifier(f.name) for f in ast.schema.fields])
            + ')';
    }
    if isinstance(ast, OrderedNode) {
        return 'SELECT * FROM ('
            + self.query(ast.body)
            + ') AS "_set" ('
            + ', '.join([quote_identifier(f.name) for f in ast.schema.fields])
            + ')'
            + (' ORDER BY ' + self.ordering(ast.ordering) if ast.ordering else '')
            + (' LIMIT ' + str(ast.limit) if ast.limit is not None else '');
    }
    if not isinstance(ast, SelectNode) {
        raise SqlError('Unvalidated relation');
    }
    from_sql = '';
    if ast.source is not None {
        from_sql = ' FROM ' + self.source(ast.source);
    }
    for join in ast.joins {
        condition = self.expr(join.condition) if join.condition is not None else '';
        from_sql += ' '
            + join.kind
            + ' JOIN '
            + self.source(join.source)
            + (' ON ' + condition if join.kind != 'CROSS' else '');
    }
    projected = [
        self.expr(p.expr) + ' AS ' + quote_identifier(p.field.name)
        for p in ast.projections
    ];
    groups = [self.expr(g) for g in ast.groups];
    predicate = ' WHERE ' + self.expr(ast.predicate)
        if ast.predicate is not None
        else '';
    having = ' HAVING ' + self.expr(ast.having) if ast.having is not None else '';
    ordering = self.ordering(ast.ordering);
    distinct = 'DISTINCT '
        if ast.distinct
        else (
            'DISTINCT ON (' + ', '.join([self.expr(e) for e in ast.distinct_on]) + ') '
                if ast.distinct_on
                else ''
        );
    return 'SELECT '
        + distinct
        + ', '.join(projected)
        + from_sql
        + predicate
        + (' GROUP BY ' + ', '.join(groups) if groups else '')
        + having
        + (' ORDER BY ' + ordering if ordering else '')
        + (' LIMIT ' + str(ast.limit) if ast.limit is not None else '');
}


impl compile_sql[R, C](query: Relation[R, C]) -> CompiledSQL {
    plan = QueryValidator().analyze(query);
    return PostgresRenderer().render(plan);
}


impl validate_recursive_step(ref: Cte, step: RelationNode) {
    if _recursive_count(step, ref) != 1 {
        raise SqlError('Recursive step requires exactly one structural self-reference');
    }
}

impl int32_type -> SqlType[SqlInt32] {
    return SqlType(DataType('integer'));
}

impl numeric_type -> SqlType[SqlNumeric] {
    return SqlType(DataType('numeric'));
}

impl array_type[T](element: SqlType[T]) -> SqlType[SqlArray[T]] {
    if element.data.nullable or element.data.name.endswith('[]') {
        raise SqlError('Array element contract requires a non-null scalar type');
    }
    return SqlType(DataType(element.data.name + '[]'));
}

impl int32(value: int) -> ScalarExpr[SqlInt32] {
    return param(int32_type(), value);
}

impl numeric(value: Decimal | int) -> ScalarExpr[SqlNumeric] {
    return param(numeric_type(), value);
}

impl array_param[T](
    element: SqlType[T], values: list[bool | int | float | str | UUID | Decimal | None]
) -> ScalarExpr[SqlArray[T]] {
    return param(array_type(element), tuple(values));
}

impl array[T](
    element: SqlType[T], items: list[ScalarExpr[T]]
) -> ScalarExpr[SqlArray[T]] {
    dtype = array_type(element).data;
    if not all([same_type(x.ast.dtype, element.data) for x in items]) {
        raise SqlError('Array element type mismatch');
    }
    return ScalarExpr(ArrayNode(dtype=dtype, items=tuple(x.ast for x in items)));
}

impl array_concat[T](
    left: ScalarExpr[SqlArray[T]], right: ScalarExpr[SqlArray[T]]
) -> ScalarExpr[SqlArray[T]] {
    return ScalarExpr(_call('ARRAY_CONCAT', (left.ast, right.ast)));
}

impl array_append[T](
    left: ScalarExpr[SqlArray[T]], right: ScalarExpr[T]
) -> ScalarExpr[SqlArray[T]] {
    return ScalarExpr(_call('ARRAY_APPEND', (left.ast, right.ast)));
}

impl any_eq[T](
    term: ScalarExpr[T], values: ScalarExpr[SqlArray[T]]
) -> ScalarExpr[Nullable[SqlBool]] {
    if values.ast.dtype.name != term.ast.dtype.name + '[]' {
        raise SqlError('ANY element type mismatch');
    }
    return ScalarExpr(
        AnyNode(dtype=DataType('boolean', True), term=term.ast, array=values.ast)
    );
}

impl compare_nullable[T](
    left: ScalarExpr[T] | ScalarExpr[Nullable[T]],
    right: ScalarExpr[T] | ScalarExpr[Nullable[T]],
    op: str = '='
) -> ScalarExpr[Nullable[SqlBool]] {
    if op not in ('=', '<>', '<', '<=', '>', '>=')
        or left.ast.dtype.name != right.ast.dtype.name {
        raise SqlError('Invalid nullable comparison');
    }
    return ScalarExpr(
        BinaryNode(
            dtype=DataType('boolean', True), op=op, left=left.ast, right=right.ast
        )
    );
}

impl or_(terms: list[ScalarExpr[SqlBool]]) -> ScalarExpr[SqlBool] {
    if not terms
        or not all([same_type(t.ast.dtype, DataType('boolean')) for t in terms]) {
        raise SqlError('OR requires non-null booleans');
    }
    return ScalarExpr(
        BoolNode(dtype=DataType('boolean'), op='OR', terms=tuple(t.ast for t in terms))
    );
}

impl _nullable_boolean(
    op: str, terms: list[ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]]
) -> ScalarExpr[Nullable[SqlBool]] {
    if not terms or not all([t.ast.dtype.name == 'boolean' for t in terms]) {
        raise SqlError('Boolean terms required');
    }
    return ScalarExpr(
        BoolNode(
            dtype=DataType('boolean', True), op=op, terms=tuple(t.ast for t in terms)
        )
    );
}

impl and_nullable(
    terms: list[ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]]
) -> ScalarExpr[Nullable[SqlBool]] {
    return _nullable_boolean('AND', terms);
}

impl or_nullable(
    terms: list[ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]]
) -> ScalarExpr[Nullable[SqlBool]] {
    return _nullable_boolean('OR', terms);
}

impl not_(term: ScalarExpr[SqlBool]) -> ScalarExpr[SqlBool] {
    if not same_type(term.ast.dtype, DataType('boolean')) {
        raise SqlError('NOT requires a boolean');
    }
    return ScalarExpr(UnaryNode(dtype=term.ast.dtype, op='NOT', term=term.ast));
}

impl not_nullable(
    term: ScalarExpr[Nullable[SqlBool]]
) -> ScalarExpr[Nullable[SqlBool]] {
    if not same_type(term.ast.dtype, DataType('boolean', True)) {
        raise SqlError('Nullable NOT requires a nullable boolean');
    }
    return ScalarExpr(UnaryNode(dtype=term.ast.dtype, op='NOT', term=term.ast));
}

impl is_not_null[T](term: ScalarExpr[Nullable[T]]) -> ScalarExpr[SqlBool] {
    return ScalarExpr(
        UnaryNode(dtype=DataType('boolean'), op='IS NOT NULL', term=term.ast)
    );
}

impl in_[T](term: ScalarExpr[T], items: list[ScalarExpr[T]]) -> ScalarExpr[SqlBool] {
    if term.ast.dtype.nullable
        or not all([same_type(term.ast.dtype, x.ast.dtype) for x in items]) {
        raise SqlError('IN requires matching non-null types');
    }
    return ScalarExpr(
        MembershipNode(
            dtype=DataType('boolean'), term=term.ast, items=tuple(x.ast for x in items)
        )
    );
}

impl sub(
    left: ScalarExpr[SqlInt64], right: ScalarExpr[SqlInt64]
) -> ScalarExpr[SqlInt64] {
    if not same_type(left.ast.dtype, DataType('bigint'))
        or not same_type(right.ast.dtype, DataType('bigint')) {
        raise SqlError('Subtraction requires int64 operands');
    }
    return ScalarExpr(
        BinaryNode(dtype=DataType('bigint'), op='-', left=left.ast, right=right.ast)
    );
}

impl numeric_add(
    left: ScalarExpr[SqlNumeric], right: ScalarExpr[SqlNumeric]
) -> ScalarExpr[SqlNumeric] {
    return ScalarExpr(_call('NUMERIC_ADD', (left.ast, right.ast)));
}

impl numeric_sub(
    left: ScalarExpr[SqlNumeric], right: ScalarExpr[SqlNumeric]
) -> ScalarExpr[SqlNumeric] {
    return ScalarExpr(_call('NUMERIC_SUB', (left.ast, right.ast)));
}

impl case_[T](
    branches:
        list[tuple[ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]], ScalarExpr[T]]],
    fallback: ScalarExpr[T]
) -> ScalarExpr[T] {
    if not branches
        or not all(
            [
                cond.ast.dtype.name == 'boolean'
                    and same_type(value.ast.dtype, fallback.ast.dtype)
                for (cond, value) in branches
            ]
        ) {
        raise SqlError('CASE requires boolean conditions and matching result types');
    }
    return ScalarExpr(
        CaseNode(
            dtype=fallback.ast.dtype,
            branches=tuple((c.ast, v.ast) for (c, v) in branches),
            fallback=fallback.ast
        )
    );
}

impl concat(
    terms: list[ScalarExpr[SqlText] | ScalarExpr[Nullable[SqlText]]]
) -> ScalarExpr[SqlText] {
    return ScalarExpr(_call('CONCAT', tuple(t.ast for t in terms)));
}

impl text_concat(
    left: ScalarExpr[SqlText], right: ScalarExpr[SqlText]
) -> ScalarExpr[SqlText] {
    return ScalarExpr(_call('TEXT_CONCAT', (left.ast, right.ast)));
}

impl lpad(
    term: ScalarExpr[SqlText], length: ScalarExpr[SqlInt32], fill: ScalarExpr[SqlText]
) -> ScalarExpr[SqlText] {
    return ScalarExpr(_call('LPAD', (term.ast, length.ast, fill.ast)));
}

impl _call(op: str, args: tuple[ExprNode, ...]) -> ExprNode {
    return CallNode(dtype=_call_type(op, args), op=op, args=args);
}

impl _call_type(op: str, args: tuple[ExprNode, ...]) -> DataType {
    if op == 'CONCAT' and args and all([a.dtype.name == 'text' for a in args]) {
        return DataType('text');
    }
    if op == 'LPAD'
        and len(args) == 3
        and same_type(args[0].dtype, DataType('text'))
        and same_type(args[1].dtype, DataType('integer'))
        and same_type(args[2].dtype, DataType('text')) {
        return DataType('text');
    }
    if op == 'TEXT_CONCAT'
        and len(args) == 2
        and all([same_type(a.dtype, DataType('text')) for a in args]) {
        return DataType('text');
    }
    if op in ('INT32_ADD', 'INT32_SUB')
        and len(args) == 2
        and all([same_type(a.dtype, DataType('integer')) for a in args]) {
        return DataType('integer');
    }
    if op in ('NUMERIC_ADD', 'NUMERIC_SUB')
        and len(args) == 2
        and all([same_type(a.dtype, DataType('numeric')) for a in args]) {
        return DataType('numeric');
    }
    if op in ('ARRAY_CONCAT', 'ARRAY_APPEND') and len(args) == 2 {
        a = args[0].dtype;
        b = args[1].dtype;
        if a.name.endswith('[]')
            and not a.nullable
            and not b.nullable
            and b.name == (a.name if op == 'ARRAY_CONCAT' else a.name[:-2]) {
            return a;
        }
    }
    raise SqlError('Invalid typed SQL function: ' + op);
}

impl _sum(term: ExprNode) -> ExprNode {
    ast = AggregateNode(dtype=DataType('numeric', True), op='SUM', term=term);
    return AggregateNode(dtype=_aggregate_type(ast), op='SUM', term=term);
}

impl sum_int32(term: ScalarExpr[SqlInt32]) -> ScalarExpr[Nullable[SqlInt64]] {
    if term.ast.dtype.name != 'integer' or term.ast.dtype.nullable {
        raise SqlError('Invalid sum_int32 input type');
    }
    return ScalarExpr(_sum(term.ast));
}

impl sum_int64(term: ScalarExpr[SqlInt64]) -> ScalarExpr[Nullable[SqlNumeric]] {
    if term.ast.dtype.name != 'bigint' or term.ast.dtype.nullable {
        raise SqlError('Invalid sum_int64 input type');
    }
    return ScalarExpr(_sum(term.ast));
}

impl sum_numeric(term: ScalarExpr[SqlNumeric]) -> ScalarExpr[Nullable[SqlNumeric]] {
    if term.ast.dtype.name != 'numeric' or term.ast.dtype.nullable {
        raise SqlError('Invalid sum_numeric input type');
    }
    return ScalarExpr(_sum(term.ast));
}

impl bool_and(
    term: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]
) -> ScalarExpr[Nullable[SqlBool]] {
    if term.ast.dtype.name != 'boolean' {
        raise SqlError('BOOL_AND requires a boolean');
    }
    return ScalarExpr(
        AggregateNode(dtype=DataType('boolean', True), op='BOOL_AND', term=term.ast)
    );
}

impl string_agg(
    term: ScalarExpr[SqlText] | ScalarExpr[Nullable[SqlText]],
    delimiter: ScalarExpr[SqlText],
    distinct: bool = False
) -> ScalarExpr[Nullable[SqlText]] {
    ast = AggregateNode(
        dtype=DataType('text', True),
        op='STRING_AGG',
        term=term.ast,
        delimiter=delimiter.ast,
        distinct=distinct
    );
    _aggregate_type(ast);
    return ScalarExpr(ast);
}

impl _aggregate_type(ast: AggregateNode) -> DataType {
    if ast.op == 'COUNT'
        and ast.term is None
        and not ast.distinct
        and ast.delimiter is None {
        return DataType('bigint');
    }
    if ast.term is not None {
        name = ast.term.dtype.name;
        if ast.op == 'SUM'
            and not ast.distinct
            and ast.delimiter is None
            and name in ('integer', 'bigint', 'numeric', 'double precision') {
            return DataType(
                'bigint'
                    if name == 'integer'
                    else ('numeric' if name in ('bigint', 'numeric') else name),
                True
            );
        }
        if ast.op in ('BOOL_AND', 'BOOL_OR')
            and name == 'boolean'
            and not ast.distinct
            and ast.delimiter is None {
            return DataType('boolean', True);
        }
        if ast.op == 'STRING_AGG'
            and name == 'text'
            and ast.delimiter is not None
            and same_type(ast.delimiter.dtype, DataType('text')) {
            return DataType('text', True);
        }
    }
    raise SqlError('Invalid aggregate signature');
}

impl optional_source(source: Source) -> NullableSource {
    return NullableSource(alias='', target=source);
}

impl left_join(
    source: NullableSource, on: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]
) -> Join {
    return Join(source=source, condition=on.ast, kind='LEFT');
}

impl cross_join(source: Source) -> Join {
    return Join(source=source, condition=None, kind='CROSS');
}

impl unnest[T](
    argument: ScalarExpr[SqlArray[T]],
    element: Field[T],
    ordinality: Field[SqlInt64] | None = None
) -> Source {
    if argument.ast.dtype.name != element.dtype.name + '[]' or element.dtype.nullable {
        raise SqlError('UNNEST element type mismatch');
    }
    if ordinality is not None and not same_type(ordinality.dtype, DataType('bigint')) {
        raise SqlError('Ordinality requires int64');
    }
    return FunctionSource(
        alias='', argument=argument.ast, element=element, ordinality=ordinality
    );
}

impl values(
    fields: list[FieldDef], rows: list[list[ScalarExpr]]
) -> Relation[Schema, Many] {
    return Relation(
        ValuesNode(
            cardinality='many',
            declared_schema=Schema(tuple(fields)),
            rows=tuple(tuple(v.ast for v in row) for row in rows)
        )
    );
}

impl union[R, C, D](left: Relation[R, C], right: Relation[R, D]) -> Relation[R, Many] {
    base = union_all(left, right).ast;
    if not isinstance(base, UnionNode) {
        raise SqlError('Expected UNION');
    }
    return Relation(
        UnionNode(
            cardinality='many', left=base.left, right=base.right, keep_duplicates=False
        )
    );
}

impl except_[R, C, D](
    left: Relation[R, C], right: Relation[R, D], all_: bool = False
) -> Relation[R, Many] {
    base = union_all(left, right).ast;
    if not isinstance(base, UnionNode) {
        raise SqlError('Expected UNION');
    }
    return Relation(
        UnionNode(
            cardinality='many',
            left=base.left,
            right=base.right,
            keep_duplicates=all_,
            operation='EXCEPT'
        )
    );
}

impl intersect[R, C, D](
    left: Relation[R, C], right: Relation[R, D], all_: bool = False
) -> Relation[R, Many] {
    base = union_all(left, right).ast;
    if not isinstance(base, UnionNode) {
        raise SqlError('Expected UNION');
    }
    return Relation(
        UnionNode(
            cardinality='many',
            left=base.left,
            right=base.right,
            keep_duplicates=all_,
            operation='INTERSECT'
        )
    );
}

impl output[T](key: Field[T]) -> ScalarExpr[T] {
    return ScalarExpr(OutputNode(dtype=key.dtype, name=key.name));
}

impl ordered[R, C](
    query: Relation[R, C], order_by: list[Order], limit: int | None = None
) -> Relation[R, Many] {
    return Relation(
        OrderedNode(
            cardinality='many', body=query.ast, ordering=tuple(order_by), limit=limit
        )
    );
}

impl with_ctes[R, C](query: Relation[R, C], bindings: list[Cte]) -> Relation[R, C] {
    return Relation(
        WithNode(
            cardinality=query.ast.cardinality, body=query.ast, bindings=tuple(bindings)
        )
    );
}

impl preceding(offset: int) -> FrameBound {
    return FrameBound('PRECEDING', offset);
}

impl following(offset: int) -> FrameBound {
    return FrameBound('FOLLOWING', offset);
}

impl current_row -> FrameBound {
    return FrameBound('CURRENT ROW');
}

impl unbounded_preceding -> FrameBound {
    return FrameBound('UNBOUNDED PRECEDING');
}

impl unbounded_following -> FrameBound {
    return FrameBound('UNBOUNDED FOLLOWING');
}

impl rows_between(start: FrameBound, end: FrameBound) -> WindowFrame {
    result = WindowFrame(start, end);
    _validate_frame(result);
    return result;
}

impl _validate_frame(frame: WindowFrame) {
    if frame.mode != 'ROWS' {
        raise SqlError('Window frame mode must be ROWS');
    }
    for bound in [frame.start, frame.end] {
        if bound.kind
            not in (
                'UNBOUNDED PRECEDING',
                'PRECEDING',
                'CURRENT ROW',
                'FOLLOWING',
                'UNBOUNDED FOLLOWING'
            )
            or type(bound.offset) is not int
            or bound.offset < 0
            or (bound.kind not in ('PRECEDING', 'FOLLOWING') and bound.offset != 0) {
            raise SqlError('Invalid window frame bound');
        }
    }
    if frame.start.kind == 'UNBOUNDED FOLLOWING'
        or frame.end.kind == 'UNBOUNDED PRECEDING' {
        raise SqlError('Invalid window frame endpoints');
    }
    positions = {
        'UNBOUNDED PRECEDING': 0,
        'PRECEDING': 1,
        'CURRENT ROW': 2,
        'FOLLOWING': 3,
        'UNBOUNDED FOLLOWING': 4
    };
    if positions[frame.start.kind] > positions[frame.end.kind] {
        raise SqlError('Invalid window frame endpoint order');
    }
}

impl row_number(
    partition_by: list[ExprNode] = [], order_by: list[Order] = []
) -> ScalarExpr[SqlInt64] {
    return ScalarExpr(
        WindowNode(
            dtype=DataType('bigint'),
            op='ROW_NUMBER',
            term=None,
            partition=tuple(partition_by),
            ordering=tuple(order_by),
            frame=None
        )
    );
}

impl dense_rank(
    partition_by: list[ExprNode] = [], order_by: list[Order] = []
) -> ScalarExpr[SqlInt64] {
    return ScalarExpr(
        WindowNode(
            dtype=DataType('bigint'),
            op='DENSE_RANK',
            term=None,
            partition=tuple(partition_by),
            ordering=tuple(order_by),
            frame=None
        )
    );
}

impl over[T](
    term: ScalarExpr[T],
    partition_by: list[ExprNode] = [],
    order_by: list[Order] = [],
    frame: WindowFrame | None = None
) -> ScalarExpr[T] {
    if not isinstance(term.ast, AggregateNode) {
        raise SqlError('OVER requires an aggregate');
    }
    return ScalarExpr(
        WindowNode(
            dtype=term.ast.dtype,
            op='AGGREGATE',
            term=term.ast,
            partition=tuple(partition_by),
            ordering=tuple(order_by),
            frame=frame
        )
    );
}

impl _children(expr: ExprNode) -> tuple[ExprNode, ...] {
    if isinstance(expr, CallNode) {
        return expr.args;
    }
    if isinstance(expr, CaseNode) {
        return tuple(e for pair in expr.branches for e in pair) + (expr.fallback, );
    }
    if isinstance(expr, ArrayNode) {
        return expr.items;
    }
    if isinstance(expr, MembershipNode) {
        return (expr.term, ) + expr.items;
    }
    if isinstance(expr, AnyNode) {
        return (expr.term, expr.array);
    }
    if isinstance(expr, WindowNode) {
        return ((expr.term, ) if expr.term is not None else ())
            + expr.partition
            + tuple(o.expr for o in expr.ordering);
    }
    if isinstance(expr, BinaryNode) {
        return (expr.left, expr.right);
    }
    if isinstance(expr, BoolNode) {
        return expr.terms;
    }
    if isinstance(expr, (UnaryNode, CastNode)) {
        return (expr.term, );
    }
    if isinstance(expr, AggregateNode) {
        return ((expr.term, ) if expr.term is not None else ())
            + ((expr.delimiter, ) if expr.delimiter is not None else ());
    }
    if isinstance(expr, CoalesceNode) {
        return (expr.term, expr.fallback);
    }
    return ();
}

impl _merge_checked(items: list[Checked]) -> Checked {
    free: set[str] = set();
    for item in items {
        free |= item.free;
    }
    return Checked(
        free=free,
        aggregate=`any([x.aggregate for x in items]),
        window=`any([x.window for x in items])
    );
}

impl _validate_order(order: Order) {
    if order.nulls not in ('', 'FIRST', 'LAST') or type(order.descending) is not bool {
        raise SqlError('Invalid ordering options');
    }
}

impl ne[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool] {
    return _compare(left, right, '<>');
}

impl lt[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool] {
    return _compare(left, right, '<');
}

impl le[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool] {
    return _compare(left, right, '<=');
}

impl ge[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool] {
    return _compare(left, right, '>=');
}

impl QueryValidator.local_bindings(
    bindings: tuple[Cte, ...], available: list[Cte]
) -> list[Cte] {
    if len({id(c) for c in bindings}) != len(bindings)
        or `any([c is prior for c in bindings for prior in available]) {
        raise SqlError('Duplicate CTE binding');
    }
    pending = list(bindings);
    result: list[Cte] = [];
    while pending {
        changed = False;
        for reference in list(pending) {
            if reference.definition is None {
                raise SqlError('CTE reference has no definition');
            }
            scan = QueryGraph();
            scan.visit_query(reference.definition);
            deps = [
                d
                for d in scan.ctes
                if d is not reference
            ];
            if `any(
                [not `any([d is c for c in list(bindings) + available]) for d in deps]
            ) {
                raise SqlError('CTE dependency is outside its lexical scope');
            }
            if all([`any([d is c for c in available + result]) for d in deps]) {
                if `any([d is reference for d in scan.ctes])
                    and not reference.recursive {
                    raise SqlError(
                        'Self-reference requires a recursive CTE definition'
                    );
                }
                result.append(reference);
                pending.remove(reference);
                changed = True;
            }
        }
        if not changed {
            raise SqlError('Mutually dependent CTE definitions are unsupported');
        }
    }
    return result;
}

impl QueryValidator.validate_cte_uncached(
    reference: Cte, outer: list[Source], available: list[Cte]
) -> set[str] {
    definition = reference.definition;
    if definition is None {
        raise SqlError('CTE reference has no definition');
    }
    if reference.materialized is not None
        and type(reference.materialized) is not bool {
        raise SqlError('Invalid materialization option');
    }
    if not _schema_equal(reference.schema, definition.schema, False) {
        raise SqlError('CTE output schema mismatch');
    }
    if reference.recursive {
        if not isinstance(definition, UnionNode) or definition.operation != 'UNION' {
            raise SqlError('Recursive binding requires UNION or UNION ALL');
        }
        validate_union(definition);
        validate_recursive_step(reference, definition.right);
        anchor = self.query(definition.left, outer, available);
        step = self.query(definition.right, outer, available + [reference]);
        return anchor.external | step.external;
    }
    return self.query(definition, outer, available).external;
}

impl QueryValidator.extended_expr(
    ast: ExprNode, scope: list[Source], local: list[Source], ctes: list[Cte]
) -> Checked {
    if isinstance(ast, WindowNode) {
        if ast.op not in ('ROW_NUMBER', 'DENSE_RANK', 'AGGREGATE') {
            raise SqlError('Invalid window function');
        }
        children = [
            self.expr(e, scope, local, ctes)
            for e in ast.partition + tuple(o.expr for o in ast.ordering)
        ];
        if `any([c.window for c in children]) {
            raise SqlError('Window keys cannot contain nested windows');
        }
        for order in ast.ordering {
            _validate_order(order);
        }
        if ast.frame is not None {
            _validate_frame(ast.frame);
        }
        group_facts = _merge_checked(children);
        free = group_facts.free;
        aggregate = group_facts.aggregate;
        if ast.op == 'AGGREGATE' {
            term = ast.term;
            if not isinstance(term, AggregateNode) or term.distinct {
                raise SqlError('Window aggregate requires a non-distinct aggregate');
            }
            if not same_type(ast.dtype, _aggregate_type(term)) {
                raise SqlError('Window aggregate result type mismatch');
            }
            args = [self.expr(e, scope, local, ctes) for e in _children(term)];
            if `any([a.window for a in args]) {
                raise SqlError('Nested windows require another query region');
            }
            argument_facts = _merge_checked(args);
            free |= argument_facts.free;
            aggregate = aggregate or argument_facts.aggregate;
        } elif ast.term is not None or not same_type(ast.dtype, DataType('bigint')) {
            raise SqlError('Invalid ranking window signature');
        }
        return Checked(free=free, aggregate=aggregate, window=True);
    }
    children = [self.expr(e, scope, local, ctes) for e in _children(ast)];
    if isinstance(ast, CallNode) {
        if not same_type(ast.dtype, _call_type(ast.op, ast.args)) {
            raise SqlError('Function result type mismatch');
        }
    } elif isinstance(ast, CaseNode) {
        if not ast.branches
            or ast.dtype.name != ast.fallback.dtype.name
            or (ast.fallback.dtype.nullable and not ast.dtype.nullable)
            or not all(
                [
                    c.dtype.name == 'boolean'
                        and v.dtype.name == ast.dtype.name
                        and (not v.dtype.nullable or ast.dtype.nullable)
                    for (c, v) in ast.branches
                ]
            ) {
            raise SqlError('Invalid CASE signature');
        }
    } elif isinstance(ast, ArrayNode) {
        if not ast.dtype.name.endswith('[]')
            or ast.dtype.nullable
            or not all(
                [same_type(v.dtype, DataType(ast.dtype.name[:-2])) for v in ast.items]
            ) {
            raise SqlError('Invalid array signature');
        }
    } elif isinstance(ast, MembershipNode) {
        if ast.term.dtype.nullable
            or not all([same_type(v.dtype, ast.term.dtype) for v in ast.items])
            or not same_type(ast.dtype, DataType('boolean')) {
            raise SqlError('Invalid IN signature');
        }
    } elif isinstance(ast, AnyNode) {
        if ast.array.dtype.name != ast.term.dtype.name + '[]'
            or not same_type(ast.dtype, DataType('boolean', True)) {
            raise SqlError('Invalid ANY signature');
        }
    } else {
        raise SqlError('Unknown scalar SQL ast');
    }
    return _merge_checked(children);
}

impl PostgresRenderer.ordering(items: tuple[Order, ...]) -> str {
    return ', '.join(
        [
            self.expr(o.expr)
                + (' DESC' if o.descending else ' ASC')
                + (' NULLS ' + o.nulls if o.nulls else '') for o in items
        ]
    );
}

impl PostgresRenderer.with_sql(bindings: tuple[Cte, ...], body: str) -> str {
    if not bindings {
        return body;
    }
    definitions: list[str] = [];
    for reference in bindings {
        definition = reference.definition;
        if isinstance(definition, UnionNode) and reference.recursive {
            step_sql = self.query(definition.right);
            if not isinstance(definition.right, SelectNode)
                or definition.right.ordering
                or definition.right.limit is not None {
                step_sql = 'SELECT * FROM (' + step_sql + ') AS "_recursive_step"';
            }
            sql = 'SELECT * FROM ('
                + self.query(definition.left)
                + ') AS "_recursive_anchor"'
                + (' UNION ALL ' if definition.keep_duplicates else ' UNION ')
                + step_sql;
        } elif definition is not None {
            sql = self.query(definition);
        } else {
            raise SqlError('Unvalidated CTE definition');
        }
        materialization = ''
            if reference.materialized is None
            else ('MATERIALIZED ' if reference.materialized else 'NOT MATERIALIZED ');
        columns = ', '.join(
            [quote_identifier(f.name) for f in reference.schema.fields]
        );
        definitions.append(
            quote_identifier(self.cte_names[id(reference)])
                + ' ('
                + columns
                + ') AS '
                + materialization
                + '('
                + sql
                + ')'
        );
    }
    return 'WITH '
        + ('RECURSIVE ' if `any([c.recursive for c in bindings]) else '')
        + ', '.join(definitions)
        + ' '
        + body;
}

impl PostgresRenderer.source_body(src: Source) -> str {
    if isinstance(src, NullableSource) {
        return self.source_body(src.target);
    }
    if isinstance(src, Table) {
        return '.'.join([quote_identifier(p) for p in src.name]);
    }
    if isinstance(src, Derived) {
        return ('LATERAL ' if src.lateral else '') + '(' + self.query(src.query) + ')';
    }
    if isinstance(src, FunctionSource) {
        return 'unnest('
            + self.expr(src.argument)
            + ')'
            + (' WITH ORDINALITY' if src.ordinality is not None else '');
    }
    if isinstance(src, (Cte, CteUse)) {
        reference = src.target if isinstance(src, CteUse) else src;
        return quote_identifier(self.cte_names[id(reference)]);
    }
    raise SqlError('Unvalidated SQL source');
}

impl PostgresRenderer.extended_expr(ast: ExprNode) -> str {
    if isinstance(ast, CallNode) {
        args = [self.expr(e) for e in ast.args];
        if ast.op
            in (
                'ARRAY_CONCAT',
                'ARRAY_APPEND',
                'TEXT_CONCAT',
                'NUMERIC_ADD',
                'NUMERIC_SUB',
                'INT32_ADD',
                'INT32_SUB'
            ) {
            op = '+'
                if ast.op in ('NUMERIC_ADD', 'INT32_ADD')
                else ('-' if ast.op in ('NUMERIC_SUB', 'INT32_SUB') else '||');
            return '(' + args[0] + ' ' + op + ' ' + args[1] + ')';
        }
        return ast.op + '(' + ', '.join(args) + ')';
    }
    if isinstance(ast, CaseNode) {
        return '(CASE '
            + ' '.join(
                [
                    'WHEN ' + self.expr(c) + ' THEN ' + self.expr(v)
                    for (c, v) in ast.branches
                ]
            )
            + ' ELSE '
            + self.expr(ast.fallback)
            + ' END)';
    }
    if isinstance(ast, ArrayNode) {
        return 'CAST(ARRAY['
            + ', '.join([self.expr(e) for e in ast.items])
            + '] AS '
            + ast.dtype.name
            + ')';
    }
    if isinstance(ast, MembershipNode) {
        values = ', '.join([self.expr(e) for e in ast.items])
            if ast.items
            else 'SELECT CAST(NULL AS ' + ast.term.dtype.name + ') WHERE FALSE';
        return '(' + self.expr(ast.term) + ' IN (' + values + '))';
    }
    if isinstance(ast, AnyNode) {
        return '(' + self.expr(ast.term) + ' = ANY(' + self.expr(ast.array) + '))';
    }
    if isinstance(ast, OutputNode) {
        return quote_identifier(ast.name);
    }
    if isinstance(ast, WindowNode) {
        fn = self.expr(ast.term) if ast.term is not None else ast.op + '()';
        parts: list[str] = [];
        if ast.partition {
            parts.append(
                'PARTITION BY ' + ', '.join([self.expr(e) for e in ast.partition])
            );
        }
        if ast.ordering {
            parts.append('ORDER BY ' + self.ordering(ast.ordering));
        }
        if ast.frame is not None {
            bounds: list[str] = [];
            for b in [ast.frame.start, ast.frame.end] {
                bounds.append(
                    (
                        str(b.offset) + ' '
                            if b.kind in ('PRECEDING', 'FOLLOWING')
                            else ''
                    )
                        + b.kind
                );
            }
            parts.append(
                ast.frame.mode + ' BETWEEN ' + bounds[0] + ' AND ' + bounds[1]
            );
        }
        return fn + ' OVER (' + ' '.join(parts) + ')';
    }
    raise SqlError('Unvalidated expression');
}

impl _source_recursive_count(source: Source, ref: Cte) -> int {
    if source is ref or (isinstance(source, CteUse) and source.target is ref) {
        return 1;
    }
    if isinstance(source, Derived) {
        return _recursive_count(source.query, ref);
    }
    if isinstance(source, FunctionSource) {
        _scan_recursive_expr(source.argument, ref);
    }
    if isinstance(source, NullableSource) {
        count = _source_recursive_count(source.target, ref);
        if count {
            raise SqlError(
                'Recursive reference cannot occur on the nullable side of an outer join'
            );
        }
    }
    return 0;
}

impl _scan_recursive_expr(expr: ExprNode, ref: Cte) {
    if isinstance(expr, (ScalarNode, ExistsNode)) {
        if _recursive_count(expr.query, ref) {
            raise SqlError('Recursive reference cannot occur in a scalar subquery');
        }
    }
    for child in _children(expr) {
        _scan_recursive_expr(child, ref);
    }
}

impl _contains_aggregate(expr: ExprNode) -> bool {
    if isinstance(expr, WindowNode) {
        expressions = list(expr.partition) + [order.expr for order in expr.ordering];
        if isinstance(expr.term, AggregateNode) {
            expressions.extend(_children(expr.term));
        } elif expr.term is not None {
            expressions.append(expr.term);
        }
        return `any([_contains_aggregate(e) for e in expressions]);
    }
    return isinstance(expr, AggregateNode)
        or `any([_contains_aggregate(c) for c in _children(expr)]);
}

impl _recursive_count(query: RelationNode, ref: Cte) -> int {
    if isinstance(query, WithNode) {
        count = _recursive_count(query.body, ref);
        for binding in query.bindings {
            if binding.definition is None {
                raise SqlError('CTE reference has no definition');
            }
            count += _recursive_count(binding.definition, ref);
        }
        return count;
    }
    if isinstance(query, OrderedNode) {
        return _recursive_count(query.body, ref);
    }
    if isinstance(query, UnionNode) {
        count = _recursive_count(query.left, ref) + _recursive_count(query.right, ref);
        if count and query.operation != 'UNION' {
            raise SqlError('Recursive set terms require UNION');
        }
        return count;
    }
    if isinstance(query, ValuesNode) {
        for row in query.rows {
            for expr in row {
                _scan_recursive_expr(expr, ref);
            }
        }
        return 0;
    }
    if not isinstance(query, SelectNode) {
        raise SqlError('Unknown recursive term');
    }
    sources = ([query.source] if query.source is not None else [])
        + [j.source for j in query.joins];
    count = sum([_source_recursive_count(s, ref) for s in sources]);
    direct = `any(
        [s is ref or (isinstance(s, CteUse) and s.target is ref) for s in sources]
    );
    expressions = [p.expr for p in query.projections]
        + [
            j.condition
            for j in query.joins
            if j.condition is not None
        ]
        + list(query.groups)
        + list(query.distinct_on)
        + [o.expr for o in query.ordering];
    if query.predicate is not None {
        expressions.append(query.predicate);
    }
    if query.having is not None {
        expressions.append(query.having);
    }
    if direct
        and (
            query.groups
            or query.having is not None
            or `any([_contains_aggregate(e) for e in expressions])
        ) {
        raise SqlError('Recursive reference cannot be aggregated in its query region');
    }
    for e in expressions {
        _scan_recursive_expr(e, ref);
    }
    return count;
}

impl _freeze_sql_value(value: any) -> any {
    if isinstance(value, (list, tuple)) {
        return tuple(_freeze_sql_value(v) for v in value);
    }
    return value;
}

impl _expr_key(expr: ExprNode) -> tuple[any, ...] {
    dtype = (expr.dtype.name, expr.dtype.nullable);
    if isinstance(expr, ColumnNode) {
        return ('column', dtype, id(expr.source), expr.name);
    }
    if isinstance(expr, SlotNode) {
        return ('slot', dtype, expr.name);
    }
    if isinstance(expr, ParamNode) {
        return ('parameter', dtype, id(expr));
    }
    if isinstance(expr, OutputNode) {
        return ('output', dtype, expr.name);
    }
    if isinstance(expr, (ScalarNode, ExistsNode)) {
        return (type(expr).__name__, dtype, id(expr.query));
    }
    options: tuple[any, ...] = ();
    if isinstance(expr, AggregateNode) {
        options = (expr.distinct, );
    }
    if isinstance(expr, WindowNode) {
        options = (
            len(expr.partition),
            tuple((o.descending, o.nulls) for o in expr.ordering),
            None
                if expr.frame is None
                else (
                    expr.frame.mode,
                    expr.frame.start.kind,
                    expr.frame.start.offset,
                    expr.frame.end.kind,
                    expr.frame.end.offset
                )
        );
    }
    return (
        type(expr).__name__,
        dtype,
        getattr(expr, 'op', ''),
        options,
        tuple(_expr_key(c) for c in _children(expr))
    );
}

impl case_nullable[T](
    branches:
        list[
            tuple[
                ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]],
                ScalarExpr[T] | ScalarExpr[Nullable[T]]
            ]
        ],
    fallback: ScalarExpr[T] | ScalarExpr[Nullable[T]]
) -> ScalarExpr[Nullable[T]] {
    if not branches
        or not all(
            [
                c.ast.dtype.name == 'boolean'
                    and v.ast.dtype.name == fallback.ast.dtype.name
                for (c, v) in branches
            ]
        ) {
        raise SqlError('CASE requires compatible conditions and result types');
    }
    return ScalarExpr(
        CaseNode(
            dtype=DataType(fallback.ast.dtype.name, True),
            branches=tuple((c.ast, v.ast) for (c, v) in branches),
            fallback=fallback.ast
        )
    );
}

impl null[T](dtype: SqlType[T]) -> ScalarExpr[Nullable[T]] {
    return param(nullable(dtype), None);
}

impl project_all(source: Source) -> list[ProjectionDef] {
    return [
        ProjectionDef(
            field=f, expr=ColumnNode(dtype=f.dtype, source=source, name=f.name)
        ) for f in source.schema.fields
    ];
}

impl _set_schema(left: RelationNode, right: RelationNode, operation: str) -> Schema {
    a = left.schema.fields;
    b = right.schema.fields;
    if len(a) != len(b)
        or not all([x.dtype.name == y.dtype.name for (x, y) in zip(a, b)])
        or operation not in ('UNION', 'EXCEPT', 'INTERSECT') {
        raise SqlError('UNION schema/cardinality mismatch');
    }
    fields: list[FieldDef] = [];
    for (x, y) in zip(a, b) {
        nullable = (x.dtype.nullable or y.dtype.nullable)
            if operation == 'UNION'
            else (
                x.dtype.nullable
                    if operation == 'EXCEPT'
                    else (x.dtype.nullable and y.dtype.nullable)
            );
        fields.append(FieldDef(x.name, DataType(x.dtype.name, nullable)));
    }
    return Schema(tuple(fields));
}

impl _cast_allowed(source: DataType, target: DataType) -> bool {
    if source.name == target.name {
        return True;
    }
    if source.name == 'text' or target.name == 'text' {
        return True;
    }
    if source.name.endswith('[]') and target.name.endswith('[]') {
        return _cast_allowed(DataType(source.name[:-2]), DataType(target.name[:-2]));
    }
    numeric = ('integer', 'bigint', 'numeric', 'double precision');
    return source.name in numeric and target.name in numeric;
}

impl add_int32(
    left: ScalarExpr[SqlInt32], right: ScalarExpr[SqlInt32]
) -> ScalarExpr[SqlInt32] {
    return ScalarExpr(_call('INT32_ADD', (left.ast, right.ast)));
}

impl sub_int32(
    left: ScalarExpr[SqlInt32], right: ScalarExpr[SqlInt32]
) -> ScalarExpr[SqlInt32] {
    return ScalarExpr(_call('INT32_SUB', (left.ast, right.ast)));
}

impl bool_or(
    term: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]
) -> ScalarExpr[Nullable[SqlBool]] {
    if term.ast.dtype.name != 'boolean' {
        raise SqlError('BOOL_OR requires a boolean');
    }
    return ScalarExpr(
        AggregateNode(dtype=DataType('boolean', True), op='BOOL_OR', term=term.ast)
    );
}

impl QueryValidator.expr(
    ast: ExprNode, scope: list[Source], local: list[Source], ctes: list[Cte]
) -> Checked {
    key = (
        id(ast),
        tuple(id(s) for s in scope),
        tuple(id(s) for s in local),
        tuple(id(c) for c in ctes)
    );
    if key not in self.expression_cache {
        self.expression_cache[key] = self.expr_uncached(ast, scope, local, ctes);
    }
    return self.expression_cache[key];
}

impl QueryValidator.validate_cte(
    reference: Cte, outer: list[Source], available: list[Cte]
) -> set[str] {
    key = (id(reference), tuple(id(s) for s in outer), tuple(id(c) for c in available));
    if key not in self.cte_cache {
        self.cte_cache[key] = self.validate_cte_uncached(reference, outer, available);
    }
    return self.cte_cache[key];
}

impl _validate_slot_name(name: str) {
    if not isinstance(name, str)
        or not name
        or name in ('sql', 'self')
        or not name.isascii()
        or not (name[0].isalpha() or name[0] == '_')
        or not all([c.isalnum() or c == '_' for c in name]) {
        raise SqlError(
            'Parameter slot requires an ASCII identifier other than sql or self'
        );
    }
}

impl slot[T](name: str, dtype: SqlType[T]) -> ScalarExpr[T] {
    _validate_slot_name(name);
    return ScalarExpr(SlotNode(dtype=dtype.data, name=name));
}

impl CompiledSQL.bind(
    values:
        dict[
            str,
            bool
                | int
                | float
                | str
                | UUID
                | Decimal
                | tuple[bool | int | float | str | UUID | Decimal | None, ...]
                | None
        ]
) -> CompiledSQL {
    if set(values) != {name for (name, dtype) in self.slots} {
        raise SqlError('Parameter names must match the compiled slots');
    }
    params = dict(self.params);
    for (name, dtype) in self.slots {
        value = values[name];
        validate_value(dtype, value);
        params[name] = _freeze_sql_value(value);
    }
    return CompiledSQL(sql=self.sql, params=params);
}
