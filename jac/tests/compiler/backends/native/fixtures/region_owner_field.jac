"""An arena follows its owning aggregate across a function boundary."""

glob drops: int = 0;

obj Resource {
    def drop {
        drops += 1;
    }
}

obj Snapshot {
    has region: own Region;

    def observed_drops -> int {
        return drops;
    }
}

obj PublishedSnapshot {
    has region: imm Region;

    def observed_drops -> int {
        return drops;
    }
}

def make_snapshot -> own Snapshot {
    region: own Region = Region();
    in region {
        resource = Resource();
    }
    return Snapshot(region=region);
}

def observe -> int {
    drops = 0;
    snapshot = make_snapshot();
    return snapshot.observed_drops();
}

def read_drops -> int {
    return drops;
}

def make_published -> own PublishedSnapshot {
    region: own Region = Region();
    in region {
        resource = Resource();
    }
    frozen = imm region;
    retained = frozen;
    return PublishedSnapshot(region=retained);
}

def observe_published -> int {
    drops = 0;
    snapshot = make_published();
    return snapshot.observed_drops();
}

def observe_partition -> int {
    drops = 0;
    parent: own Region = Region();
    (left, right) = parent.partition(2);
    in left {
        resource = Resource();
    }
    in right {
        resource = Resource();
    }
    return drops;
}
