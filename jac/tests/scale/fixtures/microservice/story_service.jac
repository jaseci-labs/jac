"""Streaming consumer: forwards a provider's live stream frame by frame.

`narrate` is owned by the narrator_service app, so the import is a bridge
stub and calling it returns a coroutine. Awaiting it hands back the live
generator (remote: fed by the SSE reader as frames arrive; colocated: the
provider's own generator), and re-yielding it streams the frames on.
"""

import from typing { Generator }
import from narrator_service { narrate }

async def:pub story(n: int) -> Generator[str, None, None] {
    frames = await narrate(n=n);
    return (str(chunk).upper() for chunk in frames);
}
