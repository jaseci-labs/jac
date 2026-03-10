"""Test that by llm() compiles without defining glob llm.

This file has NO glob llm declaration. The 'llm' name should resolve
as a builtin via the auto-import mechanism in the codegen.
"""

def summarize(text: str) -> str by llm();
