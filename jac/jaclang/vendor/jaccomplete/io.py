import contextlib
import os
import sys

_DEBUG = "_JAC_DEBUG" in os.environ

debug_stream = sys.stderr


def debug(*args):
    if _DEBUG:
        print(file=debug_stream, *args)


@contextlib.contextmanager
def mute_stderr():
    stderr = sys.stderr
    sys.stdout.flush() # flush before redirecting
    sys.stderr = open(os.devnull, "w")
    try:
        yield
    finally:
        sys.stderr.close()
        sys.stderr = stderr
