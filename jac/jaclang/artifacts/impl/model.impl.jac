impl Probe.hit(source: Source, path: str, record: dict[str, any]) -> Probe {
    return Probe(found=Found(source=source, path=path, record=record));
}

impl Probe.stale(drift: list[str]) -> Probe {
    return Probe(drift=list(drift));
}

impl Probe.missing(why: str = "not built") -> Probe {
    return Probe(drift=[why], absent=True);
}

impl Probe.by_design -> Probe {
    return Probe(omitted=True);
}

impl Probe.describe -> str {
    if self.found is not None {
        return "current";
    }
    if self.omitted {
        return "ships its floor by design";
    }
    if self.absent or not self.drift {
        return self.drift[0] if self.drift else "not built";
    }
    summary = f"stale: {self.drift[0]}";
    if len(self.drift) > 1 {
        summary += f" (and {len(self.drift) - 1} more)";
    }
    return summary;
}

impl Resolution.on_floor -> bool {
    return self.found is None;
}

impl Artifact.disabled -> bool {
    marked = building_now();
    return self.name in marked or any(name in marked for name in self.consumes);
}

impl Artifact.unavailable_reason -> str {
    return "";
}

impl Artifact.probe_sealed -> (Probe | None) {
    return None;
}

impl Artifact.probe_kit -> Probe {
    return Probe.missing();
}

impl Artifact.host_supported -> bool {
    if not self.hosts {
        return True;
    }
    import platform;
    import sys;
    host = f"{sys.platform}-{platform.machine().lower()}";
    return any(host.startswith(h) for h in self.hosts);
}

impl Artifact.build_blocker -> str {
    return "";
}

impl Artifact.provide_floor(log: Callable[[str], None]) -> None {}

impl Artifact.floor_present -> bool {
    return True;
}

impl Artifact.built -> Probe {
    return self.probe_checkout();
}
