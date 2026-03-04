"""Test native sys module: argv and exit."""
import sys;

with entry {
    args = sys.argv;
    print("argc:", len(args));
    for i in range(0, len(args)) {
        print("arg:", args[i]);
    }
    # Check for specific flags
    for i in range(1, len(args)) {
        if args[i] == "--test-flag" {
            print("FLAG_FOUND");
        }
        if args[i] == "--exit-code" {
            if i + 1 < len(args) {
                sys.exit(1);
            }
        }
    }
    print("DONE");
}
