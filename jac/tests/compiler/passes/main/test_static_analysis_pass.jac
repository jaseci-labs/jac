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

test "impl file warnings: undefined name and unreachable code are reported" {
    file_path = os.path.join(FIXTURES, "impl_checks.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("'bad_name' may be undefined" in w for w in warning_msgs) , f"Expected undefined name warning from impl file, got: {warning_msgs}";
    assert any("Unreachable" in w for w in warning_msgs) , f"Expected unreachable code warning from impl file, got: {warning_msgs}";
}

test "by-llm ability params produce no unused warnings" {
    file_path = os.path.join(FIXTURES, "genai_ability_params.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unused_warnings = [
        w
        for w in warning_msgs
        if "defined but never used" in w
    ];
    assert len(unused_warnings) == 0 , f"Expected no unused warnings for by-llm params, got: {unused_warnings}";
}

test "classmethod and staticmethod on obj produce warnings" {
    file_path = os.path.join(FIXTURES, "classmethod_on_obj.jac");
    prog = JacProgram();
    prog.compile(file_path);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("@classmethod" in w and "'obj'" in w for w in warning_msgs) , f"Expected @classmethod warning for obj, got: {warning_msgs}";
    assert any("@staticmethod" in w and "'obj'" in w for w in warning_msgs) , f"Expected @staticmethod warning for obj, got: {warning_msgs}";
}

test "classmethod and staticmethod on class produce no warnings" {
    file_path = os.path.join(FIXTURES, "classmethod_on_class.jac");
    prog = JacProgram();
    prog.compile(file_path);
    warning_msgs = [str(w) for w in prog.warnings_had];
    decorator_warnings = [
        w
        for w in warning_msgs
        if "@classmethod" in w or "@staticmethod" in w
    ];
    assert len(decorator_warnings) == 0 , f"Expected no decorator warnings for class, got: {decorator_warnings}";
}

test "classmethod on node warns with correct archetype name" {
    file_path = os.path.join(FIXTURES, "classmethod_on_node.jac");
    prog = JacProgram();
    prog.compile(file_path);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("@classmethod" in w and "'node'" in w for w in warning_msgs) , f"Expected @classmethod warning mentioning 'node', got: {warning_msgs}";
}
