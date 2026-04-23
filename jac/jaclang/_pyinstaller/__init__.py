"""PyInstaller hooks for jaclang, wired via the ``pyinstaller40`` entry point."""

import os


def get_hook_dirs() -> list[str]:
    return [os.path.dirname(__file__)]
