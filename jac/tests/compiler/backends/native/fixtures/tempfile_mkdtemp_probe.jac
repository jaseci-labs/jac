"""Probe for the native `tempfile.mkdtemp`: argv[1] is the mode.

`default` creates a directory under the environment's temp dir; `affix`
exercises `prefix`/`suffix`; `dir` places the directory under argv[2];
`missing` targets a nonexistent parent so the real errno must surface
instead of a generic retry-exhaustion failure.
"""
import os;
import sys;
import tempfile;

glob mode = sys.argv[1];

with entry {
    if mode == "affix" {
        print(tempfile.mkdtemp(suffix="-sfx", prefix="jacp-"));
    } elif mode == "dir" {
        print(tempfile.mkdtemp(dir=sys.argv[2]));
    } elif mode == "missing" {
        tempfile.mkdtemp(dir=sys.argv[2]);
        print("unreachable");
    } else {
        print(tempfile.mkdtemp());
    }
}
