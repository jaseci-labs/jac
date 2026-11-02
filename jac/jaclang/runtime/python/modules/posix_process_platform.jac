"""posix process primitives for a target with no posix_process_platform.<os>.jac; the binding rejects it."""

import from c {
    obj siginfo_t {
        has si_signo: i32 = 0,
            si_errno: i32 = 0,
            si_code: i32 = 0,
            si_pid: i32 = 0,
            si_uid: u32 = 0,
            si_status: i32 = 0;
    }
}

glob PLATFORM: str = "",
     SPAWNATTR_SIZE: i64 = 0,
     FILE_ACTIONS_SIZE: i64 = 0,
     SIGSET_SIZE: i64 = 0;

def mode_bits(value: u64) -> u32 {
    return u32.wrap(value);
}

def get_number_of_os_threads -> i64 {
    return i64(0);
}

def fork_one -> i32 {
    return i32(-1);
}

def fexecve_call(fd: i32, argv: ptr[ptr[u8]], envp: ptr[ptr[u8]]) -> i32 {
    return i32(-1);
}

def process_times -> tuple[bool, f64, f64, f64, f64, f64] {
    return (False, 0.0, 0.0, 0.0, 0.0, 0.0);
}

def WCOREDUMP(status: i32) -> i32 {
    return i32(0);
}

def WIFCONTINUED(status: i32) -> i32 {
    return i32(0);
}

def WIFSTOPPED(status: i32) -> i32 {
    return i32(0);
}

def WIFSIGNALED(status: i32) -> i32 {
    return i32(0);
}

def WIFEXITED(status: i32) -> i32 {
    return i32(0);
}

def WEXITSTATUS(status: i32) -> i32 {
    return i32(0);
}

def WTERMSIG(status: i32) -> i32 {
    return i32(0);
}

def WSTOPSIG(status: i32) -> i32 {
    return i32(0);
}

def sched_getscheduler_call(pid: i32) -> i32 {
    return i32(-1);
}

def sched_setscheduler_call(pid: i32, policy: i32, priority: i32) -> i32 {
    return i32(-1);
}

def sched_getparam_call(pid: i32) -> tuple[i32, i32] {
    return (i32(-1), i32(0));
}

def sched_setparam_call(pid: i32, priority: i32) -> i32 {
    return i32(-1);
}

def sched_rr_get_interval_call(pid: i32) -> tuple[i32, i64, i64] {
    return (i32(-1), i64(0), i64(0));
}

def spawnattr_setschedpolicy(attr: ptr, policy: i32) -> i32 {
    return i32(-1);
}

def spawnattr_setschedparam(attr: ptr, priority: i32) -> i32 {
    return i32(-1);
}

def cpu_alloc_size(count: i32) -> u64 {
    return u64(0);
}

def cpu_alloc(count: i32) -> ptr {
    return ptr();
}

def cpu_free(cpuset: ptr) {}

def cpu_zero_s(setsize: u64, cpuset: ptr) {}

def cpu_set_s(cpu: i64, setsize: u64, cpuset: ptr) {}

def cpu_isset_s(cpu: i64, setsize: u64, cpuset: ptr) -> bool {
    return False;
}

def cpu_count_s(setsize: u64, cpuset: ptr) -> i32 {
    return i32(0);
}

def sched_setaffinity_call(pid: i32, setsize: u64, cpuset: ptr) -> i32 {
    return i32(-1);
}

def sched_getaffinity_call(pid: i32, setsize: u64, cpuset: ptr) -> i32 {
    return i32(-1);
}

def pidfd_open_call(pid: i32, flags: u32) -> i32 {
    return i32(-1);
}

def setns_call(fd: i32, nstype: i32) -> i32 {
    return i32(-1);
}

def unshare_call(flags: i32) -> i32 {
    return i32(-1);
}
