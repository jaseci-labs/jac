import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))

from . import pygls
from . import lsprotocol

__all__ = ["pygls", "lsprotocol"]
