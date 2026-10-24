import from uuid { UUID }
import from decimal { Decimal }

class SqlError(ValueError) {}

obj SqlBool {}
obj SqlInt64 {}
obj SqlFloat64 {}
obj SqlText {}
obj SqlUUID {}
obj Nullable[T] {}
obj Many {}
obj AtMostOne {}
obj ExactlyOne {}

obj SqlValue {
    def __setattr__(name: str, value: any);
    def __delattr__(name: str);
}

obj DataType(SqlValue) {
    has name: str,
        nullable: bool = False;

    def postinit;
}

obj SqlType[T](SqlValue) {
    has data: DataType;
}

obj FieldDef(SqlValue) {
    has name: str,
        dtype: DataType;
}

obj Field[T](FieldDef) {}

obj Schema(SqlValue) {
    has fields: tuple[FieldDef, ...];

    def postinit;
    def find(name: str) -> FieldDef;
}

obj RelationNode(SqlValue) {
    has cardinality: str;
    has schema: Schema {
        getter {
            raise SqlError('Unknown relation schema');
        }
    }
}

obj Source(SqlValue) {
    has alias: str;
    has schema: Schema {
        getter {
            raise SqlError('Unknown source schema');
        }
    }

    def ref -> Source;
    def col[T](key: Field[T]) -> ScalarExpr[T];
}

obj Table(Source) {
    has declared_schema: Schema,
        name: tuple[str, ...];

    has schema: Schema {
        getter {
            return self.declared_schema;
        }
    }
}

obj Derived(Source) {
    has query: RelationNode,
        lateral: bool = False;

    has schema: Schema {
        getter {
            return self.query.schema;
        }
    }
}

obj CteBinding(SqlValue) {
    has _definition: RelationNode | None = None,
        _recursive: bool = False;

    has definition: RelationNode | None {
        getter {
            return self._definition;
        }
    }

    has recursive: bool {
        getter {
            return self._recursive;
        }
    }

    def __setattr__(name: str, value: any);
    def bind(query: RelationNode, recursive: bool);
}

obj Cte(Source) {
    has binding: CteBinding,
        declared_schema: Schema | None = None,
        materialized: bool | None = None;

    has definition: RelationNode | None {
        getter {
            return self.binding.definition;
        }
    }

    has recursive: bool {
        getter {
            return self.binding.recursive;
        }
    }

    has schema: Schema {
        getter {
            if self.declared_schema is not None {
                return self.declared_schema;
            }
            if self.definition is not None {
                return self.definition.schema;
            }
            raise SqlError('CTE reference has no schema');
        }
    }
}

obj CteUse(Source) {
    has target: Cte;
    has schema: Schema {
        getter {
            return self.target.schema;
        }
    }
}

obj ExprNode(SqlValue) {
    has dtype: DataType;
}

obj ColumnNode(ExprNode) {
    has source: Source,
        name: str;
}

obj ParamNode(ExprNode) {
    has value:
        bool
            | int
            | float
            | str
            | UUID
            | Decimal
            | tuple[bool | int | float | str | UUID | Decimal | None, ...]
            | None;
}

obj SlotNode(ExprNode) {
    has name: str;
}

obj BinaryNode(ExprNode) {
    has op: str,
        left: ExprNode,
        right: ExprNode;
}

obj BoolNode(ExprNode) {
    has op: str,
        terms: tuple[ExprNode, ...];
}

obj UnaryNode(ExprNode) {
    has op: str,
        term: ExprNode;
}

obj CastNode(ExprNode) {
    has term: ExprNode;
}

obj AggregateNode(ExprNode) {
    has op: str,
        term: ExprNode | None,
        distinct: bool = False,
        delimiter: ExprNode | None = None;
}

obj CoalesceNode(ExprNode) {
    has term: ExprNode,
        fallback: ExprNode;
}

obj ScalarNode(ExprNode) {
    has query: RelationNode,
        require_one: bool;
}

obj ExistsNode(ExprNode) {
    has query: RelationNode;
}

obj ScalarExpr[T](SqlValue) {
    has ast: ExprNode;
}

