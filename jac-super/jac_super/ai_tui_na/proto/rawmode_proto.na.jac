"""Phase-0 prototype: validate tui_helpers.so before building the full TUI.

Build and run:
  cd ai_tui_na
  gcc -O2 -shared -fPIC -o proto/libtui_helpers.so tui_helpers.c
  jac nacompile proto/rawmode_proto.na.jac -o proto/rawmode_proto
  ./proto/rawmode_proto
"""

import sys;
import time;

import from .tui_helpers {
    def tui_open -> i32;  def tui_close(fd: i32) -> None;  def tui_update_size(
        fd: i32
    ) -> None;  def tui_rows -> i32;  def tui_cols -> i32;  def tui_read_key(
        fd: i32
    ) -> str;  def tui_write(fd: i32, s: str) -> None;  def tui_poll(
        tty_fd: i32, timeout_ms: i32
    ) -> None;  def tui_stdin_ready -> i32;  def tui_key_ready -> i32;
}

glob fd = tui_open();

with entry {
    if fd < 0 {
        tui_write(2, "FAIL: could not open /dev/tty\n");
        sys.exit(1);
    }

    tui_update_size(fd);
}

glob rows = tui_rows(),
     cols = tui_cols();

with entry {
    tui_write(fd, "\033[?1049h");  # enter alt screen
    tui_write(fd, "\033[2J\033[H");  # clear + home
    tui_write(fd, "\033[?25l");  # hide cursor
}

glob msg = f"rawmode_proto: terminal is {cols}x{rows}. Press 'q' to quit.\r\n";

with entry {
    tui_write(fd, msg);
    tui_write(fd, "Keypresses will be echoed below.\r\n");
}

glob quit = False,
     count = 0;

with entry {
    while not quit {
        tui_poll(fd, 100);
        ready = tui_key_ready();
        if ready > 0 {
            key = tui_read_key(fd);
            if len(key) > 0 {
                count += 1;
                line = f"[{count}] bytes={len(key)} ord0={ord(key[0])}\r\n";
                tui_write(fd, line);
                if key == "q" or ord(key[0]) == 3 {  # q or ctrl+c
                    quit = True;
                }
            }
        }
    }

    tui_write(fd, "\r\nProto passed! Restoring terminal...\r\n");
    tui_write(fd, "\033[?25h");  # show cursor
    tui_write(fd, "\033[?1049l");  # leave alt screen

    tui_close(fd);
    tui_write(2, "rawmode_proto: OK\n");
}
