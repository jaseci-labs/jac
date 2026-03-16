"""Fixture for W1172: Missing await on async call."""

import from asyncio { sleep }

async def fetch_data() -> str {
    await sleep(1);
    return "data";
}

async def process() -> None {
    result = fetch_data();   # <-- Warning W1172: missing await, result is coroutine
    result2 = await fetch_data();  # <-- Ok
}
