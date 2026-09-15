"""Async `by llm()` codegen: an async def must emit `await Jac.acall_llm(...)`."""

async def get_summary(text: str) -> str by llm();

def get_summary_sync(text: str) -> str by llm();
