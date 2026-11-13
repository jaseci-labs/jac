import from jaclang.sql {
    add_int32, sub, text, int64, int32, array, array_append, array_param, any_eq,
    int64_type, field, table, boolean, left_join, row_number,
    sum_int64, lpad, numeric_add, numeric, with_ctes, concat, case_, values, slot, gt, text_type
}
with entry {
    integers = array_param(int64_type(), [1]);
    source = table('people', [field('id', int64_type())]);
    sub(text('x'), int64(1)); # invalid
    array(int64_type(), [text('x')]); # invalid
    array_append(integers, text('x')); # invalid
    any_eq(text('x'), integers); # invalid
    left_join(source, boolean(True)); # invalid
    row_number(order_by=[int64(1)]); # invalid
    sum_int64(text('x')); # invalid
    lpad(text('x'), int64(2), text('0')); # invalid
    numeric_add(int64(1), numeric(1)); # invalid
    with_ctes(int64(1), []); # invalid
    concat([int64(1)]); # invalid
    case_([(int64(1), int64(2))], int64(3)); # invalid
    int32('1'); # invalid
    values([field('id', int64_type())], [[source]]); # invalid
    add_int32(int64(1), int32(2)); # invalid
    slot(123, int64_type()); # invalid
    gt(slot('n', text_type()), int64(1)); # invalid
}
