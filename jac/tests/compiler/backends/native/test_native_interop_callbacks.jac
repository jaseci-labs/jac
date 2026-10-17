"""Interop callback registration covers the boundary's real type surface.

The boundary analysis passes server signatures through verbatim, so the
registration side must accept what they name: void returns lower to a
restype-less CFUNCTYPE and width spellings (u32, i64, ...) are aliases of the
64-bit ABI types. Signatures no ctypes type can carry still refuse. And the
unregistered-callback stub must stop the process -- a CFUNCTYPE trampoline
reports a raised exception as unraisable and hands native a fabricated 0
return, so raising cannot stop the caller.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { jac_command }
import from jaclang.runtime.interop_bridge { register_py_callbacks, NativeCallback }

def _fake_register(name: str, address: int) {
    return;
}

test "void returns and sized scalar spellings register" {
    cbs: list[object] = [];
    register_py_callbacks(
        [
            NativeCallback(name="sink", ret_type="None", param_types=["int", "u32"]),
            NativeCallback(name="wide", ret_type="f64", param_types=["i8", "usize"])
        ],
        {},
        cbs,
        _fake_register
    );
    assert len(cbs) == 2 , "every marshallable signature must register";
    assert cbs[0](1, 2) is None , "a void callback returns None, not a fabricated 0";
}

test "signatures no ctypes type can carry still refuse" {
    for bad in [
        NativeCallback(name="bad", ret_type="None", param_types=["list[int]"]),
        NativeCallback(name="bad", ret_type="int | str", param_types=[]),
        NativeCallback(name="bad", ret_type="None", param_types=["None"])
    ] {
        refused = False;
        try {
            register_py_callbacks([bad], {}, [], _fake_register);
        } except RuntimeError {
            refused = True;
        }
        assert refused , (
            f"{bad.ret_type} / {bad.param_types} cannot cross the FFI boundary"
        );
    }
}

test "calling an unregistered callback stops the process, not a 0 return" {
    tmp = tempfile.mkdtemp(prefix="jac_unregistered_cb_");
    script = os.path.join(tmp, "ghost_call.jac");
    with open(script, "w") as f {
        f.write(
            "import from jaclang.runtime.interop_bridge {\n"
                + "    register_py_callbacks,\n"
                + "    NativeCallback\n"
                + "}\n"
                + "def reg(name: str, address: int) {\n"
                + "    return;\n"
                + "}\n"
                + "with entry {\n"
                + "    cbs: list[object] = [];\n"
                + "    register_py_callbacks(\n"
                + "        [NativeCallback(name='ghost', ret_type='int', param_types=[])],\n"
                + "        {},\n"
                + "        cbs,\n"
                + "        reg\n"
                + "    );\n"
                + "    cb = cbs[0];\n"
                + "    cb();\n"
                + "    print('UNREACHABLE: native would read a fabricated 0');\n"
                + "}\n"
        );
    }
    result = subprocess.run(
        jac_command("run", script), capture_output=True, text=True, timeout=300
    );
    assert "UNREACHABLE" not in result.stdout , (
        "the trampoline must not hand native a fabricated 0 and carry on"
    );
    assert result.returncode != 0 , result.stderr;
    assert "ghost" in result.stderr , (
        f"the abort must name the unregistered function, got: {result.stderr[:300]}"
    );
}
