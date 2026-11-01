"""A method call on an `any` receiver refuses loudly instead of vanishing."""

import os;
import ctypes;
import from tests.support { JAC_ROOT, compile_mir, compile_native, get_func }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "any_receiver_method_refusal.jac";


test "mutating and reading methods on an any receiver demote their callable" {
    # These calls used to lower to nothing at all: the call was dropped from
    # the IR and the function returned as if it had run.
    fx = compile_mir(FIXTURE, FIXTURES);
    for fn in ["any_field_append", "any_field_bytearray_append", "any_param_count"] {
        assert fx.is_demoted(fn) , (
            f"{fn} must refuse its `any` receiver method call, got: {fx.demoted()}"
        );
    }
}


test "the concretely typed twins still lower and run" {
    fx = compile_mir(FIXTURE, FIXTURES);
    assert not fx.is_demoted("typed_field_append") , str(fx.demoted());
    (eng, _fx) = compile_native(FIXTURE, FIXTURES);
    run = get_func(eng, "typed_field_append", ctypes.c_int64);
    assert run() == 21;
}


test "a File parameter's methods lower without a preceding open" {
    # The File helpers used to be emitted only by `open()`, so `fp.read()` on
    # a parameter in a unit that never opens a file found no method and was
    # dropped the same silent way.
    fx = compile_mir(FIXTURE, FIXTURES);
    assert not fx.is_demoted("file_param_read") , str(fx.demoted());
}
