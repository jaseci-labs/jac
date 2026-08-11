impl Projection.fresh_page(id: UUID) -> (dict | None) {
    page = self.pages.get(id);
    if page is None {
        return None;
    }
    stamp = self.stamps.get(id);
    if stamp is None or (self.ttl_s > 0 and (time.monotonic() - stamp) > self.ttl_s) {
        self.pages.pop(id, None);
        self.stamps.pop(id, None);
        return None;
    }
    self.hits += 1;
    return page;
}


impl Projection.summary_of(id: UUID) -> (tuple | None) {
    return self.summaries.get(id);
}


impl Projection.absorb(pages: dict[UUID, dict]) -> None {
    now = time.monotonic();
    for (nid, page) in pages.items() {
        self.pages[nid] = page;
        self.stamps[nid] = now;
        anc = page.get('ancestors');
        cols = page.get('cols');
        if anc is not None {
            self.summaries[nid] = (tuple(anc), cols if cols is not None else {});
        }
        nbr = page.get('nbr');
        if isinstance(nbr, dict) {
            for (oid, summ) in nbr.items() {
                if oid not in self.pages {
                    self.summaries[oid] = summ;
                }
            }
        }
    }
    self.faults += len(pages);
}


impl Projection.evict(id: UUID) -> None {
    self.pages.pop(id, None);
    self.stamps.pop(id, None);
    self.summaries.pop(id, None);
}


impl Projection.clear -> None {
    self.pages.clear();
    self.stamps.clear();
    self.summaries.clear();
}


impl get_projection(key: str) -> Projection {
    proj = _REGISTRY.get(key);
    if proj is None {
        proj = Projection();
        _REGISTRY[key] = proj;
    }
    return proj;
}


impl evict_everywhere(id: UUID) -> None {
    for proj in _REGISTRY.values() {
        proj.evict(id);
    }
}


impl clear_all -> None {
    for proj in _REGISTRY.values() {
        proj.clear();
    }
}


impl projection_enabled -> bool {
    return _ENABLED;
}
