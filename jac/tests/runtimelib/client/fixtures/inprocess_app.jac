"""Minimal `sv` backend fixture for the in-process dispatch round-trip test.

This is the `sv` half of a Jac-native desktop app: one walker (carrying a field,
to exercise the `fields` part of the request contract) and one `sv` function.
The `cl` half -- the client runtime routing a call through `window.__jac_invoke`
instead of `fetch` -- is covered by `jac/tests/runtimelib/test_native_invoke.jac`.
Together the two tests exercise the full `cl` -> `sv` in-process path (#6596)
without needing a live webview, a display, or `nacompile`.
"""

walker:pub greet {
    has name: str = "world";

    can run with Root entry {
        report {"greeting": f"hello {self.name}"};
    }
}

def:pub add(a: int, b: int) -> int {
    return a + b;
}


"""Streaming fixture: CEF projects as SSE; native webview uses push emit."""
def:pub stream_numbers(n: int = 3) -> any {
    for i in range(n) {
        yield {"n": i};
    }
}


# `root.shared` round-trip (#6685): a note written to the shared root by one
# request must be readable by a later one, proving the shared-root resolver the
# no-serve seam installs works on the desktop in-process path. Mirrors
# jac/tests/runtimelib/fixtures/serve_shared_root.jac.
node Note {
    has text: str = "";
}

edge HasNote {}

walker:pub leave_note {
    has text: str = "";

    can run with Root entry {
        fresh = root.shared +>:HasNote():+> Note(text=self.text);
        if fresh {
            # The note is owned by its author; open it to all readers.
            grant(fresh, level=AccessLevel.READ);
        }
        report {"saved": self.text};
    }
}

walker:pub read_notes {
    can run with Root entry {
        report {"notes": sorted([n.text for n in [root.shared-->[?:Note]]])};
    }
}


# Streaming context-lifetime regression: each yield frame performs a graph
# WRITE to root.shared. A transport drains this generator long after the
# invocation coroutine returned; unless every step (and the final commit) runs
# inside the captured request context, these writes hit a torn-down context.
# The paired test drains it through the native push pump, then a separate
# read_notes proves all notes committed exactly once.
def:pub stream_notes(texts: list[str]) -> any {
    for t in texts {
        fresh = root.shared +>:HasNote():+> Note(text=t);
        if fresh {
            grant(fresh, level=AccessLevel.READ);
        }
        yield {"saved": t};
    }
}


# Async counterpart of `stream_numbers` (Phase 3): an async generator drained by
# the native pump on a fresh event loop via `context_bound_async_stream`. The
# body reads the request-scoped context (`root` must resolve for the whole drain)
# but does NOT write graph state -- graph writes inside async yield frames are
# proven deterministically by tests/runtimelib/test_streaming.jac. (Keeping the
# async body read-only also keeps this wired-path e2e deterministic under the
# pytest harness, which swaps the Jac execution context between test blocks;
# `get_shared_root` now re-resolves a stale cached root id after a guest-root
# heal -- see `JacRuntime.get_shared_root` -- so graph writes across context
# swaps work, but an async graph-write stream is exercised at the unit level in
# test_streaming.jac rather than here.)
async def:pub astream_numbers(n: int = 3) -> any {
    for i in range(n) {
        # Touch the request context so a torn-down context would surface as an
        # error frame, without persisting graph state across requests.
        _ = root;
        yield {"n": i};
    }
}
