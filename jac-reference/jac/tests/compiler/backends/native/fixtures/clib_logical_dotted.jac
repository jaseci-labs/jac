"""Test fixture: dotted logical native import (issue #6387).

A dotted path maps the leading components to a sub-directory and the last to the
library stem; a leading `.` (here, level 0 with a sub-dir) pins the lookup to the
binary's directory via the loader token ($ORIGIN / @loader_path).
"""

import from libs.raylib {
    def CloseWindow -> None;
}

def close_it -> None {
    CloseWindow();
}
