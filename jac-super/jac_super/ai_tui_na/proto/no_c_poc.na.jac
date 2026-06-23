"""POC: zero custom C — terminal I/O via libc_tty.na.jac only.

Build:
  cd ai_tui_na
  ../../../.venv/bin/python -m jaclang nacompile proto/no_c_poc.na.jac -o proto/no_c_poc

Run (interactive):
  ./proto/no_c_poc

Expected: alt-screen message, key echo, 'q' quits, stderr prints PASS lines.
"""

import sys;

import from .libc_tty {
    tty_open,
    tty_close,
    tty_update_size,
    tty_rows,
    tty_cols,
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_write,
}

def _pass(label: str) {
    tty_write(2, f"[no-c-poc] {label} PASS\n");
}

glob fd = tty_open();

with entry {
    if fd < 0 {
        tty_write(2, "[no-c-poc] tty_open failed\n");
        sys.exit(1);
    }
    _pass("tty_open");
}

glob rows = tty_rows(),
     cols = tty_cols();

with entry {
    tty_write(fd, "\033[?1049h");
    tty_write(fd, "\033[2J\033[H");
    tty_write(fd, "\033[?25l");
    tty_write(fd, f"no_c_poc: {cols}x{rows} — zero custom C, libc FFI only\r\n");
    tty_write(fd, "Press 'q' to quit. Keys echo below.\r\n");
    _pass("alt_screen");
}

glob quit = False,
     count = 0;

with entry {
    while not quit {
        tty_poll(100);
        if tty_key_ready() > 0 {
            key = tty_read_key();
            if len(key) > 0 {
                count += 1;
                tty_write(fd, f"[{count}] key len={len(key)}\r\n");
                if key == "q" or ord(key[0]) == 3 {
                    quit = True;
                }
            }
        }
    }

    tty_write(fd, "\r\nRestoring terminal...\r\n");
    tty_write(fd, "\033[?25h");
    tty_write(fd, "\033[?1049l");

    tty_close();
    _pass("tty_close");
    tty_write(2, "[no-c-poc] ALL PASS — no tui_helpers.c required\n");
}
