"""byLLM Package - Lazy Loading."""

import importlib.util
import sys

# Check if jaclang spec exists
spec = importlib.util.find_spec("jaclang")

if spec is None:
    # Package not installed at all
    sys.stderr.write(
        "ImportError: jaclang is required for byLLM to function. "
        "jaclang is provided by the jac binary -- run byLLM under `jac`, "
        "or install it with `jac install -e <byllm-path>`.\n"
    )
    sys.exit(1)

# Import jaclang to register the JacMetaImporter for .jac file imports
# Only do this if jaclang is not already being imported (avoid circular imports)
# If jaclang is in sys.modules but not fully initialized, it means we're being
# loaded as a plugin during jaclang's init - in that case, skip the import
if "jaclang" not in sys.modules:
    # Safe to import - we're being imported directly (e.g., from a .py file)
    import jaclang  # noqa: F401
# else: jaclang is already loading us as a plugin, don't re-import
