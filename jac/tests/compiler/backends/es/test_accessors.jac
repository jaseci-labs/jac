"""Accessor-backed fields use JavaScript properties rather than storage slots."""

import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import json;
import subprocess;
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.pipeline.contracts { PassIdentity }
import from jaclang.compiler.pipeline.executor { run_pass }

test "data constructors bind positional keyword and spread arguments in source order" {
    program = JacProgram();
    module = program.compile(
        "client_data_constructors.jac",
        use_str="""
obj Base { has first: int; }
obj Pair(Base) {
    has second: int = 20;
    has total: int { getter { return self.first + self.second; } }
}
obj Payload { has data: dict[str, int]; }
glob events: list[int] = [];
def mark(value: int) -> int { events.append(value); return value; }
def probe -> list[int] {
    positional = Pair(mark(1), mark(2));
    mixed = Pair(mark(3), second=mark(4));
    keywords = Pair(second=mark(6), first=mark(5));
    defaulted = Pair(7);
    values = [8, 9];
    spread = Pair(*values);
    payload = Payload({"value": 10});
    return events + [positional.total, mixed.total, keywords.total,
        defaulted.total, spread.total, payload.data["value"]];
}
""",
        options=CompileOptions(force_codespace="client", no_cgen=True)
    );
    run_pass(PassIdentity.EsastGenPass, module, program);
    assert not program.errors_had , "\n".join(
        str(error) for error in program.errors_had
    );
    result = subprocess.run(
        [
            "node",
            "-e",
            artifact_for(module).js + "\nconsole.log(JSON.stringify(probe()));"
        ],
        capture_output=True,
        text=True,
        timeout=10
    );
    assert result.returncode == 0 , result.stderr;
    assert json.loads(result.stdout.strip())
        == [1, 2, 3, 4, 6, 5, 3, 7, 11, 27, 17, 10];
}

test "client getters and setters preserve backing storage and annex bodies" {
    program = JacProgram();
    module = program.compile(
        "client_accessors.jac",
        use_str="""
obj Counter {
    has _value: int = 2;
    has value: int {
        getter;
        setter(value: int) { self._value = value * 2; }
    }
}
impl Counter.value.getter -> int { return self._value + 1; }
def probe -> list[int] {
    counter = Counter();
    before = counter.value;
    counter.value = 4;
    return [before, counter.value, counter._value];
}
""",
        options=CompileOptions(force_codespace="client", no_cgen=True)
    );
    run_pass(PassIdentity.EsastGenPass, module, program);
    assert not program.errors_had , "\n".join(
        str(error) for error in program.errors_had
    );
    result = subprocess.run(
        [
            "node",
            "-e",
            artifact_for(module).js + "\nconsole.log(JSON.stringify(probe()));"
        ],
        capture_output=True,
        text=True,
        timeout=10
    );
    assert result.returncode == 0 , result.stderr;
    assert json.loads(result.stdout.strip()) == [3, 9, 8];
}
