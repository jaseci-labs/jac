import contextlib
import os
import sys


@contextlib.contextmanager
def mute_stderr():
    stderr = sys.stderr
    sys.stdout.flush()  # flush before redirecting
    sys.stderr = open(os.devnull, "w")
    try:
        yield
    finally:
        sys.stderr.close()
        sys.stderr = stderr
