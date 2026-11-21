"""Compile-only tests for the CEF host binding: no CEF runtime, libpython-dev or
display needed, since `jac build --native` records needed libraries without loading them."""
import os;
import re;
import shutil;
import subprocess;
import sys;
import sysconfig;
import tempfile;
import from pathlib { Path }
import from jaclang.toolchains.desktop { stage_module }
import from tests.support { unit_source }

"""Locate the shipped CEF binding (under jaclang/client/)."""
def _cef_dir -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    probe = here;
    for _ in range(8) {
        cand = probe / "jaclang" / "client" / "targets" / "desktop" / "native" / "cef";
        if (cand / "cef.jac").exists() {
            return cand;
        }
        probe = probe.parent;
    }
    raise RuntimeError(
        "jaclang/client/targets/desktop/native/cef/cef.jac not found from " + str(here)
    );
}

"""Compile a CEF host with the binding staged beside it.

Returns (returncode, stderr, binary_bytes). binary_bytes is empty on failure.
"""
def _compile_cef_host(host_src: str) -> tuple[any, ...] {
    jac = shutil.which("jac") or "jac";
    tmp = tempfile.mkdtemp();
    try {
        stage_module(_cef_dir() / "cef.jac", Path(tmp));
        with open(os.path.join(tmp, "host.jac"), "w") as f {
            f.write(host_src);
        }
        result = subprocess.run(
            [jac, "build", "--native", "host.jac", "-o", "out"],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300
        );
        out = os.path.join(tmp, "out");
        data = b"";
        if os.path.exists(out) {
            with open(out, "rb") as bf {
                data = bf.read();
            }
        }
        return (result.returncode, result.stderr, data);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

"""The embedded-CPython CEF host (cef runtime model) links both libs."""
test "cef embedded-python host compiles and links libcef_dispatch and libpython" {
    if sys.platform != "linux" {
        testskip("CEF hosts link ELF shared objects; a Linux-only build");
    }
    soname = sysconfig.get_config_var("INSTSONAME")
        or f"libpython{sys.version_info.major}.{sys.version_info.minor}.so.1.0";
    stem = soname.split(".so")[0].encode();
    src = (
        "import sys;\n"
        "import from cef {\n"
        "    cef_execute_subprocess,\n"
        "    cef_queue_browser,\n"
        "    cef_startup,\n"
        "    cef_cleanup,\n"
        "}\n"
        f'import from "{soname}" {{\n'
        "    def Py_Initialize() -> None;\n"
        "    def Py_Finalize() -> None;\n"
        "    def PyRun_SimpleString(cmd: str) -> i32;\n"
        "}\n"
        "with entry {\n"
        "    code: i32 = cef_execute_subprocess();\n"
        "    if code >= 0 { sys.`exit(code); }\n"
        "    Py_Initialize();\n"
        "    PyRun_SimpleString(\"pass\");\n"
        "    cef_queue_browser(\"about:blank\", \"t\", 640, 480);\n"
        '    rc: i32 = cef_startup("", 1);\n'
        "    if rc != 1 { sys.`exit(1); }\n"
        "    Py_Finalize();\n"
        "    cef_cleanup();\n"
        "}\n"
    );
    (rc, err, data) = _compile_cef_host(src);
    assert rc == 0 , f"cef embedded-python host failed to compile:\n{err}";
    assert data[:4] == b"\x7fELF" , "output is not an ELF executable";
    assert b"libcef_dispatch.so" in data , "binary must link libcef_dispatch.so";
    assert stem in data , "binary must link the libpython soname";
    assert b"$ORIGIN" in data , "binary must carry an $ORIGIN runpath";
}

"""A host that uses the CefBrowser API links libcef_dispatch.so via $ORIGIN."""
test "cef binding host compiles and links libcef_dispatch.so" {
    if sys.platform != "linux" {
        testskip("CEF hosts link ELF shared objects; a Linux-only build");
    }
    src = (
        "import from cef { CefBrowser, new_cef_browser, cef_cleanup }\n"
        "with entry {\n"
        "    browser = new_cef_browser(\"about:blank\", \"t\", 640, 480);\n"
        "    if browser.browser_handle != 0 {\n"
        "        browser.run();\n"
        "        cef_cleanup();\n"
        "    }\n"
        "}\n"
    );
    (rc, err, data) = _compile_cef_host(src);
    assert rc == 0 , f"cef binding host failed to compile:\n{err}";
    assert data[:4] == b"\x7fELF" , "output is not an ELF executable";
    assert b"libcef_dispatch.so" in data , "binary must link libcef_dispatch.so";
    assert b"$ORIGIN" in data , "binary must carry an $ORIGIN runpath";
}

"""Regression: a bare `f;` name statement compiles but is a NO-OP in a native build;
a zero-arg function must be invoked as `f()`. The cef-subprocess helper and the
host's `_init_exe_dir` previously used the bare form, so they silently ran
nothing. This pins the runtime semantic the fix relies on: an entry-invoked
function actually executes."""
test "a native build invokes a zero-arg function called from entry with parentheses" {
    jac = shutil.which("jac") or "jac";
    tmp = tempfile.mkdtemp();
    try {
        with open(os.path.join(tmp, "m.jac"), "w") as f {
            f.write("import sys;\ndef _go { sys.`exit(7); }\nwith entry { _go(); }\n");
        }
        comp = subprocess.run(
            [jac, "build", "--native", "m.jac", "-o", "out"],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300
        );
        out = os.path.join(tmp, "out");
        assert comp.returncode == 0 and os.path.exists(out) , f"compile failed:\n{comp.stderr}";
        run = subprocess.run([out], capture_output=True, timeout=60);
        assert run.returncode == 7 , (
            f"entry did not invoke _go() (exit {run.returncode}); "
            "bare-name calls are no-ops in a native build -- use f()"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

"""JAC_CEF_DISABLE_GPU, the documented GPU fallback, must append the disable-gpu
switch; it was once a silent no-op that left the GPU process crashing."""
test "JAC_CEF_DISABLE_GPU wires through to --disable-gpu in cef_dispatch" {
    shim = (_cef_dir() / "cef_dispatch.c").read_text();
    block = re.search(r'env_set\("JAC_CEF_DISABLE_GPU"\).*?"disable-gpu"', shim, re.S);
    assert block is not None , "JAC_CEF_DISABLE_GPU must append the disable-gpu switch";
}

# String-only (no native build / CEF / display): the generated CEF host boots
# through the same host_boot runtime module as the webview host, in cef mode,
# and serves the sealed app image on the loopback server like the webview host.
test "cef host source boots the runtime host in cef mode with its app image" {
    import from jaclang.client.targets.desktop.cef_shell { _generate_host_source }
    src = _generate_host_source(
        "Title",
        800,
        600,
        "myapp",
        "/tmp/cache",
        plugin_configs={},
        program={"jab": "app.jab"},
        backend="embedded",
        dispatch_timeout_s=30.0,
        dispatch_max_queue=128,
        dispatch_debug=False
    );
    # One boot statement into host_boot, in cef mode, with the app image baked.
    assert "host_boot.boot(" in src;
    assert "cef" in src;
    assert "app.jab" in src;
    # The host reads the loopback port off the returned context.
    assert "_ctx.port" in src;
    # host_boot owns the cef wiring: it binds the plugin host to CEF and serves
    # the app image on the same loopback server the webview host uses.
    host_boot_src = unit_source(_cef_dir().parent / "host_boot.jac");
    assert "host.setup_cef(" in host_boot_src;
    assert "prepare_inprocess_runtime(" in host_boot_src;
    assert "transport_kind=\"listener\"" in host_boot_src;
}
