import fnmatch;
import os;

def run_test(
    filepath: str,
    func_name: (str | None) = None,
    filter: (str | None) = None,
    xit: bool = False,
    maxfail: (int | None) = None,
    directory: (str | None) = None,
    verbose: bool = False
) -> int;
