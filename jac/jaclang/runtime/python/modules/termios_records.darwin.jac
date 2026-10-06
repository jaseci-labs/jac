"""<termios.h> struct termios as the macOS C library lays it out.

tcflag_t and speed_t are unsigned long; c_cc (NCCS entries) follows the four
flag words.
"""
import from c {
    obj termios_flags {
        has c_iflag: u64 = 0,
            c_oflag: u64 = 0,
            c_cflag: u64 = 0,
            c_lflag: u64 = 0;
    }  def cfgetispeed(mode: ptr) -> u64;  def cfgetospeed(mode: ptr) -> u64;  def cfsetispeed(
        mode: ptr, speed: u64
    ) -> i32;  def cfsetospeed(mode: ptr, speed: u64) -> i32;
}

glob PLATFORM: str = "darwin",
     TERMIOS_SIZE: i64 = 72,
     CC_OFFSET: i64 = 32;

# The four flag words as C longs.
def flags_of(mode: ptr) -> list[i64] {
    record = ptr[termios_flags](mode).view(1);
    return [
        i64.wrap(record[0].c_iflag),
        i64.wrap(record[0].c_oflag),
        i64.wrap(record[0].c_cflag),
        i64.wrap(record[0].c_lflag)
    ];
}

def set_flags(mode: ptr, values: list[i64]) {
    record = ptr[termios_flags](mode).view(1);
    record[0].c_iflag = u64.wrap(values[0]);
    record[0].c_oflag = u64.wrap(values[1]);
    record[0].c_cflag = u64.wrap(values[2]);
    record[0].c_lflag = u64.wrap(values[3]);
}

def input_speed(mode: ptr) -> i64 {
    return i64.wrap(cfgetispeed(mode));
}

def output_speed(mode: ptr) -> i64 {
    return i64.wrap(cfgetospeed(mode));
}

def set_input_speed(mode: ptr, speed: i64) -> i32 {
    return cfsetispeed(mode, u64.wrap(speed));
}

def set_output_speed(mode: ptr, speed: i64) -> i32 {
    return cfsetospeed(mode, u64.wrap(speed));
}
