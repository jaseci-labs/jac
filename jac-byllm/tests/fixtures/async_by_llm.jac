"""Fixture for testing async by llm() codegen: async def must emit await Jac.acall_llm(...)."""

import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

async def get_summary(text: str) -> str by llm();

def get_summary_sync(text: str) -> str by llm();
