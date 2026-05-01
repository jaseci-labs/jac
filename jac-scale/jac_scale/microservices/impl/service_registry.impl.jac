"""Implementation of ServiceRegistry methods."""

"""Register a service entry. Rebuilds prefix index."""
impl ServiceRegistry.register(service_entry: ServiceEntry) -> None {
    self.entries[service_entry.name] = service_entry;
    self._rebuild_prefix_index();
}

"""Remove a service by name. Returns True if found."""
impl ServiceRegistry.deregister(name: str) -> bool {
    if name in self.entries {
        del self.entries[name];
        self._rebuild_prefix_index();
        return True;
    }
    return False;
}

"""Find the service matching a request path (longest-prefix match)."""
impl ServiceRegistry.match_route(path: str) -> ServiceEntry | None {
    for (prefix, name) in self._sorted_prefixes {
        if path == prefix or path.startswith(prefix + "/") {
            return self.entries[name];
        }
    }
    return None;
}

"""Get all entries as a health summary dict."""
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

"""Rebuild the sorted prefix list after register/deregister.

Sorted by descending prefix length so match_route does longest-prefix match.
"""
impl ServiceRegistry._rebuild_prefix_index -> None {
    pairs: list[tuple[str, str]] = [(e.prefix, e.name) for e in self.entries.values()];
    pairs.sort(key=lambda p : -len(p[0]));
    self._sorted_prefixes = pairs;
}