obj ProjectionDef(SqlValue) {
    has field: FieldDef,
        expr: ExprNode;
}

obj Projection[T](ProjectionDef) {
    def key -> Field[T];
}

obj Order(SqlValue) {
    has expr: ExprNode,
        descending: bool,
        nulls: str = '';
}

obj Join(SqlValue) {
    has source: Source,
        condition: ExprNode | None,
        kind: str = 'INNER';
}

obj SelectNode(RelationNode) {
    has projections: tuple[ProjectionDef, ...],
        source: Source | None,
        joins: tuple[Join, ...],
        predicate: ExprNode | None,
        groups: tuple[ExprNode, ...],
        having: ExprNode | None,
        ordering: tuple[Order, ...],
        limit: int | None,
        distinct: bool = False,
        distinct_on: tuple[ExprNode, ...] = ();

    has schema: Schema {
        getter {
            if '_schema_cache' not in self.__dict__ {
                object.__setattr__(
                    self,
                    '_schema_cache',
                    Schema(tuple(p.field for p in self.projections))
                );
            }
            return self.__dict__['_schema_cache'];
        }
    }
}

obj UnionNode(RelationNode) {
    has left: RelationNode,
        right: RelationNode,
        keep_duplicates: bool,
        operation: str = 'UNION';

    has schema: Schema {
        getter {
            if '_schema_cache' not in self.__dict__ {
                object.__setattr__(
                    self,
                    '_schema_cache',
                    _set_schema(self.left, self.right, self.operation)
                );
            }
            return self.__dict__['_schema_cache'];
        }
    }
}

obj Relation[R, C](SqlValue) {
    has ast: RelationNode;

    def as_source(lateral: bool = False) -> Source;
}

obj Command {}

obj CompiledSQL {
    has sql: str,
        params:
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
            ],
        slots: tuple[tuple[str, DataType], ...] = ();

    def bind(
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
    ) -> CompiledSQL;
}


def same_type(a: DataType, b: DataType) -> bool;


def bool_type -> SqlType[SqlBool];

def int64_type -> SqlType[SqlInt64];

def float64_type -> SqlType[SqlFloat64];

def text_type -> SqlType[SqlText];

def uuid_type -> SqlType[SqlUUID];

def nullable[T](dtype: SqlType[T]) -> SqlType[Nullable[T]];

def field[T](name: str, dtype: SqlType[T]) -> Field[T];

def table(
    name: str, fields: list[FieldDef], alias: str = '', namespace: str | None = None
) -> Source;

def param[T](
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
) -> ScalarExpr[T];

def slot[T](name: str, dtype: SqlType[T]) -> ScalarExpr[T];

def _validate_slot_name(name: str);

def int64(value: int) -> ScalarExpr[SqlInt64];

def text(value: str) -> ScalarExpr[SqlText];

def boolean(value: bool) -> ScalarExpr[SqlBool];

def uuid(value: UUID) -> ScalarExpr[SqlUUID];

def validate_value(
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
) -> None;

def _compare[T](
    left: ScalarExpr[T], right: ScalarExpr[T], op: str
) -> ScalarExpr[SqlBool];

def eq[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool];

def gt[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool];

def eq_nullable[T](
    left: ScalarExpr[Nullable[T]], right: ScalarExpr[Nullable[T]]
) -> ScalarExpr[Nullable[SqlBool]];

def add(
    left: ScalarExpr[SqlInt64], right: ScalarExpr[SqlInt64]
) -> ScalarExpr[SqlInt64];

def and_(terms: list[ScalarExpr[SqlBool]]) -> ScalarExpr[SqlBool];

def is_null[T](term: ScalarExpr[Nullable[T]]) -> ScalarExpr[SqlBool];

def cast[T, U](term: ScalarExpr[T], dtype: SqlType[U]) -> ScalarExpr[U];

def count -> ScalarExpr[SqlInt64];

def sum_(term: ScalarExpr[SqlFloat64]) -> ScalarExpr[Nullable[SqlFloat64]];

def coalesce[T](
    term: ScalarExpr[Nullable[T]], fallback: ScalarExpr[T]
) -> ScalarExpr[T];

