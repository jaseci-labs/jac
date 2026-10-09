"""P2 stdlib coverage for bun-hosted sv services.

PLAN.md Priority 2 extends JS stdlib module coverage for real service imports:
json, datetime, math, os, random, hashlib, uuid, time, urllib.
Each must compile for bun server modules without E5017 blocks_codegen failures.
"""

import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.codeinfo { cl_stdlib_root }
import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }


glob _P2_STDLIB_MODULES: tuple = (
         'json',
         'datetime',
         'math',
         'os',
         'random',
         'hashlib',
         'uuid',
         'time',
         'urllib'
     );


def _blocks_codegen_errors(program: JacProgram) -> list[str] {
    out: list[str] = [];
    for err in program.errors_had {
        if err.code is not None and err.code.blocks_codegen {
            out.append(str(err));
        }
    }
    return out;
}


def _compile_bun_service(source: str) -> tuple[JacProgram, any] {
    with tempfile.TemporaryDirectory(prefix='jac_bun_stdlib_') as tmp {
        main_path = os.path.join(tmp, 'service.jac');
        toml_path = os.path.join(tmp, 'jac.toml');
        with open(main_path, 'w') as f {
            f.write(source);
        }
        with open(toml_path, 'w') as f {
            f.write(
                '[project]\n'
                    + 'name = "bun-stdlib"\n'
                    + 'entry-point = "service.jac"\n\n'
                    + '[plugin.client]\n'
                    + 'target = "bun"\n'
            );
        }
        old_cwd = os.getcwd();
        try {
            os.chdir(tmp);
            program = JacProgram();
            mod = program.compile(
                main_path, options=CompileOptions(force_codespace='client')
            );
            assert mod is not None , (
                "fixture failed to compile:\n"
                + '\n'.join(str(e) for e in program.errors_had)
            );
            if not (mod.gen is not None and mod.gen.js) {
                run_pass(EsastGenPass, mod, program);
            }
            return (program, mod);
        } finally {
            os.chdir(old_cwd);
        }
    }
}


def _service_fn_name(mod: str) -> str {
    if mod == 'json' {
        return 'encode';
    }
    if mod == 'datetime' {
        return 'now_iso';
    }
    if mod == 'math' {
        return 'hypot';
    }
    if mod == 'os' {
        return 'cwd';
    }
    if mod == 'random' {
        return 'coin';
    }
    if mod == 'hashlib' {
        return 'digest';
    }
    if mod == 'uuid' {
        return 'new_id';
    }
    if mod == 'time' {
        return 'epoch';
    }
    if mod == 'urllib' {
        return 'enc';
    }
    return 'probe';
}


def _service_using(mod: str) -> str {
    if mod == 'json' {
        return (
            'import json;\n'
            + 'def:pub encode(payload: dict) -> str {\n'
            + '    return json.dumps(payload);\n'
            + '}\n'
        );
    }
    if mod == 'datetime' {
        return (
            'import from datetime { datetime }\n'
            + 'def:pub now_iso() -> str {\n'
            + '    return datetime.now().isoformat();\n'
            + '}\n'
        );
    }
    if mod == 'math' {
        return (
            'import math;\n'
            + 'def:pub hypot(a: float, b: float) -> float {\n'
            + '    return math.hypot(a, b);\n'
            + '}\n'
        );
    }
    if mod == 'os' {
        return (
            'import os;\n'
            + 'def:pub cwd() -> str {\n'
            + '    return os.getcwd();\n'
            + '}\n'
        );
    }
    if mod == 'random' {
        return (
            'import random;\n'
            + 'def:pub coin() -> int {\n'
            + '    return random.randint(0, 1);\n'
            + '}\n'
        );
    }
    if mod == 'hashlib' {
        return (
            'import hashlib;\n'
            + 'def:pub digest(text: str) -> str {\n'
            + '    return hashlib.sha256(text.encode()).hexdigest();\n'
            + '}\n'
        );
    }
    if mod == 'uuid' {
        return (
            'import uuid;\n'
            + 'def:pub new_id() -> str {\n'
            + '    return str(uuid.uuid4());\n'
            + '}\n'
        );
    }
    if mod == 'time' {
        return (
            'import time;\n'
            + 'def:pub epoch() -> int {\n'
            + '    return int(time.time());\n'
            + '}\n'
        );
    }
    if mod == 'urllib' {
        return (
            'import from urllib.parse { quote }\n'
            + 'def:pub enc(text: str) -> str {\n'
            + '    return quote(text);\n'
            + '}\n'
        );
    }
    return f'import {mod};\n' + 'def:pub probe() -> None { pass; }\n';
}


