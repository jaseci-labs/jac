import math;
import random;
import struct;
import os;
import sys;
import json;
import zlib;
import pathlib;
import hashlib;
import io;
import from datetime { datetime, timezone }

def stdlib_surface -> bool {
    if str(math.factorial(30)) != "265252859812191058636308480000000" {
        return False;
    }
    try {
        math.sqrt(-1.0);
        return False;
    } except ValueError {}
    random.seed(27);
    if random.getstate()[0] != 3 {
        return False;
    }
    packed = struct.pack(">Ih", 4294967295, -123);
    if struct.unpack(">Ih", packed)[1] != -123 {
        return False;
    }
    if zlib.decompress(zlib.compress(b"one\x00two")) != b"one\x00two" {
        return False;
    }
    parsed = json.loads("{\"values\": [1, 2], \"ready\": true}");
    parsed["values"].append(3);
    if json.dumps(parsed, sort_keys=True)
        != "{\"ready\": true, \"values\": [1, 2, 3]}" {
        return False;
    }
    if pathlib.PureWindowsPath("C:/a/b.txt").suffix != ".txt" {
        return False;
    }
    if datetime.fromtimestamp(0, timezone.utc).isoformat()
        != "1970-01-01T00:00:00+00:00" {
        return False;
    }
    if hashlib.sha256(b"abc").hexdigest()
        != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" {
        return False;
    }
    buffer = io.BytesIO(b"a\x00b");
    if buffer.read() != b"a\x00b" {
        return False;
    }
    return os.fspath(pathlib.PurePosixPath("a/b")) == "a/b"
        and sys.version_info.major == 3;
}

def patched_sqrt -> float {
    return math.sqrt(4.0);
}
