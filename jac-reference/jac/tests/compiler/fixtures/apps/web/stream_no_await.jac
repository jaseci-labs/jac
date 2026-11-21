"""A bridged streaming stub iterated without `await`: the stub is a coroutine."""

import from typing { Generator }
import from ..social_app { narrate }

def:pub story -> Generator[str, None, None] {
    for chunk in narrate(n=3) {
        yield str(chunk);
    }
}
