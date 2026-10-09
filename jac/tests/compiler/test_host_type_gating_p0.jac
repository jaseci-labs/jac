"""P0 type-environment tests: dom_types and js_globals are host-gated.

RN must stay DOM-free while still seeing js_globals — the falsifiable P0 check
from PLAN.md, exercised through the public checker rather than type_evaluator
internals.
"""

import os;
import tempfile;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }

def _error_codes(program: JacProgram) -> list[str] {
    return [
        e.code.code
        for e in program.errors_had
        if e.code is not None
    ];
}

def _compile_client_module(source: str, target: str) -> JacProgram {
    with tempfile.TemporaryDirectory(prefix='jac_host_gate_') as tmp {
        main_path = os.path.join(tmp, 'main.jac');
        toml_path = os.path.join(tmp, 'jac.toml');
        with open(main_path, 'w') as f {
            f.write(source);
        }
        with open(toml_path, 'w') as f {
            f.write(f'[plugin.client]\ntarget = "{target}"\n');
        }
        old_cwd = os.getcwd();
        try {
            os.chdir(tmp);
            program = JacProgram();
            mod = program.compile(main_path);
            assert mod is not None , (
                f"fixture failed to compile for target={target}:\n"
                + '\n'.join(str(e) for e in program.errors_had)
            );
            run_pass(TypeCheckPass, mod, program);
            return program;
        } finally {
            os.chdir(old_cwd);
        }
    }
}


test "react-native host exposes js_globals without DOM builtins" {
    src = (
        'def:pub App() -> JsxElement {\n'
        '    stamp = Date.now();\n'
        '    return <div>{stamp}</div>;\n'
        '}\n'
    );
    program = _compile_client_module(src, 'react-native');
    pretty = '\n'.join([e.pretty_print() for e in program.errors_had]);
    assert len(program.errors_had) == 0 , (
        "RN is a JS host: js_globals (Date) must type-check with zero RN-specific "
        f"type-layer code. Diagnostics:\n{pretty}"
    );
}

test "react-native host rejects document DOM surface" {
    src = (
        'def:pub App() -> JsxElement {\n'
        '    _ = document.body;\n'
        '    return <div/>;\n'
        '}\n'
    );
    program = _compile_client_module(src, 'react-native');
    pretty = '\n'.join([e.pretty_print() for e in program.errors_had]);
    assert len(program.errors_had) > 0 , (
        "RN must not merge dom_types into builtins; document must stay unknown. "
        f"Diagnostics:\n{pretty}"
    );
}

test "browser host still merges dom_types for document" {
    src = (
        'def:pub App() -> JsxElement {\n'
        '    document.body.classList.add("ready");\n'
        '    return <div/>;\n'
        '}\n'
    );
    program = _compile_client_module(src, 'web');
    pretty = '\n'.join([e.pretty_print() for e in program.errors_had]);
    assert len(program.errors_had) == 0 , (
        "browser host must provide DOM builtins for document APIs. "
        f"Diagnostics:\n{pretty}"
    );
}

test "pure server module keeps js_globals invisible" {
    src = 'def:pub server_only() -> int {\n' '    return Date.now();\n' '}\n';
    program = _compile_client_module(src, 'web');
    pretty = '\n'.join([e.pretty_print() for e in program.errors_had]);
    assert len(program.errors_had) > 0 , (
        "js_globals must be host-gated on sv/cpython hosts, not leak via "
        f"client target config. Diagnostics:\n{pretty}"
    );
    assert 'Date' in pretty or 'date' in pretty.lower() , (
        f"expected a Date-related diagnostic, got:\n{pretty}"
    );
}
