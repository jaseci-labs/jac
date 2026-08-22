"""jac single-binary launcher: the headless CLI frontend over the fused
runtime core (`_fused.*` in the bundled native stdlib).

This executable carries the jaclang runtime + a private CPython as a
zstd-compressed payload appended after the image. On first run it
materializes that payload into a versioned cache dir, then dlopens the bundled
libpython and drives it in-process. Nothing Python is linked at build time --
the stub links only libc/libdl. No system Python, uv, or pip is required at
install or runtime.

Dispatch, before any Python bring-up:

  * a trailing `.jab` overlay (a `jac build --as binary` app) exports its
    [offset, len] so the CPython boot can mount the app image out of this
    binary, and the app then owns ALL of argv;
  * worker mode: re-invoked as a Python interpreter (multiprocessing re-spawns
    `sys.executable` with `-u -c ...`), behave exactly like `python`;
  * otherwise boot the jaclang CLI.
"""

import os;
import sys;
import from jaclang.runtimelib.fused.bringup { open_runtime }
import from jaclang.runtimelib.fused.materialize { overlay_for_path }
import from jaclang.runtimelib.fused.report { die }
import from _exec_native { executable_path }

"""The validated boot dance: pin `sys.executable` to THIS binary (under
embedding, getpath derives it from the program name, and anything that
re-spawns it must come back through this binary -- worker mode is what makes
multiprocessing re-spawns land on the right interpreter), install the lazy
`.jac` finder, then hand off to the jaclang CLI, which reads `sys.argv`."""
glob BOOT_SRC: str = (
         "import sys, os\n"
         + "_exe = os.environ.get('JAC_EXECUTABLE')\n"
         + "if _exe:\n"
         + "    sys.executable = _exe\n"
         + "    sys._base_executable = _exe\n"
         + "import _jac_finder as _jf\n"
         + "_jf.apply_dev_source_override()\n"
         + "_jf.install()\n"
         + "from jaclang.jac0core.cli_boot import start_cli\n"
         + "start_cli()\n"
     );

"""True if `a` (argv[1]) is a Python interpreter short flag.

A bare `-` or any single-dash short flag (`-c`, `-u`, `-m`, ...) means "act
like python" (worker re-spawns). `-h` is the ONE exception: it is a jac CLI
help alias, and a human types it expecting jac's help. No multiprocessing
worker ever re-spawns with `-h`. This dispatch is a CONTRACT: the jac CLI must
never accept a single-dash short flag (other than `-h`) as its first argument,
or interpreter re-spawns would be misrouted."""
def is_python_first_arg(a: str) -> bool {
    if a == "-h" {
        return False;
    }
    return len(a) >= 1 and a[0] == "-" and (len(a) == 1 or a[1] != "-");
}

with entry {
    exe_path = executable_path();
    if exe_path == "" {
        die("cannot resolve executable path");
    }

    # An overlay means this is an app binary: export its coordinates for
    # cli_boot's _run_bundled_app. A plain jac CLEARS any inherited
    # JAC_APP_OVERLAY_* -- those vars cross process boundaries, so an app
    # binary that shells out to a plain jac would otherwise leave the child
    # mis-slicing its own binary (the same discipline the interpreter config
    # follows for PYTHONHOME/PYTHONPATH, #7047).
    ovl = overlay_for_path(exe_path);
    if ovl is not None {
        os.environ["JAC_APP_OVERLAY_OFF"] = str(ovl.off);
        os.environ["JAC_APP_OVERLAY_LEN"] = str(ovl.length);
    } else {
        os.environ.pop("JAC_APP_OVERLAY_OFF", "");
        os.environ.pop("JAC_APP_OVERLAY_LEN", "");
    }

    emb = open_runtime(exe_path);

    argv = sys.argv;
    worker = len(argv) > 1 and is_python_first_arg(argv[1]);
    # A non-negative result means the interpreter handled a print-and-exit
    # flag (worker mode -h/-V/--help): exit with the code CPython requested,
    # never the boot path.
    requested = emb.init_interpreter(argv, worker);
    if requested >= 0 {
        sys.`exit(requested);
    }
    if worker {
        # Py_RunMain executes the parsed -c/-m/script and finalizes. Exit
        # codes are 8-bit (the OS masks them).
        sys.`exit(emb.api.Py_RunMain() & 255);
    }
    rc = emb.api.PyRun_SimpleString(BOOT_SRC);
    emb.api.Py_FinalizeEx();
    sys.`exit(0 if rc == 0 else 1);
}
