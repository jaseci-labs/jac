import time;
import threading;
import from collections { deque }
import from enum { Enum }
import from jaclang.lsp.protocol.server { Request }

enum WorkKind {
    CHECK = 'check',
    CLOSE = 'close',
    DELETE = 'delete',
    REFRESH = 'refresh',
    DEPENDENCY = 'dependency',
    SCAN = 'scan',
    INDEX = 'index'
}

obj WorkItem {
    has uri: str,
        kind: WorkKind = WorkKind.CHECK,
        ready_at: float = 0.0,
        cancel_token: threading.Event postinit;

    def postinit {
        self.cancel_token = threading.Event();
    }
}

obj WorkQueue {
    has debounce: float = 0.3,
        request_limit: int = 128,
        request_burst: int = 8,
        condition: threading.Condition postinit,
        pending: dict[str, WorkItem] = {},
        requests: deque[Request] postinit,
        workspace_requests: deque[Request] postinit,
        active: WorkItem | Request | None = None,
        stopped: bool = False,
        request_streak: int = 0,
        background_turn: bool = False,
        completed: int = 0,
        cancelled: int = 0,
        peak_pending: int = 0;

    def postinit {
        self.condition = threading.Condition();
        self.requests = deque();
        self.workspace_requests = deque();
    }

    def schedule(
        uri: str,
        kind: WorkKind = WorkKind.CHECK,
        immediate: bool = False,
        interrupt: bool = True
    ) -> None {
        with self.condition {
            if self.stopped {
                return;
            }
            previous = self.pending.get(uri);
            if kind == WorkKind.INDEX
                and previous is not None
                and previous.kind != WorkKind.INDEX {
                return;
            }
            deadline = time.monotonic() + (0.0 if immediate else self.debounce);
            self.pending[uri] = WorkItem(uri, kind, deadline);
            if interrupt and isinstance(self.active, WorkItem) {
                self.active.cancel_token.set();
            }
            self.peak_pending = max(self.peak_pending, len(self.pending));
            self.condition.notify_all();
        }
    }

    def submit(request: Request, after_workspace: bool = False) -> bool {
        with self.condition {
            if self.stopped
                or len(self.requests) + len(self.workspace_requests)
                    >= self.request_limit {
                return False;
            }
            if after_workspace {
                self.workspace_requests.append(request);
            } else {
                self.requests.append(request);
            }
            if not after_workspace
                and isinstance(self.active, WorkItem)
                and not self.background_turn {
                self.active.cancel_token.set();
            }
            self.condition.notify_all();
            return True;
        }
    }

    def take -> WorkItem | Request | None {
        with self.condition {
            while not self.stopped {
                now = time.monotonic();
                if self.workspace_requests
                    and (
                        self.workspace_requests[0].responded
                        or self.workspace_requests[0].cancel_token.is_set()
                        or not self.pending
                    ) {
                    self.requests.append(self.workspace_requests.popleft());
                }
                ready = next(
                    (
                        item
                        for item in self.pending.values()
                        if item.ready_at <= now
                            and item.kind not in (WorkKind.SCAN, WorkKind.INDEX)
                    ),
                    None
                );
                if ready is None {
                    ready = next(
                        (
                            item
                            for item in self.pending.values()
                            if item.ready_at <= now
                        ),
                        None
                    );
                }
                self.background_turn = ready is not None
                    and ready.kind not in (WorkKind.SCAN, WorkKind.INDEX)
                    and self.request_streak >= self.request_burst;
                if self.requests and not self.background_turn {
                    self.active = self.requests.popleft();
                    self.request_streak += 1;
                    return self.active;
                }
                if ready is not None {
                    del self.pending[ready.uri];
                    self.active = ready;
                    self.request_streak = 0;
                    return ready;
                }
                delay = min(
                    (item.ready_at - now for item in self.pending.values()),
                    `default=None
                );
                self.condition.`wait(timeout=delay);
            }
        }
        return None;
    }

    def finish(item: WorkItem | Request, complete: bool = True) {
        with self.condition {
            if isinstance(item, WorkItem) {
                if not complete {
                    self.cancelled += 1;
                    if not self.stopped and item.uri not in self.pending {
                        self.pending[item.uri] = WorkItem(item.uri, item.kind);
                    }
                } else {
                    self.completed += 1;
                }
            }
            self.active = None;
            self.condition.notify_all();
        }
    }

    def flush {
        with self.condition {
            for item in self.pending.values() {
                item.ready_at = 0.0;
            }
            self.condition.notify_all();
            while not self.stopped
                and (
                    self.pending
                    or self.requests
                    or self.workspace_requests
                    or self.active is not None
                ) {
                self.condition.`wait();
            }
        }
    }

    def stop -> list[Request] {
        with self.condition {
            self.stopped = True;
            if self.active is not None {
                self.active.cancel_token.set();
            }
            abandoned = [*self.requests, *self.workspace_requests];
            self.requests.clear();
            self.workspace_requests.clear();
            self.pending.clear();
            self.condition.notify_all();
            return abandoned;
        }
    }
}
