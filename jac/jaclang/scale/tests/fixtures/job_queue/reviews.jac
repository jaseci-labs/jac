import time;

glob REVIEWED: list[str] = [];

walker Review {
    has run_id: str,
        hang: bool = False;

    can go with Root entry {
        if self.hang {
            time.sleep(3.0);
        }
        REVIEWED.append(self.run_id);
    }
}
