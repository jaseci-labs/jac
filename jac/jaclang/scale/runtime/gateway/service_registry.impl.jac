impl ServiceRegistry.register(service_entry: ServiceEntry) -> None {
    self.entries[service_entry.name] = service_entry;
    self._rebuild_prefix_index();
}

impl ServiceRegistry.deregister(name: str) -> bool {
    if name in self.entries {
        del self.entries[name];
        self._rebuild_prefix_index();
        return True;
    }
    return False;
}

impl ServiceRegistry.match_route(path: str) -> ServiceEntry | None {
    for (prefix, name) in self._sorted_prefixes {
        if path == prefix or path.startswith(prefix + "/") {
            return self.entries[name];
        }
    }
    return None;
}

impl ServiceRegistry.health_summary -> dict[str, dict] {
    result: dict[str, dict] = {};
    for (name, entry) in self.entries.items() {
        result[name] = {
            "file": entry.file,
            "prefix": entry.prefix,
            "port": entry.port,
            "url": entry.url,
            "status": entry.status.value,
            "pid": entry.pid
        };
    }
    return result;
}

impl ServiceRegistry._rebuild_prefix_index -> None {
    pairs: list[tuple[str, str]] = [(e.prefix, e.name) for e in self.entries.values()];
    pairs.sort(key=lambda (p) { -len(p[0]); });
    self._sorted_prefixes = pairs;
}
