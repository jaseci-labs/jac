"""PyInstaller hooks for jaclang, wired via the ``pyinstaller40`` entry point."""

import os
import sys


def get_hook_dirs() -> list[str]:
    """Return hook dirs AND activate jaclang's build-time support.

    Runs at PyInstaller startup (before any module graph analysis), which is
    the latest we can still avoid ``jaclang.<sub>`` getting cached as
    ``MissingModule`` in the graph from an earlier probe. Two side effects:

    * install the ``.jac`` path-level loader so FileFinder recognizes
      ``__init__.jac`` as a package marker;
    * surface jaclang's source parent directory on ``sys.path`` for PEP 660
      editable installs, which otherwise only reach jaclang via
      ``sys.meta_path`` and are invisible to path-based analyzers.
    """
    import _jac_finder

    import jaclang

    _jac_finder._install_jac_path_hook()

    jaclang_parent = os.path.dirname(os.path.dirname(jaclang.__file__))
    if jaclang_parent and jaclang_parent not in sys.path:
        sys.path.insert(0, jaclang_parent)

    print(
        f"[jaclang._pyinstaller] hook-dirs init: "
        f"jaclang={jaclang.__file__!r} sys.path[0]={sys.path[0]!r}",
        file=sys.stderr,
    )

    return [os.path.dirname(__file__)]
