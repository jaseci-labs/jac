"""Queue invariants independent of compiler speed and wall-clock sleeps."""
import from unittest.mock { patch }
import from jaclang.lsp.server.scheduler { WorkQueue, WorkItem, WorkKind }
import from jaclang.lsp.protocol.server { Request }

test "opening a burst preserves every document and coalesces each document" {
    queue = WorkQueue(debounce=0.0);
    for index in range(10) {
        queue.schedule(f'file:///module{index}.jac');
    }
    queue.schedule('file:///module3.jac');
    assert len(queue.pending) == 10;
    seen: set[str] = set();
    for _ in range(10) {
        item = queue.take();
        assert isinstance(item, WorkItem);
        seen.add(item.uri);
        queue.finish(item);
    }
    assert len(seen) == 10 and not queue.pending;
    queue.stop();
    assert queue.take() is None;
}

test "request preemption preserves background work and bounds request bursts" {
    queue = WorkQueue(debounce=0.0, request_burst=2);
    queue.schedule('file:///main.jac');
    first = queue.take();
    assert isinstance(first, WorkItem);
    for index in range(3) {
        assert queue.submit(Request(index, 'textDocument/hover', {}, 0));
    }
    assert first.cancel_token.is_set();
    queue.finish(first, complete=False);
    for _ in range(2) {
        request = queue.take();
        assert isinstance(request, Request);
        queue.finish(request);
    }
    resumed = queue.take();
    assert isinstance(resumed, WorkItem) and resumed.uri == first.uri;
    assert queue.submit(Request(4, 'textDocument/hover', {}, 0));
    assert not resumed.cancel_token.is_set();
    queue.finish(resumed);
    queue.stop();
}

test "close supersedes a cancelled check and overload rejects explicitly" {
    queue = WorkQueue(debounce=0.0, request_limit=1);
    queue.schedule('file:///main.jac');
    active = queue.take();
    assert isinstance(active, WorkItem);
    queue.schedule(active.uri, WorkKind.CLOSE);
    queue.finish(active, complete=False);
    closed = queue.take();
    assert isinstance(closed, WorkItem) and closed.kind == WorkKind.CLOSE;
    queue.finish(closed);
    assert queue.submit(Request(1, 'hover', {}, 0));
    assert not queue.submit(Request(2, 'hover', {}, 0));
    abandoned = queue.stop();
    assert len(abandoned) == 1 and abandoned[0].message_id == 1;
}