def named[T](name: str, expr: ScalarExpr[T]) -> Projection[T];

def asc[T](expr: ScalarExpr[T], nulls: str = '') -> Order;

def desc[T](expr: ScalarExpr[T], nulls: str = '') -> Order;

def inner_join(
    source: Source, on: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]
) -> Join;

def select(
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
) -> Relation[Schema, Many];

def limit_one[R, C](query: Relation[R, C]) -> Relation[R, AtMostOne];

def aggregate(
    projections: list[ProjectionDef],
    source: Source | None = None,
    where: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]] | None = None
) -> Relation[Schema, ExactlyOne];

def scalar[R, T](
    query: Relation[R, AtMostOne] | Relation[R, ExactlyOne], key: Field[T]
) -> ScalarExpr[Nullable[T]];

def scalar_one[R, T](query: Relation[R, ExactlyOne], key: Field[T]) -> ScalarExpr[T];

def exists[R, C](query: Relation[R, C]) -> ScalarExpr[SqlBool];

def union_all[R, C, D](
    left: Relation[R, C], right: Relation[R, D]
) -> Relation[R, Many];

def cte[R, C](query: Relation[R, C], materialized: bool | None = None) -> Cte;

def cte_ref(fields: list[FieldDef]) -> Cte;

def define_cte[R, C](
    reference: Cte, query: Relation[R, C], recursive: bool = False
) -> Cte;


obj Checked {
    has free: set[str],
        aggregate: bool = False,
        window: bool = False;
}

obj QueryFacts {
    has external: set[str];
}

obj ValidatedQuery {
    has query: RelationNode,
        ctes: tuple[Cte, ...],
        aliases: dict[int, str],
        cte_names: dict[int, str],
        local_orders: dict[int, tuple[Cte, ...]],
        slots: tuple[tuple[str, DataType], ...] = ();
}


def validate_identifier(name: str);

def quote_identifier(name: str) -> str;


def _key(source: Source, name: str) -> str;

def _schema_equal(a: Schema, b: Schema, names: bool = True) -> bool;

def validate_union(ast: UnionNode);

obj QueryGraph {
    has slot_types: dict[str, DataType] = {},
        ctes: list[Cte] = [],
        bound_ctes: set[int] = set(),
        physical_names: set[str] = set(),
        explicit_aliases: set[str] = set(),
        seen_sources: set[int] = set(),
        seen_queries: set[int] = set(),
        active_queries: set[int] = set(),
        seen_expressions: set[int] = set();

    def visit_source(src: Source) -> None;
    def collect(query: RelationNode);
    def visit_expr(expr: ExprNode) -> None;
    def visit_query(query: RelationNode) -> None;
}


obj QueryValidator {
    has expression_cache:
        dict[tuple[int, tuple[int, ...], tuple[int, ...], tuple[int, ...]], Checked] = {},
        query_cache: dict[tuple[int, tuple[int, ...], tuple[int, ...]], QueryFacts] = {},
        cte_cache: dict[tuple[int, tuple[int, ...], tuple[int, ...]], set[str]] = {},
        active_queries: set[int] = set(),
        aliases: dict[int, str] = {},
        cte_names: dict[int, str] = {},
        used_names: set[str] = set(),
        ordered_ctes: list[Cte] = [],
        cte_states: dict[int, int] = {},
        local_orders: dict[int, tuple[Cte, ...]] = {},
        alias_counter: int = 0,
        cte_counter: int = 0;

    def fresh_name(prefix: str) -> str;
    def alias_for(src: Source) -> str;
    def order_cte(reference: Cte) -> None;
    def analyze[R, C](query: Relation[R, C]) -> ValidatedQuery;
    def source(
        src: Source,
        ctes: list[Cte],
        outer: list[Source] = [],
        lateral_scope: list[Source] = []
    ) -> set[str];

    def validate_cte(
        reference: Cte, outer: list[Source], available: list[Cte]
    ) -> set[str];

    def local_bindings(bindings: tuple[Cte, ...], available: list[Cte]) -> list[Cte];
    def extended_expr(
        ast: ExprNode, scope: list[Source], local: list[Source], ctes: list[Cte]
    ) -> Checked;

    def expr(
        ast: ExprNode, scope: list[Source], local: list[Source], ctes: list[Cte]
    ) -> Checked;

    def expr_uncached(
        ast: ExprNode, scope: list[Source], local: list[Source], ctes: list[Cte]
    ) -> Checked;

    def validate_cte_uncached(
        reference: Cte, outer: list[Source], available: list[Cte]
    ) -> set[str];

    def query(ast: RelationNode, outer: list[Source], ctes: list[Cte]) -> QueryFacts;
    def query_body(
        ast: RelationNode, outer: list[Source], ctes: list[Cte]
    ) -> QueryFacts;

    def select_sql(
        ast: SelectNode, outer: list[Source], ctes: list[Cte]
    ) -> QueryFacts;
}


