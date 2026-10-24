"""Expected static errors: each bad call tests a separate SQL category/type."""
import from jaclang.sql {
    int64, text, boolean, add, named, select, compile_sql, scalar_one, scalar,
    field, int64_type, text_type, table, Command, inner_join, eq
}
with entry {
    add(text('a'), int64(1));
    named('x', select([named('n', int64(1))]));
    compile_sql(int64(1));
    select([named('n', int64(1))], where=int64(1));
    scalar_one(select([named('n', int64(1))]), field('n', int64_type()));
    scalar(select([named('n', int64(1))]), field('n', int64_type()));
    add(boolean(True), int64(1));
    eq(int64(1), text('bad'));
    name = field('name', text_type());
    people = table('people', [name], 'p');
    add(people.col(name), int64(1));
    compile_sql(Command());
    select([int64(1)]);
}
