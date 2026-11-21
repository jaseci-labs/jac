import from ..social_app { Sweep }

async def use_it -> int {
    w = await Sweep();
    return len(w.reports);
}