obj PostgresRenderer {
    has params:
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
        ] = {},
        slot_types: dict[str, DataType] = {},
        parameter_ids: dict[int, str] = {},
        aliases: dict[int, str] = {},
        cte_names: dict[int, str] = {},
        local_orders: dict[int, tuple[Cte, ...]] = {};

    def alias_for(src: Source) -> str;
    def render(plan: ValidatedQuery) -> CompiledSQL;
    def source(src: Source) -> str;
    def source_body(src: Source) -> str;
    def with_sql(bindings: tuple[Cte, ...], body: str) -> str;
    def ordering(items: tuple[Order, ...]) -> str;
    def extended_expr(ast: ExprNode) -> str;
    def expr(ast: ExprNode) -> str;
    def query(ast: RelationNode) -> str;
}


def compile_sql[R, C](query: Relation[R, C]) -> CompiledSQL;


def validate_recursive_step(ref: Cte, step: RelationNode);

obj SqlInt32 {}
obj SqlNumeric {}
obj SqlArray[T] {}

obj CallNode(ExprNode) {
    has op: str,
        args: tuple[ExprNode, ...];
}

obj CaseNode(ExprNode) {
    has branches: tuple[tuple[ExprNode, ExprNode], ...],
        fallback: ExprNode;
}

obj ArrayNode(ExprNode) {
    has items: tuple[ExprNode, ...];
}

obj MembershipNode(ExprNode) {
    has term: ExprNode,
        items: tuple[ExprNode, ...];
}

obj AnyNode(ExprNode) {
    has term: ExprNode,
        array: ExprNode;
}

obj OutputNode(ExprNode) {
    has name: str;
}

obj FrameBound(SqlValue) {
    has kind: str,
        offset: int = 0;
}

obj WindowFrame(SqlValue) {
    has start: FrameBound,
        end: FrameBound,
        mode: str = 'ROWS';
}

obj WindowNode(ExprNode) {
    has op: str,
        term: ExprNode | None,
        partition: tuple[ExprNode, ...],
        ordering: tuple[Order, ...],
        frame: WindowFrame | None;
}

obj NullableSource(Source) {
    has target: Source;
    has schema: Schema {
        getter {
            return Schema(
                tuple(
                    FieldDef(f.name, DataType(f.dtype.name, True))
                    for f in self.target.schema.fields
                )
            );
        }
    }
}

obj FunctionSource(Source) {
    has argument: ExprNode,
        element: FieldDef,
        ordinality: FieldDef | None;

    has schema: Schema {
        getter {
            return Schema(
                (self.element, )
                    + ((self.ordinality, ) if self.ordinality is not None else ())
            );
        }
    }
}

obj ValuesNode(RelationNode) {
    has declared_schema: Schema,
        rows: tuple[tuple[ExprNode, ...], ...];

    has schema: Schema {
        getter {
            return self.declared_schema;
        }
    }
}

obj WithNode(RelationNode) {
    has body: RelationNode,
        bindings: tuple[Cte, ...];

    has schema: Schema {
        getter {
            return self.body.schema;
        }
    }
}

obj OrderedNode(RelationNode) {
    has body: RelationNode,
        ordering: tuple[Order, ...],
        limit: int | None;

    has schema: Schema {
        getter {
            return self.body.schema;
        }
    }
}

