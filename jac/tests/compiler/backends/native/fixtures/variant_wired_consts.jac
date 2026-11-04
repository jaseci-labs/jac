"""Platform constants wired in from a variant module read their variant value.

`fcntl` and `termios` take `_F_GETFL`, `_TCSANOW`, `_OFF_IFLAG` and `_NCCS`
through archwire imports of `_fcntl_native` / `_termios_native`, whose portable
module declares none of them: only the selected `.linux` / `.darwin` variant does.
"""

import fcntl;
import termios;

with entry {
    print(fcntl.F_GETFL, fcntl.F_SETFL);
    print(termios.TCSANOW, termios.TCSAFLUSH);
    try {
        termios.tcgetattr(-1);
        print("tcgetattr accepted a bad descriptor");
    } except Exception {
        print("tcgetattr refused a bad descriptor");
    }
}
