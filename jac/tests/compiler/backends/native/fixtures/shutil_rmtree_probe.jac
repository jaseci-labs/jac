"""Probe for the native `shutil.rmtree`: argv[1] is the mode, argv[2] the tree.

`ignore` removes best-effort and reports whether the tree is gone; `strict`
removes with the default (raising) behavior, so a failure surfaces as an
uncaught exception whose message must name the entry that could not be
removed.
"""
import os;
import shutil;
import sys;

glob mode = sys.argv[1],
     target = sys.argv[2];

with entry {
    if mode == "ignore" {
        shutil.rmtree(target, ignore_errors=True);
        print("returned");
        print("gone" if not os.path.isdir(target) else "exists");
    } else {
        shutil.rmtree(target);
        print("removed");
    }
}
