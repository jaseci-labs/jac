"""Dependency-free tests for the Jac-native CEF binding.

Compile-only: these need ONLY the jac toolchain - no CEF runtime, no
libpython-dev, no display. `jac nacompile` records the needed shared libraries
(DT_NEEDED) and an $ORIGIN runpath without dlopening them, so a host that binds
libcef_dispatch.so (or libpython) links cleanly with nothing installed. This
catches binding-signature drift, wrong/missing externs, wrong soname, and
codegen regressions. The webview binding has a sibling suite in
`test_desktop_binding.jac`.
"""
import os;
import re;
import shutil;
import subprocess;
import sysconfig;
import tempfile;
import from pathlib { Path }

"""Locate the shipped CEF binding (under jaclang/runtimelib/client/)."""
def _cef_dir -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    probe = here;
    for _ in range(8) {
        cand = probe / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native" / "cef";
        if (cand / "cef.na.jac").exists() {
            return cand;
        }
        probe = probe.parent;
    }
    raise RuntimeError(
        "jaclang/runtimelib/client/targets/desktop/native/cef/cef.na.jac not found from " + str(
            here
        )
    );
}

"""Compile a CEF host with the binding staged beside it.

Returns (returncode, stderr, binary_bytes). binary_bytes is empty on failure.
"""
def _compile_cef_host(host_src: str) -> tuple {
    jac = shutil.which("jac") or "jac";
    tmp = tempfile.mkdtemp();
    try {
        shutil.copy2(str(_cef_dir() / "cef.na.jac"), os.path.join(tmp, "cef.na.jac"));
        with open(os.path.join(tmp, "host.na.jac"), "w") as f {
            f.write(host_src);
        }
        result = subprocess.run(
            [jac, "nacompile", "host.na.jac", "-o", "out"],
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
    soname = sysconfig.get_config_var("INSTSONAME") or "libpython3.12.so.1.0";
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
        "    if code >= 0 { sys.exit(code); }\n"
        "    Py_Initialize();\n"
        "    PyRun_SimpleString(\"pass\");\n"
        "    cef_queue_browser(\"about:blank\", \"t\", 640, 480);\n"
        '    rc: i32 = cef_startup("", 1);\n'
        "    if rc != 1 { sys.exit(1); }\n"
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

"""Regression: a bare `f;` name statement compiles but is a NO-OP in nacompile;
a zero-arg function must be invoked as `f()`. The cef-subprocess helper and the
host's `_init_exe_dir` previously used the bare form, so they silently ran
nothing. This pins the runtime semantic the fix relies on: an entry-invoked
function actually executes."""
test "nacompile invokes a zero-arg function called from entry with parentheses" {
    jac = shutil.which("jac") or "jac";
    tmp = tempfile.mkdtemp();
    try {
        with open(os.path.join(tmp, "m.na.jac"), "w") as f {
            f.write("import sys;\ndef _go { sys.exit(7); }\nwith entry { _go(); }\n");
        }
        comp = subprocess.run(
            [jac, "nacompile", "m.na.jac", "-o", "out"],
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
            "bare-name calls are no-ops in nacompile -- use f()"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

"""Regression: the CEF subprocess + dispatch lifecycle functions must be invoked
with `()`. Guards against re-introducing the bare-name no-op that left the
cef-subprocess entry and `g_exe_dir_buf` initialization dead."""
test "cef native lifecycle functions are invoked with parentheses" {
    cef = _cef_dir();
    sub = (cef / "cef_subprocess.na.jac").read_text();
    disp = (cef / "cef_dispatch.na.jac").read_text();
    # Required paren-form invocations.
    for needle in [
        "_subprocess_main()",
        "_subprocess_bootstrap()",
        "cef_main_args_create()"
    ] {
        assert needle in sub , f"cef_subprocess.na.jac must invoke {needle}";
    }
    assert "_init_exe_dir()" in disp , "cef_dispatch.na.jac must invoke _init_exe_dir()";
    # No bare no-op invocation (name followed directly by `;`, not `(`).
    checks = [
        (
            "cef_subprocess.na.jac",
            sub,
            ["_subprocess_main", "_subprocess_bootstrap", "cef_main_args_create"]
        ),
        ("cef_dispatch.na.jac", disp, ["_init_exe_dir"]),

    ];
    for (fname, body, fns) in checks {
        for fn in fns {
            bare = re.search(r"(?:^|[=({;,\s])" + fn + r"\s*;", body, re.M);
            assert bare is None , f"{fn} is invoked without parentheses (no-op) in {fname}";
        }
    }
}

"""Regression: JAC_CEF_DISABLE_GPU is the documented GPU fallback (QA.md §3/§5,
notes-app/README.md). It must append `disable-gpu` in `_on_before_cmdline`.
Previously the env var was a silent no-op -- the GPU process still spawned and
crashed on hosts with no usable GL. Pins the wiring so it cannot regress."""
test "JAC_CEF_DISABLE_GPU wires through to --disable-gpu in cef_dispatch" {
    cef = _cef_dir();
    disp = (cef / "cef_dispatch.na.jac").read_text();
    # The env var must be read inside the cmdline handler ...
    assert 'cef_dispatch_getenv_set("JAC_CEF_DISABLE_GPU")' in disp , (
        "cef_dispatch.na.jac must read JAC_CEF_DISABLE_GPU in _on_before_cmdline"
    );
    # ... and it must append the disable-gpu switch (not just rely on HEADLESS).
    block = re.search(
        r'cef_dispatch_getenv_set\("JAC_CEF_DISABLE_GPU"\).*?disable-gpu', disp, re.S
    );
    assert block is not None , (
        "JAC_CEF_DISABLE_GPU branch must append the \"disable-gpu\" switch"
    );
}

# String-only (no nacompile / CEF / display): the generated CEF host boots
# through the same host_boot runtime module as the webview host, in cef mode.
# The Phase J4 (#6596) in-process sv backend + sv_bridge wiring live in
# host_boot._start_loopback's cef branch, not in generated strings.
test "cef host source boots inprocess and wires the sv bridge (#6596)" {
    import from jaclang.runtimelib.client.targets.desktop.cef_desktop_target {
        _generate_host_source
    }
    src = _generate_host_source(
        "Title", 800, 600, "myapp", "/tmp/cache", {}, "main.jac", 30.0, 128, False
    );
    # One boot statement into host_boot, in cef mode, with the staged entry baked.
    assert "host_boot.boot(" in src;
    assert "cef" in src;
    assert "main.jac" in src;
    # The host reads the loopback port off the returned context.
    assert "_ctx.port" in src;
    # The cef branch of host_boot owns the sv bridge + in-process boot wiring.
    host_boot_src = (_cef_dir().parent / "host_boot.jac").read_text();
    assert "sv_bridge=inprocess_forward" in host_boot_src;
    assert "inprocess_boot(" in host_boot_src;
    assert "forward as inprocess_forward" in host_boot_src;
    assert "boot as inprocess_boot" in host_boot_src;
}
