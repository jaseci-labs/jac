"""The Linux side of the posix process area.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
Layouts are glibc's on x86_64 and aarch64: posix_spawnattr_t is 336 bytes,
posix_spawn_file_actions_t 80, sigset_t 128, siginfo_t 128 with si_pid at
byte 16, clock_t is long, and struct sched_param holds only sched_priority.
The <sys/wait.h> macros are glibc's bits/waitstatus.h, the thread count is
the 20th field of /proc/self/stat, and pidfd_open() goes through syscall()
(glibc 2.17 has no wrapper).
"""

import from jaclang.runtime.python.modules.time_records { timespec, tms }
import from jaclang.runtime.python.modules.posix_constants { SYS_pidfd_open }
import from c {
    obj siginfo_t {
        has si_signo: i32 = 0,
            si_errno: i32 = 0,
            si_code: i32 = 0,
            _pad0: i32 = 0,
            si_pid: i32 = 0,
            si_uid: u32 = 0,
            si_status: i32 = 0,
            _pad1: i32 = 0,
            _pad2: i64 = 0,
            _pad3: i64 = 0,
            _pad4: i64 = 0,
            _pad5: i64 = 0,
            _pad6: i64 = 0,
            _pad7: i64 = 0,
            _pad8: i64 = 0,
            _pad9: i64 = 0,
            _pad10: i64 = 0,
            _pad11: i64 = 0,
            _pad12: i64 = 0,
            _pad13: i64 = 0;
    }  obj sched_param {
        has sched_priority: i32 = 0;
    }  def times(buffer: &mut tms) -> i64;  def fexecve(
        fd: i32, argv: ptr[ptr[u8]], envp: ptr[ptr[u8]]
    ) -> i32;  def sched_getscheduler(pid: i32) -> i32;  def sched_setscheduler(
        pid: i32, policy: i32, param: &sched_param
    ) -> i32;  def sched_getparam(pid: i32, param: &mut sched_param) -> i32;  def sched_setparam(
        pid: i32, param: &sched_param
    ) -> i32;  def sched_rr_get_interval(pid: i32, interval: &mut timespec) -> i32;  def sched_setaffinity(
        pid: i32, setsize: u64, mask: ptr
    ) -> i32;  def sched_getaffinity(pid: i32, setsize: u64, mask: ptr) -> i32;  def __sched_cpualloc(
        count: u64
    ) -> ptr;  def __sched_cpufree(cpuset: ptr);  def __sched_cpucount(
        setsize: u64, cpuset: ptr
    ) -> i32;  def posix_spawnattr_setschedpolicy(attr: ptr, policy: i32) -> i32;  def posix_spawnattr_setschedparam(
        attr: ptr, param: &sched_param
    ) -> i32;  def setns(fd: i32, nstype: i32) -> i32;  def unshare(
        flags: i32
    ) -> i32;  def syscall(number: i64, *args: any) -> i64;  def fopen(
        path: str, mode: str
    ) -> ptr;  def fread(buffer: ptr, size: u64, count: u64, stream: ptr) -> u64;  def fclose(
        stream: ptr
    ) -> i32;  def strtok_r(
        text: ptr[u8], delimiters: str, saveptr: &mut ptr[u8]
    ) -> ptr[u8];  def atoi(text: ptr[u8]) -> i32;  def malloc(size: u64) -> ptr;  def free(
        block: ptr
    );  def memset(block: ptr, value: i32, size: u64) -> ptr;
}

glob PLATFORM: str = "linux",
     SPAWNATTR_SIZE: i64 = 336,
     FILE_ACTIONS_SIZE: i64 = 80,
     SIGSET_SIZE: i64 = 128;

# The bits of a cpu_set_t word (__NCPUBITS).
glob:priv NCPUBITS: u64 = 64;

# (mode_t)value, mode_t being unsigned int.
def mode_bits(value: u64) -> u32 {
    return u32.wrap(value);
}

# get_number_of_os_threads(): the 20th field of /proc/self/stat, 0 when it
# cannot be read.
def get_number_of_os_threads -> i64 {
    num_python_threads = i64(0);
    proc_stat = fopen("/proc/self/stat", "r");
    if proc_stat {
        stat_line = ptr[u8](malloc(160));
        if not stat_line {
            fclose(proc_stat);
            return num_python_threads;
        }
        n = fread(stat_line, 1, 159, proc_stat);
        (stat_line + i64(n)).view(1)[0] = u8(0);
        fclose(proc_stat);
        saveptr = ptr[u8]();
        field = strtok_r(stat_line, " ", &mut saveptr);
        idx = u32(19);
        while idx != 0 and field {
            field = strtok_r(ptr[u8](), " ", &mut saveptr);
            idx -= 1;
        }
        if idx == 0 and field {
            num_python_threads = i64(atoi(field));
        }
        free(stat_line);
    }
    return num_python_threads;
}

# fork1() is Solaris-only.
def fork_one -> i32 {
    return i32(-1);
}

