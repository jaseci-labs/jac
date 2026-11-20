"""Async `by llm()` codegen: an async def must emit `await Jac.acall_llm(...)`.

The test binds its own model before calling.
"""

import from jaclang.byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

async def get_summary(text: str) -> str by llm();

def get_summary_sync(text: str) -> str by llm();
