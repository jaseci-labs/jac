"""A dict literal whose first key is a string variable lowers natively.

When a dict literal is the first of its dict type in a module, the backend
chooses the dict's storage from the literal's first pair. It normalised the
first value from a string view to a string, but not the first key: a key
written as a literal was already a string, while one read from a parameter
or a module global arrived as a view, was taken for an integer key, and the
helpers for the dict could not be emitted ("Operands must be the same type").
The function then fell back to Python, and a native build that called it
failed outright. The first key is now normalised as the first value is.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "dict literals keyed first by a string variable match Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "dict_literal_variable_key.jac"
    );
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    lines = out.splitlines();
    assert lines[-5] == "1 True None 1" , out;
    assert lines[-4] == "1 0 1 True False" , out;
    assert lines[-3] == "1 on None ['first', 'second']" , out;
    assert lines[-2] == "1.5 2.5 ['lead', 'other']" , out;
    assert lines[-1] == "[1, 2, 3] 1" , out;
}