def int32_type -> SqlType[SqlInt32];
def numeric_type -> SqlType[SqlNumeric];
def array_type[T](element: SqlType[T]) -> SqlType[SqlArray[T]];
def int32(value: int) -> ScalarExpr[SqlInt32];
def numeric(value: Decimal | int) -> ScalarExpr[SqlNumeric];
def array_param[T](
    element: SqlType[T], values: list[bool | int | float | str | UUID | Decimal | None]
) -> ScalarExpr[SqlArray[T]];

def array[T](
    element: SqlType[T], items: list[ScalarExpr[T]]
) -> ScalarExpr[SqlArray[T]];

def array_concat[T](
    left: ScalarExpr[SqlArray[T]], right: ScalarExpr[SqlArray[T]]
) -> ScalarExpr[SqlArray[T]];

def array_append[T](
    left: ScalarExpr[SqlArray[T]], right: ScalarExpr[T]
) -> ScalarExpr[SqlArray[T]];

def any_eq[T](
    term: ScalarExpr[T], values: ScalarExpr[SqlArray[T]]
) -> ScalarExpr[Nullable[SqlBool]];

def ne[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool];
def lt[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool];
def le[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool];
def ge[T](left: ScalarExpr[T], right: ScalarExpr[T]) -> ScalarExpr[SqlBool];
def compare_nullable[T](
    left: ScalarExpr[T] | ScalarExpr[Nullable[T]],
    right: ScalarExpr[T] | ScalarExpr[Nullable[T]],
    op: str = '='
) -> ScalarExpr[Nullable[SqlBool]];

def or_(terms: list[ScalarExpr[SqlBool]]) -> ScalarExpr[SqlBool];
def and_nullable(
    terms: list[ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]]
) -> ScalarExpr[Nullable[SqlBool]];

def or_nullable(
    terms: list[ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]]
) -> ScalarExpr[Nullable[SqlBool]];

def not_(term: ScalarExpr[SqlBool]) -> ScalarExpr[SqlBool];
def not_nullable(term: ScalarExpr[Nullable[SqlBool]]) -> ScalarExpr[Nullable[SqlBool]];
def is_not_null[T](term: ScalarExpr[Nullable[T]]) -> ScalarExpr[SqlBool];
def in_[T](term: ScalarExpr[T], items: list[ScalarExpr[T]]) -> ScalarExpr[SqlBool];
def sub(
    left: ScalarExpr[SqlInt64], right: ScalarExpr[SqlInt64]
) -> ScalarExpr[SqlInt64];

def numeric_add(
    left: ScalarExpr[SqlNumeric], right: ScalarExpr[SqlNumeric]
) -> ScalarExpr[SqlNumeric];

def numeric_sub(
    left: ScalarExpr[SqlNumeric], right: ScalarExpr[SqlNumeric]
) -> ScalarExpr[SqlNumeric];

def case_[T](
    branches:
        list[tuple[ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]], ScalarExpr[T]]],
    fallback: ScalarExpr[T]
) -> ScalarExpr[T];

def concat(
    terms: list[ScalarExpr[SqlText] | ScalarExpr[Nullable[SqlText]]]
) -> ScalarExpr[SqlText];

def text_concat(
    left: ScalarExpr[SqlText], right: ScalarExpr[SqlText]
) -> ScalarExpr[SqlText];

def lpad(
    term: ScalarExpr[SqlText], length: ScalarExpr[SqlInt32], fill: ScalarExpr[SqlText]
) -> ScalarExpr[SqlText];

def sum_int32(term: ScalarExpr[SqlInt32]) -> ScalarExpr[Nullable[SqlInt64]];
def sum_int64(term: ScalarExpr[SqlInt64]) -> ScalarExpr[Nullable[SqlNumeric]];
def sum_numeric(term: ScalarExpr[SqlNumeric]) -> ScalarExpr[Nullable[SqlNumeric]];
def bool_and(
    term: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]
) -> ScalarExpr[Nullable[SqlBool]];

def string_agg(
    term: ScalarExpr[SqlText] | ScalarExpr[Nullable[SqlText]],
    delimiter: ScalarExpr[SqlText],
    distinct: bool = False
) -> ScalarExpr[Nullable[SqlText]];

