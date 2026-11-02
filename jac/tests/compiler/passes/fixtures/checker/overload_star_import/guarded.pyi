import sys

if sys.platform == "nowhere":
    from reexport import *
else:
    from defs import *
