import json;
import sys;
import pathlib;

with entry {
    print(json.dumps({"value": 42}, sort_keys=True));
    print(pathlib.PurePosixPath("a/b.txt").name);
    print(sys.argv[1]);
}
