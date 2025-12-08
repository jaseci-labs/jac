"""byLLM Package - Lazy Loading."""

import importlib.util
import sys

spec = importlib.util.find_spec("jaclang")

if spec is None:
    # Package not installed at all
    sys.stderr.write(
        "ImportError: jaclang is required for byLLM to function. "
        "Please install it via 'pip install jaclang', or reinstall byLLM.\n"
    )
    sys.exit(1)
else:
    # Package seems to exist, now try importing it
    try:
        jaclang = importlib.import_module("jaclang")
    except Exception:
        sys.stderr.write(
            "ImportError: jaclang is installed but could not be imported. "
            "Try reinstalling it via 'pip install --force-reinstall jaclang'.\n"
        )
        sys.exit(1)