def optional_source(source: Source) -> NullableSource;
def left_join(
    source: NullableSource, on: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]
) -> Join;

def cross_join(source: Source) -> Join;
def unnest[T](
    argument: ScalarExpr[SqlArray[T]],
    element: Field[T],
    ordinality: Field[SqlInt64] | None = None
) -> Source;

def values(
    fields: list[FieldDef], rows: list[list[ScalarExpr]]
) -> Relation[Schema, Many];

def union[R, C, D](left: Relation[R, C], right: Relation[R, D]) -> Relation[R, Many];
def except_[R, C, D](
    left: Relation[R, C], right: Relation[R, D], all_: bool = False
) -> Relation[R, Many];

def intersect[R, C, D](
    left: Relation[R, C], right: Relation[R, D], all_: bool = False
) -> Relation[R, Many];

def output[T](key: Field[T]) -> ScalarExpr[T];
def ordered[R, C](
    query: Relation[R, C], order_by: list[Order], limit: int | None = None
) -> Relation[R, Many];

def with_ctes[R, C](query: Relation[R, C], bindings: list[Cte]) -> Relation[R, C];
def preceding(offset: int) -> FrameBound;
def following(offset: int) -> FrameBound;
def current_row -> FrameBound;
def unbounded_preceding -> FrameBound;
def unbounded_following -> FrameBound;
def rows_between(start: FrameBound, end: FrameBound) -> WindowFrame;
def row_number(
    partition_by: list[ExprNode] = [], order_by: list[Order] = []
) -> ScalarExpr[SqlInt64];

def dense_rank(
    partition_by: list[ExprNode] = [], order_by: list[Order] = []
) -> ScalarExpr[SqlInt64];

def over[T](
    term: ScalarExpr[T],
    partition_by: list[ExprNode] = [],
    order_by: list[Order] = [],
    frame: WindowFrame | None = None
) -> ScalarExpr[T];

def _call(op: str, args: tuple[ExprNode, ...]) -> ExprNode;
def _call_type(op: str, args: tuple[ExprNode, ...]) -> DataType;
def _nullable_boolean(
    op: str, terms: list[ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]]
) -> ScalarExpr[Nullable[SqlBool]];

def _validate_frame(frame: WindowFrame);
def _children(expr: ExprNode) -> tuple[ExprNode, ...];
def _merge_checked(items: list[Checked]) -> Checked;
def _sum(term: ExprNode) -> ExprNode;
def _aggregate_type(ast: AggregateNode) -> DataType;
def _validate_order(order: Order);

def _recursive_count(query: RelationNode, ref: Cte) -> int;
def _source_recursive_count(source: Source, ref: Cte) -> int;
def _scan_recursive_expr(expr: ExprNode, ref: Cte);
def _contains_aggregate(expr: ExprNode) -> bool;

def _expr_key(expr: ExprNode) -> tuple[any, ...];
def _freeze_sql_value(value: any) -> any;

def case_nullable[T](
    branches:
        list[
            tuple[
                ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]],
                ScalarExpr[T] | ScalarExpr[Nullable[T]]
            ]
        ],
    fallback: ScalarExpr[T] | ScalarExpr[Nullable[T]]
) -> ScalarExpr[Nullable[T]];

def null[T](dtype: SqlType[T]) -> ScalarExpr[Nullable[T]];
def project_all(source: Source) -> list[ProjectionDef];
def _set_schema(left: RelationNode, right: RelationNode, operation: str) -> Schema;

def _cast_allowed(source: DataType, target: DataType) -> bool;

def add_int32(
    left: ScalarExpr[SqlInt32], right: ScalarExpr[SqlInt32]
) -> ScalarExpr[SqlInt32];

def sub_int32(
    left: ScalarExpr[SqlInt32], right: ScalarExpr[SqlInt32]
) -> ScalarExpr[SqlInt32];

def bool_or(
    term: ScalarExpr[SqlBool] | ScalarExpr[Nullable[SqlBool]]
) -> ScalarExpr[Nullable[SqlBool]];
