import os;

def run_twice(cmd: own str) -> int {
    rc = os.system(cmd);
    rc2 = os.system(cmd);
    return rc + rc2;
}

with entry {
    print(run_twice("true"));
}
