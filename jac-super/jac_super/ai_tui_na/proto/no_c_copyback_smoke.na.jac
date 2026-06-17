"""Smoke: does tcgetattr copy struct fields back after the call?"""

import sys;

import from "/usr/lib/libc.so.6" {
    obj Termios {
        has c_iflag: u32,
            c_oflag: u32,
            c_cflag: u32,
            c_lflag: u32,
            c_line: u8,
            c_cc0: u8,
            c_cc1: u8,
            c_cc2: u8,
            c_cc3: u8,
            c_cc4: u8,
            c_cc5: u8,
            c_cc6: u8,
            c_cc7: u8,
            c_cc8: u8,
            c_cc9: u8,
            c_cc10: u8,
            c_cc11: u8,
            c_cc12: u8,
            c_cc13: u8,
            c_cc14: u8,
            c_cc15: u8,
            c_cc16: u8,
            c_cc17: u8,
            c_cc18: u8,
            c_cc19: u8,
            c_cc20: u8,
            c_cc21: u8,
            c_cc22: u8,
            c_cc23: u8,
            c_cc24: u8,
            c_cc25: u8,
            c_cc26: u8,
            c_cc27: u8,
            c_cc28: u8,
            c_cc29: u8,
            c_cc30: u8,
            c_cc31: u8,
            c_ispeed: u32,
            c_ospeed: u32;
    }  def open(path: str, flags: i32, mode: i32) -> i32;  def close(fd: i32) -> i32;  def write(
        fd: i32, buf: str, count: i32
    ) -> i32;  def tcgetattr(fd: i32, term: Termios) -> i32;
}

def msg(s: str) {
    write(2, s, len(s));
}

def blank -> Termios {
    return Termios(
        c_iflag=0,
        c_oflag=0,
        c_cflag=0,
        c_lflag=0,
        c_line=0,
        c_cc0=0,
        c_cc1=0,
        c_cc2=0,
        c_cc3=0,
        c_cc4=0,
        c_cc5=0,
        c_cc6=0,
        c_cc7=0,
        c_cc8=0,
        c_cc9=0,
        c_cc10=0,
        c_cc11=0,
        c_cc12=0,
        c_cc13=0,
        c_cc14=0,
        c_cc15=0,
        c_cc16=0,
        c_cc17=0,
        c_cc18=0,
        c_cc19=0,
        c_cc20=0,
        c_cc21=0,
        c_cc22=0,
        c_cc23=0,
        c_cc24=0,
        c_cc25=0,
        c_cc26=0,
        c_cc27=0,
        c_cc28=0,
        c_cc29=0,
        c_cc30=0,
        c_cc31=0,
        c_ispeed=0,
        c_ospeed=0
    );
}

glob O_RDWR: int = 2,
     fd: int = open("/dev/tty", O_RDWR, 0);

with entry {
    if fd < 0 {
        msg("[copyback] FAIL open\n");
        sys.exit(1);
    }
}

glob term: Termios = blank(),
     rc: int = tcgetattr(fd, term);

with entry {
    msg(f"[copyback] rc={rc} iflag={term.c_iflag} lflag={term.c_lflag}\n");
    close(fd);
}
