import time;

glob REVIEWED: list[str] = [];

node Task {
    has title: str = "";
}

walker Review {
    has run_id: str,
        hang: bool = False,
        node_id: str = "",
        expect_root: str = "";

    can go with Root entry {
        if self.hang {
            time.sleep(3.0);
        }
        if self.expect_root and jid(root) != self.expect_root {
            raise RuntimeError(f"ran as root {jid(root)}, expected {self.expect_root}");
        }
        if self.node_id and jobj(self.node_id) is None {
            raise RuntimeError(f"node {self.node_id} is not visible to this job");
        }
        REVIEWED.append(self.run_id);
    }
}

walker Housekeeping {
    has tenant_root: str = "";

    can go with Root entry {
        if jid(root) == self.tenant_root {
            raise RuntimeError("a system target ran as the tenant's root");
        }
    }
}
