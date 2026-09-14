import sys;
import os;

def resident_rss_mb -> int {
    if sys.platform == "linux" {
        try {
            with open("/proc/self/statm") as status {
                resident_pages = int(status.read().split()[1]);
            }
            return resident_pages * os.sysconf("SC_PAGE_SIZE") // (1024 * 1024);
        } except (OSError, ValueError, IndexError) {}
    }
    if sys.platform == "darwin" {
        import subprocess;
        try {
            resident_kb = subprocess.check_output(
                ["ps", "-o", "rss=", "-p", str(os.getpid())], text=True
            );
            return int(resident_kb.strip()) // 1024;
        } except (OSError, ValueError, subprocess.SubprocessError) {}
    }
    return peak_rss_mb();
}

def peak_rss_mb -> int {
    try {
        import resource;
    } except ImportError {
        return 0;
    }
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss;
    return int(peak // (1024 * 1024 if sys.platform == "darwin" else 1024));
}

def child_cpu_seconds -> float {
    try {
        import resource;
    } except ImportError {
        return 0.0;
    }
    usage = resource.getrusage(resource.RUSAGE_CHILDREN);
    return usage.ru_utime + usage.ru_stime;
}
