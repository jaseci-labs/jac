"""Jac sitecustomize: shipped in the single binary's ``site/``.

Python imports ``sitecustomize`` during site initialization in BOTH the jac CLI
(``Py_Initialize`` + boot) and bare python mode (``jac -m <tool>`` via
``Py_BytesMain``). That makes it the one place to put the current project's
``.jac/venv`` on ``sys.path`` so it is visible to both -- the CLI's plugin
enumeration and a ``jac -m mkdocs``/``jac -m pytest`` that needs a tool
installed into the project venv.

Kept deliberately tiny and jaclang-free so non-Jac Python startup pays ~nothing.
"""

with __import__("contextlib").suppress(Exception):
    import _jac_finder

    # Project venv (deps + plugins) onto sys.path for both jac CLI and `jac -m`.
    _jac_finder.add_project_venv_to_path()
    # Lazy .jac finder so `jac -m <jac_module>` can import .jac in python mode
    # too. install() is idempotent (the CLI's BOOT_SRC calls it as well) and the
    # finder stays cheap until the first .jac import.
    _jac_finder.install()
