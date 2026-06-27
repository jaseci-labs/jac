import importlib.util
import sys

spec = importlib.util.find_spec("jaclang")

if spec is None:
    sys.stderr.write(
        "ImportError: jaclang is required for byLLM to function. "
        "or install it with `jac install -e <byllm-path>`.\n"
    )
    sys.exit(1)

if "jaclang" not in sys.modules:
    import jaclang  # noqa: F401
