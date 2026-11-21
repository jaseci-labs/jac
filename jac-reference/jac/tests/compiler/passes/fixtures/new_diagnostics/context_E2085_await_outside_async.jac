"""Fixture for E2085: 'await' used outside an async function or ability."""

async def work -> str {
    return "ok";
}

walker demo {
    can bad_run with Root entry {
        r = await work();  # <-- Error E2085 (plain 'can', not async)
        report {"r": r};
    }

    async can good_run with Root entry {
        r = await work();  # <-- Ok, ability is 'async can'
        report {"r": r};
    }
}
