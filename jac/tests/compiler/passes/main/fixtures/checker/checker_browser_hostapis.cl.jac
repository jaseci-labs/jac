"""Client-context fixture: the WHATWG browser host-API surface (issue #7114).

Mirrors the this_is_jac showcase patterns that must type-check cleanly:
frontend.impl.jac's SSE reader loop (`(await fetch(...)).body.getReader()`
+ `TextDecoder`), NativeSection.cl.jac's `fetch` + `resp.json()` with the
parsed payload cast to a concrete shape at the boundary (the strict-gradual
idiom), SourceViewer/CodeBlock's `navigator.clipboard.writeText(...)`, and
raylib_shim.cl.jac's `document.pointerLockElement` / `exitPointerLock()`.

Everything here must check clean EXCEPT the single deliberate error at the
bottom (`resp.nope()`), which pins that `Response` is a real strict type,
not a permissive escape hatch.
"""

async def read_stream(url: str) -> str {
    resp = await fetch(url);
    ok: bool = resp.ok;
    status: float = resp.status;
    if not ok or status == 0.0 {
        return "";
    }
    reader = resp.body.getReader();
    decoder = new(TextDecoder);
    buf = "";
    while True {
        chunk = await reader.read();
        if chunk.done {
            break;
        }
        buf = buf + decoder.decode(chunk.value);
    }
    return buf;
}

async def load_json(url: str) -> float {
    resp = await fetch(url);
    if not resp.ok {
        return 0.0;
    }
    data = (await resp.json()) as dict[str, dict[str, float]];
    return data["jac"]["avg"];
}

async def get_text(url: str) -> str {
    resp = await fetch(url);
    return await resp.text();
}

def encode_roundtrip(s: str) -> str {
    enc = new(TextEncoder);
    encoded = enc.encode(s);
    dec = new(TextDecoder, "utf-8");
    return dec.decode(encoded);
}

async def copy_text(t: str) -> None {
    await navigator.clipboard.writeText(t);
}

async def paste_text() -> str {
    return await navigator.clipboard.readText();
}

def release_pointer() -> bool {
    if document.pointerLockElement {
        document.exitPointerLock();
        return True;
    }
    return False;
}

# The ONE deliberate error: a member missing from the WHATWG Response
# surface must still be flagged (E1030).
async def bad(url: str) -> None {
    resp = await fetch(url);
    resp.nope();
}
