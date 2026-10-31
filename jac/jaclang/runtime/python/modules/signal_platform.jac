glob PLATFORM: str = "",
     HAS_SIGWAITINFO: bool = False,
     HAS_SIGTIMEDWAIT: bool = False,
     HAS_PIDFD_SEND_SIGNAL: bool = False,
     HAS_RT_SIGNALS: bool = False;

def sigrtmin -> i64;

def sigrtmax -> i64;

def wait_info(sigset: ptr, info: ptr) -> i32;

def timed_wait(sigset: ptr, info: ptr, timeout: ptr) -> i32;

def pidfd_send_signal(pidfd: i32, signalnum: i32, flags: i32) -> i64;

def min_signal_stack_size -> u64;

impl sigrtmin -> i64 {
    return i64(0);
}

impl sigrtmax -> i64 {
    return i64(0);
}

impl wait_info(sigset: ptr, info: ptr) -> i32 {
    return i32(-1);
}

impl timed_wait(sigset: ptr, info: ptr, timeout: ptr) -> i32 {
    return i32(-1);
}

impl pidfd_send_signal(pidfd: i32, signalnum: i32, flags: i32) -> i64 {
    return i64(-1);
}

impl min_signal_stack_size -> u64 {
    return u64(0);
}
