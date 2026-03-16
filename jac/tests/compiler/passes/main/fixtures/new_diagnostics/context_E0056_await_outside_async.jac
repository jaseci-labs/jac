"""Fixture for E0056: await used outside of an async function."""

import from asyncio { sleep }

def not_async(self) -> None {
    await sleep(1);  # <-- Error E0056: await outside async
}

async def is_async(self) -> None {
    await sleep(1);  # <-- Ok
}
