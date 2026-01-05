impl MultiHierarchyMemory.<>set(anchor: TANCH) {
    self.mem.set(anchor);
}

impl MultiHierarchyMemory.remove(anchor: Anchor) {
    self.mem.remove(anchor.id);
    if self.redis_available {
        self.redis.remove(anchor);
    }
    if self.mongo_available {
        self.mongo.remove(anchor);
    } elif self.shelf {
        self.shelf.remove(anchor);
    }
}

impl MultiHierarchyMemory.sync(anchors: Iterable[Anchor]) -> None {
    try {
        if self.redis_available {
            self.redis.commit(keys=anchors);
        }
        if self.mongo_available {
            self.mongo.commit(keys=anchors);
        } elif self.shelf {
            self.shelf.commit(keys=anchors);
        }
    } except Exception { }
}

impl MultiHierarchyMemory.close{
    self.commit();
    self.mem.close();
    if self.mongo {
        self.mongo.close();
    }
    if self.shelf {
        self.shelf.close();
    }
}

impl MultiHierarchyMemory.commit(anchor: (Anchor | None) = None) {
    try {
        gc = self.mem.get_gc();
        memory = self.mem.get_mem();
        if (anchor) {
            if (anchor in gc) {
                self.delete(anchor);
                self.mem.remove_from_gc(anchor);
            } else {
                if (self.mongo_available) {
                    self.mongo.set(anchor);
                } elif (self.shelf) {
                    self.shelf.set(anchor);
                }
            }
            return;
        }
        for anchor in gc {
            self.delete(anchor);
            self.mem.remove_from_gc(anchor);
        }
        anchors = <>set(memory.values());
        self.sync(anchors);
    } except Exception { }
}

impl MultiHierarchyMemory.find_by_id(id: UUID) -> (Anchor | None) {
    if (anchor := self.mem.find_by_id(id)) {
        return anchor;
    }
    if (self.redis_available) {
        if (anchor := self.redis.find_by_id(id)) {
            self.mem.set(anchor);
            return anchor;
        }
    }
    if (self.mongo_available) {
        if (anchor := self.mongo.find_by_id(id)) {
            self.mem.set(anchor);
            if (self.redis_available) {
                self.redis.set(anchor);
            }
            return anchor;
        }
    } elif self.shelf {
        if (anchor := self.shelf.find_by_id(id)) {
            self.mem.set(anchor);
            return anchor;
        }
    }
    return None;
}

impl MultiHierarchyMemory.init -> None {
    super.init();
    self.mem = Memory[(UUID, Anchor)]();
    self.redis = RedisDB();
    self.mongo = MongoDB();
    self.shelf: (ShelfDB | None) = None;
    self.redis_available = self.redis.redis_is_available();
    self.mongo_available = self.mongo.mongo_is_available();
    if (not self.redis_available and not self.mongo_available) {
        self.shelf = ShelfDB();
    }
}
