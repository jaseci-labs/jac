"""Portable process measurements shared by compiler workers and producers."""

import sys


def peak_rss_mb() -> int:
    """Peak resident memory of this process; zero where rusage is unavailable."""
    try:
        import resource
    except ImportError:
        return 0
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return int(peak // (1024 * 1024 if sys.platform == "darwin" else 1024))


def child_cpu_seconds() -> float:
    """CPU consumed by children already waited for, including their descendants."""
    try:
        import resource
    except ImportError:
        return 0.0
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    return usage.ru_utime + usage.ru_stime
