"""The bridged stream, awaited: the coroutine yields the live generator."""

import from typing { Generator }
import from ..social_app { narrate }

async def:pub story -> Generator[str, None, None] {
    frames = await narrate(n=3);
    return (str(chunk).upper() for chunk in frames);
}
