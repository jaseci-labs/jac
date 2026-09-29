import sys;

def run_cases {
    print("out one");
    print("err one", file=sys.stderr);
    print("out two", file=sys.stdout);
    print("err two", 42, file=sys.stderr);
}

with entry {
    run_cases();
}
