"""A variable shadows a function of the same name that it never imported.

Lowering a module declares every public function of the modules it imports
from, under the functions' bare names, whether or not the import names them.
A read of, or a call through, one of the module's own variables of that name
used to bind to the other module's function: `burst = Thing(); burst.value`
read a field out of machine code, and calling a variable holding a lambda
called the other module's function, with no diagnostic either way.
"""
import ctypes;
import os;
import subprocess;
import from tests.support { compile_native, get_func, jac_command, TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     MAIN = "var_shadows_function_main.jac",
     EXPECTED_LINES: list[str] = ["15", "9 18 10", "101", "364 606 101", "11 15050"];

test "a call through a local named like an unimported function calls the local" {
    (engine, _module) = compile_native(MAIN);
    assert get_func(engine, "local_call_probe", ctypes.c_int64)() == 101;
}

test "locals, parameters and imported functions bind as they did" {
    (engine, _module) = compile_native(MAIN);
    assert get_func(engine, "local_read_probe", ctypes.c_int64)() == 606;
    assert get_func(engine, "param_caller_probe", ctypes.c_int64)() == 11;
    assert get_func(engine, "imported_probe", ctypes.c_int64)() == 15050;
}

test "entry variables and globals named like unimported functions stay variables" {
    # Run as a program: reading a field through a function's address can
    # crash, and that must fail this test, not take the test process down.
    proc = subprocess.run(
        jac_command("run", os.path.join(FIXTURES, MAIN)),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , proc.stderr[-800:];
    assert "server codespace" not in proc.stderr , proc.stderr[-800:];
    lines = [
        line
        for line in proc.stdout.splitlines()
        if line.strip()
    ];
    assert lines == EXPECTED_LINES , proc.stdout;
}
