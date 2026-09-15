"""Jac sitecustomize: shipped in the single binary's ``site/``.

Python imports ``sitecustomize`` during site initialization in BOTH the jac CLI
(``Py_Initialize`` + boot) and bare python mode (``jac -m <tool>`` via
``Py_BytesMain``). That makes it the one place to put the current project's
``.jac/venv`` on ``sys.path`` so it is visible to both -- the CLI's plugin
enumeration and a ``jac -m uvicorn``-style invocation that needs a tool
installed into the project venv.

Kept deliberately tiny and jaclang-free so non-Jac Python startup pays ~nothing.
"""

import _jac_finder

with __import__("contextlib").suppress(Exception):
    _jac_finder.add_project_venv_to_path()
try:
    _jac_finder.apply_compiler_image()
except RuntimeError as error:
    raise SystemExit(str(error)) from error
_jac_finder.install()
