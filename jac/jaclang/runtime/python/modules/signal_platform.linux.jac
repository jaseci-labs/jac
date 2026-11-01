import from c {
    def __libc_current_sigrtmin -> i32;  def __libc_current_sigrtmax -> i32;  def sigwaitinfo(
        sigset: ptr, info: ptr
    ) -> i32;  def sigtimedwait(sigset: ptr, info: ptr, timeout: ptr) -> i32;  def syscall(
        number: i64, *args: any
    ) -> i64;  def getauxval(kind: u64) -> u64;
}

glob PLATFORM: str = "linux",
     HAS_SIGWAITINFO: bool = True,
     HAS_SIGTIMEDWAIT: bool = True,
     HAS_PIDFD_SEND_SIGNAL: bool = True,
     HAS_RT_SIGNALS: bool = True,
     SYS_pidfd_send_signal: i64 = 424,
     AT_MINSIGSTKSZ: u64 = 51;

def sigrtmin -> i64;

def sigrtmax -> i64;

def wait_info(sigset: ptr, info: ptr) -> i32;

def timed_wait(sigset: ptr, info: ptr, timeout: ptr) -> i32;

def pidfd_send_signal(pidfd: i32, signalnum: i32, flags: i32) -> i64;

def min_signal_stack_size -> u64;

impl sigrtmin -> i64 {
    return i64(__libc_current_sigrtmin());
}

impl sigrtmax -> i64 {
    return i64(__libc_current_sigrtmax());
}

impl wait_info(sigset: ptr, info: ptr) -> i32 {
    return sigwaitinfo(sigset, info);
}

impl timed_wait(sigset: ptr, info: ptr, timeout: ptr) -> i32 {
    return sigtimedwait(sigset, info, timeout);
}

impl pidfd_send_signal(pidfd: i32, signalnum: i32, flags: i32) -> i64 {
    return syscall(SYS_pidfd_send_signal, pidfd, signalnum, ptr(), flags);
}

impl min_signal_stack_size -> u64 {
    return getauxval(AT_MINSIGSTKSZ);
}
