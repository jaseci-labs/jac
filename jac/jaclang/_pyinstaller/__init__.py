"""PyInstaller hooks for jaclang, wired via the ``pyinstaller40`` entry point."""

import os


def get_hook_dirs() -> list[str]:
    """Return the hook directory; installs the ``.jac`` ``FileFinder`` loader."""
    import _jac_finder

    _jac_finder._install_jac_path_hook()

    return [os.path.dirname(__file__)]
