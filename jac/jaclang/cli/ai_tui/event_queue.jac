import from jaclang.cli.ai_tui.session_models {
    SessionEventBatch,
    UiMutation,
    mutation_dict
}
import from jaclang.cli.ai_tui.bridge_schema { MUT_SNAPSHOT_REQUIRED }

glob DEFAULT_DRAIN_CAP: int = 64,
     DEFAULT_MAX_RECORDS: int = 1024,
     DEFAULT_MAX_BYTES: int = 8 * 1024 * 1024;


obj TuiEventQueue {
    has _items: list[UiMutation] = [],
        _bytes: int = 0,
        max_records: int = DEFAULT_MAX_RECORDS,
        max_bytes: int = DEFAULT_MAX_BYTES,
        closed: bool = False,
        snapshot_required: bool = False,
        epoch: int = 0;

    def close {
        self.closed = True;
    }

    def require_snapshot(reason: str) {
        self.snapshot_required = True;
        self._items = [
            UiMutation(
                kind=MUT_SNAPSHOT_REQUIRED, seq=0, epoch=self.epoch, diagnostic=reason
            )
        ];
        self._bytes = len(reason);
    }

    def submit(item: UiMutation) {
        if self.closed {
            return;
        }
        if self.snapshot_required and item.kind != MUT_SNAPSHOT_REQUIRED {
            return;
        }
        if item.epoch != 0 {
            self.epoch = item.epoch;
        }
        self._coalesce_or_append(item);
        if len(self._items) > self.max_records or self._bytes > self.max_bytes {
            self.require_snapshot("queue_overflow");
        }
    }

    def drain(cap: int = DEFAULT_DRAIN_CAP) -> SessionEventBatch {
        n = min(cap, len(self._items));
        if n <= 0 {
            return SessionEventBatch(epoch=self.epoch);
        }
        chunk = self._items[:n];
        self._items = self._items[n:];
        self._recompute_bytes();
        if self.snapshot_required and not self._items {
            self.snapshot_required = False;
        }
        first = chunk[0].seq;
        last = chunk[n - 1].seq;
        return SessionEventBatch(
            epoch=self.epoch, first_seq=first, last_seq=last, mutations=chunk
        );
    }

    def _coalesce_or_append(item: UiMutation) {
        if self._items and item.op in ("text_append", "thinking_append") {
            prev = self._items[len(self._items) - 1];
            if (
                prev.kind == item.kind
                and prev.message_id == item.message_id
                and prev.part_id == item.part_id
                and prev.op == item.op
                and prev.epoch == item.epoch
            ) {
                prev.text += item.text;
                self._recompute_bytes();
                return;
            }
        }

        if item.kind == "runtime_state_changed" and self._items {
            last_i = len(self._items) - 1;
            if self._items[last_i].kind == "runtime_state_changed" {
                self._items[last_i] = item;
                self._recompute_bytes();
                return;
            }
        }
        self._items.append(item);
        self._bytes += len(item.text) + len(item.diagnostic) + 64;
    }

    def _recompute_bytes {
        total = 0;
        for it in self._items {
            total += len(it.text) + len(it.diagnostic) + 64;
        }
        self._bytes = total;
    }
}
