"""A `cli` app spawning a bridged walker: the stub's constructor is the remote
spawn and codegen drops the `root spawn` around it, so the expression is the
coroutine the stub returns and is awaited as such."""

import from social_app { Greet }

async def run_greet(name: str) -> list {
    walked = await (root spawn Greet(name=name));
    return walked.reports;
}

def greet_count(name: str) -> int {
    return root spawn Greet(name=name);
}
