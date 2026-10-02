"""The macOS side of the posix process area.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
posix_spawnattr_t and posix_spawn_file_actions_t are pointers, sigset_t is
32 bits, siginfo_t is 104 bytes with si_pid at byte 12, clock_t is unsigned
long and mode_t 16 bits. The <sys/wait.h> macros are Darwin's (_W_INT of an
int status), and the thread count comes from task_threads(). macOS has no
fexecve(), sched_setscheduler() family, sched_setaffinity(), setns(),
unshare() or pidfd_open(); the binding installs none of the functions that
need them, so their calls here are unreachable.
"""

import from jaclang.runtime.python.modules.time_records { tms }
import from c {
    obj siginfo_t {
        has si_signo: i32 = 0,
            si_errno: i32 = 0,
            si_code: i32 = 0,
            si_pid: i32 = 0,
            si_uid: u32 = 0,
            si_status: i32 = 0,
            si_addr: ptr = ptr(),
            si_value: i64 = 0,
            si_band: i64 = 0,
            _pad0: u64 = 0,
            _pad1: u64 = 0,
            _pad2: u64 = 0,
            _pad3: u64 = 0,
            _pad4: u64 = 0,
            _pad5: u64 = 0,
            _pad6: u64 = 0;
    }  glob mach_task_self_: u32; def task_for_pid(
        target: u32, pid: i32, task: &mut u32
    ) -> i32;  def task_threads(task: u32, threads: &mut ptr, count: &mut u32) -> i32;  def getpid -> i32;  def times(
        buffer: &mut tms
    ) -> u64;
}

glob PLATFORM: str = "darwin",
     SPAWNATTR_SIZE: i64 = 8,
     FILE_ACTIONS_SIZE: i64 = 8,
     SIGSET_SIZE: i64 = 4;

glob:priv KERN_SUCCESS: i32 = 0;

# (mode_t)value, mode_t being unsigned short.
def mode_bits(value: u64) -> u32 {
    return u32.wrap(value & 0xffff);
}

# get_number_of_os_threads(): the threads of this task, 0 when they cannot
# be counted.
def get_number_of_os_threads -> i64 {
    num_python_threads = i64(0);
    macos_self = mach_task_self_;
    macos_task = u32(0);
    if task_for_pid(macos_self, getpid(), &mut macos_task) == KERN_SUCCESS {
        macos_threads = ptr();
        macos_n_threads = u32(0);
        if task_threads(macos_task, &mut macos_threads, &mut macos_n_threads)
            == KERN_SUCCESS {
            num_python_threads = i64(macos_n_threads);
        }
    }
    return num_python_threads;
}

def fork_one -> i32 {
    return i32(-1);
}

def fexecve_call(fd: i32, argv: ptr[ptr[u8]], envp: ptr[ptr[u8]]) -> i32 {
    return i32(-1);
}

def process_times -> tuple[bool, f64, f64, f64, f64, f64] {
    process = tms();
    ticks = times(&mut process);
    if ticks == u64(0xFFFFFFFFFFFFFFFF) {
        return (False, 0.0, 0.0, 0.0, 0.0, 0.0);
    }
    return (
        True,
        f64(process.tms_utime),
        f64(process.tms_stime),
        f64(process.tms_cutime),
        f64(process.tms_cstime),
        f64(ticks)
    );
}

# --- <sys/wait.h> ----------------------------------------------------------

def:priv _WSTATUS(status: i32) -> i32 {
    return status & 0o177;
}

def WCOREDUMP(status: i32) -> i32 {
    return status & 0o200;
}

def WIFCONTINUED(status: i32) -> i32 {
    return i32(1) if _WSTATUS(status) == 0o177 and WSTOPSIG(status) == 0x13 else i32(0);
}

def WIFSTOPPED(status: i32) -> i32 {
    return i32(1) if _WSTATUS(status) == 0o177 and WSTOPSIG(status) != 0x13 else i32(0);
}

def WIFSIGNALED(status: i32) -> i32 {
    return i32(1) if _WSTATUS(status) != 0o177 and _WSTATUS(status) != 0 else i32(0);
}

def WIFEXITED(status: i32) -> i32 {
    return i32(1) if _WSTATUS(status) == 0 else i32(0);
}

def WEXITSTATUS(status: i32) -> i32 {
    return (status >> 8) & 0xff;
}

def WTERMSIG(status: i32) -> i32 {
    return _WSTATUS(status);
}

def WSTOPSIG(status: i32) -> i32 {
    return status >> 8;
}

# --- <sched.h> -------------------------------------------------------------

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

# --- namespaces and pidfd --------------------------------------------------

def pidfd_open_call(pid: i32, flags: u32) -> i32 {
    return i32(-1);
}

def setns_call(fd: i32, nstype: i32) -> i32 {
    return i32(-1);
}

def unshare_call(flags: i32) -> i32 {
    return i32(-1);
}
