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
}
