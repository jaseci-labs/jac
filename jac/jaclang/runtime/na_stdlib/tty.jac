glob IFLAG: int = 0,
     OFLAG: int = 1,
     CFLAG: int = 2,
     LFLAG: int = 3,
     CC: int = 6;

def _mi(mode: list[any], i: int) -> int;

def _set_cc(value: any) -> list[any];

def:pub setraw(fd: int, when: int = TCSAFLUSH) -> list[any];

def:pub setcbreak(fd: int, when: int = TCSAFLUSH) -> list[any];
