"""`flow` returns a Task[T], which is the concurrent.futures.Future the
runtime hands back: it is accepted wherever a Future is expected, and `wait`
on it still yields T."""
import from jaclang.compiler.driver.program { JacProgram }

glob SOURCE: str = (
         "import from concurrent.futures { Future }\n"
         + "def work -> int { return 1; }\n"
         + "obj Holder {\n"
         + "    has fut: Future | None = None;\n"
         + "    def start { self.fut = flow work(); }\n"
         + "}\n"
         + "def run -> int {\n"
         + "    plain: Future = flow work();\n"
         + "    task = flow work();\n"
         + "    got: int = wait task;\n"
         + "    return got + plain.result();\n"
         + "}\n"
     );

test "a flow handle is a Future and wait yields the flowed value" {
    prog = JacProgram();
    prog.compile(file_path="flow_task_type.jac", use_str=SOURCE, no_cgen=True);
    errors = [e.pretty_print() for e in prog.errors_had];
    assert not errors , errors;
}

test "wait on a flow handle keeps the flowed value's type" {
    prog = JacProgram();
    prog.compile(
        file_path="flow_task_wait.jac",
        use_str="def work -> int { return 1; }\n"
            + "def run -> str {\n"
            + "    task = flow work();\n"
            + "    got: str = wait task;\n"
            + "    return got;\n"
            + "}\n",
        no_cgen=True
    );
    errors = [e.pretty_print() for e in prog.errors_had];
    assert any("Cannot assign int to str" in e for e in errors) , errors;
}
