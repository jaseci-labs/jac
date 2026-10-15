"""An assertion's message is what its error says, however the message is written.

`assert cond, "text"` raised with its text and where it failed, but a message
that was worked out (`"x must be positive: " + str(x)`, an f-string) was
dropped: the error said only `assertion failed at <file>:<line>`. A program
that reports what its own checks say (a validator naming the token nothing
grants, a test that prints the value it got) lost the message.
"""

import ctypes;
import from tests.support { compile_native, get_func }

def call_str(eng: any, name: str) -> bytes {
    return get_func(eng, name, ctypes.c_char_p)();
}

test "a message built by concatenation is carried, with where it failed" {
    (eng, _) = compile_native("assert_message.jac");
    text = call_str(eng, "computed_message");
    assert text.startswith(b"x must be positive: -1 at ") , text;
    assert text.endswith(b"assert_message.jac:2") , text;
}

test "a message that is an f-string is carried, with where it failed" {
    (eng, _) = compile_native("assert_message.jac");
    text = call_str(eng, "formatted_message");
    assert text.startswith(b"too short: ab at ") , text;
    assert text.endswith(b"assert_message.jac:6") , text;
}

test "a literal message and no message are as they were" {
    (eng, _) = compile_native("assert_message.jac");
    literal = call_str(eng, "literal_message");
    assert literal.startswith(b"a literal at ")
        and literal.endswith(b"assert_message.jac:10") , literal;
    bare = call_str(eng, "bare_message");
    assert bare.startswith(b"assertion failed at ")
        and bare.endswith(b"assert_message.jac:14") , bare;
}

test "a message is not worked out while the assertion holds" {
    (eng, _) = compile_native("assert_message.jac");
    assert get_func(eng, "holding", ctypes.c_int64)() == 1;
}
