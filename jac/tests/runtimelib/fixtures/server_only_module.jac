"""A server-only module: nothing in it runs on or is exposed to the client."""

import os;

def separator -> str {
    return os.sep;
}
