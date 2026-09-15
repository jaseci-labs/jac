"""Async `by llm(stream=True)`, for jac#8932. The test binds `llm`."""

glob llm: any = None;

async def ask(topic: str) -> str by llm(stream=True);
