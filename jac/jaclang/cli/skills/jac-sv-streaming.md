---
name: jac-sv-streaming
description: Produce and consume incremental endpoint responses. Use for SSE, streamed reports, token output, or cross-app stream forwarding.
---

A function endpoint can stream by reporting a `Generator`: build a nested generator and `report` it. The reporting function returns `None`; each `yield` from the reported generator leaves the server as one SSE frame:

```jac
import time;
import from typing { Generator }

def:pub narrate(n: int) -> None {
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

When the provider is another app of the workspace (an `[apps.narrator]` service app - see `jac-sv-microservices`), its `narrate` is imported through a **bridge stub**, and a bridge stub is `async def` whatever the provider returns. So the call is a coroutine: `await` it, and what comes back is the **live generator** (remote: fed by the SSE reader as frames arrive; colocated under `jac run`: the provider's own generator). Re-yield it to forward each frame the moment it arrives - an unbuffered frame-in/frame-out gateway. The provider is a plain generator `def:pub`; the consumer is an `async def:pub` that returns a generator:

```
import from typing { Generator }

import from core.narrator { narrate }    # owned by the narrator app -> bridge stub

async def:pub story(n: int) -> Generator[str, None, None] {
    frames = await narrate(n=n);                     # the coroutine resolves to the live generator
    return (str(chunk).upper() for chunk in frames); # frame in, frame out; nothing is buffered
}
```

`for chunk in narrate(n)` without the `await` is a type error (`Coroutine[...] is not iterable`) and would be a runtime `TypeError` if it got through; the stub never returns the generator directly. Pinned by `tests/compiler/test_cross_app_import.jac` (typing) and `jaclang/scale/tests/microservices/test_microservice.jac` (remote and colocated, frame by frame).

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

- **Match the return annotation to the function's return value** - an endpoint that only `report`s a generator returns `None`. An endpoint that returns a generator declares `Generator`; streaming is detected from the returned or reported value.
- **`data:` payloads are JSON-encoded** - `data: "chunk 0"` with quotes; `JSON.parse(line[6:])`, not the raw slice.
- Chunks may coalesce or split at arbitrary byte boundaries - always buffer and split on the blank-line separator, keeping the last partial frame for the next read.
- 404/405 on the stream URL = nothing registers it: no client-side stub reference AND no entry-module import (the registration rule above).
- Iterating without re-yielding (e.g. `list(frames)`) collapses the stream into one buffered response - the gateway must return or report a generator.
