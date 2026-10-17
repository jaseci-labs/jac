// miniperf: whole-process hardware counter groups for a child process.
// Works without the perf tool (perf_event_paranoid=2: per-process, user-only).
// Profiles:
//   core     : cycles, instructions, branches, branch-misses
//   cache    : raw mem_load_retired l1/l2 misses, LLC miss, dtlb walk,
//              ld_blocks.store_forward, ld_blocks_partial.address_alias
//   frontend : uops_issued.any, idq mite/dsb cycles, resource_stalls.sb
// Multiple events share one group; events the kernel rejects are skipped.
// The child is pinned to CPU $MINIPERF_CPU if set, else its current CPU.
// On hybrid x86 (P/E cores) pinning to a P-class CPU is required for
// reliable counts; native_profile.py picks one via MINIPERF_CPU.
// NOTE: generic PERF_COUNT_HW_CACHE mappings are unreliable under
// paranoid=2 on recent kernels (L1-dcache-loads aliases cycles, misses
// return null) -- use the raw codes in the cache profile instead.
#define _GNU_SOURCE
#include <linux/perf_event.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <sched.h>
#include <signal.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

static long sys_pe(struct perf_event_attr *a, pid_t pid, int cpu, int gfd, unsigned long flags) {
    return syscall(SYS_perf_event_open, a, pid, cpu, gfd, flags);
}

struct ev { const char *name; unsigned type; unsigned long long cfg; int fd; };

#define RAW(e, u) ((unsigned long long)((u) << 8) | (e))
#define EVT(name_, ...) {name_, __VA_ARGS__, -1}

#define HW(type_) PERF_TYPE_HARDWARE, type_

static struct ev *pick(const char *prof, int *n) {
    static struct ev core[] = {
        EVT("cycles",        HW(PERF_COUNT_HW_CPU_CYCLES)),
        EVT("instructions",  HW(PERF_COUNT_HW_INSTRUCTIONS)),
        EVT("branches",      HW(PERF_COUNT_HW_BRANCH_INSTRUCTIONS)),
        EVT("branch-misses", HW(PERF_COUNT_HW_BRANCH_MISSES)),
    };
    static struct ev cache[] = { // Skylake-descendant raw codes (Lion Cove OK)
        EVT("mem-l1-miss",   PERF_TYPE_RAW, RAW(0xd1, 0x08)), // MEM_LOAD_RETIRED.L1_MISS
        EVT("mem-l2-miss",   PERF_TYPE_RAW, RAW(0xd1, 0x10)), // MEM_LOAD_RETIRED.L2_MISS
        EVT("llc-miss",      PERF_TYPE_RAW, RAW(0x2e, 0x41)), // LONGEST_LAT_CACHE.MISS
        EVT("dtlb-miss-walk",PERF_TYPE_RAW, RAW(0x08, 0x01)), // DTLB_LOAD_MISSES.MISS_CAUSED_A_WALK
        EVT("ld-stfwd",      PERF_TYPE_RAW, RAW(0x03, 0x02)), // LD_BLOCKS.STORE_FORWARD
        EVT("ld-4k-alias",   PERF_TYPE_RAW, RAW(0x07, 0x01)), // LD_BLOCKS_PARTIAL.ADDRESS_ALIAS
    };
    static struct ev frontend[] = {
        EVT("uops-issued",  PERF_TYPE_RAW, RAW(0x0e, 0x01)), // UOPS_ISSUED.ANY
        EVT("idq-mite",     PERF_TYPE_RAW, RAW(0x79, 0x14)), // IDQ.ALL_MITE_CYCLES_ANY_UOPS
        EVT("idq-dsb",      PERF_TYPE_RAW, RAW(0x79, 0x18)), // IDQ.ALL_DSB_CYCLES_ANY_UOPS
        EVT("rs-stalls-sb", PERF_TYPE_RAW, RAW(0xa2, 0x08)), // RESOURCE_STALLS.SB
    };
    if (!strcmp(prof, "cache"))    { *n = 6; return cache; }
    if (!strcmp(prof, "frontend")) { *n = 4; return frontend; }
    *n = 4; return core;
}

#define MAXEV 16
int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: miniperf <core|cache|frontend> <cmd> [args...]\n"); return 2; }
    int n; struct ev *evs = pick(argv[1], &n);
    char **cmd = argv + 2;

    int cpu = -1;
    const char *cpu_s = getenv("MINIPERF_CPU");
    if (cpu_s && *cpu_s) cpu = atoi(cpu_s);
    if (cpu < 0) cpu = sched_getcpu();
    pid_t pid = fork();
    if (pid == 0) {
        raise(SIGSTOP);
        if (cpu >= 0) {
            cpu_set_t set; CPU_ZERO(&set); CPU_SET(cpu, &set);
            if (sched_setaffinity(0, sizeof(set), &set) != 0)
                perror("sched_setaffinity");
        }
        execvp(cmd[0], cmd);
        perror("execvp"); _exit(127);
    }
    int status;
    waitpid(pid, &status, WUNTRACED);

    struct perf_event_attr a;
    int leader = -1, cnt = 0, order[MAXEV];
    for (int i = 0; i < n; i++) {
        memset(&a, 0, sizeof(a));
        a.size = sizeof(a);
        a.type = evs[i].type; a.config = evs[i].cfg;
        a.exclude_kernel = 1; a.exclude_hv = 1;
        a.read_format = PERF_FORMAT_GROUP;
        int fd = (int)sys_pe(&a, pid, -1, leader, 0);
        if (fd < 0) { evs[i].fd = -1; } else { evs[i].fd = fd; if (leader < 0) leader = fd; order[cnt++] = i; }
    }
    if (cnt == 0) { fprintf(stderr, "no counters available\n"); return 1; }
    ioctl(leader, PERF_EVENT_IOC_RESET, PERF_IOC_FLAG_GROUP);
    ioctl(leader, PERF_EVENT_IOC_ENABLE, PERF_IOC_FLAG_GROUP);
    kill(pid, SIGCONT);
    waitpid(pid, &status, 0);
    ioctl(leader, PERF_EVENT_IOC_DISABLE, PERF_IOC_FLAG_GROUP);

    unsigned long long buf[MAXEV * 2 + 1];
    ssize_t got = read(leader, buf, sizeof(buf));
    if (got < 0) { perror("read"); return 1; }
    unsigned long long nr = buf[0];

    printf("{\"cmd\":\"");
    for (int i = 0; cmd[i]; i++) printf("%s%s", cmd[i], cmd[i+1] ? " " : "");
    printf("\",\"exit\":%d,\"cpu\":%d", WIFEXITED(status) ? WEXITSTATUS(status) : -1, cpu);
    for (int j = 0; j < cnt && j < MAXEV; j++) {
        unsigned long long v = (j + 1 <= nr) ? buf[1 + j] : 0;
        printf(",\"%s\":%llu", evs[order[j]].name, v);
    }
    for (int i = 0; i < n; i++) {
        int in = 0;
        for (int j = 0; j < cnt; j++) if (order[j] == i) in = 1;
        if (!in) printf(",\"%s\":null", evs[i].name);
    }
    printf("}\n");
    return 0;
}
