"""File-rooted `cli` app: a client of the social service (decision 3)."""

import from .social_app { Greet }

async def main -> str {
    got = await Greet(name="cli");
    return got.name;
}
