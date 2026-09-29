import from ..social_app { Housekeep }

async def use_it -> str {
    w = await Housekeep(name="x");
    return w.name;
}
