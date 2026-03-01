"""Static analysis pass tests."""

import os;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "static_analysis"
     );

test "unused variable produces warning" {
    file_path = os.path.join(FIXTURES, "unused_var.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("'x' is defined but never used" in w for w in warning_msgs) , f"Expected unused variable warning for 'x', got: {warning_msgs}";
}

test "used variables produce no warnings" {
    file_path = os.path.join(FIXTURES, "used_var.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unused_warnings = [
        w
        for w in warning_msgs
        if "defined but never used" in w
    ];
    assert len(unused_warnings) == 0 , f"Expected no unused variable warnings, got: {unused_warnings}";
}

test "skip patterns produce no warnings" {
    file_path = os.path.join(FIXTURES, "skip_patterns.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unused_warnings = [
        w
        for w in warning_msgs
        if "defined but never used" in w
    ];
    assert len(unused_warnings) == 0 , f"Expected no warnings for skip patterns, got: {unused_warnings}";
}

test "unreachable code after return" {
    file_path = os.path.join(FIXTURES, "unreachable_after_return.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("Unreachable" in w for w in warning_msgs) , f"Expected unreachable code warning, got: {warning_msgs}";
}

test "all reachable code produces no unreachable warnings" {
    file_path = os.path.join(FIXTURES, "all_reachable.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unreachable_warnings = [
        w
        for w in warning_msgs
        if "Unreachable" in w
    ];
    assert len(unreachable_warnings) == 0 , f"Expected no unreachable warnings, got: {unreachable_warnings}";
}
