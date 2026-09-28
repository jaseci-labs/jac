"""<termios.h> struct termios as glibc lays it out.

tcflag_t and speed_t are unsigned int; c_line and then c_cc (NCCS entries)
follow the four flag words.
"""
import from c {
    obj termios_flags {
        has c_iflag: u32 = 0,
            c_oflag: u32 = 0,
            c_cflag: u32 = 0,
            c_lflag: u32 = 0;
    }  def cfgetispeed(mode: ptr) -> u32;  def cfgetospeed(mode: ptr) -> u32;  def cfsetispeed(
        mode: ptr, speed: u32
    ) -> i32;  def cfsetospeed(mode: ptr, speed: u32) -> i32;
}

glob PLATFORM: str = "linux",
     TERMIOS_SIZE: i64 = 60,
     CC_OFFSET: i64 = 17;

# The four flag words as C longs.
def flags_of(mode: ptr) -> list[i64] {
    record = ptr[termios_flags](mode).view(1);
    return [
        i64(record[0].c_iflag),
        i64(record[0].c_oflag),
        i64(record[0].c_cflag),
        i64(record[0].c_lflag)
    ];
}

def set_flags(mode: ptr, values: list[i64]) {
    record = ptr[termios_flags](mode).view(1);
    record[0].c_iflag = u32.wrap(values[0]);
    record[0].c_oflag = u32.wrap(values[1]);
    record[0].c_cflag = u32.wrap(values[2]);
    record[0].c_lflag = u32.wrap(values[3]);
}

def input_speed(mode: ptr) -> i64 {
    return i64(cfgetispeed(mode));
}

def output_speed(mode: ptr) -> i64 {
    return i64(cfgetospeed(mode));
}

def set_input_speed(mode: ptr, speed: i64) -> i32 {
    return cfsetispeed(mode, u32.wrap(speed));
}

def set_output_speed(mode: ptr, speed: i64) -> i32 {
    return cfsetospeed(mode, u32.wrap(speed));
}
