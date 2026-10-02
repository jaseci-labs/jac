"""Print the published-kernel asset name for the checkout's current inputs."""
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(here), "jac"))
os.environ["JAC_COMPILER_LIB"] = "off"
import jaclang  # noqa: E402,F401
from jaclang.compiler.backends.native.kernel_fetch import (  # noqa: E402
    kernel_asset_name,
    kernel_publish_key,
)

key = kernel_publish_key()
if key is None:
    sys.exit("no publish key: the stage-0 pin is self or unreadable")
print(kernel_asset_name(key))
