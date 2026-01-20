"""Test file to verify error traceback shows source code context.

This file intentionally has a relative import without a proper package structure
to trigger an ImportError with traceback.
"""

import from .nonexistent_module { Something }

def main() -> None {
    print("This should never execute");
}
