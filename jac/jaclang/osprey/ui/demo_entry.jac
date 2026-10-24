import os;
import sys;


with entry {
    if not os.isatty(0) or not os.isatty(1) {
        sys.stderr.write("demo_live_shell needs a real TTY.\n");
        raise SystemExit(1);
    }
    run_live_shell_demo();
}
