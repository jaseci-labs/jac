impl ServiceRouteTable.learn(service_name: str, templates: list[str]) -> list[str] {
    import from jaclang.scale.runtime.routing { is_learnable_prefix }

    self.unlearn(service_name);
    clashes: list[str] = [];
    for template in templates {
        prefix: str = literal_prefix(str(template));
        if not prefix or not is_learnable_prefix(prefix) {
            continue;
        }
        held: str = self._owner_of.get(prefix, "");
        if held and held != service_name {
            if prefix not in clashes {
                clashes.append(prefix);
            }
            continue;
        }
        self._owner_of[prefix] = service_name;
    }
    self._learned.add(service_name);
    self._reindex();
    return clashes;
}


impl ServiceRouteTable.forget(service_name: str) -> None {
    self.unlearn(service_name);
    self._spec_seen.pop(service_name, None);
}


impl ServiceRouteTable.owner(path: str) -> str {
    normalized: str = "/" + path.strip("/");
    for (prefix, service_name) in self._by_length {
        if normalized == prefix or normalized.startswith(prefix + "/") {
            return service_name;
        }
    }
    return "";
}


impl ServiceRouteTable.prefixes -> dict[str, str] {
    return dict(self._owner_of);
}


impl ServiceRouteTable.is_learned(service_name: str) -> bool {
    return service_name in self._learned;
}


impl ServiceRouteTable.spec_due(
    service_entry: ServiceEntry, now: float, max_age: float
) -> bool {
    if service_entry.status != ServiceStatus.HEALTHY {
        return True;
    }
    seen = self._spec_seen.get(service_entry.name);
    if seen is None {
        return True;
    }
    (url, status, at) = seen;
    if url != service_entry.url or status != service_entry.status.value {
        return True;
    }
    return now - at >= max_age;
}


impl ServiceRouteTable.mark_spec_seen(service_entry: ServiceEntry, now: float) -> None {
    self._spec_seen[service_entry.name] = (
        service_entry.url,
        service_entry.status.value,
        now
    );
}


impl ServiceRouteTable.unlearn(service_name: str) -> None {
    self._owner_of = {
        prefix: owner
        for (prefix, owner) in self._owner_of.items()
        if owner != service_name
    };
    self._learned.discard(service_name);
    self._reindex();
}


impl ServiceRouteTable._reindex -> None {
    pairs: list[tuple[str, str]] = list(self._owner_of.items());
    pairs.sort(key=lambda (p) { -len(p[0]); });
    self._by_length = pairs;
}
