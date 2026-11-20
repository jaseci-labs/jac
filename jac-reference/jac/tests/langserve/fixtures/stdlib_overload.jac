"""Test stdlib overloaded function resolution via wildcard import (os.path)."""
import os;

with entry {
    # os.path.dirname has 2 overloads from posixpath via `from posixpath import *`
    result = os.path.dirname("/foo/bar/baz.txt");
    print(result);
}
