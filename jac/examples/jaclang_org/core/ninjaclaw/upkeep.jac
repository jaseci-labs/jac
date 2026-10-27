import threading;
import from uuid { uuid4 }

obj SweepItem {
    has slug: str = "",
        body: str = "";
}

obj Chore {
    has lock: threading.Lock = threading.Lock(),
        kind: str = "",
        run_id: str = "",
        progress: str = "",
        result: any = None,
        error: str = "",
        finished: bool = False;

    def busy -> bool;
    def start(kind: str, work: Callable) -> bool;
    def note(phase: str, text: str) -> None;
    def status -> tuple[str, str];
    def peek -> tuple[str, str, any, str] | None;
    def ack(run_id: str) -> None;
}

glob CHORE: Chore = Chore();

def sweep_items(
    tutorials: list[tuple[str, str, str, str, str]], version: str
) -> list[SweepItem];

def sweep(items: list[SweepItem], note: Callable) -> dict[str, list[BlockView]];

def sweep_passed(blocks: list[BlockView]) -> bool;

impl Chore.busy -> bool {
    with self.lock {
        return bool(self.kind) and not self.finished;
    }
}

impl Chore.start(kind: str, work: Callable) -> bool {
    with self.lock {
        if self.kind {
            return False;
        }
        self.kind = kind;
        self.run_id = uuid4().hex;
        self.progress = "";
        self.result = None;
        self.error = "";
        self.finished = False;
    }

    def run {
        result: any = None;
        error = "";
        try {
            result = work(self.note);
        } except Exception as e {
            error = (type(e).__name__ + ": " + str(e))[:400];
        }
        with self.lock {
            self.result = result;
            self.error = error;
            self.finished = True;
        }
    }
    threading.Thread(target=run, name="ninjaclaw-" + kind, daemon=True).start();
    return True;
}

impl Chore.note(phase: str, text: str) -> None {
    with self.lock {
        self.progress = (text or phase)[:200];
    }
}

impl Chore.status -> tuple[str, str] {
    with self.lock {
        return ("" if self.finished else self.kind, self.progress);
    }
}

impl Chore.peek -> tuple[str, str, any, str] | None {
    with self.lock {
        if not self.kind or not self.finished {
            return None;
        }
        return (self.run_id, self.kind, self.result, self.error);
    }
}

impl Chore.ack(run_id: str) -> None {
    with self.lock {
        if not self.finished or self.run_id != run_id {
            return;
        }
        self.kind = "";
        self.run_id = "";
        self.result = None;
        self.error = "";
        self.finished = False;
    }
}

impl sweep_items(
    tutorials: list[tuple[str, str, str, str, str]], version: str
) -> list[SweepItem] {
    items: list[SweepItem] = [];
    for (slug, body, status, verified, checked) in tutorials {
        if status == "removed" or checked == version {
            continue;
        }
        if status == "published" and verified == version {
            continue;
        }
        items.append(SweepItem(slug=slug, body=body));
    }
    return items;
}

impl sweep(items: list[SweepItem], note: Callable) -> dict[str, list[BlockView]] {
    results: dict[str, list[BlockView]] = {};
    for (i, item) in enumerate(items) {
        note(
            "sweep",
            "re-verifying "
                + item.slug
                + " ("
                + str(i + 1)
                + " of "
                + str(len(items))
                + ")"
        );
        results[item.slug] = verify_markdown(
            item.body, lambda (p: str, t: str) { None; }
        );
    }
    return results;
}

impl sweep_passed(blocks: list[BlockView]) -> bool {
    return bool(blocks) and all([b.ok for b in blocks]);
}
