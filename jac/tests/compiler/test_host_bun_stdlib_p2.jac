"""P2 stdlib coverage for bun-hosted sv services.

PLAN.md Priority 2 extends JS stdlib module coverage for real service imports:
json, datetime, math, os, random, hashlib, uuid, time, urllib.
Each must compile for bun server modules without E5017 blocks_codegen failures.
"""

import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compiler { run_pass }
import from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }


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
            mod = program.compile(main_path);
            assert mod is not None , (
                "fixture failed to compile:\n"
                + '\n'.join(str(e) for e in program.errors_had)
            );
            run_pass(EsastGenPass, mod, program);
            return (program, mod);
        } finally {
            os.chdir(old_cwd);
        }
    }
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
    assert compiled.gen.js and compiled.gen.js.strip() , (
        f"stdlib {mod!r} must emit JS for bun services"
    );
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
