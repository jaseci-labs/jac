"""Subprocess worker that executes a single Jac snippet and emits a JSON result.

Run as its own process by ``CompilerBridge.run_snippet``. Executing untrusted Jac
in a child process (rather than in the long-lived MCP server) is what makes
``run_jac`` safe to call repeatedly:

* All global Jac runtime state created by the run -- the program ``mod.hub``,
  ``JacRuntime.loaded_modules``, native caches, polluted ``sys.modules`` -- dies
  with the process, so the server's memory stays flat across calls.
* A hung snippet (e.g. ``while True {}``) is killable from the parent via the
  process group; CPython cannot kill an in-process thread, so an in-process
  timeout could never actually stop the work.

Invocation::

    python _run_worker.py <jac_path> <out_path> [entrypoint]

The snippet's own stdout/stderr are captured in-process and reported inside the
JSON written to ``out_path``; the worker's real stdout/stderr are reserved for
crash diagnostics only.
"""

import contextlib
import io
import json
import os
import sys


def _close_mach(mach: object) -> None:
    """Best-effort close. A failure here (e.g. a broken plugin context in the
    host environment) must never discard the snippet's own result, so swallow
    the exception -- the process is about to exit anyway and reclaim all state.
    """
    with contextlib.suppress(Exception):
        mach.close()


def main() -> None:
    jac_path = sys.argv[1]
    out_path = sys.argv[2]
    # The parent always passes entrypoint (possibly "") as argv[3]; default it
    # defensively in case the worker is invoked manually.
    entrypoint = sys.argv[3] if len(sys.argv) > 3 else ""

    from jaclang.jac0core.constructs import WalkerArchetype
    from jaclang.jac0core.runtime import JacRuntime as Jac

    base, mod_file = os.path.split(jac_path)
    base = base or "./"
    mod_name = mod_file[:-4]  # strip ".jac"

    captured_out = io.StringIO()
    captured_err = io.StringIO()
    old_stdout, old_stderr, old_argv = sys.stdout, sys.stderr, sys.argv
    sys.stdout = captured_out
    sys.stderr = captured_err
    sys.argv = [jac_path]

    result: dict = {}
    mach = None
    try:
        if not Jac.get_base_path_dir():
            Jac.set_base_path(base)
        mach = Jac.create_j_context(
            user_root=None,
            base_path_dir=Jac.get_base_path_dir(),
            full_target_path=Jac.get_full_target_path(),
        )
        Jac.set_context(mach)

        try:
            if entrypoint:
                ret = Jac.jac_import(
                    target=mod_name, base_path=base, override_name="__main__"
                )
                if ret:
                    (loaded_mod,) = ret
                    if loaded_mod and hasattr(loaded_mod, entrypoint):
                        archetype = getattr(loaded_mod, entrypoint)()
                        if isinstance(
                            archetype, WalkerArchetype
                        ) and Jac.check_read_access(mach.entry_node):
                            Jac.spawn(mach.entry_node.archetype, archetype)
                    else:
                        sys.stderr.write(
                            f"Entrypoint '{entrypoint}' not found in module\n"
                        )
            else:
                Jac.jac_import(
                    target=mod_name,
                    base_path=base,
                    override_name="__main__",
                    lng="jac",
                )

            reports = []
            if getattr(mach, "reports", None):
                for r in mach.reports:
                    try:
                        reports.append(str(r))
                    except Exception:
                        reports.append(repr(r))

            # Build the result BEFORE closing the context. A failure in
            # mach.close() (e.g. a broken plugin in the host env) must not
            # discard the snippet's own output.
            result = {
                "stdout": captured_out.getvalue(),
                "stderr": captured_err.getvalue(),
                "exit_code": 0,
            }
            if reports:
                result["reports"] = reports
        except SystemExit as se:
            exit_code = se.code if se.code is not None else 0
            result = {
                "stdout": captured_out.getvalue(),
                "stderr": captured_err.getvalue(),
                "exit_code": int(exit_code) if isinstance(exit_code, int) else 1,
            }
        except Exception as e:
            result = {
                "stdout": captured_out.getvalue(),
                "stderr": captured_err.getvalue(),
                "exit_code": 1,
                "error": str(e),
            }
        # Close once, best-effort, after every result path is settled.
        if mach is not None:
            _close_mach(mach)
    finally:
        sys.stdout, sys.stderr, sys.argv = old_stdout, old_stderr, old_argv

    with open(out_path, "w") as f:
        json.dump(result, f)


if __name__ == "__main__":
    main()