def fexecve_call(fd: i32, argv: ptr[ptr[u8]], envp: ptr[ptr[u8]]) -> i32 {
    return fexecve(fd, argv, envp);
}

# times(): (ok, tms_utime, tms_stime, tms_cutime, tms_cstime, elapsed) as
# doubles; ok is False when times() returns (clock_t)-1.
def process_times -> tuple[bool, f64, f64, f64, f64, f64] {
    process = tms();
    ticks = times(&mut process);
    if ticks == -1 {
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

def WCOREDUMP(status: i32) -> i32 {
    return status & 0x80;
}

def WIFCONTINUED(status: i32) -> i32 {
    return i32(1) if status == 0xffff else i32(0);
}

def WIFSTOPPED(status: i32) -> i32 {
    return i32(1) if (status & 0xff) == 0x7f else i32(0);
}

def WIFSIGNALED(status: i32) -> i32 {
    return i32(1) if (i32(i8.wrap((status & 0x7f) + 1)) >> 1) > 0 else i32(0);
}

def WIFEXITED(status: i32) -> i32 {
    return i32(1) if WTERMSIG(status) == 0 else i32(0);
}

def WEXITSTATUS(status: i32) -> i32 {
    return (status & 0xff00) >> 8;
}

def WTERMSIG(status: i32) -> i32 {
    return status & 0x7f;
}

def WSTOPSIG(status: i32) -> i32 {
    return WEXITSTATUS(status);
}

# --- <sched.h> -------------------------------------------------------------

def sched_getscheduler_call(pid: i32) -> i32 {
    return sched_getscheduler(pid);
}

def sched_setscheduler_call(pid: i32, policy: i32, priority: i32) -> i32 {
    param = sched_param(sched_priority=priority);
    return sched_setscheduler(pid, policy, &param);
}

def sched_getparam_call(pid: i32) -> tuple[i32, i32] {
    param = sched_param();
    result = sched_getparam(pid, &mut param);
    return (result, param.sched_priority);
}

def sched_setparam_call(pid: i32, priority: i32) -> i32 {
    param = sched_param(sched_priority=priority);
    return sched_setparam(pid, &param);
}

def sched_rr_get_interval_call(pid: i32) -> tuple[i32, i64, i64] {
    interval = timespec();
    result = sched_rr_get_interval(pid, &mut interval);
    return (result, interval.tv_sec, interval.tv_nsec);
}

def spawnattr_setschedpolicy(attr: ptr, policy: i32) -> i32 {
    return posix_spawnattr_setschedpolicy(attr, policy);
}

def spawnattr_setschedparam(attr: ptr, priority: i32) -> i32 {
    param = sched_param(sched_priority=priority);
    return posix_spawnattr_setschedparam(attr, &param);
}

# CPU_ALLOC_SIZE(count)
def cpu_alloc_size(count: i32) -> u64 {
    return ((u64(count) + NCPUBITS - 1) // NCPUBITS) * 8;
}

# CPU_ALLOC(count)
def cpu_alloc(count: i32) -> ptr {
    return __sched_cpualloc(u64(count));
}

# CPU_FREE(set)
def cpu_free(cpuset: ptr) {
    __sched_cpufree(cpuset);
}

# CPU_ZERO_S(setsize, set)
def cpu_zero_s(setsize: u64, cpuset: ptr) {
    memset(cpuset, i32(0), setsize);
}

# CPU_SET_S(cpu, setsize, set)
def cpu_set_s(cpu: i64, setsize: u64, cpuset: ptr) {
    bit = u64.wrap(cpu);
    if bit // 8 < setsize {
        word = ptr[u64](cpuset) + i64(bit // NCPUBITS);
        word.view(1)[0] = word.view(1)[0] | (u64(1) << (bit % NCPUBITS));
    }
}

# CPU_ISSET_S(cpu, setsize, set)
def cpu_isset_s(cpu: i64, setsize: u64, cpuset: ptr) -> bool {
    bit = u64.wrap(cpu);
    if bit // 8 < setsize {
        word = ptr[u64](cpuset) + i64(bit // NCPUBITS);
        return (word.view(1)[0] & (u64(1) << (bit % NCPUBITS))) != 0;
    }
    return False;
}

# CPU_COUNT_S(setsize, set)
def cpu_count_s(setsize: u64, cpuset: ptr) -> i32 {
    return __sched_cpucount(setsize, cpuset);
}

def sched_setaffinity_call(pid: i32, setsize: u64, cpuset: ptr) -> i32 {
    return sched_setaffinity(pid, setsize, cpuset);
}

def sched_getaffinity_call(pid: i32, setsize: u64, cpuset: ptr) -> i32 {
    return sched_getaffinity(pid, setsize, cpuset);
}

# --- namespaces and pidfd --------------------------------------------------

def pidfd_open_call(pid: i32, flags: u32) -> i32 {
    return i32.wrap(syscall(SYS_pidfd_open, pid, flags));
}

def setns_call(fd: i32, nstype: i32) -> i32 {
    return setns(fd, nstype);
}

def unshare_call(flags: i32) -> i32 {
    return unshare(flags);
}
