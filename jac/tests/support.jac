"""Shared path anchor for the test suite.
Tests must not assume the editable-install layout (`jaclang.__file__` sitting
next to the repo `tests/`): under the single `jac` binary, jaclang lives in the
sealed runtime cache, not beside the tests. This module resolves the repo root
from its OWN location inside `tests/`, so every test imports one stable anchor
instead of re-deriving it with a `Path(__file__).resolve().parents` walk.

Imported as `from tests.support`, which resolves identically under the single
`jac` binary and a source checkout (same mechanism as `tests.fixtures_list`).
"""

import ctypes;

import from pathlib { Path }

# `tests/`: the directory holding this file.
glob TESTS_DIR: str = str(Path(__file__).resolve().parent),
     # Repo root (the `jac/` dir): the parent of `tests/`.
     JAC_ROOT: str = str(Path(__file__).resolve().parent.parent);

"""CompileOptions that force a fixture into the native codespace.

The retired .na.jac marker used to do this from the filename; tests that
compile a fixture and expect a JIT engine now state the mandate explicitly.
Forced placement keeps lowering failures loud (no server demotion), exactly
like the old suffix.
"""
def native_force_opts -> any {
    import from jaclang.jac0core.compile_options { CompileOptions }
    return CompileOptions(
        type_check=False, force_codespace='native', force_target_program=True
    );
}


class JacStrABI(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("root", ctypes.c_void_p),
        ("data", ctypes.c_void_p)
    ];
}

def native_str_func(
    eng: object, name: str, restype: type | None, *argtypes: type
) -> object {
    # descriptor-ABI JIT getter shared by native tests: a c_char_p
    # spelling means a Jac str (the by-value {root, data, len}
    # descriptor); LLVM decomposes the by-value param into three scalar
    # slots, so str args pass as (root, data, len) built via
    # jac_str_new, and str returns read back as a two-pointer pair with
    # the payload NUL-bounded at data
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    real_res = JacStrABI if restype == ctypes.c_char_p else restype;
    str_slots: list = [];
    real_args: list = [];
    for a in argtypes {
        if a == ctypes.c_char_p {
            str_slots.append(True);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_int64);
        } else {
            str_slots.append(False);
            real_args.append(a);
        }
    }
    raw = ctypes.CFUNCTYPE(real_res, *real_args)(addr);
    sn_addr = 0;
    for sn in ("jac_str_new", "__jac_str_new") {
        try {
            sn_addr = eng.get_function_address(sn);
        } except Exception {
            sn_addr = 0;
        }
        if sn_addr {
            break;
        }
    }
    mkstr = (
        ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(sn_addr)
            if sn_addr
            else None
    );
    def _call(*args: any) -> any {
        c_args: list = [];
        _keep: list = [];
        for (a, is_str) in zip(args, str_slots) {
            if is_str {
                b = a.encode("utf-8") if isinstance(a, str) else a;
                if mkstr is not None {
                    p = mkstr(b, len(b));
                } else {
                    _buf = ctypes.create_string_buffer(b);
                    _keep.append(_buf);
                    p = ctypes.cast(_buf, ctypes.c_void_p).value;
                }
                c_args.append(p);
                c_args.append(p);
                c_args.append(len(b));
            } else {
                c_args.append(a);
            }
        }
        r = raw(*c_args);
        if real_res is JacStrABI {
            if not r.data {
                return b"";
            }
            return ctypes.string_at(r.data);
        }
        return r;
    }
    return _call;
}


"""Fetch an object's persisted state by id from a compiled Jac program.

Runs under the system context (no user root), so access checks always pass.
Previously lived in `tests/conftest.py`, which existed only for pytest.
"""
def get_object(filename: str, id: str, main: bool = True) -> dict[(str, any)] {
    import from jaclang.cli.commands.cli_helpers { proc_file }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    (base, mod, mach) = proc_file(filename);
    try {
        Jac.jac_import(
            target=mod, base_path=base, override_name=("__main__" if main else None)
        );
        found = Jac.get_object(id);
        if not found {
            raise ValueError(f"Object with id {id} not found.");
        }
        return found.__jac__.__getstate__();
    } finally {
        mach.close();
    }
}


"""Shared bun sv e2e helpers (spawn/poll/post) used by the bun e2e tests."""

def resolved_bun -> (str | None) {
    # Use the same bun the production spawn path resolves (jac-managed
    # installer), falling back to PATH so tests still run on dev boxes.
    import from jaclang.runtimelib.client { get_bun }
    return get_bun();
}

def bun_runtime_available -> bool {
    import subprocess;
    try {
        proc = subprocess.run(
            [resolved_bun() or 'bun', '--version'],
            capture_output=True,
            text=True,
            timeout=10
        );
        return proc.returncode == 0;
    } except Exception {
        return False;
    }
}

def write_service(tmp: str, name: str, source: str) -> str {
    import os;
    path = os.path.join(tmp, f"{name}.jac");
    with open(path, 'w') as f {
        f.write(source);
    }
    return path;
}

def write_sv_project(tmp: str, module_name: str, source: str) -> None {
    import os;
    with open(os.path.join(tmp, f'{module_name}.jac'), 'w') as f {
        f.write(source);
    }
    with open(os.path.join(tmp, 'jac.toml'), 'w') as f {
        f.write(
            '[project]\n'
                + f'name = "{module_name}"\n'
                + f'entry-point = "{module_name}.jac"\n'
        );
    }
}

def spawn_bun_artifact(artifact: str, cwd: str, port: int, info: any) -> any {
    import os;
    import subprocess;
    env = os.environ.copy();
    env['PORT'] = str(port);
    env['JAC_PG_HOST'] = info.host or '127.0.0.1';
    env['JAC_PG_PORT'] = str(info.port);
    env['JAC_PG_USER'] = info.user;
    env['JAC_PG_DATABASE'] = info.database;
    if info.unix_socket_dir {
        env['JAC_PG_SOCKET'] = info.unix_socket_dir;
    }
    return subprocess.Popen(
        [resolved_bun() or 'bun', artifact],
        cwd=cwd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    );
}

def wait_service_ready(port: int, expect_substring: str = '') -> bool {
    import subprocess;
    import time;
    url = f'http://127.0.0.1:{port}/functions';
    for _ in range(40) {
        ping = subprocess.run(
            ['curl', '-sf', url], capture_output=True, text=True, timeout=2
        );
        if ping.returncode == 0
            and (not expect_substring or expect_substring in ping.stdout) {
            return True;
        }
        time.sleep(0.25);
    }
    return False;
}

def post_json(port: int, path: str, body: str) -> tuple[(bool, dict)] {
    import json;
    import subprocess;
    call = subprocess.run(
        [
            'curl',
            '-sf',
            '-X',
            'POST',
            f'http://127.0.0.1:{port}{path}',
            '-H',
            'Content-Type: application/json',
            '-d',
            body
        ],
        capture_output=True,
        text=True,
        timeout=10
    );
    if call.returncode != 0 {
        return (False, {});
    }
    return (True, json.loads(call.stdout or '{}'));
}

def stop_process(proc: any) -> None {
    import subprocess;
    proc.terminate();
    try {
        proc.`wait(timeout=5);
    } except subprocess.TimeoutExpired {
        proc.kill();
    }
}