def _assert_bun_stdlib_compiles(mod: str) {
    (program, compiled) = _compile_bun_service(_service_using(mod));
    blockers = _blocks_codegen_errors(program);
    assert len(blockers) == 0 , (
        f"stdlib {mod!r} must be available on bun-hosted services in P2. "
        + f"Diagnostics:\n"
        + '\n'.join(blockers)
    );
    js = compiled.gen.js or '';
    fn = _service_fn_name(mod);
    assert f'function {fn}(' in js , (
        f"stdlib {mod!r} service must emit the {fn!r} function body for bun "
        + "(not just the endpoint-effects preamble)"
    );
}


def _compile_cl_stdlib_js(mod: str) -> str {
    stdlib_root = cl_stdlib_root();
    assert stdlib_root is not None , "cl_stdlib root must be available for bun stdlib tests";
    if mod == 'urllib' {
        path = os.path.join(stdlib_root, 'urllib', 'parse.jac');
    } else {
        path = os.path.join(stdlib_root, mod + '.jac');
    }
    program = JacProgram();
    compiled = program.compile(path);
    assert compiled is not None , (
        f"failed to compile cl_stdlib {mod!r}:\n"
        + '\n'.join(str(e) for e in program.errors_had)
    );
    run_pass(EsastGenPass, compiled, program);
    js = compiled.gen.js or '';
    assert js.strip() , f"cl_stdlib {mod!r} must emit JS";
    return js;
}


def _assert_real_js_impl(mod: str) {
    js = _compile_cl_stdlib_js(mod);
    if mod == 'time' or mod == 'datetime' {
        assert 'Date.now' in js , f"{mod} must read wall clock via Date.now()";
        assert '1700000000' not in js , f"{mod} must not use compile stub epoch";
    }
    if mod == 'os' {
        # Delegation, not a stub: the emitted body must reach the host
        # process object (aliased locals are fine, 'process' must appear).
        assert 'globalThis.process' in js and '.cwd()' in js , (
            "os.getcwd must delegate to the host process object"
        );
    }
    if mod == 'random' {
        assert ('Math.random' in js or 'getRandomValues' in js) , "random.randint must use Math.random or crypto.getRandomValues";
    }
    if mod == 'hashlib' {
        assert 'CryptoHasher' in js , "hashlib.sha256 must use Bun.CryptoHasher";
        assert '(i * 7 + len' not in js , "hashlib must not use fake digest stub";
    }
    if mod == 'uuid' {
        assert ('randomUUID' in js or 'Math.random' in js) , "uuid.uuid4 must use crypto.randomUUID or Math.random fallback";
        assert '(i * 11 + 5)' not in js , "uuid must not use deterministic fake hex";
    }
}


test "bun server module compiles stdlib import json without codegen blockers" {
    _assert_bun_stdlib_compiles('json');
}

test "bun server module compiles stdlib import datetime without codegen blockers" {
    _assert_bun_stdlib_compiles('datetime');
}

test "bun server module compiles stdlib import math without codegen blockers" {
    _assert_bun_stdlib_compiles('math');
}

test "bun server module compiles stdlib import os without codegen blockers" {
    _assert_bun_stdlib_compiles('os');
}

test "bun server module compiles stdlib import random without codegen blockers" {
    _assert_bun_stdlib_compiles('random');
}

test "bun server module compiles stdlib import hashlib without codegen blockers" {
    _assert_bun_stdlib_compiles('hashlib');
}

test "bun server module compiles stdlib import uuid without codegen blockers" {
    _assert_bun_stdlib_compiles('uuid');
}

test "bun server module compiles stdlib import time without codegen blockers" {
    _assert_bun_stdlib_compiles('time');
}

test "bun server module compiles stdlib import urllib without codegen blockers" {
    _assert_bun_stdlib_compiles('urllib');
}

test "bun cl_stdlib time datetime os random hashlib uuid emit real JS builtins" {
    for mod in ('time', 'datetime', 'os', 'random', 'hashlib', 'uuid') {
        _assert_real_js_impl(mod);
    }
}
