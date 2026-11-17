"""Repeats the module's import, then binds `join` to another module."""
import from os.path { join }
import from shlex { join }

impl joined -> str {
    return join(["a", "b"]);
}
