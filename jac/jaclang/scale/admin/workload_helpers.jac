def phase_to_status(ready: int, desired: int, restarts: int) -> str {
    if desired > 0 and ready == 0 and restarts > 0 {
        return "Broken";
    }
    if restarts > 0 and ready > 0 {
        return "Unstable";
    }
    if desired > 0 and ready < desired {
        return "Starting";
    }
    if ready > 0 {
        return "Healthy";
    }
    return "Unknown";
}

def owner_name_from_pod(pod: str) -> str {
    if not pod {
        return "";
    }
    parts = pod.split("-");
    if len(parts) < 2 {
        return pod;
    }

    if parts[-1].isdigit() {
        return "-".join(parts[:-1]);
    }
    if len(parts) < 3 {
        return pod;
    }
    return "-".join(parts[:-2]);
}

def match_owner(pod: str, names: list[str]) -> str {
    best: str = "";
    for nm in names {
        if (pod == nm or pod.startswith(nm + "-")) and len(nm) > len(best) {
            best = nm;
        }
    }
    return best or owner_name_from_pod(pod);
}
