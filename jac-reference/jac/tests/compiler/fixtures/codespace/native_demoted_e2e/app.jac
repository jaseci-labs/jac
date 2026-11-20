import from .models { double }

async def use_double -> int {
    return await double(2);
}
