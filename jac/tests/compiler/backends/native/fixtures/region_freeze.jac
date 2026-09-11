"""Freezing transfers teardown responsibility without promoting the arena."""

glob drops: int = 0;

obj Resource {
    def drop {
        drops += 1;
    }
}

def freeze_region -> int {
    drops = 0;
    region: own Region = Region();
    in region {
        resource = Resource();
    }
    published = imm region;
    return drops;
}

def read_drops -> int {
    return drops;
}

def make_frozen -> imm Region {
    region: own Region = Region();
    in region {
        resource = Resource();
    }
    return imm region;
}

def returned_region -> int {
    drops = 0;
    published = make_frozen();
    return drops;
}

def conditional_freeze(publish: bool) -> int {
    drops = 0;
    region: own Region = Region();
    in region {
        resource = Resource();
    }
    if publish {
        published = imm region;
    }
    return drops;
}
