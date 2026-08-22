impl ServiceRouteTable.learn(service_name: str, templates: list[str]) -> list[str] {
    import from jaclang.scale.runtime.gateway.dispatch { is_gateway_owned }

    self.forget(service_name);
    clashes: list[str] = [];
    for template in templates {
        prefix: str = literal_prefix(str(template));
        if not prefix or is_gateway_owned(prefix) {
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
    self._reindex();
    return clashes;
}


impl ServiceRouteTable.forget(service_name: str) -> None {
    self._owner_of = {
        prefix: owner
        for (prefix, owner) in self._owner_of.items()
        if owner != service_name
    };
    self._reindex();
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


impl ServiceRouteTable._reindex -> None {
    pairs: list[tuple[str, str]] = list(self._owner_of.items());
    pairs.sort(key=lambda (p) { -len(p[0]); });
    self._by_length = pairs;
}
