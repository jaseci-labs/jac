"""Regular Jac enums share native method emission and argument binding."""
import ctypes;
import from tests.support { compile_mir, compile_native, get_func }

test "native enum methods preserve scalar receivers and nested calls" {
    (engine, _) = compile_native("enum_methods.jac");
    demoted = compile_mir("enum_methods.jac").demoted();
    assert not demoted , str(demoted);
    binding = get_func(engine, "binding_score", ctypes.c_int64, ctypes.c_int64);
    priority = get_func(engine, "priority_score", ctypes.c_int64, ctypes.c_int64);
    result = (binding(0), binding(1), priority(0), priority(1));
    assert result == (7, 11, 6, 22) , str(result);
}


test "imported enum methods retain declarations and default arguments" {
    (engine, _) = compile_native("enum_methods.jac");
    demoted = compile_mir("enum_methods.jac").demoted();
    assert not demoted , str(demoted);
    foreign = get_func(
        engine, "foreign_priority_score", ctypes.c_int64, ctypes.c_int64
    );
    result = (foreign(0), foreign(1));
    assert result == (15, 39) , str(result);
}
