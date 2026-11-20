"""Server-context consumer inside the `web` app.

`.helpers` is the same app (LOCAL); `..social_app` is owned by the `social`
service app (SERVICE_BRIDGE): its stubs are typed-async and a bare
statement-level spawn is deferred delivery.
"""

import from .helpers { shout }
import from ..social_app { Greet, greet, Profile }

async def run_it -> str {
    p = await greet("x");
    w = await Greet(name="y");
    return shout(p.name) + w.name;
}

def fire_and_forget -> None {
    Greet(name="z");
}
