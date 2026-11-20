"""Shared formatting helpers for the admin UI (bytes, CPU cores, age)."""

# Human-readable bytes (GB / MB / KB / B), two-decimal precision.
def:pub formatBytes(b: float) -> str {
    if b >= 1073741824 {
        return str(int(b / 10737418.24) / 100) + " GB";
    }
    if b >= 1048576 {
        return str(int(b / 10485.76) / 100) + " MB";
    }
    if b >= 1024 {
        return str(int(b / 10.24) / 100) + " KB";
    }
    return str(int(b)) + " B";
}

# CPU cores: millicores under 1 core, else cores to two decimals.
# Rounds rather than truncates: int(2.3 * 100) is 229 (2.3 has no exact float
# representation), which rendered 2.3 cores as "2.29 cores".
def:pub formatCores(c: float) -> str {
    if c < 1 {
        return str(int(c * 1000)) + "m";
    }
    v = round(c, 2);
    return str(v) + (" core" if v == 1 else " cores");
}

# Age from a unix-seconds creation timestamp ("-" when unknown/future).
def:pub formatAge(createdSecs: float) -> str {
    if createdSecs <= 0 {
        return "-";
    }
    ageSecs = (Date.now() / 1000) - createdSecs;
    if ageSecs < 0 {
        return "-";
    }
    if ageSecs < 60 {
        return str(int(ageSecs)) + "s";
    }
    if ageSecs < 3600 {
        return str(int(ageSecs / 60)) + "m";
    }
    if ageSecs < 86400 {
        hrs = int(ageSecs / 3600);
        mins = int((ageSecs % 3600) / 60);
        return str(hrs) + "h " + str(mins) + "m";
    }
    days = int(ageSecs / 86400);
    hrs = int((ageSecs % 86400) / 3600);
    return str(days) + "d " + str(hrs) + "h";
}
