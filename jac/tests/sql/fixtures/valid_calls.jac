"""Positive static-type contracts for the internal SQL API."""
import jaclang.sql as s;

with entry {
    age = s.field('age', s.int64_type());
    name = s.field('name', s.text_type());
    people = s.table('people', [age, name]);
    query = s.select(
        [s.named('name', people.col(name))],
        source=people,
        where=s.gt(people.col(age), s.slot('min_age', s.int64_type()))
    );
    compiled = s.compile_sql(query);
    bound = compiled.bind({'min_age': 18});
    optional = s.param(s.nullable(s.int64_type()), None);
    maybe_bool = s.param(s.nullable(s.bool_type()), None);
    s.eq_nullable(optional, optional);
    s.coalesce(optional, s.int64(0));
    s.is_null(optional);
    s.and_([s.boolean(True), s.not_(s.boolean(False))]);
    s.or_([s.boolean(True)]);
    s.and_nullable([maybe_bool, s.boolean(True)]);
    s.or_nullable([maybe_bool, s.boolean(False)]);
    s.not_nullable(maybe_bool);
    s.sub(s.int64(2), s.int64(1));
    s.sum_(s.param(s.float64_type(), 1.0));
    s.sum_int32(s.int32(1));
    s.sum_int64(s.int64(1));
    s.sum_numeric(s.numeric(1));
    s.bool_and(s.boolean(True));
    s.bool_or(maybe_bool);
    s.string_agg(s.text('x'), s.text(','));
}
