"""An assertion's message is what its error says, however the message is written.

`assert cond, msg` raises `AssertionError(msg)`, so `str(error)` is the message
exactly as Python renders it: a worked-out message (`"x must be positive: " +
str(x)`, an f-string) is carried whole, a bare assert says nothing, and a
`None` message says `None`. A program that reports what its own checks say (a
validator naming the token nothing grants, a test that prints the value it
got) must not lose the message.
"""

import ctypes;
import os;
import tempfile;
import from pathlib { Path }
import from tests.support { compile_native, get_func, native_build, native_run }

glob RC_FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "rc_assert_message.jac"
     );

def call_str(eng: any, name: str) -> bytes {
    return get_func(eng, name, ctypes.c_char_p)();
}

test "a message built by concatenation is carried" {
    (eng, _) = compile_native("assert_message.jac");
    text = call_str(eng, "computed_message");
    assert text == b"x must be positive: -1" , text;
}

test "a message that is an f-string is carried" {
    (eng, _) = compile_native("assert_message.jac");
    text = call_str(eng, "formatted_message");
    assert text == b"too short: ab" , text;
}

test "a literal message and no message are as they were" {
    (eng, _) = compile_native("assert_message.jac");
    literal = call_str(eng, "literal_message");
    assert literal == b"a literal" , literal;
    bare = call_str(eng, "bare_message");
    assert bare == b"" , bare;
}

test "a message is not worked out while the assertion holds" {
    (eng, _) = compile_native("assert_message.jac");
    assert get_func(eng, "holding", ctypes.c_int64)() == 1;
    assert get_func(eng, "message_calls", ctypes.c_int64)() == 1;
}

test "a message that is None says None" {
    (eng, _) = compile_native("assert_message.jac");
    text = call_str(eng, "none_message");
    assert text == b"None" , text;
}

def check_message_freed(memory: str) {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "rc_assert_message");
        native_build(RC_FIXTURE, out_bin, memory=memory, extra=["--debug"]);
        out = native_run(out_bin);
    }
    (traced, _, dump) = out.partition("--- RC LIVE OBJECTS at exit ---");
    assert dump , out[-2000:];
    lines = traced.splitlines();
    assert lines[-1] == "12" , lines[-1];
    assert "RC MALLOC" in traced , out[-2000:];
    leaked = [
        line
        for line in dump.splitlines()
        if "<- LEAK" in line
    ];
    assert not leaked , leaked;
}

test "a caught, sliced, or non-string message is freed with reference counting" {
    check_message_freed("rc");
}

test "a caught, sliced, or non-string message is freed with cycle collection" {
    check_message_freed("managed");
}
