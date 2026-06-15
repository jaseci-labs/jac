---
name: jac-sv-streaming
description: Streaming endpoints - SSE (server-sent events), `def:pub ... -> Generator`, `report stream()`, progress updates, live feeds, token-by-token output, sv-to-sv stream pass-through, consuming a stream in the browser with fetch + getReader. Load when an endpoint must deliver results incrementally instead of one response. Pair with `jac-sv-endpoints`, `jac-sv-microservices`.
---

A function endpoint streams by returning a `Generator`: build a nested generator and `report` it - the ONE place a `def` uses `report` (everywhere else only walkers report). Each `yield` leaves the server as one SSE frame the moment it happens:

```jac
import time;
import from typing { Generator }

def:pub narrate(n: int) -> Generator {
    def stream -> Generator[str, None, None] {
        for i in range(n) {
            time.sleep(0.2);            # stand-in for real incremental work
            yield f"chunk {i}";
        }
    }
    report stream();                    # a def that reports - streaming's one exception
}
```

`curl -N -X POST http://localhost:8000/function/narrate -d '{"n":5}' -H "Content-Type: application/json"` shows the wire format: one `data: "chunk 0"` frame per yield (payloads JSON-encoded), frames separated by a blank line, an `event: end` frame at the close. Frames arrive as they are yielded - no buffering (verified live).

## sv-to-sv pass-through (streaming gateway)

When another server module `sv import`s the provider, calling its streaming endpoint returns a **live generator**, not a buffered list. Iterate and re-yield to forward each frame the moment it arrives - an unbuffered frame-in/frame-out gateway:

```jac
import from typing { Generator }

sv import from analytics { narrate }    # provider's own streaming endpoint

def:pub story() -> Generator {
    def stream -> Generator[str, None, None] {
        for chunk in narrate(42) {      # live remote generator: frame in...
            yield str(chunk);           # ...frame out; nothing is buffered
        }
    }
    report stream();
}
```

## Consuming a stream in the browser

RPC stubs cannot consume streams - `await story()` waits for the whole response. Use a raw `fetch` against `/function/<name>` and read SSE frames off the body (no `"\n"` literals in cl code - use `chr(10)`):

```
resp = await fetch("/function/story", {
    "method": "POST",
    "headers": {"Content-Type": "application/json"},
    "body": "{}"
});
reader = resp.body.getReader();
decoder = new(TextDecoder);
nl = chr(10);
buf = "";
acc = "";                                  # accumulate locally, not in reactive state
feeding = True;
while feeding {
    part = await reader.read();
    if part.done { feeding = False; continue; }
    buf = buf + decoder.decode(part.value, {"stream": True});
    frames = buf.split(nl + nl);           # frames end with a blank line
    buf = frames.pop();                    # keep the trailing partial frame
    for frame in frames {
        for line in frame.split(nl) {
            if line.startswith("data: ") and not frame.startswith("event:") {
                acc = acc + JSON.parse(line[6:]);
                story = acc;               # assign the WHOLE value per frame
            }
        }
    }
}
```

Reactive-state note: reading `story` back inside this async loop sees the render-time snapshot, not the latest value - append to the local `acc` and assign the full paragraph each frame.

## Registration: streams need an entry-module import

A raw-fetch stream has no client RPC stub referencing it, so the manifest-driven self-registration never sees it (see `jac-fullstack-patterns`). Import it at the top level of the entry module or the fetch 404/405s:

```
import from guestbook { story }     # in main.jac, top level (server context)
```

## Pitfalls

- **`report stream();`, not `return stream();`** - and the outer endpoint's return type must be `Generator`, or the result is serialized as one ordinary response.
- **`data:` payloads are JSON-encoded** - `data: "chunk 0"` with quotes; `JSON.parse(line[6:])`, not the raw slice.
- Chunks may coalesce or split at arbitrary byte boundaries - always buffer and split on the blank-line separator, keeping the last partial frame for the next read.
- 404/405 on the stream URL = nothing registers it: no client-side stub reference AND no entry-module import (the registration rule above).
- Iterating without re-yielding (e.g. `list(narrate(n))`) collapses the stream into one buffered response - the gateway must itself report a generator.
